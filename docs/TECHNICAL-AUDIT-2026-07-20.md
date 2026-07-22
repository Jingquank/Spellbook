# Spellbook Technical Audit

Date: 2026-07-20  
Scope: native macOS SwiftUI app, package modules, and current build/test surface

## Post-remediation health score

| # | Dimension | Score | Verification |
|---|---|---:|---|
| 1 | Accessibility | 4/4 | Actionable controls, local image alt/failure states, independent reader scaling, editor labeling, semantic high-contrast text, and a passing scoped macOS accessibility audit. |
| 2 | Performance | 4/4 | Markdown artifacts parse off-main and cache by source; search uses debounced GRDB FTS; 1,000-skill scan and projection budgets pass. |
| 3 | Responsive design | 4/4 | The split view remains resizable and review/editor sheets now use flexible minima with vertical diff fallback at constrained widths. |
| 4 | Theming | 3/4 | System/Light/Dark and density/type controls are complete; final brand icon and a manual Increase Contrast matrix remain release inputs. |
| 5 | Anti-patterns | 4/4 | The interface remains native, dense, restrained, and free of dashboard/card-grid or decorative AI styling. |
| **Total** |  | **19/20** | **Release-candidate engineering quality; distribution inputs remain.** |

Resolved since the baseline audit:

- Sidebar status is a real labeled action and includes missing/access-required states.
- Markdown parsing and search no longer run synchronously through SwiftUI projection paths.
- Relative Markdown images are path-confined, rendered locally or remotely, and expose alt/failure labels.
- Reader and AppKit editor typography share persisted reader scaling.
- Identity thumbnails use controlled contrast-aware palettes.
- Review and conflict sheets adapt to constrained macOS windows.
- The package stress suite and macOS launch, dark appearance, and accessibility UI tests are automated.
- Deterministic failures at all six mutation checkpoints preserve the original file.

XCTest's pixel-contrast audit reports false failures for semantic primary text
over macOS material/sidebar surfaces. Contrast is therefore a named manual
System, Light, Dark, and Increase Contrast release check. Automated auditing
continues to enforce hit regions, sufficient descriptions, and actions while
filtering framework-owned Group, Other, Menu, and Touch Bar nodes.

## Baseline audit before remediation

| # | Dimension | Score | Key finding |
|---|---|---:|---|
| 1 | Accessibility | 2/4 | Actionable row status is announced but is not actionable; reader images and editor labeling are incomplete. |
| 2 | Performance | 2/4 | Markdown parsing and full-content search can run synchronously from SwiftUI/model projection paths. |
| 3 | Responsive design | 3/4 | The split view is resizable, but several review sheets use large fixed minimum sizes and have no constrained-window layout. |
| 4 | Theming | 3/4 | Most colors are semantic and System/Light/Dark work, with a few fixed white/black and named-palette exceptions. |
| 5 | Anti-patterns | 4/4 | The interface stays native, restrained, dense, and free of AI-dashboard styling. |
| **Total** |  | **14/20** | **Good; address accessibility and main-thread work before release.** |

## Anti-pattern verdict

Pass. The implementation does not read as generic AI-generated UI. It uses a native split view, sidebar list, grouped settings, system typography, restrained semantic color, and standard controls. There are no gradients, glowing actions, glass cards, card-grid dashboards, fantasy ornament, or decorative motion. The one recurring visual risk is the generated thumbnail palette, which uses several generic named colors and fixed white monograms rather than a contrast-aware identity token.

## Executive summary

- Audit score: **14/20 (Good)**.
- Issues: **0 P0, 4 P1, 4 P2, 1 P3**.
- Release-critical work is concentrated in actionable status behavior, Markdown rendering/accessibility, moving parsing/search off the main actor, and large-library validation.
- The native component vocabulary, semantic system surfaces, keyboard shortcuts, color-independent diff labels, and restrained density are strong foundations.

## P1 findings

### [P1] Sidebar status is descriptive, not actionable

- Location: `StatusIndicatorView.swift`, `SkillRowView.swift`, `SkillRecord.swift`
- Category: Accessibility
- Impact: VoiceOver can hear the status, but keyboard and pointer users cannot activate the promised next action from the row. Missing and Access Required states are also excluded from roll-up, so inaccessible skills can appear undecorated.
- Standard: WCAG 2.1.1 Keyboard; WCAG 4.1.2 Name, Role, Value; locked status behavior in `DESIGN.md`.
- Recommendation: model action-required states in the roll-up and make the single trailing indicator a labeled button that opens the relevant update, conflict, source, or access repair flow.
- Suggested command: `/harden`

### [P1] Markdown parsing and search can block the main actor

- Location: `NativeMarkdownReaderView.swift:8`; `SpellbookModel.projection`; `LibraryProjection.swift:13`; `SkillRecord.searchText`
- Category: Performance
- Impact: opening or re-rendering a long skill reparses the full document in `body`, while each search keystroke rebuilds and scans full Markdown strings for the library. Navigation can hitch with large packages or 1,000 skills.
- Standard: project concurrency invariant in `docs/BUILD-PLAN.md`; responsive interaction expectations for macOS.
- Recommendation: parse immutable Markdown artifacts off-main and cache by content hash; debounce search and use the existing GRDB FTS index to project matching IDs.
- Suggested command: `/optimize`

### [P1] Local Markdown images are reduced to text placeholders

- Location: `MarkdownAttributedStringBuilder.swift:33`; `NativeMarkdownReaderView.swift`
- Category: Accessibility
- Impact: skill documentation that relies on screenshots or diagrams loses content. Alt text is rendered as bracketed prose without an image role, and local path authorization/traversal policy is not exercised.
- Standard: WCAG 1.1.1 Non-text Content; locked reader requirements in `DESIGN.md` and `docs/BUILD-PLAN.md`.
- Recommendation: emit image-aware reader runs/blocks, resolve local assets relative to the authorized package root, reject path escape, and expose alt text or a labeled unreadable-image placeholder.
- Suggested command: `/harden`

### [P1] Text scaling is incomplete across the reader and editor

- Location: `AppearanceSettingsView.swift`; `SkillRowView.swift`; `MarkdownBlockView.swift`; `MarkdownSourceEditorView.swift`
- Category: Accessibility
- Impact: the Interface Text preference mainly changes sidebar rows. Reader hierarchy and AppKit editor size remain fixed, so users who need larger text get an inconsistent surface and may need system zoom.
- Standard: WCAG 1.4.4 Resize Text; product accessibility context.
- Recommendation: apply a shared interface scale environment, provide an independent reader scale, update the `NSTextView` font when preferences change, and verify at the largest supported setting.
- Suggested command: `/typeset`

## P2 findings

### [P2] Review sheets assume a large window

- Location: `SkillEditorSheet.swift`, `MutationPlanReviewSheet.swift`, `ExternalEditConflictSheet.swift`, `UpdateReviewSheet.swift`
- Category: Responsive design
- Impact: fixed 760–780 point minima and side-by-side comparisons can crowd small laptop workspaces, Stage Manager, or large text settings.
- Recommendation: switch comparisons to vertical layout below a measured width, constrain sheet height to available space, and preserve a readable scroll region.
- Suggested command: `/adapt`

### [P2] Generated thumbnail contrast is not guaranteed

- Location: `SkillIconView.swift:14`; `AgentIconView.swift:28`
- Category: Accessibility / Theming
- Impact: fixed white glyphs on orange, pink, green, or teal can fall below desired contrast in some appearances. Fixed black for Cursor also bypasses Increase Contrast behavior.
- Standard: WCAG 1.4.3 Contrast; WCAG 1.4.11 Non-text Contrast.
- Recommendation: use contrast-aware foreground selection or controlled light/dark identity pairs and verify Increase Contrast.
- Suggested command: `/harden`

### [P2] Multiple independent alert bindings compete on complex views

- Location: `SkillDetailView.swift`; `SkillEditorSheet.swift`; `GeneralSettingsView.swift`
- Category: Accessibility / Responsive design
- Impact: simultaneous mutation, confirmation, catalog, and conflict states can compete for presentation, making focus return and VoiceOver announcement order less predictable.
- Recommendation: consolidate presentation into one typed alert/sheet route per view and restore focus to the initiating control.
- Suggested command: `/harden`

### [P2] No automated accessibility or large-library gate

- Location: `App/SpellbookUITests/SpellbookUITests.swift`; package test targets
- Category: Accessibility / Performance
- Impact: the only UI test verifies launch and search-field existence. Regressions in VoiceOver labels, keyboard actions, 1,000-row scrolling, and scan latency can ship unnoticed.
- Recommendation: add `performAccessibilityAudit`, keyboard navigation coverage, appearance matrix launch tests, and deterministic 1,000-skill/5,000-file scan and projection budgets.
- Suggested command: `/harden`

## P3 finding

### [P3] A few visual values bypass semantic design tokens

- Location: `SkillIconView.swift`; `AgentIconView.swift`; `MutationDiffComparisonView.swift`
- Category: Theming
- Impact: fixed named colors make future brand tuning and high-contrast review more scattered, though current system surfaces remain coherent.
- Recommendation: centralize identity and diff semantic styles while retaining official agent color where known.
- Suggested command: `/polish`

## Systemic patterns

- The code generally uses native semantic colors and controls, but identity artwork is not yet centralized into a contrast-aware token layer.
- Async infrastructure boundaries are strong; the remaining main-thread work leaks in at SwiftUI projection and Markdown rendering boundaries.
- Review and recovery workflows are explicit and accessible in wording, but presentation state is distributed across several booleans and optional bindings.

## Positive findings

- The visual language is restrained and closely follows the locked ASIDE-inspired density direction.
- System, Light, and Dark appearance choices use native semantic surfaces rather than hard-coded canvases.
- Icon-only buttons retain semantic button titles, help text, or explicit accessibility labels.
- State is not encoded by color alone: status has symbols/labels and diffs show textual addition/removal counts.
- Native controls, keyboard default/cancel shortcuts, selectable technical text, and resizable split navigation provide a solid macOS baseline.
- Filesystem, Git, catalog, and FSEvents work is isolated from SwiftUI views; strict-concurrency and warnings-as-errors builds pass.

## Recommended actions

1. **[P1] `/optimize`**: move Markdown parsing and FTS-backed search off the main actor, then add the 1,000-skill budget.
2. **[P1] `/harden`**: make status actionable, add image/path safety, consolidate presentation routes, and add automated accessibility coverage.
3. **[P1] `/typeset`**: make interface, reader, and editor scaling consistent.
4. **[P2] `/adapt`**: add constrained-width review layouts and large-text verification.
5. **[P3] `/polish`**: centralize contrast-aware identity/diff tokens and run the final appearance matrix.

Re-run `/audit` after fixes to measure the score again.
