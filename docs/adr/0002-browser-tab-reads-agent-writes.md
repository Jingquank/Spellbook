# 2. The browser tab reads and annotates; the agent is the only writer

Date: 2026-09-05

## Status

Accepted.

## Context

Spellbook's next form is a temporary interface: `/spellbook` in Claude Code, Codex or
Cursor opens a browser tab showing every Install on the machine, and the user reads a
skill there, highlights a range, writes a Note, and wants the change made. The retired
macOS app could edit, update and remove skills itself, and carried the mutation plans,
checkpoints, recovery journal and diff previews that safe direct writes demand. A browser
tab that also writes would need all of it again, and would then compete with the agent
for the same files.

Two transports were considered for getting Notes to the agent: a clipboard block the user
pastes into the chat, and a small local server the skill starts and the agent polls. The
`impeccable` skill on this machine already uses the second shape.

## Decision

The browser tab never writes to disk. Every change, including rename, remove and update,
is a Brief sent to the agent, which edits the files with its own tools and its own
permission model. The skill that opens the tab also starts a local server; the tab posts
Briefs to it, the agent picks them up, and the tab reloads the skill when the file changes.
Clipboard copy of a Brief remains available as a fallback for agents without the server.

## Consequences

- No mutation, preview or recovery machinery in the browser. One writer, one permission
  prompt, one audit trail: the agent's.
- Layout state the tab owns (Canvas positions, Inferred Install names, dismissals) lives
  in browser storage keyed by project, not in the skill tree.
- The tab is only as live as the server. Without it the Survey is still readable and
  Briefs still copy; only delivery state and reload are lost.
- Because the agent applies edits, the Reader shows the result by reloading the file.
  It does not render its own diff; the agent's transcript is where the change is explained.
