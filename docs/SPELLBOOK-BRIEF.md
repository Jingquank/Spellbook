# Spellbook Product and Design Brief

Status: Locked for initial implementation  
Date: 2026-07-20  
Platform: Native macOS app, Swift and SwiftUI

Implementation sequence: [BUILD-PLAN.md](BUILD-PLAN.md)

## 1. Feature Summary

Spellbook is a native macOS library for the skills installed across Claude Code, Cursor, Codex, and future agent adapters. It discovers existing local skills, renders their Markdown as readable documentation, explains where each skill came from, and provides safe tools to edit, update, copy, or remove installations.

The app is for developers who have accumulated skills through hand-written files, GitHub repositories, packages, and agent-specific installers. It must make a scattered local system feel legible without pretending every file has clean provenance.

## 2. Primary User Action

The primary action is to select a skill and immediately understand what it does, where it is installed, whether it differs from its source, and whether any action is needed.

The library should answer "What skills do I have?" before it asks the user to organize or sync anything.

## 3. Product Model

Spellbook keeps four concepts separate:

| Concept | Meaning | Primary responsibility |
| --- | --- | --- |
| Package | A distributable source that may contain one or many skills | Provenance, version, update boundary, repository |
| Skill | One user-facing capability with a Markdown entry point | Name, description, author, rendered content |
| Installation | One physical copy of a skill for one agent | Path, enabled state when supported, local hash, edit history |
| Agent | A host such as Claude Code, Cursor, or Codex | Discovery rules, format adapter, install and removal behavior |

This model is required. A skill is not duplicated in the conceptual library merely because it is installed for three agents, and editing one installation never silently edits the other two.

### Package surfacing

- A package with multiple skills, such as Bench, appears as a compact package group with its skills nested underneath.
- A package with exactly one skill, such as i-have-adhd, appears as the skill itself by default. Package, source, and update information remain visible in the detail pane.
- Settings includes an optional "Always show package groups" preference. When enabled, one-skill packages also receive an explicit package wrapper.
- Package updates operate at the package boundary, then show the affected skills before any files change.

## 4. Information Architecture

### Main library

The app uses a dense two-pane macOS layout.

The left sidebar contains:

1. Search.
2. A compact Skill-first / Agent-first view control.
3. The current hierarchical library.
4. One actionable indicator per row at most.
5. A restrained footer area for scan state and settings access when needed.

The right detail pane contains:

1. Skill title, thumbnail, description, and primary actions.
2. Provenance and installation metadata.
3. Agent installation summary.
4. A reader-friendly Markdown document.
5. Contextual diff, edit, update, or removal UI when invoked.

### Skill-first view

Skill-first is the default library view. Skills are organized by identity, with multi-skill package groups where applicable. Installed Claude, Cursor, and Codex copies are fields in the skill detail. Selecting an installation reveals its path, last installed or updated time, local state, and agent-specific content.

### Agent-first view

Agent-first groups the library under agent logos, as in the ASIDE reference. Each agent is a disclosure group and its installed skills fold underneath. Package context is secondary. This view answers "What does this agent currently have?"

### Settings

Settings uses a dense native sidebar and inset grouped rows. Initial sections are:

- General: launch behavior, scanning, file watching, update checks.
- Sources: GitHub and package source connections.
- Agents: detected adapters, directories, and permissions.
- Appearance: theme, density, interface type scale, reader width, code wrapping.
- Advanced: custom filename patterns, ignored roots, cache and index controls.

## 5. Discovery and First Launch

Spellbook should feel useful on first open.

1. Detect supported agents and scan their well-known user-level skill directories.
2. Request access only when macOS requires it, explaining which directory is needed and why.
3. Offer additional folders and custom roots as an explicit user action.
4. Build the library incrementally so results appear while the scan continues.
5. Watch granted roots for changes so agent-authored edits appear quickly without a manual rescan.

The scanner recognizes common skill entry points and configurable patterns, including `SKILL.md`, agent-specific Markdown layouts, and `.agent.claude.md`. Directory-based skills may include references, scripts, assets, metadata, and multiple Markdown files; the declared or inferred entry document is what the reader opens first.

Scanning the entire laptop is never a silent background action. Known directories are automatic where permitted; broader roots require explicit access.

### Expected scale

- Empty: 0 skills.
- Typical: 20 to 100 skills across 2 or 3 agents.
- Power user: 100 to 500 skills.
- Stress target: 1,000 skills and 5,000 tracked files without blocking navigation.

## 6. Metadata and Provenance

Each skill detail can show:

- Name and description.
- Author or organization.
- Website and GitHub repository.
- Package name and version or source revision.
- Installed agents and per-agent paths.
- Last installed or updated time.
- Last local modification time.
- Provenance confidence.

Metadata is resolved in this order: explicit skill metadata, package or plugin manifest, Git repository, supported installer manifest, then user-authored overrides. Missing values are shown honestly as Unknown and can be corrected by the user.

For pre-existing files, "last installed or updated" may not be knowable. File timestamps may be shown as an approximate observation and labeled accordingly. Once Spellbook manages an installation, it records exact operations in its local index.

## 7. Modification Detection

Modification claims must be evidence-based.

- Spellbook-managed install: compare the current normalized content hash with the exact baseline recorded at install or update.
- Identifiable source: retrieve or locate the matching source revision and compare against its normalized content.
- Unmanaged file without a recoverable source: show Unverified, not Modified. The user may connect a source or mark the current version as a baseline.

Formatting normalization may ignore line-ending differences, but never semantic Markdown changes. Package assets and supporting files are tracked separately from the entry Markdown.

## 8. Actionable Status

The sidebar uses one actionable indicator, chosen by priority:

1. Conflict or action required.
2. Locally modified.
3. Update available.

All three states are supported, but only the highest-priority state occupies the row. Clicking the indicator opens the relevant diff or resolution flow. Clean skills show no status decoration.

Package groups may show a rolled-up indicator derived from their most urgent child state. The detail pane always exposes the complete state.

## 9. Reading and Editing

### Reader

Markdown renders with native-feeling typography and support for headings, lists, tables, task lists, links, images, block quotes, inline code, and fenced code. The reader preserves a focused measure and offers copy controls for code. Raw source remains available.

### Edit flow

1. The user selects a specific agent installation or the package source when one is editable.
2. Spellbook opens an editor with rendered preview and clear scope text.
3. Saving writes only to the selected installation.
4. Spellbook refreshes the hash, metadata, and rendered content immediately.
5. A post-save action offers **Apply to other agents**.

Apply to other agents is always explicit. It previews target agents, destination paths, format adaptation, and diffs. It never becomes automatic because the installations may have intentionally diverged.

Changes made outside Spellbook, including edits made by an agent, are detected through file watching. The open reader refreshes promptly; an unsaved Spellbook edit receives a conflict state instead of being overwritten.

## 10. Updating

Spellbook supports per-skill, per-package, selected, and Update All flows.

Before updating, it:

1. Resolves the source and checks provenance confidence.
2. Fetches or reads the candidate version.
3. Shows affected installations and a concise change summary.
4. Protects local modifications with a diff and explicit choice.
5. Creates a recoverable backup and writes atomically.

Update All is a review queue, not a blind overwrite. Clean updates can be applied in one confirmation. Modified, conflicting, unauthenticated, or unverified items pause for individual resolution.

For packages, one package update may change several skills. The review names every affected skill and preserves each agent installation as an independent target.

## 11. GitHub and Custom Sources

Initial source support includes public GitHub repositories, local Git repositories, direct files, and installer manifests that Spellbook can identify reliably.

The initial release provides manual source connection and update checking. A custom GitHub sync flow is a staged extension, not a prerequisite for the first useful version. Its intended shape is:

- Connect a skill or package to a repository, branch, tag, and optional subdirectory.
- Pull with preview.
- Push a user-edited source only through an explicit authenticated action.
- Support a personal fork without changing the original package identity.
- Never treat bidirectional sync as automatic.

GitHub CLI authentication may be reused when available. Account-level OAuth and background push are deferred until the local update model is proven.

## 12. Removal and Recovery

Removal is scoped to a selected installation, selected agents, or the whole package. The confirmation names the exact files and agents affected.

Material files move to a recoverable Spellbook Trash or the macOS Trash where practical. Spellbook removes only files it can attribute to the selected installation. Unknown adjacent files are left untouched and reported.

## 13. Key States

- First scan: progressive results, clear permission requests, no blank waiting screen.
- Empty library: explain supported locations and offer Add Folder.
- Clean: readable content with no unnecessary status badge.
- Update available: one direct review action.
- Locally modified: show the installation and its baseline diff.
- Conflict: preserve both versions and require a resolution choice.
- Unverified source: explain what is unknown and offer Connect Source or Set Baseline.
- Missing file: retain the record briefly, explain the path, and offer Forget or Locate.
- Unsupported structure: show discovered files and offer manual entry-point selection.
- Permission denied or revoked: keep indexed metadata, disable mutation, and offer Restore Access.
- Offline or source unavailable: keep local reading and editing available; updates can retry later.
- Partial package failure: report per-skill outcomes and keep successful writes recoverable.
- External edit during an open edit: do not overwrite; enter conflict resolution.

## 14. Interaction and Safety Model

- Single click selects; double click is not required for core actions.
- Search matches names, descriptions, authors, package names, agents, paths, and rendered Markdown text.
- Keyboard navigation covers the library, view switcher, detail actions, search, and update review.
- Context menus expose secondary operations such as Reveal in Finder, Copy Path, Open Repository, Set Baseline, and Remove.
- Diffs are semantic where possible and fall back to line-based Markdown diffs.
- Writes use coordinated, atomic replacement and are followed by verification.
- Destructive or many-target operations always receive a named review step.

## 15. Visual Direction

The color strategy is Restrained. The interface is predominantly warm or cool-tinted system neutrals, with color reserved for skill thumbnails, official agent logos, status semantics, and destructive confirmation.

The layout should feel closer to ASIDE's compact skill and settings panels than to a spacious web dashboard. Rows are short, dividers are subtle, sections are grouped by rhythm, and the detail pane is mostly open reading space. v0 contributes directness; Codex contributes calm technical typography and source-aware actions.

The name Spellbook does not justify fantasy decoration. Product identity should emerge through naming, iconography, and excellent organization.

## 16. Appearance Controls

Appearance settings are part of the initial surface, not a future polish item:

- System, Light, or Dark appearance.
- Compact or Comfortable density, with Compact as default.
- Small, Default, or Large interface type scale.
- Focused or Wide reader measure.
- Code wrapping on or off.

These options affect layout tokens consistently across the library, detail pane, settings, and update review.

## 17. Technical Constraints and Architecture Direction

- Native macOS app written in Swift and SwiftUI, with AppKit bridges where native filesystem, text editing, window, or menu behavior requires them.
- Use semantic macOS colors, named SF Symbols, native focus behavior, and platform controls in implementation. The design tokens specify visual intent rather than hard-coded web colors.
- Initial deployment target: macOS 14 or newer.
- Local-first index and operation history, with no account required for core use.
- Agent support is adapter-based so discovery, parsing, formatting, install, update, and removal rules do not leak into the shared domain model.
- File observation uses macOS filesystem events for granted roots.
- Markdown parsing has one canonical syntax tree used by reader, editor preview, search indexing, and semantic diff.
- Signed and notarized direct distribution is the initial assumption because broad local tooling and Git integration conflict with a simple App Store sandbox story. App Store distribution can be reconsidered after the permission model is validated.

## 18. Initial Delivery Scope

### Phase 1: Trustworthy inventory

- Agent adapters for Claude Code, Cursor, and Codex.
- First-launch discovery and folder permissions.
- Skill, package, installation, and source model.
- Skill-first and Agent-first views.
- Dense library sidebar and Markdown reader.
- Metadata, provenance confidence, and one actionable status.
- Appearance settings.

### Phase 2: Safe management

- External change watching.
- Installation-scoped editing and preview.
- Apply to other agents.
- Modification baselines and diffs.
- Removal with recovery.

### Phase 3: Updates

- Public GitHub and local Git update checks.
- Per-item, per-package, selected, and Update All review queues.
- Conflict handling, backups, and atomic verified writes.

### Phase 4: Custom source workflows

- Personal forks, branch and subdirectory mappings.
- Authenticated manual pull and push.
- Additional agent and installer adapters.

## 19. Acceptance Criteria

The initial product direction is successful when:

- Existing supported skills appear without manual re-import after required access is granted.
- Bench is represented as one package with five browsable skills.
- i-have-adhd appears as one skill by default, with its package metadata in details.
- A skill installed for multiple agents has independent installation state.
- Editing one installation changes no other agent until Apply to other agents is confirmed.
- External edits appear promptly and never overwrite an unsaved in-app edit.
- A user can tell whether a modified claim is exact, inferred, or unverified.
- Update All never silently replaces a locally modified file.
- Sidebar density is comparable to the ASIDE references in Compact mode.
- Theme and type settings apply consistently without breaking hierarchy or accessibility.

## 20. Recommended Implementation References

- Product interface principles for density, familiar native controls, and status semantics.
- Spatial design for the resizable two-pane shell and compact hierarchy.
- Typography guidance for the Markdown reader and code treatment.
- Interaction design for update review, conflict resolution, and filesystem permissions.
- Accessibility guidance for keyboard navigation, VoiceOver, contrast, and text scaling.
- Motion guidance for restrained state transitions only.

## 21. Open Questions

None block initial implementation. Custom authenticated GitHub push, App Store distribution, and additional agent adapters are deliberately deferred and must not expand the first build.
