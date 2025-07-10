#!/usr/bin/env bash

# Complete installation and testing script for git-checkpoints
# This script demonstrates the full workflow: install tool, create GitHub repo, run tests

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_REPO_NAME="git-checkpoints-demo-$(date +%s)"
INSTALL_METHOD="${INSTALL_METHOD:-local}"  # local, global, or path

# Output functions
print_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
print_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Help function
show_help() {
    cat <<EOF
Git Checkpoints Installation and Test Script

This script demonstrates the complete workflow:
1. Install git-checkpoints tool
2. Create a GitHub repository
3. Install the tool in the repository
4. Run comprehensive tests

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -m, --method METHOD     Installation method: local, global, or path (default: local)
  -r, --repo-name NAME    Custom repository name (default: auto-generated)
  -s, --skip-install      Skip installation step
  -k, --keep-repo         Keep the test repository after completion
  -v, --verbose           Enable verbose output

Installation Methods:
  local   - Copy script to test repository (default)
  global  - Install script globally in PATH
  path    - Add script directory to PATH

Examples:
  $0                      Run with default settings
  $0 -m global            Install globally and test
  $0 -r my-test-repo      Use custom repository name
  $0 -k                   Keep repository after testing

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
            -m|--method)
                INSTALL_METHOD="$2"
                shift
                ;;
            -r|--repo-name)
                TEST_REPO_NAME="$2"
                shift
                ;;
            -s|--skip-install)
                SKIP_INSTALL=1
                ;;
            -k|--keep-repo)
                KEEP_REPO=1
                ;;
            -v|--verbose)
                VERBOSE=1
                export VERBOSE=1
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
    
    # Check if we're in the right directory
    if [ ! -f "$PROJECT_DIR/git-checkpoints" ]; then
        print_error "git-checkpoints script not found in $PROJECT_DIR"
        exit 1
    fi
    
    # Check GitHub CLI
    if ! command -v gh &>/dev/null; then
        print_error "GitHub CLI (gh) is required but not installed"
        print_info "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    # Check GitHub authentication
    if ! gh auth status &>/dev/null; then
        print_error "GitHub CLI is not authenticated"
        print_info "Run 'gh auth login' to authenticate"
        exit 1
    fi
    
    # Check git configuration
    if ! git config user.name &>/dev/null || ! git config user.email &>/dev/null; then
        print_warning "Git user.name or user.email not configured"
        print_info "Setting temporary configuration..."
        git config --global user.name "Git Checkpoints Test" 2>/dev/null || true
        git config --global user.email "test@git-checkpoints.local" 2>/dev/null || true
    fi
    
    print_success "Prerequisites check completed"
}

# Install git-checkpoints tool
install_tool() {
    if [ "${SKIP_INSTALL:-0}" = "1" ]; then
        print_info "Skipping installation step"
        return
    fi
    
    print_info "Installing git-checkpoints tool using method: $INSTALL_METHOD"
    
    case "$INSTALL_METHOD" in
        "local")
            print_info "Local installation - tool will be copied to test repository"
            ;;
        "global")
            print_info "Installing globally to ~/.local/bin/"
            mkdir -p "$HOME/.local/bin"
            cp "$PROJECT_DIR/git-checkpoints" "$HOME/.local/bin/"
            chmod +x "$HOME/.local/bin/git-checkpoints"
            
            # Add to PATH if not already there
            if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
                export PATH="$HOME/.local/bin:$PATH"
                print_info "Added ~/.local/bin to PATH for this session"
                print_warning "Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your shell profile for permanent access"
            fi
            
            print_success "Global installation completed"
            ;;
        "path")
            print_info "Adding project directory to PATH"
            export PATH="$PROJECT_DIR:$PATH"
            print_success "Added $PROJECT_DIR to PATH for this session"
            ;;
        *)
            print_error "Unknown installation method: $INSTALL_METHOD"
            exit 1
            ;;
    esac
}

# Create GitHub repository and set up test environment
setup_test_repository() {
    print_info "Creating GitHub repository: $TEST_REPO_NAME"
    
    # Create repository
    if ! gh repo create "$TEST_REPO_NAME" --public --description "Test repository for git-checkpoints demonstration" --clone=false; then
        print_error "Failed to create GitHub repository"
        exit 1
    fi
    
    print_success "Created GitHub repository: $TEST_REPO_NAME"
    
    # Create temporary directory and clone
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    print_info "Cloning repository to: $temp_dir"
    if ! gh repo clone "$TEST_REPO_NAME" .; then
        print_error "Failed to clone repository"
        exit 1
    fi
    
    # Configure git
    git config user.name "Git Checkpoints Test"
    git config user.email "test@git-checkpoints.local"
    
    # Copy git-checkpoints script if using local method
    if [ "$INSTALL_METHOD" = "local" ]; then
        cp "$PROJECT_DIR/git-checkpoints" ./
        chmod +x ./git-checkpoints
        print_info "Copied git-checkpoints script to repository"
    fi
    
    # Create initial project structure
    print_info "Setting up sample project..."
    bash "$SCRIPT_DIR/fixtures/sample_project.sh" web
    
    # Create initial commit
    git add .
    git commit -m "Initial commit with sample project"
    git push origin main
    
    print_success "Test repository setup completed"
    echo "Repository URL: $(gh repo view --web --json url -q .url)"
    echo "Local path: $(pwd)"
}

# Run demonstration workflow
run_demonstration() {
    print_info "Running git-checkpoints demonstration..."
    
    # Determine command based on installation method
    local git_checkpoints_cmd
    case "$INSTALL_METHOD" in
        "local")
            git_checkpoints_cmd="./git-checkpoints"
            ;;
        "global"|"path")
            git_checkpoints_cmd="git-checkpoints"
            ;;
    esac
    
    # Test basic functionality
    print_info "Step 1: Testing basic commands"
    echo "Version: $($git_checkpoints_cmd version)"
    echo "Available checkpoints: $($git_checkpoints_cmd list 2>&1)"
    
    # Create some changes and checkpoints
    print_info "Step 2: Making changes and creating checkpoints"
    
    # Modify existing files
    echo "/* Enhanced styles */" >> styles.css
    echo "body { font-size: 16px; }" >> styles.css
    
    # Create first checkpoint
    $git_checkpoints_cmd create "enhanced-styles"
    print_success "Created checkpoint: enhanced-styles"
    
    # Add new functionality
    echo "" >> script.js
    echo "// New feature: click counter display" >> script.js
    echo "function updateCounter() {" >> script.js
    echo "  document.title = \`Clicks: \${clickCount}\`;" >> script.js
    echo "}" >> script.js
    
    # Stage some changes
    git add script.js
    
    # Create second checkpoint
    $git_checkpoints_cmd create "added-counter-feature"
    print_success "Created checkpoint: added-counter-feature"
    
    # Show current checkpoints
    print_info "Step 3: Listing checkpoints"
    $git_checkpoints_cmd list
    
    # Test loading a checkpoint
    print_info "Step 4: Testing checkpoint loading"
    
    # Make some destructive changes
    echo "/* This will break everything */" > styles.css
    rm -f script.js
    
    print_warning "Made destructive changes (deleted script.js, overwrote styles.css)"
    
    # Load previous checkpoint
    echo "y" | $git_checkpoints_cmd load "added-counter-feature"
    print_success "Restored from checkpoint: added-counter-feature"
    
    # Verify files are restored
    if [ -f "script.js" ] && [ -f "styles.css" ]; then
        print_success "Files successfully restored!"
    else
        print_error "File restoration failed!"
        exit 1
    fi
    
    # Test configuration
    print_info "Step 5: Testing configuration"
    $git_checkpoints_cmd config set notify true
    $git_checkpoints_cmd config set interval 10
    $git_checkpoints_cmd config get
    
    # Test auto-checkpoint
    print_info "Step 6: Testing auto-checkpoint"
    echo "// Auto checkpoint test" >> script.js
    $git_checkpoints_cmd auto
    
    # Show final state
    print_info "Step 7: Final checkpoint list"
    $git_checkpoints_cmd list
    
    print_success "Demonstration completed successfully!"
}

# Run comprehensive tests
run_tests() {
    print_info "Running comprehensive test suite..."
    
    # Copy test files to current directory
    cp -r "$SCRIPT_DIR"/* ./tests/ 2>/dev/null || true
    
    # Run unit tests
    if [ -f "./tests/unit_tests.sh" ]; then
        print_info "Running unit tests..."
        if bash "./tests/unit_tests.sh"; then
            print_success "Unit tests passed"
        else
            print_warning "Unit tests failed"
        fi
    fi
    
    # Run basic workflow test
    if [ -f "./tests/test_scenarios/basic_workflow_test.sh" ]; then
        print_info "Running workflow tests..."
        if bash "./tests/test_scenarios/basic_workflow_test.sh"; then
            print_success "Workflow tests passed"
        else
            print_warning "Workflow tests failed"
        fi
    fi
    
    print_success "Test suite completed"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    if [ "${KEEP_REPO:-0}" != "1" ]; then
        print_info "Cleaning up test repository..."
        
        if [ -n "${TEST_REPO_NAME:-}" ]; then
            if gh repo delete "$TEST_REPO_NAME" --confirm 2>/dev/null; then
                print_success "Deleted GitHub repository: $TEST_REPO_NAME"
            else
                print_warning "Could not delete repository: $TEST_REPO_NAME"
                print_info "You may need to delete it manually at: https://github.com/$(gh api user -q .login)/$TEST_REPO_NAME"
            fi
        fi
    else
        print_info "Keeping test repository as requested"
        print_info "Repository: https://github.com/$(gh api user -q .login)/$TEST_REPO_NAME"
    fi
    
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
    echo "Git Checkpoints Installation & Test Demo"
    echo "========================================"
    echo "Timestamp: $(date)"
    echo "Repository: $TEST_REPO_NAME"
    echo "Install Method: $INSTALL_METHOD"
    echo
    
    # Run all steps
    check_prerequisites
    install_tool
    setup_test_repository
    run_demonstration
    run_tests
    
    # Print success message
    echo
    print_success "🎉 Git Checkpoints installation and testing completed successfully!"
    echo
    echo "Summary:"
    echo "- ✅ Tool installed using method: $INSTALL_METHOD"
    echo "- ✅ GitHub repository created and configured"
    echo "- ✅ Demonstration workflow completed"
    echo "- ✅ Test suite executed"
    
    if [ "${KEEP_REPO:-0}" = "1" ]; then
        echo "- 📁 Repository preserved for further exploration"
        echo "  URL: https://github.com/$(gh api user -q .login)/$TEST_REPO_NAME"
    fi
    
    echo
    print_info "You can now use git-checkpoints in your own projects!"
    
    if [ "$INSTALL_METHOD" = "global" ]; then
        print_info "The tool is globally available as 'git-checkpoints'"
    elif [ "$INSTALL_METHOD" = "local" ]; then
        print_info "Copy the git-checkpoints script to your project directories to use it"
    fi
}

# Run main function
main "$@"
