## Personal Context — Read First

Before reading any project files or starting any workflow in this project, read the AI Operating System file. It is expected at:

`${workspaceFolder}/.ai/ai_os_fb.txt`

If the model cannot access this file directly, or if the file cannot be found or read, stop and notify the user with: "I could not access ai_os_fb.txt at the expected path. Please paste its contents here so I can apply your personal context before continuing."

This file defines the user's identity, communication preferences, current goals, daily schedule, and working constraints. Apply the preferences, goals, and constraints defined in that file to every response in this project — including tone, language, formatting, and scheduling constraints. If a response topic is not covered by the file, use your default behavior.

If a user request conflicts with a constraint defined in the file (e.g., scheduling outside working hours), surface the conflict explicitly and propose an alternative that respects the constraint rather than silently complying or refusing.
