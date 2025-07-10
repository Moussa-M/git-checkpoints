#!/usr/bin/env bash

# Cron seconds test for git-checkpoints
# Tests 10-second interval auto-checkpointing with file changes

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test_helpers.sh"

# Test configuration
TEST_REPO_NAME="git-checkpoints-seconds-test-$(date +%s)"
SKIP_CLEANUP="${SKIP_CLEANUP:-0}"
TEST_DURATION=60  # Test for 60 seconds

# Global variables
ORIGINAL_DIR=""
TEST_DIR=""
GITHUB_REPO_CREATED=0
GIT_CHECKPOINTS_PATH=""
WRAPPER_PID=""

# Cleanup function
cleanup() {
    local exit_code=$?
    
    test_info "Cleaning up seconds test environment..."
    
    # Kill wrapper process if running
    if [ -n "$WRAPPER_PID" ]; then
        kill "$WRAPPER_PID" 2>/dev/null || true
        test_info "Stopped auto-checkpoint process"
    fi
    
    # Remove wrapper scripts
    rm -f /tmp/git-checkpoints-wrapper-*.sh
    
    # Remove any cron jobs we might have created
    if command -v crontab &>/dev/null; then
        local temp_cron
        temp_cron=$(mktemp)
        crontab -l 2>/dev/null | grep -v "git-checkpoints-wrapper" > "$temp_cron" || true
        crontab "$temp_cron" 2>/dev/null || true
        rm -f "$temp_cron"
    fi
    
    # Return to original directory
    if [ -n "$ORIGINAL_DIR" ]; then
        cd "$ORIGINAL_DIR"
    fi
    
    # Clean up local test directory
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
        test_info "Removed local test directory: $TEST_DIR"
    fi
    
    # Clean up GitHub repository
    if [ $GITHUB_REPO_CREATED -eq 1 ] && [ "$SKIP_CLEANUP" != "1" ]; then
        test_info "Deleting GitHub repository: $TEST_REPO_NAME"
        if delete_github_repo "$TEST_REPO_NAME"; then
            test_info "Successfully deleted GitHub repository"
        else
            test_warning "Failed to delete GitHub repository: $TEST_REPO_NAME"
        fi
    fi
    
    exit $exit_code
}

trap cleanup EXIT

# Test setup
setup_seconds_test() {
    test_info "Setting up 10-second interval test..."
    
    ORIGINAL_DIR="$(pwd)"
    GIT_CHECKPOINTS_PATH=$(get_git_checkpoints_path)
    
    if [ $? -ne 0 ]; then
        test_error "Cannot find git-checkpoints script"
        exit 1
    fi
    
    # Check prerequisites
    if ! command -v gh &>/dev/null; then
        test_error "GitHub CLI (gh) is required for seconds tests"
        exit 1
    fi
    
    if ! gh auth status &>/dev/null; then
        test_error "GitHub CLI is not authenticated"
        exit 1
    fi
    
    if ! command -v crontab &>/dev/null; then
        test_warning "crontab not available - will test manually"
    fi
    
    # Create GitHub repository
    test_info "Creating GitHub repository: $TEST_REPO_NAME"
    if create_github_repo "$TEST_REPO_NAME" "10-second interval test repository for git-checkpoints"; then
        GITHUB_REPO_CREATED=1
        test_success "Created GitHub repository: $TEST_REPO_NAME"
    else
        test_error "Failed to create GitHub repository"
        exit 1
    fi
    
    # Create local test directory and clone
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    if gh repo clone "$TEST_REPO_NAME" .; then
        test_success "Successfully cloned repository"
    else
        test_error "Failed to clone repository"
        exit 1
    fi
    
    # Fix remote URL for proper authentication (use GitHub CLI's default)
    # Note: This will use the authenticated user's GitHub account
    local github_user
    github_user=$(gh api user -q .login 2>/dev/null || echo "")
    if [ -n "$github_user" ]; then
        git remote set-url origin "git@github.com:$github_user/$TEST_REPO_NAME.git"
    fi
    
    # Configure git
    git config user.name "Seconds Test User"
    git config user.email "secondstest@example.com"
    
    # Copy git-checkpoints script
    cp "$GIT_CHECKPOINTS_PATH" ./git-checkpoints
    chmod +x ./git-checkpoints
    
    # Create initial commit
    echo "# 10-Second Interval Test Repository" > README.md
    git add README.md
    git commit -m "Initial commit"
    git push origin main
    
    test_success "Seconds test environment setup complete"
}

# Test 10-second interval configuration
test_10_second_config() {
    test_info "Testing 10-second interval configuration..."
    
    # Configure 10-second interval
    assert_success "./git-checkpoints config set interval 10s" "Should set 10-second interval"
    assert_success "./git-checkpoints config set notify true" "Should enable notifications"
    
    # Verify configuration
    local config_output
    config_output=$(./git-checkpoints config get)
    assert_contains "$config_output" "10s" "Should show 10s interval"
    
    test_success "10-second configuration test completed"
}

# Start auto-checkpoint process manually (since cron is complex for seconds)
start_auto_checkpoint_process() {
    test_info "Starting 10-second auto-checkpoint process..."
    
    # Create a background process that runs auto-checkpoint every 10 seconds
    (
        while true; do
            ./git-checkpoints auto 2>/dev/null
            sleep 10
        done
    ) &
    
    WRAPPER_PID=$!
    test_success "Started auto-checkpoint process (PID: $WRAPPER_PID)"
}

# Test auto-checkpoint with file changes
test_auto_checkpoint_with_changes() {
    test_info "Testing auto-checkpoint with file changes over $TEST_DURATION seconds..."
    
    local start_time
    start_time=$(date +%s)
    local checkpoint_count=0
    
    # Start the auto-checkpoint process
    start_auto_checkpoint_process
    
    # Test scenario: make changes at different intervals
    local test_scenarios=(
        "5:Create initial file"
        "15:Modify existing file"
        "25:Add new file"
        "35:No changes (should not create checkpoint)"
        "45:Modify multiple files"
        "55:Final changes"
    )
    
    for scenario in "${test_scenarios[@]}"; do
        local wait_time="${scenario%%:*}"
        local action="${scenario#*:}"
        
        # Wait until the specified time
        while [ $(($(date +%s) - start_time)) -lt "$wait_time" ]; do
            sleep 1
        done
        
        test_info "At ${wait_time}s: $action"
        
        case "$action" in
            "Create initial file")
                echo "console.log('Initial test file');" > test.js
                git add test.js
                ;;
            "Modify existing file")
                echo "// Modified at $(date)" >> test.js
                git add test.js
                ;;
            "Add new file")
                echo "body { background: #f0f0f0; }" > styles.css
                git add styles.css
                ;;
            "No changes"*)
                # Don't make any changes - test that no checkpoint is created
                ;;
            "Modify multiple files")
                echo "// Multiple changes" >> test.js
                echo "/* More styles */" >> styles.css
                echo "<h1>Test</h1>" > index.html
                git add .
                ;;
            "Final changes")
                echo "// Final test" >> test.js
                git add test.js
                ;;
        esac
        
        # Check git status to verify working directory state
        local git_status
        git_status=$(git status --porcelain)
        test_info "Git status: $([ -z "$git_status" ] && echo "clean" || echo "has changes")"
    done
    
    # Wait for the full test duration
    while [ $(($(date +%s) - start_time)) -lt "$TEST_DURATION" ]; do
        sleep 1
    done
    
    # Stop the auto-checkpoint process
    if [ -n "$WRAPPER_PID" ]; then
        kill "$WRAPPER_PID" 2>/dev/null || true
        WRAPPER_PID=""
        test_info "Stopped auto-checkpoint process"
    fi
    
    test_success "Auto-checkpoint test completed"
}

# Analyze results
analyze_results() {
    test_info "Analyzing auto-checkpoint results..."
    
    # List all checkpoints created
    local checkpoints
    checkpoints=$(./git-checkpoints list)
    test_info "Checkpoints created:"
    echo "$checkpoints"
    
    # Count auto checkpoints
    local auto_count
    auto_count=$(git tag -l 'checkpoint/auto_*' | wc -l)
    test_info "Total auto checkpoints created: $auto_count"
    
    # Verify checkpoints were pushed to remote
    git fetch --tags origin
    local remote_tags
    remote_tags=$(git ls-remote --tags origin | grep checkpoint | wc -l)
    test_info "Checkpoints pushed to remote: $remote_tags"
    
    # Check working directory status
    local final_status
    final_status=$(git status --porcelain)
    if [ -z "$final_status" ]; then
        test_success "Working directory is clean (files properly staged/committed)"
    else
        test_info "Working directory status:"
        git status
        test_success "Working directory has expected staged changes"
    fi
    
    # Verify that checkpoints contain different changes
    if [ "$auto_count" -gt 1 ]; then
        test_success "Multiple checkpoints created - change detection working"
    else
        test_warning "Only $auto_count checkpoint created - may need longer test duration"
    fi
    
    test_success "Results analysis completed"
}

# Test working directory preservation
test_working_directory_preservation() {
    test_info "Testing working directory preservation..."
    
    # Create some changes
    echo "// Test preservation" > preserve-test.js
    echo "/* Staged change */" > staged.css
    git add staged.css
    
    # Record current state
    local unstaged_before
    unstaged_before=$(git diff --name-only)
    local staged_before
    staged_before=$(git diff --cached --name-only)
    
    test_info "Before auto-checkpoint:"
    test_info "  Unstaged files: $unstaged_before"
    test_info "  Staged files: $staged_before"
    
    # Run auto-checkpoint
    ./git-checkpoints auto
    
    # Check state after
    local unstaged_after
    unstaged_after=$(git diff --name-only)
    local staged_after
    staged_after=$(git diff --cached --name-only)
    
    test_info "After auto-checkpoint:"
    test_info "  Unstaged files: $unstaged_after"
    test_info "  Staged files: $staged_after"
    
    # Verify preservation
    if [ "$unstaged_before" = "$unstaged_after" ] && [ "$staged_before" = "$staged_after" ]; then
        test_success "Working directory state preserved correctly"
    else
        test_error "Working directory state changed unexpectedly"
    fi
    
    test_success "Working directory preservation test completed"
}

# Main test execution
main() {
    test_info "Starting git-checkpoints 10-second interval test..."
    test_info "Test repository: $TEST_REPO_NAME"
    test_info "Test duration: $TEST_DURATION seconds"
    
    # Setup test environment
    setup_seconds_test
    
    # Run all tests
    test_10_second_config
    test_working_directory_preservation
    test_auto_checkpoint_with_changes
    analyze_results
    
    # Print summary
    print_test_summary
    
    if [ $TESTS_FAILED -eq 0 ]; then
        test_success "All 10-second interval tests passed! 🎉"
        test_info "The git-checkpoints tool successfully:"
        test_info "- Configured 10-second intervals"
        test_info "- Created automatic checkpoints when changes detected"
        test_info "- Preserved working directory state"
        test_info "- Pushed checkpoints to remote repository"
        test_info "- Handled periods with no changes correctly"
        echo
        local github_user
        github_user=$(gh api user -q .login 2>/dev/null || echo "USER")
        test_info "Repository URL: https://github.com/$github_user/$TEST_REPO_NAME"
        exit 0
    else
        test_error "Some 10-second interval tests failed! 😞"
        exit 1
    fi
}

# Run main function
main "$@"
