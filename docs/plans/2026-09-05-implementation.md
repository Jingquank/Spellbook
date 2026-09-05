# Spellbook implementation plan

Date: 2026-09-05. Follows the design brief and ADRs 0002 and 0003.

## Shape

```
skills/spellbook/   SKILL.md and scripts/spellbook.mjs (start, wait-brief, stop)
server/             Node ESM, no dependencies: scan.mjs, model.mjs, server.mjs, briefs.mjs
app/                Vite + React + TypeScript, built to app/dist
design/             tokens, fonts, icons, thumbnails.js (shared by the app)
```

## Steps

1. **Scanner.** Enumerate roots for the project and the device, resolve symlinks, read
   frontmatter, list files, detect Recorded Installs (Bench manifests, plugin manifests, Codex
   system), cluster the rest by install day into Inferred Installs, leave Loose Skills, and
   compute Drift between copies. Output the Survey JSON the prototypes used.
2. **Server.** Serve `app/dist`, the Survey, file contents restricted to Markdown and text inside a
   skill folder, a Brief queue, SSE for file changes and Brief pickup, and a rescan route. Open the
   browser on start.
3. **Skill.** SKILL.md tells the agent to start the server, open the tab, then loop on
   `wait-brief`, applying each Brief with its own tools. `stop` ends the server.
4. **App.** Port the round-three book: title bar with a cmdk palette, contents page in both
   Registers, Reader with tabs and Notes, Brief sending, Settings spread. State in zustand,
   appearance through next-themes, toasts through Sonner, popovers and menus through base-ui.
5. **Run it here.** Build the app, start the server against this repo, verify the Survey matches
   the prototype's twelve Installs, send a Brief from the tab, receive it with `wait-brief`.

## Status, 2026-09-05

Steps 1 to 5 done. `npm run build` produces `app/dist`; `node skills/spellbook/scripts/spellbook.mjs start` scans this machine into ten device Installs and the project's own `spellbook` skill, serves the book, and a Brief posted from the tab reached `wait-brief`, whose requested edit came back to the tab as a `changed` event. Browser automation could not drive the tab's Send Brief button in this session (the extension disconnected); the same request was sent through the API.

## Critique pass, 2026-09-05

`/impeccable critique` scored the tab 26/40 (snapshot in `.impeccable/critique/`). Every recommended command was run in one pass: agent actions are Briefs (drift reconcile, open in editor); contrast, type sizes, Increase Contrast reachability, tree roles, live regions and tab keys fixed; Undo on dismissing a guessed group; the title bar and Reader de-duplicated; notes re-anchor after a reload and the history says "applied" only when a quoted passage changed. The contents page was redesigned from a four-option artifact (Contents Page Options): option A, Index, became the single row model for both Registers, with actions revealed on hover or focus and page numbers that follow the shared sort. `ContentsProse.tsx` and `ContentsMono.tsx` were replaced by `Contents.tsx`.

## Motion pass, 2026-09-05

`/find-animation-opportunities` proposed six moments and rejected seven; all six were prototyped (artifact "Six Motions"), the fold got eight further variations (artifact "Nine Unfolds"), the user chose Unfurl, and the six are implemented in `app.css` with `@starting-style`, Base UI's `data-starting-style`/`data-ending-style`, and a grid-row height transition. The Notes margin was also relaid: three groups, the add action in the head, room for focus rings.

## Not in this pass

- Cursor and Gemini roots beyond detection of copies. Marks are shown; no agent-specific launch.
- Anchored-note highlights in browsers without the CSS Custom Highlight API. The Note still
  records the quote and lines.
- Committing `app/dist`. Build locally with `npm run build` until a release process exists.
