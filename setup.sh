#!/usr/bin/env bash
# setup.sh — One-shot recovery script for mac-freeze-guard.
# Run this after cloning the repo to restore the full freeze-prevention setup.
# Safe to re-run: it overwrites existing files and reloads agents cleanly.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DEST="$HOME/Library/Scripts/freeze_guard"
LOG_DEST="$HOME/Library/Logs/freeze_guard"
LAUNCHD_DEST="$HOME/Library/LaunchAgents"
MAC_LOG_DIR="$HOME/Downloads/mac_freeze_fix"

echo "=== mac-freeze-guard: recovery setup ==="
echo "Repo: $REPO_DIR"

# --- 1. Create required directories
echo "[1/5] Creating directories..."
mkdir -p "$SCRIPT_DEST"
mkdir -p "$LOG_DEST"
mkdir -p "$MAC_LOG_DIR"

# --- 2. Install scripts
echo "[2/5] Installing scripts..."
cp "$REPO_DIR/scripts/nightly_refresh.sh"  "$SCRIPT_DEST/"
cp "$REPO_DIR/scripts/memory_watchdog.sh"  "$SCRIPT_DEST/"
chmod +x "$SCRIPT_DEST/nightly_refresh.sh"
chmod +x "$SCRIPT_DEST/memory_watchdog.sh"

# --- 3. Pre-create launchd log files
# launchd cannot create new files in ~/Library/Logs/ without them existing first.
echo "[3/5] Pre-creating launchd log files..."
touch "$LOG_DEST/nightly_stdout.log"
touch "$LOG_DEST/nightly_stderr.log"
touch "$LOG_DEST/watchdog_stdout.log"
touch "$LOG_DEST/watchdog_stderr.log"

# --- 4. Install launchd plists
echo "[4/5] Installing launchd agents..."
cp "$REPO_DIR/launchd/com.francisco.nightly-refresh.plist"  "$LAUNCHD_DEST/"
cp "$REPO_DIR/launchd/com.francisco.memory-watchdog.plist"  "$LAUNCHD_DEST/"

# --- 5. Load agents (unload first in case they are already registered)
echo "[5/5] Loading launchd agents..."
USER_ID=$(id -u)

for LABEL in com.francisco.nightly-refresh com.francisco.memory-watchdog; do
  launchctl bootout "gui/$USER_ID/$LABEL" 2>/dev/null || \
    launchctl unload "$LAUNCHD_DEST/$LABEL.plist" 2>/dev/null || true
done

sleep 1

launchctl bootstrap "gui/$USER_ID" "$LAUNCHD_DEST/com.francisco.nightly-refresh.plist" 2>/dev/null || \
  launchctl load "$LAUNCHD_DEST/com.francisco.nightly-refresh.plist"

launchctl bootstrap "gui/$USER_ID" "$LAUNCHD_DEST/com.francisco.memory-watchdog.plist" 2>/dev/null || \
  launchctl load "$LAUNCHD_DEST/com.francisco.memory-watchdog.plist"

echo ""
echo "=== Setup complete ==="
echo "Verify with:"
echo "  launchctl list | grep francisco"
echo ""
echo "Expected output:"
echo "  <PID>  0  com.francisco.memory-watchdog   (running)"
echo "  -      0  com.francisco.nightly-refresh    (scheduled for 04:20)"
echo ""
echo "Logs are written to: $MAC_LOG_DIR/"
echo "  memory_watchdog.log  — pCloud freeze detections and restarts"
echo "  nightly_refresh.log  — nightly Dock + pCloud Drive restarts"
