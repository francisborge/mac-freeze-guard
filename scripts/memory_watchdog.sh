#!/usr/bin/env bash
# memory_watchdog.sh — Runs every 15 minutes via launchd.
# Two independent checks: (1) is the pCloud process alive at all, (2) does the FUSE
# filesystem actually respond. A single failed FS probe can be a normal sync stall, so a
# restart only fires after 2 consecutive failed probes (~15 min apart) — see the false-positive
# history in this log from before that safeguard existed. Logs a heartbeat every run (even on
# a clean pass) so a future freeze leaves a trail proving whether this agent executed at all.

LOG_DIR="$HOME/Library/Logs/freeze_guard"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/memory_watchdog.log"
STATE_FILE="$LOG_DIR/.watchdog_state"
FS_STRIKE_FILE="$LOG_DIR/.watchdog_fs_strike"
PCLOUD_MOUNT="$HOME/pCloud Drive"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>&1; }

mem_summary() {
  local free swap
  free=$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub("\\.", "", $3); print $3}')
  swap=$(sysctl -n vm.swapusage 2>/dev/null | awk -F'used = ' '{print $2}' | awk '{print $1, $2}')
  echo "free_pages=${free:-NA} swap_used=${swap:-NA}"
}

# No `timeout` binary on this Mac (confirmed 2026-09-02) — self-timeout via a killer subshell
# instead, so a stuck `stat` can't hang the watchdog itself.
fs_probe() {
  ( stat "$PCLOUD_MOUNT" > /dev/null 2>&1 ) &
  local probe_pid=$!
  ( sleep 5; kill -9 "$probe_pid" 2>/dev/null ) &
  local killer_pid=$!
  local rc=0
  wait "$probe_pid" 2>/dev/null || rc=1
  kill "$killer_pid" 2>/dev/null
  wait "$killer_pid" 2>/dev/null
  return $rc
}

restart_pcloud() {
  local reason="$1" now last cooldown=300
  now=$(date +%s)
  last=0
  [[ -f "$STATE_FILE" ]] && last=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
  if (( now - last < cooldown )); then
    log "restart skipped ($reason) — within ${cooldown}s cooldown of last restart"
    return
  fi
  log "$reason — restarting"
  osascript -e 'tell application "pCloud Drive" to quit' 2>/dev/null || true
  sleep 3
  pkill -9 -f "pCloud Drive" 2>/dev/null || true
  sleep 2
  open -a "pCloud Drive" 2>/dev/null || true
  log "pCloud Drive relaunched — cooldown starts now (${cooldown}s)"
  echo "$now" > "$STATE_FILE"
  rm -f "$FS_STRIKE_FILE"
}

# --- Check 1: is the process alive at all?
if ! pgrep -f "pCloud Drive" > /dev/null 2>&1; then
  restart_pcloud "pCloud Drive process not found"
  log "heartbeat: $(mem_summary)"
  exit 0
fi

# --- Check 2: does the FUSE filesystem actually respond? (process can be alive but hung)
if fs_probe; then
  rm -f "$FS_STRIKE_FILE"
  log "heartbeat: $(mem_summary)"
  exit 0
fi

STRIKES=1
[[ -f "$FS_STRIKE_FILE" ]] && STRIKES=$(( $(cat "$FS_STRIKE_FILE" 2>/dev/null || echo 0) + 1 ))

if (( STRIKES >= 2 )); then
  restart_pcloud "pCloud Drive process alive but filesystem unresponsive for 2 consecutive checks"
else
  echo "$STRIKES" > "$FS_STRIKE_FILE"
  log "pCloud Drive filesystem probe failed (strike ${STRIKES}/2) — confirming next run before restarting"
fi
log "heartbeat: $(mem_summary)"

# --- Rotate log if > 200KB
LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
if (( LOG_SIZE > 204800 )); then
  mv "$LOG_FILE" "${LOG_FILE}.1"
  log "Log rotated"
fi
