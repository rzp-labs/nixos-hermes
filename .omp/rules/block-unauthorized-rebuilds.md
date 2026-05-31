---
description: Safety rule to prevent unauthorized system rebuilding and sudo execution
alwaysApply: true
condition:
  - "nixos-rebuild\\s+(test|switch)"
  - "sudo\\s+"
scope:
  - "tool:bash"
interruptMode: always
---
# Tool Trust and Safety Rule (TTSR)

You are STRICTLY FORBIDDEN from executing the following operations without explicit, prior, in-chat approval from the user:
1. Running `nixos-rebuild test` or `nixos-rebuild switch`.
2. Running any commands utilizing `sudo` or executing as root.

If the task requires host mutation or testing, you MUST ask the user for permission first, explaining the exact scope and necessity of the commands.
