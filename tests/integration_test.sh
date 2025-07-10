#!/usr/bin/env bash

# Integration test for git-checkpoints
# This test creates a real GitHub repository and tests all functionality

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# Test configuration
TEST_REPO_PREFIX="${TEST_REPO_PREFIX:-git-checkpoints-test}"
TEST_REPO_NAME="$TEST_REPO_PREFIX-$(date +%s)"
SKIP_CLEANUP="${SKIP_CLEANUP:-0}"
VERBOSE="${VERBOSE:-0}"

# Global variables
ORIGINAL_DIR=""
TEST_DIR=""
GITHUB_REPO_CREATED=0
GIT_CHECKPOINTS_PATH=""

# Cleanup function
cleanup() {
    local exit_code=$?
    
    test_info "Cleaning up test environment..."
    
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
            test_warning "You may need to delete it manually"
        fi
    fi
    
    exit $exit_code
}

# Set up cleanup trap
trap cleanup EXIT

# Test setup
setup_integration_test() {
    test_info "Setting up integration test environment..."
    
    # Store original directory
    ORIGINAL_DIR="$(pwd)"
    
    # Find git-checkpoints script
    GIT_CHECKPOINTS_PATH=$(get_git_checkpoints_path)
    if [ $? -ne 0 ]; then
        test_error "Cannot find git-checkpoints script"
        exit 1
    fi
    test_info "Using git-checkpoints script: $GIT_CHECKPOINTS_PATH"
    
    # Check prerequisites
    if ! command -v gh &>/dev/null; then
        test_error "GitHub CLI (gh) is required but not installed"
        exit 1
    fi
    
    if ! gh auth status &>/dev/null; then
        test_error "GitHub CLI is not authenticated. Run 'gh auth login' first"
        exit 1
    fi
    
    # Create GitHub repository
    test_info "Creating GitHub repository: $TEST_REPO_NAME"
    if create_github_repo "$TEST_REPO_NAME" "Integration test repository for git-checkpoints"; then
        GITHUB_REPO_CREATED=1
        test_success "Created GitHub repository: $TEST_REPO_NAME"
    else
        test_error "Failed to create GitHub repository"
        exit 1
    fi
    
    # Create local test directory and clone
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    test_info "Cloning repository to: $TEST_DIR"
    if gh repo clone "$TEST_REPO_NAME" .; then
        test_success "Successfully cloned repository"
    else
        test_error "Failed to clone repository"
        exit 1
    fi
    
    # Configure git
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Copy git-checkpoints script to test directory for easy access
    cp "$GIT_CHECKPOINTS_PATH" ./git-checkpoints
    chmod +x ./git-checkpoints
    
    test_success "Integration test environment setup complete"
}

# Test basic checkpoint operations
test_basic_operations() {
    test_info "Testing basic checkpoint operations..."
    
    # Test version command
    local version_output
    version_output=$(./git-checkpoints version)
    assert_contains "$version_output" "2.1.0" "Version command should return correct version"
    
    # Test help command
    local help_output
    help_output=$(./git-checkpoints help)
    assert_contains "$help_output" "Usage:" "Help command should show usage information"
    
    # Test list with no checkpoints
    local list_output
    list_output=$(./git-checkpoints list 2>&1)
    assert_contains "$list_output" "No checkpoints found" "Should show no checkpoints initially"
    
    # Create some test files
    create_test_files 3
    git add .
    
    # Test creating a checkpoint
    assert_success "./git-checkpoints create test-checkpoint-1" "Should create first checkpoint"
    
    # Verify checkpoint was created
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "test-checkpoint-1" "Should list the created checkpoint"
    
    # Verify git tag was created
    assert_success "git tag -l | grep -q 'checkpoint/test-checkpoint-1'" "Git tag should be created"
    
    test_success "Basic operations test completed"
}

# Test checkpoint with changes
test_checkpoint_with_changes() {
    test_info "Testing checkpoint creation with various changes..."
    
    # Modify existing files
    modify_test_files 3
    
    # Add new file
    echo "New file content" > new_file.txt
    
    # Stage some changes
    git add test_file_1.txt new_file.txt
    
    # Create checkpoint with mixed staged/unstaged changes
    assert_success "./git-checkpoints create mixed-changes" "Should create checkpoint with mixed changes"
    
    # Verify checkpoint exists
    local list_output
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "mixed-changes" "Should list mixed-changes checkpoint"
    
    # Verify working directory is unchanged
    assert_file_exists "new_file.txt" "New file should still exist in working directory"
    assert_success "git diff --quiet test_file_2.txt test_file_3.txt" "Unstaged changes should remain"
    
    test_success "Checkpoint with changes test completed"
}

# Test loading checkpoints
test_load_checkpoint() {
    test_info "Testing checkpoint loading..."
    
    # Clean working directory
    git reset --hard HEAD
    git clean -fd
    
    # Verify files are gone
    assert_file_not_exists "new_file.txt" "New file should be removed after reset"
    
    # Load the mixed-changes checkpoint
    echo "y" | ./git-checkpoints load mixed-changes
    
    # Verify changes were applied
    assert_file_exists "new_file.txt" "New file should be restored after loading checkpoint"
    
    # Verify file modifications
    local file_content
    file_content=$(cat test_file_1.txt)
    assert_contains "$file_content" "Modified content" "File should contain modified content"
    
    test_success "Load checkpoint test completed"
}

# Test auto-checkpoint functionality
test_auto_checkpoint() {
    test_info "Testing auto-checkpoint functionality..."
    
    # Clean working directory first
    git reset --hard HEAD
    git clean -fd
    
    # Create new changes
    echo "Auto checkpoint test" > auto_test.txt
    git add auto_test.txt
    
    # Test auto command
    assert_success "./git-checkpoints auto" "Auto checkpoint should succeed with changes"
    
    # Verify auto checkpoint was created
    local list_output
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "auto_" "Should create auto-named checkpoint"
    
    # Test auto with no changes
    local auto_output
    auto_output=$(./git-checkpoints auto 2>&1)
    assert_contains "$auto_output" "No changes detected" "Should detect no changes"
    
    test_success "Auto checkpoint test completed"
}

# Test configuration management
test_configuration() {
    test_info "Testing configuration management..."
    
    # Test getting default config
    local config_output
    config_output=$(./git-checkpoints config get)
    assert_contains "$config_output" "interval:" "Should show interval configuration"
    assert_contains "$config_output" "notify:" "Should show notify configuration"
    
    # Test setting configuration
    assert_success "./git-checkpoints config set interval 10" "Should set interval config"
    assert_success "./git-checkpoints config set notify true" "Should set notify config"
    
    # Verify configuration was set
    local interval_value
    interval_value=$(./git-checkpoints config get interval)
    assert_contains "$interval_value" "10" "Should return set interval value"
    
    local notify_value
    notify_value=$(./git-checkpoints config get notify)
    assert_contains "$notify_value" "true" "Should return set notify value"
    
    test_success "Configuration test completed"
}

# Test remote operations
test_remote_operations() {
    test_info "Testing remote repository operations..."
    
    # Create a checkpoint that should be pushed to remote
    echo "Remote test content" > remote_test.txt
    git add remote_test.txt
    
    assert_success "./git-checkpoints create remote-test" "Should create checkpoint for remote test"
    
    # Verify tag was pushed to remote
    sleep 2  # Give some time for push to complete
    
    # Fetch tags from remote to verify
    git fetch --tags origin
    
    # Check if tag exists on remote
    local remote_tags
    remote_tags=$(git ls-remote --tags origin)
    assert_contains "$remote_tags" "checkpoint/remote-test" "Checkpoint tag should be pushed to remote"
    
    test_success "Remote operations test completed"
}

# Test deletion operations
test_delete_operations() {
    test_info "Testing checkpoint deletion..."
    
    # Test deleting a specific checkpoint
    assert_success "./git-checkpoints delete test-checkpoint-1" "Should delete specific checkpoint"
    
    # Verify checkpoint was deleted locally
    local list_output
    list_output=$(./git-checkpoints list)
    assert_not_contains "$list_output" "test-checkpoint-1" "Deleted checkpoint should not appear in list"
    
    # Verify tag was deleted locally
    assert_failure "git tag -l | grep -q 'checkpoint/test-checkpoint-1'" "Git tag should be deleted locally"
    
    # Create a test checkpoint for bulk deletion
    echo "Delete test" > delete_test.txt
    git add delete_test.txt
    ./git-checkpoints create delete-me
    
    # Test deleting all checkpoints
    echo "y" | ./git-checkpoints delete "*"
    
    # Verify all checkpoints were deleted
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "No checkpoints found" "All checkpoints should be deleted"
    
    test_success "Delete operations test completed"
}

# Test error handling
test_error_handling() {
    test_info "Testing error handling..."
    
    # Test loading non-existent checkpoint
    assert_failure "./git-checkpoints load non-existent" "Should fail to load non-existent checkpoint"
    
    # Test deleting non-existent checkpoint
    assert_failure "./git-checkpoints delete non-existent" "Should fail to delete non-existent checkpoint"
    
    # Test creating checkpoint with no changes
    git reset --hard HEAD
    git clean -fd
    local no_changes_output
    no_changes_output=$(./git-checkpoints create no-changes 2>&1)
    assert_contains "$no_changes_output" "No changes to checkpoint" "Should handle no changes gracefully"
    
    # Test invalid config key
    assert_failure "./git-checkpoints config set invalid-key value" "Should fail with invalid config key"
    
    test_success "Error handling test completed"
}

# Main test execution
main() {
    test_info "Starting git-checkpoints integration test..."
    test_info "Test repository: $TEST_REPO_NAME"
    
    # Setup test environment
    setup_integration_test
    
    # Run all tests
    test_basic_operations
    test_checkpoint_with_changes
    test_load_checkpoint
    test_auto_checkpoint
    test_configuration
    test_remote_operations
    test_delete_operations
    test_error_handling
    
    # Print summary
    print_test_summary
    
    if [ $TESTS_FAILED -eq 0 ]; then
        test_success "All integration tests passed! 🎉"
        exit 0
    else
        test_error "Some integration tests failed! 😞"
        exit 1
    fi
}

# Run main function
main "$@"
