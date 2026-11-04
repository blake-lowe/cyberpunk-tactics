# Cyberpunk RED: Equipment Reference

Weapons, attachments, ammunition, armour, shields, general gear, drugs, pharmaceuticals and fashion
from the core rulebook, imported for the game's data (data/rules/weapons.json, armor.json, gear.json).
Page numbers are book pages; numbers are exact, rules are short paraphrases (never rulebook text).

How the data reads: each item has `fx` (machine-readable effects; vocabulary in gear.json `fx_keys`)
and, where fx can't express a rule, `unmodelled`. Only items whose effects the game implements are
sold in the night market (`shop_rep`); the rest are data waiting for their mechanics.

## Weapons Reference (CPR core p.91-95, p.173-177, p.340-349, p.385)

Page numbers are book pages. Numbers are exact; rules are short paraphrases. Data: `weapons.json` (slice "weapons").

### 1. Price Categories (p.385)

| Category | eb |
|---|---|
| Cheap | 10 |
| Everyday | 20 |
| Costly | 50 |
| Premium | 100 |
| Expensive | 500 |
| Very Expensive | 1,000 |
| Luxury | 5,000 |
| Super Luxury | 10,000+ |

- Without a Fixer or a Night Market you can only buy up to Premium (p.385).

### 2. Melee Weapons (p.92, p.340, p.175)

| Type | Examples | Dmg | ROF | Conceal | Cost | Page |
|---|---|---|---|---|---|---|
| Light Melee | Combat Knife, Tomahawk | 1d6 | 2 | Yes | 50 (Costly) | p.92 |
| Medium Melee | Baseball Bat, Crowbar, Machete | 2d6 | 2 | No | 50 (Costly) | p.92 |
| Heavy Melee | Lead Pipe, Sword, Spiked Bat | 3d6 | 2 | No | 100 (Premium) | p.92 |
| Very Heavy Melee | Chainsaw, Sledgehammer, Naginata | 4d6 | 1 | No | 500 (Expensive) | p.92 |

- The book sets hands per weapon, not per class ("varies by type") (p.92).
- Melee damage ignores half the defender's SP, rounded up (p.176).
- Melee skill is generally tied to DEX (p.91).

### 3. Ranged Weapons (p.94, p.341, Clip Chart p.344)

| Type | Skill | Dmg | Mag (ammo) | Ext / Drum | ROF | Hands | Conceal | Special | Cost |
|---|---|---|---|---|---|---|---|---|---|
| Medium Pistol | Handgun | 2d6 | 12 (M Pistol) | 18 / 36 | 2 | 1 | Yes | - | 50 (Costly) |
| Heavy Pistol | Handgun | 3d6 | 8 (H Pistol) | 14 / 28 | 2 | 1 | Yes | - | 100 (Premium) |
| Very Heavy Pistol | Handgun | 4d6 | 8 (VH Pistol) | 14 / 28 | 1 | 1 | No | - | 100 (Premium) |
| SMG | Handgun | 2d6 | 30 (M Pistol) | 40 / 50 | 1 | 1 | Yes | Autofire (3), Suppressive | 100 (Premium) |
| Heavy SMG | Handgun | 3d6 | 40 (H Pistol) | 50 / 60 | 1 | 1 | No | Autofire (3), Suppressive | 100 (Premium) |
| Shotgun | Shoulder Arms | 5d6 | 4 (Slug) | 8 / 16 | 1 | 2 | No | Shotgun Shell | 500 (Expensive) |
| Assault Rifle | Shoulder Arms | 5d6 | 25 (Rifle) | 35 / 45 | 1 | 2 | No | Autofire (4), Suppressive | 500 (Expensive) |
| Sniper Rifle | Shoulder Arms | 5d6 | 4 (Rifle) | 8 / 12 | 1 | 2 | No | - | 500 (Expensive) |
| Bows & Crossbows | Archery | 4d6 | N/A (Arrow) | - | 1 | 2 | No | Arrows | 100 (Premium) |
| Grenade Launcher | Heavy Weapons | 6d6 | 2 (Grenade) | 4 / 6 | 1 | 2 | No | Explosive | 500 (Expensive) |
| Rocket Launcher | Heavy Weapons | 8d6 | 1 (Rocket) | 2 / 3 | 1 | 2 | No | Explosive | 500 (Expensive) |

- Ranged skill is generally tied to REF (p.93).
- Ammo must match the weapon's type: M/H/VH Pistol, Slug or Rifle bullets, Shotgun Shell, Arrow, Grenade, Rocket (p.344).
- Basic ammo costs 10eb per 10 (Cheap). There is no Basic grenade or rocket: those are bought one at a time by type (p.94, p.344).
- Non-exotic ranged weapons have 3 attachment slots. Attachments are not covered here (p.96, p.342).

#### Alt Fire Modes (p.173-174)
- **Autofire**: costs an Action and 10 rounds, uses the Autofire skill and the Autofire DV row, no Aimed Shot. Damage is 2d6 x (amount the DV was beaten by), capped at the weapon's multiplier. Double 6 gives a Critical Injury.
- **Suppressive Fire**: costs an Action and 10 rounds. Everyone on foot, out of cover and in sight within 25 m makes WILL+Concentration against your REF+Autofire. Anyone who fails must spend their next move getting to cover.
- **Shotgun Shell**: one attack vs DV13. On a hit, every visible target in front of you within 6 m takes 3d6, rolled once. No Aimed Shot.
- **Arrows**: loading is part of the attack, so bows never Reload. Basic arrows can be recovered.
- **Explosive**: hits a 10x10 m (5x5 squares) area centred on the target square, with damage rolled once. On a miss the GM places the blast within that area. Cover the blast can't destroy protects whoever is behind it.

#### Thrown (p.177)
- Throwing an object takes an Action: DEX+Athletics against the Grenade Launcher DV row, to a maximum of 25 m. Targets who can dodge bullets can dodge it.
- A thrown melee weapon deals its normal damage but does not halve SP. A grenade does its launcher damage. Improvised objects do whatever the GM decides.

### 4. Weapon Quality (p.342)

| Standard cost | Poor | Excellent |
|---|---|---|
| 50 (Costly) | 20 (Everyday) | 100 (Premium) |
| 100 (Premium) | 50 (Costly) | 500 (Expensive) |
| 500 (Expensive) | 100 (Premium) | 1,000 (Very Expensive) |

- **Poor**: a Critical Failure (natural 1) on the attack jams the weapon. Clearing it takes an Action, with no Check.
- **Excellent**: +1 to Attack Checks.
- The book also calls Standard quality "Average" (p.95, p.347).

#### Brand Examples (Poor / Standard / Excellent, p.342)

| Type | Poor | Standard | Excellent |
|---|---|---|---|
| Medium Pistol | Dai Lung Streetmaster | Federated Arms X-9mm | Militech "Avenger" |
| Heavy Pistol | Dai Lung Magnum | Mustang Arms "Mark III" | Nova "Cityhunter" |
| Very Heavy Pistol | Federated Arms "Super Chief" | Sternmeyer P-35 | Militech "Boomer Buster" |
| Bow | GunMart "Sherwood" | Eagletech "Tomcat" | Eagletech "Bearcat" |
| Crossbow | GunMart "Hunter" | Eagletech "Striker" | Eagletech "Scorpion" |
| SMG | Federated Arms Tech-Assault III | Militech "Mini-Gat" | Arasaka "Minami 10" |
| Heavy SMG | Chadran Arms "City Reaper" | Sternmeyer SMG-21 | Militech "Viper" |
| Shotgun | GunMart "Home Defender" | Arasaka "Rapid Assault" | Militech "Bulldog" |
| Assault Rifle | Chadran Arms "Jungle Reaper" | Militech "Ronin" | Militech "Dragon" |
| Sniper Rifle | GunMart "Snipe-Star" | Nomad "Long Rifle" | Arasaka WSSA Sniper System |
| Grenade Launcher | Towa Manufacturing Type-G | Militech "Mini-Grenade" | Tsunami Arms Type-18 |
| Rocket Launcher | Towa Manufacturing Type-R | Militech "Urban" | Militech "Hotshot" |

### 5. Exotic Weapons (overview p.95, full rules p.347-349)

Exotics are Average quality. They take no attachments and no Non-Basic ammo unless stated. Otherwise each works as its base weapon.

| Weapon | Base | Key numbers | Cost | Page |
|---|---|---|---|---|
| Air Pistol | Medium Pistol | 0 dmg; acid balls -1 SP per hit; no crits | 100 (Premium) | p.347 |
| Battleglove | (gauntlet) | 3 cyberarm option slots; 1 Action to don or doff | 1,000 (V. Expensive) | p.347 |
| Constitution Arms Hurricane | Shotgun | 5d6, ROF 2, mag 16; no Aimed; 2-Action reload; BODY 11+ | 5,000 (Luxury) | p.348 |
| Dartgun | Very Heavy Pistol | 4d6, mag 8, Non-Basic arrows only | 100 (Premium) | p.348 |
| Flamethrower | Shotgun | Heavy Weapons; incendiary shells only; burn 4/turn; no crits or Aimed | 500 (Expensive) | p.348 |
| Kendachi Mono-Three | Very Heavy Melee | Excellent, 2H, 4d6; ignores SP<11 with biometric key | 5,000 (Luxury) | p.348 |
| Malorian Arms 3516 | Very Heavy Pistol | Excellent, 5d6; built-in Smartgun Link, must be linked to fire | 10,000 (Super Luxury) | p.348 |
| Microwaver | Very Heavy Pistol | 0 dmg; DV15 Cybertech or 2 cyberware/electronics off for 1 min; battery 8 | 500 (Expensive) | p.348-349 |
| Militech "Cowboy" U-56 | Grenade Launcher | 6d6, ROF 2, mag 4, any grenade; 2-Action reload; BODY 11+ | 5,000 (Luxury) | p.349 |
| Rhinemetall EMG-86 Railgun | Assault Rifle | Heavy Weapons, 5d6, mag 4; ignores SP<11; no Autofire or Aimed; BODY 11+ | 5,000 (Luxury) | p.349 |
| Shrieker | Very Heavy Pistol | 0 dmg; DV15 Resist Torture/Drugs or Damaged Ear; deafens the user without ear protection; battery 8 | 500 (Expensive) | p.349 |
| Stun Baton | Medium Melee | 1H, 2d6; KO at 1 HP instead of killing; no crits or ablation | 100 (Premium) | p.349 |
| Stun Gun | Heavy Pistol | 3d6; KO at 1 HP; no crits or ablation; battery 8 | 100 (Premium) | p.349 |
| Tsunami Arms Helix | Assault Rifle | Autofire only, multiplier 5, mag 40, 20 rounds per attack; BODY 11+ | 5,000 (Luxury) | p.349 |

- **BODY 11+**: the weapon can only be fired by someone with BODY 11 or higher, unless it is mounted (p.348-349).
- **2-Action reload**: the reload is spread over two turns (p.348-349).
- **Battery weapons** (Microwaver, Shrieker, Stun Gun): ammo is free. A pack lasts 8 shots and recharges in 1 hour. Spare packs cost 50eb (Costly) (p.349).
- **Flamethrower**: ammo costs the same as incendiary shells (100eb per 10, p.346). Ignited targets take 4 at the end of each turn until they spend an Action to put the fire out. This replaces any weaker fire (p.348).
- **Microwaver**: a cyberlimb it shuts down acts as if dismembered but stays attached (p.349).
- **Air Pistol**: the p.95 table says Very Heavy Pistol, but the full entry on p.347 says Medium Pistol. The full entry is used.

## Weapon Attachments and Ammunition (Night Market)

Implementation reference from the core rulebook, Night Market chapter. Page numbers are book pages. Paraphrase only; numbers are exact.
Price tiers: Cheap 10, Everyday 20, Costly 50, Premium 100, Expensive 500, Very Expensive 1,000 (p342-347).

### 1. Attachment rules (p342, also p96)

| Rule | Value |
|---|---|
| Slots | Each non-Exotic ranged weapon has 3 attachment slots (p342) |
| Exotic weapons | No attachments unless stated (p347); a Tech upgrade can add a slot (p148) |
| Slot cost | 1 unless the item says "Requires 2" (Smartgun Link, both Underbarrels) |
| Same location | Attachments in the same physical spot can be combined; each pays its own slot cost (p342) |
| Duplicates | Fitting the same attachment twice does nothing (p342) |
| Magazines | Only one clip attachment (Extended or Drum) per weapon (p343) |
| Weapon type | Each attachment is bought for one weapon type and can't be moved to another type (p342) |

### 2. Attachments (p343-344)

| Attachment | Eligible | Slots | Effect | Cost | Page |
|---|---|---|---|---|---|
| Bayonet | Shoulder Arms | 1 | Also attacks as a Light Melee Weapon; not concealable | 100 | p343 |
| Drum Magazine | All but bows/crossbows | 1 | Mag = Drum column; not concealable | 500 | p343 |
| Extended Magazine | All but bows/crossbows | 1 | Mag = Extended column; not concealable | 100 | p343 |
| Grenade Launcher Underbarrel | Shoulder Arms | 2 | Two-handed alt mode as Grenade Launcher, 1 grenade; not concealable | 500 | p343 |
| Infrared Nightvision Scope | All | 1 | Obscured-target penalties (dark, smoke, fog) drop to 0; heat outlines only | 500 | p343 |
| Shotgun Underbarrel | Shoulder Arms | 2 | Two-handed alt mode as Shotgun, 2 shells; not concealable | 500 | p343 |
| Smartgun Link | All | 2 | +1 to Ranged Attacks; needs Neural Link + Interface Plugs or Subdermal Grip; 1 hour to fit | 500 | p344 |
| Sniping Scope | All | 1 | See detail to 800 m; +1 single shot or Aimed Shot at 51 m+; no stack with TeleOptics | 100 | p344 |

"All" means all non-Exotic ranged weapons. Shoulder Arms weapons here: shotgun, assault rifle, sniper rifle.

- Smartgun plugs: Interface Plugs connect while drawing into a free hand (if not already in use); a Subdermal Grip links on its own. Being disarmed just unplugs them, and plugging back in while holding it is free (p344).

#### Clip Chart (p344)

| Weapon | Standard | Extended | Drum |
|---|---|---|---|
| Medium Pistol | 12 | 18 | 36 |
| Heavy Pistol | 8 | 14 | 28 |
| Very Heavy Pistol | 8 | 14 | 28 |
| SMG | 30 | 40 | 50 |
| Heavy SMG | 40 | 50 | 60 |
| Shotgun | 4 | 8 | 16 |
| Assault Rifle | 25 | 35 | 45 |
| Sniper Rifle | 4 | 8 | 12 |
| Grenade Launcher | 2 | 4 | 6 |
| Rocket Launcher | 1 | 2 | 3 |

### 3. Ammunition rules (p344, p94, p174)

| Rule | Value |
|---|---|
| Kinds | Bullet (medium/heavy/very heavy pistol, slug, rifle), Shotgun Shell, Arrow, Grenade, Rocket; buy the kind your weapon takes (p344) |
| Purchase unit | Grenades and rockets are bought one at a time; all else in lots of 10 (p344). Listed cost is per lot |
| Basic | Bullets, shells, arrows only. Grenades and rockets have no Basic type (p94, p345) |
| Grenades | Can be thrown or fired from a Grenade Launcher (p344) |
| Arrows | Basic arrows can be recovered after firing (p174) |
| Exotic weapons | Basic ammo only unless stated (p347) |

### 4. Ammunition types (p345-347)

| Ammo | Kinds | Check on hit | Effect | Cost | Page |
|---|---|---|---|---|---|
| Basic | Bullets, Arrows, Shells | - | None | 10 | p345 |
| Armor-Piercing | All but Shells | - | Ablates armour 2 instead of 1 | 100 | p345 |
| Biotoxin | Arrows, Grenades | Resist Torture/Drugs DV15 | No damage; organic targets who fail take 3d6 to HP, no ablation | 500 | p345 |
| EMP | Grenades | Cybertech DV15 | No damage; on fail 2 cyberware/electronics are dead for 1 minute | 500 | p345 |
| Expansive | Bullets (incl. slugs), Arrows | - | Foreign Object crit also gives a rerolled second crit, no Bonus Damage | 100 | p345 |
| Flashbang | Grenades | Resist Torture/Drugs DV15 | No damage; on fail Damaged Eye + Damaged Ear for 1 minute, no Bonus Damage | 100 | p346 |
| Incendiary | Bullets, Arrows, Grenades, Shells | - | Damage through SP ignites: 2 HP at end of each turn until an Action is spent; no stacking | 100 | p346 |
| Poison | Arrows, Grenades | Resist Torture/Drugs DV13 | No damage; organic targets who fail take 2d6 to HP, no ablation | 100 | p346 |
| Rubber | Bullets (incl. slugs), Arrows | - | No crits, no ablation; a hit that would take a target above 1 HP below 0 leaves them at 1 HP | 10 | p346 |
| Sleep | Arrows, Grenades | Resist Torture/Drugs DV13 | No damage; organic targets who fail are Prone + Unconscious 1 minute (woken by damage or a touch) | 500 | p346 |
| Smart | Bullets, Arrows, Rockets | - | Needs Targeting Scope cyberware; single-shot miss by 4 or less gets one reroll at d10+10 (+LUCK) vs the same DV | 500 | p346 |
| Smoke | Grenades | - | 10 x 10 m smoke cloud for 1 minute; typical -4 to tasks through it | 50 | p347 |
| Teargas | Grenades | Resist Torture/Drugs DV13 | No damage; targets with organic eyes who fail get Damaged Eye for 1 minute, no Bonus Damage | 50 | p347 |

- Disabled cyberlimbs (EMP) act like dismembered limbs but stay attached (p345, see p187).
- Smart ammo will not fire without Targeting Scope. A target that can dodge bullets may dodge the second chance (p346).
- Default damaging grenade/rocket: rockets only come as Armor-Piercing or Smart. Grenades that deal damage are Armor-Piercing or Incendiary.

## Cyberpunk RED: Armour, Shields and Gear Reference

Implementation reference for armour, shields and general gear. Page numbers are book pages. Terse paraphrase; numbers are exact. Machine-readable version: `data/rules/armor.json and data/rules/gear.json`.

### 1. Armour (p96-97, p184-186, p350)

| Armour | SP | Penalty (REF/DEX/MOVE) | Cost | Page |
|---|---|---|---|---|
| Leathers | 4 | None | 20eb (Everyday) | p97,185,350 |
| Kevlar | 7 | None | 50eb (Costly) | p97,185,350 |
| Light Armorjack | 11 | None | 100eb (Premium) | p97,185,350 |
| Bodyweight Suit | 11 | None | 1,000eb (V. Expensive) | p97,185,350 |
| Medium Armorjack | 12 | -2 | 100eb (Premium) | p97,185,350 |
| Heavy Armorjack | 13 | -2 | 500eb (Expensive) | p97,185,350 |
| Flak | 15 | -4 | 500eb (Expensive) | p97,185,350 |
| Metalgear | 18 | -4 | 5,000eb (Luxury) | p97,185,350 |

| Rule | Value |
|---|---|
| Locations | Bought separately for head or body, each at list price (p96, p184) |
| Bodyweight Suit | One purchase covers both locations, SP11 each; repaired together; one per person; +1 Hardware-only deck slot while worn (p350) |
| Penalty | Only the single worst Armour Penalty among worn pieces applies, once, to REF, DEX and MOVE; MOVE can drop to 0 (p96, p184) |
| Stacking | SP doesn't stack: highest SP in a location counts (p96) |
| Ablation | If any damage gets through, all worn armour in that location loses 1 SP until repaired (p186) |
| Location hit | Body unless the attacker made an Aimed Shot at the head (p186) |
| Bypass | Poison and fire (and some ammo/gear) ignore armour (p186) |

No corrections: `data/rules/armor.json` matches the book for all 8 entries. It does not model per-location purchase.

### 2. Shields (p183-184, p351)

| Shield | HP | Hands | Cost | Page |
|---|---|---|---|---|
| Bulletproof Shield | 10 | 1 | 100eb (Premium) | p97, p183-184, p351 |
| Corpse (Human Shield) | Its BODY | 1 | - | p184 |

| Rule | Value |
|---|---|
| Equip / drop | One Action each; the hand can't do anything else (p183) |
| Cover | While it has HP left, the wielder counts as in cover (p183) |
| Interpose | Against an attacker you can see you may put the shield in the way: no dodge, the shield takes the whole attack; a ranged attack can still simply miss (p183) |
| Destroyed | At 0 HP it gives no cover and stays in hand until dropped with an Action; inorganic shields can be repaired (p183) |
| Human Shield | Attacker in a Grapple may equip the grappled target as an Action using the grapple hand (p184) |
| Human Shield limits | Can't block melee or head-Aimed Shots; can't dodge; takes hits as a normal target; you may attack it yourself (p184) |
| Human Shield release | Ending the Grapple is free; dropping a corpse costs an Action. A shield that dies becomes HP = its BODY (p184) |

### 3. Medical Gear

| Item | Key numbers | Cost | Page |
|---|---|---|---|
| Airhypo | - | 50eb (Costly) | p352 |
| Cryopump | 1 charge, refill 50eb; occupant in 15 HP cover; no Death Saves up to 1 week | 5,000eb (Luxury) | p353 |
| Cryotank | occupant in 30 HP cover; DV13 Medical Tech, heal x2 | 5,000eb (Luxury) | p353 |
| Medscanner | +2 first_aid, +2 paramedic | 1,000eb (V. Expensive) | p354 |
| Medtech Bag | - | 100eb (Premium) | p354 |

- **Airhypo**: Compressed-air injector: dose a willing ally as an Action, or a foe with a Melee attack instead of damage. Needs drug doses (p.357). Melee hit delivers one dose instead of damage.
- **Cryopump**: Briefcase body-bag pump: puts a dying patient in stasis, halting Death Saves for up to a week. Medtech only. Target must be willing or unconscious; one human-size target; surgery/stabilisation in stasis is safer (no number). Medtech Cryosystem Operation ranks raise charges (p.150).
- **Cryotank**: Person-sized stasis tank; occupant stays unconscious indefinitely but heals at double rate. Medtech only. Base/med-bay fixture rather than field kit. 'Medical Tech Check' is the Medtech Medicine ability, not a skills.json id.
- **Medscanner**: Diagnostic scanner with probes; +2 First Aid and Paramedic for non-surgical emergencies. Doesn't stack.
- **Medtech Bag**: Full field medical kit: staplers, spray skin, scalpels and the rest. No listed bonus. tool_for is an interpretation: absence could apply p.130's -2 no-tools modifier.

### 4. Tools

| Item | Key numbers | Cost | Page |
|---|---|---|---|
| Duct Tape | - | 20eb (Everyday) | p353 |
| Grapple Gun | 30 m, line 10 HP | 100eb (Premium) | p181,353 |
| Tech Bag | - | 500eb (Expensive) | p354 |
| Techscanner | +2 basic_tech, +2 cybertech, +2 land_vehicle_tech, +2 sea_vehicle_tech, +2 air_vehicle_tech, +2 electronics_security_tech, +2 weaponstech | 1,000eb (V. Expensive) | p355 |
| Techtool | - | 100eb (Premium) | p101,355 |
| Shovel or Axe | - | 50eb (Costly) | p339 |

- **Duct Tape**: Tape in many colours, including a self-glowing kind used to mark tunnels and caches. Narrative; could mark routes or improvise gags/restraints.
- **Grapple Gun**: Rocket grapple fixing to thick cover within 30 m; climb the line at no movement penalty. Not a weapon. Line holds only 2x the user's weight; hand is occupied; can't be used to Grab. Auto-succeeds the fall-save (p.181, p.215).
- **Tech Bag**: Repair kit: techtool, wire and tape, fasteners, plug-in modules, heat torch, prybars, hammer. No listed bonus; tool_for is an interpretation (avoids p.130 -2 no-tools).
- **Techscanner**: Diagnostic scanner for machines and electronics; +2 to seven TECH repair skills. Doesn't stack.
- **Techtool**: All-in-one multitool for electronics and machine repair. p.355 text duplicates the Tech Bag entry (book error); p.101 calls it a multitool. tool_for is an interpretation.
- **Shovel or Axe**: Digging or chopping tool; appears only in the Night Market survival column, with no rules text. No description; could double as an improvised melee weapon (GM call).

### 5. Electronics

| Item | Key numbers | Cost | Page |
|---|---|---|---|
| Agent | +2 library_search, +2 wardrobe_style | 100eb (Premium) | p352 |
| Audio Recorder | 24 h per chip | 100eb (Premium) | p352 |
| Braindance Viewer | - | 1,000eb (V. Expensive) | p352 |
| Chemical Analyzer | - | 1,000eb (V. Expensive) | p352 |
| Computer | - | 50eb (Costly) | p352 |
| Cyberdeck (Poor Quality) | 5 slots | 100eb (Premium) | p353 |
| Cyberdeck (Standard Quality) | 7 slots | 500eb (Expensive) | p353 |
| Cyberdeck (Excellent Quality) | 9 slots | 1,000eb (V. Expensive) | p353 |
| Memory Chips | - | 10eb (Cheap) | p354 |
| Smart Glasses | 2 eye-option slots, paired | 500eb (Expensive) | p354 |
| Video Camera | 12 h per chip | 100eb (Premium) | p355 |
| Virtuality Goggles | - | 100eb (Premium) | p355 |

- **Agent**: Learning-AI smartphone that runs your calls, schedule, shopping and navigation; nearly everyone carries one. Wardrobe & Style +2 only while wearing the outfits it picks (seasonal). Phone/records/data-pool roles are narrative; could gate in-mission comms.
- **Audio Recorder**: Records about 24 hours of sound onto one memory chip. Narrative; could serve evidence/blackmail objectives.
- **Braindance Viewer**: Rig for playing braindance recordings: relive someone else's full sensory and emotional experience. Narrative; could tie to braindance-recovery gig objectives or downtime.
- **Chemical Analyzer**: Identifies a substance's exact composition as an Action against a large sample database. Could identify drugs/poisons/loot or reveal a contaminated-supply objective.
- **Computer**: Laptop or desktop for writing and browsing the Data Pool. Narrative; base-management flavour.
- **Cyberdeck (Poor Quality)**: Modular netrunning platform with 5 slots for Programs and Hardware. Netrunning per p.195; the repo's net code owns the deck model.
- **Cyberdeck (Standard Quality)**: Modular netrunning platform with 7 slots for Programs and Hardware. Netrunning per p.195; the repo's net code owns the deck model.
- **Cyberdeck (Excellent Quality)**: Modular netrunning platform with 9 slots for Programs and Hardware. Netrunning per p.195; the repo's net code owns the deck model.
- **Memory Chips**: Thin plastic data wafers of assorted capacity. Narrative; datashard/loot objectives.
- **Smart Glasses**: Wearable frames with two Cybereye option slots, counted as paired; one pair worn at a time. Lets non-chromed crew use eye options (low light etc.) — integrate with cyberware slice.
- **Video Camera**: Handheld recorder storing about 12 hours of video and sound per memory chip. Media flavour; could serve 'get footage' objectives.
- **Virtuality Goggles**: Headset overlaying cyberspace imagery on your real view; recommended for netrunners. Netrunning per p.195; also used with interface plugs to visualise machine controls.

### 6. Security Gear

| Item | Key numbers | Cost | Page |
|---|---|---|---|
| Bug Detector | 2 m | 500eb (Expensive) | p352 |
| Handcuffs | broken by BODY >10 | 50eb (Costly) | p353 |
| Homing Tracer | 1 mile | 500eb (Expensive) | p354 |
| Lock Picking Set | - | 20eb (Everyday) | p354 |
| Radar Detector | 100 m | 500eb (Expensive) | p354 |

- **Bug Detector**: Beeps when within 2 m of a tap, bug or other listening device. Could reveal hidden bugs/surveillance objects on the map within 1 square.
- **Handcuffs**: Basic restraints; anyone with BODY above 10 snaps them easily. Could support capture/extraction objectives; applying them has no stated action cost.
- **Homing Tracer**: Receiver tracking a linked button-sized tag up to a mile away; one tag included. Spare tags 50eb. Could drive tail/track-the-target gig objectives.
- **Lock Picking Set**: Pouch of tools for opening mechanical locks. No listed bonus; without tools a Pick Lock check takes the -2 'no right tools' modifier (p.130).
- **Radar Detector**: Beeps when an active radar beam is within 100 m. Could warn of radar-based security sensors.

### 7. Comms

| Item | Key numbers | Cost | Page |
|---|---|---|---|
| Disposable Cell Phone | - | 50eb (Costly) | p353 |
| Radio Communicator | 1 mile | 100eb (Premium) | p354 |
| Radio Scanner/Music Player | 1 mile | 50eb (Costly) | p354 |
| Scrambler/Descrambler | - | 500eb (Expensive) | p354 |

- **Disposable Cell Phone**: Cheap throwaway phone for people who don't want to be traced. Narrative; could reduce trace/heat on comms-dependent gigs.
- **Radio Communicator**: Earpiece radio with a one-mile range. Could gate squad coordination (e.g. sharing spotted enemies) on a mission.
- **Radio Scanner/Music Player**: Music player that also scans and listens in on active radio bands within a mile. Scrambled channels need a descrambler. Could reveal enemy comms/alarm state.
- **Scrambler/Descrambler**: Encrypts your outgoing comms; matching descrambler included. Could block enemy radio interception (radio_scanner).

### 8. Survival Gear

| Item | Key numbers | Cost | Page |
|---|---|---|---|
| Anti-Smog Breathing Mask | immune: inhaled | 20eb (Everyday) | p352 |
| Auto Level Dampening Ear Protectors | immune: loud_noise | 1,000eb (V. Expensive) | p352 |
| Binoculars | x2-x3 | 50eb (Costly) | p352 |
| Flashlight | 100 m beam, 10 hours | 20eb (Everyday) | p353 |
| Food Stick | - | 10eb (Cheap) | p353 |
| Glow Stick | 4 m radius, 10 hours | 10eb (Cheap) | p353 |
| Inflatable Bed & Sleep-bag | - | 20eb (Everyday) | p354 |
| Kibble Pack | - | 10eb (Cheap) | p354 |
| MRE | - | 10eb (Cheap) | p354 |
| Road Flare | 100 m radius, 1 hour | 10eb (Cheap) | p354 |
| Rope (60m/yds) | 60 m, 360 kg | 20eb (Everyday) | p354 |
| Tent & Camping Equipment | - | 50eb (Costly) | p355 |
| Radiation Suit | immune: radiation | 1,000eb (V. Expensive) | p101,339 |

- **Anti-Smog Breathing Mask**: Filter mask; wearer ignores toxic gases, fumes and other inhaled hazards. Teargas (p.347) hits meat eyes, not lungs, so RAW the mask does not stop it; smoke still obscures vision.
- **Auto Level Dampening Ear Protectors**: Compact earwear; wearer is immune to deafening noise effects such as flashbangs. Blocks the Damaged Ear half of a Flashbang (p.346) and the Shrieker's self-inflicted Damaged Ear (p.349); Damaged Eye still applies.
- **Binoculars**: Handheld optics magnifying the view two to three times. Book gives no rules number; game could cut long-range observation/Perception penalties while used.
- **Flashlight**: Rechargeable torch with a 100 m beam lasting about 10 hours a charge. Could cancel darkness penalties (p.130) along a beam; also reveals the holder.
- **Food Stick**: Grainy dried ration bar; one awful meal. Downtime/upkeep flavour.
- **Glow Stick**: Single-use light tube lighting a 4 m area for up to 10 hours. Could be thrown to light a 2-square area.
- **Inflatable Bed & Sleep-bag**: Self-inflating mattress and thin sleeping bag folding into a small square pack. Downtime flavour.
- **Kibble Pack**: Foil pack of pet-food-like cereal; one numbered meal. Downtime/upkeep flavour.
- **MRE**: Self-heating meal bag; add water, pull tab, hot meal in two minutes. Downtime/upkeep flavour.
- **Road Flare**: Single-use coloured flare lighting a 100 m area for an hour. Could be thrown to light a large zone.
- **Rope (60m/yds)**: 60 m nylon line rated to about 360 kg. Climbing/rappel flavour.
- **Tent & Camping Equipment**: One-person tube tent, rechargeable self-heating pot and a cheap spork. Downtime flavour.
- **Radiation Suit**: Protective suit against radiation. Listed in the starting gear table and Night Market, not the Master Gear List. High-level radiation (p.181) treats you as Mildly On Fire each turn; the suit negates it.

### 9. Misc Gear

| Item | Key numbers | Cost | Page |
|---|---|---|---|
| Carryall | - | 20eb (Everyday) | p352 |
| Drum Synthesizer | - | 500eb (Expensive) | p353 |
| Electric Guitar or another Instrument | - | 500eb (Expensive) | p353 |
| Glow Paint | - | 20eb (Everyday) | p353 |
| Linear Frame ß (Beta) | BODY->14 | 5,000eb (Luxury) | p354 |
| Linear Frame ∑ (Sigma) | BODY->12 | 1,000eb (V. Expensive) | p354 |
| Personal CarePak | - | 20eb (Everyday) | p354 |
| Pocket Amplifier | - | 50eb (Costly) | p354 |
| Vial of Biotoxin | DV15 Resist Torture/Drugs or 3d6 to HP, 30 min | 500eb (Expensive) | p355 |
| Vial of Poison | DV13 Resist Torture/Drugs or 2d6 to HP, 30 min | 100eb (Premium) | p355 |

- **Carryall**: Ripstop nylon bag, from messenger size up to a near body-sized duffel. No rules; could add inventory/loot capacity.
- **Drum Synthesizer**: Linked pads and processor imitating nearly any drum; needs an amplifier. Rockerboy performance flavour.
- **Electric Guitar or another Instrument**: Any instrument; electronic ones need an amplifier to be heard. Rockerboy performance flavour; electric versions need pocket_amplifier.
- **Glow Paint**: Spray can of glow-in-the-dark paint for markers, art and tags. Narrative; route marking or gang tagging.
- **Linear Frame ß (Beta)**: Powered exoskeleton raising BODY to 14 while plugged in; HP and Death Save unchanged. Raises BODY to 14 (won't exceed 14). Unlocks BODY 11+ heavy weapons (p.349), thick-cover moving (p.182).
- **Linear Frame ∑ (Sigma)**: Powered exoskeleton raising BODY to 12 while plugged in; HP and Death Save unchanged. Book contradicts itself on plugs (text says two, bullet says one); listed as 1. Won't raise BODY past 12.
- **Personal CarePak**: Toiletry kit: loaded toothbrush, wipes, depilatory, comb. Narrative.
- **Pocket Amplifier**: Book-sized rechargeable amp carrying sound 100 m for 6 hours; two instruments. Performance flavour; could make a noise distraction.
- **Vial of Biotoxin**: Coat a light melee blade as an Action; for 30 minutes hits force DV15 resist or 3d6 straight to HP. Armour neither reduces nor is ablated.
- **Vial of Poison**: Coat a light melee blade as an Action; for 30 minutes hits force DV13 resist or 2d6 straight to HP. Armour neither reduces nor is ablated.

### 10. Fashion (p102, p356)

Clothing gives no SP. Prices are per piece.

| Style | Bottoms | Top | Jacket | Footwear | Jewelry | Mirrorshades | Glasses | Contact Lenses | Hats |
|---|---|---|---|---|---|---|---|---|---|
| Bag Lady Chic | 20 | 10 | 20 | 20 | 20 | 20 | 10 | 10 | 10 |
| Gang Colors | 50 | 20 | 50 | 20 | 50 | 20 | 20 | 10 | 10 |
| Generic Chic | 50 | 20 | 50 | 20 | 50 | 20 | 20 | 10 | 10 |
| Bohemian | 50 | 20 | 50 | 50 | 100 | 50 | 50 | 10 | 10 |
| Leisurewear | 100 | 20 | 100 | 50 | 100 | 50 | 50 | 20 | 50 |
| Nomad Leathers | 100 | 20 | 100 | 100 | 100 | 50 | 50 | 20 | 100 |
| Asia Pop | 100 | 20 | 100 | 100 | 100 | 100 | 100 | 100 | 100 |
| Urban Flash | 100 | 20 | 100 | 100 | 100 | 100 | 100 | 100 | 100 |
| Businesswear | 500 | 50 | 500 | 500 | 5,000 | 500 | 500 | 100 | 500 |
| High Fashion | 1,000 | 500 | 1,000 | 5,000 | 50,000 | 1,000 | 1,000 | 1,000 | 5,000 |

### 11. Notes

- data/rules/armor.json: all 8 armours match the book (sp, penalty magnitude, cost) on p.97, p.185 and p.350. No value corrections.
- Structural gap: book armour is bought per location (head OR body, each at full list price), except Bodyweight Suit which is one purchase covering both (p.96, p.350). armor.json has no location field; recruit.gd puts one id on both slots, and the shop sells one 'piece' at one price. Flag for integration.
- armor.json has no shield entries; bulletproof_shield (10 HP, 100eb, one hand) is new here. The cyberarm-mounted shield (p.115/p.365) belongs to the cyberware slice.
- Book inconsistency (outside slice, FYI): p.183 cover examples list Metal Door as Thin Steel 20 HP while the p.182 table says Thin Steel 25 HP. armor.json uses 25.
- Techtool description on p.355 is a copy-paste of Tech Bag; p.101 gives the real gist (all-in-one multitool). Paraphrased from p.101.
- Linear Frame Sigma: p.354 says both two and one installations of Interface Plugs; JSON uses 1 (the bullet). Beta needs 2.
- Radiation Suit (1,000eb, p.101/p.339) and Shovel or Axe (50eb, p.339) are not on the Master Gear List; included anyway.
- fx.tool_for on medtech_bag, tech_bag, techtool, lock_picking_set is an interpretation (book gives no bonus, only p.130's -2 'no right tools'). Tag RULES-UNVERIFIED or HOUSE-RULE when adopted.
- Agent Wardrobe & Style +2 is conditional (only when wearing what it picks); model as opt-in or ignore.
- Fashion styles (10) included as category misc with per-piece piece_costs/piece_tiers instead of a single cost (cost null). Read from p.102 layout extraction; p.356 is the same table.
- cost_tier uses the book names; 'Very Expensive' written in full. human_shield and fashion have cost null.
- night_market = the p.338-339 Night Market generator column the item appears in (personal_electronics, survival_gear, food_drugs, weapons_armor, clothing_fashionware); absent = not in that table. Armour only appears there as 'Armor of <=100eb / 500eb / 1,000eb' buckets.
- Skipped: Street Drugs (p.357-358; drug slice, not gear), Night Market food items (canned goods, live chickens etc., p.338-339; pure flavour, no rules), cyberdeck hardware/programs (p.368+), home defences (p.372).
- cryotank's check uses skill id 'medical_tech' which isn't in skills.json: it is the Medtech Role Ability Medicine (Medical Tech specialty).

## Cyberpunk RED: Drugs, Pharmaceuticals and Fashion Reference

Implementation reference extracted from the core rulebook. Page numbers are book pages. Terse paraphrase; numbers and tables are exact.
Machine-readable copy: `drugs_fashion.json` (same slice).

### 1. Street Drugs (p227-229, repeated p357-358)

#### Using street drugs (p227)

| Rule | Value |
|---|---|
| Dosing a willing target | An Action with an Airhypo, one dose (p227) |
| Dosing an unwilling target | One Melee Weapon Attack with an Action; a hit gives the dose and deals no damage (p227) |
| Primary Effect | Applies automatically on dosing, lasts the listed duration (p227) |
| Addiction check | When the Primary Effect ends: WILL + Resist Torture/Drugs + 1d10 vs the Secondary Effect DV (p227) |
| Failed check | Secondary Effect applies; it is permanent and habit forming until Addiction Therapy (p227) |
| Extra doses | Each extra dose extends the Primary Effect by its full duration (p227) |
| Law | NCPD rarely cares about drugs unless looking for an excuse (p357) |

#### Drug table (p357)

| Drug | Primary Effect | Duration | Secondary DV | Addicted | Cost/dose | Page |
|---|---|---|---|---|---|---|
| Black Lace | Ignore Seriously Wounded; take 2d6 Humanity Loss, refunded if the check succeeds | 24 h | 17 | Loss kept; -2 REF except while high | 50eb (Costly) | p357 |
| Blue Glass | GM-called "flash outs": lose your Action that Turn | 4 h | 15 | Flash out off the drug (about hourly); dose now makes you immune to flash outs | 20eb (Everyday) | p357 |
| Boost | +2 INT, may exceed 8 | 24 h | 17 | -2 INT | 50eb (Costly) | p357 |
| Smash | +2 Dance, Contortionist, Conversation, Human Perception, Persuasion, Acting | 4 h | 15 | -2 to the same six skills; cravings | 10eb (Cheap) | p357-358 |
| Synthcoke | +1 REF, may exceed 8; paranoia | 4 h | 15 | -2 REF except while high; cravings | 20eb (Everyday) | p358 |

Smash comes as a yellow, foamy canned drink (p357). Paranoia, cravings and the timing of flash outs are GM-prompted roleplay.

#### Addiction Therapy (p229-230)

| Therapy | Effect | Medical Tech DV | Cost | Page |
|---|---|---|---|---|
| Addiction | Frees the patient of one addiction. For 1 year afterward, they auto-fail that drug's Secondary Effect check | DV15, materials 500eb (Expensive) | 1,000eb (V. Expensive) | p230 |

- Takes one full week during which the Medtech and the patient do nothing else. On a failure the week and the materials are lost (p229).
- Medtechs can't treat themselves. Materials come only from Biotechnica. A hospital stay overnight costs 100eb per night (p229).

### 2. Medtech Pharmaceuticals (p149-150)

| Rule | Value |
|---|---|
| Access | Each Medical Tech (Pharmaceuticals) point unlocks one pharmaceutical of the player's choice; the specialty caps at 5 points (p149) |
| Medical Tech Skill | Pharmaceuticals points + Cryosystem Operation points (p149) |
| Synthesis | DV13 Medical Tech check: 200eb of materials makes doses equal to Medical Tech Skill in 1 hour; materials are lost on a failure (p149) |
| Street drugs | Can't be synthesized this way (p149) |
| Giving a dose | An Action; an unwilling target takes an Airhypo Melee Weapon Attack, and a hit doses instead of dealing damage (p150) |
| Who | Only Medtechs can administer them correctly (p150) |

| Pharmaceutical | Effect | Limit | Page |
|---|---|---|---|
| Antibiotic | A target already healing naturally heals +2 HP per day for a week | One course at a time | p150 |
| Rapidetox | Immediately purges any drug, poison or intoxicant | — | p150 |
| Speedheal | Instantly heals HP equal to the target's BODY + WILL; no effect when Mortally Wounded | Once per day | p150 |
| Stim | Ignore all Seriously Wounded penalties for 1 hour | Once per day | p150 |
| Surge | Function unimpaired without sleep for 24 hours | Once per week | p150 |

No shop price is listed. The effective cost per dose is 200eb divided by Medical Tech Skill (20 to 200eb).

### 3. Fashion (p356; same table p102; styles p328)

Prices in eb for each piece. Column "Lenses" is Contact Lenses.

| Style | Says about you | Bottoms | Top | Jacket | Footwear | Jewelry | Mirrorshades | Glasses | Lenses | Hat |
|---|---|---|---|---|---|---|---|---|---|---|
| Bag Lady Chic | Homeless, Ragged, Vagrant | 20 | 10 | 20 | 20 | 20 | 20 | 10 | 10 | 10 |
| Gang Colors | Dangerous, Violent, Rebellious | 50 | 20 | 50 | 20 | 50 | 20 | 20 | 10 | 10 |
| Generic Chic | Standard, Colorful, Modular | 50 | 20 | 50 | 20 | 50 | 20 | 20 | 10 | 10 |
| Bohemian | Folksy, Retro, Free-Spirited | 50 | 20 | 50 | 50 | 100 | 50 | 50 | 10 | 10 |
| Leisurewear | Comfort, Agility, Athleticism | 100 | 20 | 100 | 50 | 100 | 50 | 50 | 20 | 50 |
| Nomad Leathers | Western, Rugged, Tribal | 100 | 20 | 100 | 100 | 100 | 50 | 50 | 20 | 100 |
| Asia Pop | Bright, Costume-like, Youthful | 100 | 20 | 100 | 100 | 100 | 100 | 100 | 100 | 100 |
| Urban Flash | Flashy, Technological, Streetwear | 100 | 20 | 100 | 100 | 100 | 100 | 100 | 100 | 100 |
| Businesswear | Leadership, Presence, Authority | 500 | 50 | 500 | 500 | 5,000 | 500 | 500 | 100 | 500 |
| High Fashion | Exclusive, Designer, Couture | 1,000 | 500 | 1,000 | 5,000 | 50,000 | 1,000 | 1,000 | 1,000 | 5,000 |

Price tiers: 10 Cheap, 20 Everyday, 50 Costly, 100 Premium, 500 Expensive, 1,000 V. Expensive, 5,000+ Luxury.

- Clothing is cosmetic: the core rules give it no mechanical effect. The style signals the image you project on The Street (p328).
- 2045 clothes can report damage to your Agent, adjust to temperature, and change color or show 2D images (p327). This is flavor only.
- Complete Package characters get an extra 800eb to spend only on Fashion or Fashionware. Any unspent amount is lost (p105).
- Wardrobe & Style (COOL) bonuses come from other gear, not from clothing. An Agent gives +2 if you wear the outfits it suggests (p352). Three or more Light Tattoo installs give +2 (p358). The Chrome cyberlimb option gives +2 (p367).
