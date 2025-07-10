#!/usr/bin/env bash

# Comprehensive cleanup script for git-checkpoints tests
# Removes all test repositories, local files, cron jobs, and processes

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
print_error() { echo -e "${RED}[ERROR]${NC} $*"; }

cleanup_github_repos() {
    print_info "Cleaning up GitHub test repositories..."
    
    if ! command -v gh &>/dev/null; then
        print_warning "GitHub CLI not available - skipping GitHub cleanup"
        return
    fi
    
    # Get list of repositories that match test patterns
    local test_repos
    test_repos=$(gh repo list --json name -q '.[].name' 2>/dev/null | grep -E "(git-checkpoints-.*test|git-checkpoints-demo)" || echo "")
    
    if [ -z "$test_repos" ]; then
        print_info "No test repositories found to clean up"
        return
    fi
    
    echo "$test_repos" | while read -r repo; do
        if [ -n "$repo" ]; then
            print_info "Deleting repository: $repo"
            if gh repo delete "$repo" --yes 2>/dev/null; then
                print_success "Deleted: $repo"
            else
                print_warning "Could not delete: $repo (may not exist or no permissions)"
            fi
        fi
    done
}

cleanup_local_files() {
    print_info "Cleaning up local test files..."
    
    # Remove temporary test directories
    local temp_dirs
    temp_dirs=$(find /tmp -maxdepth 1 -name "tmp.*" -type d 2>/dev/null || echo "")
    
    if [ -n "$temp_dirs" ]; then
        echo "$temp_dirs" | while read -r dir; do
            if [ -d "$dir" ]; then
                print_info "Removing: $dir"
                rm -rf "$dir" 2>/dev/null || true
            fi
        done
        print_success "Removed temporary test directories"
    else
        print_info "No temporary test directories found"
    fi
    
    # Remove wrapper scripts
    local wrapper_scripts
    wrapper_scripts=$(find /tmp -maxdepth 1 -name "git-checkpoints-wrapper-*.sh" 2>/dev/null || echo "")
    
    if [ -n "$wrapper_scripts" ]; then
        echo "$wrapper_scripts" | while read -r script; do
            if [ -f "$script" ]; then
                print_info "Removing wrapper script: $script"
                rm -f "$script" 2>/dev/null || true
            fi
        done
        print_success "Removed wrapper scripts"
    else
        print_info "No wrapper scripts found"
    fi
}

cleanup_cron_jobs() {
    print_info "Cleaning up test cron jobs..."
    
    if ! command -v crontab &>/dev/null; then
        print_warning "crontab not available - skipping cron cleanup"
        return
    fi
    
    # Get current crontab
    local current_cron
    current_cron=$(crontab -l 2>/dev/null || echo "")
    
    if [ -z "$current_cron" ]; then
        print_info "No cron jobs found"
        return
    fi
    
    # Check for git-checkpoints related jobs
    local git_checkpoints_jobs
    git_checkpoints_jobs=$(echo "$current_cron" | grep -i "git-checkpoints" || echo "")
    
    if [ -n "$git_checkpoints_jobs" ]; then
        print_info "Found git-checkpoints cron jobs:"
        echo "$git_checkpoints_jobs"
        
        # Remove git-checkpoints related cron jobs
        local cleaned_cron
        cleaned_cron=$(echo "$current_cron" | grep -v "git-checkpoints" || echo "")
        
        if echo "$cleaned_cron" | crontab - 2>/dev/null; then
            print_success "Cleaned git-checkpoints cron jobs"
        else
            print_warning "Could not update crontab"
        fi
    else
        print_info "No git-checkpoints cron jobs found"
    fi
}

cleanup_processes() {
    print_info "Cleaning up test processes..."
    
    # Find git-checkpoints related processes
    local git_processes
    git_processes=$(pgrep -f "git-checkpoints" 2>/dev/null || echo "")
    
    if [ -n "$git_processes" ]; then
        print_info "Found git-checkpoints processes: $git_processes"
        
        # Kill processes gracefully first
        echo "$git_processes" | while read -r pid; do
            if [ -n "$pid" ]; then
                print_info "Terminating process: $pid"
                kill "$pid" 2>/dev/null || true
            fi
        done
        
        # Wait a moment
        sleep 2
        
        # Force kill if still running
        git_processes=$(pgrep -f "git-checkpoints" 2>/dev/null || echo "")
        if [ -n "$git_processes" ]; then
            echo "$git_processes" | while read -r pid; do
                if [ -n "$pid" ]; then
                    print_info "Force killing process: $pid"
                    kill -9 "$pid" 2>/dev/null || true
                fi
            done
        fi
        
        print_success "Cleaned up test processes"
    else
        print_info "No git-checkpoints processes found"
    fi
}

verify_cleanup() {
    print_info "Verifying cleanup..."
    
    local issues=0
    
    # Check for remaining temp directories
    local remaining_temps
    remaining_temps=$(find /tmp -maxdepth 1 -name "tmp.*" -type d 2>/dev/null | wc -l)
    if [ "$remaining_temps" -gt 0 ]; then
        print_warning "$remaining_temps temporary directories still exist"
        issues=$((issues + 1))
    fi
    
    # Check for remaining wrapper scripts
    local remaining_wrappers
    remaining_wrappers=$(find /tmp -maxdepth 1 -name "git-checkpoints-wrapper-*.sh" 2>/dev/null | wc -l)
    if [ "$remaining_wrappers" -gt 0 ]; then
        print_warning "$remaining_wrappers wrapper scripts still exist"
        issues=$((issues + 1))
    fi
    
    # Check for remaining processes
    local remaining_processes
    remaining_processes=$(pgrep -f "git-checkpoints" 2>/dev/null | wc -l)
    if [ "$remaining_processes" -gt 0 ]; then
        print_warning "$remaining_processes git-checkpoints processes still running"
        issues=$((issues + 1))
    fi
    
    # Check for remaining cron jobs
    if command -v crontab &>/dev/null; then
        local remaining_cron
        remaining_cron=$(crontab -l 2>/dev/null | grep -c "git-checkpoints" || echo "0")
        if [ "$remaining_cron" -gt 0 ]; then
            print_warning "$remaining_cron git-checkpoints cron jobs still exist"
            issues=$((issues + 1))
        fi
    fi
    
    if [ "$issues" -eq 0 ]; then
        print_success "Cleanup verification passed - all clean!"
    else
        print_warning "Cleanup verification found $issues remaining items"
    fi
    
    return $issues
}

main() {
    echo "========================================"
    echo "Git Checkpoints Test Cleanup"
    echo "========================================"
    echo "Timestamp: $(date)"
    echo
    
    print_info "Starting comprehensive cleanup..."
    
    cleanup_github_repos
    cleanup_local_files
    cleanup_cron_jobs
    cleanup_processes
    
    echo
    verify_cleanup
    
    echo
    print_success "🧹 Cleanup completed!"
    print_info "All test artifacts have been removed:"
    print_info "- GitHub test repositories deleted"
    print_info "- Local test directories removed"
    print_info "- Wrapper scripts cleaned up"
    print_info "- Test cron jobs removed"
    print_info "- Test processes terminated"
}

# Show help if requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
Git Checkpoints Test Cleanup Script

This script removes all test artifacts created during git-checkpoints testing:
- GitHub test repositories (git-checkpoints-*test*, git-checkpoints-demo*)
- Local temporary directories (/tmp/tmp.*)
- Wrapper scripts (/tmp/git-checkpoints-wrapper-*.sh)
- Test-related cron jobs
- Running git-checkpoints test processes

Usage: $0 [--help]

Options:
  --help, -h    Show this help message

The script will automatically detect and clean up all test artifacts.
EOF
    exit 0
fi

# Run main function
main "$@"
