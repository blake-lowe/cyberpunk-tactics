# Roadmap

Check-ins (🔶) are where work pauses for a user decision or review.

| # | Milestone | Status | Check-in |
|---|---|---|---|
| M0 | Skeleton: project, test runner, conventions | ✅ done | — |
| M1 | Rules core (headless): checks, skills, initiative, weapons/ROF/autofire, SP + ablation, aimed shots, damage, Critical Injuries, death saves, Humanity, cyberware, Solo Combat Awareness, recruits | ✅ done (reviewed) | ✅ |
| M2 | Procedural generation: multi-floor maps, cover, hackables, coupled Net Architectures (+ Netrunner Interface rules); debug renders | ✅ done (reviewed through M2f) | ✅ |
| M3a | Tactical core, headless: grid pathfinding (stairs, ladders, bridges), line of sight and binary cover (walls, windows, cover pieces), destructible cover, encounter setup (crew at deploy, guards at posts), enemy AI, Netrunner session (jack in within 6 m, NET actions per turn, Black ICE fights), win/lose | ✅ done (headless) | — |
| M3b | ✅ playtested — Playable greybox in Godot: 3D blockout from TacMap with floor slicing, camera, move grid shown only while planning, hit % and DODGE callouts, initiative bar, unit panel, NET overlay | — | 🔶 user plays locally |
| M4 | Visual pass: pixel post-process, neon lighting/bloom, VFX, tuning controls. M4a-c: off-grid world builder, cutaway, light field, OKLab palette, stylised HUD, juice, cyberspace styles. M4d: animated characters (Quaternius bodies + Mixamo clips, retargeted), gun handling with IK, deaths, blood, debris; sunset badlands (natural terrain, per-scene light and palette) | ✅ M4d reviewed twice; badlands new | 🔶 motion review round 3 + badlands |
| M5 | Gameplay depth (owner's "c"): suppressive fire, shotgun shells, melee/brawling, grenades, stabilisation, reload in play; AI uses them; guards from the book's NPC tiers on the p399 budget | ✅ built overnight | 🔶 overnight review page |
| M6 | Gig loop, first slice: fixer board, gig → encounter → results (pay, rep, IP, injuries, permadeath), rest/treat/train/hire, saves | ✅ first slice built overnight | 🔶 overnight review page |
| M7 | Stealth phase (facing, vision cones, Perception vs Stealth with light, patrols, alarm, backup, NCPD escalation, withdrawal); Medtech Medicine and Tech Maker in play; heat; downtime episodes; gig objectives (data / eliminate / snatch-and-extract); twists; per-fixer rep; night market + salvage; safehouse facilities; ripperdoc + therapy; Role perk trees + Role Rank | ✅ built overnight (second night) | 🔶 overnight review page |
| M7b | Data-driven world (prep for the Night City 2047 overhaul): factions with relations (sides replace team numbers; three-way fights), objectives as plug-in modules, security doctrines, docs/world → data/world pipeline with validation, locations registry (empty until 2047), save versioning + migrations, catalogue renders | ✅ built | 🔶 catalogue review page |
| M9 | Night City 2045 overhaul (owner-approved plan, artifact KP5hcvh5hAj1Zf7vk3VdNe). P1 the city as data: 26 districts, ~500 locations, 73 factions, 112 district stat blocks + the free Hardened Mooks/LTs/Mini Bosses, ~97 fixers. P2 Security and Utility Codes in play (1d10 under the code → the named faction responds; intensity on the p399 budget; Hardened → Hardened blocks; a contractor named by a place's code holds its posts; response time 1 min ≈ 2 rounds, HOUSE-RULE pacing; utilities an optional complication on 1 gig in 3); the Hardened complication tables replace our twists. P3 city map screen, jobs from location hooks via district fixers, new site generators (housing, markets, restaurants, hotels, banks, schools), travel time by district band. P4 set pieces as layout recipes: Fort Sumter, Ziggurat HQ, Main Port/Flotsam first; then NorCal base, Combat Zone, Totentanz, Hot Zone ruins, MaxTac HQ/TT Tower, the Estates, Playland | 🚧 P1-P3 built; P4 in progress | 🔶 review after each phase |
| M8+ | Fabrication/Invention, story gigs and fixer betrayals, downtime assignments, civilians/hazards/weather, vehicles, equipment models (owner: keep painted clothes for now), economy tuning, story gigs | — | per feature |

## Decisions log
- NC2045 plan (owner, 2026-11-04): book-only factions (Valentinos, Wraiths, Kang Tao, Zetatech removed); compact district stat blocks converted by deriving the missing stats (BODY = Death Save, REF from INIT, WILL from the HP formula, weapon skills from COM #, the rest from the tier's core block; RULES-UNVERIFIED); security response time 1 minute ≈ 2 rounds (HOUSE-RULE pacing, the book leaves it to the GM, p.7); the Hardened complication tables + Utility Codes replace our invented twists; weapon licences/justice deferred; jobs stay in the Fixer Network room (the Afterlife is a map location). The books are never committed; numbers and short paraphrases with PDF-page cites only (NC2045 pdf p.N = printed p.N-1).
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

### M3 playtest verdicts (user)
- It runs. Next: visuals first, a huge overhaul per the spec; questions welcome.
- Guards spawned too far away → test on a much smaller map → `skirmish` scene (30×24), now the greybox default.
- UI too barebones → aim for Baldur's Gate 3 → view/hud.gd (party portraits, initiative strip, hotbar, tooltip, log, NET panel).
- Guards not in the turn order until they join the encounter → alert system (sight 15 sq, gunfire 12 sq, shout 8 sq).
- Show building interiors only when visible to squad members → Vision (cell sight; explored remembered and dimmed; guards drawn only in sight).
- M4a look review page: https://claude.ai/artifact/918gYH5UnmSbw4vCoovnEm (db collection `verdicts`, keys m4_*).

### M4a review notes (user, chat)
- The grid should only drive movement; render the scene as if it weren't on a grid (marching cubes if needed) → WorldBuilder (continuous walls, merged floors, marching squares, shaped props, off-grid clutter).
- Not one vertical slice: draw every floor and roof → XCOM-style near-side cutaway; skyline.
- Fonts generic, UI must be more stylised, no rounded elements → CutBox chamfered chrome, Jersey 10 + VT323, pixel portraits.
- Ask a subagent for visual improvements at least twice before the next approval → two critique rounds, both applied (see commits 9419a99, 1fa4f05).
- M4b review page: https://claude.ai/artifact/Vs8526BGY2RDEK7VpBKE8X (db collection `verdicts`, keys m4b_*). The M4a page's verdicts were never saved; its questions carry over.

### M4b-c chat notes (user)
- Two more critique rounds (3 and 4) applied; then smooth (non-blocky) character models.
- Lighting on squad models; portrait polish; a juice pass incl. combat; a game-feel review applied.
- Muzzle flashes: realistically large, very short-lived, weapon-specific; no laser-like trails for
  ballistic weapons → per-weapon flash profiles, travelling rounds, brass, smoke.
- Turn banner moved under the turn-order strip (style kept).
- Run Action: the owner thought CPR had none; the core book has it (p127 Actions table, "Run: take an
  additional Move Action"), so it stays rules-as-written and is now clickable, pending the m4c_run verdict.
- Cyberspace view: a stylised environment background (six styles to pick from) under a holographic
  NET showing only linked nodes, with firewalls blocking.
- Units blend in (no extra lighting, no rings or glows); only the active unit gets a white outline.
  ROUND / UNDETECTED top right. Turn-order portraits no longer stretch. Portraits rendered from 3D.
- Review page updated in place: https://claude.ai/artifact/Vs8526BGY2RDEK7VpBKE8X (new keys m4c_*).

### M4c review verdicts (user)
- Cyberspace: wireframe reads best → variants (crisp full-res default, blueprint, scan, pixel); keep the other
  styles for transitions and weapon/item/ability effects.
- Units blend in: right, but replace the white outline with an amber caret above the active unit → done.
- Portraits: shorter necks, more hair and face variation, no busy backdrop, softer light, smaller → done
  (facial realism is limited by primitive models; real character meshes come with the asset route).
- Combat feel: good so far, needs playtesting. Combat log → top right with hover-to-expand (done). Armour /
  Friday Night Firefight spot check: core resolution matches the book; not yet in play: Suppressive Fire,
  shotgun shells, melee/brawling, grenades, Medtech stabilisation.
- Run: keep (rules as written).
- Off-grid world: right direction. Add XCOM-style cover shields on hover while moving (done) and an
  inspector for material/stats (done as hold-Alt; the owner worried a dwell timer would be annoying).
- Palette: good; later, palettes vary by neighbourhood/zone (backlog).
- Camera orthographic; cutaway keep; HUD right direction.
- Assets: CC0 packs; main worry is stiff, unrealistic animation. Plan: Quaternius Universal Base Characters +
  Universal Animation Library (CC0, humanoid rig, glTF) retargeted in Godot. The itch.io download can't be
  scripted from the cloud container; owner to download and add (or share a Drive link).
- Next: VFX + motion (done in M4c), then characters/animation (b), then gameplay (c).

### M4d review verdicts (user, two rounds)
- Motion review page (videos of every clip and combat beat): https://claude.ai/artifact/Vs8526BGY2RDEK7VpBKE8X
- Round 1 → fixed: single-shot outcomes never played (rounding bug), destroyed cover redrawn, doors only
  opened after playback, flashes larger/brighter with light, barrel follows the aim point, blood spray and
  floor splats, deaths swapped/blended, pistols, smaller guns, flat sling, steady reloads, CPR compressions,
  stand to fire (never into own cover), cleaner cyberspace.
- Round 2 → fixed: guards seen "walking through walls" were on upper storeys above the cutaway (now hidden
  while moving there; the view lifts for guards firing from above); dying units drop their gun; dodge is a
  snap duck into the crouch; pistols held upright; cover breaks into debris that stays; cyberspace readable
  again without light rings. Found on the way: failed Death Saves now play a death; screen shake was
  unstable at low frame rates.
- Deferred with the owner's OK: the rifle reload's magazine (detaching mag, matching the left hand).
- Outfits: keep the painted clothes; modelled equipment later (M6+).

### Badlands (owner, overnight brief)
- "A sunset badlands scene to make sure we can handle more natural environments": per-scene looks (fixed
  sun, sky, rim, lamp strength, palette), a sunset palette without orange/yellow neon ramps (sunlit rock went
  garish), CC0 Stylized Nature models through the world shader (rocks rising into low cliffs, dead/twisted
  trees, scrub, grass, pebbles as decoration only), buttes on the horizon, off-map ground matched to fog.


### Overnight decisions (report to owner)
- Guards: CPR NPC tiers (Mook/Lieutenant/Mini Boss, p411-415, RULES-UNVERIFIED: read from a garbled
  extraction) on the p399 budget; balance check: AI crew of 3 beats an equal number of Mooks 12/12.
- HOUSE-RULES: melee reach covers diagonal neighbours; failed-gig rescue fee, clinic treatment price
  and hire price (Campaign.ECON) are placeholders. (The frag grenade, free armour patching, the Armory
  discount and the IP rubric were removed by the core-book-only ruling below.)
- Board is the main scene; dev flags still open the tactical view directly.
- Fresh-eyes review (subagent): fixed four bugs (jack-in range anchor, NET action validation, ICE/strain
  damage events, all-unconscious hang); its next-step list is on the review page.

### Overnight decisions, night 2 (report to owner)
- Stealth (M7): guards on posts face outward; HOUSE-RULE 120° view cone (VIEW_HALF_ANGLE 60) plus
  2-square all-round awareness; Perception vs Stealth with -4 in darkness ("obscured" task modifier) and
  -2 per 5 squares past 5; badlands counts as daylight; unalerted guards patrol after each crew turn; a
  guard who sees the crew and survives a turn calls it in; backup (HOUSE-RULE 3 rounds) enters at the
  entrance farthest from the crew.
- Objectives by gig kind: data theft = pull the File or clear the site; gang hit = eliminate (not done
  while backup is inbound, HOUSE-RULE); corp extraction = snatch: GRAB (an Action) the package in the
  target building's most secure zone, carry it to the deploy zone; a downed carrier drops it.
- Twists (35% of gigs, HOUSE-RULE): Heavy security (+1 security, pay ×1.25), Blackout (no lights),
  Shift change (alarm on round 6, pay ×1.15).
- Reputation is per fixer (security tiers and pay scale with that fixer's rep); overall street cred
  still gates market stock and board size.
- Night market: book list prices; items ≥ 500 eb cost +20% "via a fixer" (spec); stock gated by
  reputation (stand-in for p337 rolls); resale at half; two guns + one melee weapon per person.
  Salvage after a won gig: 25% of the downed opposition's gear list value. *(Superseded: the book's
  Night Market and storage, see "Owner ruling, part 2".)*
- Safehouse: Med Bay, Armory, Fixer Network, Training Room; two levels each (costs and effects in
  Campaign.FACILITIES). *(Superseded: rooms have no levels or effects.)*
- Ripperdoc: twelve pieces whose effects the rules already use, book foundations (p111-116), price
  includes surgery (p110), Humanity Loss rolled; therapy = 600 eb and a week (p230), crew rests meanwhile.
- Role perks (spec "short skill tree per Role"): two tiers × two choices for Solo, Netrunner, Medtech
  (data/rules/perks.json); tier 1 100 IP, tier 2 200 IP + Role Rank 5; Role Rank at 60 × new Rank (p411).
- Unit readability in bright scenes: left as is, per your "no glows under units" verdict; options on the
  review page.
- Medtech Medicine in play (p149-150): starting split 2 Surgery / 2 Pharmaceuticals (HOUSE-RULE);
  Speedheal and Stim via DOSE; doses per gig = Medical Tech Skill, made free in downtime; a gig = a day.
- Second fresh-eyes review: fixed the backup-arrival freeze, sellable cyber-claws, Overclock on the jack-in
  turn; one stealth roll per guard/sneaker/round (HOUSE-RULE); a call-in rouses every guard on site.
- Escalation: NCPD (Lieutenant + 2 Mooks) 8 rounds after backup if still fighting; backup = 1 + security
  Mooks. p399 baseline unchanged (10/12); with escalation a slow AI crew loses ~half → WITHDRAW from the
  deploy zone (gig fails, no rescue fee, anyone left behind is lost; HOUSE-RULE).
- Review page (night 2) republished at the same URL, keys m7_*.
- Tech Role (spec priority 3): Maker Rank 4 = 8 Specialty ranks, HOUSE-RULE split Field 3 / Upgrade 3 /
  Fabrication 2; RIG (U) jury-rigs an ally's worn armour to full for the gig (Maker-table DV by price,
  RULES-UNVERIFIED vs the p140 repair sidebar); workshop +1 SP armour upgrades between gigs (p148);
  Tech perks; Tech recruits for hire.
- Heat 0-10 (HOUSE-RULE): unseen gig -1, alarm +1, NCPD +2, +1 per 3 bodies, downtime episode +1; rest
  cools 1 per 2 days; heat raises twist odds (+4%/heat) and speeds NCPD (-1 round per 2 heat).
- Cyberpsychosis out of combat: after each gig, crew at risk roll the approved episode chance once; an
  episode hurts a crewmate 2d6 (never below 1 HP).
- Personal jobs: a fixer at rep 3+ sometimes offers one (security 3, double pay, +3 rep). HOUSE-RULE
  setups: 8% of gigs from a fixer at rep 0 are a hidden setup (heavy security, guards waiting); winning
  pays nothing and that fixer stops offering work.
- Review reels added: dose, rig, grab, backup, watch. tools/campaign_autoplay.gd runs the whole loop
  headless (AI crew) as a smoke test.
- Balance (pending owner review): site opposition lowered to crew × (0.5 + security) (was 1.5 + security);
  heavy twist pays ×1.5; a call-in rouses guards within 20 squares only; gentler heat. Evidence: headless
  campaign runs with an AI crew won 0 of 15 gigs. Caveat: the AI crew can't open locked doors or sneak,
  so most gigs stalled until backup/NCPD wore it down; it's a weak proxy for a player.
- Downtime assignments: Recover / Train (+6 IP/day, half healing) / Hustle (60 eb +10/rep per day, half
  healing, 1-in-10 days +1 heat).
- Escalation retuned after measuring (balance_autoplay -- --escalate): backup = security Mooks after 5
  rounds; NCPD only at security 2+, heavy twist, or heat 3+, 12 rounds after backup. With escalation on, an
  AI crew of 3 vs equal Mooks now wins 10/12 (was 2/12), matching the no-escalation baseline.

### Owner ruling: core-book systems only → done
"Use only systems from the core rulebook, don't invent your own." Removed, with what replaced them:
- Campaign heat (gig heat, daily cool-down, twist odds, faster NCPD, MaxTac at high heat): gone. In-gig
  alarm, backup and the NCPD escalation stay, driven only by the security doctrine data (min_security,
  rounds); MaxTac is no longer in any escalation (still callable for dev renders).
- Hustle and Train downtime: gone (no book rule earns eb or IP in downtime; IP come from the GM, p410).
  Downtime is Recover only (natural healing, p223).
- Armory discount: gone; the Armory is a plain room (future storage/loadout room), no levels.
- Frag Grenade: gone (the book has no basic grenade, p94/p344); new games start with empty storage.
- Free armour repair: replaced by Item Repair (p140): the crew's best TECH + Basic Tech rolls vs the
  Price Category DV at the halfway mark of the category's time (failure starts over); work carries over
  between rests; no materials cost listed.
- Addiction therapy with no roll: replaced by p229-230: a crew Medtech (not the patient) pays the 500eb
  materials, a week passes, TECH + Medical Tech vs DV15; failure wastes the week and materials; success
  cures it and that drug's addiction roll auto-fails for a year.
- IP rubric: replaced by the Group column of the p410 table (RULES-UNVERIFIED reading): failed 10,
  won with a crew member lost 20 ("barely"), won with everyone back 30 ("worked together well").
- Per-fixer rep, faction standing, crew-wide rep: replaced by per-character Reputation (p193). A won gig's
  deed Level = 2 x security - 1, +1 if backup was called (RULES-UNVERIFIED reading of the "who knows"
  table); it replaces a character's Reputation only if higher; the board and market gate on the crew's
  best Reputation. Save v5 migrates old saves (rep → each crew member's Reputation; frags and Armory
  levels refunded).
- Still invented and not covered by the ruling (flagged for the owner): setups/twists. (Training Room,
  Med Bay, Fixer Network, salvage, rescue fee and the no-check humanity therapy: removed, see below.)

### Owner ruling, part 2: storage, the book's Night Market → done (model half; screens next)
- Storage for everything: every purchase goes into safehouse storage (Campaign.stash, Items keys:
  kit "<section>/<id>", "weapon/<id>[@poor|@excellent]", "armor/<id>[@upgraded][@sp<N>]"); nothing is
  bought for someone and owning one never blocks another. The crew equip weapons (any number, in
  equip order; built-in cyberware weapons stay) and head/body armour from storage; the replaced piece
  goes back with its upgrade and ablation (repair only works on worn armour). Recruits arrive equipped.
  The old two-guns-plus-one-melee limit, resale at half and the +20% fixer markup are gone.
- Night Market (p337-339, data/rules/night_market.json): 1d6 twice for two categories, 1d10 listings
  each on the d100 columns, repeats rerolled, every Quality Rating of a weapon, a Cyberware Option brings
  its foundations; only items the game plays are on sale. HOUSE-RULE: a market stays 3 days, then the
  next is rolled (no schedule in the book); no quantity cap (the book gives none). No Reputation gate
  (p337 gives no number). Cyberware on sale is installed free at the Ripperdoc (p338). Staples (owner's
  design): Teargas and Flashbang grenades are always available from the fixer.
- Removed: Med Bay +2 HP/day and clinic discount, Fixer Network +1 gig / earlier security, Training Room
  +5 IP (rooms have no levels; save v6 refunds levels at their build costs); salvage at 25% (the book has
  no loot rule; the Scavenger perk was removed (owner)); the 500eb rescue fee.
- Humanity therapy: p229-230 like Addiction Therapy: a crew Medtech (not the patient), a week, materials
  100eb (Standard, DV15, 2d6) or 500eb (Extreme, DV17, 4d6), TECH + Medical Tech; failure wastes both.

### Owner notes (morning after night 2) → done
- Badlands fog: out-of-sight terrain only dims (per-scene fog_sat/fog_cool/fog_dim; night scenes unchanged).
- Safehouse as a place: scenes/base.tscn is the main scene (3D warehouse in the pixel pipeline; rooms per
  facility, props by level, crew placed by downtime job and walking between rooms; click to upgrade).
- Netrunning focus: a playtester agent ran ~130 data gigs headless, an auditor checked every NET rule
  against docs/rules/cyber-net.md. Four batches of fixes (b34cfa7, 36ff9e6, 352f84d, ba0c5c0): NET/meat
  Action exclusivity, Jack In as a NET Action, held nodes lost on jack-out, dumps hit with met ICE, Programs
  (Sword, Armor), Slide, Pathfinder, the speed contest, every Black ICE effect, wound penalties on
  Interface, DV cap 12, walls block jack-in, every NET has a File, cameras that spot (and can be held in the
  NET or tampered with by hand, DV13 RULES-UNVERIFIED), patrolling ICE, firewall back-door, re-jack memory,
  Kraken cap, plug pull, NET panel with odds and a revealed-only route list.
  Completion (started at the terminal): sec1 12/24 → 24/24, sec2 21/24 → 19/24 (in 6 NET turns, was 16),
  sec3 10/24 → 16/24 (11 turns, was 22).
  HOUSE-RULES: ICE pins rather than chases; Kraken lock can't renew back to back; camera Perception 10,
  range 8.
- Cyberspace wireframe outline restored (4×4-averaged, brightness-relative edges).
- NET walk-in replays (crew walking to the terminal): sec1 11 → 18/24, sec2 16 → 18/24 (dipped to 11 when
  cameras first went live), sec3 5 → 7/24. Cameras retuned (6 squares, Perception 8, 90° cone facing
  away from the mount, tamper from 3 squares); allies can be passed through (HOUSE-RULE). Open: 4 of 72
  gigs put every target terminal behind locked security doors (shoot the door or come in through the
  NET elsewhere); guns, not ICE, are what down runners now.

### M7b: data-driven world (owner approved the approach)
- Catalogue review page: https://claude.ai/artifact/8TvGyfvdQcxBTKT8AqJVXB (verdicts in its db collection `verdicts`,
  one doc per item `cat_<section>_<id>`, plus `cat_factions__choice` and `cat_sites__choice` for the two open
  questions). Read them with ArtifactData list before acting.
- Open findings on that page: corps look alike (only sleeve colour differs); Maelstrom and MaxTac too dark at night;
  beige bystander jackets read as skin; small site types (shack, booths, ship, train) render as big blocks in raids.
- Rebuild it: `tools/catalogue.gd` (faction looks), greybox `--promo=1` shots with `--site=` / `--profile=`,
  `tools/catalogue_page.py <dir> <out.html> [notes.json]`.

