# Cyberpunk Red × XCOM-style Tactical Game  
## Design Specification  
**Personal Project | Godot | 3D with Pixel-Art Shader**

### Overview
A turn-based tactical game that blends Cyberpunk Red tabletop rules with XCOM 2-style crew management and mission structure. The emphasis is on street-level edgerunner play: a crew of Roles taking on parameterized gigs in Night City. Core fantasy is Cyberpunk Red crew + gigs + roles, supported by XCOM-like tactics, light meta progression, and deep procedural systems.

**MVP Path**: Systems-first foundation (procedural maps + network architectures, light-grid combat resolution, data structures for Roles/skills/cyberware) → user acceptance gate → core tactical loop (Solo + Netrunner, basic gigs, skill checks, destructible cover, simple progression) → expand.

---

### Core Fantasy & Structure
- Street-level Cyberpunk Red experience: play a crew of edgerunners taking on gigs.
- XCOM-like tactical combat and light meta progression.
- Emphasis on roles, gig types, and emergent street-level storytelling rather than a heavy campaign map.
- Themes: unethical corporations, experimental technologies and their implications, the seeming insignificance of life in the city.

---

### Tactical Combat
- **Grid**: Simple fixed-size tile grid. Visible only when planning a Move action (for immersion).
- **Action Economy**: Cyberpunk Red rules as written — one Move + one Action per turn.
- **Cover**: Binary (full or none). No partial cover. Cover is destructible. Separate from worn armor.
- **Resolution**: Direct Cyberpunk Red skill checks (stats + skill + modifiers). Displayed as percentage chances (BG3-style).
- **Initiative**: Full CPR initiative (REF + modifiers). Strict turn order. New combatants (reinforcements) roll and join the order immediately.
- **Armor**: Full CPR fidelity — Stopping Power (SP) with ablation on damaging hits. Separate head and body armor. SP and ablation visible in UI.
- **Aimed Shots**: Full CPR-style. Players can aim for head or other locations (higher DV). Head hits use head SP and head Critical Injury tables. Percentages update live.
- **Weapons**: Full CPR weapon stats (damage dice, ROF, autofire, range DVs, etc.). Build incrementally if needed, but combat largely uses rules as written. Percentages update by fire mode.
- **Variety**: Comes primarily from cyberware, weapons, gear, Role Abilities, and skills.
- **Reinforcements**: Triggered by conditions (alarm level, noise, failed stealth, gig parameters). Spawn at logical map entrances, roll initiative, and join the fight. Support for NCPD, Trauma Team, MaxTac (carefully scoped).
- **Clocks and plot twists** (Single Player Mode p.25-26, p.75-76): a hidden-length detection clock (visible dice pips on the round tab) adds pressure before the alarm on stealth gigs, and a Tech or Netrunner can win time back; about one gig in four hides a plot twist that springs mid-gig. Details: docs/rules/solo-mode.md.
- **Morale** (Single Player Mode p.20-21): enemies break at stress points (Seriously Wounded, half their side down, their leader down) on a 1d10 by tier, and flee off the map or surrender. Details: docs/rules/solo-mode.md.

---

### Roles & Character Identity
- One Role per character (no multiclassing).
- Role Ability is the major signature power; improves with Role Rank.
- Short, focused skill tree per Role (XCOM-style branching choices) for specialization, perks, and alternative uses of the Role Ability.
- Skills and cyberware remain independent and important.
- **Implementation Priority**:
  1. Solo + Netrunner
  2. Medtech
  3. Tech
  4. Remainder optional/later

---

### Character Progression
- Hybrid model:
  - Role Rank gates tiers of the Role Ability.
  - Short skill tree per Role for specialization.
  - Independent skill investment (IP from gigs).
  - Cyberware and gear.
- Lightweight overall; avoid bogging the player down.

---

### Character Creation & Crew
- Full Cyberpunk Red flavor (lifepath elements, starting skills, gear, cyberware, Role).
- Process kept lightweight — primarily recruiting existing or procedurally generated characters rather than deep manual creation.
- Start with a small crew; recruit more over time via fixers, gigs, and base facilities.
- Avoid heavy item selection during creation.

---

### Gigs & Mission Structure
- Hybrid: Core set of designed gig templates / job types that are heavily parameterized (locations, targets, opposition, twists).
- Plus occasional larger story gigs.
- Fixers offer a rotating selection.
- Strong focus on procedural systems generating realistic, dynamic cyberpunk environments.

---

### Procedural Environments & Maps
- Deep procedural systems for tactical maps and surrounding context.
- Night City neighborhood layout is static (placement is fixed).
- **Map Generation**: More generative / algorithmic layout (fewer pre-made rooms). Algorithms place walls, floors, cover, vertical connections guided by parameters (density, security level, verticality, faction presence). Research published methods.
- **Verticality**: Multi-level support from the start (multiple floors, stairs/elevators/ladders, elevation affecting movement, LOS, and cover).
- **Interactive Elements**: Procedural placement of hackable objects, destructible cover, hazards, etc., generated in realistic ways.
- **Emergent Systems** (carefully scoped):
  - Alarm levels.
  - Reinforcements (NCPD, Trauma Team, MaxTac).
  - Civilians.
  - Going loud or failing checks can escalate the situation.
- Interactive environment systems that reward creative use of roles, skills, cyberware, and gear.

---

### Network Architectures & Netrunning
- Full CPR Architecture system.
- Netrunner can jack in and take actions in cyberspace or meatspace according to CPR rules, interleaved with tactical turns.
- **Generation**: Tightly coupled — placing hackable objects simultaneously builds the corresponding Architecture of nodes. Digital map reflects physical layout logically.
- **Complexity**: Enhanced but familiar. Keep core CPR node types and Interface actions, but add more nodes, branching paths, layered security, and environmental feedback. Architectures can be more complex than tabletop RAW while still resolving quickly in a video game. Mostly an expansion rather than a rewrite.

---

### Meta Progression & Between-Gig Structure
- Moderate XCOM-style home base (apartment complex, warehouse, or similar).
- A few rooms (armory, workshop, intel/fixer network, medical, etc.). *Owner ruling (core-book systems
  only): rooms are places and screens, with no levels, costs or effects; safehouse storage holds
  everything the crew owns.*
- Manage crew, assign downtime actions, track reputation.
- Unlocks better gear or gig opportunities through upgrades and relationships.
- **Downtime**: Focused and quick. Short phase after gigs (or every few) to recover injuries, install cyberware, train skills/Role Rank, or work on base upgrades. Reputation updates. Get back to gigs without a long management sim.

---

### Injury, Death & Consequences
- Permadeath (permanent or very costly to reverse).
- Plus Cyberpunk Red Critical Injuries (triggered on damage dice, apply ongoing penalties, require treatment).
- Medtech characters meaningfully reduce risk or recovery time (base facilities no longer give bonuses:
  owner ruling, core-book systems only).
- Death Saves and wound states follow CPR principles. HOUSE-RULE (owner, for pace): only the crew, a
  rescue's captive and Trauma Team cardholders roll Death Saves; other NPCs flatline below 1 HP.

---

### Cyberware, Humanity & Gear
- Full CPR fidelity: Cyberware costs Humanity (cyberpsychosis risk), provides mechanical benefits, requires installation.
- Installation time simplified.
- Gear bought at the book's Night Market (p337-339) into safehouse storage, then equipped from there.
  (Salvage of downed enemies' gear was removed: the core book has no rule for it. Bodies can be
  searched instead, by Single Player Mode's corpse-loot tables at lower rates than the book:
  docs/rules/solo-mode.md.)
- UI keeps selection from feeling overwhelming.
- **Economy**:
  - Gigs pay eb based on difficulty, risk, and reputation.
  - Spend on gear, cyberware, medical treatment, base upgrades, recruitment.
  - Loot supplements income.
  - Money is a real constraint but not punishingly scarce.
  - ~~Items < 500 eb: buy on demand. Items ≥ 500 eb: require a fixer. Reputation can earn invites to
    night markets.~~ Superseded (owner ruling, core-book systems only): list prices, no markup, no
    Reputation gate.
- **Night Markets**: the book's generator (p338-339): each market rolls two categories of goods and
  what's on the shelves, each item in a limited stock that sells off day by day; a new one sets up when it has sold out (house rule). The fixer always has a few
  staple consumables (owner's design).
- **Humanity & Cyberpsychosis**:
  - Full pressure. Low Humanity imposes penalties.
  - At very low Humanity, risk of episodes (loss of control, forced aggression) that can trigger in or out of combat.
  - Episodes are dangerous and can harm the crew or mission.
  - Recovery via the book's therapy (p229-230: a Medtech, a week, a Medical Tech check); meaningful time/opportunity cost.

---

### Reputation
*Superseded (owner ruling, core-book systems only): Reputation is per character (p193) and only the
fixer board reads it; no per-fixer score, no market access by Reputation, no campaign heat.*
- Simple per-fixer reputation score.
- Raised by successful/clean jobs or helping the fixer; lowered by failures, excessive collateral, or betrayals.
- Higher reputation unlocks better-paying or more interesting gigs from that fixer, plus occasional unique offers and night market access.

---

### Narrative Structure
- Light framing.
- Most gigs are self-contained with short fixer briefs, procedural complications, and outcome-based consequences (reputation, money).
- Larger story moments are occasional and mostly emerge from player choices and procedural systems.
- Themes: unethical corporations, experimental tech and implications, insignificance of life in the city.

---

### Visual Style & Presentation
- **Aesthetic**: True pixel-art look on 3D models via strong pixelation/pixel-art shader (or post-process). Helps cover imperfect models. Limited palette feel, hard edges, deliberate pixel scaling.
- **Lighting**: Very realistic, inspired by Cyberpunk 2077. Lots of neon with light spill and bloom. High contrast. Critical combat information must always read clearly.
- **Environments**: Existing asset packs + pixel shader.
- **Characters, Equipment, Effects**: Explore code-generated / AI-coding-assistant modular assets. Retargeted animations (Mixamo-style) on humanoid models.
- **Animations (early set)**: Idle, move, shoot/aim, melee, hit react, death/downed, jack-in, plus reload, take cover, use object/terminal, stunned/crit reaction. Modular attachments (weapons, cyberware) are simple.
- **VFX**: Minimal high-impact, code-generated set integrated with lighting:
  - Muzzle flash + dynamic light
  - Hit impact / spark
  - Blood splatter / stronger crit feedback
  - Destruction debris/dust
  - Plus 1–2 cyberpunk flavor effects (electrical spark on hack/disable, glitch/hologram flicker, or enhanced crit bloom)
- **UI**: Minimalist high-contrast overlay (hit percentages, action economy, cover status, critical injury warnings, Role Ability states, SP/ablation). Cyberspace is a distinct but quickly switchable view or overlay.
- **Shader Approach** (to be finalized in implementation): Prefer strong post-process pixelation that works with dynamic lighting and bloom; expose controls for pixel scale, contrast, and bloom so readability is maintained.

---

### Technical & Pipeline Notes (Godot)
- 3D with pixel-art shader.
- Systems-first: clean data structures for characters (stats, skills, Role Rank, Role Ability, cyberware, Humanity), weapons (full CPR fields), cover objects (HP/destruction), network nodes, initiative/turn management, and procedural generation.
- Light grid only shown during move planning.
- Procedural map generation is algorithmic; research published methods for urban/interior layout and graph/network generation.
- Asset pipeline: asset-pack environments; code/AI-assisted modular characters, weapons, cyberware; retargeted humanoid animations; code-generated VFX.
- Combat largely rules-as-written from Cyberpunk Red, with noted enhancements only where they improve video game play (especially richer but still fast Net Architectures).

---

### Open / Future Considerations
- Exact procedural generation algorithms (after research).
- Precise tuning of Humanity thresholds, episode frequency, and recovery rates.
- Full list of Role skill-tree nodes (after Solo + Netrunner prototypes).
- Detailed night market and fixer sourcing UX.
- Final pixel-shader implementation and readability tuning at tactical camera distances.
- Audio and additional atmosphere.
- Expansion beyond core Roles and gig templates.

---

*This document captures the design decisions made through iterative Q&A. It is a living spec for a personal Godot project.*
