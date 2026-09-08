# Origin and one voice verification

Owner selected treatment A (inline metadata) on 2026-09-08. Areas 1–6 are implemented.
No commit made. The original plan's corpus table is a historical expectation, not a fixture to fabricate.

## Checks

- `npm run typecheck`, `npm run build`: passed. Vite retains existing runtime design-asset and
  large chunk notices.
- `node --test server/scan.test.mjs`: passed isolated Origin, stale lock, evidence, D13 and Drift fixtures.
- `node server/server.test.mjs`: passed health counts, fallback port, stable restart, missing root
  discovery, delayed SKILL.md creation, SSE, Brief delivery/reload and accelerated idle exit.
- `npm run scan -- --compact`: passed; actual table below. No time-based grouping remains.
- Spellbook: 40417; pointee: 43083, both stable across stop/start. Both titles include the project.
  pointee names `~/Code/pointee/.claude/skills/` when empty.
- `start` with a connected tab returned its existing URL, without opening another tab.
- `status --all` and `stop --all`: passed against a temporary inventory of these two servers.
  The unrelated pre-existing obsidian-skills server was left running.
- An initial restart attempt exceeded the old nine-second launcher allowance during repository
  matching. The allowance is now 45 seconds; both restart checks then passed.
- Light appearance and Wide Reader persisted across the stable-port restart. Original System
  appearance and Focused width were restored after testing.
- Created the plan's temporary pointee demo while connected. It appeared without Rescan. Sent
  test Brief `817c2d2a`, received it through `wait-brief`, applied its exact replacement, and saw
  updated text plus the sent Note's history in the Reader. Removed demo/SKILL.md and its folder;
  the project returned to its empty chapter.
- Exact `--idle 1`: passed; server exited at least 59 seconds after SSE disconnect and within
  the 65-second test deadline.
- Browser DOM checks: no Commit Mono outside rendered code/Brief preview in the sampled Reader
  and Settings. Records and Keys contain no Register, Groups or mono tags.
- Keyboard checks: file-tab Right selected Files and moved focus there without changing page 1;
  Enter activates Note on skill; Escape while editing a kept Draft restores its saved text.
- Impeccable independent assessment: 28/40 versus 26/40 baseline. Two identified interaction bugs
  were repaired and browser-verified after assessment; no post-fix score was invented.

## Current corpus

| Source | Install or Loose Skill | Skills | Origin grade and kind | Origin |
| --- | --- | ---: | --- | --- |
| project | spellbook | 1 | matched local | Jingquank/Spellbook |
| device | aside-browser | 1 | hinted app | Aside |
| device | Bench | 6 | recorded pack | Jingquank/Bench |
| device | Codex system skills | 6 | recorded github | openai/skills |
| device | emilkowalski/skills | 7 | recorded github | emilkowalski/skills |
| device | frontend-design | 1 | recorded plugin | anthropics/claude-plugins-official |
| device | hatch-pet | 1 | unknown unknown | unknown |
| device | impeccable | 1 | unknown unknown | unknown |
| device | interface-craft | 1 | unknown unknown | unknown |
| device | ip-as-logo | 1 | recorded github | s1dashu/ip-as-logo-skill |
| device | Mastermind | 2 | matched local | Jingquank/Mastermind |
| device | mattpocock/skills | 6 | recorded github | mattpocock/skills |
| device | notion | 4 | recorded plugin | anthropics/claude-plugins-official |
| device | show-me | 1 | recorded github | humanlayer/skills |
| device | spellbook | 1 | matched local | Jingquank/Spellbook |

Differences from the 2026-09-07 handoff: prototype is absent (emilkowalski has seven); device
roots also contain Spellbook; impeccable and interface-craft no longer contain the specified
GitHub links in their SKILL.md/README copies, so they remain Unknown Loose Skills. Bench and
Mastermind also have Drift on the current corpus. Single-skill Install names follow D11's skill
name rule (spellbook), while their Origin retains the repository name (Spellbook).

## Visual limits and remaining critique issues

The in-app browser exposed roughly 387×218–436×303 CSS pixels even after a requested desktop
viewport override. Chrome was unavailable. Native screenshots, accessibility trees, interaction
checks and computed styles were inspected, but ordinary desktop composition, responsive layout
and contrast are not certified by this run. Narrow-window clipping was observed.

The one detector pass returned an Unfurl padding-transition warning and a graph-paper background
advisory, both matching explicit existing DESIGN.md choices. No measured jank was claimed.
Mutable browser injection was unavailable, so no live detector overlay was presented.

Future Note work: keyboard range selection and Draft refresh recovery. Neither adds curation.
