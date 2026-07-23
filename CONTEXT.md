# Spellbook Product Language

- **Library View**: the combined navigation preference that controls organization, sorting, and group placement in the library sidebar.
- **Organize By**: whether the Library is grouped primarily by Skill or Agent.
- **Sort By**: the existing ordering mode applied inside the chosen Library View.
- **Placement**: where package or agent groups appear relative to ungrouped skills. The current option is Groups First.
- **Inspection Surface**: the trailing, independently scrolling management area for installations, source state, updates, conflicts, and evidence. It supports the reader; it does not replace it.
- **Evidence Group**: deduplicated provenance observations sharing a normalized source URL, summarized by confidence, evidence kinds, installation support, and recency.
- **Interface Icon**: a semantic, template-rendered Iconoir glyph represented by `SpellbookIcon`; it inherits a role rather than an ad-hoc color.
- **Agent Mark**: official Claude Code, Cursor, or Codex identity artwork rendered at 22 pt in original color. It is not an Interface Icon.
- **Icon Button**: an icon-only action with a tooltip, accessibility label, tokenized glyph/frame size, and exactly one visual surface owner.
- **Surface Owner**: the single layer responsible for a control’s idle, hover, focus, and pressed container. A native toolbar or bordered control owns its surface; a custom quiet button supplies its own.
- **Title Action Cluster**: the fixed in-page pairing of the selected skill name and its adjacent More menu. It is plain content, never a liquid-glass toolbar control, and does not transform on hover.

Use these terms in UI specifications, tests, accessibility identifiers, and design discussions.
