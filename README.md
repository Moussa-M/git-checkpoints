
# Git Checkpoints

🔄 **Zero-config, language-agnostic Git snapshots via tags.**

---

## 🚀 One-Line Install

```bash
curl -LsSf https://raw.githubusercontent.com/moussa-m/git-checkpoints/main/install.sh | bash
```

* Installs `git-checkpoints` into your `PATH`
* Adds `git checkpoint` / `git checkpoints` aliases in **this** repo
* Schedules auto-snapshot every 5 minutes when changes exist (configurable)

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
git-checkpoints config get status             # show current status
git-checkpoints config set interval 10        # set interval to 10 minutes
```

**Available options:**
- `interval` - Auto-checkpoint interval in minutes (default: 5)
- `status` - Current status: `paused` or `running`

**Examples:**
```bash
# Set checkpoints every 15 minutes
git-checkpoints config set interval 15
git-checkpoints resume  # apply new interval

# Check current configuration
git-checkpoints config get
# Output:
# ℹ️ Current configuration:
#   interval: 15 minutes
#   status: running
```

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
