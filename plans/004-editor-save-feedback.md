# 004 — Clarify editor save completion

- **Status**: DONE
- **Commit**: UNBORN (repository has no initial commit)
- **Severity**: MEDIUM
- **Category**: Feedback
- **Estimated scope**: 2 files, about 35 lines

## Problem

At `SkillEditorSheet.swift:90`, `didSave` instantly replaces helper text with Apply to other agents and changes Save to Done. The operation succeeds, but the footer teleports between states.

## Target

Crossfade the leading footer region and trailing primary label independently over 160ms `easeOut`, opacity only. Preserve frames and alignment. Reduced Motion uses 90ms `easeOut`. Do not add celebration, bounce, or a transient toast.

## Repo conventions to follow

- Reuse the feedback values in `SpellbookMotion` from plan 001.
- Keep the explicit Apply to other agents action and existing save semantics.

## Steps

1. Read `accessibilityReduceMotion` in `SkillEditorSheet`.
2. Isolate the leading footer state and give it stable identity for `didSave`, using opacity transition only.
3. Replace the primary string initializer with a stable label container that crossfades Save to Done without resizing.
4. Attach animation only to `didSave`; draft typing and external change reconciliation must remain unanimated.

## Boundaries

- Do not animate the editor content, keyboard focus, draft text, conflict sheet, or sheet dismissal.
- Do not change save validation or mutation planning.

## Verification

- **Mechanical**: run all Swift tests and Debug app build.
- **Feel check**: save a skill, confirm both footer changes read as one completion event, then invoke Apply to other agents.
- Under Reduced Motion, confirm a brief opacity change remains and no layout shifts occur.
- **Done when**: successful save state is clear without slowing repeat editing.

## Verification result

DONE on 2026-07-21. The leading footer and primary label retain stable containers and crossfade only when a committed save exposes the Apply action; typing, draft reconciliation, editor content, and focus remain unanimated. The complete Swift package suite and Debug app build pass.
