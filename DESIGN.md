# Spellbook Design System

## Design Direction

Spellbook uses a restrained, native macOS product language. The physical scene is a developer on a laptop or desktop monitor, moving quickly between coding agents in normal office or evening light, then slowing down to read a skill carefully. System light and dark appearances are equally supported, with System as the default.

The visual anchors are:

- ASIDE for dense sidebars, compact settings rows, thin dividers, and quiet hierarchy.
- v0 for direct controls, minimal chrome, and interfaces that get out of the way of work.
- Codex for calm technical content, disciplined typography, and source-aware workflows.

These are principles, not skins. Spellbook remains recognizably native to macOS.

## Color

Color strategy: restrained and app-owned. The OKLCH values below remain the design targets; `SpellbookDesign.Palette` resolves them to a custom neutral light, dark, and Increase Contrast palette rather than inheriting arbitrary platform accent colors.

- `canvas`: `oklch(0.985 0.004 75)` light, `oklch(0.185 0.006 255)` dark
- `sidebar`: `oklch(0.965 0.005 75)` light, `oklch(0.215 0.007 255)` dark
- `surface-raised`: `oklch(0.995 0.003 75)` light, `oklch(0.245 0.008 255)` dark
- `text-primary`: `oklch(0.225 0.007 255)` light, `oklch(0.925 0.005 75)` dark
- `text-secondary`: `oklch(0.51 0.008 255)` light, `oklch(0.70 0.007 75)` dark
- `separator`: `oklch(0.88 0.006 255)` light, `oklch(0.33 0.008 255)` dark
- `selection`: a neutral tint, not a saturated brand fill
- `success`, `warning`, and `error`: semantic system colors adjusted for contrast

Skill thumbnails and official agent logos retain their own color. Status color appears only on the single actionable indicator, destructive confirmations, and diff semantics. Primary buttons use a high-contrast neutral fill. Blue is not the default action color.

## Typography

- Interface and prose: bundled Schibsted Grotesk. Core Text supplies per-glyph fallback for unsupported scripts.
- Code, paths, revisions, hashes, diffs, aligned tables, and editor text: bundled Commit Mono with programming ligatures disabled.
- SF remains only in macOS-owned menus, alerts, tooltips, picker menus, and window chrome.
- Default interface scale: 12 pt metadata, 14 pt rows and controls, 15 pt section labels, and 22 to 24 pt titles.
- Reader prose: 15 pt default with a 1.5 to 1.6 line-height equivalent and a 68 to 74 character measure.
- Hierarchy comes from weight, spacing, and a restrained scale. Display typography is not used inside the app shell.

## Density and Spacing

The default density is Compact, modeled on ASIDE's information rhythm.

- Compact sidebar rows: 30 to 32 pt.
- Comfortable sidebar rows: 38 to 40 pt.
- Compact settings rows: 44 to 48 pt.
- Comfortable settings rows: 52 to 56 pt.
- Sidebar section gaps: 10 to 14 pt, with 6 to 8 pt within a group.
- Detail content inset: 28 to 32 pt on a standard window.
- Dividers are one physical pixel where the display permits it.

Whitespace separates conceptual groups. Do not wrap every section in a card. Use inset grouped rows where controls need a shared boundary, and use open content for the reader.

## App Shell

- Native macOS window with a compact toolbar and a two-pane `NavigationSplitView` structure.
- Sidebar target width: 240 to 280 pt, resizable within sensible limits.
- Detail pane fills the remaining space and scrolls independently.
- The sidebar begins with an app-owned search field and adjacent Library View menu. A second status-led row shows live library health with persistent Scan and Update affordances.
- Navigation uses short rows, small identity artwork, disclosure chevrons only where children exist, and one trailing actionable state indicator at most.
- The detail header is open and typographic. Metadata sits in concise labeled rows or columns before the Markdown reader.

## Library Components

### Skill row

Shows thumbnail, skill name, optional package context, and at most one actionable indicator. Secondary paths and dates do not live in the row by default.

### Package group

Used automatically for packages containing multiple skills. It is a compact disclosure group with package identity and child skill rows. A one-skill package is flattened by default.

### Agent group

Used in Agent-first view. It uses the official agent logo and folds installed skills underneath it, matching the structure of the ASIDE reference.

### Detail header and management inspector

The Adaptive Resolution Header shows identity, a bounded summary, and one compact installation/source/state line. A single state-resolution row leads into the Markdown reader. Installations, provenance, candidates, and grouped Evidence live in an independently scrolling trailing Manage inspector that can be collapsed from the toolbar without changing reader width preferences.

### Markdown reader

Renders headings, lists, tables, links, block quotes, inline code, fenced code, images, and task lists with readable rhythm. Code blocks support copy and optional line wrapping. Referenced local assets are resolved relative to the skill package when access is available.

### Settings group

Uses ASIDE-like inset grouped rows, not dashboard cards. Labels and descriptions align left; toggles, menus, and steppers align right.

## Actionable Status Indicator

Each list row shows no more than one indicator. The highest-priority state wins:

1. Conflict or action required.
2. Locally modified.
3. Update available.

The indicator combines symbol, accessible label, and restrained semantic color. Selecting it opens the relevant diff or resolution action directly. Lower-priority states remain visible in the detail pane.

## Appearance Settings

The Theme section includes:

- Appearance: System, Light, Dark.
- Density: Compact, Comfortable. Compact is default.
- Interface text size: Small, Default, Large.
- Reader width: Focused, Wide.
- Code wrapping: Off, On.

Reduced motion, contrast, and accessibility appearance settings follow macOS automatically. Theme preferences change presentation only and never alter scanned content.

## Controls and Feedback

- Use native buttons, menus, toggles, disclosure groups, search fields, and confirmation sheets.
- Hover is subtle and optional; selection is always clear without relying on hover.
- Typical transitions last 150 to 220 ms and communicate selection, disclosure, or save state only.
- Destructive actions name the exact installation or package affected.
- Progress appears inline in the row or toolbar that initiated it. Avoid central loading spinners.

## Visual Prohibitions

- No gradient text, decorative gradients, glass cards, glowing actions, or blue-filled controls by default.
- No card grid for the library.
- No nested cards in details or settings.
- No decorative magic particles, fantasy ornament, or medieval styling despite the name Spellbook.
- No multiple status badges competing inside a sidebar row.

Exact implementation values and exceptions live in [docs/DESIGN-TOKENS.md](docs/DESIGN-TOKENS.md). Architecture decisions live in [docs/adr](docs/adr).
