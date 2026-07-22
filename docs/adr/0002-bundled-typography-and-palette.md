# ADR 0002: Bundled Typography and Custom Palette

Status: Accepted — 2026-07-22

## Decision

Bundle and process-register Schibsted Grotesk for app-owned interface and prose, and Commit Mono for code-like content. Disable programming ligatures. Use a custom neutral light/dark/Increase Contrast palette. Reserve blue for links, focus, and updates; use neutral actions and selection.

## Rationale

This gives Spellbook a consistent reading voice and prevents the user's macOS accent from changing core hierarchy. The palette remains quiet while status and diff meanings stay distinct.

## Consequences

Font registration happens before views resolve typography. Debug builds assert missing resources; release builds fall back safely. Core Text provides per-glyph fallback. macOS-owned UI keeps native SF typography and presentation.
