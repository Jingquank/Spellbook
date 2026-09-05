# 1. Parameterise the five thumbnail compositions

Date: 2026-08-29

## Status

Accepted.

## Context

`design/thumbnails.js` seeds a tile from two hashes: the package id picks one of 7
palettes, the skill id picks one of 5 compositions. Inside a composition, the only
variation is two booleans derived from `seed % 2` and `seed % 3`. The reachable
output is therefore **35 tiles**, nudged by an inferred category that only rotates
the colour order.

Two facts made this untenable.

First, the artwork unit is the **install folder**, not the package and not the skill.
A folder downloaded on its own gets one tile; a multi-skill skillset folder gets one
tile for the set. This machine holds 41 install folders.

Second, 41 folders into 35 bins collides by the pigeonhole principle. Measured on
the real corpus with an 8x8 perceptual signature, the shipped renderer produces
**34 distinct tiles for 41 folders — 32% share a twin**, with a three-way tie between
`grill-with-docs`, `claude-md-management` and `frontend-design`. By the birthday
bound the shipped space is more likely than not to collide at **7 folders**. This was
never a tuning problem; the corpus outgrew the generator at its eighth entry.

The original design deliberately tied palette to package so that "one package reads
as one family". That intent assumed a marketplace world of many small packages. The
actual filesystem is one large loose folder of personal skills plus a tail of
plugins, so the family signal was spending the entire colour axis to say almost
nothing.

Four expansions were prototyped against the real corpus and compared by measured
collision rate, not by argument: parameterising the existing compositions,
continuous hue rotation, adding seven new composition families, and the last two
combined.

## Decision

Keep the 7 curated palettes and the 5 composition families. Drive the interior of
each composition from the folder hash: element counts, ring and blade counts,
rotation, gutters, split positions, crop offsets.

Palette continues to come from the folder identity. A composition family remains a
recognisable silhouette, so sibling tiles still rhyme; the parameters guarantee that
no two folders resolve to the same image. Measured output: **41 distinct tiles for
41 folders**, with headroom to roughly 445 folders before a collision is more likely
than not.

Continuous hue rotation was rejected: it scores well numerically while destroying
the seven curated colour stories and admitting every muddy intermediate hue, which
would make the set read as generated rather than chosen. Adding composition families
was rejected as the primary move because 84 bins only buys headroom to 11 folders —
it remains available as a later addition on top of this decision.

## Consequences

- Pixel parity with the retired Swift renderer is deliberately broken. Nothing
  depends on it; the macOS app was retired at `1fdffd3`.
- Every existing tile changes once. Because tiles are deterministic and users learn
  them, this reshuffle should happen exactly once, not incrementally.
- A composition family becomes a loose resemblance rather than a fixed silhouette.
  Recognition shifts from "which of five shapes" toward "which specific instance",
  which is the behaviour a 41-folder library needs.
- The category inference still rotates colour order and is now the weakest part of
  the seed. It can be removed later without affecting uniqueness.
