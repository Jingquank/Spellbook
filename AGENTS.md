# Working in Spellbook

Spellbook shows every skill Install on the machine as one book, opened by a coding agent from a
skill. The tab reads and annotates; the agent is the only writer. It is a visualizer, not a skill
manager: never add grouping, renaming or dismissal controls to the tab.

Read before changing anything:

- `CONTEXT.md`: the glossary. Use its terms in code, tests, accessibility names and docs.
- `DESIGN.md`: how the book looks and behaves. `design/tokens.css` holds the constants.
- `docs/adr/`: decisions already made. Do not reverse one without a new ADR.
- `docs/plans/`: the newest dated plan is the current work. As of 2026-09-07 that is
  `docs/plans/2026-09-07-origin-and-one-voice.md`, which is also a full handoff.

Layout: `server/` is plain Node with no dependencies (`scan.mjs` builds the Survey, `server.mjs`
serves it); `app/` is React + Vite built into `app/dist`; `skills/spellbook/` is the installable
skill and launcher. `npm run typecheck`, `npm run build`, `npm run scan -- --compact`.

Ask before committing. Never write into a skill folder except in response to a Brief.
