#!/usr/bin/env bash

# Main test runner for git-checkpoints
# Runs all test suites and provides comprehensive reporting

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE="${VERBOSE:-0}"
SKIP_INTEGRATION="${SKIP_INTEGRATION:-0}"
SKIP_UNIT="${SKIP_UNIT:-0}"
PARALLEL="${PARALLEL:-0}"

# Test results
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
SUITE_RESULTS=()

# Output functions
print_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
print_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Help function
show_help() {
    cat <<EOF
Git Checkpoints Test Runner

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -v, --verbose           Enable verbose output
  -u, --unit-only         Run only unit tests
  -i, --integration-only  Run only integration tests
  -p, --parallel          Run tests in parallel (experimental)
  --skip-cleanup          Skip cleanup of test repositories
  --test-repo-prefix      Prefix for test repository names

Environment Variables:
  VERBOSE=1               Enable verbose output
  SKIP_INTEGRATION=1      Skip integration tests
  SKIP_UNIT=1             Skip unit tests
  SKIP_CLEANUP=1          Skip cleanup of test repositories
  TEST_REPO_PREFIX        Prefix for test repository names
  PARALLEL=1              Run tests in parallel

Examples:
  $0                      Run all tests
  $0 --unit-only          Run only unit tests
  $0 --integration-only   Run only integration tests
  $0 --verbose            Run with verbose output

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                export VERBOSE=1
                ;;
            -u|--unit-only)
                SKIP_INTEGRATION=1
                ;;
            -i|--integration-only)
                SKIP_UNIT=1
                ;;
            -p|--parallel)
                PARALLEL=1
                ;;
            --skip-cleanup)
                export SKIP_CLEANUP=1
                ;;
            --test-repo-prefix)
                export TEST_REPO_PREFIX="$2"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if git-checkpoints script exists
    if ! command -v git-checkpoints &>/dev/null && [ ! -f "../git-checkpoints" ] && [ ! -f "./git-checkpoints" ]; then
        print_error "git-checkpoints script not found"
        print_error "Make sure the script is in PATH or in the parent directory"
        exit 1
    fi
    
    # Check git configuration
    if ! git config user.name &>/dev/null || ! git config user.email &>/dev/null; then
        print_warning "Git user.name or user.email not configured"
        print_info "Setting temporary git configuration for tests..."
        git config --global user.name "Test User" 2>/dev/null || true
        git config --global user.email "test@example.com" 2>/dev/null || true
    fi
    
    # Check for integration test prerequisites
    if [ "$SKIP_INTEGRATION" != "1" ]; then
        if ! command -v gh &>/dev/null; then
            print_warning "GitHub CLI (gh) not found - skipping integration tests"
            print_info "Install GitHub CLI and authenticate to run integration tests"
            SKIP_INTEGRATION=1
        elif ! gh auth status &>/dev/null; then
            print_warning "GitHub CLI not authenticated - skipping integration tests"
            print_info "Run 'gh auth login' to enable integration tests"
            SKIP_INTEGRATION=1
        fi
    fi
    
    print_success "Prerequisites check completed"
}

# Run a test suite
run_test_suite() {
    local suite_name="$1"
    local script_path="$2"
    local start_time end_time duration
    
    print_info "Running $suite_name..."
    start_time=$(date +%s)
    
    if [ "$VERBOSE" = "1" ]; then
        if bash "$script_path"; then
            local exit_code=0
        else
            local exit_code=$?
        fi
    else
        local output
        if output=$(bash "$script_path" 2>&1); then
            local exit_code=0
        else
            local exit_code=$?
        fi
    fi
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        print_success "$suite_name completed successfully (${duration}s)"
        SUITE_RESULTS+=("$suite_name:PASS:${duration}s")
    else
        print_error "$suite_name failed (${duration}s)"
        SUITE_RESULTS+=("$suite_name:FAIL:${duration}s")
        
        if [ "$VERBOSE" != "1" ] && [ -n "${output:-}" ]; then
            print_error "Test output:"
            echo "$output"
        fi
    fi
    
    return $exit_code
}

# Run tests in parallel
run_tests_parallel() {
    local pids=()
    local results_dir
    results_dir=$(mktemp -d)
    
    print_info "Running tests in parallel..."
    
    # Start unit tests
    if [ "$SKIP_UNIT" != "1" ]; then
        (
            if run_test_suite "Unit Tests" "$SCRIPT_DIR/unit_tests.sh"; then
                echo "PASS" > "$results_dir/unit"
            else
                echo "FAIL" > "$results_dir/unit"
            fi
        ) &
        pids+=($!)
    fi
    
    # Start integration tests
    if [ "$SKIP_INTEGRATION" != "1" ]; then
        (
            if run_test_suite "Integration Tests" "$SCRIPT_DIR/integration_test.sh"; then
                echo "PASS" > "$results_dir/integration"
            else
                echo "FAIL" > "$results_dir/integration"
            fi
        ) &
        pids+=($!)
    fi
    
    # Wait for all tests to complete
    local overall_result=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            overall_result=1
        fi
    done
    
    # Clean up
    rm -rf "$results_dir"
    
    return $overall_result
}

# Run tests sequentially
run_tests_sequential() {
    local overall_result=0
    
    # Run unit tests
    if [ "$SKIP_UNIT" != "1" ]; then
        if ! run_test_suite "Unit Tests" "$SCRIPT_DIR/unit_tests.sh"; then
            overall_result=1
        fi
    fi
    
    # Run integration tests
    if [ "$SKIP_INTEGRATION" != "1" ]; then
        if ! run_test_suite "Integration Tests" "$SCRIPT_DIR/integration_test.sh"; then
            overall_result=1
        fi
    fi
    
    return $overall_result
}

# Print test summary
print_summary() {
    echo
    echo "========================================"
    echo "Test Suite Summary"
    echo "========================================"
    
    local total_suites=0
    local passed_suites=0
    local failed_suites=0
    
    for result in "${SUITE_RESULTS[@]}"; do
        IFS=':' read -r suite_name status duration <<< "$result"
        total_suites=$((total_suites + 1))
        
        if [ "$status" = "PASS" ]; then
            echo -e "${GREEN}✅ $suite_name${NC} ($duration)"
            passed_suites=$((passed_suites + 1))
        else
            echo -e "${RED}❌ $suite_name${NC} ($duration)"
            failed_suites=$((failed_suites + 1))
        fi
    done
    
    echo
    echo "Suites run: $total_suites"
    echo -e "Suites passed: ${GREEN}$passed_suites${NC}"
    echo -e "Suites failed: ${RED}$failed_suites${NC}"
    
    if [ $failed_suites -eq 0 ]; then
        echo -e "${GREEN}🎉 All test suites passed!${NC}"
        return 0
    else
        echo -e "${RED}💥 Some test suites failed!${NC}"
        return 1
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    exit $exit_code
}

# Main function
main() {
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Parse arguments
    parse_args "$@"
    
    # Print header
    echo "========================================"
    echo "Git Checkpoints Test Suite Runner"
    echo "========================================"
    echo "Timestamp: $(date)"
    echo "Working Directory: $(pwd)"
    echo "Script Directory: $SCRIPT_DIR"
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Determine what tests to run
    local tests_to_run=()
    if [ "$SKIP_UNIT" != "1" ]; then
        tests_to_run+=("Unit Tests")
    fi
    if [ "$SKIP_INTEGRATION" != "1" ]; then
        tests_to_run+=("Integration Tests")
    fi
    
    if [ ${#tests_to_run[@]} -eq 0 ]; then
        print_warning "No tests to run (all test suites skipped)"
        exit 0
    fi
    
    print_info "Tests to run: ${tests_to_run[*]}"
    echo
    
    # Run tests
    local start_time end_time total_duration
    start_time=$(date +%s)
    
    if [ "$PARALLEL" = "1" ] && [ ${#tests_to_run[@]} -gt 1 ]; then
        run_tests_parallel
        local result=$?
    else
        run_tests_sequential
        local result=$?
    fi
    
    end_time=$(date +%s)
    total_duration=$((end_time - start_time))
    
    # Print summary
    echo
    print_summary
    echo
    echo "Total execution time: ${total_duration}s"
    
    if [ $result -eq 0 ]; then
        print_success "All tests completed successfully! 🚀"
        exit 0
    else
        print_error "Some tests failed! 🔥"
        exit 1
    fi
}

# Run main function
main "$@"
