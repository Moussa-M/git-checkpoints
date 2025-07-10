# Git Checkpoints Test Suite

This test suite provides comprehensive testing for the git-checkpoints tool, including real integration tests with GitHub repositories.

## Test Structure

- `integration_test.sh` - Main integration test that creates a real GitHub repo and tests all functionality
- `unit_tests.sh` - Unit tests for individual functions
- `test_helpers.sh` - Helper functions shared across tests
- `test_scenarios/` - Directory containing various test scenarios
- `fixtures/` - Test data and sample files

## Running Tests

### Prerequisites

1. GitHub CLI (`gh`) installed and authenticated
2. Git configured with user name and email
3. The git-checkpoints script available in PATH or current directory

### Run All Tests

```bash
cd tests
./run_all_tests.sh
```

### Run Individual Tests

```bash
# Integration tests (creates real GitHub repo)
./integration_test.sh

# Unit tests only
./unit_tests.sh

# Specific scenario
./test_scenarios/basic_workflow_test.sh
```

## Test Coverage

- ✅ Basic checkpoint creation and listing
- ✅ Loading and applying checkpoints
- ✅ Deleting checkpoints (single and all)
- ✅ Auto-checkpoint functionality
- ✅ Configuration management
- ✅ Remote repository operations
- ✅ Error handling and edge cases
- ✅ Cron job management
- ✅ Notification system
- ✅ Cross-platform compatibility

## Environment Variables

- `GITHUB_TOKEN` - GitHub personal access token (optional, uses gh auth if available)
- `TEST_REPO_PREFIX` - Prefix for test repository names (default: "git-checkpoints-test")
- `SKIP_CLEANUP` - Set to "1" to skip cleanup of test repositories
- `VERBOSE` - Set to "1" for verbose test output
