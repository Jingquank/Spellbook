# ADR 0001: Layered Design Tokens

Status: Accepted — 2026-07-22

## Decision

Use one internal `SpellbookDesign` namespace with primitives, semantic roles, and component recipes. Views consume semantic roles or recipes. `SpellbookMotion` stays independent.

## Rationale

The previous `SpellbookMetrics` constants and view-local values mixed scale, intent, and component geometry. Layers preserve a small reusable scale while allowing explicit component contracts and deterministic review.

## Consequences

Production UI is migrated with visual parity before redesign. A source guard rejects new orphan visual values. Artwork math, content geometry, behavior values, and motion are documented exceptions.
