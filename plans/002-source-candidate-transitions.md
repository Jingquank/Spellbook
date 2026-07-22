# 002 — Bridge source candidate arrival and dismissal

- **Status**: DONE
- **Commit**: UNBORN (repository has no initial commit)
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 2 files, about 35 lines

## Problem

`SkillProvenanceView.swift:58` inserts and removes candidate rows immediately after remote discovery:

```swift
ForEach(model.candidates(for: skill)) { candidate in
    candidateRow(candidate)
}
```

The change is occasional and asynchronous, so the abrupt appearance makes the result feel disconnected from Find Source.

## Target

Candidate entrance: opacity 0 plus scale 0.98 to settled over 180ms `easeOut`. Candidate exit: opacity to 0 over 140ms `easeOut`. Reduced Motion: opacity only over 100ms. Motion must be interruptible and driven by transitions, not keyframes.

## Repo conventions to follow

- Reuse `SpellbookMotion` from plan 001.
- Only animate `opacity` and `scaleEffect`; never row height, padding, or offset.
- Preserve the existing neutral candidate surface.

## Steps

1. Add source-candidate timing constants to `SpellbookMotion`: 0.18 entrance, 0.14 exit, 0.10 reduced.
2. Read `accessibilityReduceMotion` in `SkillProvenanceView`.
3. Give each candidate row the specified asymmetric transition; Reduced Motion returns `.opacity` only.
4. Attach animation to the stable candidate ID array so unrelated provenance text changes do not animate.

## Boundaries

- Do not animate evidence, metadata, links, errors, or detail navigation.
- Do not change candidate acceptance/rejection behavior.
- Do not stagger multiple candidates.

## Verification

- **Mechanical**: run all Swift tests and Debug app build.
- **Feel check**: run Find Source with zero, one, and multiple results; dismiss a result mid-entrance and confirm motion retargets rather than restarts.
- Under Reduce Motion, confirm candidates only fade.
- **Done when**: candidate arrival is connected to discovery without moving readable source content unnecessarily.

## Verification result

DONE on 2026-07-21. Candidate identity changes drive asymmetric 180ms entrance and 140ms exit transitions; Reduce Motion uses a 100ms opacity-only transition. Source evidence, navigation, and candidate actions remain unchanged. The complete Swift package suite and Debug app build pass.
