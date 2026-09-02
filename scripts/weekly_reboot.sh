#!/usr/bin/env bash
# weekly_reboot.sh — Runs Sunday 03:00 via launchd.
# Resets the long-uptime memory/compressor buildup that preceded the Sep 1 2026 freeze
# (13-day uptime, ~10GB compressor, ~200MB free RAM). Graceful AppleScript restart —
# respects unsaved-changes dialogs, so a reboot can be silently skipped if one is blocking;
# that's an accepted tradeoff over a forced `shutdown -r now`, which would need passwordless sudo.

LOG_DIR="$HOME/Library/Logs/freeze_guard"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/weekly_reboot.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>&1; }

log "=== Weekly reboot START — uptime: $(uptime) ==="

osascript -e 'display notification "Restarting in 3 minutes to clear memory/uptime buildup. Save your work now." with title "Scheduled Weekly Restart" sound name "Basso"' 2>/dev/null || true

sleep 180

log "Issuing restart"
osascript -e 'tell application "System Events" to restart' 2>>"$LOG_FILE" || log "Restart command failed or was blocked (e.g. unsaved-changes dialog)"

log "=== Weekly reboot END (if you're reading this in the same log session, the restart did not happen) ==="
