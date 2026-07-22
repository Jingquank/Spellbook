---
target: "SPELLBOOK app: home, settings, dropdowns, editors, and related states"
total_score: 24
p0_count: 0
p1_count: 4
timestamp: 2026-07-22T02-26-53Z
slug: ookkit-sources-spellbookui-spellbookrootview-swift
---
# Spellbook App Critique

## Design Health Score

| # | Heuristic | Score | Key issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 2 | Initial scanning can appear as no results; several async actions only disable controls |
| 2 | Match System / Real World | 3 | Mostly developer-native language; baseline, provisional cluster, and provenance need more context |
| 3 | User Control and Freedom | 2 | Review and recovery are strong, but post-save edits can be dismissed or propagated unsafely |
| 4 | Consistency and Standards | 3 | Cohesive native vocabulary; actionable status behaves differently by status |
| 5 | Error Prevention | 2 | Filesystem reviews are excellent, but the editor state model permits unsaved divergence |
| 6 | Recognition Rather Than Recall | 2 | Important source, publishing, baseline, and removal tasks are buried; current submenu state is hidden |
| 7 | Flexibility and Efficiency | 2 | Search and two library modes help, but app commands, shortcuts, bulk paths, and arrow traversal are absent |
| 8 | Aesthetic and Minimalist Design | 3 | Calm and focused overall; generic no-results UI and crowded source/actions are exceptions |
| 9 | Error Recovery | 3 | Managed recovery is excellent; scan failures and raw localized errors are weaker |
| 10 | Help and Documentation | 2 | Tooltips and explanatory copy exist, but task-focused help for provenance, conflict, and publishing is missing |
| **Total** |  | **24/40** | **Acceptable: significant improvements needed** |

## Anti-Patterns Verdict

**Pass. Spellbook does not look obviously AI-generated.**

The restrained semantic colors, compact sidebar, system typography, native controls, skill artwork, and installation-first detail hierarchy feel intentional and consistent with the quiet, lucid, trustworthy brief. There are no gradients, glows, glass cards, hero metrics, decorative fantasy styling, or repetitive dashboard-card grids. The weaker areas look like unfinished native-app UX, not AI slop: generic `ContentUnavailableView` states become oversized in the narrow sidebar, settings lean heavily on default grouped forms, and high-value workflows are hidden in a long More menu.

The deterministic detector returned `[]` for `Packages/SpellbookKit/Sources/SpellbookUI`, but that is zero coverage rather than a clean result because the detector does not scan Swift. A SwiftUI-specific source pass found 0 gradients, 0 material/glass effects, 0 shadows/glows, 0 decorative animations, 11 icon-only labels, 11 sheets, 12 alerts, 5 menus, and 44 directly sized frames. The direct sizes are mostly legitimate macOS constraints; exact sheet sizes still need larger-text and localization testing. Browser overlays were not applicable to this native app, so the live app was inspected directly instead.

## Overall Impression

Spellbook already feels like a credible native utility. It is compact, readable, and unusually precise about filesystem safety. Its single biggest opportunity is to make state actionable and coherent: every warning should lead directly to resolution, every long-running action should acknowledge progress, and every selection/filter/editor transition should preserve a trustworthy mental model.

## Cognitive Load

**3 of 8 checklist failures: moderate cognitive load.** Single focus, grouping, visual hierarchy, one-thing-at-a-time decisions, and progressive disclosure mostly pass. Chunking, minimal choices, and working-memory support fail. The live More menu exposed about 7 top-level choices plus 3 Package Name choices. The Sources pane exposes about 9 controls across discovery folders, provenance, search scope, and publishing. Appearance is the strong counterexample, with no more than three controls per section.

## Emotional Journey

The prevailing emotion is calm confidence. The strongest peak is mutation review: Spellbook promises to recheck, back up, and verify files, and removal ends with Move to Recovery rather than Delete. External edits preserve both versions. The emotional valley occurs before users reach that safety machinery: a clean-account scan can look like no results, conflict and modified indicators do not open a resolution, and post-save editor state can silently diverge.

## What's Working

1. The visual register is right. The library is compact without feeling cramped, artwork and agent identities add personality, and Markdown remains the reading focus.
2. Filesystem safety is communicated unusually well. Review sheets, exact target naming, backups, verification, recoverable removal, and external-change preservation materially earn trust.
3. Information architecture begins with user concepts. Skill-first and agent-first views, installation rows, concise metadata, and source provenance avoid making raw filesystem paths the primary navigation model.

## Priority Issues

### [P1] Post-save editing can lose or fork content

**Evidence:** `SkillEditorSheet.swift:31`, `SkillEditorSheet.swift:47`, `SkillEditorSheet.swift:117`, `SkillEditorSheet.swift:165`.

After a successful save, the editor remains editable while the primary action changes to Done. Further typing does not reset `didSave`. Pressing Done drops those edits, while Apply to other agents can distribute the unsaved draft even though the source installation still contains the previously saved version.

**Fix:** Treat editor state as a real state machine. After commit, either dismiss, lock the saved document, or reset to a clean editable state that becomes dirty on the next change. Block dismissal with unsaved work, and only allow Apply to other agents from the exact committed content hash.

**Suggested command:** `/harden`

### [P1] Actionable conflict and modification status leads to a dead end

**Evidence:** `StatusIndicatorView.swift:9`, `SpellbookModel.swift:374`, `SkillDetailHeaderView.swift:31`.

The sidebar status is a button, but only update availability opens a review. Conflict, action-required, and modified states merely select an installation. The detail header repeats the state as a passive capsule. Users are told something needs attention without seeing the diff, cause, or next action.

**Fix:** Route every status to its exact destination: conflict comparison, local modification diff, permission recovery, or update review. Make the detail status actionable and name the next step.

**Suggested command:** `/shape`

### [P1] The Markdown reader is visually structured but not semantically navigable

**Evidence:** `MarkdownBlockView.swift:23`, `MarkdownListItemView.swift:15`, `MarkdownTableView.swift:9`.

Headings are only bold text, list markers are hidden without replacement list semantics, and table headers have no row or column relationships. The live accessibility tree exposed a long reader mainly as one text region. VoiceOver users cannot navigate the primary reading surface by heading or retain list/table context.

**Fix:** Expose heading levels, list and list-item structure, table headers and cell relationships, code-block labels, and sensible accessibility grouping. Validate VoiceOver rotor navigation with representative long skills.

**Suggested command:** `/harden`

### [P1] Loading, empty, error, and filtered states are not a coherent state machine

**Evidence:** `LibrarySidebarView.swift:14`, `SpellbookModel.swift:151`.

With an empty snapshot during scanning, the sidebar falls through to the generic search no-results state. Scan failure has no retry action. Filtering can show No Results and zero projected skills while the detail pane and toolbar keep operating on the previously selected skill from the full snapshot.

**Fix:** Define distinct initial-loading, scanning-with-results, empty-library, scan-failure, and filtered-no-results states. Give failure an explicit retry and settings path. Clear detail when selection exits the projection, or deliberately label it as pinned outside the current filter.

**Suggested command:** `/harden`

### [P2] Important actions are buried and inefficient for experts

**Evidence:** `SkillDetailView.swift:109`, `LibraryNodeView.swift:33`, `SpellbookApp.swift:41`.

More mixes source connection, package naming, identity merging or splitting, publishing, baseline management, Finder reveal, and removal. Package Name shows no active choice. The toolbar edit menu is announced as Compose in the live accessibility tree. Custom sidebar rows lack native arrow selection, and there are no app commands for scan, updates, edit, reveal, or navigation.

**Fix:** Move source actions into Source, installation actions into installation rows, and publishing into a task-focused group. Reserve More for secondary commands. Mark active submenu choices, add an explicit Edit skill accessibility label, and add native commands and list traversal.

**Suggested command:** `/distill`

## Persona Red Flags

### Alex, power user

- No discoverable shortcuts for scan, updates, edit, reveal, mode switching, or next and previous skill.
- Seven-plus More-menu actions slow repeated work and mix unrelated task domains.
- The editor is narrow, has no line numbers, and provides no source/preview or independent wrapping control.
- Collapsed Agent groups can hide the selected skill while its detail remains open.

### Sam, keyboard and VoiceOver user

- Scan, update, settings, and mode controls have useful accessible names, and status does not rely on color alone.
- Long Markdown documents lack semantic heading, list, and table navigation.
- Custom library rows support click and Return but no explicit native arrow traversal or Space activation.
- The edit menu is announced as Compose, and several grouped settings rows collapse into undifferentiated text.

### Morgan, multi-agent developer

- Skill-first and agent-first switching can leave a detail whose row is filtered out or hidden in a collapsed group.
- Locally modified, conflict, unified, and observed change expose state but do not consistently explain the next operation.
- Publish can be disabled without explaining which source or destination prerequisite is missing.
- Independent installations and recoverable reviewed mutations are exactly right; the missing piece is a direct state-to-resolution path.

## Minor Observations

- Routine async actions only disable their button; connect, apply, save planning, update, publish, and Find Source need visible progress and accessible busy state.
- The newly added artwork gallery gives every candidate button only Generated or Imported text; up to eight candidates can therefore have indistinguishable VoiceOver names, and the selected checkmark is not exposed as a selected trait.
- Copy code gives no completion feedback.
- `MetadataRowView` and `MetadataLinkRowView` give the same grid labels different emphasis.
- The generic no-results title becomes oversized in a 240 to 300 point sidebar.
- Sources combines four jobs in one long pane; Appearance is much more legible and well chunked.

## Questions to Consider

- If a state earns the one allowed status indicator, should clicking it ever do less than open the exact resolution?
- Should filtering govern both panes, or intentionally pin detail outside the filter with an explicit explanation?
- Is the editor a lightweight emergency editor or a credible daily Markdown workspace?
- Would Sources be easier to understand if organized by tasks such as Add folders, Verify origins, and Configure publishing?
