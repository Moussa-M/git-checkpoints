#!/usr/bin/env bash

# Test helper functions for git-checkpoints tests

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test output functions
test_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
test_success() { echo -e "${GREEN}[PASS]${NC} $*"; }
test_warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
test_error() { echo -e "${RED}[FAIL]${NC} $*"; }

# Test assertion functions
assert_success() {
    local cmd="$1"
    local description="${2:-Command should succeed}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$cmd" &>/dev/null; then
        test_success "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        test_error "$description"
        test_error "Command failed: $cmd"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_failure() {
    local cmd="$1"
    local description="${2:-Command should fail}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$cmd" &>/dev/null; then
        test_error "$description"
        test_error "Command unexpectedly succeeded: $cmd"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    else
        test_success "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi
}

assert_contains() {
    local output="$1"
    local expected="$2"
    local description="${3:-Output should contain expected text}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if echo "$output" | grep -q "$expected"; then
        test_success "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        test_error "$description"
        test_error "Expected to find: '$expected'"
        test_error "In output: '$output'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_contains() {
    local output="$1"
    local unexpected="$2"
    local description="${3:-Output should not contain text}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if echo "$output" | grep -q "$unexpected"; then
        test_error "$description"
        test_error "Unexpectedly found: '$unexpected'"
        test_error "In output: '$output'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    else
        test_success "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi
}

assert_file_exists() {
    local file="$1"
    local description="${2:-File should exist: $file}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ -f "$file" ]; then
        test_success "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        test_error "$description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local description="${2:-File should not exist: $file}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ ! -f "$file" ]; then
        test_success "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        test_error "$description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test environment setup
setup_test_repo() {
    local repo_name="${1:-test-repo-$(date +%s)}"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    cd "$temp_dir" || exit 1
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create initial commit
    echo "# Test Repository" > README.md
    git add README.md
    git commit --quiet -m "Initial commit"
    
    echo "$temp_dir"
}

cleanup_test_repo() {
    local repo_path="$1"
    if [ -n "$repo_path" ] && [ -d "$repo_path" ]; then
        rm -rf "$repo_path"
    fi
}

# GitHub repository helpers
create_github_repo() {
    local repo_name="$1"
    local description="${2:-Test repository for git-checkpoints}"
    
    if command -v gh &>/dev/null; then
        gh repo create "$repo_name" --public --description "$description" --clone=false
        return $?
    else
        test_error "GitHub CLI (gh) not available"
        return 1
    fi
}

delete_github_repo() {
    local repo_name="$1"
    
    if command -v gh &>/dev/null; then
        gh repo delete "$repo_name" --confirm
        return $?
    else
        test_error "GitHub CLI (gh) not available"
        return 1
    fi
}

# Test summary
print_test_summary() {
    echo
    echo "=================================="
    echo "Test Summary"
    echo "=================================="
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Utility functions
wait_for_file() {
    local file="$1"
    local timeout="${2:-10}"
    local count=0
    
    while [ $count -lt $timeout ]; do
        if [ -f "$file" ]; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    return 1
}

get_git_checkpoints_path() {
    # Try to find git-checkpoints script
    if command -v git-checkpoints &>/dev/null; then
        command -v git-checkpoints
    elif [ -f "../git-checkpoints" ]; then
        realpath "../git-checkpoints"
    elif [ -f "./git-checkpoints" ]; then
        realpath "./git-checkpoints"
    else
        test_error "git-checkpoints script not found"
        return 1
    fi
}

# Test data generators
create_test_files() {
    local count="${1:-3}"
    
    for i in $(seq 1 "$count"); do
        echo "Test file $i content" > "test_file_$i.txt"
    done
}

modify_test_files() {
    local count="${1:-3}"
    
    for i in $(seq 1 "$count"); do
        if [ -f "test_file_$i.txt" ]; then
            echo "Modified content $i" >> "test_file_$i.txt"
        fi
    done
}
