# Git Checkpoints Testing Guide

This directory contains a comprehensive test suite for the git-checkpoints tool, including unit tests, integration tests, and specialized cron job testing.

## 🧪 Test Suite Overview

### Test Files Structure
```
tests/
├── README.md                           # Basic test documentation
├── TESTING.md                          # This comprehensive guide
├── test_helpers.sh                     # Shared helper functions and assertions
├── run_all_tests.sh                    # Main test runner with parallel execution
├── cleanup_all_tests.sh                # Comprehensive cleanup script
├── integration_test.sh                 # Full GitHub integration tests
├── unit_tests.sh                       # Individual function testing
├── install_and_test.sh                 # Complete installation demo
├── fixtures/
│   └── sample_project.sh               # Project generators for testing
└── test_scenarios/
    ├── basic_workflow_test.sh           # Development workflow tests
    ├── cron_auto_checkpoint_test.sh     # Standard cron job testing
    └── cron_seconds_test.sh             # 10-second interval testing
```

## 🚀 Quick Start

### Prerequisites
- **Git** - Version control system
- **GitHub CLI (gh)** - For repository creation and management
- **Bash** - Shell environment (version 4.0+)
- **crontab** - For cron job testing (optional)

### Authentication Setup
```bash
# Authenticate with GitHub CLI
gh auth login

# Verify authentication
gh auth status
```

### Running All Tests
```bash
# Run the complete test suite
cd tests
./run_all_tests.sh

# Run with cleanup disabled (to inspect test repositories)
SKIP_CLEANUP=1 ./run_all_tests.sh
```

## 📋 Individual Test Categories

### 1. Unit Tests
Tests individual functions and components:
```bash
./unit_tests.sh
```

**Coverage:**
- Configuration management
- Checkpoint creation logic
- Change detection algorithms
- Helper function validation

### 2. Integration Tests
Tests with real GitHub repositories:
```bash
./integration_test.sh
```

**Coverage:**
- GitHub repository creation
- Remote push functionality
- Tag management
- Authentication handling

### 3. Basic Workflow Tests
Tests typical development scenarios:
```bash
./test_scenarios/basic_workflow_test.sh
```

**Coverage:**
- Create, list, load, delete checkpoints
- Working directory preservation
- Multiple checkpoint scenarios
- Error handling

### 4. Cron Job Tests
Tests automatic checkpoint functionality:
```bash
# Standard cron testing (minute-based intervals)
./test_scenarios/cron_auto_checkpoint_test.sh

# Advanced seconds testing (10-second intervals)
./test_scenarios/cron_seconds_test.sh
```

**Coverage:**
- Automatic checkpoint creation
- Change detection over time
- Working directory state preservation
- Remote push automation
- Configuration management

### 5. Installation Demo
Complete installation and demonstration:
```bash
./install_and_test.sh --method local
```

**Coverage:**
- Tool installation process
- Sample project creation
- End-to-end workflow demonstration
- GitHub integration

## 🔧 Advanced Testing

### Environment Variables
Control test behavior with environment variables:

```bash
# Skip cleanup (keep test repositories for inspection)
SKIP_CLEANUP=1 ./run_all_tests.sh

# Enable verbose output
VERBOSE=1 ./unit_tests.sh

# Custom test duration for cron tests
TEST_DURATION=120 ./test_scenarios/cron_seconds_test.sh
```

### Custom Test Configuration

#### GitHub Repository Settings
Tests automatically create temporary GitHub repositories with names like:
- `git-checkpoints-test-[timestamp]`
- `git-checkpoints-demo-[timestamp]`
- `git-checkpoints-seconds-test-[timestamp]`

#### Cleanup Behavior
By default, all test artifacts are cleaned up automatically:
- GitHub repositories are deleted
- Local temporary directories are removed
- Cron jobs are cleaned up
- Background processes are terminated

To preserve test repositories for inspection:
```bash
SKIP_CLEANUP=1 ./test_scenarios/integration_test.sh
```

## 🤖 GitHub Actions Integration

### Workflow Files
- `.github/workflows/test.yml` - Main test suite
- `.github/workflows/pr-check.yml` - Fast PR validation
- `.github/workflows/badges.yml` - Status badge updates

### Test Matrix
The GitHub Actions workflow runs tests in parallel across different categories:
- Unit tests
- Integration tests
- Workflow tests
- Cron job tests
- Installation tests

### Triggering Seconds Tests
The 10-second interval test runs automatically on push to main, or can be triggered on PRs by adding the `test-seconds` label.

## 🧹 Cleanup and Maintenance

### Manual Cleanup
If tests are interrupted or fail to clean up properly:
```bash
# Run comprehensive cleanup
./cleanup_all_tests.sh

# Check for remaining artifacts
./cleanup_all_tests.sh --verify
```

### Test Repository Management
The cleanup script automatically:
- Finds and deletes test repositories matching patterns
- Removes local temporary directories
- Cleans up cron jobs
- Terminates background processes

## 📊 Test Results and Reporting

### Test Output Format
Tests use a standardized output format:
- `[PASS]` - Test passed
- `[FAIL]` - Test failed
- `[INFO]` - Informational message
- `[WARNING]` - Warning message

### Test Summary
Each test script provides a summary:
```
==================================
Test Summary
==================================
Tests run: 15
Tests passed: 15
Tests failed: 0
All tests passed!
```

## 🔍 Debugging Tests

### Common Issues

#### Authentication Problems
```bash
# Check GitHub CLI authentication
gh auth status

# Re-authenticate if needed
gh auth login
```

#### Permission Issues
```bash
# Ensure scripts are executable
chmod +x tests/*.sh
chmod +x tests/test_scenarios/*.sh
```

#### Cron Job Issues
```bash
# Check if crontab is available
command -v crontab

# View current cron jobs
crontab -l
```

### Verbose Testing
Enable detailed output for debugging:
```bash
VERBOSE=1 ./unit_tests.sh
```

### Test Isolation
Each test runs in isolation:
- Separate temporary directories
- Independent GitHub repositories
- Isolated cron job configurations
- Clean environment setup

## 🚀 Contributing Tests

### Adding New Tests
1. Create test file in appropriate directory
2. Follow naming convention: `*_test.sh`
3. Use test helpers from `test_helpers.sh`
4. Include cleanup in test functions
5. Add to `run_all_tests.sh` if needed

### Test Helper Functions
Available in `test_helpers.sh`:
- `assert_success` - Assert command succeeds
- `assert_failure` - Assert command fails
- `assert_contains` - Assert output contains text
- `test_info` - Print informational message
- `test_success` - Print success message
- `test_error` - Print error message

### Example Test Structure
```bash
#!/usr/bin/env bash
source "$(dirname "$0")/test_helpers.sh"

test_my_feature() {
    test_info "Testing my feature..."
    
    # Setup
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Test
    assert_success "my_command" "Should succeed"
    
    # Cleanup
    cd - && rm -rf "$test_dir"
    
    test_success "My feature test completed"
}

main() {
    test_my_feature
    print_test_summary
}

main "$@"
```

This comprehensive testing framework ensures the git-checkpoints tool works reliably across different environments and use cases.
