# Cyberpunk Tactics — working notes for Claude

Turn-based tactical game on Cyberpunk RED rules, XCOM-style crew/gig loop. Godot 4.7.2, GDScript.
Design source of truth: `docs/design-spec.md`. Milestones and status: `docs/roadmap.md`.

## Setup & tests
- `tools/install_godot.sh` — installs pinned Godot to /opt/godot (cloud containers start without it).
- `tools/test.sh [filter]` — headless unit tests. Must pass before every commit.
- Tests live in `tests/unit/**/test_*.gd`, extend `TestCase`, methods named `test_*`.
- `tools/soak.sh [--campaigns=30 --gigs=6 --rounds=12 --plan=board,setpiece]` — integration soak of the whole
  gig loop (SoakDriver: board offers, forced gigs at every set piece; AI both sides; resolve/save/reload;
  invariants, determinism). ~10 s a gig: run it in the background after gig-loop changes.
  `tests/unit/test_soak.gd` is its small pass. Campaign gigs are built by `GigSetup.for_campaign` (greybox and soak share it).
- Gotcha: a parse error in any script a `-s` main script depends on makes Godot hang in the debugger instead of exiting. Always wrap ad-hoc `godot -s` runs in `timeout`, and run code through `tools/test.sh` first to surface parse errors.
- No GPU in the cloud container: verify logic with tests, not screenshots. Visual work is reviewed by the user locally.

## Layout
- `src/core/` — pure rules: Dice, Check (exact probabilities), Combatant, Attack (preview + resolve), TurnState, Initiative, Cover. `RefCounted` only, no Nodes.
- `src/meta/` — between-gig systems (Recruit generator, later base/economy).
- `src/data/` — `Resource` definitions (characters, weapons, cyberware, roles).
- `data/rules/` — rules content JSON. skills/cyberware/roles are GENERATED: edit `docs/rules/*.md` or `tools/gen_rules_data.py`, then run `python3 tools/gen_rules_data.py`. weapons/armor/critical_injuries/gear are hand-edited
  (each entry cited; `docs/rules/gear.md` is the equipment reference; an item is sold only when its data has
  `shop_rep`, no `unmodelled` and only implemented `fx`, enforced by tests/unit/core/test_gear_data.gd).
- `docs/rules/` — page-cited rules reference distilled from the core book. Read these instead of the PDF.
- `docs/world/` → `data/world/` — Night City as data: factions, security doctrines, locations. GENERATED: edit the
  `world <file>.<path>` JSON blocks in `docs/world/*.md` (page-cited paraphrase beside each), then
  `python3 tools/gen_world_data.py`; `tools/test.sh` fails if they drift. Read by `src/world/` (World, Security).
- `data/gen/objectives.json` + `src/tactical/objectives/` — one module per gig objective (Objective interface);
  `data/gen/themes.json` — per-scene looks and palettes (SceneTheme). Rules code asks sides/relations
  (`Encounter.hostile/allied/is_guard/opfor`), never compares team numbers.
- `src/gen/`: SceneGen (scene planners, outdoor yards/fences/props) and DistrictGen (city neighbourhoods from profiles) → BuildingGen (one building plot, any Footprint shape) → Layouts/Furnish; data in `data/gen/` (scenes, districts, sites, rooms). `src/gen/` maps, `src/net/` net architectures, `src/tactical/` grid/turns/scenes, `src/ui/`, `src/meta/` base/economy.
- Keep rules code independent of presentation so it stays testable headless.

## Conventions
- Static typing everywhere. Tabs for indentation (Godot default).
- All randomness through a seeded `Dice` instance passed in — never global `randi()` in rules code.
- Rules values: cite the source next to the value (`# CPR core p.XXX` or `# Demiplane: <page>`).
  Anything not yet checked against the rulebook is tagged `# RULES-UNVERIFIED`; grep for it before milestone sign-off.
- Never cite source-book pages in player-facing text (hover cards, HUD, screens, log lines, toasts): cites live in code comments and data cite/_doc fields only (owner).
- Deliberate departures from rules-as-written are tagged `# HOUSE-RULE:` with a one-line reason.
- Rules reference: Demiplane Nexus (free official) or the user's own PDF on request. Don't paste rulebook text into the repo; store numbers and short paraphrases only.

## Workflow
- Review artifacts (🔶 check-ins) must let the user record and save verdicts on the page (load the `artifact-capabilities` skill for persistence), and offer alternatives with a recommendation.
- One milestone per session where possible; commit at green-test checkpoints.
- Stop for the user only at the check-ins in `docs/roadmap.md` or on genuine design/aesthetic questions.
  Routine implementation choices: decide, then note them in the commit message.

## Greybox (M3b)
- `scenes/greybox.tscn` (main scene) → `src/tactical/greybox.gd` builds a 3D blockout from a generated TacMap and drives `Encounter`.
- Screenshot it headless with software GL: `timeout 180 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-method gl_compatibility --resolution 1280x720 --path . -- --shot=out.png [--scene=x|--profile=y] [--seed=n]`.
- Dev mode (`--dev`, or click the title screen's Options heading 5 times): JOBS gets a CUSTOM GIG (DEV) card
  (`src/ui/screens/custom_gig_card.gd`) that sets every gig parameter; `CustomGig` (src/meta/) turns its form or the
  same greybox-style flags (`CustomGig.from_flags`) into a campaign gig (`Campaign.accept_custom`, marked `dev`).
  Shot of it: `godot --path . scenes/base.tscn -- --demo --screen=jobs --dev --focus=custom [--setpiece=x ...] --shot=out.png`.
