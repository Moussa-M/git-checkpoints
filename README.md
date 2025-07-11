# Git Checkpoints

🔄 **Zero-config, language-agnostic Git snapshots via tags.**

[![Tests](https://img.shields.io/github/actions/workflow/status/Moussa-M/git-checkpoints-public/test.yml?branch=main&label=Tests)](https://github.com/Moussa-M/git-checkpoints-public/actions/workflows/test.yml)
[![PR Check](https://img.shields.io/github/actions/workflow/status/Moussa-M/git-checkpoints-public/pr-check.yml?branch=main&label=PR%20Check)](https://github.com/Moussa-M/git-checkpoints-public/actions/workflows/pr-check.yml)
[![License](https://img.shields.io/github/license/Moussa-M/git-checkpoints-public)](LICENSE)
[![Version](https://img.shields.io/github/v/release/Moussa-M/git-checkpoints-public)](https://github.com/Moussa-M/git-checkpoints-public/releases)

---

## 🚀 Installation

### Option 1: NPM Package

```bash
npm install -g git-checkpoints
```

### Option 2: Python Package

```bash
pip install git-checkpoints
```

### Option 3: Bash Script (One-Line Install)

```bash
curl -LsSf https://raw.githubusercontent.com/moussa-m/git-checkpoints/main/install.sh | bash
```

Both methods:
* Install `git-checkpoints` into your `PATH`
* Add `git checkpoint` / `git checkpoints` aliases in **this** repo
* Schedule auto-snapshot every 5 minutes when changes exist (configurable)

---

## ❌ One-Line Uninstall

```bash
git-checkpoints uninstall
```

Removes the global CLI **and** all cron entries.

---

## 💻 Usage

### Git aliases (in your repo)

```bash
git checkpoint [name]      # create a checkpoint
git checkpoints list       # list all checkpoints
git checkpoints delete *   # delete one or all
git checkpoints load <name># restore a checkpoint
```

### Direct CLI

```bash
git-checkpoints create [name]
git-checkpoints list
git-checkpoints delete <name|*>
git-checkpoints load <name>
git-checkpoints auto
git-checkpoints pause              # pause auto-checkpointing
git-checkpoints resume             # resume auto-checkpointing
git-checkpoints config <get|set>   # manage configuration
git-checkpoints local-uninstall
git-checkpoints uninstall
```

---

## ⚙️ Configuration

Control auto-checkpointing behavior with the config command:

```bash
git-checkpoints config get                    # show all settings
git-checkpoints config get interval           # show current interval
git-checkpoints config set interval 10        # set interval to 10 minutes
```

**Available options:**
- `interval` - Auto-checkpoint interval in minutes (default: 5)
- `notify` - Enable notifications for checkpoint actions (true/false, default: false)
- `max_auto` - Maximum number of auto checkpoints to keep (default: 10, 0 to disable)
- `auto_age_days` - Delete auto checkpoints older than this many days (default: 30, 0 to disable)

Auto cleanup of old or excess auto checkpoints runs automatically after creating a new auto checkpoint, based on the `max_auto` and `auto_age_days` settings. Manual checkpoints are not affected.

**Examples:**
```bash
# Set checkpoints every 15 minutes
git-checkpoints config set interval 15
git-checkpoints resume  # apply new interval

# Enable notifications
git-checkpoints config set notify true

# Set max auto checkpoints to 5 and age limit to 14 days
git-checkpoints config set max_auto 5
git-checkpoints config set auto_age_days 14

# Check current configuration
git-checkpoints config get
# Output:
# ℹ️ Current configuration for this repository:
#   interval: 15 minutes
#   notify:   true
#   max_auto:       5 (0 to disable)
#   auto_age_days:  14 (0 to disable)
# ✅ Auto-checkpointing is ACTIVE (interval: 15m).
```

---

## 🧪 Testing & Development

This project includes a comprehensive test suite that runs automatically on GitHub Actions.

### Running Tests Locally

```bash
# Run all tests
cd tests
./run_all_tests.sh

# Run specific test categories
./unit_tests.sh                                    # Unit tests
./integration_test.sh                              # GitHub integration tests
./test_scenarios/basic_workflow_test.sh            # Workflow tests
./test_scenarios/cron_auto_checkpoint_test.sh      # Cron job tests
./test_scenarios/cron_seconds_test.sh              # 10-second interval tests

# Clean up test artifacts
./cleanup_all_tests.sh
```

### Test Coverage

- **Unit Tests**: Individual function testing
- **Integration Tests**: Real GitHub repository creation and management
- **Workflow Tests**: Typical development scenarios
- **Cron Tests**: Automatic checkpoint functionality with various intervals
- **Installation Tests**: Complete installation process verification

### GitHub Actions

The project uses GitHub Actions for continuous integration:

- **Full Test Suite**: Runs on push to main branch
- **PR Quick Check**: Fast tests for pull requests
- **Seconds Interval Test**: Extended testing with 10-second intervals (triggered by `test-seconds` label)

### Prerequisites for Local Testing

- Git
- GitHub CLI (`gh`) with authentication
- Bash 4.0+
- crontab (optional, for cron tests)

---

## 🛠 Troubleshooting

* **`git-checkpoints` not found?**
  Ensure your install dir (e.g. `~/.local/bin`) is in `$PATH`.
* **No snapshots?**

  * Check uncommitted changes: `git status`
  * Trigger one manually: `git checkpoint`
* **Cron not running?**

  * Verify service: `systemctl status cron`
  * Check crontab: `crontab -l | grep git-checkpoints`

Enjoy effortless, zero-config backups of your work-in-progress!