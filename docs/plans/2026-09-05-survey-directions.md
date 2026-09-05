# Spellbook in the browser: design brief and prototype plan

Date: 2026-09-05. Status: draft for review before any prototype is built.

## The flow we are designing

In Claude Code, Codex or Cursor the user types `/spellbook`. The skill scans the current project and the whole device for skills, groups them by Source, and opens a browser tab showing the Survey. Clicking a skill opens the Reader beside the Survey. The user highlights a range, writes a Note, and sends a Brief. The agent edits the file; the Reader reloads.

## Decisions reached in the interview

1. **A block is an Install, a slab is a skill.** The Survey presents Installs. A Loose Skill is a one-slab block; the Bench install is a six-slab block. Artwork stays with the Install, as CONTEXT.md and ADR 0001 already say.
2. **The two Sources are "From Spellbook" (the project) and "On this device".** The word *Global* is avoided: the device root holds installs for several agents, so nothing there is global to any one of them.
3. **One Install across agent roots.** A symlinked or byte-identical copy under another agent's root is the same Install wearing another Agent Mark. A diverged copy is the same Install in a Drift state, never a second block.
4. **Transport is a skill-launched local server the agent polls.** Clipboard copy of the Brief is the fallback. Recorded in ADR 0002.
5. **The agent is the only writer.** The tab reads and annotates. Rename, remove and update are all Briefs. Recorded in ADR 0002.
6. **Notes are anchored and batched.** A Note pins to a highlighted range mapped to source lines, or to the skill as a whole. Notes collect in the Reader margin and leave together as one Brief naming the file, the quoted lines and the request.
7. **The Reader shows SKILL.md first and sibling Markdown as tabs.** Scripts, assets and fonts are listed by name, never rendered. Frontmatter becomes the metadata header.
8. **The Reader opens as a side pane at reader width (760px) and the Survey stays.** Below roughly 1100px the Reader takes the full width with a back control.
9. **After a Brief is sent, Notes move to a Sent state and the Reader reloads when the file changes.** No diff view in the tab; the agent's transcript explains the change.
10. **Ten directions get prototyped**, all sharing one Reader and one note flow. The Shelf block is a stack of slabs with the Group Thumbnail on the top face. The Canvas is auto-arranged with dragging allowed and positions kept in browser storage, never on disk.

Glossary additions made during the interview: Agent Mark, Drift, Reader, Note, Brief. See CONTEXT.md.

## What the Survey shows on this machine

The prototypes use the real corpus, read from disk today.

- **Bench install** (Recorded, six skills: drill, grid, huh, lore, writereport, xray). Every one has a diverged copy under `~/.claude/skills`, so the whole Install shows Drift.
- **Three Inferred Installs** from install-time clustering: seven design and animation skills from 1 August, six planning and interview skills from 19 July, and master plus mastermind from 26 July, which also exist under Gemini.
- **Two Loose Skills**: aside-browser, and impeccable (57 files, drifted, also on Gemini).
- **Two plugins with skills**: frontend-design (one skill) and notion (four). swift-lsp has no skills and is not shown.
- **Codex**: hatch-pet as a Loose Skill, and six Codex system skills as one quiet Recorded Install.
- **Project Source**: this repo has no skills yet. The prototype fixtures two, `spellbook` and `design-tokens`, so the project group is visible. They are labelled as fixtures.

Twelve Installs and thirty-seven skills in all. Assumption to confirm: Codex reads the shared `~/.agents/skills` root, so shared skills carry both the Claude Code and Codex marks.

## Shared by all ten directions

- **Design language**: the existing tokens, Schibsted Grotesk for interface, Commit Mono for anything code-like, warm graphite interaction colour, hairline separators, no cards inside cards, light and dark.
- **Frame**: a 40px title bar with the project name, Source counts, search, and a Rescan control that is itself a Brief to the agent.
- **Install anatomy**, however a direction draws it: Group Thumbnail, name, skill count, Agent Marks, a single Drift indicator, and for an Inferred Install a "guessed" label with rename and dismiss.
- **Reader pane**: metadata header from frontmatter, tabs for sibling Markdown, a named file list, the Notes margin, a Send Brief control, the Sent state, and a reload indicator.
- **Note flow**: select text, an "Add note" affordance appears, the Note lands in the margin anchored to the range. "Note on skill" adds an unanchored one. Send Brief shows exactly what the agent will receive.
- **States**: project with no skills, an Install in Drift, an Inferred Install being renamed or dismissed.

## The ten directions

Each answers a different question about "what do I have".

1. **Shelf**: volume at a glance. Isometric slab stacks on two shelves, one per Source. Height is skill count. Top face carries the Group Thumbnail, each slab's front face carries a skill name. Hover lifts a slab; click opens it.
2. **Canvas**: my own arrangement. Flat tiles on a pannable surface in the Berd spirit, auto-packed into two Source regions, draggable, positions remembered per project. A skill list unfolds beneath the tile on click.
3. **Aside**: the browser shell. A persistent vertical sidebar is the Survey: agent groups with their marks, Installs folded underneath in compact 31px rows with 18px artwork and hairline dividers. The Reader is the main pane from the start.
4. **Bookshelf**: browsing a library. Spine-out books on shelves, thickness is skill count, spine colour from the palette, Source as shelf label. Pulling a book tips it forward to show the skill list.
5. **Atlas**: proportion and coverage. A treemap where each Install is a territory sized by skill count and each skill a parcel inside it. Sources are the two continents. The whole library fits one screen without scrolling.
6. **Contact Sheet**: artwork first. Large Group Thumbnails edge to edge in a strict grid, names as captions in metadata type, one sheet per Source. Skills appear as a strip under the selected frame.
7. **Card Catalog**: what each one does. A drawer of tabbed index cards; the front card shows thumbnail, name and description. Source tabs on the drawer. Skimmable descriptions are the point.
8. **Terminal**: the agent's own register. Commit Mono throughout, a box-drawing tree of Sources, Installs and skills, keyboard-first, Group Thumbnails reduced to tiny glyphs. Fastest to scan, least decorative.
9. **Timeline**: recency and staleness. Installs along an install-date axis grouped by month, newest at the right, so what arrived together reads as a cluster and what has not been touched in months reads as quiet.
10. **Grimoire**: reading first. A book spread: the left page is the Survey as a table of contents, the right page is the Reader. Turning pages moves between skills; Notes are marginalia.

## Prototype plan

- **One artifact, "Spellbook Directions"**, with a switcher across the ten directions (keys 1 to 0). Shared Reader, shared note flow, shared corpus inlined. Any direction can be split into its own page later.
- **Thumbnails** use the shipped renderer. ADR 0001's parameterisation is accepted but not yet in `thumbnails.js`, so some of the eleven Installs may share a tile; that is noted, not fixed, in this pass.
- **Not built**: the local server, file watching, real Markdown line mapping for anchors. Send Brief simulates Sent and then a reload after a short delay.
- **Fonts**: Schibsted Grotesk from Google Fonts, Commit Mono embedded.

## Where the prototype is

Published as the artifact "Spellbook Directions": https://claude.ai/code/artifact/2d6babfd-eca4-4995-8597-1c8c5c2bc4d4. Keys 1 to 0 switch directions. Verified in Chrome: all ten directions render, the Reader opens beside the Survey, a whole-skill Note goes to Sent and the file reloads with the Note filed as applied, and the Add note pill appears on a text selection. Completing an anchored Note through the pill was not exercised by automation because a browser extension's selection popup blocked it; try that first by hand.

## Review outcome, 2026-09-05

After the first cut the user kept two directions: **Terminal** and **Grimoire**. The other eight are set aside, not deleted from the artifact.

## Round two

Three prototypes side by side in a second artifact, each carrying the states the first cut skipped: renaming and dismissing an Inferred Install, Drift detail showing which copies differ and how, an empty project Source, and narrow widths.

1. **Terminal v2**: adds a preview pane for the cursor row (Group Thumbnail at full size, description, path, marks, Drift detail), sort and fold keys, live note and Brief counts in the header, `r` to name a guessed group and `x` to dismiss it.
2. **Grimoire v2**: the contents page folds by Install so thirty-seven entries no longer scroll, running heads and page numbers, Drift and Guessed as marginal annotations with their actions, and Notes as marginalia.
3. **Folio**, the merge: Grimoire's spread with a Terminal contents page. Left page is the mono tree with keyboard navigation, filter and a preview strip; right page is the Reader with marginalia. The Reader keeps Schibsted Grotesk in all three: the Survey speaks the agent's register, the text you read speaks the reader's.

### Where round two is

Published as the artifact "Spellbook Round Two": https://claude.ai/code/artifact/12bcdfab-124f-4cc0-98a3-82c0cb5e2cfd. Keys 1 to 3 switch directions; the studio strip has an "empty project" toggle and a "reset groups" control. Verified in Chrome: all three render, Terminal v2's cursor preview follows `j`/`k`, dismissing a guessed group turns it into Loose Skills, the Drift popover lists both copies per skill with real line counts, the empty-project state moves the Reader to the first device skill, and reset restores. Inline renaming was not exercised by automation because selecting the input text wakes a browser extension's selection popup; try it by hand.

## Round two outcome, 2026-09-05

The user kept **Grimoire** and **Folio** and asked for a settings page to switch between them. Decisions: the switch is the **Register** of the contents page (Prose or Mono), not a theme; **Settings** opens as the book's last spread, holding Appearance (System, Light, Dark), Register, Reader width and text size, Connection, Roots and Groups, plus a Keys reference; the default Register is Prose. Round three is one product prototype, no longer a comparison.

### Round three

One artifact, "Spellbook": https://claude.ai/code/artifact/deb039da-4dba-490e-8073-9c6e9401dd41. The book opens in the Prose register on page 1 of 38: 37 skills and Settings as page 38. Settings holds Appearance, Register, Reader width and text size, Connection, Roots (with real counts per root), Groups (names and dismissals with restore), Keys, and a Prototype section with the empty-project simulation. Verified in Chrome: the spread renders with no console errors, Settings opens from the footer, switching the Register redraws the contents page in mono, Dark applies across the page, and Back to reading returns to the same skill. Renaming a guessed group by hand and the anchored Note pill remain to be tried manually because of the browser extension's selection popup.

## What I need from the review

- Which directions to kill early and which to push further.
- Whether the shared Reader and note flow matches how you expect to work.
- Whether the Codex shared-root assumption is right.
