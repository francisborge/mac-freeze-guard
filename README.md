# mac-freeze-guard

Prevents **Finder + pCloud Drive freeze** on macOS with multi-monitor setups and high RAM usage. Two launchd agents: a 15-minute watchdog that detects and recovers a frozen pCloud filesystem, and a nightly refresh that restarts Dock + pCloud Drive to clear memory leaks.

## The problem

On Apple Silicon Macs running near full RAM (24GB used by WindowServer, Chrome, VS Code, Outlook, WhatsApp, and other background apps), sustained memory pressure builds up over days of uptime — swap I/O climbs, the memory compressor grows, and eventually either pCloud Drive's FUSE kernel filesystem stalls (holding kernel VFS locks and deadlocking Finder) or the whole system stops responding entirely.

Root cause chain (diagnosed from system logs, most recently the Sep 1 2026 freeze that needed a hard reboot):
1. Uptime climbs for days without a reboot (13 days at the time of the Sep 1 freeze) while swap I/O and the memory compressor grow (~10GB compressed, ~200MB free RAM at the last healthy snapshot before the freeze).
2. A memory-heavy background app left running continuously (e.g. a device-companion app only needed occasionally) adds several more GB of resident memory.
3. Memory hits Critical Pressure; pCloud's FUSE filesystem can stall and hold kernel VFS locks, deadlocking Finder — or, under severe enough pressure, the whole system (including this project's own watchdog scripts) stops responding and needs a hard reboot.
4. A watchdog that only checks whether the pCloud process is still running (`pgrep`) cannot catch a hung-but-alive process — it has to probe the filesystem itself too (see `memory_watchdog.sh`).

## Solution

| Agent | Trigger | Action |
|---|---|---|
| `memory_watchdog` | Every 15 min | Checks pCloud is running, then probes the filesystem. Requires 2 consecutive failed probes (~15 min apart) before restarting pCloud — avoids false positives from normal sync stalls |
| `nightly_refresh` | 04:20 every night | Restart Dock + pCloud Drive to clear accumulated memory leaks; prunes 30-day-old status snapshots |
| `memory_pressure_watchdog` | Every 5 min | Checks system memory-pressure level. On 2 consecutive critical readings, sends a notification (with a 30-min cooldown) so you can save work before a freeze. Notify-only — never kills processes automatically |
| `weekly_reboot` | Sunday 03:00 | Gracefully restarts the Mac (`System Events` restart) to reset the long-uptime memory/compressor buildup that preceded the Sep 1 freeze |

**Finder is never restarted automatically** — that would lose your Finder session.

## Recovery (after system failure or fresh macOS install)

```bash
# 1. Clone the repo
git clone https://github.com/francisborge/mac-freeze-guard.git
cd mac-freeze-guard

# 2. Run setup (creates dirs, installs scripts + plists, loads agents)
bash setup.sh

# 3. Verify
launchctl list | grep francisco
```

Expected output:
```
<PID>  0  com.francisco.memory-watchdog            ← running, probes every 15 min
<PID>  0  com.francisco.memory-pressure-watchdog   ← running, probes every 5 min
-      0  com.francisco.nightly-refresh             ← scheduled for 04:20
-      0  com.francisco.weekly-reboot               ← scheduled Sunday 03:00
```

## File locations after setup

| File | Location |
|---|---|
| Watchdog script | `~/Library/Scripts/freeze_guard/memory_watchdog.sh` |
| Nightly script | `~/Library/Scripts/freeze_guard/nightly_refresh.sh` |
| Memory-pressure watchdog script | `~/Library/Scripts/freeze_guard/memory_pressure_watchdog.sh` |
| Weekly reboot script | `~/Library/Scripts/freeze_guard/weekly_reboot.sh` |
| Watchdog plist | `~/Library/LaunchAgents/com.francisco.memory-watchdog.plist` |
| Nightly plist | `~/Library/LaunchAgents/com.francisco.nightly-refresh.plist` |
| Memory-pressure watchdog plist | `~/Library/LaunchAgents/com.francisco.memory-pressure-watchdog.plist` |
| Weekly reboot plist | `~/Library/LaunchAgents/com.francisco.weekly-reboot.plist` |
| All script logs, snapshots, launchd stdout/err | `~/Library/Logs/freeze_guard/` (single location — there is no other log path for this project) |

Log files are local only and not tracked in this repo.

## Rebuild with AI

See [.github/prompts/rebuild_mac_guard.prompt.md](.github/prompts/rebuild_mac_guard.prompt.md) for a complete prompt you can paste into GitHub Copilot or any AI assistant to rebuild this setup from scratch, even without this repo.

## Why scripts are in `~/Library/Scripts/` not `~/Downloads/`

macOS TCC (privacy framework) prevents launchd agents from executing scripts in `~/Downloads/`. Scripts must be in `~/Library/Scripts/`. Similarly, launchd `StandardOutPath`/`StandardErrorPath` log files must either pre-exist or point to `~/Library/Logs/` — launchd exits with code 78 if it cannot open them.
