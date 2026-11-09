# Single Player Mode: morale and corpse loot

Distilled from R. Talsorian's *Cyberpunk RED: Single Player Mode* (cited `SPM p.<printed page>`).
Numbers and short paraphrases only. Where the game departs from the book the line says HOUSE-RULE.

## 1. Morale (SPM p.20-21; table reprinted p.32)

The opposition doesn't fight to the last body. At a **stress point** an NPC rolls **1d10**; at or
under its mentality's number it stops fighting (it flees or surrenders), above it fights on.

| Mentality (book) | Our NPCs | Ends the fight on |
|---|---|---|
| Lost to violence / fully dedicated | Boss tier, the Cyberpsycho block, anyone with a combat drug in their system, MaxTac | 1-2 |
| Experienced (hardened ganger, elite security) | Mini Boss | 1-4 |
| Trained (experienced ganger, regular security) | Lieutenant (Hardened Lieutenants too) | 1-6 |
| Inexperienced (newbie ganger or security) | Hardened Mook | 1-8 |
| Unsure streetrat (cannon fodder) | Mook | 1-9 |

The book lets the GM pick the stress point (half the group down, Seriously Wounded, a round
count). The game uses three, each rolled **at most once per unit**:

- **wounded:** the unit reaching Seriously Wounded;
- **half:** more than half of its side down (dead, out cold, Mortally Wounded, or already quit:
  HOUSE-RULE, the book says incapacitated or dead);
- **leader:** its side's top tier above Mook down (all of them, if there are two).

Who rolls: alerted units on guard-run sides (the opposition, backup, police, a free-for-all's
gangs); Trauma Team only once the crew has shot at them. Never the assassination mark (it already
runs), turrets, bystanders, the crew or a captive. No calming down (HOUSE-RULE).

**Flee or surrender** (HOUSE-RULE): a unit that breaks surrenders when a standing foe can see it
within 6 squares, when it's held or prone, or when it has no way off the map; otherwise it runs
(Move + Run a turn) for the nearest map exit and is gone there. Trauma Team never surrenders.

- A surrendered unit drops its weapons, moves to a side of its own that is neutral to everyone,
  takes no more turns, and can be searched (and its keycard taken). The crew can still shoot it;
  the attack preview says so.
- A fleeing unit no longer counts as opposition and never fights back. **HOUSE-RULE:** a guard who
  gets off the map while the alarm is below 2 raises it.
- "Put every hostile down" (eliminate, and every other job's clear-the-site win) counts both as done.

Code: `src/tactical/morale.gd`, `Encounter.surrender / start_flight / flee_out`, `AI.flee`.

## 2. Corpse loot (SPM p.65-70)

Three d100 tables of what someone carries beyond their stat block: **Streetrat** (p.65-66),
**Edgerunner** (p.67-68), **Corporate** (p.69-70). Data: `data/rules/corpse_loot.json` (our own
2-5 word label per row). The book gives every body a row; the game is stingier (owner).

**Search Body**: an Action, beside (or on) a body that is down or surrendered, once per body.

**Rates (HOUSE-RULE).** First 1d6 for whether there's anything worth taking, then the table:

| Body | Anything on 1d6 | Chance |
|---|---|---|
| Mook | 1-2 | 1 in 3 |
| Lieutenant | 1-3 | 1 in 2 |
| Mini Boss, Boss, the assassination mark | 1-4 | 2 in 3 |

A row the game can't play (`unmodelled`: junk, flavour, gear we don't model) is re-rolled, so a find
is always something. Modelled rows per table: Streetrat 24, Edgerunner 44, Corporate 38.

**Which table (HOUSE-RULE).** By the faction the body stood with: corp and service (security,
contractors, Trauma Team) Corporate; police (NCPD, MaxTac) Edgerunner; gangs, criminals and anyone
else Streetrat for Mooks, Edgerunner for Lieutenants and up. The mark: Corporate if a corp's, else
Edgerunner.

**What a find is.**

- **eb:** cash and chips at face value; a valuable (gems, wine, programs, a painting) goes to a
  fence at half (HOUSE-RULE).
- **item:** storage items the Night Market could sell (`NightMarket.on_sale`): weapons (poor or
  excellent where the book says so), armour (ablated where it says so), drugs, an AP grenade,
  loose cyberware the ripperdoc fits, a Techscanner.
- **keycard:** used at once. A janitor's badge opens the site's lowest locked zone, an exec's
  office keycard every lock.
- **NET login code:** opens one Password on this site's NET without a roll (HOUSE-RULE).
- **lead:** a plot hook (meet, map, cache, blueprint, heist plans, a fixer's IOU, a Night Market
  invite...) kept in the campaign's lead list for later follow-up offers.

**Going home.** Finds go home with whoever found them: on a win or a withdrawal, what the crew who
got out carry; nothing when the whole crew went down; nothing a fallen finder carried.

Code: `src/tactical/corpse_loot.gd`, `Encounter.search_body`, `Campaign._take_loot`, `Campaign.leads`.
