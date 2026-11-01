# Roadmap

Check-ins (🔶) are where work pauses for a user decision or review.

| # | Milestone | Status | Check-in |
|---|---|---|---|
| M0 | Skeleton: project, test runner, conventions | ✅ done | — |
| M1 | Rules core (headless): checks, skills, initiative, weapons/ROF/autofire, SP + ablation, aimed shots, damage, Critical Injuries, death saves, Humanity, cyberware, Solo Combat Awareness, recruits | ✅ done (reviewed) | ✅ |
| M2 | Procedural generation: multi-floor maps, cover, hackables, coupled Net Architectures (+ Netrunner Interface rules); debug renders | ⏳ next | 🔶 do layouts feel right? |
| M3 | Playable greybox: Solo vs Netrunner on a generated map, move-only grid, % UI, destructible cover | — | 🔶 user plays locally |
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
