# Old Combat Zone

The pre-war San Morro Industrial Zone, flattened in the 4th Corporate War and left to rot, then rebuilt by
veteran Lasky and his refugees into a warren of shored-up buildings and fortresses (NC2045 p.166-167). It became a
district only in 2042, when Lasky's foster son Brick Coleman bought a Council seat. The older Faded want to keep to
themselves in the Warren; the younger Edgerunners Inc. (ERI) want the district joined to the city and police it,
warning thieves out and executing killers on the spot. Haakensen's offer to raze the Warren for a megabuilding is
setting the two at each other's throats, while the Iron Sights push south out of their northern turf (p.167-169).

```world city.districts.old_combat_zone
{
	"name": "Old Combat Zone",
	"region": "island",
	"manager": {"name": "Brick Coleman", "role": "Solo 7"},
	"population": "split by generation: the older Faded (mostly in the Warren) and the younger ERI",
	"security_code": {"n": 3, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": 8,
	"provider": "eri",
	"gangs": ["iron_sights", "generation_red", "shroomers", "willows", "faded"],
	"ncart": [],
	"profile": "combat_zone",
	"look": ["ruined factories", "shored-up buildings", "post-apocalyptic", "fortified blocks", "container housing"],
	"history": "The San Morro Industrial Zone was wrecked in the 4CW, resettled by Lasky's Faded, and made a district when Brick Coleman bought a Council seat in 2042.",
	"cite": "NC2045 p.166-175"
}
```

Inside the Warren the Faded police themselves; ERI squads (one veteran Solo plus five to ten recruits) patrol the
rest (p.167).

### #1 Alice's

A well-run Iron Sights brothel, operated for the Weng Fang Tong, catering to wealthy clients' niche tastes (p.169).

```world locations.locations.old_combat_zone_1
{
	"name": "Alice's", "district": "old_combat_zone", "number": 1, "type": "club",
	"owner": "iron_sights", "owner_name": "Alice Terris (Exec 3/Solo 5), for the Weng Fang Tong",
	"security_code": {"n": 7, "faction": "iron_sights", "intensity": "medium", "hardened": true},
	"utility_code": 6,
	"npcs": ["Alice Terris (Exec 3/Solo 5)"],
	"hooks": [
		{"text": "Rich clients come to the OCZ to keep their particular fetishes secret.", "gigs": ["data_theft"]},
		{"text": "Workers are body-sculpted to order, and whether they consent is doubtful.", "gigs": ["rescue"]}
	],
	"gigs": ["data_theft", "rescue", "gang_hit"],
	"interior": "",
	"cite": "NC2045 p.169"
}
```

### #2 Always Hot

A firing range in an old warehouse run by an ex-Militech trainer, who stages periodic street hunts of bioengineered
deer ending in a community feast (p.169).

```world locations.locations.old_combat_zone_2
{
	"name": "Always Hot", "district": "old_combat_zone", "number": 2, "type": "venue",
	"owner": "", "owner_name": "Mac Trautman (Solo 6)",
	"security_code": {"n": 5, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Mac Trautman (Solo 6)"],
	"hooks": [{"text": "Nobody knows where Mac gets the Biotechnica deer for his hunts.", "gigs": ["data_theft"]}],
	"gigs": [],
	"interior": "Warehouse firing range; surrounding streets are blocked off during hunts.",
	"cite": "NC2045 p.169"
}
```

### #3 The Arena

A copper-and-red warehouse, home of the ERI-sponsored roller derby team that both factions cheer for (p.169).

```world locations.locations.old_combat_zone_3
{
	"name": "The Arena", "district": "old_combat_zone", "number": 3, "type": "venue",
	"owner": "eri", "owner_name": "Edgerunners Inc. (Combat Zone Cannons)",
	"security_code": {"n": 5, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Refurbished warehouse derby rink.",
	"cite": "NC2045 p.169"
}
```

### #4 Bladeware

An Iron Sights shop for blades, held or implanted, managed by a self-styled master (p.169-170).

```world locations.locations.old_combat_zone_4
{
	"name": "Bladeware", "district": "old_combat_zone", "number": 4, "type": "shop",
	"owner": "iron_sights", "owner_name": "Sengo (Tech 4), manager",
	"security_code": {"n": 8, "faction": "iron_sights", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Sengo (Tech 4)"],
	"hooks": [{"text": "Sengo's tale of a Japanese master is a lie: Great Lakes Cutlery fired him for stealing supplies.", "gigs": []}],
	"gigs": ["gang_hit"],
	"interior": "",
	"cite": "NC2045 p.169"
}
```

### #5 The Farnsworth Building

An ornate old architects' office block fought over by several gangs and now held by the yogang Generation Red
(p.170).

```world locations.locations.old_combat_zone_5
{
	"name": "The Farnsworth Building", "district": "old_combat_zone", "number": 5, "type": "gang_base",
	"owner": "generation_red", "owner_name": "Generation Red",
	"security_code": {"n": 5, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Blades (Fixer 2)", "Ms. Slee (Solo 5)"],
	"hooks": [
		{"text": "The Kill Krashers tried and failed to retake the building last year.", "gigs": ["gang_hit"]},
		{"text": "Danger Gal operatives have been seen going in, perhaps to recruit the kids.", "gigs": ["corp_extraction"]},
		{"text": "Ms. Slee keeps urging the children to move into the Warren.", "gigs": ["rescue"]}
	],
	"gigs": ["gang_hit", "corp_extraction", "rescue"],
	"interior": "Statuary, murals and the area's only fountain, redecorated by the kids; ERI patrols pass a few times a week.",
	"cite": "NC2045 p.170"
}
```

### #6 Flasher's Corner

A street-corner hustler at Government and Effinger selling junk and, better, local information (p.170).

```world locations.locations.old_combat_zone_6
{
	"name": "Flasher's Corner", "district": "old_combat_zone", "number": 6, "type": "market",
	"owner": "", "owner_name": "Mal \"Flasher\" Devincher (Fixer 2)",
	"security_code": {"n": 3, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Mal \"Flasher\" Devincher (Fixer 2)"],
	"hooks": [{"text": "Flasher sells scraps of OCZ intel as readily as his junk.", "gigs": ["data_theft"]}],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.170"
}
```

### #7 From the Ashes

A community clinic run by an ex-Trauma Team surgeon who treats everyone: the OCZ's closest thing to neutral
ground (p.170). The Willows meet here monthly (p.45).

```world locations.locations.old_combat_zone_7
{
	"name": "From the Ashes", "district": "old_combat_zone", "number": 7, "type": "medical",
	"owner": "", "owner_name": "Phoenix Redwyne (Medtech 7/Fixer 6)",
	"security_code": {"n": 6, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Phoenix Redwyne (Medtech 7/Fixer 6)"],
	"hooks": [{"text": "The Iron Sights hit the clinic with a punknaught; edgerunners drove them off, but the gang is unlikely to let it go.", "gigs": ["gang_hit", "rescue"]}],
	"gigs": ["gang_hit", "rescue"],
	"interior": "",
	"cite": "NC2045 p.170"
}
```

### #8 Ionic Semiconductor Building

A pre-war robot factory turned Iron Sights container housing for members' families (p.170).

```world locations.locations.old_combat_zone_8
{
	"name": "Ionic Semiconductor Building", "district": "old_combat_zone", "number": 8, "type": "housing",
	"owner": "iron_sights", "owner_name": "Iron Sights",
	"security_code": {"n": 4, "faction": "iron_sights", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["gang_hit"],
	"interior": "Factory hall of stacked containers; steel-reinforced doors locked from midnight to 7 am against raids.",
	"cite": "NC2045 p.170"
}
```

### #9 Jesse James' Kosher Deli

ERI's heart: neither deli nor kosher, more pub crossed with a fight gym where disputes are settled by fists
(p.170-171).

```world locations.locations.old_combat_zone_9
{
	"name": "Jesse James' Kosher Deli", "district": "old_combat_zone", "number": 9, "type": "bar",
	"owner": "eri", "owner_name": "Brick Coleman (Solo 7)",
	"security_code": {"n": 10, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": 7,
	"npcs": ["Brick Coleman (Solo 7)", "Robert B (Solo 4)"],
	"hooks": [],
	"gigs": ["assassination", "data_theft"],
	"interior": "A sunken main floor of tables, cleared and ringed with raised bulletproof plexi for bare-knuckle disputes; house rules burned above the bar; Brick's office in the back.",
	"cite": "NC2045 p.170"
}
```

### #10 Kibble Kirkle

A bodega of cheap usable supplies whose staff all take names starting with K (p.171).

```world locations.locations.old_combat_zone_10
{
	"name": "Kibble Kirkle", "district": "old_combat_zone", "number": 10, "type": "shop",
	"owner": "", "owner_name": "",
	"security_code": {"n": 3, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [{"text": "Locals joke the bodega is a cult front, and the narrator suspects they are right.", "gigs": ["data_theft"]}],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.171"
}
```

### #11 The Laydown

A huge cube and container community where at least half of ERI lives, Brick included (p.171).

```world locations.locations.old_combat_zone_11
{
	"name": "The Laydown", "district": "old_combat_zone", "number": 11, "type": "housing",
	"owner": "eri", "owner_name": "Edgerunners Inc.",
	"security_code": {"n": 6, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Brick Coleman (Solo 7)"],
	"hooks": [],
	"gigs": ["gang_hit"],
	"interior": "Cube and cargo container stacks.",
	"cite": "NC2045 p.171"
}
```

### #12 The Lodge

A symbol-covered building near The Glen where masked, wealthy outsiders gather monthly under guard (p.171).

```world locations.locations.old_combat_zone_12
{
	"name": "The Lodge", "district": "old_combat_zone", "number": 12, "type": "club",
	"owner": "", "owner_name": "",
	"security_code": {"n": 6, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Nobody knows who the masked members are or what they do inside.", "gigs": ["data_theft"]},
		{"text": "Some think Brick trades ERI protection for the members' backing on his Council plans.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "A modest multi-storey building; members arrive with their own security force.",
	"cite": "NC2045 p.171"
}
```

### #13 Substation 12

Brick's showpiece power substation, routing Outskirts solar and wind power to the lower Island (p.171).

```world locations.locations.old_combat_zone_13
{
	"name": "Substation 12", "district": "old_combat_zone", "number": 13, "type": "utility",
	"owner": "eri", "owner_name": "",
	"security_code": {"n": 10, "faction": "eri", "intensity": "heavy", "hardened": true},
	"utility_code": 3,
	"npcs": [],
	"hooks": [{"text": "The Faded resent it because most of its power goes to other districts; ERI answers any threat with maximum force.", "gigs": ["sabotage"]}],
	"gigs": ["sabotage"],
	"interior": "",
	"cite": "NC2045 p.171"
}
```

### #14 The Terrace

A failed terraced green space of packed dirt and weeds: kids by day, couples by night, smugglers after
midnight (p.171-172).

```world locations.locations.old_combat_zone_14
{
	"name": "The Terrace", "district": "old_combat_zone", "number": 14, "type": "park",
	"owner": "", "owner_name": "",
	"security_code": {"n": 4, "faction": "eri", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [{"text": "After midnight, smugglers use it to land small boats.", "gigs": ["gang_hit"]}],
	"gigs": [],
	"interior": "Banked dirt terraces by the water; an ERI patrol watches by day.",
	"cite": "NC2045 p.171"
}
```

### #15 The Underground

A derelict NCART depot deep underground, home village of the isolationist fungus-farming Shroomers (p.172).

```world locations.locations.old_combat_zone_15
{
	"name": "The Underground", "district": "old_combat_zone", "number": 15, "type": "gang_base",
	"owner": "shroomers", "owner_name": "The Shroomers",
	"security_code": {"n": 10, "faction": "shroomers", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["gang_hit"],
	"interior": "A cavernous maintenance depot with vast fungus and lichen gardens; produce sold through Mrs. Suzuki's Bodega in Old Japantown.",
	"cite": "NC2045 p.172"
}
```

### #16 The Warren

The first true megabuilding: factories and worker housing fused by the Faded into a multi-block fortress
(p.172-173). Map pins 16a-16f are its outer-ring tenants, listed in the interior.

```world locations.locations.old_combat_zone_16
{
	"name": "The Warren", "district": "old_combat_zone", "number": 16, "type": "megabuilding",
	"owner": "faded", "owner_name": "Lasky (Solo 6)",
	"security_code": {"n": 8, "faction": "faded", "intensity": "medium", "hardened": true},
	"utility_code": 7,
	"npcs": ["Lasky (Solo 6)", "Ms. Slee (Solo 5)", "Anita Delores (Media 4/Rockerboy 4)", "Leo Baskin", "Sister Agatha", "Bobby Glenn"],
	"hooks": [
		{"text": "Haakensen proposes razing the Warren for a megabuilding; Lasky vows to shoot any demolition crew and Faded-ERI brawls are growing.", "gigs": ["sabotage", "gang_hit", "assassination"]},
		{"text": "If Brick's plans go ahead, Lasky may make a last stand with the Faded behind him.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit", "rescue", "sabotage"],
	"interior": "A maze of random stairs and twisting halls with armed resistance behind most doors; markets, schools, clinics, armories, hydroponics, small factories; outsiders kept to the outer ring, hopefuls in a tent city outside. Outer ring: 16a Angel Radio (slanted penthouse), 16b Baskin Books, 16c OCZ Schoolhouse (ERI-guarded), 16d The Pantheon (multi-faith hall with a religious BD library), 16e Smithery (artisan guns, outsiders pay ~3x), 16f Uncle Anne's (meat and Kibble stall).",
	"cite": "NC2045 p.172"
}
```

## Fixers

- Phoenix Redwyne (Medtech 7/Fixer 6), From the Ashes: neutral-ground clinic kept supplied through contacts and favours (p.170).
- Mal "Flasher" Devincher (Fixer 2), Flasher's Corner (Government and Effinger): cheap goods and local information (p.170).
- Blades (Fixer 2), The Farnsworth Building: oldest member of Generation Red (p.173).

## Personalities

- Alice Terris (Exec 3/Solo 5): manager of Alice's and ambitious head of the Iron Sights rearguard, neon wolvers, out to grow the gang's OCZ turf (p.172-173).
- Blades (Fixer 2): heavily chromed Generation Red teen being eyed by Danger Gal (p.173).
- Bobby Glenn: bookish teen who haunts Baskin Books and scavenges for books (p.173).
- Lasky (Solo 6): founder of the OCZ and leader of the Faded; aging and widowed, he may make a last stand against Brick's plans (p.173).
- Ms. Slee (Solo 5): OCZ Schoolhouse headmistress and martial artist, possibly an ex-commando; pushing Lasky and Brick to talk (p.173).
- Robert B (Solo 4): head bartender at the Deli who keeps Brick's people in line (p.173).
