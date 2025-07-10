#!/usr/bin/env bash

# Unit tests for git-checkpoints
# These tests focus on individual functions and don't require GitHub integration

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# Global variables
ORIGINAL_DIR=""
TEST_DIR=""
GIT_CHECKPOINTS_PATH=""

# Cleanup function
cleanup() {
    local exit_code=$?
    
    test_info "Cleaning up unit test environment..."
    
    # Return to original directory
    if [ -n "$ORIGINAL_DIR" ]; then
        cd "$ORIGINAL_DIR"
    fi
    
    # Clean up local test directory
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
        test_info "Removed local test directory: $TEST_DIR"
    fi
    
    exit $exit_code
}

# Set up cleanup trap
trap cleanup EXIT

# Test setup
setup_unit_test() {
    test_info "Setting up unit test environment..."
    
    # Store original directory
    ORIGINAL_DIR="$(pwd)"
    
    # Find git-checkpoints script
    GIT_CHECKPOINTS_PATH=$(get_git_checkpoints_path)
    if [ $? -ne 0 ]; then
        test_error "Cannot find git-checkpoints script"
        exit 1
    fi
    test_info "Using git-checkpoints script: $GIT_CHECKPOINTS_PATH"
    
    # Create local test repository
    TEST_DIR=$(setup_test_repo)
    cd "$TEST_DIR"
    
    # Copy git-checkpoints script to test directory
    cp "$GIT_CHECKPOINTS_PATH" ./git-checkpoints
    chmod +x ./git-checkpoints
    
    test_success "Unit test environment setup complete"
}

# Test version and help commands
test_version_and_help() {
    test_info "Testing version and help commands..."
    
    # Test version command
    local version_output
    version_output=$(./git-checkpoints version)
    assert_contains "$version_output" "2.1.0" "Version should be 2.1.0"
    
    # Test help command
    local help_output
    help_output=$(./git-checkpoints help)
    assert_contains "$help_output" "Usage:" "Help should contain usage information"
    assert_contains "$help_output" "create" "Help should mention create command"
    assert_contains "$help_output" "list" "Help should mention list command"
    assert_contains "$help_output" "load" "Help should mention load command"
    assert_contains "$help_output" "delete" "Help should mention delete command"
    
    test_success "Version and help commands test completed"
}

# Test checkpoint creation
test_checkpoint_creation() {
    test_info "Testing checkpoint creation..."
    
    # Test with no changes
    local no_changes_output
    no_changes_output=$(./git-checkpoints create test-empty 2>&1)
    assert_contains "$no_changes_output" "No changes to save" "Should handle no changes"
    
    # Create test files
    create_test_files 2
    
    # Test with unstaged changes only
    assert_success "./git-checkpoints create unstaged-test" "Should create checkpoint with unstaged changes"
    
    # Verify checkpoint was created
    local list_output
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "unstaged-test" "Should list created checkpoint"
    
    # Test with staged changes
    git add test_file_1.txt
    assert_success "./git-checkpoints create staged-test" "Should create checkpoint with staged changes"
    
    # Test with mixed changes
    modify_test_files 2
    echo "New file" > new_file.txt
    git add new_file.txt
    assert_success "./git-checkpoints create mixed-test" "Should create checkpoint with mixed changes"
    
    # Test auto-naming
    echo "Auto test" > auto_file.txt
    assert_success "./git-checkpoints create" "Should create checkpoint with auto name"
    
    # Verify auto-named checkpoint
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "auto_" "Should create auto-named checkpoint"
    
    test_success "Checkpoint creation test completed"
}

# Test checkpoint listing
test_checkpoint_listing() {
    test_info "Testing checkpoint listing..."
    
    # Test list command output format
    local list_output
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "Available checkpoints" "Should show header"
    assert_contains "$list_output" "unstaged-test" "Should list unstaged-test"
    assert_contains "$list_output" "staged-test" "Should list staged-test"
    assert_contains "$list_output" "mixed-test" "Should list mixed-test"
    
    # Test list alias
    local ls_output
    ls_output=$(./git-checkpoints ls)
    assert_contains "$ls_output" "Available checkpoints" "ls alias should work"
    
    test_success "Checkpoint listing test completed"
}

# Test checkpoint loading
test_checkpoint_loading() {
    test_info "Testing checkpoint loading..."
    
    # Clean working directory
    git reset --hard HEAD
    git clean -fd
    
    # Verify files are gone
    assert_file_not_exists "test_file_1.txt" "Test files should be removed"
    assert_file_not_exists "new_file.txt" "New file should be removed"
    
    # Load a checkpoint (auto-answer yes)
    echo "y" | ./git-checkpoints load mixed-test
    
    # Verify files were restored
    assert_file_exists "test_file_1.txt" "Test file should be restored"
    assert_file_exists "new_file.txt" "New file should be restored"
    
    # Test loading non-existent checkpoint
    assert_failure "echo 'y' | ./git-checkpoints load non-existent" "Should fail to load non-existent checkpoint"
    
    # Test load alias
    git reset --hard HEAD
    git clean -fd
    echo "y" | ./git-checkpoints apply staged-test
    assert_file_exists "test_file_1.txt" "Apply alias should work"
    
    test_success "Checkpoint loading test completed"
}

# Test checkpoint deletion
test_checkpoint_deletion() {
    test_info "Testing checkpoint deletion..."
    
    # Test deleting specific checkpoint
    assert_success "./git-checkpoints delete unstaged-test" "Should delete specific checkpoint"
    
    # Verify checkpoint was deleted
    local list_output
    list_output=$(./git-checkpoints list)
    assert_not_contains "$list_output" "unstaged-test" "Deleted checkpoint should not appear"
    
    # Test deleting non-existent checkpoint
    assert_failure "./git-checkpoints delete non-existent" "Should fail to delete non-existent checkpoint"
    
    # Create a test checkpoint for bulk deletion
    echo "Delete me" > delete_test.txt
    git add delete_test.txt
    ./git-checkpoints create delete-me
    
    # Test deleting all checkpoints
    echo "y" | ./git-checkpoints delete "*"
    
    # Verify all checkpoints were deleted
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "No checkpoints found" "All checkpoints should be deleted"
    
    # Test rm alias
    echo "Another test" > another_test.txt
    git add another_test.txt
    ./git-checkpoints create rm-test
    assert_success "./git-checkpoints rm rm-test" "rm alias should work"
    
    test_success "Checkpoint deletion test completed"
}

# Test auto-checkpoint functionality
test_auto_checkpoint() {
    test_info "Testing auto-checkpoint functionality..."
    
    # Test auto with no changes
    local auto_output
    auto_output=$(./git-checkpoints auto 2>&1)
    assert_contains "$auto_output" "No changes detected" "Should detect no changes"
    
    # Create changes and test auto
    echo "Auto test content" > auto_test.txt
    git add auto_test.txt
    
    assert_success "./git-checkpoints auto" "Auto should create checkpoint with changes"
    
    # Verify auto checkpoint was created
    local list_output
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "auto_" "Should create auto-named checkpoint"
    
    # Test auto with identical changes (should not create duplicate)
    auto_output=$(./git-checkpoints auto 2>&1)
    assert_contains "$auto_output" "No new changes to checkpoint" "Should not create duplicate checkpoint"
    
    test_success "Auto checkpoint test completed"
}

# Test configuration management
test_configuration() {
    test_info "Testing configuration management..."
    
    # Test default configuration
    local config_output
    config_output=$(./git-checkpoints config get)
    assert_contains "$config_output" "interval: 5 minutes" "Should show default interval"
    assert_contains "$config_output" "notify:   false" "Should show default notify setting"
    
    # Test setting individual config values
    assert_success "./git-checkpoints config set interval 15" "Should set interval"
    assert_success "./git-checkpoints config set notify true" "Should set notify"
    
    # Test getting individual config values
    local interval_value
    interval_value=$(./git-checkpoints config get interval)
    assert_contains "$interval_value" "15" "Should return set interval value"
    
    local notify_value
    notify_value=$(./git-checkpoints config get notify)
    assert_contains "$notify_value" "true" "Should return set notify value"
    
    # Test invalid config operations
    assert_failure "./git-checkpoints config set invalid-key value" "Should fail with invalid key"
    assert_failure "./git-checkpoints config set" "Should fail with missing parameters"
    assert_failure "./git-checkpoints config invalid-action" "Should fail with invalid action"
    
    test_success "Configuration test completed"
}

# Test error handling and edge cases
test_error_handling() {
    test_info "Testing error handling and edge cases..."
    
    # Test invalid commands
    assert_failure "./git-checkpoints invalid-command" "Should fail with invalid command"
    
    # Test checkpoint name sanitization
    echo "Sanitize test" > sanitize.txt
    git add sanitize.txt
    assert_success "./git-checkpoints create 'test with spaces!@#'" "Should sanitize checkpoint name"
    
    # Verify sanitized name
    local list_output
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "test_with_spaces___" "Should sanitize special characters"
    
    # Test duplicate checkpoint names
    echo "Duplicate test" > duplicate.txt
    git add duplicate.txt
    assert_failure "./git-checkpoints create 'test with spaces!@#'" "Should fail with duplicate name"
    
    # Test operations outside git repository
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    cp "$TEST_DIR/git-checkpoints" ./
    
    assert_failure "./git-checkpoints create test" "Should fail outside git repository"
    assert_failure "./git-checkpoints list" "Should fail outside git repository"
    
    # Return to test directory
    cd "$TEST_DIR"
    rm -rf "$temp_dir"
    
    test_success "Error handling test completed"
}

# Test cron-related functionality (without actually setting up cron)
test_cron_functionality() {
    test_info "Testing cron-related functionality..."
    
    # Test status command
    local status_output
    status_output=$(./git-checkpoints status 2>&1)
    assert_contains "$status_output" "Auto-checkpointing" "Should show auto-checkpoint status"
    
    # Test pause command (should work even without active cron)
    assert_success "./git-checkpoints pause" "Should pause auto-checkpointing"
    
    # Verify paused status
    status_output=$(./git-checkpoints status 2>&1)
    assert_contains "$status_output" "PAUSED" "Should show paused status"
    
    # Test resume command (may fail if crontab not available, but should not crash)
    ./git-checkpoints resume 2>/dev/null || true
    
    test_success "Cron functionality test completed"
}

# Main test execution
main() {
    test_info "Starting git-checkpoints unit tests..."
    
    # Setup test environment
    setup_unit_test
    
    # Run all tests
    test_version_and_help
    test_checkpoint_creation
    test_checkpoint_listing
    test_checkpoint_loading
    test_checkpoint_deletion
    test_auto_checkpoint
    test_configuration
    test_error_handling
    test_cron_functionality
    
    # Print summary
    print_test_summary
    
    if [ $TESTS_FAILED -eq 0 ]; then
        test_success "All unit tests passed! 🎉"
        exit 0
    else
        test_error "Some unit tests failed! 😞"
        exit 1
    fi
}

# Run main function
main "$@"
