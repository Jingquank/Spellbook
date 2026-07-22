# 003 — Give the artwork gallery restrained feedback

- **Status**: DONE
- **Commit**: UNBORN (repository has no initial commit)
- **Severity**: LOW
- **Category**: Missed opportunity and state indication
- **Estimated scope**: 2 files, about 55 lines

## Problem

`ArtworkManagerSheet.swift:95` instantly replaces the empty state with a grid, and the selection checkmark at line 109 snaps between candidates.

## Target

- Empty state to gallery: opacity 0 plus scale 0.98 to settled over 200ms `easeOut`.
- Later candidate insertion: opacity 0 plus scale 0.98 over 180ms `easeOut`.
- Selection checkmark: opacity 0 plus scale 0.90 over 140ms `easeOut`, with a symmetric exit.
- Reduced Motion: opacity only, 110ms for container/candidates and 90ms for checkmark.

## Repo conventions to follow

- Reuse `SpellbookMotion`; native SwiftUI transitions only.
- Keep the existing 4-column grid, frame, image styling, and gallery limit behavior.

## Steps

1. Add artwork timing constants and Reduced Motion variants to `SpellbookMotion`.
2. Read `accessibilityReduceMotion` in `ArtworkManagerSheet`.
3. Animate the empty/grid branch only when `candidates.isEmpty` changes.
4. Animate candidate insertion/removal based on candidate IDs without staggering.
5. Add the checkmark transition keyed only to `selectedCandidateID`.

## Boundaries

- Do not animate Image Playground, file import panels, repository artwork, or the entire sheet.
- Do not add bounce, rotation, particles, glow, or color changes.
- Do not change gallery persistence or selection logic.

## Verification

- **Mechanical**: run all Swift tests and Debug app build.
- **Feel check**: generate/import the first, second, and ninth artwork; confirm no grid reflow animation and no implicit replacement of active art.
- Toggle Reduced Motion and confirm all scale is removed while feedback remains.
- **Done when**: generation has immediate, quiet feedback and gallery reading remains stable.

## Verification result

DONE on 2026-07-21. Empty/gallery, candidate, and selection states use the planned durations and scale values, with opacity-only Reduced Motion branches. The gallery’s adaptive layout, eight-candidate limit, replacement safety, and persistence behavior are preserved. The complete Swift package suite and Debug app build pass.
