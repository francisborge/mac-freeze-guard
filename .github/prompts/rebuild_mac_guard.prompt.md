---
description: >
  Rebuild the mac-freeze-guard setup from scratch — four launchd agents (memory watchdog
  every 15 min, memory-pressure watchdog every 5 min, nightly refresh at 04:20, weekly
  reboot Sunday 03:00) that prevent Finder/pCloud Drive freezes and total-system freezes on
  Apple Silicon Macs under high RAM/uptime pressure. Use this when recovering after a system
  failure or fresh macOS install, or to verify the current setup matches the spec.
agent: agent
---

# Mac Freeze Guard — Rebuild Workflow

You are a macOS systems engineer. Rebuild or verify the mac-freeze-guard launchd setup on this machine by following the steps below in order.

## Context

My Mac (Apple M5 Pro, 24 GB RAM, macOS Sequoia/Sonoma, 3 displays: built-in Retina + 2× Dell 4K external) experiences freezes ranging from partial (**Finder and pCloud Drive unresponsive**) to total system freezes requiring a hard reboot, typically after several days of uptime.

**Root cause (diagnosed from system logs, most recently the Sep 1 2026 freeze):**
1. Uptime climbs for days without a reboot (13 days measured before the Sep 1 freeze) while swap I/O and the memory compressor grow (~10GB compressed, ~200MB free RAM at the last healthy snapshot).
2. A memory-heavy background app left running continuously adds several more GB of resident memory.
3. Memory hits Critical Pressure. pCloud Drive's FUSE-based kernel filesystem can stall under this pressure, holding kernel VFS locks — Finder deadlocks waiting for filesystem responses. Under severe enough pressure the whole system stops responding, including this project's own watchdog scripts, and only a hard reboot recovers it.
4. A watchdog that only checks whether the pCloud process is running (`pgrep`) cannot catch a hung-but-alive process — it must also probe the filesystem, confirmed across 2 consecutive checks to avoid false positives from normal sync stalls.

**Critical deployment constraint:**
Scripts must live in `~/Library/Scripts/freeze_guard/`, NOT `~/Downloads/`. macOS TCC prevents launchd agents from executing scripts in `~/Downloads/`. `StandardOutPath`/`StandardErrorPath` must point to `~/Library/Logs/freeze_guard/` — launchd exits with code 78 if it cannot create or open log files there. All script logs and status snapshots also live under `~/Library/Logs/freeze_guard/` — there is no other log location for this project.

---

## Step 1 — Check current state

Run the following and show output:

```bash
launchctl list | grep 'com.francisco'
ls ~/Library/Scripts/freeze_guard/ 2>/dev/null || echo "Scripts dir missing"
ls ~/Library/LaunchAgents/com.francisco.*.plist 2>/dev/null || echo "Plists missing"
ls ~/Library/Logs/freeze_guard/ 2>/dev/null || echo "Log dir missing"
```

Report which components exist and which are missing. If all four artifacts exist and both agents appear in `launchctl list` with exit code 0 (the second column), confirm the setup is healthy and stop. If either agent shows a non-zero exit code or is missing a PID where one is expected, continue to Step 4.

If only some components are missing, unload any currently loaded agents before running setup.sh:

```bash
launchctl unload ~/Library/LaunchAgents/com.francisco.*.plist 2>/dev/null
```

Then proceed with the full setup.

---

## Step 2 — Locate repo

Check if the repo is already cloned (the canonical location syncs via pCloud Drive):

```bash
ls "$HOME/pCloud Drive/Hochschule Luzern/HSLU/projects/mac-freeze-guard/setup.sh" 2>/dev/null || \
  ls ~/mac-freeze-guard/setup.sh 2>/dev/null || \
  ls ~/Projects/mac-freeze-guard/setup.sh 2>/dev/null || \
  echo "Repo not found"
```

If the repo is found at any path, use that path for `cd` in Step 3. Do not re-clone if already present at any location.

If not found, clone it (prefer cloning under the pCloud Drive folder so it syncs across machines):

```bash
git clone https://github.com/francisborge/mac-freeze-guard.git ~/mac-freeze-guard
cd ~/mac-freeze-guard
```

If git clone fails, stop and report the error message. Do not proceed to Step 3. Ask the user to verify network access and the repository URL before retrying.

---

## Step 3 — Run setup

```bash
cd ~/mac-freeze-guard   # or wherever it was cloned
bash setup.sh
```

If setup.sh exits with a non-zero code, print the full terminal output and stop. Do not proceed to Step 4 until setup.sh completes successfully.

`setup.sh` will:
- Create `~/Library/Scripts/freeze_guard/` and copy all four scripts
- Create `~/Library/Logs/freeze_guard/` and pre-create log files with `touch`
- Copy all four plists to `~/Library/LaunchAgents/`
- Load all four agents with `launchctl load`

After `launchctl load`, immediately run `launchctl list | grep 'com.francisco'`. If an agent is absent, run `plutil -lint ~/Library/LaunchAgents/com.francisco.<name>.plist` to check for plist errors and report the result.

---

## Step 4 — Verify

```bash
launchctl list | grep 'com.francisco'
```

Expected output:
```
<PID>  0  com.francisco.memory-watchdog    ← running, probes every 15 min
-      0  com.francisco.nightly-refresh    ← scheduled for 04:20
```

If `memory-watchdog` is missing a PID, run:

```bash
launchctl start com.francisco.memory-watchdog
launchctl list | grep 'com.francisco'
```

If exit code is non-zero, check:

```bash
cat ~/Library/Logs/freeze_guard/watchdog_stdout.log
cat ~/Library/Logs/freeze_guard/watchdog_stderr.log
```

If the stderr log contains `No such file or directory` for the script path, the scripts were not copied correctly — re-run setup.sh. If it contains `Permission denied`, run `chmod +x ~/Library/Scripts/freeze_guard/memory_watchdog.sh` and retry. If the error is unrecognized, paste the full log content and stop for user input.

---

## Step 5 — Manual smoke test

Force a watchdog probe to confirm pCloud detection works:

1. Run the script:

```bash
bash ~/Library/Scripts/freeze_guard/memory_watchdog.sh
```

2. Check exit code: if non-zero, the script failed — inspect stderr.

3. Read the log:

```bash
tail -5 ~/Library/Logs/freeze_guard/watchdog_stdout.log
```

4. Pass/fail: if the file contains a line with a timestamp and either `pCloud OK` or a restart event, the setup is working. If the file is empty or does not exist, the log path is misconfigured — re-run setup.sh.

---

## Agent reference

| Agent | Trigger | Script | Log |
|---|---|---|---|
| `memory_watchdog` | Every 15 min | `~/Library/Scripts/freeze_guard/memory_watchdog.sh` | `~/Library/Logs/freeze_guard/watchdog_stdout.log` |
| `memory_pressure_watchdog` | Every 5 min | `~/Library/Scripts/freeze_guard/memory_pressure_watchdog.sh` | `~/Library/Logs/freeze_guard/pressure_stdout.log` |
| `nightly_refresh` | 04:20 daily | `~/Library/Scripts/freeze_guard/nightly_refresh.sh` | `~/Library/Logs/freeze_guard/nightly_stdout.log` |
| `weekly_reboot` | Sunday 03:00 | `~/Library/Scripts/freeze_guard/weekly_reboot.sh` | `~/Library/Logs/freeze_guard/reboot_stdout.log` |

launchd stdout/stderr → `~/Library/Logs/freeze_guard/`
