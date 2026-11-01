# Cyberpunk RED - Characters (implementation reference)

Source: core rulebook, book page numbers in parentheses. Paraphrased; numbers exact.

## 1. Core resolution (needed by everything below)

- Skill Check = STAT + Skill Level + 1d10 vs DV (or vs opponent's STAT + Skill + 1d10). Tie goes to the Defender. (p129)
- "Skill Base" = STAT + Skill Level. Skills are rated 1-10 (p85).
- Critical Success: natural 10 -> roll another 1d10 and add it (no chain). Critical Failure: natural 1 -> roll another 1d10 and subtract it (no chain). (p130)
- LUCK: before rolling, spend points from the LUCK pool; +1 to the roll per point. Pool = LUCK STAT, refills at start of each session. (p72, p130)
- Complementary Skill: GM may give a one-time +1 (no stacking). Taking 4x time: single +1. No Skill: roll STAT only (see p130). (p130)

| Difficulty | DV |
|---|---|
| Simple | 9 |
| Everyday | 13 |
| Difficult | 15 |
| Professional | 17 |
| Heroic | 21 |
| Incredible | 24 |
| Legendary | 29 |
(p129)

Common modifier examples: night/low light -1, never done before -1, complex task -2 (p130). Seriously Wounded: -2 to all Actions; Mortally Wounded: -4 all Actions, -6 MOVE (min 1) (p186).

## 2. The 10 STATs (p72)

STATs normally 2-8 at creation (Complete Package limits), can exceed 8 later.

| Group | STAT | Governs |
|---|---|---|
| Mental | INT | Intelligence/perception/learning; base for Awareness, Education skills |
| Mental | WILL | Determination, courage; feeds HP and Concentration/Endurance/Resist Torture-Drugs |
| Mental | COOL | Social presence and influence; Social/Performance skills |
| Mental | EMP | Relating to others; offsets cyberpsychosis; x10 = Humanity |
| Combat | TECH | Using tools/instruments; all Technique skills |
| Combat | REF | Reaction/coordination; ranged weapon hit chance, driving, piloting |
| Fortune | LUCK | Pool of points added to rolls (see above) |
| Physical | BODY | Size/toughness; feeds HP and Death Save |
| Physical | DEX | Physical competence; melee hit chance, dodging (Evasion), athletics |
| Physical | MOVE | Movement speed (see Derived) |

## 3. Derived stats

| Stat | Formula | Page |
|---|---|---|
| Hit Points | `10 + 5 * ceil((BODY + WILL) / 2)` (book prints a lookup table: 20 at BODY 2/WILL 2, 75 at BODY 15/WILL 10) | p79 |
| Seriously Wounded threshold | `ceil(HP / 2)`; Seriously Wounded when HP is below this | p79, p186 |
| Death Save | = BODY | p79 |
| Humanity (HUM) | `EMP * 10` (max HUM stays 10 x starting EMP, modified by therapy cap, see cyber-net.md) | p80 |
| Current EMP | tens digit of current Humanity: EMP drops each time the tens place of HUM drops (HUM 44 = EMP 4; 39 = EMP 3) | p80 |
| MOVE Action distance | MOVE x 2 m/yds, or MOVE squares on a grid (diagonals allowed) | p126, p168-169 |

HP check values: `HP = 10 + 5*ceil((BODY+WILL)/2)`: BODY 6/WILL 6 = 40; BODY 8/WILL 6 = 45; BODY 7/WILL 6 = 45.

Wound States (p186):

| State | Trigger | Effect | Stabilize DV |
|---|---|---|---|
| Lightly Wounded | HP < full | none | 10 |
| Seriously Wounded | HP < 1/2 max (round up) | -2 all Actions | 13 |
| Mortally Wounded | HP < 1 | -4 all Actions, -6 MOVE (min 1); Death Save at start of each own Turn; Critical Injury on each melee/ranged damage; Death Save Penalty +1 | 15 (heals to 1 HP, then Unconscious ~1 minute) |
| Dead | one failed Death Save | - | - |

Death Save (p222): roll d10; success if roll < BODY (after adding Death Save Penalty to the roll); natural 10 always fails. Penalty +1 per save while Mortally Wounded; resets to Base Death Save Penalty on stabilization. Some Critical Injuries raise the Base Penalty by 1 (p187, p222).
AMBIGUITY (p222): "roll under BODY" with the penalty added to the roll; implement as `d10 + penalty < BODY`, natural 10 = auto fail.

Armor (p186, for derived-stat context): damage - SP at location; leftover to HP; armor ablates 1 SP if any damage got through. Critical Injury on 2+ sixes on damage dice, +5 bonus damage direct to HP (p187).

## 4. Skills

Level rules: skills rated 1-10 (creation caps at 6). (x2) skills cost double points at creation and double IP to raise (p81, p411). Basic Skills must start at least Level 2: Athletics, Brawling, Concentration, Conversation, Education, Evasion, First Aid, Human Perception, Language (Streetslang), Local Expert (Your Home), Perception, Persuasion, Stealth (p85). Every character also gets 4 Levels in one Language from Cultural Origin (free, p85/p88).

Categories (9): Awareness, Body, Control, Education, Fighting, Performance, Ranged Weapon, Social, Technique (p81).

### Master skill list (p82-85, p130-142)

| Skill | STAT | Category | x2 | Use |
|---|---|---|---|---|
| Concentration | WILL | Awareness | | Focus, memory, ignore distraction (Basic) |
| Conceal/Reveal Object | INT | Awareness | | Hide objects/weapons; detect hidden objects |
| Lip Reading | INT | Awareness | | Read speech from lips |
| Perception | INT | Awareness | | Spot hidden things/people (not Conceal objects) (Basic) |
| Tracking | INT | Awareness | | Follow trails |
| Athletics | DEX | Body | | Jump, climb, throw, swim, lift (Basic) |
| Contortionist | DEX | Body | | Escape bonds, squeeze into spaces |
| Dance | DEX | Body | | Professional dancing |
| Endurance | WILL | Body | | Withstand harsh conditions/hardship |
| Resist Torture/Drugs | WILL | Body | | Resist pain, interrogation, drugs, gases (used as DV save) |
| Stealth | DEX | Body | | Move quietly/hide; opposed by Perception (Basic) |
| Drive Land Vehicle | REF | Control | | Drive land vehicles |
| Pilot Air Vehicle | REF | Control | x2 | Pilot air vehicles |
| Pilot Sea Vehicle | REF | Control | | Pilot sea vehicles |
| Riding | REF | Control | | Ride trained animals |
| Accounting | INT | Education | | Books, budgets, false books |
| Animal Handling | INT | Education | | Handle, train, care for animals |
| Bureaucracy | INT | Education | | Navigate bureaucracies |
| Business | INT | Education | | Business practices, sales, procurement |
| Composition | INT | Education | | Write songs, articles, stories |
| Criminology | INT | Education | | Forensics, evidence, police records |
| Cryptography | INT | Education | | Encrypt/decode messages |
| Deduction | INT | Education | | Draw non-obvious conclusions from clues; diagnosis |
| Education | INT | Education | | General schooling knowledge (Basic) |
| Gamble | INT | Education | | Odds and games of chance |
| Language | INT | Education | | One specific language per purchase (Basic: Streetslang) |
| Library Search | INT | Education | | Search databases/Data Pools for facts |
| Local Expert | INT | Education | | Know a neighborhood and its factions (Basic: Your Home) |
| Science | INT | Education | | Academic field (choose area per purchase) |
| Tactics | INT | Education | | Large-scale battle management |
| Wilderness Survival | INT | Education | | Survive in the wild |
| Brawling | DEX | Fighting | | Unarmed fighting/grappling (Basic) |
| Evasion | DEX | Fighting | | Dodge melee; REF 8+ can also dodge ranged (Basic) |
| Martial Arts | DEX | Fighting | x2 | Martial Arts forms (choose form per purchase; forms p178) |
| Melee Weapon | DEX | Fighting | | Fight with melee weapons |
| Acting | COOL | Performance | | Roles, disguise, faking emotion |
| Play Instrument | TECH | Performance | | Play an instrument (choose one) |
| Archery | REF | Ranged Weapon | | Bows/crossbows |
| Autofire | REF | Ranged Weapon | x2 | Autofire fire mode |
| Handgun | REF | Ranged Weapon | | Pistols (and SMGs per weapon table) |
| Heavy Weapons | REF | Ranged Weapon | x2 | Grenade/rocket launchers, other heavy |
| Shoulder Arms | REF | Ranged Weapon | | Rifles and shotguns |
| Bribery | COOL | Social | | Bribe appropriately |
| Conversation | EMP | Social | | Extract info through talk (Basic) |
| Human Perception | EMP | Social | | Read emotions, detect lies (Basic) |
| Interrogation | COOL | Social | | Forcibly extract information |
| Persuasion | COOL | Social | | Convince/influence (Basic) |
| Personal Grooming | COOL | Social | | Maximize attractiveness |
| Streetwise | COOL | Social | | Contacts, illegal goods, street safety |
| Trading | COOL | Social | | Bargain with merchants |
| Wardrobe & Style | COOL | Social | | Clothing choice |
| Air Vehicle Tech | TECH | Technique | | Repair air vehicles |
| Basic Tech | TECH | Technique | | Repair simple devices/anything not covered elsewhere |
| Cybertech | TECH | Technique | | Identify/repair cybernetics |
| Demolitions | TECH | Technique | x2 | Set/defuse explosives |
| Electronics/Security Tech | TECH | Technique | x2 | Complex electronics, computers, security systems, counter Defenses |
| First Aid | TECH | Technique | | Basic treatment of common Critical Injuries (Basic) |
| Forgery | TECH | Technique | | Make/detect false documents |
| Land Vehicle Tech | TECH | Technique | | Repair land vehicles |
| Paint/Draw/Sculpt | TECH | Technique | | Create visual art |
| Paramedic | TECH | Technique | x2 | Treat Critical Injuries not needing Surgery |
| Photography/Film | TECH | Technique | | Photos, video, braindances |
| Pick Lock | TECH | Technique | | Bypass non-electronic locks |
| Pick Pocket | TECH | Technique | | Lift items unnoticed |
| Sea Vehicle Tech | TECH | Technique | | Repair sea vehicles |
| Weaponstech | TECH | Technique | | Repair weapons |

Role-granted TECH skills (not buyable otherwise): **Surgery** (Medtech via Medicine; severe Critical Injuries, cyberware install) and **Medical Tech** (Medtech only; medical machinery) (p149-150, p85).

Repair-skill DV/time depends on item Price Category (sidebar p140; Maker table p149).

## 5. Role Abilities

All starting characters begin Role Ability at **Rank 4** (p142). Ranks go 1-10. Multiclassing: after Rank 4 in current Role, buy Rank 1 of a new Role's ability with IP; locked from multiclassing again until the latest Role is Rank 4 (p143). Other Roles (Rockerboy p144, Exec p153, Media p151, Lawman p158, Fixer p159, Nomad p161) not detailed here.

### 5.1 Solo - Combat Awareness (p146)

Points available = Combat Awareness Rank. Reallocate before Initiative is rolled, any time outside combat, or in combat as an Action; unchanged allocations persist. Spend points on:

| Ability | Cost | Effect |
|---|---|---|
| Damage Deflection | 2/4/6/8/10 points | Reduce the first damage taken this Round by 1/2/3/4/5 |
| Fumble Recovery | 4 points | Ignore Critical Failures (1s) rolled while attacking (roll still counts as 1) |
| Initiative Reaction | 1 point each | +1 to Initiative rolls per point |
| Precision Attack | 3/6/9 points | +1/+2/+3 to Attacks |
| Spot Weakness | 1 point each | +1 damage (before armor) per point on first successful Attack each Round |
| Threat Detection | 1 point each | +1 to Perception Checks per point |

Example: Rank 6 = 6 points, e.g. Damage Deflection 1 (2) + Spot Weakness 2 (2) + Threat Detection 2 (2).
AMBIGUITY (p146): text does not state a Rank gate per ability or whether Spot Weakness/Deflection points must be bought in the stepped amounts shown; implemented as shown.

### 5.2 Netrunner - Interface (p147, p197)

| Interface Rank | 1-3 | 4-6 | 7-9 | 10 |
|---|---|---|---|---|
| NET Actions per Turn | 2 | 3 | 4 | 5 |

Interface Abilities (Backdoor, Cloak, Control, Eye-Dee, Pathfinder, Scanner, Slide, Virus, Zap): exact mechanics in cyber-net.md. Roll for abilities = Interface Rank + 1d10 vs DV (p198).

### 5.3 Tech - Maker (p147-149)

On each Maker Rank increase: +1 Rank in two different Maker Specialties of your choice (Field, Upgrade, Fabrication, Invention Expertise). At Rank 4 start: 8 specialty ranks to distribute.

| Specialty | Mechanic |
|---|---|
| Field Expertise | Add Rank to any Basic Tech, Cybertech, Electronics/Security Tech, Weaponstech, or Land/Sea/Air Vehicle Tech check made for non-Maker purposes. With 1+ Rank: jury-rig an item to perfect condition (full SP/HP) as an Action at the normal repair DV (+Rank to the check); lasts 10 minutes per Rank, then reverts and cannot be jury-rigged again until fully repaired. (p147) |
| Upgrade Expertise | Apply one upgrade per item: reduce non-borgware cyberware HL by 1d6 (if its HL was 2d6+); +1 option/attachment/program slot; halve future full-repair time; make a one-handed weapon concealable; Average -> Excellent weapon quality; add attachment slot to Exotic weapon; let Exotic weapon fire one Non-Basic ammo type; +1 SP (only if item had SP); vehicle upgrade needing Nomad Rank 1; install a self-invented upgrade (materials = Price Category set at invention). Check: TECH + the item's repair Skill + Rank + 1d10 vs table DV; need materials of the item's price category; failure wastes time but nothing is lost. Cheap items fabricate for 5eb. (p148) |
| Fabrication Expertise | Build an existing or invented item. Check: TECH + repair Skill + Rank + 1d10 vs table DV; materials cost one price category lower than the item (Super Luxury: half price). Failure restarts, materials survive. (p148) |
| Invention Expertise | Design a new item or upgrade; GM writes rules and sets Price Category (minimum Expensive). Check: TECH + relevant repair Skill + Rank + 1d10 vs DV. Others cannot make it until blueprints exist. (p148-149) |

Upgrade/Fabricate/Invent DV and time (p149):

| Price Category | DV | Time |
|---|---|---|
| Cheap/Everyday | 9 | 1 hour |
| Costly | 13 | 6 hours |
| Premium | 17 | 1 day |
| Expensive | 21 | 1 week |
| Very Expensive | 24 | 2 weeks |
| Luxury | 29 | 1 month |
| Super Luxury | 29 | 1 month per 10,000eb of cost |

### 5.4 Medtech - Medicine (p149-150)

On each Medicine Rank increase, allocate 1 point to one of three Specialties (starting Rank 4 = 4 points).

| Specialty | Effect |
|---|---|
| Surgery | Each point = +2 Levels of the Surgery Skill (max 10). Surgery treats the worst Critical Injuries and installs cyberware (DVs in cyber-net.md). |
| Medical Tech (Pharmaceuticals) | Each point = +1 Medical Tech Skill (max 10 total, max 5 points here). Each point also unlocks one Pharmaceutical: synthesize with DV13 Medical Tech Check; from 200eb of materials make doses = Medical Tech Skill Level in 1 hour; failure wastes materials. Not Street Drugs. |
| Medical Tech (Cryosystem Operation) | Each point = +1 Medical Tech Skill (max 5 points here). Medical Tech Skill = Pharmaceutical points + Cryosystem points. Benefits table below. |

Pharmaceuticals (p150): giving a dose is an Action (unwilling target: melee Airhypo attack that delivers a dose instead of damage). Only Medtechs can administer correctly.

| Drug | Effect |
|---|---|
| Antibiotic | Target already healing recovers +2 HP/day for a week; one use at a time |
| Rapidetox | Purges all drug/poison/intoxicant effects at once |
| Speedheal | Non-Mortally-Wounded target heals BODY + WILL HP instantly; once per day |
| Stim | Ignore Seriously Wounded penalties for 1 hour; once per day |
| Surge | No sleep penalty for 24 hours; once per week |

Cryosystem benefits (p150): 1 pt = 1 Cryopump; 2 = Registered Cryotank Technician (24/7 access to 1 Cryotank at medical/government facilities); 3 = own Cryotank installed in a room of choice; 4 = +2 Cryotanks (same room), Cryopump 2 charges, carries 2 people in stasis; 5 = +3 more Cryotanks, Cryopump 3 charges, carries 3 people. (Details p353.)

Other Medtech-only uses (Surgery for cyberware installation/harvesting, Bodysculpting, Therapy, Medical Tech): p226-230, see cyber-net.md.

## 6. Improvement Points (IP)

Cost to raise to the next Level/Rank (cannot skip levels) (p411):

| Raise to Level/Rank | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Normal Skill (20 x new Level) | 20 | 40 | 60 | 80 | 100 | 120 | 140 | 160 | 180 | 200 |
| (x2) Skill (40 x new Level) | 40 | 80 | 120 | 160 | 200 | 240 | 280 | 320 | 360 | 400 |
| Role Ability Rank (60 x new Rank) | 60 | 120 | 180 | 240 | 300 | 360 | 420 | 480 | 540 | 600 |

Earning IP per session (p410-411): Group column or Playstyle column (Warrior, Socializer, Explorer, Roleplayer), GM awards 10, 20, 30, 40, 50, 60, 70, or 80 (80 = legendary/group all goals plus side goals). Take the higher of Group result or the best-fitting Playstyle result.
AMBIGUITY (p410): award tier descriptions are qualitative; the game needs its own rubric mapping mission outcomes to 10-80.

## 7. Character creation

Order: STATs -> derived (HP, HUM) -> Skills -> Weapons/Armor -> Outfit/Fashion -> Lifestyle -> Cyberware (p72-120). Role Ability starts at Rank 4 (p142).

| Method | STATs | Skills | Gear |
|---|---|---|---|
| 1. Streetrat (Templates) | Roll 1d10 once on the Role's row; copy the whole row; do not rearrange (p73) | Fixed per Role, fixed levels, + 4-level Language (p86-87) | Fixed lists per Role (p98, p103, p117); plus 500eb cash to spend or keep (p98) |
| 2. Edgerunner (Fast and Dirty) | Roll 1d10 per STAT, read that STAT's column of the Role's table (p77) | Role's fixed 20 skills, you spread **86 points**; each skill min 2, max 6; (x2) skills cost 2 per level; the 4-level cultural Language is free (p88) | Same fixed lists as Streetrat, 500eb (p98) |
| 3. Complete Package | Spend a pool of points; each STAT 2-8. Pool by rank: Minor Supporting 50, **Starting 62**, Major Supporting 70, Minor Hero 75, Major Hero 80 (p78) | **86 points** over any skills; max 6; Basic Skills min 2; (x2) cost double; free 4-level Language (p90) | **2,550eb** for weapons, armor, gear, cyberware (keep unspent) (p104); plus **800eb** for Fashion/Fashionware only, unspent is lost (p105) |

Streetrat/Edgerunner note: no pooling of money between players; no extra starting funds recommended; Luxury+ items at creation not recommended (p95).

Lifestyle (p105): non-Exec start in rented Cargo Container with Kibble lifestyle; first month free; owe 1100eb on the 1st of next month or evicted on the 2nd. Exec: rent-free Corporate Conapt with Good Prepak lifestyle, paid this month, then 600eb on the 1st of each month. (Nomads have a Moto housing option, p165.)

Starting cyberware: Streetrat/Edgerunner get a fixed Role list (p117); Humanity Loss totals pre-computed: Rockerboy 9 (-1 EMP), Solo 14, Netrunner 14, Tech 12, Medtech 12, Media 10, Lawman 10, Exec 12, Fixer 16, Nomad 14 (each -2 EMP except Rockerboy). Complete Package buys cyberware from the 2,550eb pool. Optional extra: GM may allow signing on with a Corporation/Mob/military for 1500eb of cyberware plus a free Neural Link, with an employer hook (p118-119). At creation, Humanity Loss uses the fixed numbers (2d6=7, 1d6=3, 1d6/2 round up=2, 4d6=14); afterwards roll the dice (p111).

### Streetrat starting cyberware (p117)

| Role | Cyberware | HL total |
|---|---|---|
| Rockerboy | Audio Recorder, Chemskin, Cyberaudio Suite, Techhair | 9 (EMP -1) |
| Solo | Biomonitor, Neural Link, Sandevistan or Wolvers | 14 (EMP -2) |
| Netrunner | Interface Plugs, Neural Link, Shift Tacts, Skinwatch | 14 (EMP -2) |
| Tech | Cybereye, MicroOptics, Skinwatch, Tool Hand | 12 (EMP -2) |
| Medtech | Biomonitor, Cybereye, Nasal Filters or Toxin Binders, TeleOptics | 12 (EMP -2) |
| Media | Amplified Hearing or Voice Stress Analyzer, Cyberaudio Suite, Light Tattoo | 10 (EMP -2) |
| Lawman | Hidden Holster, Subdermal Pocket | 10 (EMP -2) |
| Exec | Biomonitor or Techhair, Cyberaudio Suite, Internal Agent, Toxin Binders or Nasal Filters | 12 (EMP -2) |
| Fixer | Cyberaudio Suite, Internal Agent, Subdermal Pocket, Voice Stress Analyzer or Amplified Hearing | 16 (EMP -2) |
| Nomad | Interface Plugs or Wolvers, Neural Link | 14 (EMP -2) |

Resolved (p117): the Solo list is "Sandevistan Speedware or Wolvers"; Biomonitor is 0 HL, so 0 + 7 + 7 = 14.

### Edgerunner skill lists (non-Basic part; 7 per Role + 13 Basic = 20 skills) (p88-89)

| Role | Role skills |
|---|---|
| Rockerboy | Composition, Handgun, Melee Weapon, Personal Grooming, Play Instrument (choose 1), Streetwise, Wardrobe & Style |
| Solo | Autofire (x2), Handgun, Interrogation, Melee Weapon, Resist Torture/Drugs, Shoulder Arms, Tactics |
| Netrunner | Basic Tech, Conceal/Reveal Object, Cryptography, Cybertech, Electronics/Security Tech (x2), Handgun, Library Search |
| Tech | Basic Tech, Cybertech, Electronics/Security Tech (x2), Land Vehicle Tech, Shoulder Arms, Science (choose 1), Weaponstech |
| Medtech | Basic Tech, Cybertech, Deduction, Paramedic (x2), Resist Torture/Drugs, Science (choose 1), Shoulder Arms |
| Media | Bribery, Composition, Deduction, Handgun, Library Search, Lip Reading, Photography/Film |
| Lawman | Autofire, Criminology, Deduction, Handgun, Interrogation, Shoulder Arms, Tracking |
| Exec | Accounting, Bureaucracy, Business, Deduction, Handgun, Lip Reading, Personal Grooming |
| Fixer | Bribery, Business, Forgery, Handgun, Pick Lock, Streetwise, Trading |
| Nomad | Animal Handling, Drive Land Vehicle, Handgun, Melee Weapon, Tracking, Trading, Wilderness Survival |

Edgerunner example: 20 skills x4 = 80, +6 spare; cost counts (x2) skills at double (p88-89). Lawman's Autofire is listed without (x2) in the table (p89); AMBIGUITY (p89): likely a typo, Autofire is (x2) in the master list (p83).

### Streetrat starting skill levels (Basic Skills + Role skills) (p86-87)

Basic skills by Role (Athletics 2 and Concentration 2 and Language Streetslang 2 for all unless noted; Exec/Nomad/Fixer differences noted):

| Basic skill | Rock | Solo | Net | Tech | Med | Media | Law | Exec | Fix | Nom |
|---|---|---|---|---|---|---|---|---|---|---|
| Athletics | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |
| Brawling | 6 | 2 | 2 | 2 | 2 | 2 | 6 | 2 | 2 | 6 |
| Concentration | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 |
| Conversation | 2 | 2 | 2 | 2 | 6 | 6 | 6 | 6 | 6 | 2 |
| Education | 2 | 2 | 6 | 6 | 6 | 2 | 2 | 6 | 2 | 2 |
| Evasion | 6 | 6 | 6 | 6 | 6 | 6 | 6 | 6 | 6 | 6 |
| First Aid | 6 | 6 | 2 | 6 | 2 | 2 | 2 | 2 | 2 | 6 |
| Human Perception | 6 | 2 | 2 | 2 | 6 | 6 | 2 | 6 | 6 | 2 |
| Language (Streetslang) | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 4 | 2 |
| Local Expert (Your Home) | 4 | 2 | 2 | 2 | 2 | 6 | 2 | 2 | 6 | 2 |
| Perception | 2 | 6 | 2 | 2 | 2 | 6 | 2 | 2 | 2 | 4 |
| Persuasion | 6 | 2 | 2 | 2 | 2 | 6 | 2 | 6 | 4 | 2 |
| Stealth | 2 | 2 | 6 | 2 | 2 | 2 | 2 | 2 | 2 | 6 |

Role skills (all 6 unless marked):
- Rockerboy: Composition, Handgun, Melee Weapon, Personal Grooming 4, Play Instrument (choose 1), Streetwise, Wardrobe & Style 4
- Solo: Autofire, Handgun, Interrogation, Melee Weapon, Resist Torture/Drugs, Shoulder Arms, Tactics
- Netrunner: Basic Tech, Conceal/Reveal Object, Cryptography, Cybertech, Electronics/Security Tech, Handgun, Library Search
- Tech: Basic Tech, Cybertech, Electronics/Security Tech, Land Vehicle Tech, Science (choose 1), Shoulder Arms, Weaponstech
- Medtech: Basic Tech, Cybertech 4, Deduction, Paramedic, Resist Torture/Drugs 4, Science (choose 1), Shoulder Arms
- Media: Bribery, Composition, Deduction, Handgun, Library Search 4, Lip Reading 4, Photography/Film 4
- Lawman: Autofire, Criminology, Deduction, Handgun, Interrogation, Shoulder Arms, Tracking
- Exec: Accounting, Bureaucracy, Business, Deduction, Handgun, Lip Reading, Personal Grooming 4
- Fixer: Bribery, Business, Forgery, Handgun, Pick Lock 4, Streetwise, Trading
- Nomad: Animal Handling, Drive Land Vehicle, Handgun, Melee Weapon, Tracking, Trading, Wilderness Survival

(p86-87)

### Streetrat starting gear (p98, p103) - summary

Each Role gets a fixed list of weapons (with choices marked "or"), Light Armorjack body+head (SP11) in most Roles, ammo, an Agent, a Role outfit (Netrunner: Cyberdeck with 7 slots plus Programs Armor, Sword, and one of See Ya/Eraser/Vrizzbolt/Worm; Tech: Tech Bag; Medtech: Medtech Bag, Airhypo) and Fashion pieces. Full per-Role lists are on p98 and p103 of the book; the game should keep these as data. 500eb cash extra (p98). Complete Package buys all of it individually (p104).

### Streetrat STAT templates (roll 1d10, take the row; Edgerunner: roll per STAT column) (p74-77)

| Role | d10 | INT | REF | DEX | TECH | COOL | WILL | LUCK | MOVE | BODY | EMP |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Rockerboy | 1 | 7 | 6 | 6 | 5 | 6 | 8 | 7 | 7 | 3 | 8 |
| Rockerboy | 2 | 3 | 7 | 7 | 7 | 7 | 6 | 7 | 7 | 5 | 8 |
| Rockerboy | 3 | 4 | 5 | 7 | 7 | 6 | 6 | 7 | 7 | 5 | 8 |
| Rockerboy | 4 | 4 | 5 | 7 | 7 | 6 | 8 | 7 | 6 | 3 | 8 |
| Rockerboy | 5 | 3 | 7 | 7 | 7 | 6 | 8 | 6 | 5 | 4 | 7 |
| Rockerboy | 6 | 5 | 6 | 7 | 5 | 7 | 8 | 5 | 7 | 3 | 7 |
| Rockerboy | 7 | 5 | 6 | 6 | 7 | 7 | 8 | 7 | 6 | 3 | 6 |
| Rockerboy | 8 | 5 | 7 | 7 | 5 | 6 | 6 | 6 | 6 | 4 | 8 |
| Rockerboy | 9 | 3 | 5 | 5 | 6 | 7 | 8 | 7 | 5 | 5 | 7 |
| Rockerboy | 10 | 4 | 5 | 6 | 5 | 8 | 8 | 7 | 6 | 4 | 7 |
| Solo | 1 | 6 | 7 | 7 | 3 | 8 | 6 | 5 | 5 | 6 | 5 |
| Solo | 2 | 7 | 8 | 6 | 3 | 6 | 6 | 7 | 5 | 6 | 6 |
| Solo | 3 | 5 | 8 | 7 | 4 | 7 | 7 | 6 | 7 | 8 | 5 |
| Solo | 4 | 5 | 8 | 6 | 4 | 6 | 7 | 6 | 5 | 7 | 6 |
| Solo | 5 | 6 | 6 | 7 | 5 | 7 | 6 | 7 | 6 | 8 | 4 |
| Solo | 6 | 7 | 7 | 6 | 5 | 7 | 6 | 6 | 7 | 7 | 5 |
| Solo | 7 | 7 | 7 | 6 | 5 | 6 | 7 | 7 | 6 | 6 | 6 |
| Solo | 8 | 7 | 8 | 7 | 5 | 6 | 6 | 5 | 6 | 8 | 4 |
| Solo | 9 | 7 | 7 | 6 | 4 | 6 | 6 | 6 | 5 | 6 | 5 |
| Solo | 10 | 6 | 6 | 8 | 5 | 6 | 6 | 5 | 6 | 6 | 5 |
| Netrunner | 1 | 5 | 8 | 7 | 7 | 7 | 4 | 8 | 7 | 7 | 4 |
| Netrunner | 2 | 5 | 6 | 7 | 5 | 8 | 3 | 8 | 7 | 5 | 5 |
| Netrunner | 3 | 5 | 6 | 8 | 6 | 6 | 4 | 7 | 6 | 7 | 4 |
| Netrunner | 4 | 5 | 7 | 7 | 7 | 7 | 5 | 8 | 6 | 5 | 5 |
| Netrunner | 5 | 5 | 8 | 8 | 5 | 7 | 3 | 7 | 5 | 5 | 6 |
| Netrunner | 6 | 6 | 6 | 6 | 7 | 8 | 4 | 7 | 7 | 6 | 6 |
| Netrunner | 7 | 6 | 6 | 6 | 7 | 6 | 5 | 7 | 7 | 7 | 6 |
| Netrunner | 8 | 5 | 7 | 8 | 6 | 8 | 4 | 8 | 5 | 7 | 4 |
| Netrunner | 9 | 7 | 6 | 7 | 7 | 6 | 3 | 6 | 5 | 6 | 5 |
| Netrunner | 10 | 7 | 8 | 6 | 6 | 6 | 4 | 7 | 7 | 5 | 6 |
| Tech | 1 | 6 | 7 | 7 | 8 | 4 | 4 | 5 | 5 | 7 | 6 |
| Tech | 2 | 7 | 6 | 6 | 7 | 5 | 3 | 7 | 7 | 5 | 5 |
| Tech | 3 | 8 | 6 | 5 | 7 | 5 | 4 | 7 | 7 | 5 | 7 |
| Tech | 4 | 7 | 8 | 7 | 8 | 4 | 4 | 6 | 5 | 6 | 7 |
| Tech | 5 | 6 | 6 | 7 | 6 | 4 | 3 | 7 | 7 | 6 | 6 |
| Tech | 6 | 8 | 7 | 5 | 6 | 3 | 3 | 7 | 6 | 6 | 7 |
| Tech | 7 | 8 | 6 | 7 | 8 | 4 | 4 | 7 | 6 | 7 | 6 |
| Tech | 8 | 8 | 8 | 7 | 8 | 5 | 4 | 6 | 5 | 6 | 6 |
| Tech | 9 | 6 | 6 | 7 | 8 | 3 | 3 | 5 | 7 | 7 | 7 |
| Tech | 10 | 8 | 8 | 5 | 6 | 4 | 4 | 6 | 5 | 6 | 6 |
| Medtech | 1 | 7 | 5 | 6 | 7 | 5 | 3 | 8 | 5 | 5 | 7 |
| Medtech | 2 | 6 | 7 | 7 | 7 | 4 | 4 | 6 | 7 | 7 | 7 |
| Medtech | 3 | 6 | 5 | 5 | 8 | 5 | 3 | 8 | 5 | 7 | 8 |
| Medtech | 4 | 8 | 7 | 6 | 8 | 3 | 5 | 6 | 6 | 5 | 7 |
| Medtech | 5 | 6 | 7 | 5 | 7 | 5 | 5 | 8 | 7 | 6 | 8 |
| Medtech | 6 | 8 | 5 | 5 | 8 | 5 | 5 | 6 | 6 | 5 | 6 |
| Medtech | 7 | 8 | 6 | 5 | 8 | 5 | 4 | 8 | 5 | 7 | 7 |
| Medtech | 8 | 6 | 5 | 7 | 7 | 3 | 5 | 8 | 5 | 5 | 8 |
| Medtech | 9 | 6 | 6 | 7 | 7 | 5 | 4 | 6 | 6 | 5 | 6 |
| Medtech | 10 | 8 | 7 | 6 | 6 | 3 | 4 | 8 | 7 | 6 | 7 |
| Media | 1 | 6 | 6 | 5 | 5 | 8 | 7 | 5 | 7 | 5 | 7 |
| Media | 2 | 8 | 7 | 7 | 3 | 6 | 6 | 6 | 5 | 6 | 8 |
| Media | 3 | 6 | 7 | 7 | 5 | 6 | 8 | 5 | 5 | 5 | 7 |
| Media | 4 | 6 | 5 | 7 | 5 | 6 | 7 | 5 | 5 | 6 | 6 |
| Media | 5 | 6 | 6 | 7 | 4 | 8 | 7 | 6 | 7 | 5 | 8 |
| Media | 6 | 7 | 5 | 5 | 4 | 8 | 7 | 6 | 7 | 5 | 8 |
| Media | 7 | 8 | 5 | 6 | 3 | 7 | 6 | 6 | 5 | 6 | 7 |
| Media | 8 | 6 | 5 | 6 | 5 | 6 | 8 | 6 | 6 | 7 | 8 |
| Media | 9 | 7 | 7 | 5 | 4 | 6 | 7 | 6 | 5 | 6 | 7 |
| Media | 10 | 7 | 6 | 6 | 3 | 7 | 6 | 7 | 6 | 7 | 6 |
| Lawman | 1 | 5 | 6 | 7 | 5 | 7 | 8 | 5 | 6 | 5 | 6 |
| Lawman | 2 | 6 | 6 | 6 | 5 | 6 | 8 | 5 | 7 | 5 | 5 |
| Lawman | 3 | 5 | 7 | 7 | 7 | 6 | 7 | 5 | 5 | 7 | 6 |
| Lawman | 4 | 6 | 6 | 7 | 6 | 6 | 8 | 5 | 7 | 7 | 6 |
| Lawman | 5 | 6 | 6 | 7 | 6 | 7 | 7 | 6 | 5 | 5 | 6 |
| Lawman | 6 | 7 | 6 | 5 | 5 | 7 | 8 | 5 | 6 | 7 | 4 |
| Lawman | 7 | 7 | 8 | 7 | 5 | 6 | 8 | 7 | 6 | 5 | 4 |
| Lawman | 8 | 5 | 6 | 6 | 5 | 6 | 8 | 5 | 7 | 6 | 4 |
| Lawman | 9 | 7 | 7 | 5 | 5 | 7 | 7 | 6 | 5 | 5 | 6 |
| Lawman | 10 | 6 | 6 | 5 | 6 | 8 | 7 | 5 | 7 | 6 | 6 |
| Exec | 1 | 8 | 5 | 5 | 3 | 8 | 6 | 6 | 5 | 5 | 7 |
| Exec | 2 | 8 | 6 | 6 | 4 | 7 | 6 | 7 | 7 | 5 | 7 |
| Exec | 3 | 8 | 7 | 6 | 3 | 8 | 6 | 7 | 6 | 4 | 5 |
| Exec | 4 | 8 | 5 | 7 | 5 | 6 | 5 | 6 | 5 | 5 | 7 |
| Exec | 5 | 7 | 7 | 6 | 5 | 8 | 5 | 7 | 7 | 5 | 6 |
| Exec | 6 | 5 | 7 | 7 | 3 | 6 | 7 | 6 | 5 | 5 | 7 |
| Exec | 7 | 6 | 6 | 7 | 5 | 8 | 7 | 6 | 7 | 4 | 6 |
| Exec | 8 | 6 | 7 | 7 | 3 | 7 | 5 | 7 | 5 | 5 | 7 |
| Exec | 9 | 7 | 6 | 7 | 5 | 7 | 5 | 7 | 6 | 5 | 5 |
| Exec | 10 | 7 | 7 | 5 | 5 | 8 | 6 | 6 | 7 | 4 | 7 |
| Fixer | 1 | 8 | 5 | 7 | 4 | 6 | 5 | 8 | 5 | 5 | 8 |
| Fixer | 2 | 8 | 5 | 5 | 5 | 6 | 7 | 8 | 7 | 5 | 7 |
| Fixer | 3 | 6 | 6 | 6 | 4 | 5 | 6 | 8 | 6 | 3 | 8 |
| Fixer | 4 | 7 | 7 | 5 | 5 | 7 | 6 | 7 | 7 | 5 | 8 |
| Fixer | 5 | 8 | 6 | 6 | 3 | 6 | 5 | 8 | 7 | 5 | 6 |
| Fixer | 6 | 8 | 7 | 5 | 5 | 6 | 7 | 7 | 5 | 3 | 6 |
| Fixer | 7 | 8 | 6 | 6 | 5 | 6 | 5 | 6 | 7 | 5 | 8 |
| Fixer | 8 | 6 | 6 | 7 | 4 | 7 | 6 | 7 | 7 | 4 | 7 |
| Fixer | 9 | 8 | 7 | 7 | 5 | 5 | 5 | 7 | 6 | 5 | 7 |
| Fixer | 10 | 6 | 5 | 6 | 5 | 5 | 6 | 8 | 6 | 4 | 7 |
| Nomad | 1 | 6 | 6 | 8 | 3 | 6 | 7 | 6 | 6 | 6 | 4 |
| Nomad | 2 | 5 | 7 | 6 | 5 | 8 | 8 | 8 | 7 | 5 | 4 |
| Nomad | 3 | 5 | 8 | 6 | 3 | 8 | 7 | 6 | 5 | 6 | 5 |
| Nomad | 4 | 5 | 8 | 7 | 4 | 8 | 6 | 7 | 7 | 7 | 5 |
| Nomad | 5 | 6 | 6 | 6 | 3 | 6 | 7 | 6 | 7 | 7 | 4 |
| Nomad | 6 | 7 | 6 | 8 | 4 | 6 | 7 | 6 | 5 | 6 | 5 |
| Nomad | 7 | 6 | 7 | 8 | 4 | 6 | 6 | 7 | 5 | 7 | 5 |
| Nomad | 8 | 5 | 7 | 8 | 3 | 8 | 6 | 7 | 5 | 5 | 5 |
| Nomad | 9 | 6 | 7 | 6 | 4 | 8 | 6 | 6 | 6 | 6 | 6 |
| Nomad | 10 | 5 | 6 | 7 | 4 | 7 | 8 | 7 | 7 | 7 | 4 |
