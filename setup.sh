#!/usr/bin/env bash
# setup.sh — One-shot recovery script for mac-freeze-guard.
# Run this after cloning the repo to restore the full freeze-prevention setup.
# Safe to re-run: it overwrites existing files and reloads agents cleanly.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DEST="$HOME/Library/Scripts/freeze_guard"
LOG_DEST="$HOME/Library/Logs/freeze_guard"
LAUNCHD_DEST="$HOME/Library/LaunchAgents"

SCRIPTS=(nightly_refresh.sh memory_watchdog.sh memory_pressure_watchdog.sh weekly_reboot.sh)
LABELS=(com.francisco.nightly-refresh com.francisco.memory-watchdog com.francisco.memory-pressure-watchdog com.francisco.weekly-reboot)

echo "=== mac-freeze-guard: recovery setup ==="
echo "Repo: $REPO_DIR"

# --- 1. Create required directories
echo "[1/5] Creating directories..."
mkdir -p "$SCRIPT_DEST"
mkdir -p "$LOG_DEST"

# --- 2. Install scripts
echo "[2/5] Installing scripts..."
for SCRIPT in "${SCRIPTS[@]}"; do
  cp "$REPO_DIR/scripts/$SCRIPT" "$SCRIPT_DEST/"
  chmod +x "$SCRIPT_DEST/$SCRIPT"
done

# --- 3. Pre-create launchd log files
# launchd cannot create new files in ~/Library/Logs/ without them existing first.
echo "[3/5] Pre-creating launchd log files..."
touch "$LOG_DEST/nightly_stdout.log" "$LOG_DEST/nightly_stderr.log"
touch "$LOG_DEST/watchdog_stdout.log" "$LOG_DEST/watchdog_stderr.log"
touch "$LOG_DEST/pressure_stdout.log" "$LOG_DEST/pressure_stderr.log"
touch "$LOG_DEST/reboot_stdout.log" "$LOG_DEST/reboot_stderr.log"

# --- 4. Install launchd plists
echo "[4/5] Installing launchd agents..."
for LABEL in "${LABELS[@]}"; do
  cp "$REPO_DIR/launchd/$LABEL.plist" "$LAUNCHD_DEST/"
done

# --- 5. Load agents (unload first in case they are already registered)
echo "[5/5] Loading launchd agents..."
USER_ID=$(id -u)

for LABEL in "${LABELS[@]}"; do
  launchctl bootout "gui/$USER_ID/$LABEL" 2>/dev/null || \
    launchctl unload "$LAUNCHD_DEST/$LABEL.plist" 2>/dev/null || true
done

sleep 1

for LABEL in "${LABELS[@]}"; do
  launchctl bootstrap "gui/$USER_ID" "$LAUNCHD_DEST/$LABEL.plist" 2>/dev/null || \
    launchctl load "$LAUNCHD_DEST/$LABEL.plist"
done

echo ""
echo "=== Setup complete ==="
echo "Verify with:"
echo "  launchctl list | grep francisco"
echo ""
echo "Expected output:"
echo "  <PID>  0  com.francisco.memory-watchdog            (running, every 15 min)"
echo "  <PID>  0  com.francisco.memory-pressure-watchdog   (running, every 5 min)"
echo "  -      0  com.francisco.nightly-refresh             (scheduled for 04:20)"
echo "  -      0  com.francisco.weekly-reboot               (scheduled Sun 03:00)"
echo ""
echo "Logs are written to: $LOG_DEST/"
echo "  memory_watchdog.log           — pCloud freeze detections and restarts"
echo "  memory_pressure_watchdog.log  — system memory-pressure heartbeat + alerts"
echo "  nightly_refresh.log           — nightly Dock + pCloud Drive restarts"
echo "  weekly_reboot.log             — weekly scheduled restart"
