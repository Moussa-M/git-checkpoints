#!/usr/bin/env bash

# Basic workflow test for git-checkpoints
# Tests a typical user workflow from start to finish

set -euo pipefail

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test_helpers.sh"

# Global variables
ORIGINAL_DIR=""
TEST_DIR=""
GIT_CHECKPOINTS_PATH=""

# Cleanup function
cleanup() {
    local exit_code=$?
    
    test_info "Cleaning up basic workflow test..."
    
    if [ -n "$ORIGINAL_DIR" ]; then
        cd "$ORIGINAL_DIR"
    fi
    
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
    
    exit $exit_code
}

trap cleanup EXIT

# Test setup
setup_workflow_test() {
    test_info "Setting up basic workflow test..."
    
    ORIGINAL_DIR="$(pwd)"
    GIT_CHECKPOINTS_PATH=$(get_git_checkpoints_path)
    
    if [ $? -ne 0 ]; then
        test_error "Cannot find git-checkpoints script"
        exit 1
    fi
    
    TEST_DIR=$(setup_test_repo)
    cd "$TEST_DIR"
    
    cp "$GIT_CHECKPOINTS_PATH" ./git-checkpoints
    chmod +x ./git-checkpoints
    
    test_success "Basic workflow test setup complete"
}

# Simulate a typical development workflow
test_development_workflow() {
    test_info "Testing typical development workflow..."
    
    # Step 1: Start working on a feature
    test_info "Step 1: Starting feature development..."
    echo "function calculateSum(a, b) {" > calculator.js
    echo "  return a + b;" >> calculator.js
    echo "}" >> calculator.js
    
    # Create first checkpoint
    assert_success "./git-checkpoints create feature-start" "Should create initial feature checkpoint"
    
    # Step 2: Add more functionality
    test_info "Step 2: Adding more functionality..."
    echo "" >> calculator.js
    echo "function calculateProduct(a, b) {" >> calculator.js
    echo "  return a * b;" >> calculator.js
    echo "}" >> calculator.js
    
    # Create second checkpoint
    assert_success "./git-checkpoints create added-multiply" "Should create checkpoint after adding multiply"
    
    # Step 3: Add tests
    test_info "Step 3: Adding tests..."
    echo "// Test cases" > tests.js
    echo "console.log('Testing sum:', calculateSum(2, 3));" >> tests.js
    echo "console.log('Testing product:', calculateProduct(4, 5));" >> tests.js
    
    # Stage some files
    git add tests.js
    
    # Create checkpoint with mixed changes
    assert_success "./git-checkpoints create added-tests" "Should create checkpoint with tests"
    
    # Step 4: Experiment with a risky change
    test_info "Step 4: Making experimental changes..."
    echo "// EXPERIMENTAL: Division function" >> calculator.js
    echo "function calculateDivision(a, b) {" >> calculator.js
    echo "  if (b === 0) throw new Error('Division by zero');" >> calculator.js
    echo "  return a / b;" >> calculator.js
    echo "}" >> calculator.js
    
    # Create experimental checkpoint
    assert_success "./git-checkpoints create experimental-division" "Should create experimental checkpoint"
    
    # Step 5: Realize the experiment broke something, revert to previous state
    test_info "Step 5: Reverting experimental changes..."
    git reset --hard HEAD
    git clean -fd
    
    # Load the checkpoint before the experiment
    echo "y" | ./git-checkpoints load added-tests
    
    # Verify we're back to the right state
    assert_file_exists "tests.js" "Tests file should be restored"
    assert_file_exists "calculator.js" "Calculator file should be restored"
    
    local calc_content
    calc_content=$(cat calculator.js)
    assert_contains "$calc_content" "calculateProduct" "Should have multiply function"
    assert_not_contains "$calc_content" "calculateDivision" "Should not have experimental division function"
    
    # Step 6: Continue development with a safer approach
    test_info "Step 6: Continuing with safer approach..."
    echo "" >> calculator.js
    echo "function calculateDifference(a, b) {" >> calculator.js
    echo "  return a - b;" >> calculator.js
    echo "}" >> calculator.js
    
    # Add test for new function
    echo "console.log('Testing difference:', calculateDifference(10, 3));" >> tests.js
    
    # Create final checkpoint
    assert_success "./git-checkpoints create added-subtraction" "Should create final checkpoint"
    
    # Step 7: Review all checkpoints
    test_info "Step 7: Reviewing development history..."
    local list_output
    list_output=$(./git-checkpoints list)
    assert_contains "$list_output" "feature-start" "Should list initial checkpoint"
    assert_contains "$list_output" "added-multiply" "Should list multiply checkpoint"
    assert_contains "$list_output" "added-tests" "Should list tests checkpoint"
    assert_contains "$list_output" "experimental-division" "Should list experimental checkpoint"
    assert_contains "$list_output" "added-subtraction" "Should list final checkpoint"
    
    test_success "Development workflow test completed"
}

# Test checkpoint comparison workflow
test_checkpoint_comparison() {
    test_info "Testing checkpoint comparison workflow..."
    
    # Clean workspace
    git reset --hard HEAD
    git clean -fd
    
    # Load different checkpoints and compare
    echo "y" | ./git-checkpoints load feature-start
    local initial_files
    initial_files=$(ls -la)
    
    echo "y" | ./git-checkpoints load added-subtraction
    local final_files
    final_files=$(ls -la)
    
    # Verify progression
    assert_file_exists "calculator.js" "Calculator should exist in final state"
    assert_file_exists "tests.js" "Tests should exist in final state"
    
    local final_calc_content
    final_calc_content=$(cat calculator.js)
    assert_contains "$final_calc_content" "calculateSum" "Should have sum function"
    assert_contains "$final_calc_content" "calculateProduct" "Should have product function"
    assert_contains "$final_calc_content" "calculateDifference" "Should have difference function"
    
    test_success "Checkpoint comparison test completed"
}

# Test cleanup workflow
test_cleanup_workflow() {
    test_info "Testing cleanup workflow..."
    
    # Delete experimental checkpoint
    assert_success "./git-checkpoints delete experimental-division" "Should delete experimental checkpoint"
    
    # Verify it's gone
    local list_output
    list_output=$(./git-checkpoints list)
    assert_not_contains "$list_output" "experimental-division" "Experimental checkpoint should be deleted"
    
    # Keep important checkpoints
    assert_contains "$list_output" "feature-start" "Should keep feature-start checkpoint"
    assert_contains "$list_output" "added-subtraction" "Should keep final checkpoint"
    
    test_success "Cleanup workflow test completed"
}

# Main test execution
main() {
    test_info "Starting basic workflow test..."
    
    setup_workflow_test
    test_development_workflow
    test_checkpoint_comparison
    test_cleanup_workflow
    
    print_test_summary
    
    if [ $TESTS_FAILED -eq 0 ]; then
        test_success "Basic workflow test passed! 🎉"
        exit 0
    else
        test_error "Basic workflow test failed! 😞"
        exit 1
    fi
}

main "$@"
