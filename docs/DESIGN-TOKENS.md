# Spellbook Design Tokens

`SpellbookDesign` is the only source for app-owned visual constants. Its three layers are primitives, semantic roles, and component recipes. `SpellbookMotion` remains independent and is excluded from token enforcement.

## Primitives

| Family | Values |
| --- | --- |
| Space | 2, 4, 6, 8, 12, 16, 20, 24, 32, 48 pt |
| Radius | 4, 6, 8, 10, 12 pt, plus capsule at the call site |
| Stroke | 0.5 and 1 pt |
| Interface icon | 10, 12, 14, 16, 20 pt |
| Agent mark | 22 pt |
| Other artwork | 18, 20, 42 pt |
| Icon-button frame | 24, 28, 32 pt |

Intentional component dimensions such as 31, 39, 44, 52, 240, 260, 300, 760, and 980 are recipes, not general spacing values.

## Typography roles

All app-owned text uses Schibsted Grotesk unless the role is code-like. Commit Mono programming ligatures are disabled in AppKit editors and should not be re-enabled in attributed content.

| Role | Family | Base size | Weight |
| --- | --- | ---: | --- |
| Micro | Schibsted Grotesk | 11 | Regular |
| Metadata | Schibsted Grotesk | 12 | Regular |
| Control | Schibsted Grotesk | 14 | Regular |
| Row label | Schibsted Grotesk | 14 | Regular |
| Body | Schibsted Grotesk | 14 | Regular |
| Reader body | Schibsted Grotesk | 15 | Regular |
| Section title | Schibsted Grotesk | 15 | Semibold |
| Sheet title | Schibsted Grotesk | 22 | Bold |
| Detail title | Schibsted Grotesk | 24 | Bold |
| Code metadata | Commit Mono | 12 | Regular |
| Code body | Commit Mono | 13 | Regular |

Roles use `Font.custom(_:size:relativeTo:)`. Small, Default, and Large interface scaling and all four reader scales remain functional.

## Palette roles

The code palette provides separate light, dark, Increase Contrast light, and Increase Contrast dark values. Hex values below are sRGB seeds in that order.

| Role | Light | Dark | High light | High dark | Meaning |
| --- | --- | --- | --- | --- | --- |
| Canvas | FBFAF8 | 222326 | FFFEFC | 191A1D | Reader and window content |
| Sidebar | F4F3F1 | 292A2E | EFEEEB | 242529 | Navigation background |
| Raised | FEFDFB | 313238 | FFFFFF | 37383E | Elevated native surface |
| Grouped | F0EFEC | 2B2C30 | EAE9E5 | 313238 | Inset grouped controls |
| Hover | EDECE9 | 34353A | E5E4E0 | 3D3E44 | Pointer affordance |
| Selection | E4E3DF | 3C3D43 | D8D7D2 | 484A51 | Neutral selected surface |
| Primary text | 242529 | E9E8E5 | 17181B | F7F6F2 | Main content |
| Secondary text | 686A70 | B7B6B2 | 54565B | CDCCC8 | Supporting content |
| Tertiary text | 717378 | 8F908E | 64666B | A7A8A5 | Quiet metadata |
| Separator | DAD9D5 | 47484D | C7C6C1 | 5B5C62 | Boundaries |
| Disabled | A5A6A4 | 747579 | 8D8E8C | 8A8B90 | Unavailable content |
| Interaction, Focus, Link, Update | 5C5E63 | BBBDB9 | 44464B | D4D4CF | Warm graphite affordance |
| Success | 2F7651 | 69B88B | 236440 | 82CCA2 | Positive state |
| Warning | 9A5A12 | E2A052 | 814704 | F2B66D | Caution |
| Error | AB4138 | E17A72 | 922E28 | F0948D | Failure or conflict |
| Diff added | EAF4EE | 26352D | DCEEE3 | 2D4437 | Added content surface |
| Diff removed | F7ECEA | 382A2B | F1DEDA | 4A3031 | Removed content surface |

Primary actions use a neutral primary-text fill with canvas-colored content. Skill artwork and official agent identity keep their original colors.

## Component recipes

- Sidebar: 240/260/300 pt min/ideal/max width; 31/39 pt compact/comfortable rows; 18 pt artwork; 6 pt horizontal inset; 4 pt vertical inset; 6 pt row radius.
- Icons: `SpellbookIconSize` is 10/12/14/16/20 pt; `SpellbookIconUsage` maps dense chrome/standard controls/content/emphasis to those sizes; official agent marks are 22 pt; `SpellbookIconButtonFrame` is 24/28/32 pt. Regular Iconoir SVGs use a 2 pt stroke on the unchanged 24×24 view box.
- Icon color roles: Primary → `textPrimary`; Secondary → `textSecondary`; Interactive → `interaction`; Disabled → `disabled`; status roles → `success`, `warning`, `error`, and `update`.
- Quiet icon button or menu: transparent idle surface, visible glyph, one 6 pt-radius neutral hover/focus/pressed surface, tooltip, and accessibility label. A native toolbar or bordered button is already the surface owner and receives no nested quiet surface.
- Detail reader: 30/36 pt compact/comfortable inset; 22/28 pt section rhythm; 760/980 pt Focused/Wide measure; 42 pt artwork.
- Fixed detail title bar: 40 pt high, plain canvas content with no material or rounded group surface. It contains the `Skill` title, adjacent 10 pt More glyph, and a trailing 10 pt Manage disclosure; both controls use the reusable 24 pt quiet-control frame and semantic interaction color. The generic window title is hidden.
- Review Update: Iconoir `download-circle` at 14 pt inside one small native bordered button, first-baseline aligned with the large title; vertical `ViewThatFits` fallback.
- Management inspector: 280/340/420 pt min/ideal/max width and independent scrolling.
- Settings: 44/52 pt compact/comfortable rows.
- Installation rows: 38 pt divider indent and 11 pt horizontal inset.
- Evidence: 76 pt label column and 52 pt confidence column.
- Sheets: 20 pt content padding; 12 pt section padding; 54 pt divider indent; 420/460/500/520/560/620/780 pt named widths; 280/300/320/360/420/440/460/520/560/600 pt named heights; 480 pt update minimum width; and 260 pt update-content minimum height.
- Reader auxiliaries: 18 pt list marker; 120 pt minimum table column; 520 pt maximum image height; 34 pt code header; 150/190/220 pt diff min/ideal/max height.

## Usage

```swift
Text(skill.name)
    .font(SpellbookDesign.Typography.rowLabel)
    .foregroundStyle(SpellbookDesign.Palette.textPrimary)
    .padding(.horizontal, SpellbookDesign.Sidebar.horizontalInset)
```

Prefer semantic and component roles over primitives. Use a primitive directly only when the value describes general rhythm rather than a component contract.

## Exceptions

Raw values are allowed only for documented content-derived artwork geometry, renderer math, behavior constants, and native API parameters that are not visual design. Motion values belong in `SpellbookMotion`. Add any new exception to the guard allowlist with a reason; never silence a file merely for convenience.

SF Symbols are a separate, narrow exception. `NativeSystemSymbol` is the only allowlist and may be used only where macOS owns presentation: native menus, empty states, and window chrome. Brand tiles and skill/package thumbnails are identity artwork and are not governed by interface-icon tint or stroke tokens.
