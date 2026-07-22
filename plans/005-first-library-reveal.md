# 005 — Bridge the first library reveal

- **Status**: DONE
- **Commit**: UNBORN (repository has no initial commit)
- **Severity**: LOW
- **Category**: Preventing a jarring change
- **Estimated scope**: 2 files, about 50 lines

## Problem

`LibrarySidebarView.swift:14` conditionally replaces scan error, empty state, search empty state, and the library. The first successful scan can replace an empty/loading surface with up to 1,000 rows immediately.

## Target

Animate only the first empty/loading-to-library structural change: outgoing opacity over 100ms `easeOut`, followed by incoming container opacity over 180ms `easeOut`; total no more than 280ms. Do not animate individual rows. Reduced Motion uses 80ms out and 100ms in, opacity only. Search-result changes, sorting, view-mode changes, rescans of an existing library, and keyboard navigation must remain unanimated.

## Repo conventions to follow

- Reuse `SpellbookMotion`.
- Preserve lazy list construction and current empty-state copy.
- Motion is permitted only for the rare first reveal.

## Steps

1. Add first-reveal timings to `SpellbookMotion`.
2. In `LibrarySidebarView`, track whether a nonempty library has been shown during this view lifetime.
3. Apply a two-phase opacity transition only when that flag changes from false to true after a successful scan and `searchText` is empty.
4. Ensure projection changes while the library is already visible do not receive implicit animation.
5. Under Reduce Motion, shorten both opacity phases as specified.

## Boundaries

- Never animate `ForEach` rows, search filtering, sidebar selection, Skill/Agent switching, sort order, or disclosure groups.
- Do not delay interaction until the entrance completes.
- Do not add stagger, scale, blur, or positional movement.

## Verification

- **Mechanical**: run all Swift tests, the 1,000-skill performance test, and Debug app build.
- **Feel check**: launch with an empty cache and scan; confirm one calm container reveal. Scan again, search, sort, and switch views; confirm none of those animate.
- Under Reduce Motion, confirm the reveal remains legible and finishes in 180ms total.
- **Done when**: only the first successful population is bridged, with no cost to daily navigation.

## Verification result

DONE on 2026-07-21. The first successful empty/loading-to-library population uses a 100ms exit followed by a 180ms entrance; Reduce Motion totals 180ms. Search, sorting, view switching, rescans, selection, rows, and disclosures receive no implicit animation. Both 1,000-skill performance checks, the complete Swift package suite, and the Debug app build pass.
