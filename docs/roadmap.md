# Roadmap

Check-ins (🔶) are where work pauses for a user decision or review.

| # | Milestone | Status | Check-in |
|---|---|---|---|
| M0 | Skeleton: project, test runner, conventions | ✅ done | — |
| M1 | Rules core (headless): checks, skills, initiative, weapons/ROF/autofire, SP + ablation, aimed shots, damage, Critical Injuries, death saves, Humanity | ⏳ next | 🔶 rules review + any values that need the PDF |
| M2 | Procedural generation: multi-floor maps, cover, hackables, coupled Net Architectures; debug renders | — | 🔶 do layouts feel right? |
| M3 | Playable greybox: Solo vs Netrunner on a generated map, move-only grid, % UI, destructible cover | — | 🔶 user plays locally |
| M4 | Visual pass: pixel post-process, neon lighting/bloom, VFX, tuning controls | — | 🔶 aesthetic review on user's GPU |
| M5+ | Gigs/fixers, base & downtime, progression, Medtech, Tech, reinforcements, cyberpsychosis | — | per feature |

## Decisions log
- Godot 4.7.2, GDScript, Forward+ renderer.
- Custom minimal test runner instead of an addon (no external dependency, fast headless).
