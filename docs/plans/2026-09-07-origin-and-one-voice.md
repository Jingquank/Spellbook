# Origin grouping, one voice, one tab per project

Date: 2026-09-07. Status: decided in a `/grill-with-docs` interview with the owner; nothing built yet
except the glossary. This document is the handoff: any agent (Codex, Claude Code) can execute it
from a clean session. Read [CONTEXT.md](../../CONTEXT.md) first; it already carries the new terms.

## Handoff state

Done in this session, uncommitted on `main`:

- `CONTEXT.md`: Install is now "the skills that share one Origin"; Origin, Recorded Origin,
  Matched Origin, Hinted Origin added; Register, Recorded Install and Inferred Install removed;
  Settings no longer lists Register.
- `docs/adr/0004-group-installs-by-origin-evidence.md`: the decision record.
- `docs/adr/0002-browser-tab-reads-agent-writes.md`: one consequence amended.
- This plan.

Not started: everything under "Work". Run `git status` to see the four files above.

## The four requests

1. Opening Spellbook from a second project showed "Nothing here yet" and read as stale. It was
   correct (that project, `~/Code/pointee`, has no skill folders) but nothing said which project the
   tab was looking at, and every tab is titled "Spellbook".
2. The device chapter groups skills by install day ("Installed together, 6 Sep"), which puts
   unrelated skills together (ip-as-logo and show-me) and splits nothing usefully.
3. Skills need provenance: where an Install came from, so a later version can update it.
4. Every interface element set in Commit Mono should be redesigned in the interface face, and the
   Folio mono Register removed.

## Decisions

Numbered so the code and docs can cite them.

### Tabs and servers

- D1. One server and one tab per project, as today. The port is derived from the project path
  (hash into a fixed range, next free port as fallback) so the browser origin, and with it
  `localStorage`, is stable across restarts. Today the port is random, which silently loses every
  preference on restart.
- D2. The tab title carries the project name ("pointee · Spellbook"). The empty project chapter
  names the project and the exact folder that would become a section.
- D3. The rule for "From this project" is unchanged: only skill folders inside the project's
  `.claude/skills`, `.agents/skills`, `.codex/skills` count.
- D4. A server exits on its own after 30 minutes with no tab connected (no SSE client) and no agent
  waiting on `wait-brief`. The launcher gains `status --all` and `stop --all`.
- D5. `start` against a live server that already has a connected tab does not open another tab; it
  prints the URL. Today `open <url>` opens a duplicate tab every time.
- D6. The top level of every root is watched; a new folder with a `SKILL.md` triggers a debounced
  rescan without the user pressing Rescan.

### Grouping and Origin

- D7. Installs are grouped by Origin, never by install time. The Inferred Install and the
  "Installed together" label are gone.
- D8. The Origin unit is what the installer treated as one thing: the lockfile `source` repo for
  the Agent Skills CLI, one plugin for the plugin manifest, one pack for a pack manifest, one local
  repository for a symlink or text match. An Install is one per Origin whatever the install dates;
  each skill keeps its own dates.
- D9. Evidence grades. Recorded and Matched Origins form Installs; a Hinted Origin is shown as
  "probably …" on a Loose Skill and never groups; Unknown says unknown. Every Install says how its
  Origin was established.
- D10. Spellbook is a visualizer, not a manager. The tab offers no naming, dismissing or grouping
  controls and keeps no curation state in the browser. Remove "name it", "not a group", the Groups
  settings section, the `r` and `x` keys, and the `useGroups` store.
- D11. Naming. GitHub sources use the `owner/repo` slug ("emilkowalski/skills"); local
  repositories use the folder name ("Bench", "Mastermind", "Spellbook"); plugins keep the plugin
  name; a single-skill Install is named by its skill with the Origin as detail.
- D12. Bench's `.bench-install.json` counts as a Recorded pack Origin (name "Bench", version);
  matching adds the repository. Bench's installer is not changed.
- D13. Text matches found inside another project's skill roots (`*/.agents/skills/*`,
  `*/.claude/skills/*`, `*/.codex/skills/*`, `*/.gemini/skills/*`, `*/.cursor/skills/*`) never
  count as source. Lockfile entries whose folder is not on disk are ignored.
- D14. Origin surfaces: the contents row word replaces "recorded / plugin / guessed" with the
  Origin kind; the Reader head shows the full Origin, grade and what it matched; Settings gains a
  Records section listing every lockfile and manifest read. No update action in this version.

### Mono and Folio

- D15. Commit Mono remains only inside rendered code (`code`, `pre` in Markdown) and the Brief
  preview text. Every interface element moves to Schibsted Grotesk with tabular figures.
- D16. The Folio Register, the Register setting, the 13 px mono rows, the entry line counts and the
  "mono" tags in the Keys table are removed. One voice.
- D17. A design round comes first: one page showing the mono-free contents page, Reader head,
  footer, Settings rows and drift popover together with the Origin surfaces, on the real corpus,
  light and dark. The owner picks; then it is built and measured with an `/impeccable critique`.

## Facts found on this device

These are what the resolvers must read. Paths are real; formats were inspected.

### Agent Skills CLI lockfile: `~/.agents/.skill-lock.json`

Written by `npx skills add`. Shape:

```json
{ "version": 1, "skills": { "<skill-id>": {
    "source": "emilkowalski/skills", "sourceType": "github",
    "sourceUrl": "https://github.com/emilkowalski/skills.git",
    "skillPath": "skills/animation-vocabulary/SKILL.md",
    "skillFolderHash": "e6dc…", "installedAt": "2026-07-19T21:50:43.530Z",
    "updatedAt": "2026-08-01T22:50:34.184Z", "pluginName": "mattpocock-skills" } },
  "dismissed": [], "lastSelectedAgents": [] }
```

Skill id is the folder name under `~/.agents/skills`. The file also lists skills no longer on disk
(old pbakaus/impeccable verbs, many mattpocock entries); ignore those (D13). On this device it
covers: emilkowalski/skills (animation-vocabulary, apple-design, emil-design-eng,
find-animation-opportunities, improve-animations, review-animations, pick-ui-library, prototype),
mattpocock/skills (design-an-interface, domain-modeling, grill-with-docs, grill-me, grilling,
obsidian-vault), s1dashu/ip-as-logo-skill (ip-as-logo), humanlayer/skills (show-me).

### Claude plugins: `~/.claude/plugins/installed_plugins.json` and `known_marketplaces.json`

Each plugin key is `name@marketplace`; entries carry `installPath`, `version`, `installedAt`,
`lastUpdated`, `gitCommitSha`. `known_marketplaces.json` maps the marketplace to
`{ source: { source: "github", repo: "anthropics/claude-plugins-official" } }`. Origin per plugin
(D8): repo + `plugins/<name>` + commit.

### Bench pack manifest: `.bench-install.json` in `~/.claude/skills` and `~/.agents/skills`

`{ "version": "1.12.0", "skills": { "<id>": ["SKILL.md", …] } }`. No URL. Skills: writereport,
xray, drill, lore, grid, huh. The skill sources live in `~/Code/Bench` (`HUH.md`, `GRID.md`,
`DRILL.md`, `LORE.md`, `XRAY.md`, `WRITEREPORT.md`), remote `https://github.com/Jingquank/Bench.git`;
each installed skill's frontmatter description appears verbatim in its source file.

### Codex: `~/.codex/skills/.system/*`

Preinstalled from `openai/skills` (`skills/.system/<name>`), stated in the skill-installer's own
SKILL.md. Codex's `install-skill-from-github.py` downloads a zip and writes no record, so
`~/.codex/skills/hatch-pet` has no Origin (Unknown).

### Local repositories

- `~/Code/Spellbook`: `~/.claude/skills/spellbook` and `~/.agents/skills/spellbook` are symlinks into
  it. Remote `github.com/Jingquank/Spellbook`.
- `~/Code/Mastermind`: `master` and `mastermind` descriptions appear verbatim in
  `src/cli/index.ts` (and `dist/cli/index.js`). The `mastermind` CLI named in both skills resolves
  on PATH to the global npm package `mastermind-md@0.2.1`, whose `package.json` repository is
  `https://github.com/Jingquank/Mastermind.git`. Both skills exist as real copies in `~/.agents`,
  `~/.claude` and `~/.gemini`, all born 2026-07-26 00:12.
- Caveat (D13): `impeccable` also matched `~/Code/Mastermind/.agents/skills/impeccable/SKILL.md`,
  a project-level copy, not a source.

### Package caches, useful as corroboration only

`npm ls -g`: `skills@1.5.21`, `mastermind-md@0.2.1`, `impeccable@3.5.0`, `dialkit@2.0.0`.
`~/.npm/_npx/*/node_modules/<pkg>/package.json`: `bench@1.10.0` (repo Jingquank/Bench),
`impeccable@4.0.1` (repo pbakaus/impeccable), `skills@1.5.19/1.5.23` (vercel-labs/skills).

### Content hints (Hinted Origin, D9)

- `impeccable` (installed 4.2.0, real copies in `~/.agents`, `~/.claude`, `~/.gemini`, in Drift):
  links to `https://impeccable.style` and `https://github.com/pbakaus/impeccable/releases`.
- `interface-craft`: links to `https://github.com/joshpuckett/dialkit`.
- `aside-browser` (`version: 3`): links to `https://releases.aside.com/install.sh`; `Aside.app` is
  in `/Applications`.
- `master`: text says "Alias of /mastermind" (a companion reference; the Origin comes from the
  match above).

### Frontmatter keys seen across all 60 SKILL.md files

`name`, `description` (all), `disable-model-invocation` (16), `user-invocable` (9),
`argument-hint` (9), `metadata` (4), `version` (3), `license` (1), `allowed-tools` (1). No
`source`, `repository` or `homepage` key exists anywhere; do not rely on one.

### Expected device chapter after the change

| Install | Skills | Grade and evidence |
| --- | --- | --- |
| Bench | 6 | recorded pack 1.12.0; matched `~/Code/Bench` → Jingquank/Bench |
| Codex system skills | 6 | recorded, openai/skills |
| emilkowalski/skills | 8 | recorded, lockfile |
| mattpocock/skills | 6 | recorded, lockfile |
| Mastermind | 2 | matched `~/Code/Mastermind` → Jingquank/Mastermind, CLI `mastermind-md` |
| frontend-design | 1 | recorded plugin, anthropics/claude-plugins-official |
| notion | 4 | recorded plugin, anthropics/claude-plugins-official |
| ip-as-logo | 1 | recorded, s1dashu/ip-as-logo-skill |
| show-me | 1 | recorded, humanlayer/skills |
| aside-browser (Loose) | 1 | hinted: probably Aside |
| impeccable (Loose, Drift) | 1 | hinted: probably pbakaus/impeccable |
| interface-craft (Loose) | 1 | hinted: probably joshpuckett/dialkit |
| hatch-pet (Loose) | 1 | unknown |

Project chapter for this repository: Spellbook, 1 skill, matched local repository (symlink).

## Work

Order: 1 (design) can run in parallel with 2 and 3; 4 depends on 1 and 2; 5 follows 4.

### 1. Design round (D15, D16, D17)

One HTML page on the real corpus (use `npm run scan -- --compact` output), light and dark, showing:

- the contents page with chapter labels, Install rows carrying the Origin word, entries with page
  numbers, and the filter line, all in Schibsted Grotesk with `font-variant-numeric: tabular-nums`;
- the Reader head: crumb (thumbnail, Install name, Origin word, marks), title, description, and the
  metadata row (path, lines, files, updated) without mono;
- the footer, the Settings rows (Roots, the new Records section, no Register, no Groups), the Keys
  table without mono tags, and the drift popover.

In Claude Code publish it as an Artifact; in Codex write it under the session scratch directory and
open it in the browser. Show two or three treatments for the elements that are hardest without
mono (paths, the metadata row, page numbers) and let the owner pick. The interface type scale in
`DESIGN.md` (11 px micro, 12 px metadata, 14 px rows) still holds.

### 2. Scanner: Origin resolution (`server/scan.mjs`)

Data model, added to each Install and to each Loose Skill's wrapper:

```ts
interface Origin {
  kind: "github" | "plugin" | "pack" | "local" | "app" | "unknown";
  grade: "recorded" | "matched" | "hinted" | "unknown";
  name: string;          // display name per D11
  slug?: string;         // owner/repo
  url?: string;          // https://github.com/…, or the local repo path for kind local
  path?: string;         // path inside the repo (skillPath dir, plugins/<name>)
  ref?: string;          // commit sha or version when known
  version?: string;
  evidence: string[];    // human sentences: "recorded by the Agent Skills CLI lockfile", "matched ~/Code/Bench: description of huh found in HUH.md"
  record?: string;       // ~-path of the file that recorded it
}
```

Resolvers, in this order; the first recorded or matched hit wins, hints accumulate:

1. **Lockfile** `~/.agents/.skill-lock.json`: for each skill on disk whose id is a key, Origin
   kind github, grade recorded, slug = `source`, url = `sourceUrl`, path = dirname of `skillPath`,
   ref = `skillFolderHash`; installedAt/updatedAt become the skill's dates when present.
2. **Plugin manifest** (existing `pluginInstalls`): kind plugin, grade recorded, slug from
   `known_marketplaces.json`, path `plugins/<name>`, ref = `gitCommitSha`, version.
3. **Pack manifest** `.bench-install.json`: kind pack, grade recorded, name "Bench", version.
4. **Codex system root**: kind github, grade recorded, slug `openai/skills`, path
   `skills/.system/<name>`.
5. **Local repository by symlink**: if the skill's real path lies inside a directory that has a
   `.git`, kind local, grade matched, url = repo path, slug from `git config --get remote.origin.url`
   (read `.git/config` directly; no child process needed), name = folder name.
6. **Local repository by text**: for skills still without a recorded or matched Origin, search
   candidate repositories for a text file containing the skill's frontmatter description verbatim.
   Candidates: every git working copy directly under the parents of any local repo already found,
   plus `~/Code` and `~/Developer` if they exist; skip `node_modules`, `.git`, `dist`, files over
   2 MB, and any path under a skill root (D13). Cache results per scan. Two skills matching the
   same repo form one Install.
7. **CLI on PATH**: if the SKILL.md body names a command that resolves on PATH to a file inside a
   global npm package (`…/lib/node_modules/<pkg>/`), add evidence and, if no repo was found yet,
   kind github with the package's `repository` URL, grade matched only when combined with another
   fact (a text match or a package cache with the same name); otherwise hinted.
8. **Hints**: first GitHub URL in SKILL.md or README.md → hinted github; a
   `releases.<host>/install.sh` style URL or an app in `/Applications` whose name matches → hinted
   app; frontmatter `version` and `license` as detail.

Grouping: key = `kind + slug|url|name (+ plugin path for plugins)`. Recorded and matched Origins
group; hinted and unknown skills become Loose wrappers (existing `looseInstall`) carrying their
Origin. Delete `clusterInferred`. Install ids: `orig-` + sha1(key).slice(0, 8), stable across scans.
Survey gains `records: { path, kind, entries, read: boolean }[]` for Settings. Keep Drift and
`mergeCopies` as they are. `--compact` output must produce the table above on this device.

### 3. Server and launcher (D1, D4, D5, D6)

- `server/server.mjs`: `wantPort` defaults to `40000 + hash(project) % 10000`; on `EADDRINUSE`
  try the next port (max 20). `/api/health` returns `clients` (SSE count) and `waiters`. Idle timer:
  every minute, if `clients === 0 && waiters.length === 0` for 30 minutes, exit. Watch each root's
  top level (`fs.watch` non-recursive on the root dir) and rescan, debounced 500 ms, when a new
  directory gaining a `SKILL.md` appears. `flushChanges` unchanged for known skills.
- `skills/spellbook/scripts/spellbook.mjs`: `start` reads `/api/health`; if `clients > 0`, print
  the URL and do not `open`. Add `status --all` and `stop --all`, iterating
  `$TMPDIR/spellbook/*.json`, checking liveness, listing project, URL, pid, clients. Update the
  usage line and SKILL.md's "Other commands".
- `app/index.html` title stays "Spellbook"; `App.tsx` sets `document.title` to
  `<project> · Spellbook` once the Survey loads.

### 4. App (D2, D10, D14, D16)

- `store.ts`: delete `Register` and `useGroups`; `visibleInstalls` returns `survey.installs`
  unchanged (delete or inline it); `usePrefs` keeps width and text.
- `types.ts`: add `Origin`; `Kind` becomes `"install" | "loose"` or is replaced by `origin.grade`;
  remove `renamed`, `originalName`, `fromDismissed`; Survey gains `records`.
- `Book.tsx`: single class (`gr bk gr2` → rename to `gr bk`); drop the `mono` prop.
- `Contents.tsx`: remove the `mono` prop, `ln` spans, `r`/`x` handlers, `RenameInline`,
  `dismissWithUndo`, `ct-acts`, the guessed pill. Row word = Origin kind, with a title holding the
  first evidence sentence; hinted shows "probably <slug>". Empty chapter copy: "<project> has no
  skills of its own. A folder with a SKILL.md under <projectPath>/.claude/skills/ would appear
  here."
- `InstallBits.tsx`: delete `RenameInline`, the guessed branches in `Badges` and `Annotations`;
  add an `OriginLine` for the Reader head: kind, name, slug or path, ref, then the evidence
  sentences in secondary text.
- `Reader.tsx`: crumb shows the Origin word; head adds `OriginLine` under the metadata row.
- `Settings.tsx`: delete the Contents/Register section and the Groups section; add Records
  (each lockfile and manifest read: path, kind, entries); Keys table loses the `reg` spans and the
  `r`/`x` row; the nav list follows.
- `TitleBar.tsx`: project shown in the interface face, not `<code>`.
- `SKILL.md` rules: drop the Inferred Install sentence and the "name or dismiss" sentence; add
  "An Origin marked probably is a hint from the skill's own text; say so if you rely on it."

### 5. CSS (`app/src/styles/app.css`, D15)

Remove `font-family: var(--sb-font-code)` from: `.ct-hd .cnt`, `.ct-ch .n`, `.ct .pg`,
`.ct-ent .ln` (deleted), `.ct-in`, `.gr-ft`, `.rd-meta`, `.rd-tab`, `.rd-fm`, `.rd-files`,
`.rd-note .q .ln`, `.pop .row`, `.set-nav .lnk .v`, `.set-root`, `.set-row .lb .t.mono`,
`.set-row .n`, `.set-keys kbd`, `.skill-row .m`, `#studio` leftovers, and the `.fo …` block
(lines 512 to 523 and 585 to 586 today). Keep it on `code, pre, kbd, samp` inside `.rd-body` and on
`.rd-brief`. Add `font-variant-numeric: tabular-nums` where numbers align (page numbers, counts,
metadata). Delete the `.fo` media query. Sizes come from the chosen treatment in step 1.

### 6. Docs

- `DESIGN.md`: rewrite "The book" (one voice, no Register), "Installs and their states"
  (Origin grades replace Recorded/Guessed/Plugin badges; no name or dismiss actions), "Settings"
  (Records replaces Groups and Register), "Type" (Commit Mono only for code), "Keyboard" (no r, x).
- `README.md`: the ASCII contents sample, "Use it" (tab section, Settings, Keys), "Concepts" table,
  "What the scanner reads" (add the lockfile, marketplaces, local repositories, text matching),
  "Command reference" (`status --all`, `stop --all`, stable port, idle exit), "Status and known
  gaps" (localStorage now persists), and the decisions list (ADR 0004).
- `CONTEXT.md` is done. Re-read it before naming anything in code.

### 7. Verification

1. `npm run scan -- --compact` on this device produces the expected table; hinted skills carry
   `origin.grade === "hinted"` and are Loose; no Install named "Installed together".
2. `npm run typecheck && npm run build`.
3. `start` from `~/Code/Spellbook` and from `~/Code/pointee`: two ports, both stable across a
   `stop`/`start`; the pointee tab is titled "pointee · Spellbook" and its empty chapter names
   `~/Code/pointee/.claude/skills/`. `start` again with the tab open prints the URL and opens no
   second tab. `status --all` lists both; `stop --all` ends both.
4. Create `~/Code/pointee/.claude/skills/demo/SKILL.md` while the tab is open: the section appears
   without pressing Rescan. Delete it afterwards.
5. Idle: with `--idle 1` (add a flag for testing) the server exits a minute after the last tab
   closes.
6. `/impeccable critique` on the built tab; record the score beside the 26/40 baseline in
   `.impeccable/critique/`.
7. Send one Brief end to end and watch the reload, as before.

## Out of scope, deliberately

- An "update from Origin" action (next version; the Origin model is shaped for it: kind github
  re-runs `npx skills add <slug>` or `npx skills update`; plugin runs the plugin updater; pack
  re-runs its installer; local pulls the repository).
- Changing Bench's installer to record a URL.
- Cursor and Gemini launch paths; Codex `skill-installer` records.
- Any curation state, on disk or in the browser.

## Links

- Interview memory: the decisions above came from a question-mode grilling on 2026-09-07.
- Previous plans: [2026-09-05-survey-directions.md](2026-09-05-survey-directions.md),
  [2026-09-05-implementation.md](2026-09-05-implementation.md).
- ADRs: [0002](../adr/0002-browser-tab-reads-agent-writes.md),
  [0003](../adr/0003-react-vite-tab-served-by-node-skill.md),
  [0004](../adr/0004-group-installs-by-origin-evidence.md).

## Execution — 2026-09-08

Areas 1–6 implemented with treatment A selected by the owner. Verification results, current
corpus differences and the desktop visual-inspection limitation are recorded in
[the verification report](../verification/2026-09-08-origin-and-one-voice.md).
The handoff state and expected table above describe the original interview snapshot.
