# Spellbook Product Language

- **Install**: the unit a user actually acquired, and the unit artwork belongs to.
  An Install may hold one skill or many, and its skills need not be siblings on
  disk — Bench writes six skills as six flat folders under one recorded install.
  The Install, not the directory, is the identity.
- **Recorded Install**: an Install a manifest attests to, such as
  `~/.claude/skills/.bench-install.json`. Its membership is fact.
- **Inferred Install**: a group Spellbook proposes from install-time clustering
  where no manifest exists. It is always presented as a guess, always nameable, and
  always dismissable. An Inferred Install never overrides a Recorded one.
- **Loose Skill**: a skill belonging to no Install that Spellbook can establish.
  It is not an error and is not hidden.
- **Agent Mark**: official Claude Code, Codex, Cursor or Gemini identity artwork shown on
  an Install to say which agents can reach it. A symlinked or byte-identical copy under
  another agent root is the same Install wearing another mark, never a second Install.
- **Drift**: the state of an Install whose copies under different agent roots no longer
  match. Drift belongs to one Install; it never splits it in two.
  _Avoid_: conflict, fork, duplicate, out of sync.
- **Group Thumbnail**: the generated artwork for an Install. A skill does not get
  artwork of its own; it inherits its Install's.
- **Source**: where an Install was found, and the top-level grouping in the Survey.
  The two Sources are the current project and the device. The device Source holds
  installs for every agent on the machine, so it is never "global" to any one agent.
  _Avoid_: Global, user-level, home.
- **Composition Family**: one of the five silhouettes a Group Thumbnail can take.
  Since [ADR 0001](docs/adr/0001-parameterise-thumbnail-compositions.md) a family is
  a resemblance between tiles, not a fixed image.
- **Reader**: the view that renders one skill for reading and noting. SKILL.md comes
  first; sibling Markdown files open beside it; scripts, assets and fonts are named,
  never rendered.
- **Note**: a remark pinned to a highlighted range of a skill's Markdown, or to the
  skill as a whole. Notes accumulate in the Reader until they are sent.
  _Avoid_: comment, annotation, highlight, feedback.
- **Brief**: the batch of Notes delivered to the agent in one send, naming the file,
  the quoted lines and the request. The agent is the only writer; the Brief is how the
  browser asks for a change.
  _Avoid_: payload, message, prompt.
- **Register**: the voice of the contents page, chosen in Settings: Prose (the Grimoire
  look) or Mono (the Folio look). One book, one Reader, two Registers.
  _Avoid_: theme, mode, skin, edition, look.
- **Settings**: the last spread of the book, reached by turning past the final skill or
  from the footer. Holds Appearance, Register, Reader, Connection, Roots and Groups.
  _Avoid_: preferences, options, colophon, settings page.
- **Survey**: the view `/spellbook` opens on, showing every Install at once. Its job
  is recall and selection, not maintenance.

Use these terms in UI specifications, tests, accessibility identifiers, and design
discussions.
