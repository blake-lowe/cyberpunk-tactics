# South Night City

The Island's oldest combat zone: a sprawl of abandoned warehouses, shanty towns and container housing where
residents scrape by while gangs ride through and the City Manager skims everything first (NC2045 p.138-139).
Garven Haakensen bought the manager's seat with cash and blackmail, and has since lost the Port (2036) and the
Reclamation Zone (2039) to new districts. The deputized provider, Scythe Security, is far too small for the job and
only guards what Haakensen calls "desirable"; locals rely on the DeadWoods and the Zoners instead. The narrator
suspects Haakensen is deliberately tanking property values so shell companies can buy the district up for an
unnamed developer (p.139-140).

```world city.districts.south_night_city
{
	"name": "South Night City",
	"region": "island",
	"manager": {"name": "Garven Haakensen", "role": "Fixer 7"},
	"population": "large and diverse; the down-on-their-luck, pushed there or kept there by the system",
	"security_code": {"n": 5, "faction": "scythe_security", "intensity": "medium", "hardened": false},
	"utility_code": 6,
	"provider": "scythe_security",
	"gangs": ["deadwoods", "enhanced", "kanzaki_family", "kill_krashers", "reckoners", "sinful_adams", "tombstone_preservers", "zoners", "bozos", "tyger_claws"],
	"ncart": ["King Street", "Spivey Street"],
	"profile": "combat_zone",
	"look": ["abandoned warehouses", "shanty towns", "cargo containers", "smog", "gang turf"],
	"history": "Haakensen fled the nuke, bought the manager seat a decade later, then lost the Port and Reclamation Zone; a Zoner march on The Glen ended in deaths.",
	"cite": "NC2045 p.138-149"
}
```

NCART: the map shows a Blue Line and an Orange Line station; the names are read off the Flashmap (p.28) and are
the King Street transfer and Spivey Street (best reading of a small map).

### 101.9 The Dirge (not on map)

A Zoners pirate radio station in an armoured, junk-camouflaged van that is always hunting for power (p.141).

```world locations.locations.south_night_city_the_dirge
{
	"name": "101.9 The Dirge", "district": "south_night_city", "number": null, "type": "media",
	"owner": "zoners", "owner_name": "The Zoners",
	"security_code": {"n": 10, "faction": "zoners", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [{"text": "The station drinks power and the Zoners are always scrounging new energy sources to stay on air.", "gigs": []}],
	"gigs": [],
	"interior": "A mobile broadcast van rebuilt from scavenged cyberware, vehicle and weapon parts, disguised as rubble.",
	"cite": "NC2045 p.141"
}
```

### #1 The Boneyard

A shanty town on an old cemetery, peaceful and fertile, held by the neo-goth Sinful Adams with some Tombstone
Preservers (p.141).

```world locations.locations.south_night_city_1
{
	"name": "The Boneyard", "district": "south_night_city", "number": 1, "type": "squat",
	"owner": "sinful_adams", "owner_name": "Gomez (Rockerboy 4) and Ophelia (Solo 5)",
	"security_code": {"n": 10, "faction": "sinful_adams", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Gomez (Rockerboy 4)", "Ophelia (Solo 5)"],
	"hooks": [
		{"text": "The Sinful Adams come down hard on anyone desecrating the graves or homes.", "gigs": ["gang_hit"]},
		{"text": "Residents say they hear voices near the surviving headstones.", "gigs": []}
	],
	"gigs": ["gang_hit"],
	"interior": "Shacks among headstones; Poe's Respite, a three-room schoolhouse run by Gomez; The Crypt, a bar open most nights.",
	"cite": "NC2045 p.141"
}
```

### #2 Combat Cabb Headquarters

The legendary armed taxi firm, the only one that drives into combat zones, runs a fleet of at least 18 armoured
cabs from a walled bunker compound (p.141-142).

```world locations.locations.south_night_city_2
{
	"name": "Combat Cabb Headquarters", "district": "south_night_city", "number": 2, "type": "transport",
	"owner": "combat_cabb", "owner_name": "Combat Cabb",
	"security_code": {"n": 10, "faction": "combat_cabb", "intensity": "medium", "hardened": true},
	"utility_code": 4,
	"npcs": [],
	"hooks": [],
	"gigs": ["sabotage", "data_theft"],
	"interior": "Four armoured bunkers round a courtyard: 1-2 vehicle fleet and repair bays, 3 dispatch and admin, 4 armory, quarters and rec; a double-reinforced wall with turret mounts.",
	"cite": "NC2045 p.141"
}
```

### #3 Container Mart

A shopping plaza of stacked shipping containers, Scythe Security's old contract (p.142).

```world locations.locations.south_night_city_3
{
	"name": "Container Mart", "district": "south_night_city", "number": 3, "type": "market",
	"owner": "", "owner_name": "Melinda Joy (Rockerboy 2/Fixer 3)",
	"security_code": {"n": 5, "faction": "scythe_security", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": ["Melinda Joy (Rockerboy 2/Fixer 3)"],
	"hooks": [
		{"text": "Rumour says Melinda Joy and Haakensen go way back.", "gigs": ["data_theft"]},
		{"text": "SlushSlurp will dust its shaved ice with synthcoke, blue glass or boost for a fee.", "gigs": []}
	],
	"gigs": ["data_theft"],
	"interior": "Container shops: Ancestral Threads (hair salon), Chopper's (ripper dentist), Container Bodega, Getaway Tours (BD parlour), Old Lady Stuff (crafts, armour repair), Panik (nail salon), SlushSlurp.",
	"cite": "NC2045 p.142"
}
```

### Duck. Duck. Dead! (not on map)

A one-night Bozo death maze that springs up without warning in an abandoned building, then vanishes (p.142).

```world locations.locations.south_night_city_duck_duck_dead
{
	"name": "Duck. Duck. Dead!", "district": "south_night_city", "number": null, "type": "warehouse",
	"owner": "bozos", "owner_name": "Prankstarr the Clown (Medtech 6/Tech 4)",
	"security_code": {"n": 11, "faction": "bozos", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Prankstarr the Clown (Medtech 6/Tech 4)"],
	"hooks": [
		{"text": "Anyone who runs from a trio of tied clown dolls is dragged off by dozens of Bozos into the maze.", "gigs": ["rescue"]},
		{"text": "Recordings of each night's victims hit the market as XBDs weeks later.", "gigs": ["data_theft"]}
	],
	"gigs": ["rescue", "gang_hit"],
	"interior": "A trap maze in an abandoned building: victims wake naked in shock collars that fire if they stand still 60 s; blade pits, acid showers, live panels, flamethrower drones, robot dogs, explosive toys; ends in a forced moral choice.",
	"cite": "NC2045 p.142"
}
```

### #4 Fort Sumter

A former high school that is now the base of the DeadWoods, a cowboy-themed guardian gang protecting the
railways (p.143).

```world locations.locations.south_night_city_4
{
	"name": "Fort Sumter", "district": "south_night_city", "number": 4, "type": "gang_base",
	"owner": "deadwoods", "owner_name": "Isaiah \"Gunslinger\" Hurston (Nomad 6/Solo 6)",
	"security_code": {"n": 10, "faction": "deadwoods", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Isaiah \"Gunslinger\" Hurston (Nomad 6/Solo 6)"],
	"hooks": [],
	"gigs": ["gang_hit", "sabotage"],
	"interior": "1F auditorium, chow hall, petition offices; 2F (friends only) rec room, ops centre, entertainment; basement and sub-basement (members only) bunks, gym, gun range, armory, security office; roof sniper nests and a pad for Gunslinger's prototype aerodyne cyberbike; bike garage behind.",
	"cite": "NC2045 p.143"
}
```

### Fortitude South (not on map)

What looks like one more derelict building is, the narrator's sources claim, a US military-intelligence post
(p.143). Security Code printed as unknown.

```world locations.locations.south_night_city_fortitude_south
{
	"name": "Fortitude South", "district": "south_night_city", "number": null, "type": "corp_office",
	"owner": "us_government", "owner_name": "United States consulate (military intelligence)",
	"security_code": null,
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Suspected US spy post recovering lost tech and watching key people and places in the city.", "gigs": ["data_theft", "corp_extraction"]},
		{"text": "Culper Ring and Danger Gal operatives reportedly drop by to pass along information.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft", "corp_extraction"],
	"interior": "A state-of-the-art intelligence facility behind an abandoned facade, staffed by at least six officers.",
	"cite": "NC2045 p.143"
}
```

### #5 GunMart

The cheap-gun neocorp's headquarters in a former megamart, its guns failing one time in ten (p.143). The
Security Code number is printed as "1-" (most likely 10); recorded as 10.

```world locations.locations.south_night_city_5
{
	"name": "GunMart", "district": "south_night_city", "number": 5, "type": "gun_shop",
	"owner": "gunmart", "owner_name": "GunMart",
	"security_code": {"n": 10, "faction": "gunmart", "intensity": "heavy", "hardened": false},
	"utility_code": 5,
	"npcs": [],
	"hooks": [
		{"text": "Rumour has the Enhanced meeting in the back warehouse.", "gigs": ["data_theft"]},
		{"text": "The cheap guns may be part of a plot to push people into violence and the Enhanced's cyberpsychosis creed.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": ["data_theft", "sabotage"],
	"interior": "Front aisles of guns and ammo by category, FBC guards and chromed cashiers; cavernous back warehouse of crated weapons awaiting shipment (made at the Heywood Industrial Zone factory).",
	"cite": "NC2045 p.143"
}
```

### #6 Haakensen Tower

The district's only new skyscraper, a monument to the City Manager's ego paid for with money the district
needed (p.143-144).

```world locations.locations.south_night_city_6
{
	"name": "Haakensen Tower", "district": "south_night_city", "number": 6, "type": "corp_office",
	"owner": "city_government", "owner_name": "Garven Haakensen (Fixer 7)",
	"security_code": {"n": 10, "faction": "scythe_security", "intensity": "heavy", "hardened": false},
	"utility_code": 3,
	"npcs": ["Garven Haakensen (Fixer 7)", "Greg Calters", "Andrew Scythe III (Exec 3/Solo 4)"],
	"hooks": [
		{"text": "Haakensen may be tanking property values so fly-by-night firms can buy up the district for an unknown developer.", "gigs": ["data_theft"]},
		{"text": "Nobody can explain why tiny Scythe Security won the district contract.", "gigs": ["data_theft"]},
		{"text": "Haakensen's aide Greg Calters has a weakness for tall blondes.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft", "assassination", "sabotage"],
	"interior": "Haakensen's apartments and offices on the top floors; cronies rent the others; Scythe Security on 2F and the underground garage; a cafe, Mayoral Race, on the ground floor.",
	"cite": "NC2045 p.143"
}
```

### #7 KidZ

A daycare and school in a rebuilt junior high, run by the veteran-owned not-for-profit Outreach on a sliding
scale and always short of money (p.144).

```world locations.locations.south_night_city_7
{
	"name": "KidZ", "district": "south_night_city", "number": 7, "type": "school",
	"owner": "", "owner_name": "Outreach",
	"security_code": {"n": 6, "faction": "deadwoods", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Professor Rowan Powers", "Conor Justice (Medtech 4/Solo 2)", "Baker Street"],
	"hooks": [],
	"gigs": [],
	"interior": "Patched-up junior high with automated defences; classrooms above, nursery and preschool in the basement; 20 volunteer staff.",
	"cite": "NC2045 p.144"
}
```

### #8 Lazarus Training Center

The elite PMC's central training base for the Pacifica Confederation, a neighbourhood-sized fortress (p.144).

```world locations.locations.south_night_city_8
{
	"name": "Lazarus Training Center", "district": "south_night_city", "number": 8, "type": "military",
	"owner": "lazarus", "owner_name": "Lazarus",
	"security_code": {"n": 11, "faction": "lazarus", "intensity": "heavy", "hardened": true},
	"utility_code": 3,
	"npcs": ["Paul Nshoka (Tech 5/Solo 2)"],
	"hooks": [{"text": "Solos believe it stockpiles enough troops and munitions to invade a small country.", "gigs": ["data_theft"]}],
	"gigs": ["data_theft", "sabotage"],
	"interior": "Very thick walls, turrets, mines and trained guards; armoured vehicles, trucks, AVs and helicopters in constant traffic; every worker, down to the cooks, is Lazarus staff.",
	"cite": "NC2045 p.144"
}
```

### #9 MAX-TAC HQ

Max Hammerman's privatised cyberpsycho squad, incorruptible but billing for every bullet (p.144-145).

```world locations.locations.south_night_city_9
{
	"name": "MAX-TAC HQ", "district": "south_night_city", "number": 9, "type": "police",
	"owner": "maxtac", "owner_name": "Max Hammerman (Lawman 10)",
	"security_code": {"n": 11, "faction": "maxtac", "intensity": "heavy", "hardened": true},
	"utility_code": 3,
	"npcs": ["Max Hammerman (Lawman 10)"],
	"hooks": [],
	"gigs": ["data_theft", "sabotage"],
	"interior": "A fortified castle round a hidden rose garden: east tower vehicles (vans to AVs) and repair bays, west tower a top armory; between them meeting rooms, intel posts, comms, clinics, workshops, training, offices, barracks.",
	"cite": "NC2045 p.144"
}
```

### #10 MindNutz Lover

The district's hottest braindance club, mixing NCU students and local partygoers (p.145).

```world locations.locations.south_night_city_10
{
	"name": "MindNutz Lover", "district": "south_night_city", "number": 10, "type": "club",
	"owner": "", "owner_name": "Steve \"Chance\" Dore (Rockerboy 3)",
	"security_code": {"n": 3, "faction": "scythe_security", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": ["Steve \"Chance\" Dore (Rockerboy 3)"],
	"hooks": [],
	"gigs": [],
	"interior": "One storey: booths, dance floor and bar in one bright space, plus BD.",
	"cite": "NC2045 p.145"
}
```

### Nostradamus' Warehouse (not on map)

An invite-only archive of physical books and a vast NET architecture of collected datafiles; its location is
kept secret (p.145).

```world locations.locations.south_night_city_nostradamus_warehouse
{
	"name": "Nostradamus' Warehouse", "district": "south_night_city", "number": null, "type": "data_center",
	"owner": "nostradamus", "owner_name": "Nostradamus (Media ?)",
	"security_code": {"n": 10, "faction": "nostradamus", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Nostradamus (Media ?)", "Smiling Wisdom (Netrunner 4)"],
	"hooks": [
		{"text": "Nostradamus buys books and loaded memory chips from edgerunners.", "gigs": ["data_theft"]},
		{"text": "He trades with a secretive tech-nomad clan and hints he is preparing for the day a wall falls.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "A heavily defended warehouse of books and a massive NET architecture.",
	"cite": "NC2045 p.145"
}
```

### #11 Savage Docs

The district's trusted ripperdoc, run by the late founder's five apprentices and somehow protected by both the
Tyger Claws and the Kanzaki, who hate each other (p.145). Security faction printed as "Tyger Claws/Kanzaki".

```world locations.locations.south_night_city_11
{
	"name": "Savage Docs", "district": "south_night_city", "number": 11, "type": "medical",
	"owner": "", "owner_name": "Savage Docs' five apprentices",
	"security_code": {"n": 9, "faction": "tyger_claws", "intensity": "light", "hardened": true},
	"utility_code": 4,
	"npcs": ["Johnny B Good (Medtech 6)"],
	"hooks": [{"text": "Johnny B Good pays well for deliveries of new medical equipment.", "gigs": ["data_theft"]}],
	"gigs": ["data_theft"],
	"interior": "An old emergency centre with seven wings of three beds each and slightly dated gear; open 24/7; guarded by Tyger Claws and Kanzaki Family alike.",
	"cite": "NC2045 p.145"
}
```

### #12 Silverhand Studios

Kerry Eurodyne's artist apartment building, now run for profit by his cousin (p.145-146).

```world locations.locations.south_night_city_12
{
	"name": "Silverhand Studios", "district": "south_night_city", "number": 12, "type": "housing",
	"owner": "", "owner_name": "Kerry Eurodyne; run by Jomari Jackson (Exec 2/Fixer 2)",
	"security_code": {"n": 5, "faction": "scythe_security", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": ["Jomari Jackson (Exec 2/Fixer 2)", "Kerry Eurodyne"],
	"hooks": [],
	"gigs": [],
	"interior": "Vaulted ceilings, skylights, configurable studio flats; murals repainted every few days.",
	"cite": "NC2045 p.145"
}
```

### #13 The Slammer

A packed edgerunner and ganger bar across two buildings, home of the Arena where gangs settle feuds by agreed
trial by combat (p.146). Security faction printed as "Patrons".

```world locations.locations.south_night_city_13
{
	"name": "The Slammer", "district": "south_night_city", "number": 13, "type": "bar",
	"owner": "", "owner_name": "Cassius Brown (Solo 6)",
	"security_code": {"n": 10, "faction": "locals", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Cassius Brown (Solo 6)", "JessiGames (Fixer 4)"],
	"hooks": [{"text": "Gangs from across the city book the Arena to settle disputes with agreed terms, and JessiGames runs the betting.", "gigs": ["gang_hit"]}],
	"gigs": ["gang_hit"],
	"interior": "East building: the cinder-block Arena; west building: dance floor and bar crammed with small tables; too loud to eavesdrop; no food.",
	"cite": "NC2045 p.146"
}
```

### #14 South Cargo Village

Container homes on the Glen border, watched over by NCPD snipers (p.146).

```world locations.locations.south_night_city_14
{
	"name": "South Cargo Village", "district": "south_night_city", "number": 14, "type": "housing",
	"owner": "", "owner_name": "",
	"security_code": {"n": 6, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "A cargo container community overlooked by NCPD snipers guarding The Glen.",
	"cite": "NC2045 p.146"
}
```

### #15 South Night City Volunteer Fire Station

The Zoners' volunteer fire brigade, kept running on a small Night Corp grant and called-in favours (p.146).

```world locations.locations.south_night_city_15
{
	"name": "South Night City Volunteer Fire Station", "district": "south_night_city", "number": 15, "type": "civic",
	"owner": "zoners", "owner_name": "Tearjerker (Lawman 4) and Forty Mike-Mike (Lawman 4)",
	"security_code": {"n": 9, "faction": "zoners", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Tearjerker (Lawman 4)", "Forty Mike-Mike (Lawman 4)", "Billy Young (Lawman 1)", "Baker Street"],
	"hooks": [],
	"gigs": [],
	"interior": "A few mostly working fire engines, turnout gear and supplies; volunteer crew.",
	"cite": "NC2045 p.146"
}
```

### #16 Union Chapel Building

A once-grand chapel ruined by gang wars, now the Reckoners' church (p.146).

```world locations.locations.south_night_city_16
{
	"name": "Union Chapel Building", "district": "south_night_city", "number": 16, "type": "church",
	"owner": "reckoners", "owner_name": "The Reckoners",
	"security_code": {"n": 5, "faction": "reckoners", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [{"text": "The Reckoners preach the coming Harvest of Souls and lure listeners with cookies.", "gigs": ["gang_hit"]}],
	"gigs": ["gang_hit"],
	"interior": "Arched foyer and broken stained glass, battle-damaged.",
	"cite": "NC2045 p.146"
}
```

### #17 University Cargo Bay

Some of the cheapest student housing near NCU, if you don't mind stray bullets (p.147).

```world locations.locations.south_night_city_17
{
	"name": "University Cargo Bay", "district": "south_night_city", "number": 17, "type": "housing",
	"owner": "", "owner_name": "",
	"security_code": {"n": 5, "faction": "ncu_campus_security", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.147"
}
```

## Fixers

- Garven Haakensen (Fixer 7), Haakensen Tower: City Manager; brokers deals between City Council factions (p.139).
- Melinda Joy (Rockerboy 2/Fixer 3), Container Mart: owns the mall and runs its bodega; old ties to Haakensen (p.142).
- JessiGames (Fixer 4), The Slammer: books the bets on Arena fights (p.146).
- Jomari Jackson (Exec 2/Fixer 2), Silverhand Studios: runs the building's lettings as a business (p.145-146).

## Personalities

- Andrew Scythe III (Exec 3/Solo 4): ex-hotel security who founded Scythe Security; quietly out of his depth with the district contract (p.147).
- Baker Street: a Sherlock-obsessed KidZ pupil hunting for a case; orphaned by an Enhanced-Inquisitors fight, looked after by the fire station crew (p.147).
- Conor Justice (Medtech 4/Solo 2): Outreach co-founder and army medic at KidZ, married to co-founders Tommy Wayne and Victoria Chase (p.147).
- The Dead Ringers: doll-like twin Bozos fond of poisons, biotoxins and pickpocketing; not part of Prankstarr's circus (p.147).
- FreeFall (Netrunner 4): Zoner netrunner who feeds tips to independent medias; brother Drop is in Maelstrom (p.147).
- Gomez (Rockerboy 4) and Ophelia (Solo 5): the Sinful Adams' dapper boss and armoured war leader; not a couple (p.147).
- Greg Calters: Haakensen's lackey and errand boy; weakness for tall blondes (p.147).
- Isaiah "Gunslinger" Hurston (Nomad 6/Solo 6): DeadWoods leader, ex-MAX-TAC and mercenary, wearing his father's Western Stars badge (p.147).
- Johnny B Good (Medtech 6): medtech and bookkeeper holding Savage Docs together; pays for new medical gear (p.147).
- Mister Studd (Rockerboy 4): star of an arty BD troupe and a Zoner (p.147).
- Paul Nshoka (Tech 5/Solo 2): retired bomb-disposal captain who lost his legs in 2029, now a Lazarus instructor (p.147).
- Prankstarr the Clown (Medtech 6/Tech 4): ex-Militech psychiatrist turned Bozo, creator of Duck. Duck. Dead! (p.147).
