#!/usr/bin/env python3
"""Git Checkpoints CLI - calls the bash script."""

import os
import sys
import subprocess
from pathlib import Path


def is_git_repo():
    """Check if current directory is a git repository."""
    try:
        subprocess.check_output(['git', 'rev-parse', '--git-dir'],
                               stderr=subprocess.DEVNULL)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def is_setup_needed():
    """Check if git-checkpoints needs initial setup."""
    if not is_git_repo():
        return False
    
    try:
        # Check if aliases are set up
        subprocess.check_output(['git', 'config', '--local', 'alias.checkpoint'],
                               stderr=subprocess.DEVNULL)
        return False  # Already set up
    except subprocess.CalledProcessError:
        return True  # Needs setup

def run_auto_setup():
    """Run automatic setup for git-checkpoints."""
    try:
        # Look for install.sh script
        install_script_paths = [
            Path(__file__).parent.parent / "install.sh",
            Path(__file__).parent / "install.sh",
        ]
        
        install_script = None
        for path in install_script_paths:
            if path.exists():
                install_script = path
                break
                
        if install_script:
            print("🚀 Setting up git-checkpoints for this repository...")
            os.chmod(install_script, 0o755)
            result = subprocess.run([str(install_script)], cwd=str(install_script.parent))
            if result.returncode == 0:
                print("✅ Auto-setup completed!")
                return True
        else:
            print("⚠️ Auto-setup script not found - run 'git-checkpoints resume' to enable auto-checkpointing")
            return False
    except Exception as e:
        print(f"⚠️ Auto-setup failed: {e}")
        return False

def main():
    """Main entry point - executes the bash script."""
    try:
        # Auto-setup on first use in a git repository
        if is_setup_needed():
            run_auto_setup()
        
        # Look for the bash script in multiple locations
        potential_paths = [
            # Check parent directory (source directory)
            Path(__file__).parent.parent / "git-checkpoints",
            # Check package directory (if copied)
            Path(__file__).parent / "git-checkpoints",
            # Check installed location
            Path("/usr/local/bin/git-checkpoints"),
            Path(os.path.expanduser("~/.local/bin/git-checkpoints")),
        ]
        
        script_path = None
        for path in potential_paths:
            if path.exists():
                script_path = path
                break
                
        if script_path is None:
            print("Error: git-checkpoints bash script not found", file=sys.stderr)
            print("Searched locations:", file=sys.stderr)
            for path in potential_paths:
                print(f"  {path}", file=sys.stderr)
            sys.exit(1)

        # Make sure it's executable
        os.chmod(script_path, 0o755)

        # Execute with all arguments
        result = subprocess.run([str(script_path)] + sys.argv[1:])
        sys.exit(result.returncode)

    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
