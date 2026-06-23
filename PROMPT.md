# Mac Freeze Guard — AI Rebuild Prompt

Use this file to recreate the entire mac-freeze-guard setup from scratch using an AI assistant (e.g. GitHub Copilot, Claude). Paste the content below as your first message.

---

## Prompt

My Mac laptop (Apple M5 Pro, 24GB RAM, macOS Sequoia/Sonoma, 3 displays: built-in Retina + 2x Dell 4K external) experiences partial freezes where **Finder and pCloud Drive become unresponsive**, typically after 17:00 during afternoon work sessions.

**Root cause (already diagnosed):**
1. The system runs near 100% RAM usage (WindowServer leaks 1GB+ after multi-day uptime with 3 monitors; Chrome + VS Code + Outlook + WhatsApp all open simultaneously).
2. pCloud Drive uses a FUSE-based kernel filesystem. Under memory pressure, the pCloud daemon stalls and holds kernel VFS locks, causing Finder to deadlock waiting for filesystem responses.
3. Both pCloud and Finder appear completely frozen. Only fix was manual force-quit.

**The solution I had in place (needs to be rebuilt):**

Two launchd agents:

### 1. Memory Watchdog (every 15 min)
**File:** `~/Library/Scripts/freeze_guard/memory_watchdog.sh`
- Every 15 minutes, run `timeout 5 ls "$HOME/pCloud Drive"` to probe if pCloud's filesystem responds.
- If it responds within 5 seconds → exit silently, do nothing.
- If it times out or fails → pCloud is frozen: quit it via osascript, force-kill with pkill -9, relaunch with `open -a "pCloud Drive"`. Log the event.
- After a restart, apply a 5-minute cooldown (tracked via `~/.watchdog_state` timestamp file) before probing again, to avoid restarting pCloud while it's still loading.
- Log file: `~/Downloads/mac_freeze_fix/memory_watchdog.log`
- **Never restart Finder** — that loses the user's Finder session.

**launchd plist:** `~/Library/LaunchAgents/com.francisco.memory-watchdog.plist`
- `StartInterval`: 900 (every 15 minutes)
- `RunAtLoad`: true
- StandardOutPath/StandardErrorPath → `~/Library/Logs/freeze_guard/` (NOT ~/Downloads — TCC restriction prevents launchd from creating new files there)

### 2. Nightly Refresh (04:20 every night)
**File:** `~/Library/Scripts/freeze_guard/nightly_refresh.sh`
- Restart Dock (invisible to user, clears minor memory leaks).
- Gracefully quit pCloud Drive via osascript, force-kill if still running, relaunch.
- Take a status snapshot (uptime, memory_pressure, top memory consumers) to `~/Downloads/mac_freeze_fix/nightly_status_<timestamp>.txt`.
- Log file: `~/Downloads/mac_freeze_fix/nightly_refresh.log`
- **Never restart Finder** — preserves Finder session.

**launchd plist:** `~/Library/LaunchAgents/com.francisco.nightly-refresh.plist`
- `StartCalendarInterval`: Hour=4, Minute=20
- `RunAtLoad`: false
- StandardOutPath/StandardErrorPath → `~/Library/Logs/freeze_guard/`

**Critical deployment note:** Scripts must live in `~/Library/Scripts/freeze_guard/`, NOT in `~/Downloads/`. macOS TCC prevents launchd agents from executing scripts located in `~/Downloads/`. Similarly, launchd StandardOutPath/StandardErrorPath log files must be pre-created (use `touch`) or point to `~/Library/Logs/` — launchd cannot create new files in `~/Downloads/` and will exit with code 78 if the log file doesn't exist there.

**Verification after setup:**
```bash
launchctl list | grep francisco
# Expected:
# <PID>  0  com.francisco.memory-watchdog    ← running
# -      0  com.francisco.nightly-refresh    ← scheduled
```

**Log locations (local only, not in repo):**
- `~/Downloads/mac_freeze_fix/memory_watchdog.log` — watchdog events
- `~/Downloads/mac_freeze_fix/nightly_refresh.log` — nightly events
- `~/Library/Logs/freeze_guard/` — launchd stdout/stderr

**Repo (for file reference):** `github.com/francisborge/mac-freeze-guard`
Contains: `scripts/`, `launchd/`, `setup.sh` (one-shot recovery), this file.
