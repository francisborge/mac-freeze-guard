#!/usr/bin/env bash
# memory_watchdog.sh — Runs every 15 minutes via launchd.
# Checks whether the pCloud Drive process is running.
# Restarts it (kill then relaunch) only if the process is gone.
# Does NOT probe the filesystem — FUSE stat/ls blocks during normal sync,
# causing false positives that reset Finder's session.

LOG_DIR="$HOME/Library/Logs/freeze_guard"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/memory_watchdog.log"
STATE_FILE="$LOG_DIR/.watchdog_state"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>&1; }

# --- Check if pCloud Drive process is running
if pgrep -f "pCloud Drive" > /dev/null 2>&1; then
  # Process is alive — do nothing, no log noise
  exit 0
fi

# --- Process not found — pCloud has crashed
NOW=$(date +%s)

# Cooldown: skip if we restarted less than 5 minutes ago
LAST_ACTION=0
[[ -f "$STATE_FILE" ]] && LAST_ACTION=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
COOLDOWN=300  # 5 minutes

if (( NOW - LAST_ACTION < COOLDOWN )); then
  exit 0
fi

log "pCloud Drive process not found — restarting"

# Always kill any remnant before relaunching (handles hung/zombie processes)
osascript -e 'tell application "pCloud Drive" to quit' 2>/dev/null || true
sleep 3
pkill -9 -f "pCloud Drive" 2>/dev/null || true
sleep 2
open -a "pCloud Drive" 2>/dev/null || true

log "pCloud Drive relaunched — cooldown starts now (${COOLDOWN}s)"
echo "$NOW" > "$STATE_FILE"

# --- Rotate log if > 200KB
LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
if (( LOG_SIZE > 204800 )); then
  mv "$LOG_FILE" "${LOG_FILE}.1"
  log "Log rotated"
fi
