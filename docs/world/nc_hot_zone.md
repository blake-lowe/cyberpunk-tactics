# The Hot Zone

What is left of Night City's original corporate centre after the nuke (NC2045 p.90-91): blocks of ruins coated
in cancer dust, where radiation, toxins, unstable towers, sinkholes and falling glass kill more than the people
do. No City Manager: the Council nominally oversees it, Night Corp pays for most of the cleanup and nomads do
the work. NCPD never sets foot inside; armoured AVs snipe anyone firing a gun and gas scavver turf wars that
threaten to spill out.

District-level hooks (p.91): a Charter Hill lowlife sells AV "hunting" tours over the squatters; Zhirafa's new
heavy equipment keeps failing (sabotage or metal fatigue); Maelstrom and the Reckoners clash over Reckoner
recruiting in squatter camps. Location #4's responder is printed as "??" (faction id `unknown`); #10's as
"Toggle's Drones & Patrons" (`patrons`). Stat blocks (p.95): Scavver Mook, Lightning Cats Mook (Hardened Mook).

## District

```world city.districts.hot_zone
{
	"name": "The Hot Zone",
	"region": "island",
	"manager": null,
	"population": "hundreds, maybe thousands, none by choice: refugees, scavvers, streetrats and the desperate, plus gangers and worse who like it there",
	"security_code": {"n": 2, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": 10,
	"provider": "ncpd",
	"gangs": ["lightning_cats", "maelstrom", "reckoners", "scavvers"],
	"ncart": [],
	"profile": "hot_zone",
	"look": ["nuked ruins", "toppled towers", "cancer dust", "rubble", "no neon", "sinkholes"],
	"history": "The old corporate centre, wrecked by the nuke in the 4th Corporate War; shrinking each year as Night Corp-funded nomad crews rebuild inward from The Glen, Little Europe and the Upper Marina, while Maelstrom, scavvers and Reckoners sabotage the reclamation.",
	"cite": "NC2045 p.90-95"
}
```

## Locations

### #1 Ashcroft Hotel

An abandoned hotel near the centre of the Zone, split down the middle but held up by its two leaning wings and still mostly roofed.

```world locations.locations.hot_zone_1
{
	"name": "Ashcroft Hotel",
	"district": "hot_zone",
	"number": 1,
	"type": "ruin",
	"owner": "maelstrom",
	"owner_name": "Maelstrom's head scavver",
	"security_code": {"n": 9, "faction": "maelstrom", "intensity": "medium", "hardened": true},
	"utility_code": 6,
	"npcs": [],
	"hooks": [
		{"text": "Maelstrom's head scavver has made it a trapped, guarded headquarters; meddling with it brings Maelstrom down on you.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit"],
	"interior": "Two wings leaning into each other under a mostly intact roof; booby-trapped and guarded.",
	"cite": "NC2045 p.93"
}
```

### #2 The Crater

The unrecognisable remains of Arasaka's old Night City HQ, a rubble heap 50 m deep that the Reckoner doomsday cult treats as holy ground.

```world locations.locations.hot_zone_2
{
	"name": "The Crater",
	"district": "hot_zone",
	"number": 2,
	"type": "ruin",
	"owner": "reckoners",
	"owner_name": "The Reckoners",
	"security_code": {"n": 6, "faction": "reckoners", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Rumours of treasure persist; doombas hunt for tunnels into the sub-sub-basements.", "gigs": ["data_theft"]},
		{"text": "Reckoner \"prophets\" chant around the clock, guarded by cancer-ridden \"pure souls\" with SMGs.", "gigs": ["gang_hit"]}
	],
	"gigs": ["data_theft", "gang_hit"],
	"interior": "50 m deep rubble pit, surface picked clean; possible tunnels to buried sub-basements; Reckoner guards.",
	"cite": "NC2045 p.93"
}
```

### #3 Crisis Center

The old Trauma Team and Crisis Medical neighbours, dropped into one tangled, fire-gutted mass by something (an AV crash, orbital strike or soil liquefaction, depending who you ask).

```world locations.locations.hot_zone_3
{
	"name": "Crisis Center",
	"district": "hot_zone",
	"number": 3,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 2, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Medical tech, radioactive material and drug caches make it one of the most popular and violent scavving sites.", "gigs": ["gang_hit", "data_theft"]}
	],
	"gigs": ["gang_hit"],
	"interior": "Two collapsed medical facilities fused into one burned ruin.",
	"cite": "NC2045 p.93"
}
```

### #4 Dark Zone One

A site no drone can map and where unseen snipers kill anyone on foot; Raven Microcyb, EBM and Infocomp all had offices here.

```world locations.locations.hot_zone_4
{
	"name": "Dark Zone One",
	"district": "hot_zone",
	"number": 4,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 11, "faction": "locals", "responder": "unknown", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The tight security suggests a corp is digging under Infocomp's remains; an intact cache from the dead info broker could upset the whole corporate balance of power.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": ["data_theft"],
	"interior": "Ruins of corporate offices; mysterious snipers; drone imagery jammed or distorted.",
	"cite": "NC2045 p.93"
}
```

### #5 The Dump

The largest staging field for sorting Hot Zone wreckage before removal, by the Old Japantown border; the poorest squatters camp here and pick the heaps in relative peace.

```world locations.locations.hot_zone_5
{
	"name": "The Dump",
	"district": "hot_zone",
	"number": 5,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 4, "faction": "maelstrom", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Wreckage heaps and choking crater dust; squatters shelter in surviving low-rises.",
	"cite": "NC2045 p.93"
}
```

### #6 Eurasiabank Plaza

The hottest site in the Zone: the bank tower sank straight down, driving six floors underground before its top half crumbled.

```world locations.locations.hot_zone_6
{
	"name": "Eurasiabank Plaza",
	"district": "hot_zone",
	"number": 6,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 2, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Bank rumours sometimes do lead to hard currency or gold; the sunken floors hold drowned vaults, server rooms and file stores, and some explorers never come back.", "gigs": ["data_theft", "rescue"]}
	],
	"gigs": ["data_theft", "rescue"],
	"interior": "Six sunken, partly flooded but passable floors, far more extensive than expected: vaults, server rooms, file stores.",
	"cite": "NC2045 p.93"
}
```

### #7 Graceland Medical

The Jellical Inn, an old cat-cosplay hotel half-crushed by the Barbican Building, held by the Lightning Cats; in its garage lives Father Grace, the Zone's beloved Elvis-preaching free medic.

```world locations.locations.hot_zone_7
{
	"name": "Graceland Medical",
	"district": "hot_zone",
	"number": 7,
	"type": "gang_base",
	"owner": "lightning_cats",
	"owner_name": "The Lightning Cats",
	"security_code": {"n": 10, "faction": "lightning_cats", "intensity": "light", "hardened": true},
	"utility_code": 5,
	"npcs": ["Father Grace (Medtech 4)", "Bengal Khan (Solo 6)"],
	"hooks": [
		{"text": "No one knows how Father Grace pays for his meds; CityMed has no record of him or his rig.", "gigs": ["data_theft"]}
	],
	"gigs": ["gang_hit", "data_theft"],
	"interior": "Old themed hotel under fallen tower wreckage; an armoured ex-CityMed mobile clinic in the garage.",
	"cite": "NC2045 p.94"
}
```

### #8 The N54

The former Network 54 building, the tallest structure still standing in the Zone, which climbers race to tag.

```world locations.locations.hot_zone_8
{
	"name": "The N54",
	"district": "hot_zone",
	"number": 8,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 2, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Climbers salute \"Lailah\", a rad-roasted corpse with a rusted FN-RAL beside \"Blackhand Was Right\"; legend says anyone who touches her things is cursed.", "gigs": []}
	],
	"gigs": [],
	"interior": "Tall ruined tower covered in climbers' tags; a small tent sheltering Lailah's corpse is left untouched.",
	"cite": "NC2045 p.94"
}
```

### #9 Safe Child

The wreck of the city's most exclusive daycare, subject of creepy rumours even urban explorers avoid.

```world locations.locations.hot_zone_9
{
	"name": "Safe Child",
	"district": "hot_zone",
	"number": 9,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 2, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Rumours: the dead kids and carers haunt it, or are in cryo below, or survived feral and hunt intruders.", "gigs": ["rescue"]}
	],
	"gigs": ["rescue"],
	"interior": "",
	"cite": "NC2045 p.94"
}
```

### #10 Toggle's Temple

A hidden, invitation-only underground paradise for gun nuts on the Zone's western edge, run by a man with faulty firmware.

```world locations.locations.hot_zone_10
{
	"name": "Toggle's Temple",
	"district": "hot_zone",
	"number": 10,
	"type": "gun_shop",
	"owner": "",
	"owner_name": "Toggle (Tech 5)",
	"security_code": {"n": 8, "faction": "locals", "responder": "patrons", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Toggle (Tech 5)"],
	"hooks": [],
	"gigs": [],
	"interior": "Underground; at least one of every gun ever made; firing ranges and obstacle courses (20eb); guarded by Toggle's drones and patrons.",
	"cite": "NC2045 p.94"
}
```

### #11 Totentanz

Maelstrom's castle: the club and its home, Burleson Tower, which the gang keeps standing and guards. Warlock wants people to come bargain for tech, drugs and fun; no cover, half-price Smash, the 10eb Armageddon.

```world locations.locations.hot_zone_11
{
	"name": "Totentanz",
	"district": "hot_zone",
	"number": 11,
	"type": "club",
	"owner": "maelstrom",
	"owner_name": "Maelstrom",
	"security_code": {"n": 9, "faction": "maelstrom", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Warlock (Solo 6)"],
	"hooks": [
		{"text": "Inside is mostly peaceful, but once out of the bouncers' sight anyone you angered may knife you.", "gigs": ["assassination", "gang_hit"]},
		{"text": "Maelstrom fights anyone trying to rehab the surrounding blocks.", "gigs": ["sabotage"]}
	],
	"gigs": ["gang_hit", "assassination"],
	"interior": "Dim club inside the damaged Burleson Tower, which Maelstrom occupies, runs and maintains.",
	"cite": "NC2045 p.94"
}
```

## Fixers

- Hamilton "Guzz" Parker (Fixer 4/Nomad 4) — Folk nomad, NCU economics lecturer; negotiates contracts for nomad reconstruction packs on the Zone's edge.


## Personalities

- Bengal Khan (Solo 6): scarred, tiger-furred leader of the Lightning Cats, still strong enough to throw a motorcycle.

- Hamilton "Guzz" Parker (Fixer 4/Nomad 4): nomad contract negotiator and part-time NCU economics teacher.

- The Hot Zone Lurker (??): scavver legend of a glowing three-eyed skeleton in a yellow hazmat suit whose radioactive hand burns people to ash.

- Lucia Zskremsky: City Hall clerk for the Zone's property and reconstruction records; a Boost addict who loses or finds paperwork for a fix.

- Ripper (Solo 4): runs the Diggers, Maelstrom's scavvers, through fear and sadistic loyalty rites.

- Precious: a mute, ragged Zone oddity who shadows visitors and helps those who feed him.

- Valence (Tech 3): ex-scavver at The Forlorn Hope who sells Zone advice and, for enough eb or a good cause, guides crews in.
