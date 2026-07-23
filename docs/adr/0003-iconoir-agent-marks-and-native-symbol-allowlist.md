# ADR 0003: Iconoir, Agent Marks, and the Native Symbol Allowlist

Status: Accepted — 2026-07-23

## Decision

Spellbook-owned interface icons come from Iconoir revision
`10a66d02c6e3c94437bbf268352b1652e9eae7e5`. Assets are vendored as template
SVGs in the SpellbookUI SwiftPM asset catalog. Regular icons preserve their
24×24 geometry, caps, and joins while changing the upstream 1.5 stroke to 2.0.
Solid assets are limited to explicit binary state artwork.

`SpellbookIcon`, its four size tokens, semantic color roles, and reusable icon
views/buttons are the only app-owned icon API. Raw SF Symbol calls are rejected
by tests. `NativeSystemSymbol` is the sole exception and is limited to
macOS-owned menus, empty states, and window chrome.

Claude Code, Cursor, and Codex use official Marketplace or brand-kit tiles.
They render at 22 points in original color without a Spellbook background,
tint, crop, or effect. Provenance, versions, checksums, licenses, and trademark
notes ship beside the resources.

## Rationale

A single geometric family removes the inconsistent weights and optical sizes
created by ad-hoc SF Symbol selection. Semantic color and frame roles let the
same glyph behave predictably across light, dark, Increase Contrast, hover,
focus, pressed, and disabled states. Official product tiles preserve identity
without pretending brand artwork is a UI symbol.

The native exception avoids replacing artwork inside controls whose layout,
hit testing, accessibility, and rendering are owned by AppKit. Keeping the
allowlist centralized makes the boundary enforceable.

## Consequences

Adding an interface icon requires adding one enum case, one vendored asset,
upstream provenance, and a passing geometry/checksum test. Buttons must name a
single surface owner. Native toolbars retain native hit regions and never wrap
their icons in another Spellbook container.

The detail pane owns a fixed, plain title bar containing skill title text,
an adjacent More menu, and the Manage toggle; the generic window title is
hidden. These app-owned controls stay outside the native toolbar so macOS
cannot add an outer liquid-glass container. Dense page and sidebar chrome
uses the 10-point micro recipe inside the shared 24-point quiet-control frame.
Review Update uses a labeled native bordered button, so it does not receive the
custom quiet-button surface.
