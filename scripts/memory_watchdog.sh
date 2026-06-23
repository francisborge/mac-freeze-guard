#!/usr/bin/env bash
# memory_watchdog.sh — Runs every 15 minutes via launchd.
# Probes whether pCloud Drive's filesystem is responding.
# Only restarts pCloud if it is actually frozen — never based on RAM alone.
# This avoids unnecessary restarts that would lose your Finder session.

LOG_DIR="$HOME/Downloads/mac_freeze_fix"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/memory_watchdog.log"
STATE_FILE="$LOG_DIR/.watchdog_state"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>&1; }

PCLOUD_MOUNT="$HOME/pCloud Drive"

# --- Cooldown check: skip if pCloud was restarted less than 5 minutes ago
LAST_ACTION=0
[[ -f "$STATE_FILE" ]] && LAST_ACTION=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
NOW=$(date +%s)
ELAPSED=$(( NOW - LAST_ACTION ))
COOLDOWN=300  # 5 minutes

if (( ELAPSED < COOLDOWN )); then
  # Still within cooldown after last restart — skip probe, exit silently
  exit 0
fi

# --- Probe: can we list the pCloud Drive mount within 20 seconds?
if timeout 20 ls "$PCLOUD_MOUNT" > /dev/null 2>&1; then
  # pCloud is responding normally — do nothing, no log noise
  exit 0
fi

# --- First probe failed — wait 5s and retry before declaring frozen
log "pCloud Drive probe 1 timed out — retrying in 5s"
sleep 5

if timeout 20 ls "$PCLOUD_MOUNT" > /dev/null 2>&1; then
  log "pCloud Drive probe 2 OK — transient slowness, no restart needed"
  exit 0
fi

# --- Both probes failed — pCloud is frozen or unmounted
log "pCloud Drive both probes timed out — restarting"

osascript -e 'tell application "pCloud Drive" to quit' 2>/dev/null || true
sleep 4
pkill -9 -f "pCloud Drive" 2>/dev/null || true
sleep 2
open -a "pCloud Drive" 2>/dev/null || true

log "pCloud Drive restarted — cooldown starts now (${COOLDOWN}s)"
echo "$NOW" > "$STATE_FILE"

# --- Rotate log if > 200KB
LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
if (( LOG_SIZE > 204800 )); then
  mv "$LOG_FILE" "${LOG_FILE}.1"
  log "Log rotated"
fi
