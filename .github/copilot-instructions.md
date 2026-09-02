## Personal Context — Read First

Before reading any project files or starting any workflow in this project, read the AI Operating System file. It is expected at:

`${workspaceFolder}/.ai/ai_os_fb.txt`

If the model cannot access this file directly, or if the file cannot be found or read, stop and notify the user with: "I could not access ai_os_fb.txt at the expected path. Please paste its contents here so I can apply your personal context before continuing."

This file defines the user's identity, communication preferences, current goals, daily schedule, and working constraints. Apply the preferences, goals, and constraints defined in that file to every response in this project — including tone, language, formatting, and scheduling constraints. If a response topic is not covered by the file, use your default behavior.

If a user request conflicts with a constraint defined in the file (e.g., scheduling outside working hours), surface the conflict explicitly and propose an alternative that respects the constraint rather than silently complying or refusing.

## Project overview

mac-freeze-guard prevents Finder + pCloud Drive freezes on macOS caused by memory/swap
pressure and FUSE filesystem hangs. Two (soon more) launchd agents automate detection and
recovery. See [README.md](../README.md) for the full problem statement and agent table.

## Conventions

- Scripts are installed to `~/Library/Scripts/freeze_guard/`, never run from `~/Downloads/` —
  macOS TCC blocks launchd from executing scripts there.
- All logs (script logs, launchd stdout/err, status snapshots) live under
  `~/Library/Logs/freeze_guard/`. There is no other log location for this project.
- `setup.sh` is the single idempotent installer: copies scripts + plists, pre-creates log
  files (launchd fails with exit 78 if it can't open them), and bootstraps/reloads agents.
- Finder is never restarted automatically — that would lose the user's Finder session.

## Recovery workflow

1. Check current state: `launchctl list | grep francisco`, and confirm
   `~/Library/Scripts/freeze_guard/`, `~/Library/LaunchAgents/com.francisco.*.plist`, and
   `~/Library/Logs/freeze_guard/` all exist.
2. If the repo isn't cloned locally, clone it, then `cd` into it.
3. Run `bash setup.sh` (safe to re-run).
4. Verify with `launchctl list | grep francisco`; troubleshoot via the `*_stdout.log` /
   `*_stderr.log` files in `~/Library/Logs/freeze_guard/`.

A more detailed, branching version of this workflow (with troubleshooting steps for each
failure mode) is maintained as a Copilot prompt file at
[.github/prompts/rebuild_mac_guard.prompt.md](prompts/rebuild_mac_guard.prompt.md) — its
steps apply regardless of which agent is following them.
