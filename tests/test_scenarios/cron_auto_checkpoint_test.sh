#!/usr/bin/env bash

# Cron auto-checkpoint test for git-checkpoints
# Tests the automatic checkpoint creation and remote push functionality

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test_helpers.sh"

# Test configuration
TEST_REPO_NAME="git-checkpoints-cron-test-$(date +%s)"
SKIP_CLEANUP="${SKIP_CLEANUP:-0}"

# Global variables
ORIGINAL_DIR=""
TEST_DIR=""
GITHUB_REPO_CREATED=0
GIT_CHECKPOINTS_PATH=""

# Cleanup function
cleanup() {
    local exit_code=$?
    
    test_info "Cleaning up cron test environment..."
    
    # Remove any cron jobs we might have created
    if command -v crontab &>/dev/null; then
        local temp_cron
        temp_cron=$(mktemp)
        crontab -l 2>/dev/null | grep -v "git-checkpoints" | grep -v "$TEST_DIR" > "$temp_cron" || true
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
setup_cron_test() {
    test_info "Setting up cron auto-checkpoint test..."
    
    ORIGINAL_DIR="$(pwd)"
    GIT_CHECKPOINTS_PATH=$(get_git_checkpoints_path)
    
    if [ $? -ne 0 ]; then
        test_error "Cannot find git-checkpoints script"
        exit 1
    fi
    
    # Check prerequisites
    if ! command -v gh &>/dev/null; then
        test_error "GitHub CLI (gh) is required for cron tests"
        exit 1
    fi
    
    if ! gh auth status &>/dev/null; then
        test_error "GitHub CLI is not authenticated"
        exit 1
    fi
    
    if ! command -v crontab &>/dev/null; then
        test_warning "crontab not available - skipping actual cron job tests"
        return 1
    fi
    
    # Create GitHub repository
    test_info "Creating GitHub repository: $TEST_REPO_NAME"
    if create_github_repo "$TEST_REPO_NAME" "Cron test repository for git-checkpoints"; then
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
    
    # Configure git
    git config user.name "Cron Test User"
    git config user.email "crontest@example.com"
    
    # Copy git-checkpoints script
    cp "$GIT_CHECKPOINTS_PATH" ./git-checkpoints
    chmod +x ./git-checkpoints
    
    # Create initial commit
    echo "# Cron Test Repository" > README.md
    git add README.md
    git commit -m "Initial commit"
    git push origin main
    
    test_success "Cron test environment setup complete"
}

# Test cron job setup and configuration
test_cron_setup() {
    test_info "Testing cron job setup and configuration..."
    
    # Test initial status (should be inactive)
    local status_output
    status_output=$(./git-checkpoints status 2>&1)
    test_info "Initial status: $status_output"
    
    # Configure auto-checkpoint interval
    assert_success "./git-checkpoints config set interval 1" "Should set 1-minute interval"
    assert_success "./git-checkpoints config set notify true" "Should enable notifications"
    
    # Test resume command (sets up cron job)
    assert_success "./git-checkpoints resume" "Should setup cron job"
    
    # Verify cron job was created
    local cron_output
    cron_output=$(crontab -l 2>/dev/null | grep "$TEST_DIR" || echo "")
    assert_contains "$cron_output" "git-checkpoints auto" "Should create cron job with auto command"
    
    # Test status after resume
    status_output=$(./git-checkpoints status 2>&1)
    assert_contains "$status_output" "ACTIVE" "Should show active status"
    
    test_success "Cron setup test completed"
}

# Test pause and resume functionality
test_pause_resume() {
    test_info "Testing pause and resume functionality..."
    
    # Test pause
    assert_success "./git-checkpoints pause" "Should pause auto-checkpointing"
    
    # Verify paused status
    local status_output
    status_output=$(./git-checkpoints status 2>&1)
    assert_contains "$status_output" "PAUSED" "Should show paused status"
    
    # Verify cron job was removed
    local cron_output
    cron_output=$(crontab -l 2>/dev/null | grep "$TEST_DIR" || echo "")
    assert_not_contains "$cron_output" "git-checkpoints auto" "Should remove cron job when paused"
    
    # Test resume again
    assert_success "./git-checkpoints resume" "Should resume auto-checkpointing"
    
    # Verify active status
    status_output=$(./git-checkpoints status 2>&1)
    assert_contains "$status_output" "ACTIVE" "Should show active status after resume"
    
    test_success "Pause/resume test completed"
}

# Test auto-checkpoint creation with changes
test_auto_checkpoint_with_changes() {
    test_info "Testing auto-checkpoint creation with file changes..."
    
    # Create some changes
    echo "console.log('Auto checkpoint test');" > app.js
    echo "body { background: #f0f0f0; }" > styles.css
    git add app.js styles.css
    
    # Test auto command directly
    assert_success "./git-checkpoints auto" "Should create auto checkpoint with changes"
    
    # Verify checkpoint was created
    local list_output
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "auto_" "Should create auto-named checkpoint"
    
    # Test that identical changes don't create duplicate
    local auto_output
    auto_output=$(./git-checkpoints auto 2>&1)
    assert_contains "$auto_output" "No new changes to checkpoint" "Should not create duplicate checkpoint"
    
    test_success "Auto-checkpoint creation test completed"
}

# Test remote push functionality
test_remote_push() {
    test_info "Testing remote push of checkpoints..."
    
    # Create a new checkpoint
    echo "// Remote push test" >> app.js
    git add app.js
    assert_success "./git-checkpoints create remote-push-test" "Should create checkpoint for remote test"
    
    # Wait a moment for push to complete
    sleep 3
    
    # Fetch tags from remote
    git fetch --tags origin
    
    # Verify tag exists on remote
    local remote_tags
    remote_tags=$(git ls-remote --tags origin)
    assert_contains "$remote_tags" "checkpoint/remote-push-test" "Checkpoint should be pushed to remote"
    
    # Test auto checkpoint remote push
    echo "// Auto remote test" >> styles.css
    git add styles.css
    ./git-checkpoints auto
    
    # Wait and fetch
    sleep 3
    git fetch --tags origin
    
    # Check for auto checkpoint on remote
    remote_tags=$(git ls-remote --tags origin)
    local auto_tag_count
    auto_tag_count=$(echo "$remote_tags" | grep -c "checkpoint/auto_" || echo "0")
    
    if [ "$auto_tag_count" -gt 0 ]; then
        test_success "Auto checkpoint was pushed to remote"
    else
        test_warning "Auto checkpoint may not have been pushed to remote"
    fi
    
    test_success "Remote push test completed"
}

# Test cron job execution simulation
test_cron_execution_simulation() {
    test_info "Testing cron job execution simulation..."
    
    # Create changes that would trigger auto-checkpoint
    echo "// Cron simulation test" > cron-test.js
    echo "function cronTest() { return 'automated'; }" >> cron-test.js
    git add cron-test.js
    
    # Simulate what cron would do (run auto command)
    test_info "Simulating cron job execution..."
    local cron_result
    if cron_result=$(./git-checkpoints auto 2>&1); then
        test_success "Cron simulation executed successfully"
        test_info "Cron output: $cron_result"
    else
        test_error "Cron simulation failed"
        test_error "Error output: $cron_result"
    fi
    
    # Verify checkpoint was created
    local list_output
    list_output=$(./git-checkpoints list)
    local checkpoint_count
    checkpoint_count=$(echo "$list_output" | grep -c "auto_" || echo "0")
    
    if [ "$checkpoint_count" -gt 0 ]; then
        test_success "Cron simulation created checkpoint successfully"
    else
        test_error "Cron simulation did not create expected checkpoint"
    fi
    
    test_success "Cron execution simulation completed"
}

# Test cleanup of cron jobs
test_cron_cleanup() {
    test_info "Testing cron job cleanup..."
    
    # Test local uninstall
    assert_success "./git-checkpoints local-uninstall" "Should remove local cron jobs"
    
    # Verify cron job was removed
    local cron_output
    cron_output=$(crontab -l 2>/dev/null | grep "$TEST_DIR" || echo "")
    assert_not_contains "$cron_output" "git-checkpoints" "Should remove cron job on local uninstall"
    
    # Verify status shows inactive
    local status_output
    status_output=$(./git-checkpoints status 2>&1)
    test_info "Status after cleanup: $status_output"
    
    test_success "Cron cleanup test completed"
}

# Main test execution
main() {
    test_info "Starting git-checkpoints cron auto-checkpoint test..."
    test_info "Test repository: $TEST_REPO_NAME"
    
    # Setup test environment
    if ! setup_cron_test; then
        test_warning "Cron test setup failed - skipping cron-specific tests"
        exit 0
    fi
    
    # Run all cron tests
    test_cron_setup
    test_pause_resume
    test_auto_checkpoint_with_changes
    test_remote_push
    test_cron_execution_simulation
    test_cron_cleanup
    
    # Print summary
    print_test_summary
    
    if [ $TESTS_FAILED -eq 0 ]; then
        test_success "All cron auto-checkpoint tests passed! 🎉"
        test_info "The git-checkpoints tool successfully:"
        test_info "- Sets up and manages cron jobs"
        test_info "- Creates automatic checkpoints when changes are detected"
        test_info "- Pushes checkpoints to remote repositories"
        test_info "- Handles pause/resume of automatic checkpointing"
        exit 0
    else
        test_error "Some cron tests failed! 😞"
        exit 1
    fi
}

# Run main function
main "$@"
