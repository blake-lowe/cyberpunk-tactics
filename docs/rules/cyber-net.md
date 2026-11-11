# Cyberpunk RED - Humanity, Cyberware and Netrunning (implementation reference)

Source: core rulebook, book page numbers in parentheses. Paraphrased; numbers exact.

## 1. Humanity and cyberpsychosis

### 1.1 Humanity basics (p80, p229)

- Humanity (HUM) = EMP x 10 at creation. 5 EMP = 50 HUM.
- Current EMP = tens digit of current HUM, rounded as the tens place drops: HUM 44 = EMP 4; at 39 EMP becomes 3. (HUM 40-49 -> EMP 4.) EMP drops every time the tens place of HUM is lowered. (p80, p229)
- HUM below 0 = cyberpsychosis state (p80).
- At character creation Humanity Loss (HL) from cyberware uses preset flat numbers; after creation roll the dice shown (p111):

| Dice | Creation flat |
|---|---|
| 1d6/2 (round up) | 2 |
| 1d6 | 3 |
| 2d6 | 7 |
| 4d6 | 14 |
| N/A | 0 |

- Cyberware that replaces a lost/missing part (Medical-Grade) has no HL and no option slots (p109, p226). Bodysculpting: Standard has no HL; Exotic costs 4d6 HL (p227). Installing cyberware does not trigger HL for 0-HL items; Fashionware is 0 HL (p111).
- Chipware: first time a given piece of Chipware is installed in a Chipware Socket HL is accrued; re-installing a piece already used does not (p359). Cyberarms: first install of a brand new Cyberarm via Quick Change Mount accrues HL; reattaching a previously used one does not (p365).
- Paired options (e.g. two Cybereyes, paired cyberleg options): HL is paid separately for each purchase (p112, p116, p360, p366).

### 1.2 Non-cyberware Humanity Loss (p109, p231)

GM-assigned. Examples: witnessing scavvers eating a baby: at least 6 (p109).

| Trauma type | Example | HL |
|---|---|---|
| Traumatic Physical Incident | Torture | 1d6 |
| Traumatic Mental Incident | Witnessing a horrific death/mutilation | 1d6 |
| Long-term Mental Stress | Kidnapping, imprisonment, long-term abuse | 2d6 |
| Long-term Environmental Stress | Starvation, trapped in war zone, a month of constant danger | 2d6 |

Street drug Black Lace: 2d6 HL on taking a dose; returned if the user passes (is not affected by) the Secondary Effect, otherwise kept (p227).

### 1.3 Effects of low EMP / Humanity (p232)

| Current EMP | Effect |
|---|---|
| 3 or more | No cyberpsychosis or dissociative disorder |
| 2 | Borderline dissociative disorder. Roleplay accordingly |
| 1 | Dissociative disorder, borderline cyberpsychosis; shows at least 3 traits from the Hare Psychopathy checklist |
| 0 | Cyberpsychosis; shows at least 5 traits from the checklist |
| 0 and negative Humanity | Extreme cyberpsychosis: GM takes control, plays character at worst tendencies; returned to player if Humanity goes positive again |

Violent cyberpsychos are hunted by Psycho Squads (C-SWAT, MAX-TAC); death is typical (p109, p232).
AMBIGUITY (p232): the book gives no mechanical roll or trigger table; the game must define what "roleplay accordingly" means for NPC/AI control (suggest AI takeover of the unit at EMP 0, stat penalties for EMP 1-2).

### 1.4 Therapy and recovery (p229-230)

Therapy is done by a Medtech with Medical Tech Skill; takes 1 entire week of the doctor and patient; roll Medical Tech vs DV at the end; failure wastes the week and materials. Medtechs cannot treat themselves. Overnight hospital stay adds 100eb per night. Materials are bought from Biotechnica. (p229)

| Therapy | Cost | Medical Tech DV | Materials | Effect |
|---|---|---|---|---|
| Addiction | 1,000eb (V. Expensive) | 15 | 500eb (Expensive) | Frees patient of one addiction; for 1 year after, they auto-fail Secondary Effect rolls for that drug |
| Standard Humanity Loss | 500eb (Expensive) | 15 | 100eb (Premium) | Regain 2d6 HUM |
| Extreme Humanity Loss | 1,000eb (V. Expensive) | 17 | 500eb (Expensive) | Regain 4d6 HUM |

(p230)
Maximum Humanity cap: Humanity cannot be restored fully while cyberware remains. Each installed cyberware piece lowers maximum Humanity by 2; each Borgware piece lowers it by 4; cyberware with 0 HL at install lowers nothing. (p230)
AMBIGUITY (p230): the book does not say whether max Humanity starts at 10 x creation EMP (assumed) nor whether the cap recalculates when cyberware is removed (assumed yes).

Street drug Secondary Effects (p227-229, p357): at end of Primary Effect roll WILL + Resist Torture/Drugs + 1d10 vs DV; fail = addicted.

| Drug | Dose cost | Primary Effect | Secondary DV | Secondary Effect |
|---|---|---|---|---|
| Black Lace | 50eb | 24h: ignore Seriously Wounded; 2d6 HUM loss | 17 | HL kept, addicted: REF -2 unless under Primary |
| Blue Glass | 20eb | 4h: random "flash outs" lose your Action | 15 | addicted; flash-outs persist (immune only while under Primary) |
| Boost | 50eb | 24h: INT +2 (can exceed 8) | 17 | addicted: INT -2 |
| Smash | 10eb | 4h: +2 Dance, Contortionist, Conversation, Human Perception, Persuasion, Acting | 15 | addicted: -2 to those skills |
| Synthcoke | 20eb | 4h: REF +1 (can exceed 8), paranoia | 15 | addicted: REF -2 unless under Primary |

Multiple doses extend Primary Effect by its full duration (p227).

## 2. Cyberware

### 2.1 Install rules (p110, p226)

- Installation surgery is included in purchase price, including at character creation (p110).
- Cannot install cyberware while suffering a Critical Injury related to it (p110).
- Install location, in order of severity: **Mall** (any shop; "ear-piercing"), **Clinic** (ripperdoc with Medtech, mostly automated), **Hospital** (major surgery, rare) (p110).
- Self-install only allowed if typical installation is Mall (p226). Otherwise a Medtech uses Surgery.

| Install | Surgery DV (Medtech only) | Install cost at a hospital |
|---|---|---|
| Mall | 13 | 100eb (Premium) |
| Clinic | 15 | 500eb (Expensive) |
| Hospital | 17 | 1,000eb (V. Expensive) |
(p226)
- Medtech install or harvest takes 4 hours; failure destroys the cyberware and wastes 2 hours. Harvesting from a corpse uses the same DV as installing; easily removable pieces (Chipware, Cyberlimbs with Quick Change Mount) can be removed by anyone as an Action. Destroyed cyberware can be repaired with Cybertech but has no market value. (p226)
- Medical-Grade replacement: no benefits, no option slots, no HL; cloned replacement limb 50eb (Costly), included in hospital visit cost (p226). A full cyber replacement means paying Treatment for the Critical Injury plus the cyberware cost (p226).
AMBIGUITY (p226): "Cost to Install at a Hospital" table is for installing cyberware you supply; purchase price elsewhere already includes surgery (p110).

### 2.2 Foundational vs optional (p111)

- Most categories have a foundational piece with Option Slots; options need a free slot unless marked otherwise.
- Fashionware, Internal and External Cyberware have no foundation but at most 7 Option Slots worth in each category.
- Benefits of multiple installations of the same cyberware do not stack unless stated.
- Cyberware cost is in eb with Price Category in parentheses.

| Category | Foundation | Option Slots |
|---|---|---|
| Fashionware | none | 7 |
| Neuralware | Neural Link | 5 (Chipware does not use a slot) |
| Cyberoptics | Cybereye | 3 per eye |
| Cyberaudio | Cyberaudio Suite (only 1) | 3 |
| Internal | none | 7 |
| External | none | 7 |
| Cyberlimbs | Cyberarm | 4 |
| Cyberlimbs | Cyberleg | 3 |
| Borgware | see item notes | n/a |

Placement details from the full entries (p358-367), as the game's slot model (src/core/cyber.gd) reads them:
- A piece takes 1 Option Slot unless its entry says otherwise (p358 sidebar). Chipware takes no Neural Link slot; a Chipware Socket holds a single chip, and several sockets may be installed, each paid for (p359).
- "Paired" options are purchased twice and installed in two different Cybereyes/Cyberlegs, Humanity Loss for each purchase; they "must be paired to work properly" (p361, p366): Anti-Dazzle, Image Enhance, LL/IR/UV (2 slots per eye), Virtuality; Grip Foot, Jump Booster (2 slots), Skate Foot, Web Foot.
- Cyberarm and Cyberleg "do not have to be paired" and come with a Standard Hand/Foot that takes no slot and no HL (p364, p366).
- "Can be installed as the only piece of Cyberware in a meat arm": Big Knucks, Rippers, Scratchers, Slice 'N Dice, Subdermal Grip, Tool Hand, Wolvers; a Standard Hand in a meat arm doesn't count towards that. Meat leg: Talon Foot; Standard Foot doesn't count (p364-367).
- Subdermal Grip: Cyberarm and Neuralware Option; requires a Neural Link and takes a Neuralware Option Slot (p366).
- Only one Speedware (p359-360); only one Cyberaudio Suite (p362). Coverings need a Cyberarm or Cyberleg and take no slot; Hardened Shielding makes its limb and options immune to EMP (Microwaver) and Non-Black ICE effects (p367).
- Senses and hazards, as the game plays them (full entries p359-363): Low Light/Infrared/UV reduces penalties from darkness and other "intangible obscurement, like smoke, fog, etc." to 0 but can't see through anything that could be cover (p360; HOUSE-RULE, owner 2026-11-11: of the Night City Weather penalties it sees through smog, ash and dust but not heavy rain, storms or blood rain, Weather.optics_sight); Image Enhance +2 Perception for Checks that include sight, Amplified Hearing +2 for Checks that include hearing (p360-361; different pieces, so a Check using both senses takes both); Anti-Dazzle: immune to blindness and other effects of dangerous flashes "like those of a flashbang" (p360); Level Damper: immune to deafness and other effects of dangerously loud noises, flashbang named (p361); Nasal Filters: immune to toxic gasses, fumes and anything that must be inhaled (p363); Independent Air Supply: 30 minutes of air, an hour to refill (p363); Radar/Sonar: constant scan within 50m, nothing behind cover, a beep and a direction for each new moving object (p363); Tactile Boost: motion within 20m while a hand touches a surface, that hand doing nothing else (p359).
- READINGS (phase 2): teargas works on "anyone with meat eyes" (p347), not through the lungs, so Nasal Filters don't stop it (two Cybereyes do); a poison or biotoxin grenade is a toxic gas cloud, so they do. The Night City Weather sight penalties (rain, dust, ash, smog) are intangible obscurement, so LL/IR/UV ignores them. A gig never outlasts the Independent Air Supply's 30 minutes.
- AMBIGUITY (p366): Subdermal Grip in a Cyberarm: the game charges it a Cyberarm slot (the 1-slot default) as well as the Neuralware slot.

Full cyberware descriptions are on p358-366; the lists below are the abbreviated tables (p111-116).

### 2.3 Cyberware table (p111-116)

HL column: dice (creation flat value in parentheses). Install: M = Mall, C = Clinic, H = Hospital, "-" = N/A (chip).

**Fashionware (p111, 7 slots)** - all HL 0.

| Name | Inst | Effect | Cost |
|---|---|---|---|
| Biomonitor | M | Subdermal vitals readout; links to Agent | 100eb |
| Chemskin | M | Skin hue change; +2 Personal Grooming if also Techhair | 100eb |
| EMP Threading | M | Silver circuit-like lines; cosmetic | 10eb |
| Light Tattoo | M | Projected tattoos; +2 Wardrobe & Style with 3+ tattoos | 100eb |
| Shift Tacts | M | Color-changing eye lenses | 100eb |
| Skinwatch | M | Implanted LED watch | 100eb |
| Techhair | M | Light-emitting hair; +2 Personal Grooming if also Chemskin | 100eb |

**Neuralware (p112, foundation Neural Link, 5 slots)**

| Name | Inst | Effect | HL | Cost |
|---|---|---|---|---|
| Neural Link | C | Wired nervous system; required for Neuralware and Subdermal Grip; 5 option slots | 2d6 (7) | 500eb |
| Braindance Recorder | C | Records experiences to chip/device | 2d6 (7) | 500eb |
| Chipware Socket | C | Neck socket for Chipware (swap is an Action; no slot used; can have several, each paid) | 2d6 (7) | 500eb |
| Interface Plugs | C | Wrist/head plugs to connect to machines, Smartguns, Cyberdecks | 2d6 (7) | 500eb |
| Kerenzikov | C | Speedware: +2 Initiative always; only one Speedware at a time | 4d6 (14) | 500eb |
| Sandevistan | C | Speedware: Action to get +3 Initiative for 1 minute, 1 hour cooldown; only one Speedware | 2d6 (7) | 500eb |
| Chemical Analyzer | - | Chipware: identify substances | 1d6 (3) | 500eb |
| Memory Chip | - | Chipware: data storage for cyberware | 0 | 10eb |
| Olfactory Boost | - | Chipware: use Tracking by scent | 2d6 (7) | 100eb |
| Pain Editor | - | Chipware: ignore Seriously Wounded penalties | 4d6 (14) | 1,000eb |
| Skill Chip | - | Chipware: its Skill counts as trained at +3 unless already trained higher (then it does nothing); (x2) skills cost more | 2d6 (7) | 500eb (1,000eb for x2 skill) |
| Tactile Boost | - | Chipware: sense motion within 20m by touching a surface | 2d6 (7) | 100eb |

**Cyberoptics (p112-113, foundation Cybereye, 3 slots per eye)** - paired options need two Cybereyes.

| Name | Inst | Effect | HL | Cost |
|---|---|---|---|---|
| Cybereye | C | Artificial eye, 3 slots | 2d6 (7) | 100eb |
| Anti-Dazzle | M | Immune to flash effects; paired | 1d6/2 (2) | 100eb |
| Chyron | M | Subscreen in vision | 1d6/2 (2) | 100eb |
| Color Shift | M | Eye colour/pattern changes | 1d6/2 (2) | 100eb |
| Dartgun | C | Concealed single-shot Dartgun; 3 slots | 1d6/2 (2) | 500eb |
| Image Enhance | M | +2 Perception, Lip Reading, Conceal/Reveal Object; paired | 1d6 (3) | 500eb |
| Low Light / Infrared / UV | M | Ignore darkness/smoke/fog penalties; paired; 2 slots per eye | 1d6 (3) | 500eb |
| MicroOptics | C | 400x magnification | 1d6/2 (2) | 100eb |
| MicroVideo | C | Camera in eye, records; 2 slots | 1d6/2 (2) | 500eb |
| Radiation Detector | C | Radiation readout within 100m | 1d6 (3) | 1,000eb |
| Targeting Scope | C | +1 on Aimed Shot check | 1d6 (3) | 500eb |
| TeleOptics | C | See detail to 800m; +1 to single shots and Aimed Shots at 51m+ | 1d6 (3) | 500eb |
| Virtuality | M | Cyberspace imagery overlay; paired | 1d6/2 (2) | 100eb |

**Cyberaudio (p113, foundation Cyberaudio Suite, 3 slots)** - all options need the Suite.

| Name | Inst | Effect | HL | Cost |
|---|---|---|---|---|
| Cyberaudio Suite | C | Foundation; only one | 2d6 (7) | 500eb |
| Amplified Hearing | M | +2 Perception (hearing) | 1d6 (3) | 100eb |
| Audio Recorder | C | Records audio | 1d6/2 (2) | 100eb |
| Bug Detector | M | Beeps within 2m of a listening device | 1d6/2 (2) | 100eb |
| Homing Tracer | C | Follow a linked tracer up to 1 mile | 1d6/2 (2) | 100eb |
| Internal Agent | M | Agent installed internally | 1d6 (3) | 100eb |
| Level Damper | M | Immune to loud-noise effects | 1d6/2 (2) | 100eb |
| Radio Communicator | M | Radio, 1 mile | 1d6/2 (2) | 100eb |
| Radio Scanner / Music Player | C | Music and radio within 1 mile | 1d6/2 (2) | 50eb (Costly) |
| Radar Detector | C | Beeps if active radar within 100m | 1d6/2 (2) | 500eb |
| Scrambler / Descrambler | M | Scramble/descramble comms | 1d6/2 (2) | 100eb |
| Voice Stress Analyzer | M | +2 Human Perception and Interrogation | 1d6 (3) | 100eb |

**Internal Cyberware (p114, 7 slots)**

| Name | Inst | Effect | HL | Cost |
|---|---|---|---|---|
| AudioVox | C | Voice synth: +2 Acting and Play Instrument (singing) | 1d6 (3) | 500eb |
| Contraceptive Implant | M | Prevents pregnancy | 0 | 10eb |
| Enhanced Antibodies | M | After stabilization, heal BODY x 2 per day of rest | 1d6/2 (2) | 500eb |
| Cybersnake | H | Esophagus-mounted Very Heavy Melee Weapon, concealable | 4d6 (14) | 1,000eb |
| Gills | H | Breathe underwater | 2d6 (7) | 1,000eb |
| Grafted Muscle and Bone Lace | H | BODY +2 (changes HP, Wound Threshold, Death Save); cannot raise BODY above 10 | 4d6 (14) | 1,000eb |
| Independent Air Supply | H | 30 min oxygen, 1 hour to refill | 1d6/2 (2) | 1,000eb |
| Midnight Lady Sexual Implant | C | Sexual implant | 2d6 (7) | 100eb |
| Mr. Studd Sexual Implant | C | Sexual implant | 2d6 (7) | 100eb |
| Nasal Filters | C | Immune to toxic gases/fumes | 1d6/2 (2) | 100eb |
| Radar / Sonar Implant | C | Scan terrain within 50m; not through cover | 2d6 (7) | 1,000eb |
| Toxin Binders | C | +2 Resist Torture/Drugs | 1d6/2 (2) | 100eb |
| Vampyres | C | Excellent Quality Light Melee Weapon in mouth, concealable; can add Poison/Biotoxin | 4d6 (14) | 500eb |

**External Cyberware (p114, 7 slots)**

| Name | Inst | Effect | HL | Cost |
|---|---|---|---|---|
| Hidden Holster | C | Store a concealable weapon in the body | 2d6 (7) | 500eb |
| Skin Weave | H | Body and head SP 7; no stack with worn armor; ablates; +1 SP per day rest | 2d6 (7) | 500eb |
| Subdermal Armor | H | Body and head SP 11; no stack with worn armor; ablates; +1 SP per day rest | 4d6 (14) | 1,000eb |
| Subdermal Pocket | C | 2" x 4" under-skin storage | 1d6 (3) | 100eb |

**Cyberlimbs (p115-116)** - Cyberarm (4 slots), Cyberleg (3 slots); Hardened Shielding and coverings need Cyberarm or Cyberleg.

| Name | Inst | Effect | HL | Cost |
|---|---|---|---|---|
| Cyberarm | H | Replacement arm, 4 slots; includes Standard Hand (free, no slot) | 2d6 (7) | 500eb |
| Standard Hand | C | Cybernetic hand; can go in a meat arm | 1d6/2 (2) | 100eb |
| Big Knucks | C | Armored knuckles, Medium Melee, concealable; can be only cyberware in meat arm | 1d6 (3) | 100eb |
| Cyberdeck | C | Cyberdeck in arm; 3 slots; +1 Program/Hardware slot to the deck | 1d6 (3) | 500eb |
| Grapple Hand | C | As an Action fires hand + 30m line to Thick cover; climbing the line has no movement penalty; retracts free; not a weapon | 1d6 (3) | 100eb |
| Medscanner | C | +2 First Aid and Paramedic; 2 slots | 2d6 (7) | 500eb |
| Popup Grenade Launcher | C | Single-shot concealable launcher; 2 slots | 2d6 (7) | 500eb |
| Popup Melee Weapon | C | One-handed Light/Medium/Heavy melee concealed, drawn/stowed free; 2 slots | 2d6 (7) | 500eb |
| Popup Shield | C | Bulletproof Shield (10 HP), concealed; out/away free while it has HP; replaceable; 3 slots | 2d6 (7) | 500eb |
| Popup Ranged Weapon | C | One-handed ranged weapon provided by the user, concealed, drawn/stowed free; 2 slots | 2d6 (7) | 500eb |
| Quick Change Mount | C | Remove/install Cyberarm as an Action | 2d6 (7) | 100eb |
| Rippers | C | Carbo-glass claws, Medium Melee, concealable; sole cyberware in meat arm allowed | 1d6 (3) | 500eb |
| Scratchers | M | Light Melee fingernails, concealable; sole cyberware in meat arm allowed | 1d6/2 (2) | 100eb |
| Shoulder Cam | C | Video camera in shoulder; 2 slots | 2d6 (7) | 500eb |
| Slice 'N Dice | C | Monofilament thumb whip, Medium Melee, concealable; sole cyberware in meat arm allowed | 1d6 (3) | 500eb |
| Subdermal Grip | C | Smartgun use without Interface Plug; needs Neural Link; sole cyberware in meat arm allowed | 1d6 (3) | 100eb |
| Techscanner | C | +2 to multiple TECH skills; 2 slots | 2d6 (7) | 500eb |
| Tool Hand | C | Built-in tools; sole cyberware in meat arm allowed | 1d6 (3) | 100eb |
| Wolvers | C | Heavy Melee claws, concealable; sole cyberware in meat arm allowed | 2d6 (7) | 500eb |
| Cyberleg | H | Replacement leg, 3 slots; includes Standard Foot; most options paired | 1d6 (3) | 100eb |
| Standard Foot | C | Cybernetic foot; can go in a meat leg | 1d6/2 (2) | 100eb |
| Grip Foot | C | No climbing movement penalty; paired | 1d6 (3) | 500eb |
| Jump Booster | C | No jumping movement penalty; paired; 2 slots | 1d6 (3) | 500eb |
| Skate Foot | C | +6m movement when using Run Action; concealable; paired | 1d6 (3) | 500eb |
| Talon Foot | C | Light Melee blade, concealable; sole cyberware in meat leg allowed | 1d6 (3) | 500eb |
| Web Foot | C | No swimming movement penalty; paired | 1d6 (3) | 500eb |
| Hardened Shielding | C | Limb and its options immune to EMP and Non-Black ICE Program effects | 1d6 (3) | 1,000eb |
| Plastic Covering | M | Cosmetic coating; no slot | 0 | 100eb |
| Realskinn Covering | M | Artificial skin coating; no slot | 0 | 500eb |
| Superchrome Covering | M | Metallic coating; +2 Wardrobe & Style; no slot | 0 | 1,000eb |

Cyberleg note: Standard Foot included free with Cyberleg and takes no slot or HL (p116).

**Borgware (p116)** - HL is a flat 4d6 (14) each; each Borgware piece lowers max Humanity by 4 (p230).

| Name | Inst | Effect | HL | Cost |
|---|---|---|---|---|
| Artificial Shoulder Mount | H | Mount 2 Cyberarms under first set | 4d6 (14) | 1,000eb |
| Implanted Linear Frame Beta | H | BODY becomes 14 (changes HP, Wound Threshold, Death Save); needs BODY 8, 2 Grafted Muscles and Bone Lace | 4d6 (14) | 5,000eb (Luxury) |
| Implanted Linear Frame Sigma | H | BODY becomes 12; needs BODY 6, Grafted Muscles and Bone Lace | 4d6 (14) | 1,000eb |
| MultiOptic Mount | H | Up to 5 extra Cybereyes | 4d6 (14) | 1,000eb |
| Sensor Array | C | Up to 5 extra Cyberaudio options (no slot used); needs Suite | 4d6 (14) | 1,000eb |

AMBIGUITY (p116): Linear Frame Sigma requires "Grafted Muscles and Bone Lace" (singular, likely 1 piece); Beta requires 2. Treat Sigma as 1 Grafted Muscle.

Starting cyberware and employer-bankrolled cyberware (1500eb + free Neural Link): see characters.md.

## 3. Netrunning (p195-218)

### 3.1 Gear and setup (p196-197)

- Requires: Neural Link + Interface Plugs (p196) and a Cyberdeck. Without Interface (Role Ability) you cannot netrun (p197).
- Virtuality Goggles overlay NET imagery on the real world (p196). Without them the runner is effectively Unconscious in meatspace until they Jack Out (p197).
- A Netrunner can plug into only one Cyberdeck at a time; switching decks needs a Meat Action (p196).

Cyberdeck (p196):

| Type | Cost | Slots |
|---|---|---|
| Poor Quality | 100eb (Premium) | 5 |
| Standard | 500eb (Expensive) | 7 |
| Excellent Quality | 1,000eb (V. Expensive) | 9 |

Programs and Hardware share the deck's slots (p196). Black ICE in a deck uses 2 slots (p204). Installing/uninstalling a Program, Black ICE, or Hardware takes 1 hour (p201, p204, p208).

Misc upgrades (p208):

| Name | Effect | Cost |
|---|---|---|
| Bodyweight Suit | SP11 head and body armor; storage for Cyberdeck/cords; adds 1 Hardware-only slot (hardware there is accessible only when worn and takes 1 slot) | 1,000eb (V. Expensive) |
| Cyberarm Cyberdeck option | Deck in Cyberarm; +1 Program/Hardware slot | 500eb (Expensive) |

Hardware (1 slot each unless noted) (p208):

| Name | Effect | Cost |
|---|---|---|
| Backup Drive (2 slots) | Saves destroyed Non-Black ICE Attacker/Defender/Booster Programs; reinstall all as a Meat Action if slots free; restored in saved state (once-per-Netrun limits kept); contents erased if removed | 100eb |
| DNA Lock (2 slots) | Biometric lock; else DV17 Electronics/Security Tech to bypass | 100eb |
| Hardened Circuitry | Immune to EMP and Non-Black ICE Program disable/destroy effects | 100eb |
| Insulated Wiring | Deck/clothing cannot catch fire from Program effects | 100eb |
| KRASH Barrier (2 slots) | Immune to Program effects forcing Jack Out | 100eb |
| Range Upgrade | Access point range 8m (instead of 6m) | 100eb |

### 3.2 Actions per Turn (p197-198)

- On your Turn: take either one Meat Action OR as many NET Actions as Interface allows. You always keep your Move Action (p197).

| Interface Rank | 1-3 | 4-6 | 7-9 | 10 |
|---|---|---|---|---|
| NET Actions | 2 | 3 | 4 | 5 |
(p147, p197)

NET Action list (p198): Jack In/Out; Use Interface Ability; Activate/Deactivate Program; Miscellaneous (GM, rare).
Not a NET Action: moving within the Architecture (as far as you like, but not past an obstruction like a Password) and saving a copy of a File to the deck (p198).

### 3.3 Jack In / Out and meatspace interplay (p198)

- Jack In (a NET Action) works only within 6 m/yds of an access point (8m with Range Upgrade); a wall between you and the point normally blocks it. Being jacked in is a prerequisite for anything in the Architecture. (p198, p208)
- Moving out of access range while jacked in jacks you out automatically AND you suffer all remaining enemy Black ICE you have encountered but not Derezzed. (p198)
- Jack Out safely (a NET Action, from within range): resets the Architecture's defenses; all your Programs leave with you; starting over means jacking back into the same location. Permanent effects need a Virus at the bottom. (p198)
- Your Move Action is still available while jacked in; you can move to cover as long as you stay within access range (p197 example).
- Netrunners can Scan (Scanner, Meat Action) for access points in meatspace (p199).
- A Turn is Meat Action OR NET Actions, so a runner who needs to shoot or flee in meatspace gives up that Turn's NET Actions (p197 example). Cyberware cannot be hacked via Interface (governed by Cybertech); analog or CitiNet-only devices have no Architecture (counter with Electronics/Security Tech) (p209).

### 3.4 Interface Abilities (p198-201)

Roll for abilities: Interface Rank + 1d10 vs DV (p198). Each needs a NET Action except Scanner.

| Ability | Action | Mechanic |
|---|---|---|
| Scanner | Meat Action | Find Meatspace location of access points in the area; higher roll = more found from farther away; GM sets result (e.g. 14 -> 2 access points) (p199) |
| Backdoor | NET Action | Break a Password in the Architecture; roll vs Password DV; if you know the password you pass automatically (p199) |
| Cloak | NET Action | Hide traces of your actions and any Virus; DV for another Netrunner to see through it (via Pathfinder) = your Cloak Check. If you Jack Out without Cloak, another Netrunner using Pathfinder automatically learns what you did (p199) |
| Control | NET Action | Take a Control Node (cameras, drones, turrets, laser grids, elevators, sprinklers, ...) vs the Node's DV. Operating each thing on the node costs a separate NET Action, anywhere in the Architecture while you hold the node. Each Node can be activated once per Turn. To take a Node held by another Netrunner/Demon, DV = their Control Check. You lose all held Nodes when you Jack Out (p199) |
| Eye-Dee | NET Action | Identify a found piece of data and its value; some Files have a DV to beat (p199) |
| Pathfinder | NET Action | Reveal the map: see as many floors as your Check, up to the first obstruction (usually a Password) whose DV exceeds your Check; shows contents but not DVs (p199-200) |
| Slide | NET Action | Flee a single non-Demon Black ICE: roll Interface + 1d10 vs the ICE's Perception + 1d10; success moves you to an adjacent floor (not past a Password or obstruction); that ICE stops following and waits where you left it. Once per Turn; cannot be used preemptively (p200) |
| Virus | NET Actions as GM sets | Only at the lowest floor: leave a custom Virus that makes up to 2 changes, persisting after Jack Out. GM sets DV and NET Action cost; roll Interface + 1d10 vs DV. DV to destroy the Virus = your Virus Check (p200) |
| Zap | NET Action | Attack a Program or Netrunner: Interface + 1d10 vs Program's Defense + 1d10 or Netrunner's Interface + 1d10. Hit: 1d6 to the Program's REZ or directly to the Netrunner's brain (p201) |

Virus examples (p200): change Asp icons: DV6, 1 NET Action; disable a Black ICE until Virus destroyed: DV10, 2 NET Actions; make a Control Node malfunction: DV10, 2 NET Actions; delete all Black ICE permanently: DV12, 10 NET Actions; halve the Architecture's floors permanently: DV12, 10 NET Actions. Example: change all passwords every 5 min = DV12, 9 NET Actions (p200). A failed Virus Check means redoing all NET Actions (p200).

### 3.5 Net combat (p201, p204-205)

Attack roll: Interface + Program ATK + 1d10 (or Black ICE ATK + 1d10) vs Target's Interface + 1d10 (Netrunner) or Program/Black ICE DEF + 1d10. On a hit target suffers the Program's Effect. Class-restricted Programs (Anti-Personnel, Anti-Program) only work on their target type. (p201)
- Tie: assumed defender wins as in all Checks (p129).
- Derezzed: Program at 0 REZ stays loaded and running but useless; restoring costs 2 NET Actions (deactivate + activate). Destroyed Programs are erased and must be rebought. (p201)
- Each Program can be Activated only once per Round; a Rezzed Program cannot be Activated again until Deactivated (p201). Multiple copies stack unless stated (p201).
- Attackers automatically Deactivate after activation (p202).

Black ICE encounter and initiative (p205):
- Meeting Black ICE lying in wait: roll Interface + any SPEED bonus (e.g. Speedy Gonzalvez +2) + 1d10 vs ICE SPD + 1d10. If ICE wins, you (or a random active Program for Anti-Program ICE) suffer its Effect immediately. Either way it enters the Initiative Queue at the top (one above the current highest).
- On its Turns it attacks once: ATK + 1d10 vs Netrunner Interface + 1d10 (or Program DEF + 1d10 for Anti-Program). The GM plays all Black ICE.
- It chases through the whole Architecture until Derezzed or Slid away from. Anti-Program ICE keeps following even if you have no Programs Rezzed.
- Your own Black ICE: Activate as a NET Action either lying in wait on your current floor (not in combat) or during combat targeting a valid target (enters top of the Initiative Queue). To retarget: Deactivate then Activate again (2 NET Actions). Own Black ICE ignores anything but its one task. (p205)
- Demons enter the Initiative Queue at the top when they detect an intruder with an Observation Camera or when a Netrunner enters the Architecture (p212).

### 3.6 Programs (p202-204)

Classes: Booster (improves abilities while Rezzed), Defender (stops/reduces attacks while Rezzed), Attacker (damages/disables; auto-deactivates) (p202). Stats: ATK, DEF, REZ (hit points).

| Name | Class | ATK | DEF | REZ | Effect | Cost |
|---|---|---|---|---|---|---|
| Eraser | Booster | 0 | 0 | 7 | +2 to Cloak Checks while Rezzed | 20eb |
| See Ya | Booster | 0 | 0 | 7 | +2 to Pathfinder Checks | 20eb |
| Speedy Gonzalvez | Booster | 0 | 0 | 7 | Speed +2 | 100eb |
| Worm | Booster | 0 | 0 | 7 | +2 to Backdoor Checks | 50eb |
| Armor | Defender | 0 | 0 | 7 | Lower brain damage you take by 4; 1 copy running at a time, each copy once per Netrun | 50eb |
| Flak | Defender | 0 | 0 | 7 | Non-Black ICE Attacker ATK against you becomes 0; 1 copy at a time, once per Netrun | 50eb |
| Shield | Defender | 0 | 0 | 7 | Stops the first successful Non-Black ICE Program Effect that deals brain damage, then Derezzes; 1 copy at a time, once per Netrun | 20eb |
| Banhammer | Anti-Program Attacker | 1 | 0 | 0 | 3d6 REZ to Non-Black ICE Program or 2d6 REZ to Black ICE | 50eb |
| Sword | Anti-Program Attacker | 1 | 0 | 0 | 3d6 REZ to Black ICE or 2d6 REZ to Non-Black ICE | 50eb |
| DeckKRASH | Anti-Personnel Attacker | 0 | 0 | 0 | Enemy forcibly Jacked Out unsafely (suffers all Rezzed enemy Black ICE encountered) | 100eb |
| Hellbolt | Anti-Personnel Attacker | 2 | 0 | 0 | 2d6 direct to brain; deck and clothes burn unless insulated: 2 HP at end of each of their Turns until they spend a Meat Action to put out (no stacking) | 100eb |
| Nervescrub | Anti-Personnel Attacker | 0 | 0 | 0 | INT, REF, DEX each -1d6 (min 1) for 1 hour | 100eb |
| Poison Flatline | Anti-Personnel Attacker | 0 | 0 | 0 | Destroys one random Non-Black ICE Program on target's deck | 100eb |
| Superglue | Anti-Personnel Attacker | 2 | 0 | 0 | Target cannot progress deeper or Jack Out safely for 1d6 Rounds (unsafe Jack Out still allowed); once per Netrun per copy | 100eb |
| Vrizzbolt | Anti-Personnel Attacker | 1 | 0 | 0 | 1d6 direct to brain; target's total NET Actions next Turn -1 (min 2) | 50eb |

Note: Boosters/Defenders list REZ 7; Attackers list REZ 0 and DEF 0 (p203-204).

### 3.7 Black ICE (p204-207)

PER = difficulty to Slide away (Slide check is vs PER + 1d10); SPD = reaction speed on first encounter; ATK/DEF; REZ = HP. (p206)

| Name | Class | PER | SPD | ATK | DEF | REZ | Effect | Cost |
|---|---|---|---|---|---|---|---|---|
| Asp | Anti-Personnel | 4 | 6 | 2 | 2 | 15 | Destroys one random Program on the enemy deck | 100eb |
| Giant | Anti-Personnel | 2 | 2 | 8 | 4 | 25 | 3d6 direct to brain; forced unsafe Jack Out (suffer other Rezzed ICE met, not Giant) | 1,000eb |
| Hellhound | Anti-Personnel | 6 | 6 | 6 | 2 | 20 | 2d6 direct to brain; deck and clothes burn unless insulated, 2 HP per end of their Turn until a Meat Action to extinguish (no stacking) | 500eb |
| Kraken | Anti-Personnel | 6 | 2 | 8 | 4 | 30 | 3d6 direct to brain; cannot go deeper or Jack Out safely until end of their next Turn (unsafe Jack Out allowed) | 1,000eb |
| Liche | Anti-Personnel | 8 | 2 | 6 | 2 | 25 | INT, REF, DEX each -1d6 (min 1) for 1 hour | 500eb |
| Raven | Anti-Personnel | 6 | 4 | 4 | 2 | 15 | Derezzes one random Rezzed Defender, then 1d6 direct to brain | 50eb |
| Scorpion | Anti-Personnel | 2 | 6 | 2 | 2 | 15 | MOVE -1d6 (min 1) for 1 hour | 100eb |
| Skunk | Anti-Personnel | 2 | 4 | 4 | 2 | 10 | -2 to all Slide Checks until this Program is Derezzed; one Netrunner per Skunk, multiple Skunks stack | 500eb |
| Wisp | Anti-Personnel | 4 | 4 | 4 | 2 | 15 | 1d6 direct to brain; total NET Actions next Turn -1 (min 2) | 50eb |
| Dragon | Anti-Program | 6 | 4 | 6 | 6 | 30 | 6d6 to a Program; if enough to Derez it, Destroyed instead | 1,000eb |
| Killer | Anti-Program | 4 | 8 | 6 | 2 | 20 | 4d6 to a Program; Destroys instead of Derezzing | 500eb |
| Sabertooth | Anti-Program | 8 | 6 | 6 | 2 | 25 | 6d6 to a Program; Destroys instead of Derezzing | 1,000eb |

Black ICE classes: Anti-Personnel (hunts Netrunners), Anti-Program (hunts Rezzed Programs), Demon (operates Control Nodes; too big for decks) (p205).

### 3.8 Lethal and brain-damage effects (p198-207)

- Brain damage (Zap 1d6, Hellbolt 2d6, Vrizzbolt 1d6, Giant/Kraken 3d6, Hellhound 2d6, Raven/Wisp 1d6) is dealt directly to the Netrunner's brain, i.e. their HP (p201, p204-207).
- Armor Program lowers brain damage by 4; Shield blocks first brain-damage Effect; Flak zeroes Non-Black ICE Attacker ATK (p203).
- Jack Out unsafely (DeckKRASH, Giant, leaving range): suffer all Rezzed/encountered enemy Black ICE on the way out (p198, p204, p206).
- Fire: 2 HP per end of Turn until Meat Action to extinguish (Hellbolt, Hellhound) (p204, p206).
- Stat damage: Nervescrub/Liche lower INT/REF/DEX for 1 hour (psychosomatic, not permanent); Scorpion lowers MOVE (p204, p207).
AMBIGUITY (p201, p206): the book says "direct to brain" and never states that it ignores or is reduced by armor, or explicitly that 0 HP puts the runner into Mortally Wounded/Death Save; implement as HP damage bypassing armor SP, with normal Wound State rules (p186).

### 3.9 NET Architectures (p209-218)

Metaphor: an elevator; each floor holds one thing behind a door; you must open every floor in order (no skipping); you can go down any number of floors per Turn unless blocked by a Password or other obstruction (p209). Black ICE attacks as soon as its door is opened unless you win the speed contest, then enters the top of the Initiative Queue (p209).

Example architecture: floors 1 File DV6, 2 Password DV8, 3 Control Node (cameras) DV10, 4 Password DV8, 5 Asp, 6 Control Node (security door) DV10, 7 Hellhound (p209).

**Step 0 - Difficulty Rating (p210)**

| | Basic | Standard | Uncommon | Advanced |
|---|---|---|---|---|
| Password/File/Control Node DV | 6 | 8 | 10 | 12 |
| Interface of a Netrunner with a fighting chance | 2 | 4 | 6 | 8 |
| Interface of a Netrunner who might die before the bottom | N/A | 2 or less | 4 or less | 6 or less |

**Step 1 - Shape (p210)**: roll 3d6 = total floors. Roll d10: 7+ means a branch; roll again, repeat until a roll under 7. Split floors between main branch and branches freely. Cannot branch until after floor 2 of the main branch. One branch must be longest so there is a defined bottom (where a Virus can be left).

**Step 2 - Fill (p210-211)**: top-down. First two floors use the Lobby table (re-roll duplicate Programs or Passwords); other floors use the Difficulty column rolled on 3d6 (re-roll duplicate Programs and Passwords). Deeper floors tend toward more Files/Control Nodes. Custom: swap floors, replace a Program with one of equal cost, or borrow a floor from one Difficulty higher as a "Boss Floor".

Lobby (floors 1-2), roll 1d6 (p211):

| Roll | Floor |
|---|---|
| 1 | File DV6 |
| 2 | Password DV6 |
| 3 | Password DV8 |
| 4 | Skunk |
| 5 | Wisp |
| 6 | Killer |

All other floors, roll 3d6 (p211):

| 3d6 | Basic | Standard | Uncommon | Advanced |
|---|---|---|---|---|
| 3 | Hellhound | Hellhound x2 | Kraken | Hellhound x3 |
| 4 | Sabertooth | Hellhound, Killer | Hellhound, Scorpion | Asp x2 |
| 5 | Raven x2 | Skunk x2 | Hellhound, Killer | Hellhound, Liche |
| 6 | Hellhound | Sabertooth | Raven x2 | Wisp x3 |
| 7 | Wisp | Scorpion | Sabertooth | Hellhound, Sabertooth |
| 8 | Raven | Hellhound | Hellhound | Kraken |
| 9 | Password DV6 | Password DV8 | Password DV10 | Password DV12 |
| 10 | File DV6 | File DV8 | File DV10 | File DV12 |
| 11 | Control Node DV6 | Control Node DV8 | Control Node DV10 | Control Node DV12 |
| 12 | Password DV6 | Password DV8 | Password DV10 | Password DV12 |
| 13 | Skunk | Asp | Killer | Giant |
| 14 | Asp | Killer | Liche | Dragon |
| 15 | Scorpion | Liche | Dragon | Killer, Scorpion |
| 16 | Killer, Skunk | Asp | Asp, Raven | Kraken |
| 17 | Wisp x3 | Raven x3 | Dragon, Wisp | Raven, Wisp, Hellhound |
| 18 | Liche | Liche, Raven | Giant | Dragon x2 |

**Step 3 - Fit to world (p210-211)**: every File/Control Node needs a reason to exist; someone important knows the Passwords. Control Nodes may be non-combat (cameras, sprinklers, locks, ...). Active Defenses need a Demon present to run them; Imps are the commonplace default.

### 3.10 Files, Passwords, Control Nodes (p198-199, p209-210)

- Password: obstruction with a DV; defeated by Backdoor (roll vs DV) or by knowing it; blocks movement and Pathfinder visibility (p199-200).
- File: data; Eye-Dee identifies it (some have a DV); copying it into the deck is free (not a NET Action) (p198-199).
- Control Node: has a DV; Control takes it; each connected device needs another NET Action; once per Turn per Node (p199).

### 3.11 Demons and Defenses (p212-216)

Demons are Black ICE Intelligent Systems: trigger-based AI. They have only Zap (self-defense) and Control; cannot run Programs or Black ICE; unimpeded by Passwords; always aware of intruders; win Speed automatically; cannot be Slid away from; no free first hit; no SPD/PER/DEF (defend with Interface + 1d10). On their Turn they use NET Actions on Control Node triggers first, leftover on Zap. Each Node still once per Turn. They enter the Initiative Queue top on detection (p212).

| Demon | REZ | Interface | NET Actions | Combat Number | Cost (to buy) |
|---|---|---|---|---|---|
| Imp | 15 | 3 | 2 | 14 | 1,000eb (V. Expensive) |
| Efreet | 25 | 4 | 3 | 14 | 5,000eb (Luxury) |
| Balron | 30 | 7 | 4 | 14 | 10,000eb (Super Luxury) |
(p212, p218). Combat Number is STAT + Skill; add 1d10 for attack and defense with controlled drones/turrets.

Defense types: **Active** (mobile robots; need Demon or Netrunner to stay operational), **Emplaced** (immobile weapons; own Control Node; act on own Combat Number + 1d10 when uncontrolled; cannot dodge), **Environmental** (built into surroundings; toggle ON/OFF only, activate exactly on trigger). Uncontrolled Defenses can be countered with Electronics/Security Tech (DV and time listed); once countered they can be controlled remotely within 6m of an access point by an Agent using an Action like Control (p213-215). A Netrunner controlling one attacks/defends with their own Skills (p213-214).

Active Defenses (p213) - trigger: target enters area without proper pass/badge.

| Type | Armament | Counter (Elec/Sec Tech) | Data |
|---|---|---|---|
| Air Swarm Drone Cloud | Treat as one entity with Very Heavy Melee Weapon | DV17, 5 min | MOVE 8, 15 HP |
| Ground Drone | 2 of: Very Heavy Pistol (8 AP), SMG (30 basic), Observation camera | DV21, 5 min | MOVE 4, 30 HP |
| Large Air Drone | 2 of: Dartgun (8 poison), VH Pistol (8 AP), camera | DV21, 5 min | MOVE 6, 20 HP |
| Mini Air Drone | 1 of: Dartgun, VH Pistol, camera | DV17, 5 min | MOVE 6, 15 HP |
| Spider Walking Drone | 2 of: Grenade Launcher (2 teargas), Very Heavy Melee, Heavy SMG (40), camera | DV21, 5 min | MOVE 4, 40 HP |

Emplaced Defenses (p214):

| Type | Effect | Counter | Data |
|---|---|---|---|
| Automated Blood Swarm | Single attack on all in room: DV15 Resist Torture/Drugs or 3d6 direct to HP (armor not ablated); gas filters block | DV21, 5 min | trigger: enters without badge |
| Automated Melee Weapon | Very Heavy Melee Weapon, e.g. water cutter | DV17, 5 min | Combat Number 14, 25 HP; attacks until all dead/out of range/badge shown |
| Automated Turret | Ranged weapon: Assault Rifle (25), Flamethrower (4 incendiary), Dartgun (8), VH Pistol (8 AP), or Heavy SMG (40) | DV17, 5 min | Combat Number 14, 25 HP |

Environmental Defenses (p215-216): all have Perception DV17 to spot unless noted.

| Type | Effect | Counter | HP/Data |
|---|---|---|---|
| Observation Cameras | Low-light/IR/UV, report to Demon; trigger: enters room | DV9, 1 min | 5 HP; see room/corridor |
| Tanglefoot Flooring | MOVE -1d6 until carpet destroyed or leave | DV13, 1 min | 20 HP |
| Electrical Flooring | 6d6 to body (armor reduces, not ablated); re-shocked at end of each their Turn until off | DV13, 1 min | 20 HP |
| Laser Grid | Treated as Very Heavy Melee hit to body; cross safely with DV17 Contortionist | DV17, 5 min | trigger: enters area or moves 2m |
| Tip-floor | Fall into pit; DV15 Athletics to avoid (none if Grapple Hand/Gun); 6d6 to body (armor reduces) | DV13, 1 min | - |
| Goop | MOVE -2d6 until destroyed or escape | DV13, 1 min | 10 HP |
| Ceiling/Wall Punchers | 6d6 to body (armor reduces) | DV13, 5 min | 20 HP |
| Slip-floor | Movement needs DV15 Athletics or fall Prone | DV13, 1 min | 10 HP |
| Stun Panels | Within 2m of panel: DV15 Resist Torture/Drugs or Damaged Eye and Damaged Ear for 1 minute (no bonus dmg); area 10m x 10m | DV13, 1 min | 5 HP |
| Sleep Gas Elevator | Seals space, top of Initiative; DV13 Resist Torture/Drugs or Unconscious until damaged or woken; defeat by reducing HP to 0 | DV17, 5 min | 60 HP |

### 3.12 Buying an Architecture (p217-218)

| Floors | Max Control Nodes | Portable | Cost per floor |
|---|---|---|---|
| 3-6 | 2 | Yes | 1,000eb (V. Expensive) |
| 7-12 | 3 | No | 5,000eb (Luxury) |
| 13-18 | N/A | No | 10,000eb (Super Luxury) |

Floors cannot be added after purchase. Sold only at a Night Market with Personal Electronics run by a Fixer of Rank 4+ (p217).

Per floor feature price (Password/File/Control Node): DV6 500eb, DV8 1,000eb, DV10 5,000eb, DV12 10,000eb (p217). Black ICE priced as for Cyberdecks; 2 on one floor = 2x each, 3 = 3x each. Demons: one per six floors, no doubling (p218). Defense price by counter DV: DV9 500eb, DV13 1,000eb, DV17 5,000eb, DV21 10,000eb (p218). Example: 4-floor, 13,500eb total (p218).

AMBIGUITY (p217): 13-18 floor Architectures list no Control Node maximum (N/A).
