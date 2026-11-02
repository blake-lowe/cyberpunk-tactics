# Roadmap

Check-ins (🔶) are where work pauses for a user decision or review.

| # | Milestone | Status | Check-in |
|---|---|---|---|
| M0 | Skeleton: project, test runner, conventions | ✅ done | — |
| M1 | Rules core (headless): checks, skills, initiative, weapons/ROF/autofire, SP + ablation, aimed shots, damage, Critical Injuries, death saves, Humanity, cyberware, Solo Combat Awareness, recruits | ✅ done (reviewed) | ✅ |
| M2 | Procedural generation: multi-floor maps, cover, hackables, coupled Net Architectures (+ Netrunner Interface rules); debug renders | ✅ done (reviewed through M2f) | ✅ |
| M3a | Tactical core, headless: grid pathfinding (stairs, ladders, bridges), line of sight and binary cover (walls, windows, cover pieces), destructible cover, encounter setup (crew at deploy, guards at posts), enemy AI, Netrunner session (jack in within 6 m, NET actions per turn, Black ICE fights), win/lose | ✅ done (headless) | — |
| M3b | ✅ built, awaiting playtest — Playable greybox in Godot: 3D blockout from TacMap with floor slicing, camera, move grid shown only while planning, hit % and DODGE callouts, initiative bar, unit panel, NET overlay | — | 🔶 user plays locally |
| M4 | Visual pass: pixel post-process, neon lighting/bloom, VFX, tuning controls | — | 🔶 aesthetic review on user's GPU |
| M5+ | Gigs/fixers, base & downtime, progression, Medtech, Tech, reinforcements, cyberpsychosis | — | per feature |

## Decisions log
- Godot 4.7.2, GDScript, Forward+ renderer.
- Custom minimal test runner instead of an addon (no external dependency, fast headless).
- Rules data is generated from `docs/rules/*.md` by `tools/gen_rules_data.py` (skills, cyberware, roles); weapons/armor/crits are hand-written JSON verified against printed pages.
- Ranged defenders with REF 8+ dodge automatically whenever dodging lowers the hit chance (no prompt, keeps turns fast).
- At most one Critical Injury per attack, even if both the double-6 and Mortally Wounded triggers apply.
- Solo Damage Deflection reduces HP damage after armor and the head multiplier.
- HOUSE-RULE: unconscious melee targets get no Evasion; recruit loadouts are pared down from the book's gear lists.
- HOUSE-RULE cyberpsychosis episodes (approved): at EMP ≤ 2, check at the start of each combat turn: 5% at EMP 2, 15% at EMP 1, 30% at EMP 0. Episode = AI control for 1-2 turns, attacking the nearest target (friend or foe). Humanity < 0 = permanent AI control.
- Auto-dodge must be legible: the UI shows a "DODGE" callout/animation on the defender whenever the dodge choice is taken (attack result carries `dodged`). → M3.
- Backlog (scoped, not scheduled): full per-Role starting gear lists (p98-103) replacing the pared-down Recruit.LOADOUT; needs the inventory/gear system (M5+).
- Deferred within the rules core: Martial Arts special moves, grapple/choke/throw, weapon quality/attachments/special ammo, vehicles, Medtech/Tech Role Abilities (roadmap priority 2-3), non-core Roles.
- M2 review page: `tools/map_viewer/` (build.py + template.html) turns an `export_maps.gd` dump into a comparison page. Reuse it for future generator reviews.
- HOUSE-RULE (pending review): guaranteed minimum Black ICE per zone (NetGen.MIN_ICE), because map content usually fills the 3d6 floor budget.
- Principle (user): the NET is not bound by the tabletop architecture rules. Keep the book's node types, DVs, Interface abilities and Black ICE stats for familiarity, but structure (floor order, 3d6 size, d10 branching, lobby table) is ours to redesign for video-game play. Current tree generator is a baseline, pending the Subnets/Graph decision.

### M2 review verdicts (user)
- Layouts: hybrid by site type — treemap for corporate, growth for clubs/squats/gang hideouts, BSP for warehouses/industrial.
- NET structure: a graph. Low security = simple subnets (zone clusters joined by firewalls); high security = complex graph (more subnets, loops, multiple routes, patrolling ICE). One generator, complexity scales with security.
- Physical access may skip some layers, but not 1:1: entry points are probabilistic, and some nodes/data are net-only (no physical shortcut reaches them).
- Black ICE from a per-site budget (security × gig threat) instead of the book's floor tables. Replaces the MIN_ICE stopgap.
- Cover: lighter by default, density varies by area/room type.
- Process: review artifacts must let the user record and save verdicts on the page itself.
- M2b review page: same URL as M2 (https://claude.ai/artifact/USi3z8E9Nzg5U8D4oiJpo3). Verdicts save to the page's db collection `verdicts` (one doc per decision key: choice, note, updated) — read them with ArtifactData list before acting on the review.

### M2b review verdicts (user)
- Cover density right (walls count as cover → M3: walls get HP by material, fences see-through).
- ICE budget right; tune later. NET complexity right; intro gigs even simpler → net_scale "intro".
- Jack-in: deterministic — each access point wired to one specific node → per-terminal port nodes.
- Site layouts: buildings fine, but need outdoor areas, multiple buildings, purpose-built scenes, larger maps → SceneGen (street block, megablock, shipyard, badlands, rail yard, corp campus).

### M2c review verdicts (user)
- Scene types approved; keep adding over time. Add verticality → roofs (hatch/ladder access), skybridges, footbridges over roads and rail.
- Scene size right for gigs; bigger city as a tech demo → city_district (4x3 blocks).
- NETs: mostly separate, sometimes linked; ~1.5-1.75x too complex → trimmed ~1.6x, related-structure links 30-50%.
- Ports approved; too busy in the viewer → hidden by default with per-hub counts.
- Walls/doors use the book's cover values (p182-183); fences stop movement, not bullets.

### M2d review verdicts (user)
- Verticality approved.
- NETs still big: not everything needs all security levels → per-site `levels`; rename levels L1, L2, L3… (display); not every building needs a NET → per-site `net_chance`; NETs should be impactful, not volume.
- Linked NETs as "sockets": a node pointing into the other NET; taking it moves the runner there.
- City district size fine but too grid-like → diagonal avenues, cut corners. Too much cover in roads → curb parking only; barriers rarer. Cars are rare in the Time of the Red.
- Asked what's missing → added windows, deployment zone, guard posts, explosive barrels; proposed lighting/stealth, civilians, sewers, vehicles, hazards, weather for prioritisation.
- One more generation pass before M3 (this M2e).

### M2e review verdicts (user)
- NETs right in size, but too many devices per hub → content in branches of ≤3 behind junction rings (graphs, readable).
- Sockets: make them bidirectional; hard to find → paired sockets, links more frequent.
- Break grids more, everywhere; think wider about Night City establishments; aim for parameters per neighbourhood → DistrictGen + 8 profiles (data/gen/districts.json), 13 new establishments + outdoor uses, footprint shapes, decay.
- Windows/deploy/posts/barrels approved. One more pass before M3 (this M2f).

### M2f review verdicts (user)
- NET branching: branch *down* a level (Y), not sideways within a level (T) → junction rings removed; a level with >4 items splits into small subnets, each behind its own firewall from a subnet one level up; L1 stays a single trunk; no same-level hub links.
- Sockets: only between nodes of the same level (no bypassing) → enforced.
- Profiles, establishments approved; shapes right; decay varies by neighbourhood (profile ranges).
- Start M3. (Missing-elements ranking still open: lighting/stealth, civilians, sewers, vehicles, hazards, weather.)
- M3a decisions: guards carry keys to their own security doors (the crew must hack or shoot them); doors stay open once walked through; rank-and-file guards skip cyberpsychosis episodes; AI steers by walking distance (bucket-queue Dijkstra), ~200 ms per turn on the cloud CPU.
- M3 playtest page: https://claude.ai/artifact/TYxEY3nRMqu1doZGhq8wQt (verdicts in its db collection `verdicts`, keys m3_*).
