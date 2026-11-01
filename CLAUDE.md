# Cyberpunk Tactics — working notes for Claude

Turn-based tactical game on Cyberpunk RED rules, XCOM-style crew/gig loop. Godot 4.7.2, GDScript.
Design source of truth: `docs/design-spec.md`. Milestones and status: `docs/roadmap.md`.

## Setup & tests
- `tools/install_godot.sh` — installs pinned Godot to /opt/godot (cloud containers start without it).
- `tools/test.sh [filter]` — headless unit tests. Must pass before every commit.
- Tests live in `tests/unit/**/test_*.gd`, extend `TestCase`, methods named `test_*`.
- Gotcha: a parse error in any script a `-s` main script depends on makes Godot hang in the debugger instead of exiting. Always wrap ad-hoc `godot -s` runs in `timeout`, and run code through `tools/test.sh` first to surface parse errors.
- No GPU in the cloud container: verify logic with tests, not screenshots. Visual work is reviewed by the user locally.

## Layout
- `src/core/` — pure rules: Dice, Check (exact probabilities), Combatant, Attack (preview + resolve), TurnState, Initiative, Cover. `RefCounted` only, no Nodes.
- `src/meta/` — between-gig systems (Recruit generator, later base/economy).
- `src/data/` — `Resource` definitions (characters, weapons, cyberware, roles).
- `data/rules/` — rules content JSON. skills/cyberware/roles are GENERATED: edit `docs/rules/*.md` or `tools/gen_rules_data.py`, then run `python3 tools/gen_rules_data.py`. weapons/armor/critical_injuries are hand-edited.
- `docs/rules/` — page-cited rules reference distilled from the core book. Read these instead of the PDF.
- `src/gen/`: SceneGen (scene planners, outdoor yards/fences/props) and DistrictGen (city neighbourhoods from profiles) → BuildingGen (one building plot, any Footprint shape) → Layouts/Furnish; data in `data/gen/` (scenes, districts, sites, rooms). `src/gen/` maps, `src/net/` net architectures, `src/tactical/` grid/turns/scenes, `src/ui/`, `src/meta/` base/economy.
- Keep rules code independent of presentation so it stays testable headless.

## Conventions
- Static typing everywhere. Tabs for indentation (Godot default).
- All randomness through a seeded `Dice` instance passed in — never global `randi()` in rules code.
- Rules values: cite the source next to the value (`# CPR core p.XXX` or `# Demiplane: <page>`).
  Anything not yet checked against the rulebook is tagged `# RULES-UNVERIFIED`; grep for it before milestone sign-off.
- Deliberate departures from rules-as-written are tagged `# HOUSE-RULE:` with a one-line reason.
- Rules reference: Demiplane Nexus (free official) or the user's own PDF on request. Don't paste rulebook text into the repo; store numbers and short paraphrases only.

## Workflow
- Review artifacts (🔶 check-ins) must let the user record and save verdicts on the page (load the `artifact-capabilities` skill for persistence), and offer alternatives with a recommendation.
- One milestone per session where possible; commit at green-test checkpoints.
- Stop for the user only at the check-ins in `docs/roadmap.md` or on genuine design/aesthetic questions.
  Routine implementation choices: decide, then note them in the commit message.
