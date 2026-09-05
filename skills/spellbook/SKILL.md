---
name: spellbook
description: Open Spellbook, a browser tab that shows every skill Install in this project and on this device as one book, lets the user read a skill, leave Notes and send you a Brief. Use when the user types /spellbook, asks what skills are installed, or wants to review or edit a skill with you.
user-invocable: true
disable-model-invocation: true
argument-hint: [start | wait-brief | rescan | stop]
---

# Spellbook

Spellbook is a temporary interface. You open it, the user reads and annotates in it, and every
change comes back to you as a Brief. The tab never writes to disk; you are the only writer.

## Open it

```bash
node "$SKILL_DIR/scripts/spellbook.mjs" start --project "$PWD"
```

`$SKILL_DIR` is this skill's folder. The script starts the local server if it is not running,
opens the browser tab, and prints the URL. Tell the user the tab is open, in one line.

## Wait for Briefs

```bash
node "$SKILL_DIR/scripts/spellbook.mjs" wait-brief --timeout 600
```

This blocks until the user sends a Brief, then prints it and exits 0. Each run prints exactly
one Brief; run it again for the next. A Brief names a file, quotes
the lines the user highlighted, and carries their Notes. Read it, make the change with your own
tools (Read, Edit), and say what you changed. The tab reloads the file the moment it changes on
disk, so there is nothing to send back.

Exit 3 means no Brief arrived within the timeout; ask the user whether to keep waiting, and run
`wait-brief` again if so. Exit 2 means the server is gone; run `start` again.

Loop `wait-brief` until the user says they are done.

## Rules

- Never write to a skill folder except in response to a Brief, and only the change it asks for.
- An Inferred Install ("Installed together, 1 Aug") is a guess. Say so if you refer to it.
- Drift is a state, not an error: the same skill differs between agent roots. Report it; do not
  reconcile it unless a Brief asks.
- The user may name or dismiss a guessed group in the tab; that lives in their browser, not on
  disk. Do not "fix" it.

## Other commands

- `status`: is the server running for this project, and where.
- `rescan`: re-read the roots after you add or remove a skill.
- `stop`: shut the server down when the user is finished.
