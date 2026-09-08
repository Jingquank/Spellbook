# 4. Installs are grouped by Origin evidence, and the tab offers no curation

Date: 2026-09-07

## Status

Accepted. Amends one consequence of [ADR 0002](0002-browser-tab-reads-agent-writes.md).

## Context

The first tab grouped device skills that no manifest covered by install day ("Installed together,
6 Sep"), presented the result as a guess, and let the user name or dismiss it in the browser. On the
real corpus the good groups were never "same day": they were "same origin". The Agent Skills CLI
lockfile at `~/.agents/.skill-lock.json` records the GitHub repository of sixteen skills and
explains three of the five guessed groups exactly, while the two skills that arrived on 6 September
came from two different repositories. Where no installer left a record, the skill's own text can
still be found verbatim in a local repository (Bench's six skills in `~/Code/Bench`, master and
mastermind in `~/Code/Mastermind`), which is a stronger fact than a shared minute.

The owner also settled Spellbook's scope: it is a visualizer. The user reads, notes and sends
Briefs; the agent changes files. Hand-curating the library in the tab (renaming groups, dismissing
them, declaring provenance) is not wanted, and any such state would have needed a home on disk
that the next version's updater could read.

## Decision

An Install is the set of skills that share one Origin. Origins carry an evidence grade:

- **Recorded**: an installer wrote it down (the Agent Skills CLI lockfile, a plugin marketplace
  record, a pack manifest, Codex's system root). Forms an Install.
- **Matched**: two independent facts agree, such as the skill's description found verbatim in a
  local git working copy together with that repository's remote, or a symlink into such a copy.
  Forms an Install and always states what it matched.
- **Hinted**: one content signal (a URL, a version). Shown as "probably …" on a Loose Skill.
  Never groups.
- **Unknown**: shown as unknown.

Install time is never a grouping key. The tab has no controls to name, dismiss or regroup, and keeps
no curation state anywhere. Names follow the Origin: `owner/repo` for GitHub sources, the folder
name for local repositories, the plugin name for plugins, the skill name for a single-skill
Install.

## Considered options

- Keep time clustering with a minutes window instead of a day. Rejected: it would still have
  needed a correction affordance, and the lockfile already names the groups better.
- Group on any signal, including hints. Rejected: one wrong URL in a README would merge unrelated
  skills with no way to undo it in the tab.
- Keep user declarations, stored in a Spellbook-owned file or in the browser. Rejected by scope:
  a visualizer shows what it can establish.

## Consequences

- Every Install id changes once (ids derive from the Origin key), so existing browser state
  keyed by the old ids is abandoned. There is none worth migrating; the only persisted state that
  remains is appearance, reader width and text size.
- ADR 0002's consequence "layout state the tab owns (Canvas positions, Inferred Install names,
  dismissals) lives in browser storage" no longer applies. The tab persists preferences only.
- Text matching reads local repositories at scan time. It must skip copies that sit inside other
  projects' skill roots, or a project-level copy of a skill masquerades as its source.
- The Origin model is the seam for a later "update from Origin" action: each kind knows what
  fetching means (the skills CLI, the plugin updater, the pack installer, `git pull`).
