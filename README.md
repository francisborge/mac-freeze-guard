# mac-freeze-guard

Prevents **Finder + pCloud Drive freeze** on macOS with multi-monitor setups and high RAM usage. Two launchd agents: a 15-minute watchdog that detects a crashed pCloud process and relaunches it, and a nightly refresh that restarts Dock + pCloud Drive to clear memory leaks.

## The problem

On Apple Silicon Macs running near full RAM (24GB used by WindowServer, Chrome, VS Code, Outlook, WhatsApp), pCloud Drive's FUSE kernel filesystem can stall under memory pressure. When it stalls it holds kernel VFS locks, causing Finder to deadlock waiting for filesystem responses — both appear completely frozen.

Root cause chain (diagnosed from system logs):
1. `pCloudFinderExt` connection drops (~17:15)
2. Memory hits Critical Pressure (`modelmanagerd` "Critical Memory Pressure Event Loop")
3. `watchdogd` fires error-level events
4. Finder and pCloud are unresponsive

## Solution

| Agent | Trigger | Action |
|---|---|---|
| `memory_watchdog` | Every 15 min | Checks if pCloud Drive process is running. If crashed → kill any remnant + relaunch. No filesystem probe (FUSE blocks during sync, causing false Finder resets) |
| `nightly_refresh` | 04:20 every night | Restart Dock + pCloud Drive to clear accumulated memory leaks |

**Finder is never restarted automatically** — that would lose your Finder session.

## Recovery (after system failure or fresh macOS install)

```bash
# 1. Clone the repo
git clone https://github.com/francisborge/mac-freeze-guard.git
cd mac-freeze-guard

# 2. Run setup (creates dirs, installs scripts + plists, loads agents)
bash setup.sh

# 3. Verify
launchctl list | grep francisco
```

Expected output:
```
<PID>  0  com.francisco.memory-watchdog    ← running, probes every 15 min
-      0  com.francisco.nightly-refresh    ← scheduled for 04:20
```

## File locations after setup

| File | Location |
|---|---|
| Watchdog script | `~/Library/Scripts/freeze_guard/memory_watchdog.sh` |
| Nightly script | `~/Library/Scripts/freeze_guard/nightly_refresh.sh` |
| Watchdog plist | `~/Library/LaunchAgents/com.francisco.memory-watchdog.plist` |
| Nightly plist | `~/Library/LaunchAgents/com.francisco.nightly-refresh.plist` |
| Watchdog log | `~/Library/Logs/freeze_guard/memory_watchdog.log` |
| Nightly log | `~/Library/Logs/freeze_guard/nightly_refresh.log` |
| launchd stdout/err | `~/Library/Logs/freeze_guard/` |

Log files are local only and not tracked in this repo.

## Rebuild with AI

Open GitHub Copilot Chat in **Agent mode** and run:

```
/rebuild_mac_guard
```

This prompt (`.github/prompts/rebuild_mac_guard.prompt.md`) checks the current state, clones the repo if needed, runs `setup.sh`, and verifies both launchd agents are loaded — no manual steps required.

## Why scripts are in `~/Library/Scripts/` not `~/Downloads/`

macOS TCC (privacy framework) prevents launchd agents from executing scripts in `~/Downloads/`. Scripts must be in `~/Library/Scripts/`. Similarly, launchd `StandardOutPath`/`StandardErrorPath` log files must either pre-exist or point to `~/Library/Logs/` — launchd exits with code 78 if it cannot open them.
