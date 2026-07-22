# Spellbook Build Plan

Status: Finalized  
Date: 2026-07-20  
Inputs: [PRODUCT.md](../PRODUCT.md), [DESIGN.md](../DESIGN.md), [SPELLBOOK-BRIEF.md](SPELLBOOK-BRIEF.md)

Implementation evidence and remaining distribution inputs are tracked in
[IMPLEMENTATION-VERIFICATION.md](IMPLEMENTATION-VERIFICATION.md). Product
scope changes require updating the locked brief before changing this plan.

## 1. Outcome

Build a signed and notarized native macOS application that discovers existing skills for Claude Code, Cursor, and Codex; presents them in Skill-first and Agent-first libraries; renders their Markdown; tracks provenance and local modifications; safely edits independent installations; applies changes to other agents only when explicitly requested; and updates clean skills or packages through a reviewed, recoverable workflow.

The first release ends at the trustworthy Update All workflow. Authenticated GitHub push, automatic bidirectional sync, a marketplace, runtime-loaded adapters, and additional agents remain post-release work.

## 2. Locked Technical Decisions

| Area | Decision |
| --- | --- |
| Platform | Native macOS app, deployment target macOS 14 or newer |
| Language | Swift 6 language mode with strict concurrency enabled from the first commit |
| Interface | SwiftUI app shell, AppKit bridges where native editing or filesystem behavior needs them |
| Distribution | Developer ID signed and notarized direct download, Hardened Runtime enabled, App Sandbox disabled for the first release |
| Persistence | SQLite in WAL mode with FTS5 through GRDB |
| Markdown | One canonical syntax tree through `swift-markdown`; no WebView reader |
| Filesystem changes | Plan, review, commit, verify, and recover through one mutation module |
| File observation | FSEvents as an invalidation signal followed by targeted reconciliation |
| Git | Local Git and public GitHub sources in the first release; authenticated publishing deferred |
| Product state | Local files remain the truth; SQLite is an index and operation record |
| Dependencies | Start with GRDB 7.11.1 and swift-markdown 0.8.0; commit `Package.resolved` |

App Sandbox is deferred because automatic discovery across several existing tool directories and local Git integration are core to the product. Spellbook still scans only known agent directories automatically. Additional roots require explicit selection, and Full Disk Access is never requested by default.

## 3. Project Structure

Use one Xcode project with one local Swift package:

```text
Spellbook/
├── Spellbook.xcodeproj
├── App/
│   ├── SpellbookApp/
│   └── SpellbookUITests/
├── Packages/
│   └── SpellbookKit/
│       ├── Package.swift
│       ├── Sources/
│       │   ├── SpellbookCore/
│       │   ├── SpellbookMarkdown/
│       │   ├── SpellbookInfrastructure/
│       │   └── SpellbookUI/
│       └── Tests/
│           ├── SpellbookCoreTests/
│           ├── SpellbookMarkdownTests/
│           ├── SpellbookInfrastructureTests/
│           └── Fixtures/
├── docs/
└── .github/workflows/
```

### Target responsibilities

| Target | Responsibility | Must not contain |
| --- | --- | --- |
| `SpellbookCore` | Domain values, invariants, library projection, application interface, discovery reconciliation, provenance assessment, planning policies | SwiftUI, AppKit, GRDB, Git processes, concrete filesystem code |
| `SpellbookMarkdown` | Parse, normalize, render model, searchable text, outline, semantic Markdown diff | Persistence, agent logic, file mutation |
| `SpellbookInfrastructure` | GRDB store, FSEvents, coordinated file access, recovery journal, Git and HTTP sources, Claude/Cursor/Codex adapters | SwiftUI views or visual policy |
| `SpellbookUI` | App shell, reader, editor, review flows, settings, appearance tokens, `@MainActor` presentation state | Direct SQL, direct file writes, Git commands, agent-specific conditionals |
| `SpellbookApp` | Composition root, scenes, commands, entitlements, signing configuration | Product rules or data transformation |

Dependency direction:

```text
SpellbookApp
├── SpellbookUI ───────────────→ SpellbookCore
│       └──────────────────────→ SpellbookMarkdown
├── SpellbookInfrastructure ──→ SpellbookCore
│       └──────────────────────→ SpellbookMarkdown
└── SpellbookMarkdown ─────────→ SpellbookCore
```

No cyclic target dependencies are permitted.

## 4. Architecture Interfaces

### Application module

SwiftUI talks to one deep application module:

```swift
public protocol SpellbookApplication: Sendable {
    func observe() -> AsyncStream<ApplicationSnapshot>
    func scan(_ scope: ScanScope) async
    func plan(_ intent: OperationIntent) async throws -> OperationPlan
    func commit(_ approval: OperationApproval) async throws -> OperationReceipt
}
```

The interface hides discovery, reconciliation, persistence, source retrieval, diffing, mutation, recovery, and status roll-up. `observe()` immediately emits the current indexed snapshot, then incremental changes.

### Real adapter seams

Create adapters only where multiple implementations are required:

- `AgentAdapter`: Claude Code, Cursor, Codex.
- `PackageFormatAdapter`: standard skill directory, recognized package or plugin manifest, configurable single-file pattern.
- `SourceAdapter`: local Git, public GitHub, direct local file, recognized installer manifest.
- `CatalogStore`: GRDB production adapter and temporary SQLite test adapter.

Do not create public interfaces for clocks, UUID generation, every filesystem call, or every database table. Keep those as injected values or private test seams.

### Agent adapter responsibility

An agent adapter owns three behaviors:

1. Describe known discovery roots and supported layouts.
2. Interpret a directory snapshot as installation candidates.
3. Project canonical skill material into that agent's proposed file set.

Agent adapters never write files. All proposed writes pass through the mutation module.

### Package format responsibility

A package format adapter probes and decodes a discovered candidate. Probe ties become an explicit ambiguous state and manual entry-point flow. Registration order must never decide silently.

Bench and i-have-adhd are permanent contract fixtures:

- Bench decodes to one package and five skills.
- i-have-adhd decodes to one package and one skill.
- Flattening i-have-adhd is library presentation only; the package record always remains in the domain.

## 5. Domain and Identity Rules

Use immutable `Sendable` values and strongly typed identifiers for agent, package, skill, installation, source, operation, and tracked file.

Core records:

- `PackageRecord`: provenance and update unit.
- `SkillRecord`: reading and conceptual library unit.
- `InstallationRecord`: one independent physical copy for one agent.
- `SourceBinding`: source locator plus evidence and confidence.
- `ContentFingerprint`: normalized entry Markdown hash plus supporting-file manifest.
- `BaselineRecord`: exact managed revision, recoverable source revision, or absent.
- `OperationRecord`: planned targets, approvals, results, and recovery data.

Invariants:

1. Package identity comes from a verified manifest or normalized source plus subdirectory when available; otherwise use a persistent local UUID.
2. Skill identity is package identity plus a declared or inferred stable key, never display name alone.
3. Installation identity is agent plus canonical location, reconciled with filesystem resource identity where available.
4. Similar names or content never silently merge two skills.
5. A skill installed for three agents retains three installation records.
6. Every edit, removal, or update names installation IDs explicitly.
7. Single-skill package flattening never deletes or bypasses the package relationship.
8. `Modified` requires a baseline or matching source revision. Without evidence, state is `Unverified`.
9. Exact installed or updated time is recorded only for Spellbook-managed operations. File dates remain labeled observations.
10. Actionable status priority is conflict, modified, then update available.

## 6. Persistence Schema

Start with versioned GRDB migrations for:

- `agents`
- `packages`
- `skills`
- `installations`
- `sources`
- `trackedFiles`
- `baselines`
- `provenanceEvidence`
- `operations`
- `operationFiles`
- `grantedRoots`
- `userOverrides`
- `settings`
- `skillSearch` FTS5 table

Persist raw Markdown, normalized hashes, extracted search text, file manifests, evidence, preferences, operation timestamps, and recovery metadata. Do not persist the parsed Markdown syntax tree. Rebuild and cache it so parser changes do not require data migrations.

If the index is missing or corrupt, local skill files remain untouched. The app offers an index rebuild. Migration failure should preserve the original database and enter a repair state rather than silently creating an empty library.

## 7. Concurrency and Filesystem Model

- `@MainActor SpellbookModel` owns window presentation state.
- `LibraryActor` owns reconciliation and immutable application snapshots.
- `DatabaseActor` serializes GRDB writes and migrations.
- `FileObservationActor` owns FSEvents streams and debounced targeted rescans.
- `MutationActor` serializes Spellbook-managed filesystem changes.
- `SourceActor` limits concurrent Git and network work.

No filesystem traversal, hashing, Markdown parsing, SQL, Git, or network request runs on the main actor.

FSEvents indicates that a directory hierarchy changed. It does not identify truth by itself. Coalesce bursts, map them to the nearest known package root, and reconcile that root from disk. A relaunch scan and periodic low-priority reconciliation cover missed or ambiguous events.

Spellbook-authored events are correlated by operation ID and expected fingerprints. Do not ignore all events for a time window, because an agent may edit the same file during that window.

## 8. Markdown Pipeline

Use `swift-markdown` as the only full-document parser. The Markdown module exposes opaque document artifacts rather than leaking parser node types.

One parse produces:

- Native reader blocks.
- Editor preview.
- Heading outline.
- Plain search text.
- Normalized content fingerprint.
- Semantic diff input.

Use SwiftUI for reader blocks and an AppKit `NSTextView` bridge for source editing. Code blocks initially provide monospaced text, horizontal scrolling or wrapping, language labels, and copy actions. Advanced language syntax highlighting is deferred until the reader, diff, and accessibility behavior are stable.

Resolve local images relative to the authorized package root. Canonicalize the path and reject traversal outside that root. Missing or unreadable assets render a labeled placeholder instead of breaking the document.

## 9. Mutation and Recovery Pipeline

Every save, Apply to other agents action, update, and removal follows the same flow:

1. Resolve intent and construct all proposed agent-specific file sets.
2. Read current fingerprints and attach them as preconditions.
3. Materialize candidate files in a staging directory.
4. Calculate per-file and per-installation diffs.
5. Return an immutable review plan without changing local skills.
6. Revalidate paths, permission, attribution, and fingerprints after approval.
7. Write a durable recovery journal and create all backups before the first mutation.
8. Coordinate access with `NSFileCoordinator` and replace each file atomically where supported.
9. Re-read and verify every resulting fingerprint.
10. Roll back the affected installation when verification fails.
11. Record per-target outcomes and request targeted reconciliation.

A multi-file, multi-root operation cannot be globally atomic. Spellbook promises per-file atomic replacement, durable recovery information, verified rollback where safe, and explicit partial outcomes.

Removal moves attributable files to a recoverable Spellbook Trash or macOS Trash. Unknown adjacent files are left untouched.

## 10. Milestones

### M0: Repository and build foundation

Tasks:

- Initialize Git and create the macOS Xcode project under the existing repository root.
- Add the local `SpellbookKit` package and enforce the dependency graph above.
- Add GRDB and swift-markdown at the locked starting versions.
- Enable Swift 6 strict concurrency, Hardened Runtime, test targets, and warnings as errors in CI.
- Add a GitHub Actions macOS build and test workflow with signing disabled for test builds.
- Add fixture licenses and provenance notes before copying external fixture content.
- Create synthetic Bench-like and i-have-adhd-like fixtures if upstream content cannot be redistributed.

Exit gate:

- A blank native window builds locally and in CI.
- Every package target has a running smoke test.
- Dependency direction is documented and cycle-free.
- No concurrency warnings are accepted into the baseline.

### M1: Domain, projections, reader, and fixture shell

Tasks:

- Implement identifiers, records, evidence, confidence, fingerprints, and invariants.
- Implement reconciliation without filesystem dependencies.
- Implement Skill-first and Agent-first projections.
- Implement one-skill flattening and the Always show package groups preference.
- Implement actionable indicator roll-up and priority.
- Implement the canonical Markdown artifact and native reader blocks.
- Build the dense two-pane shell, search field, view switcher, detail header, reader, and settings shell against fixture snapshots.
- Keep location and directory as detail fields alongside author, website or repository, installed or updated time, and agent installation information. Paths never become a top-level organizing group.
- Implement System, Light, Dark; Compact, Comfortable; type scale; reader width; and code wrapping.

Exit gate:

- Bench fixture appears as one package with five skills.
- i-have-adhd fixture appears as one skill by default and as a package group when the setting is enabled.
- One skill with Claude, Cursor, and Codex installations remains one skill with three independent installation fields.
- The detail header exposes author, website or GitHub repository, package, location, observed or exact dates, and installed agent versions without crowding the sidebar row.
- Compact sidebar rows and settings match the density tokens in `DESIGN.md`.
- Keyboard selection, VoiceOver labels, dark mode, and 1,000-row sidebar scrolling are verified.

### M2: Live inventory and search

Tasks:

- Implement GRDB schema, migrations, transactions, FTS5, and database repair entry points.
- Implement known-root detection for Claude Code, Cursor, and Codex.
- Implement the three agent adapters and package format adapters.
- Recognize standard `SKILL.md`, agent-specific Markdown layouts, `.agent.claude.md`, manifests, references, scripts, and assets.
- Implement explicit Add Folder and granted-root persistence.
- Implement progressive scanning, cancellation, symlink protection, bounded retry, and partial diagnostics.
- Reconcile discoveries into the catalog without false deletion after incomplete or permission-limited scans.
- Extract metadata by the locked precedence rules and label unknown or approximate values.
- Connect FTS search across names, descriptions, authors, packages, agents, paths, and Markdown text.
- Restore the indexed library immediately on relaunch, then reconcile in the background.

Exit gate:

- Supported pre-existing skills appear after first launch without manual re-import.
- Initial results stream into the sidebar before the full scan completes.
- Relaunch shows the cached library before reconciliation finishes.
- Permission denial keeps the rest of the library usable.
- Ambiguous identity remains duplicated or Unverified rather than silently merged.
- The 1,000-skill and 5,000-file fixture completes without blocking navigation.

### M3: External changes and provenance

Tasks:

- Implement FSEvents root observation and targeted package rescans.
- Add baseline storage, normalized content comparison, and supporting-file manifests.
- Implement managed, identifiable-source, and unmanaged provenance tiers.
- Implement Clean, Modified, Conflict, Unverified, Missing, and Access Required states.
- Distinguish exact managed operation time from observed file modification time.
- Add Connect Source and Set Current as Baseline actions.
- Add missing-file, revoked-permission, malformed-package, and unsupported-layout repair flows.
- Refresh an open reader after safe external changes.

Exit gate:

- External agent edits appear in the library promptly through targeted reconciliation.
- Timestamps alone never produce a Modified claim.
- An orphan skill without a source displays Unverified.
- Revoked access preserves indexed metadata and disables mutation.
- The sidebar shows at most one actionable indicator in the locked priority order.

### M4: Safe editing, propagation, removal, and recovery

Tasks:

- Build the installation-scoped `NSTextView` editor and rendered preview.
- Track editor base fingerprint, draft state, selected installation, and external conflicts.
- Implement generic operation plans and the review UI.
- Implement staging, durable journal, backups, coordinated writes, atomic replacement, verification, rollback, and receipts.
- Save only the selected installation.
- Implement Apply to other agents as a new explicit multi-target plan with agent-format adaptation and per-target diffs.
- Implement recoverable removal by installation, selected agents, or package.
- Add crash-start recovery that detects and completes or rolls back interrupted operations.
- Add operation history and Reveal Backup or Restore actions.

Exit gate:

- Editing one installation changes no sibling installation.
- Apply to other agents never has implicit targets and always previews every destination.
- An external edit to a dirty document creates a conflict and preserves both versions.
- Unknown adjacent files survive package removal.
- Injected failure at every mutation stage leaves a verified receipt and a recoverable state.
- Relaunch during an interrupted operation enters recovery before permitting more writes.

### M5: Source updates and Update All

Tasks:

- Implement local Git, public GitHub, direct-file, and recognized-manifest source adapters.
- Add Git availability checks and clear offline, missing-revision, rate-limit, and source-mismatch states.
- Fetch candidate package content into staging without touching installations.
- Build package-level update comparison and affected-skill roll-up.
- Add Markdown semantic diff with line-based fallback.
- Implement per-skill, per-package, selected, and Update All review queues.
- Batch only clean and verified updates under one confirmation.
- Pause modified, conflicting, unauthenticated, or unverified targets for individual resolution.
- Run accepted updates through the same mutation and recovery pipeline as edits.

Exit gate:

- A Bench package update names all changed skills and every affected installation.
- i-have-adhd updates as one skill while retaining package provenance.
- Update All never replaces a locally modified file without an explicit per-item choice.
- Offline use leaves reading and local editing fully available.
- Partial package failure reports per-target results and remains recoverable.
- Network tests use deterministic adapters; integration tests use local bare Git repositories.

### M6: Release hardening

Tasks:

- Finish first-launch permission explanations, scan progress, empty state, and access repair.
- Complete keyboard commands, menus, context menus, focus restoration, VoiceOver, Increase Contrast, reduced motion, and text scaling.
- Profile launch, cached library load, scanning, FTS search, Markdown rendering, and sidebar scrolling.
- Add privacy-safe structured logging with paths redacted from exported diagnostics by default.
- Test database corruption, disk full, source outage, permission revocation, file replacement races, and crash recovery.
- Add app icon, About, acknowledgements, update mechanism decision, signing, notarization, and release packaging.
- Run the clean-account release matrix on the oldest and current supported macOS versions.

Exit gate:

- A clean machine can install, launch, discover known roots, read a skill, and complete a safe edit.
- Denying or revoking access is understandable and never risks local files.
- No filesystem or database work blocks the main actor.
- The signed and notarized build passes the full smoke and recovery matrix.
- Every acceptance criterion in `SPELLBOOK-BRIEF.md` has an automated or named manual verification.

## 11. Performance Budgets

Use a named reference Mac and record its hardware and OS with benchmark results.

- Cached library visible after launch: target under 500 ms.
- First discovered skill during an uncached scan: target under 2 seconds for known local roots.
- Full 1,000-skill and 5,000-file reference scan: target under 15 seconds.
- Search result refresh after settled input: target under 100 ms.
- External file edit reflected after the write settles: target under 2 seconds.
- Sidebar and reader scrolling: no sustained visible hitching under the stress fixture.
- No individual synchronous main-actor task over 16 ms during scanning or indexing.

These are regression budgets, not universal guarantees for network volumes or unavailable file providers. Slow roots must remain cancellable and must not block already indexed content.

## 12. Test Strategy

### Pure tests

Test identity, reconciliation, package grouping, one-skill flattening, status priority, evidence confidence, normalization, semantic diff policies, update classification, and plan generation through module interfaces.

### Adapter contracts

Run shared contract suites against every agent, package format, and source adapter. Required fixtures include:

- Bench-like one-package, five-skill layout.
- i-have-adhd-like one-package, one-skill layout.
- Claude, Cursor, and Codex copies of one skill with intentional divergence.
- `.agent.claude.md` and custom filename patterns.
- Nested references, scripts, and local images.
- Malformed frontmatter, invalid UTF-8, missing entry points, symlink cycles, and path escape attempts.

### Integration tests

Use real temporary directories, temporary SQLite databases, and local bare Git repositories. Cover migration, FTS, full and targeted scan, relaunch, permission loss, external edit, stale plan, coordinated write, rollback, restore, trash, and interrupted-operation recovery.

### UI tests

Cover both library views, package disclosure, selection retention, search, Compact and Comfortable density, appearance variants, reader, editor, update review, conflict resolution, keyboard navigation, VoiceOver labels, and empty or error states.

### Manual release matrix

Run on a clean macOS account with no agents, one agent, and all three agents; with network offline; with permissions denied and restored; and with the 1,000-skill stress fixture. Repeat with the signed and notarized artifact, not only an Xcode development build.

## 13. Delivery Order and Commit Boundaries

Keep commits independently buildable and reviewable. Recommended sequence:

1. Project, package targets, CI, and fixture harness.
2. Domain identities, evidence, and invariants.
3. Reconciliation, projections, and status policy.
4. Markdown artifact and reader model.
5. Fixture-driven SwiftUI shell and appearance settings.
6. GRDB schema, migrations, and FTS.
7. Agent and package format adapter contracts.
8. Claude, Cursor, and Codex discovery adapters.
9. Progressive scan, permissions, reconciliation, and search.
10. FSEvents observation and targeted rescans.
11. Provenance, baselines, metadata confidence, and repair states.
12. Editor draft and conflict model.
13. Plan-review-commit mutation and recovery journal.
14. Installation save, Apply to other agents, and removal.
15. Local Git and public GitHub source adapters.
16. Package update planning, diff, and Update All.
17. Accessibility, performance, diagnostics, and release recovery.
18. Signing, notarization, packaging, and release checklist.

Do not begin source update implementation before the mutation fault-injection suite passes. Do not begin authenticated GitHub publishing before the first release's pull and recovery behavior has shipped and been observed.

## 14. Risk Register

| Risk | Required mitigation |
| --- | --- |
| False package or skill identity merge | Bias toward separate Unverified records; require evidence before merging |
| Agent layouts evolve | Fixture-driven adapter contracts and versioned adapter behavior |
| Unknown package architecture | Confidence-based package probes and manual entry-point selection |
| FSEvents burst or missed detail | Debounce, targeted rescan, relaunch reconciliation, periodic low-priority reconciliation |
| External change races | Fingerprint preconditions, coordinated access, post-write verification |
| Multi-file partial write | Durable journal, complete backups before mutation, per-installation rollback and outcomes |
| Permission loss | Centralized granted-root handling, read-only indexed state, explicit repair |
| Database corruption | Preserve files, back up the database, rebuild index independently |
| Markdown scope expansion | One parser, permanent conformance fixtures, defer advanced highlighting |
| Git unavailable or source offline | Capability preflight, actionable errors, local features remain available |
| UI becomes web-like or spacious | DESIGN.md tokens, ASIDE-density fixture views, visual review at every milestone |
| Architecture fragments into shallow targets | Keep five targets; add a new target only when it earns a deep independent interface |

## 15. Deliberate Deferrals

The following are not part of the first release:

- Authenticated GitHub push or account OAuth.
- Automatic bidirectional or background sync.
- Runtime-loaded third-party adapter plug-ins.
- App Store sandbox distribution.
- Marketplace or online skill discovery.
- Automatic cross-agent propagation.
- Cloud accounts or a background daemon.
- CRDT or automatic three-way semantic merge.
- Advanced per-language code highlighting.
- Unrestricted whole-disk scanning.
- Agent adapters beyond Claude Code, Cursor, and Codex.

## 16. Definition of Done

A milestone is done only when:

- Its interface behavior is covered at the appropriate pure, contract, integration, or UI level.
- Its user-visible states match PRODUCT.md, DESIGN.md, and SPELLBOOK-BRIEF.md.
- Errors are actionable and do not imply certainty without evidence.
- File operations are off the main actor and safe under cancellation or failure.
- Accessibility labels and keyboard behavior are included with the feature.
- Performance is measured against the relevant budget.
- New persistence changes include a forward migration and migration test.
- Documentation names any new invariant, permission, recovery behavior, or deferred limitation.

The first release is done when M0 through M6 pass their exit gates and every locked acceptance criterion has a named verification result.

## 17. Primary Technical References

- [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [Coordinated file access with NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
- [File System Events](https://developer.apple.com/documentation/coreservices/file_system_events)
- [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [Swift Markdown](https://github.com/swiftlang/swift-markdown)
- [GRDB.swift](https://github.com/groue/GRDB.swift)
