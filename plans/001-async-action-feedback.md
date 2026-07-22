# 001 — Make consequential async actions visibly active

- **Status**: DONE
- **Commit**: UNBORN (repository has no initial commit)
- **Severity**: MEDIUM
- **Category**: Purpose, frequency, and accessibility
- **Estimated scope**: 3 files, about 70 lines

## Problem

Long-running actions disable their button without changing its appearance.

```swift
// MutationPlanReviewSheet.swift:48 — current
Button(commitTitle) { Task { await commit() } }
    .disabled(isCommitting)

// UpdateReviewSheet.swift:45 — current
Button(selectedIDs.count > 1 ? "Update Selected" : "Update") {
    Task { await applyUpdates() }
}
.disabled(selectedIDs.isEmpty || isApplying)
```

The same gap exists for `SkillProvenanceView.swift:17`: Find Source only disables while `model.isFindingSource` is true.

## Target

Preserve each button's dimensions and crossfade its normal label to a small native `ProgressView` plus an exact in-progress label. Use opacity only: 160ms `easeOut`; Reduced Motion uses 90ms `easeOut`. Labels: `Saving…`, `Applying…`, `Updating…`, `Restoring…`, `Moving…`, and `Finding…` as appropriate. No bounce, scale, or looping motion beyond the native spinner.

## Repo conventions to follow

- Native SwiftUI only; `DESIGN.md` sets 150–220ms as the normal transition range.
- Keep controls quiet and neutral; do not introduce colored progress UI.
- Add shared values in `Sources/SpellbookUI/SpellbookMotion.swift`; do not duplicate durations.

## Steps

1. Add `SpellbookMotion` with `feedbackDuration = 0.16`, `reducedFeedbackDuration = 0.09`, and helpers returning `.easeOut` animations.
2. In `MutationPlanReviewSheet`, add `accessibilityReduceMotion`, replace the string button initializer with a label builder, keep a stable minimum width, and animate only label opacity when `isCommitting` changes.
3. Derive the in-progress label from `plan.kind` without changing `commitTitle`.
4. Apply the same pattern to `UpdateReviewSheet` using `isApplying` and `Updating…`.
5. Apply the same pattern to Find Source using `model.isFindingSource` and `Finding…`.

## Boundaries

- Do not change operation semantics, disabled conditions, sheet dismissal, or error handling.
- Do not animate keyboard focus, sheet presentation, or the spinner itself beyond system behavior.
- Do not add dependencies.

## Verification

- **Mechanical**: `xcrun swift test`; Debug `xcodebuild` for scheme Spellbook. Both must pass.
- **Feel check**: trigger Find Source and a mutation review. Button frames must not jump, activity must appear immediately, and rapid failure must retarget cleanly.
- Enable Reduce Motion in macOS Accessibility; confirm the label still crossfades in 90ms with no transform.
- **Done when**: every listed async button visibly communicates work while preserving existing behavior.

## Verification result

DONE on 2026-07-21. Stable dual-label button containers, exact progress copy, accessibility labels, and 160ms/90ms opacity feedback are implemented for mutation commits, bulk updates, and source discovery. The complete Swift package suite and Debug app build pass.
