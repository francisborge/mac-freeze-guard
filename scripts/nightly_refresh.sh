#!/usr/bin/env bash
# nightly_refresh.sh — Runs at 04:20 via launchd.
# Restarts Dock and pCloud Drive to clear accumulated memory leaks.
# Finder is intentionally NOT restarted — this preserves your Finder session.
# Lives in ~/Library/Scripts/freeze_guard/ — accessible by launchd without TCC issues.

LOG_DIR="$HOME/Downloads/mac_freeze_fix"
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
log "=== Nightly refresh END ==="
