# Spellbook

A design language and a generative artwork system, waiting for their next interface.

The macOS SwiftUI application that used to live here has been removed. Spellbook's next form is a
temporary interface that runs in the browser, opened by the agent from a skill and shaped by
whatever codebase it is looking at. That interface is not designed yet.

What survived the reset:

| Path | What it is |
| --- | --- |
| `design/index.html` | The documentation and live reference. Open it. |
| `design/tokens.css` | Every design constant as a CSS custom property, in four palettes. |
| `design/thumbnails.js` | The generative skill thumbnail renderer, dependency-free. |
| `design/fonts/` | Schibsted Grotesk and Commit Mono, with OFL licenses. |
| `design/icons/` | 46 Iconoir glyphs, 4 agent marks, and provenance records. |

## Reading it

```sh
python3 -m http.server -d design 8000   # then open http://localhost:8000
```

Opening `design/index.html` directly works too, but some browsers refuse to load fonts over
`file://` and the page falls back to a system sans. Serving it shows the real typefaces.

## The thumbnail generator

`thumbnails.js` is a port of the Swift renderer, not a reimplementation. Both hashes accumulate in
64-bit unsigned arithmetic and wrap identically, so a given package and skill id produce the same
one of 35 images they always did.

```js
const spec = SpellbookThumbnails.thumbnailFor({
  packageId: "anthropics/skills",
  skillId: "anthropics/skills/pdf"
});
SpellbookThumbnails.render(canvas, spec, 42);
```

## History

The SwiftUI app, its plans, audits, and prototype captures are in git history at `2576040` and
earlier. Nothing was lost, only set down.
