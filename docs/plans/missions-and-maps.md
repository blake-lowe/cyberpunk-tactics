# Missions and maps: how the procedural systems hold up, and what's needed

Status: plan for owner review (2026-11-03). Nothing here is built yet.

## How this was tested

`tools/procgen_survey.gd` runs every scene type through `SceneGen.generate` + `Encounter.setup` for
every objective (data, eliminate, snatch) at security 1–3 over 4 seeds: **468 gigs**, 13 scene types
(the 8 fixed scenes, 4 neighbourhood profiles, the city-district demo). For each it measures whether the
gig is *playable*, not just whether it generates: a target building exists, the guard budget is placed,
the crew can walk from deploy to the target without breaching a door, a NET access point can be reached
on foot (within jack range, no wall), the target File exists and is routable in the NET, the snatch
package is inside the target and walk-reachable, there's an entrance for backup, how many guards sit
behind locked doors, and generation time. Plus screenshots of the snatch objective on scenes it was never
meant for (badlands, rail yard, shipyard, combat zone).

## What holds up

| | result |
|---|---|
| Target building, guards placed to budget, deploy → target walkable, backup entrance | 468 / 468 |
| Data objective has a File with a NET route (max firewall DV 12) | 156 / 156 |
| Snatch package inside the target and walk-reachable | 156 / 156 |
| Generation time | 0.1–2 s per scene; city district 6 s |

The objectives are not actually scene-specific: snatch and eliminate work on every map type, and data
works wherever there's a NET. The gig list only uses each objective on 3–4 hand-picked scenes.

## What breaks or is thin

1. **Terminals you can't reach (data gigs).** Shipyard 0/12, badlands 8/12, combat zone 9/12,
   Pacifica 9/12, corp campus 10/12, lone building 11/12. Every failure is a site with **one** access
   point, inside a room behind locked security doors (the ship's bridge, the raider camp's shack). The
   only ways in today are the NET itself (which needs that terminal) or shooting the door down.
2. **Locked doors have one answer.** Guards sit behind locked doors in most gigs (avg 1–3.4 of ~3.7;
   shipyard and rail yard almost all of them). There's no lock-picking or bypass (CPR: Electronics/
   Security Tech), no keycards, no Tech or Solo way through other than gunfire.
3. **Opposition doesn't scale with the map.** ~3.7 guards on a 30×24 skirmish and on a 220×170 city
   district. Big maps are empty walks; guards all cluster in the target building.
4. **Objectives aren't visible enough on big maps.** The snatch beacon is hard to spot at overview zoom
   (screenshots); there's no objective marker at the screen edge when it's off-camera.
5. **Mission variety is three kinds.** The spec wants "a core set of designed gig templates, heavily
   parameterised (locations, targets, opposition, twists)", civilians, and NCPD / Trauma Team / MaxTac
   reinforcements. We have data / eliminate / snatch, no civilians, and NCPD reuses Mook stats.
6. **Interior-only sites have no scene.** 25 site types exist (club, clinic, data center, NCPD precinct,
   temple, villa, chop shop, BD parlour, capsule hotel...) but only reach play inside multi-building
   scenes, never as the gig's own location.

## Plan

Sizes: S = under a day, M = 1–3 days, L = a week-ish. Each step keeps the survey green (it becomes a
test: no gig may be unplayable).

### P0: make every generated gig playable (S–M)

- **Guarantee a reachable way in to the NET** (S): every NET with a single access point behind a locked
  door gets a second, public one (a maintenance junction box on an outside wall or in the public zone),
  so data gigs never require breaching first. Survey target: aps_reach > 0 in 100%.
- **Bypass a lock** (S): a crew Action at a locked door: TECH + Electronics/Security Tech vs DV by
  security (13/15/17, RULES-UNVERIFIED until checked), Techs add Field Expertise. Fails loudly at -5
  (noise). HUD button when next to a locked door.
- **Keycards** (S): one guard per secure zone carries a keycard; looting them (an Action next to the
  downed guard) opens that zone's doors. Uses the existing `Prop_KeyCard` model.
- **Objective markers** (S): an edge-of-screen arrow and distance for the package / target File's
  terminal / extraction zone; a taller beacon.
- **Survey as a test** (S): run a 1-seed version of the survey in `tools/test.sh` (fast scenes only)
  asserting the invariants above.

### P1: scale and variety from what already exists (M)

- **Opposition by map size and site** (M): budget = crew × (0.5 + security) for the target building,
  plus patrol pairs per extra building / outdoor area on big maps (Mooks, unalerted, patrolling), so big
  maps aren't empty. Check with balance_autoplay.
- **Objective × scene compatibility table** (S): replace the hand-picked scene lists in gigs.json with
  rules (data needs a NET; snatch needs an interior; eliminate anywhere; new kinds below declare theirs),
  so every gig kind can appear on every fitting map and site.
- **Site raid scene** (S): a scene that wraps any single site type (`lone_building` with `site=` picked by
  the gig): club, clinic, data center, NCPD precinct, villa, chop shop... Gig templates choose sites by
  fiction ("hit the Tyger Claws' BD parlour").

### P2: new mission types (M each)

Each lists what it needs from the generator and the rules layer.

| mission | goal | needs |
|---|---|---|
| **Assassination** | Down one named target (a Lieutenant or Mini Boss) and leave | VIP placement in the most secure room with a bodyguard pair; target AI flees to the farthest exit when the alarm goes up (escape = fail); identification (a portrait in the briefing, a marker once seen) |
| **Rescue** | Get a captive out alive | holding-cell room kind (locked); a captive unit (non-combatant, follows the nearest crew member once freed, can be downed); extraction like snatch |
| **Sabotage** | Plant a charge on a device and get clear | target device kinds (server rack, transformer, generator) placed deep; "plant" Action + a 3-round fuse; explosion uses the grenade blast rules at a larger radius; leave before or after |
| **Data plant** | Upload a virus at a specific NET node | NET-only variant of data: a Virus action (CPR p200, DV10-12, several NET Actions) at a marked node; good stealth gig |
| **Hold the line** | Defend a spot for N rounds | defend position chosen from the map (a room with 1–2 entrances); wave spawner from the existing backup system with escalating tiers; good for badlands / rail yard |
| **Recon** | Tag N marked objects unseen and leave | marks on devices / vehicles; tagging is an Action within 3 squares and line of sight; leaving undetected pays a bonus |

### P3: the spec's emergent layer and new places (L)

- **Civilians** (M–L): non-combatants in public zones of clubs, markets and streets; panic and flee on
  gunfire (raising the alarm); harming them costs reputation and heat. Needs crowd placement per room kind
  and a flee AI.
- **Reinforcement tiers** (M): NCPD (current), Trauma Team (arrives to extract wounded VIPs; armoured,
  avoids fights unless shot), MaxTac (heat 7+ only; very tough). New NPC blocks (book p411-415, verify).
- **New map types** (L each): sewers / underground (single-floor maze, low light), rooftops (multi-roof
  parkour, gaps and bridges; the vertical systems exist), convoy ambush on a street (needs vehicles as
  moving cover).

## Suggested order

P0 first: it's small and it fixes real dead ends found by the survey. Then the compatibility table and
the site raid scene (cheap variety), then Assassination and Rescue (most requested types in tactics
games, and they reuse snatch/extraction). Sabotage and Data plant after; Hold the line once the
reinforcement tiers exist. Civilians and new map types last.

## Decisions for the owner

1. Lock bypass DVs and whether a failed bypass makes noise (proposed: yes, at -5).
2. Opposition scaling on big maps: add patrol pairs (proposed) or keep the budget fixed and make big
   maps rarer.
3. Which two new mission types first (proposed: Assassination, Rescue).
4. Civilians: yes/no for now (they're the spec's, but they cost AI and readability work).
