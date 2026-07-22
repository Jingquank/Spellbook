# Spellbook animation plans

The repository has no initial Git commit, so these plans are stamped `UNBORN`. They implement the five motion opportunities approved after the full-app audit.

| # | Plan | Severity | Status | Dependencies |
|---|---|---|---|---|
| 001 | [Async action feedback](001-async-action-feedback.md) | MEDIUM | DONE | None; creates `SpellbookMotion` |
| 002 | [Source candidate transitions](002-source-candidate-transitions.md) | LOW | DONE | 001 |
| 003 | [Artwork gallery feedback](003-artwork-gallery-feedback.md) | LOW | DONE | 001 |
| 004 | [Editor save feedback](004-editor-save-feedback.md) | MEDIUM | DONE | 001 |
| 005 | [First library reveal](005-first-library-reveal.md) | LOW | DONE | 001 |

## Recommended execution order

1. Execute 001 to establish the shared native timing vocabulary.
2. Execute 004, then 002 and 003; they reuse the feedback and entrance helpers.
3. Execute 005 last and rerun the 1,000-skill performance check.

All plans prohibit motion on search, core navigation, list selection, sorting, and disclosure groups.
