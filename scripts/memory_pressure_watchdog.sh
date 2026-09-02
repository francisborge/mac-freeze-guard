#!/usr/bin/env bash
# memory_pressure_watchdog.sh — Runs every 5 minutes via launchd.
# Early-warning system: notifies the user before the system reaches total-freeze territory
# (see README root cause — 13-day uptime + swap/compressor buildup preceded the Sep 1 freeze).
# Notify-only — never kills or restarts processes automatically.

LOG_DIR="$HOME/Library/Logs/freeze_guard"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/memory_pressure_watchdog.log"
STRIKE_FILE="$LOG_DIR/.pressure_strike"
NOTIFY_STATE_FILE="$LOG_DIR/.pressure_notify_state"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>&1; }

LEVEL=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || echo 1)
FREE_PAGES=$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub("\\.", "", $3); print $3}')

case "$LEVEL" in
  4) STATUS="critical" ;;
  2) STATUS="warning" ;;
  *) STATUS="normal" ;;
esac

log "heartbeat: level=$STATUS free_pages=${FREE_PAGES:-NA}"

if [[ "$STATUS" != "critical" ]]; then
  rm -f "$STRIKE_FILE"
  exit 0
fi

# --- Require 2 consecutive critical readings (~5 min apart) before acting on it
STRIKES=1
[[ -f "$STRIKE_FILE" ]] && STRIKES=$(( $(cat "$STRIKE_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$STRIKES" > "$STRIKE_FILE"

if (( STRIKES < 2 )); then
  log "critical pressure observed (strike ${STRIKES}/2) — confirming next run before notifying"
  exit 0
fi

# --- Confirmed sustained critical pressure — notify (with cooldown to avoid spam)
NOW=$(date +%s)
LAST_NOTIFY=0
[[ -f "$NOTIFY_STATE_FILE" ]] && LAST_NOTIFY=$(cat "$NOTIFY_STATE_FILE" 2>/dev/null || echo 0)
COOLDOWN=1800  # 30 minutes

if (( NOW - LAST_NOTIFY < COOLDOWN )); then
  log "critical pressure confirmed but within ${COOLDOWN}s notification cooldown — skipping alert"
  exit 0
fi

TOP5=$(top -l 1 -o rsize -n 5 2>/dev/null | tail -5 | awk '{print $2, $12}' | tr '\n' ';')
log "critical pressure confirmed — notifying user. Top RSS: $TOP5"

osascript -e 'display notification "macOS memory pressure is critical — consider closing apps or saving your work before a freeze." with title "Memory Pressure Warning" sound name "Basso"' 2>/dev/null || true

echo "$NOW" > "$NOTIFY_STATE_FILE"

# --- Rotate log if > 200KB
LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
if (( LOG_SIZE > 204800 )); then
  mv "$LOG_FILE" "${LOG_FILE}.1"
  log "Log rotated"
fi
