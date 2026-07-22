# Spellbook Implementation Verification

Status: Developer build complete; release credentials and final brand asset pending  
Date: 2026-07-20  
Source of truth: [BUILD-PLAN.md](BUILD-PLAN.md)

## Milestone status

| Milestone | Status | Verification |
| --- | --- | --- |
| M0 — Foundation | Complete | Native macOS 14 Swift 6 app, five-module dependency graph, pinned package resolution, strict package compilation, and CI workflow. |
| M1 — Domain and reader | Complete | Skill-first and Agent-first projections, Bench five-skill grouping, one-skill flattening preference, native Markdown, dense two-pane shell, and appearance settings. |
| M2 — Inventory and search | Complete | GRDB migrations and FTS5, cached launch, Claude/Cursor/Codex roots, custom folders, progressive scanner, symlink protection, and corrupt-index repair. |
| M3 — External changes | Complete | FSEvents-targeted reconciliation, evidence baselines, missing/access states, source connection, and one actionable status indicator. |
| M4 — Safe management | Complete | Installation-scoped editor, explicit Apply to other agents, reviewed removal, durable journal, backups, verification, rollback, restore, crash recovery, and operation history. |
| M5 — Sources and Update All | Complete for explicit sources | Public or local Git repositories and direct Markdown sources stage per-file plans through the mutation pipeline. Bench-style package updates identify all five skills and every installation. Auto-detected in-place Git repositories retain a separate fast-forward fallback; migrate that fallback to the generic journal before public release or require an explicit source connection. |
| M6 — Release hardening | Engineering complete; distribution pending | Accessibility, dark appearance, constrained sheets, Markdown asset safety, strict compilation, stress budgets, and mutation fault injection pass. Developer ID signing, notarization, oldest-OS smoke testing, and the final app icon require release inputs. |

## Automated evidence

| Gate | Result |
| --- | --- |
| Strict Swift package suite | 44 tests passed with `-warnings-as-errors` |
| macOS UI suite | 3 tests passed: launch, dark appearance, and accessibility descriptions/actions/hit regions |
| 1,000 skills / 5,000 files scan | 1.01 seconds on the development Mac; budget is 15 seconds |
| 1,000-skill projection | 16.3 milliseconds; settled search budget is 100 milliseconds |
| Mutation failure matrix | Original file preserved at all six checkpoints |
| Crash recovery | Interrupted journal restores the verified backup before new writes |
| Package contracts | Bench-like package yields five skills; one-skill package flattens by default and groups when enabled |
| Source contracts | Direct Markdown and five-skill Git package updates stage reviewed mutation plans |

The XCTest pixel-contrast audit is not a reliable automated gate for macOS
translucent sidebar/material backgrounds: it reported failures for semantic
primary text. Contrast remains a named manual check in System, Light, Dark,
and Increase Contrast appearances. The automated audit continues to cover
hit regions, descriptions, and actions, excluding framework-owned Group,
Other, Menu, and Touch Bar nodes.

## Remaining release inputs

1. Approve and add the final Spellbook app icon.
2. Supply the Apple Development Team ID, Developer ID Application identity,
   and a local `notarytool` keychain profile.
3. Decide whether automatic in-place Git updates ship in 0.1 or are replaced
   by the safer explicit Connect Source flow.
4. Execute the clean-account matrix on macOS 14 and the current macOS release.
5. Archive, notarize, staple, and assess the exact downloadable artifact.

No source skill file is required to complete these release-only steps.
