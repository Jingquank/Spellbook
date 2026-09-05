# 3. The tab is a Vite-built React app served by a dependency-free Node server the skill starts

Date: 2026-09-05

## Status

Accepted.

## Context

ADR 0002 made the tab a read-and-annotate surface driven by a skill-launched local server. The
prototypes were single HTML files with hand-written DOM code; the real tab needs popovers, menus, a
command palette, toasts, a theme switch and a shared store, and it must be runnable from a skill
with nothing installed but Node.

## Decision

Two parts with one contract between them.

- **Server** (`server/`): plain Node 20+ ESM using only `node:` modules. It scans the roots, builds
  the Survey, serves the built app and a small JSON API (`/api/survey`, `/api/file`,
  `/api/briefs`, `/api/events` over SSE, `/api/rescan`), queues Briefs for the agent, and watches
  the skill roots so the tab can reload a file the agent changed. The skill runs it with
  `node`; there is no install step on the user's machine.
- **App** (`app/`): React with TypeScript, built by Vite into static files the server hosts.
  Libraries, from the studio's curated list: base-ui for popovers, menus and toggle groups; cmdk
  for the palette; Sonner for toasts; shiki for code blocks; next-themes for the appearance
  attribute; zustand with persistence for prefs, notes and group state; cva and clsx for
  variants and classes. Markdown renders through react-markdown with remark-gfm. Notes anchor with
  the native Selection and Range APIs and the CSS Custom Highlight API.
- **Skill** (`skills/spellbook/`): SKILL.md plus a launcher script. The agent starts the server,
  then repeatedly runs `wait-brief`, which blocks until a Brief arrives and prints it.

## Considered options

- Keep the vanilla single-file approach. Rejected: the note flow, palette and settings already
  outgrew it in the prototype, and every accessible primitive would be hand-rolled.
- A framework server (Express, Hono) or a bundled binary. Rejected: the server is a skill's helper
  and must run from a bare `node` with no install; the API is six routes.
- Next.js. Rejected: no routing, no SSR, one page.

## Consequences

- The app build (`app/dist`) is committed or built before use; the skill never runs `npm install`.
- The server has zero runtime dependencies and can be audited in one sitting.
- Library churn is confined to `app/`; the API is the stable seam.
