#!/usr/bin/env bash
# nightly_refresh.sh — Runs at 04:20 via launchd.
# Restarts Dock and pCloud Drive to clear accumulated memory leaks.
# Finder is intentionally NOT restarted — this preserves your Finder session.
# Lives in ~/Library/Scripts/freeze_guard/ — accessible by launchd without TCC issues.

LOG_DIR="$HOME/Library/Logs/freeze_guard"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/nightly_refresh.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>&1; }

log "=== Nightly refresh START ==="

# --- 1. Restart Dock (invisible to user; clears minor memory leaks)
if killall Dock >> "$LOG_FILE" 2>&1; then
  log "Dock restarted"
else
  log "Dock: nothing to kill (ignored)"
fi

# --- 2. Gracefully quit pCloud Drive, wait, relaunch
osascript -e 'tell application "pCloud Drive" to quit' >> "$LOG_FILE" 2>&1 || true
sleep 5

# Verify pCloud Drive is actually gone before relaunching
if pgrep -f "pCloud Drive" > /dev/null 2>&1; then
  log "pCloud Drive still running after quit — force-killing"
  pkill -9 -f "pCloud Drive" 2>/dev/null || true
  sleep 3
fi

open -a "pCloud Drive" >> "$LOG_FILE" 2>&1 || true
log "pCloud Drive relaunch requested"

# --- 3. Status snapshot
TS="$(date +%Y%m%d_%H%M%S)"
SNAP="$LOG_DIR/nightly_status_$TS.txt"
{
  echo "Timestamp: $(date)"
  echo "Uptime: $(uptime)"
  echo
  memory_pressure 2>&1 | head -20
  echo
  echo "=== top memory ==="
  top -l 1 -o rsize -n 10 | tail -12
} > "$SNAP"
log "Snapshot saved: $SNAP"

# --- 4. Prune old snapshots (30-day retention)
# One snapshot per run and nothing ever removed them: 62 files by 26.08, growing
# ~3.6 KB/day without bound. They are not redundant — each is a distinct daily
# capture — so the set is bounded rather than dropped. Mirrors the 200 KB
# rotation memory_watchdog.sh already does for its own log.
find "$LOG_DIR" -name 'nightly_status_*.txt' -mtime +30 -delete 2>/dev/null
log "Snapshots pruned (30d retention; $(ls "$LOG_DIR"/nightly_status_*.txt 2>/dev/null | wc -l | tr -d ' ') kept)"
log "=== Nightly refresh END ==="
