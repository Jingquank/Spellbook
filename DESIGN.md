# Spellbook Design

Spellbook is a temporary interface. An agent opens it from a skill, it shows every skill Install
on the machine as one book, and it closes when the work is done. This document records how that
book looks and behaves. The vocabulary is [CONTEXT.md](CONTEXT.md); the constants are
[design/tokens.css](design/tokens.css); the live reference is [design/index.html](design/index.html).

## Direction

Quiet, lucid, trustworthy. Spellbook reads like a well-made book, not a dashboard. Its personality
comes from the generated skill artwork, the agent marks, disciplined typography and clear
behaviour, never from decorative chrome. Colour belongs to the artwork and to the single state that
needs attention; everything else is warm graphite.

Anti-references: marketplace grids, gradient AI dashboards, chat-first framing, file managers that
lead with paths, tools that overwrite ambiguity.

## The book

The tab is a two-page spread.

- **Left page: the contents.** Every Install, grouped by Source ("From this project" first,
  then "On this device"), with its skills as entries. One row model in both **Registers**; the
  Register, chosen in Settings and kept in the browser, changes type, not behaviour:
  - Chapter labels are 11 px uppercase with a hairline after them and the count at the end.
  - A **section** (an Install) is a 32 px row: chevron, 20 px Group Thumbnail, name, one-word
    annotations (a dashed "guessed" pill, a solid "named" pill, "recorded", "plugin", the word
    "drift" in the warning colour), a dotted leader, and the skill count. Sections fold; the open
    one follows the page being read. On hover or focus the leader gives way to the guessed group's
    two actions, "name it" and "not a group"; at rest a row shows only the pill.
  - An **entry** (a skill) is a 28 px row indented to the section name: name, leader, page number.
    The selected entry sits on the selection surface; the current section on the grouped surface;
    the keyboard cursor is a 2 px inset ring, distinct from selection.
  - Rhythm: 2 px between sections, the entries block padded 2 px above and 6 px below, 22 px and a
    hairline between chapters. The name wins the space; annotations never truncate it.
  - **Prose** (the Grimoire look, the default) sets the rows in Schibsted Grotesk. **Mono** (the
    Folio look) sets the same rows in Commit Mono at 13 px with 12 px glyph tiles and line counts
    after each entry.
  - A filter line sits at the foot of the page in both Registers, with the key hint beside it.
    Sorting (book order, name, date, size) applies to the contents and to the page numbers alike.
- **Right page: the Reader.** One skill at a time, with the Notes margin on its outer edge.
- **Footer:** Previous, the page number ("page 12 of 38"), Settings, Next. Skills are pages 1 to N;
  Settings is page N+1.
- **Running heads:** Install name on the left of the right page, skill name on the right.

The book is `min(1320px, 100%)` wide in Focused width and `min(1680px, 100%)` in Wide. Below
900 px the pages stack, contents above the Reader.

## The Reader

- **Title bar** (40 px, plain): "Skill · SKILL.md", a Path copy control, a More menu. No material,
  no glass.
- **Head**: crumb row (24 px Group Thumbnail, Install name, badges, Agent Marks), the skill name at
  24 px bold, the frontmatter description at 15 px secondary, then a mono metadata row (path,
  lines, files, updated).
- **Tabs**: SKILL.md first, sibling Markdown files next, "Files" last. Files lists every file by
  name and kind; nothing but Markdown is ever rendered.
- **Body**: Markdown at the reader body size (14, 15 or 16 px), line height 1.55, measure 68ch
  (84ch in Wide). Frontmatter keys other than name and description appear as a mono block above
  the body. Links do not navigate; they are shown.
- **Notes margin** (232 px): three groups in a column with 14 px between them. The head carries
  "Notes · n" and the "Note on skill" action. Each Note is a block under a hairline: anchor line
  (line range or "whole skill"), the text or its textarea with a one-line hint, then Draft or Sent
  with Edit and Remove. The foot is the full-width Send Brief, a "Preview Brief · Copy Brief" line,
  the delivery status, and the history after a reload. The column keeps 4 px of horizontal room so
  focus rings never clip against its scroll edge.

## Notes and the Brief

1. Select text in the body. An "Add note" pill appears above the selection.
2. The pill turns the selection into a Note: quote, source line range, an empty text field with
   focus. Enter keeps it, Escape discards it. The range stays highlighted while the Note exists.
3. "Note on skill" adds a Note with no range.
4. Notes are Drafts until "Send Brief · n". One Brief carries every Draft for the file: the path,
   each quoted range with its lines, each note. "Preview Brief" shows exactly that text.
   "Copy Brief" puts it on the clipboard for agents without the server.
5. Sent Notes show "Sent 14:07". The status line reads "Sent to Claude Code at 14:07. Waiting for
   the edit." When the file changes on disk the body reloads, Sent Notes move to a one-line
   history ("3 notes sent at 14:07, applied"), and a toast confirms. No diff view; the agent's
   transcript explains the change.

The tab never writes to disk. See ADR 0002.

## Installs and their states

- **Group Thumbnail**: generated by `design/thumbnails.js` from the Install identity. Square crop
  for tiles and glyphs, rounded for crumbs and previews.
- **Agent Marks**: 16 px official marks (22 px where prominent). A skill reachable from several
  agents is one Install wearing several marks.
- **Recorded**: a neutral outlined badge. **Plugin**: badge with the version.
- **Guessed** (Inferred Install): a dashed badge, and two actions revealed on hover or focus
  wherever the Install is named: "name it" (inline rename, kept in the browser) and "not a group"
  (its skills become Loose Skills; the confirming toast carries Undo, and Settings can restore).
- **Drift**: the warning colour on one word, "drift", never a red banner. Clicking it opens a
  popover listing each drifted skill's copies (root, lines, files, date), the files that differ,
  and one action that sends a Brief asking the agent to reconcile. Every control that names the
  agent sends a Brief; none of them only explains.
- **Empty Source**: the chapter stays, with one sentence saying what would appear there.
- **Fixture**: a grey badge; only in prototypes.

## Settings

The last spread of the book. Left page: a contents list of the sections with their current values.
Right page: inset grouped rows, 44 px, label and explanation left, control right.

Sections: Appearance (System · Light · Dark), Contents register (Grimoire · prose, Folio · mono),
Reader (Width: Focused · Wide; Text size: 14 · 15 · 16), Connection (opened by, delivery, fallback),
Roots (every scanned root with counts and a note, plus "Ask <agent> to rescan"), Groups (names and
dismissals with restore), Keys. Everything here lives in the browser for this device.

## Type

- **Interface**: Schibsted Grotesk. 11 px micro labels (uppercase, 0.06 to 0.08em tracking),
  12 px metadata, 14 px rows and controls, 15 px section titles, 22 to 24 px titles.
- **Code and paths**: Commit Mono, ligatures off. 12 px metadata, 13 px body. The Mono register
  is set entirely in it at 13 px on a 21 px line.
- **Reader prose**: 15 px default, 1.55 line height, 68ch measure.

Hierarchy comes from weight and spacing. No display type inside the shell.

## Colour

Four palettes in `tokens.css`: light, dark, and an Increase Contrast pair. Roles, not values:
canvas, sidebar, raised, grouped, hover, selection; primary, secondary and tertiary text;
separator; one warm-graphite interaction colour for links, focus and controls. Success, warning and
error appear only on the single element that carries the state. Primary buttons are a neutral
high-contrast fill.

Artwork and agent marks keep their own colour. Nothing else is saturated.

Two surfaces carry a texture, both drawn from the tokens and both under the type. The canvas
behind the book is graph paper, an 8 px minor grid at a third of the separator colour and a 40 px
major grid at about half, on a
pseudo-element beneath the spread so nothing it does can clip the pages.
The right page carries a halftone screen: a 4 px dot pattern of the text colour at 7%, on a
pseudo-element under the Reader, so the page reads as printed stock rather than a flat panel.
The left page stays plain, with only its gutter shadow.

## Motion

One easing (`--sb-ease-out`). Hover 100 ms, feedback 160 ms, disclosure 180 ms, reveal 180 ms
in and 100 ms out. Everything a user does dozens of times a day is instant or near-instant. Six
moments are authored, each with one named purpose:

1. **Popovers and menus grow from the element that opened them**: scale 0.96 to 1 with a fade,
   180 ms in, 100 ms out, transform origin at the trigger. Spatial consistency.
2. **The edit landing**: when the agent's change reaches the disk, the body dims to 0.35 over
   160 ms, then returns like a page turn (6 px slide, 180 ms); the status check settles from 0.8
   and the history line drops in by 4 px. The re-anchored Note flashes for two seconds. The one
   moment that earns a beat.
3. **The "Add note" pill** rises from the selection, 120 ms, and never animates out.
4. **A Note enters the margin** by 4 px, 180 ms; removal stays instant.
5. **The book appears** once per session as one object, 6 px and 180 ms, no stagger.
6. **Unfurl**: a section's entries block grows from zero height over 180 ms, so the rows below
   slide instead of jumping, and the entries fade in as room appears; folding runs the same in
   reverse. The chevron turns on the same clock.

Reduced Motion shortens every duration and removes the movement, never the state change: fades
stay, slides and scales go. Nothing else animates.

## Keyboard

Both registers, identically: ← → turn pages; j k (or ↑ ↓) move the cursor over sections and
entries; Enter opens an entry or folds a section; h and l fold and unfold; z folds or unfolds all;
/ focuses the filter; s cycles the sort (book order, name, date, size) for contents and pages
alike; r names a guessed group and x says it is not one; Escape leaves Settings or clears the
filter. In the Reader, ← → on the tab list move between files.

## Icons and artwork

Interface icons are the vendored Iconoir set (`design/icons/`), stroke 2, at 12, 14 or 16 px,
coloured by text role. Agent marks are official artwork, never recoloured. Thumbnails are
deterministic: the same Install always draws the same tile.

## Accessibility

Full keyboard operation, visible focus (2 px interaction-colour outline), WCAG AA contrast in every
palette, state never encoded by colour alone (drift is a word, guessed is a dashed shape), reduced
motion respected, prose measure kept under 84ch.

## What Spellbook does not do

- Edit, rename, remove or update a skill itself. Every change is a Brief to the agent.
- Show a diff. The agent explains its change where it made it.
- Rank, recommend or sell skills. The Survey is the user's own library, nothing else.
