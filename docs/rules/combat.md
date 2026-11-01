# Cyberpunk RED: Combat and Skill Rules Reference

Implementation reference extracted from the core rulebook. Page numbers are book pages. Terse paraphrase; numbers and tables are exact.
Units: 1 m/yd = 0.5 grid square (1 square = 2 m/yds) (p126).

## 1. Skill Checks (p128-130)

| Rule | Value |
|---|---|
| Check | STAT + Skill + 1d10 vs DV (p129) |
| Opposed check | Attacker STAT+Skill+1d10 vs Defender STAT+Skill+1d10; the tie goes to the Defender (p129) |
| Skill Base | STAT + Skill combined (p130) |
| No Skill | Use STAT + 1d10 only (p130) |
| Critical Success | Natural 10: roll another 1d10 and add it. No chain on a second 10 (p130) |
| Critical Failure | Natural 1: roll another 1d10 and subtract it. No chain on a second 1 (p130) |
| Modifiers | Subtract the Modifier Value from the roll; cumulative (p130) |
| Retry | Only if chances improved (more time, better tool, or a Complementary Check) (p130) |
| Complementary Skill | GM discretion: +1 to one subsequent related check, once, no stacking (p130) |
| Extra Time | Taking 4x longer gives a single +1 (p130) |
| LUCK | Before rolling, spend LUCK Pool points for +1 each. The Pool equals the LUCK STAT and refills each session (p130) |
| Skill task length | An Action covers a task of 3 s max. Longer tasks take one Action per Turn at 3 s per Turn, with the roll made at the end (p128) |

### Difficulty Values (p129)

| Difficulty | DV |
|---|---|
| Simple | 9 |
| Everyday | 13 |
| Difficult | 15 |
| Professional | 17 |
| Heroic | 21 |
| Incredible | 24 |
| Legendary | 29 |

### Example Negative Modifiers (p130)

| Condition | Mod |
|---|---|
| Night or low light | -1 |
| Never done this before | -1 |
| Complex task | -2 |
| No right tools or parts | -2 |
| Slept uncomfortably | -2 |
| Extreme stress | -2 |
| Exhausted | -4 |
| Extremely drunk or sedated | -4 |
| Performing task secretly | -4 |
| Task obscured by smoke or darkness | -4 |

Positive modifiers come from gear, cyberware, Role Abilities and drugs (p130).

AMBIGUITY (p130): the rules do not say whether a Critical Success or Failure overrides a DV outcome. The text says a high DV can still beat a Critical Success and a skilled character can succeed after a Critical Failure, so treat the crit as only a roll adjustment.

## 2. Stats and Derived Stats (p72-80)

Ten STATs: INT, WILL, COOL, EMP, TECH, REF, LUCK, BODY, DEX, MOVE (p72). Generally 1-8, can go higher. Complete Package build: 62 points, STAT range 2-8 (p78).

| Derived | Formula | Page |
|---|---|---|
| Hit Points | 10 + 5 x ceil((BODY + WILL) / 2) | p79 |
| Seriously Wounded threshold | ceil(HP / 2) | p79 |
| Death Save | = BODY | p79 |
| Humanity | EMP x 10 | p80 |
| EMP (effective) | tens digit of current Humanity; drops each time the tens place drops (44 HUM = EMP 4; 39 = EMP 3) | p80 |
| Humanity < 0 | Cyberpsychosis | p80 |
| Initiative | REF + 1d10 | p168 |
| Move Action distance | MOVE x 2 m/yds, or MOVE squares (diagonals allowed) | p169 |
| Evasion / dodge | DEX + Evasion + 1d10 | p172, p176 |
| Dodge eligibility (ranged) | Defender needs REF 8+ | p172 |
| Melee attack | DEX + weapon Skill + 1d10 | p176 |
| Ranged attack | REF + weapon Skill + 1d10 | p172 |
| Grapple/Grab | DEX + Brawling + 1d10 (both sides) | p177 |
| Breath hold | BODY minutes | p180 |
| Natural healing | BODY HP per full resting day | p223 |
| Carrying two-handed melee in one hand | BODY 8+ | p176 |

Weapon Skills by type (p94, p171): Handgun (pistols, SMGs), Shoulder Arms (shotgun, assault rifle, sniper), Archery (bows), Heavy Weapons (grenade or rocket launcher), Melee Weapon (melee), Brawling (unarmed), Martial Arts, Autofire (autofire and suppressive).
Melee weapons are generally DEX-linked, ranged weapons REF-linked (p91, p93).

## 3. Turn Structure and Actions (p126-127, p168-169)

- Combat Time: one Turn is about 3 s. A Round is every entity taking one Turn (p168).
- Initiative = REF + 1d10. Order descending. Ties reroll. The queue repeats each Round (p168).
- Turn = 1 Move Action + 1 Action (p168).
- Run: an extra Move Action, only if a Move Action was already taken this Turn (p169).
- The Action can be taken in the middle of a Move Action ("Splitting") (p169).
- Grid: cannot stop between squares (p169).

| Action | Effect | Page |
|---|---|---|
| Move Action | MOVE x 2 m/yds (MOVE squares) | p168 |
| Attack | Melee or Ranged attack | p168 |
| Choke | Choke a Grabbed opponent | p168 |
| Equip/Drop Shield | Costs an Action | p168 |
| Get into Vehicle | Enter an unlocked vehicle or one you hold the key for | p168 |
| Get Up | Stand from Prone. While Prone you cannot use a Move Action until you Get Up | p168 |
| Grab | Grab an opponent, or take an object they hold | p168 |
| Hold Action | Hold an Action until a declared event or queue number; state the Action and target | p169 |
| Human Shield | Equip a Grabbed opponent as shield | p169 |
| Reload | Fully reload one ammo type; no mixing in a magazine | p169, p170 |
| Run | Extra Move Action | p169 |
| Start a Vehicle | Gain its MOVE and jump to top of Initiative Queue | p169 |
| Stabilize | See section 9 | p169 |
| Throw | Throw a grabbed opponent or an object | p169 |
| Use NET Actions | Netrunning (out of scope here) | p169 |
| Use an Object | Anything not needing a Skill; stowing a weapon counts, drawing an easy weapon into a free hand does not | p169 |
| Use a Skill | Quick Skill task | p169 |
| Vehicle Maneuver | Focus on a dangerous driving maneuver | p169 |

- Drawing an easily accessible weapon into a free hand is not an Action. Dropping a held weapon (not a shield) is not an Action. Stowing is an Action (p169, p170).
- Swimming, climbing, and jumping with a running start cost 2 m/yds per m/yd moved. A standing jump covers half the running-jump distance (p169).
- Prone: no Move Action until Get Up (p169).

### ROF and splitting (p169)

- 2 ROF attacks (melee, medium pistol, heavy pistol): the two attacks can be split across a Move Action (move, shoot, move, shoot, move). They can also be split between two different 2 ROF weapons.
- 1 ROF attacks take the whole Attack Action, but movement can still be split around them.
- Never more than 2 Attack Checks per Action. Cannot attack with two 1 ROF weapons in the same Action, even dual wielding.

## 4. Weapons (p92-95, p171, p173-176)

### Melee weapons (p92, p175)

| Type | Examples | Damage | ROF | Concealable | Cost |
|---|---|---|---|---|---|
| Light | Combat Knife, Tomahawk | 1d6 | 2 | Yes | 50eb |
| Medium | Baseball Bat, Crowbar, Machete | 2d6 | 2 | No | 50eb |
| Heavy | Lead Pipe, Sword, Spiked Bat | 3d6 | 2 | No | 100eb |
| Very Heavy | Chainsaw, Sledgehammer, Helicopter Blades, Naginata | 4d6 | 1 | No | 500eb |

- Hands required vary by weapon (p92). Reach is 2 m/yds (p176).
- Melee damage ignores half the Defender's armor SP, rounded up (p176).
- Thrown melee weapons deal stated damage but do not halve SP (p177).

### Ranged weapons (p94, p171)

Column order resolved from the garbled PDF layout (see AMBIGUITY below).

| Weapon | Skill | Dmg | Mag (ammo) | ROF | Hands | Conceal | Cost | Alt modes |
|---|---|---|---|---|---|---|---|---|
| Medium Pistol | Handgun | 2d6 | 12 | 2 | 1 | Yes | 50eb | none |
| Heavy Pistol | Handgun | 3d6 | 8 | 2 | 1 | Yes | 100eb | none |
| Very Heavy Pistol | Handgun | 4d6 | 8 | 1 | 1 | No | 100eb | none |
| SMG | Handgun | 2d6 | 30 | 1 | 1 | Yes | 100eb | Autofire (3), Suppressive |
| Heavy SMG | Handgun | 3d6 | 40 | 1 | 1 | No | 100eb | Autofire (3), Suppressive |
| Shotgun | Shoulder Arms | 5d6 | 4 (slug) | 1 | 2 | No | 500eb | Shotgun Shell |
| Assault Rifle | Shoulder Arms | 5d6 | 25 | 1 | 2 | No | 500eb | Autofire (4), Suppressive |
| Sniper Rifle | Shoulder Arms | 5d6 | 4 | 1 | 2 | No | 500eb | none |
| Bow / Crossbow | Archery | 4d6 | N/A (arrows; no Reload needed) | 1 | 2 | No | 100eb | Arrows |
| Grenade Launcher | Heavy Weapons | 6d6 | 2 | 1 | 2 | No | 500eb | Explosive |
| Rocket Launcher | Heavy Weapons | 8d6 | 1 | 1 | 2 | No | 500eb | Explosive |

Verified against printed p94: all values above match, including VH Pistol not concealable and Bow magazine N/A.

- Basic ammunition: 10eb per 10 units (p94). Bullets (Pistol, Slug, Rifle), Shotgun Shell, Arrow. Grenades and rockets have no Basic type (p94).
- Arrows: no Reload action. Basic Arrows are always retrievable (p174).
- Non-basic ammunition (Incendiary, Armor-Piercing, Poisoned, etc.): details on p344, not covered here (p96).
- Attachments: each non-Exotic ranged weapon has 3 attachment slots, specifics on p342 (p96).
- Weapon quality: see p342 (not covered here; Exotic weapons are always Average quality) (p95).

### Exotic weapons, brief (p95)

All Exotic weapons are Average quality and incompatible with attachments and non-Basic ammo unless stated (p95).

| Weapon | Summary | Cost |
|---|---|---|
| Air Pistol | VH Pistol firing paint (and acid) balls | 100eb |
| Battleglove | Heavy gauntlet, 3 Cyberarm option slots | 1,000eb |
| Constitution Arms Hurricane | Shotgun, 2 ROF, needs BODY 11+ | 5,000eb |
| Dartgun | VH Pistol firing Non-Basic Arrows | 100eb |
| Flamethrower | Shotgun with incendiary shells; Heavy Weapons Skill | 500eb |
| Kendachi Mono-Three | 2-handed Very Heavy Melee; ignores armor lower than SP11 | 5,000eb |
| Malorian Arms 3516 | Excellent-quality VH Pistol, 5d6 | 10,000eb |
| Microwaver | VH Pistol; shuts down cyberware and electronics | 500eb |
| Militech Cowboy U-56 | Grenade Launcher, 2 ROF, needs BODY 11+ | 5,000eb |
| Rhinemetall EMG-86 Railgun | Assault Rifle ignoring armor lower than SP11; Heavy Weapons; BODY 11+ | 5,000eb |
| Shrieker | VH Pistol; causes Damaged Ear Critical Injury | 500eb |
| Stun Baton | Less-lethal Medium Melee | 100eb |
| Stun Gun | Less-lethal Heavy Pistol | 100eb |
| Tsunami Arms Helix | Assault Rifle, Autofire only, higher multiplier; BODY 11+ | 5,000eb |

Full exotic rules are on p347 (not read).

## 5. Armor and Shields (p96-97, p183-185)

| Armor | SP | Penalty (min 0) | Cost |
|---|---|---|---|
| Leathers | 4 | none | 20eb |
| Kevlar | 7 | none | 50eb |
| Light Armorjack | 11 | none | 100eb |
| Bodyweight Suit | 11 | none | 1,000eb |
| Medium Armorjack | 12 | -2 REF, DEX, MOVE | 100eb |
| Heavy Armorjack | 13 | -2 REF, DEX, MOVE | 500eb |
| Flak | 15 | -4 REF, DEX, MOVE | 500eb |
| Metalgear | 18 | -4 REF, DEX, MOVE | 5,000eb |
| Bulletproof Shield | 10 HP (reduced by damage) | none, always occupies one arm | 100eb |

(p97, p185)

- Armor is bought separately for head and body locations (p96, p184).
- Armor penalty: the single worst penalty among worn armor applies once (not per piece). MOVE minimum 0, so you can become immobile (p96, p184).
- SP does not stack. Only the highest SP in a location counts. All worn armor in a location ablates simultaneously (p96, p184).
- Starting kit: Light Armorjack SP11 for body and head (p98).

### Shields (p183-184)

- Equip and drop each take an Action. The shield hand cannot be used for anything else (p183).
- While wielding a shield with HP remaining you are in cover. You may interpose it against an attack from a target you can see. If you do, you cannot dodge, though a ranged attack can still miss. The shield takes the entire attack as HP damage (p183).
- At 0 HP the shield is destroyed (repairable if inorganic), is no longer cover, and stays equipped until you spend an Action to drop it (p183).
- Corpse shield: HP = the corpse's BODY in life (p184).
- Human Shield (p184):
  - Requires being the Attacker in a Grapple, no other shield, and uses the grappling hand; the Action "equips" them.
  - Counts as cover.
  - Cannot block melee attacks or Aimed Shots at your head.
  - The shield cannot dodge ranged attacks, even at REF 8+.
  - A shot at them damages them normally.
  - You can attack your own Human Shield.
  - On death they become a corpse shield with HP = BODY.
  - Releasing a live shield means ending the Grapple, which is free. Dropping a corpse shield costs an Action.

## 6. Ranged Combat (p170-174)

Resolution (p172):
- Attacker: REF + weapon Skill + 1d10 vs DV from the range table, or vs the Defender's DEX + Evasion + 1d10 if the Defender has REF 8+ and chooses to dodge.
- Defender wins ties. On a hit, roll weapon damage; armor reduces it (see section 8).
- Example (p170): DV15 shot at 24 m with an Assault Rifle.

### Single Shot DVs by Range (p173)

| Weapon | 0-6 | 7-12 | 13-25 | 26-50 | 51-100 | 101-200 | 201-400 | 401-800 |
|---|---|---|---|---|---|---|---|---|
| Pistol | 13 | 15 | 20 | 25 | 30 | 30 | N/A | N/A |
| SMG | 15 | 13 | 15 | 20 | 25 | 25 | 30 | N/A |
| Shotgun (Slug) | 13 | 15 | 20 | 25 | 30 | 35 | N/A | N/A |
| Assault Rifle | 17 | 16 | 15 | 13 | 15 | 20 | 25 | 30 |
| Sniper Rifle | 30 | 25 | 25 | 20 | 15 | 16 | 17 | 20 |
| Bow / Crossbow | 15 | 13 | 15 | 17 | 20 | 22 | N/A | N/A |
| Grenade Launcher | 16 | 15 | 15 | 17 | 20 | 22 | 25 | N/A |
| Rocket Launcher | 17 | 16 | 15 | 15 | 20 | 20 | 25 | 30 |

Range bands are in m/yds; N/A means the range is not possible. "Pistol" covers all four pistol classes. Heavy SMG uses the SMG row (inferred; the table lists only SMG).

### Aimed Shots (p170)

- Max 1 ROF. Takes the entire Action, -8 to the Check, ranged or melee.
- Head: multiply the damage that gets through head armor by 2.
- Held Item: if at least 1 damage gets through body armor, the target drops one held item of your choice.
- Leg: if at least 1 damage gets through body armor, the target gets Broken Leg (if they have an unbroken leg left).
- Cannot be combined with Autofire or Shotgun Shell (p173, p174).

### Autofire (p173)

- Costs an Action and 10 bullets (needs 10 in the magazine). Uses the Autofire Skill, and the Autofire Range table, not the normal one. Dodgeable by REF 8+.
- On a hit: roll 2d6 and multiply by (amount the Check beat the DV), capped at the weapon's Autofire multiplier (SMG 3, Assault Rifle 4). Double 6s inflict a Critical Injury.
- Example (p173): AR at 14 m, DV17, beat by 4, 2d6 = 10, x4 = 40 damage.

| Autofire DV | 0-6 | 7-12 | 13-25 | 26-50 | 51-100 |
|---|---|---|---|---|---|
| SMG | 20 | 17 | 20 | 25 | 30 |
| Assault Rifle | 22 | 20 | 17 | 20 | 25 |

(p173)

AMBIGUITY (p173): "multiplied by the amount you beat the DV", capped at the multiplier. If the Check only just beats the DV, the multiplier is 1. The Heavy SMG shares the SMG column (Autofire 3 per p94).

### Suppressive Fire (p174)

- Costs an Action and 10 bullets.
- All on-foot targets within 25 m/yds, out of cover, in your line of sight roll WILL + Concentration + 1d10 vs your REF + Autofire + 1d10.
- A failure means they must use their next Move Action to get into cover, plus the Run Action if needed, or get as close to cover as possible.

AMBIGUITY (p174): the tie rule is not stated for this contest, nor is whether Suppressive Fire deals damage. The text implies no damage.

### Shotgun Shell (p174)

- One Ranged Attack (REF + Shoulder Arms + 1d10) vs DV13.
- On a hit, every target in front of you, within 6 m/yds (3 squares) and visible, takes 3d6 damage. Damage is rolled once for all targets.
- No Aimed Shot. Each target with REF 8+ may dodge individually.

### Explosives (p174)

- Damage hits all targets (and terrain) in a 10x10 m/yd area (5x5 squares) centered on the target's 2x2 m/yd square. Damage is rolled once.
- If the attack roll misses the DV, the GM places the landing point somewhere in the 10x10 area around the target, and the blast is centered there instead.
- REF 8+ may individually dodge by rolling higher than the original attack Check, and if so are placed outside the blast area.
- Cover: a blast does not hurt targets behind cover it cannot destroy. If the damage would destroy the cover, the target is no longer covered and takes full damage.
- Grenade Launcher 6d6, Rocket Launcher 8d6 (p94). Launcher DV uses the range table. Thrown grenades: see Throw.

### Thrown objects (p177)

- Action, Ranged Attack with DEX + Athletics + 1d10, max range 25 m/yds, using the Grenade Launcher DV entry. Dodgeable by REF 8+.
- Melee weapons deal stated damage when thrown, without halving SP. Grenades deal their launcher damage. Improvised: GM decides.

## 7. Melee, Brawling, Grapple, Martial Arts (p175-180)

### Melee (p176)
- Attack: DEX + Melee Weapon Skill + 1d10 vs the Defender's DEX + Evasion + 1d10 (tie to Defender). Target must be within 2 m/yds.
- 2 ROF except Very Heavy (1 ROF). Halves SP (round up).

### Brawling (p176)

| BODY | 4 or less | 5-6 (or 4 or less with a Cyberarm) | 7-10 | 11+ |
|---|---|---|---|---|
| Damage | 1d6 | 2d6 | 3d6 | 4d6 |

- Uses the Brawling Skill. A Cyberarm gives at least 2d6. Brawling does not halve armor SP.
- Brawling is also the Skill for initiating and defending against a Grapple.

### Grab (p177)
- Needs a free hand. Both roll DEX + Brawling + 1d10; the target must be within reach.
- If the attacker wins: either grab hold of the Defender or take one object they hold into a free hand.
- Grappled: both take -2 to all Actions. The Defender cannot use a Move Action and is dragged along by the Attacker's Move Action. No two-handed weapon use for either party. The grabbing hand is occupied.
- The Attacker ends the Grapple freely. The Defender (or anyone else) must use an Action and win a Grab roll against the Attacker to break it.
- Prerequisite for Choke and Throw.
- Choke: Action, deals the Attacker's BODY directly to HP, ignoring armor without ablation. If it would reduce a target above 1 HP to below 0, they are left at 1 HP and Unconscious. Choking the same target 3 successive Rounds makes them Unconscious regardless of HP (p177).
- Throw (person): Action, deals the Attacker's BODY directly to HP, ignoring armor, no ablation. Ends the Grapple (and the -2). Target is Prone (p177).

### Martial Arts (p178)
- Requires at least 1 point in Martial Arts. 2 ROF. Halves armor SP (round up).
- Damage by BODY: 4 or less 1d6, 5-6 2d6, 7-10 3d6, 11+ 4d6.
- Attack: DEX + the Form's Skill + 1d10 vs the Defender's DEX + Evasion + 1d10 (or a DV for some Special Moves). Special Moves need at least 1 point in that Form. Special Moves cannot be Aimed Shots unless stated.

Special Moves (p179-180). "SMR" means the Martial Arts Special Move Resolution.

| Form | Move | Requirement | Effect | Page |
|---|---|---|---|---|
| Shared | Recovery | none | On Get Up, SMR vs DV13: Get Up costs no Action | p179 |
| Aikido | Disarming Combination | Hit same target with a Brawling and a Martial Arts Attack this Turn | Once per Turn, SMR DV15: one held object is yours or on the floor | p179 |
| Aikido | Counter Throw | Dodged all Melee Attacks targeted at you since your last Turn | Once per Turn, Action, SMR DV15: Throw one target in melee range whose attack you dodged; cannot be avoided; no Grapple needed | p179 |
| Karate | Armor Breaking Combination | Hit same target with a Melee Weapon and a Martial Arts Attack this Turn | Once per Turn, SMR DV15: target's worn armor ablated by an additional 2 | p179 |
| Karate | Bone Breaking Strike | WILL 8+ | Replaces the 2 attacks; one target, Action. On a hit: damage plus Broken Ribs. With -8: aim at head instead, Cracked Skull. No new crit if already suffering | p179 |
| Judo | Iron Grip | Target successfully Grabbed, not already affected | Once per Turn, Action, SMR DV15: target's escape attempts get an additional -2 and they cannot make Ranged Attacks until the Grapple ends | p179 |
| Judo | Grab Escape | Hit a target that is grappling you with 2 Melee Attacks this Turn | Once per Turn, SMR DV15: you escape the Grapple, and they get Broken Arm (you pick the arm) if not already | p179 |
| Taekwondo | Pressure Point Strike | WILL 8+ | Replaces the 2 attacks; one target. On a hit: damage plus Spinal Injury. With -8: head instead, Brain Injury. No new crit if already suffering | p180 |
| Taekwondo | Flying Kick | MOVE 8+, moved at least 4 m/yds already this Turn | Replaces the 2 attacks; uses Action and all remaining movement to fling in a straight line up to 4 m/yds. On a hit: damage to body, target Prone and removed from any open vehicle or motorcycle | p180 |

AMBIGUITY (p179-180): the printed layout is two-column and somewhat scrambled. The Judo and Karate pairing and the Karate/Judo headers are inferred from move names and requirements. Verify which Judo move is Iron Grip versus Grab Escape. Whether Grab Escape belongs to Judo (grappling form) is inferred, and Counter Throw to Aikido.

## 8. Cover, Damage, Armor Ablation (p182-186)

### Cover (p182)
- In cover only if fully behind something that could stop a bullet. If the enemy has line of sight, you are not in cover. No partial cover.
- Cover has HP. A 2x2 m/yd (1 square) section can be attacked like a character. At 0 HP it is destroyed. Excess damage is lost and does not hurt the person behind; you can hurt them on your next Attack. Explosives are the exception (section 6).
- Thick cover cannot be moved by characters under BODY 10 without equipment. Steel cover cannot be damaged by Martial Arts or Brawling except by a Cyberarm or BODY 10+.

| Material | Thick HP | Thin HP |
|---|---|---|
| Steel | 50 | 25 |
| Stone | 40 | 20 |
| Bulletproof Glass | 30 | 15 |
| Concrete | 25 | 10 |
| Wood | 20 | 5 |
| Plaster/Foam/Plastic | 15 | 0 (not cover) |

(p182) Examples (p183): Bank vault door thick steel 50; Car door thin steel 25; Metal door thin steel 20 (listed as 20, though thin steel is 25 in the table); Data term thick concrete 25; Office wall thick plaster 15; Sofa 15; Overturned table 5; Wooden door 5; Wardrobe 5; Cubicle and windshield 0 (not cover); Refrigerator and shipping container thin steel 25; Engine block, hydrant 50; Tree, bar, log wall 20; Boulder 40; Statue 20.

AMBIGUITY (p183): the Metal Door example is listed at 20 HP, but Thin Steel is 25 HP in the main table. Likely a printing inconsistency.

### Taking Damage (p186)
1. Attacker rolls damage.
2. Subtract the SP of the hit location (body unless an Aimed Shot at the head); remaining damage subtracts from HP.
3. If any damage got through, the armor in that location ablates: SP -1 until repaired (all worn armor in that location).
- Poisons, fire, and similar bypass armor.
- Head Aimed Shot: damage that gets through head SP is multiplied by 2 (3 with Cracked Skull) (p170, p222).
- Melee and Martial Arts attacks halve SP (round up) before step 2 (p176, p178). Brawling does not (p176).
- Example (p175): a SP11 Light Armorjack is treated as SP6, leaving 1 damage on a 6 roll, and ablates to 10.

AMBIGUITY (p186): the rules do not state whether ablation occurs with 0 damage through; they say ablate if any damage was taken. The ablation by Melee: the printed SP (after halving) is not what ablates, the armor's SP drops by 1 (example p175).

### Wound States (p186, p220)

| State | Threshold | Effect | Stabilize DV |
|---|---|---|---|
| Lightly Wounded | HP below full | none | 10 |
| Seriously Wounded | HP below ceil(max/2) | -2 to all Actions | 13 |
| Mortally Wounded | HP below 1 | -4 to all Actions; -6 MOVE (min 1); Death Save at start of each Turn; any Melee/Ranged damage causes a Critical Injury; Death Save Penalty +1 per damaging attack | 15 (heals to 1 HP, Unconscious 1 min) |
| Dead | One failed Death Save | | never coming back |

(p186, p220, p222). Each new Wound State replaces the previous effect.

Verified against printed p220: -2 all Actions for Seriously Wounded; -4 all Actions and -6 MOVE (min 1) for Mortally Wounded.

### Death Saves (p188, p222)
- At the start of each of your Turns while Mortally Wounded: roll a d10. If the roll is under your BODY (adjusted by the Death Save Penalty), you live and take your Turn. A natural 10 always fails.
- Each time you roll a Death Save, the Death Save Penalty increases by 1 (each future save is made with an additional +1). It accumulates until Stabilization restores 1 HP, then resets to the Base Death Save Penalty (raised by certain Critical Injuries).
- One failed save is death.

AMBIGUITY (p188): the penalty is added to the d10 roll ("an additional +1"); the check is roll < BODY after the penalty. The rule says "roll under your BODY". A roll equal to BODY fails.

## 9. Critical Injuries (p187-188, p220-223)

- Trigger: two or more damage dice from a Melee or Ranged attack show 6 (p187). Autofire: both 2d6 dice are 6 (p173). Mortally Wounded characters also suffer one whenever damaged by an attack (p186).
- Roll 2d6 on the Body table (or the Head table if an Aimed Shot at the head); reroll until a result the target does not already have (p187).
- Each Critical Injury deals 5 Bonus Damage directly to HP when suffered, no ablation, no location modifier, even if no damage got through SP (p187).
- A Cyberlimb or cyber organ still suffers the effect and bonus damage. Cybertech may be used for Quick Fix or Treatment (p223).
- Quick Fix: removes the effect for the rest of the day, takes 1 minute per attempt, can be done on yourself. Treatment: removes the effect permanently, takes 4 hours per attempt, cannot be done on yourself (p223).

### Body (p187)

| 2d6 | Injury | Effect | Quick Fix | Treatment |
|---|---|---|---|---|
| 2 | Dismembered Arm | Arm gone; drop items in that hand; Base DSP +1 | N/A | Surgery DV17 |
| 3 | Dismembered Hand | Hand gone; drop items in it; Base DSP +1 | N/A | Surgery DV17 |
| 4 | Collapsed Lung | -2 MOVE (min 1); Base DSP +1 | Paramedic DV15 | Surgery DV15 |
| 5 | Broken Ribs | At end of each Turn you move more than 4 m/yds on foot, re-suffer the bonus damage (5 to HP) | Paramedic DV13 | Paramedic DV15 or Surgery DV13 |
| 6 | Broken Arm | Arm unusable; drop items in that hand | Paramedic DV13 | Paramedic DV15 or Surgery DV13 |
| 7 | Foreign Object | Same as Broken Ribs (bonus damage after moving more than 4 m/yds) | First Aid or Paramedic DV13 | Quick Fix removes the effect permanently |
| 8 | Broken Leg | -4 MOVE (min 1) | Paramedic DV13 | Paramedic DV15 or Surgery DV13 |
| 9 | Torn Muscle | -2 to Melee Attacks | First Aid or Paramedic DV13 | Quick Fix removes the effect permanently |
| 10 | Spinal Injury | Next Turn no Action (Move Action still allowed); Base DSP +1 | Paramedic DV15 | Surgery DV15 |
| 11 | Crushed Fingers | -4 to all Actions involving that hand | Paramedic DV13 | Surgery DV15 |
| 12 | Dismembered Leg | Leg gone; -6 MOVE (min 1); cannot dodge; Base DSP +1 | N/A | Surgery DV17 |

### Head (p188, p221-222)

| 2d6 | Injury | Effect | Quick Fix | Treatment |
|---|---|---|---|---|
| 2 | Lost Eye | Eye gone; -4 Ranged Attacks and vision Perception; Base DSP +1 | N/A | Surgery DV17 |
| 3 | Brain Injury | -2 all Actions; Base DSP +1 | N/A | Surgery DV17 |
| 4 | Damaged Eye | -2 Ranged Attacks and vision Perception | Paramedic DV15 | Surgery DV13 |
| 5 | Concussion | -2 all Actions | First Aid or Paramedic DV13 | Quick Fix removes the effect permanently |
| 6 | Broken Jaw | -4 to all Actions involving speech | Paramedic DV13 | Paramedic or Surgery DV13 |
| 7 | Foreign Object | Bonus damage when moving more than 4 m/yds (as above) | First Aid or Paramedic DV13 | Quick Fix removes the effect permanently |
| 8 | Whiplash | Base DSP +1 | Paramedic DV13 | Paramedic or Surgery DV13 |
| 9 | Cracked Skull | Aimed head shots multiply damage through SP by 3 instead of 2; Base DSP +1 | Paramedic DV15 | Paramedic or Surgery DV15 |
| 10 | Damaged Ear | After moving more than 4 m/yds in a Turn, no Move Action next Turn; -2 hearing Perception | Paramedic DV13 | Surgery DV13 |
| 11 | Crushed Windpipe | Cannot speak; Base DSP +1 | N/A | Surgery DV15 |
| 12 | Lost Ear | Ear gone; same movement restriction as Damaged Ear; -4 hearing Perception; Base DSP +1 | N/A | Surgery DV17 |

"Base DSP +1" = Base Death Save Penalty increased by 1.

Verified against printed p222: 11 Crushed Windpipe, 12 Lost Ear.

## 10. Stabilization and Healing (p222-223)

- Stabilize is an Action: TECH + First Aid (or Paramedic) + 1d10 vs DV by Wound State: Lightly 10, Seriously 13, Mortally 15 (p222).
- After stabilization the target heals BODY HP per full day of resting and light activity until full. If they push it, they gain no HP that day, wounds reopen, and they need re-stabilization (p222-223).
- Mortally Wounded + success: healed to 1 HP and Unconscious for 1 minute (p223). Death Saves still occur if they are damaged back to Mortally Wounded while unconscious (p223).
- Exposure to extreme elements prevents natural healing even when Stabilized (p181).

Healing skills (p223): Cybertech (cyber injuries only, cannot stabilize); First Aid (stabilize and common Quick Fixes; always at least +2); Paramedic (x2 cost; stabilize, Quick Fix, and Treat all but the deadliest); Surgery (Medtech only; the deadliest Treatments).

## 11. Other Damage Sources (p180-181)

| Hazard | Rule | Page |
|---|---|---|
| Being On Fire | Direct HP damage at the end of each Turn until an Action puts it out; no ablation. Mild (wood) 2, Strong (gasoline) 4, Deadly (thermite) 6 | p180 |
| Drowning/Asphyxia | After BODY minutes, at start of each Turn take BODY direct to HP, no ablation. Asphyxia in space: also 1d6 to INT, REF, DEX at end of Turn; INT 0 = dead; reversed on breath | p180 |
| Electrocution | 6d6 immediately, armor applies; repeats at the end of each of your Turns while still at the source | p180 |
| Exposure | 1d6 direct to HP per day; no natural healing while exposed | p181 |
| Falling | Fall 40 m/yds per Turn end; DV15 Athletics to catch a ledge. 10+ m/yds: 2d6 per 10 m/yds (body armor applies); fail DV15 Athletics = Broken Leg. 2 Cyberlegs negate, except falls over 30 m/yds. Skyscraper fall = dead | p181 |
| Poison | Resist Torture/Drugs vs DV; on fail: Mild DV11 1d6, Strong DV13 2d6, Deadly DV15 3d6 direct to HP; no ablation | p181 |
| Drugs | Resist vs DV; Mild 11 (Inebriation), Strong 13 (Suggestibility), Deadly 15 (designer effect) | p181 |
| Radiation | High level: treated as Mildly On Fire per Turn in the hot zone (cannot put out while there); extreme zone: Deadly On Fire | p181 |

AMBIGUITY (p181): fall damage "10 m/yds or more takes 2d6 for every 10 m/yds". Whether partial 10-m increments round down is not stated (assume floor).
