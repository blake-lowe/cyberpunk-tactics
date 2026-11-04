# Reclamation Zone

One of the city's youngest districts, a hard-working, noisy place carved out of South Night City in 2039 for the
Dorado Clan, ex-Snake Nation rail nomads who keep NCART running in exchange for the land (NC2045 p.158-159).
Every adult trains as an auxiliary of Los Perros Guardianes, a volunteer militia with K-9 units that aims to stop
trouble before NCPD gets involved. Old City Manager Santos Dorado is slowing down and an election is quietly
brewing; the district suffers occasional sabotage and Kill Krasher raids from the east, which locals blame on
Haakensen (p.159).

```world city.districts.reclamation_zone
{
	"name": "Reclamation Zone",
	"region": "island",
	"manager": {"name": "Santos Dorado", "role": "Nomad 4/Exec 6"},
	"population": "mostly the Dorado Clan (several families, about half Muslim); about 10% later joiners: NCART staff, prior locals, ex-nomads",
	"security_code": {"n": 8, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": 5,
	"provider": "los_perros_guardianes",
	"gangs": ["tombstone_preservers", "kill_krashers"],
	"ncart": ["Reclamation Zone Station"],
	"profile": "industrial",
	"look": ["rail yards", "converted train cars", "junk heaps", "patrol dogs", "busy workshops"],
	"history": "Santos Dorado traded NCART upkeep for land; the Council split it off South Night City by a slim vote in 2039.",
	"cite": "NC2045 p.158-165"
}
```

NCART: the district map marks one Orange Line station, presumably location #14 (Pacific Boulevard on the p.28
Flashmap).

### #1 Booster Bistro

A rickety diner where its owner gives down-and-out ex-gangers work and a fresh start; good egg dishes (p.159-161).

```world locations.locations.reclamation_zone_1
{
	"name": "Booster Bistro", "district": "reclamation_zone", "number": 1, "type": "restaurant",
	"owner": "", "owner_name": "Axel 8",
	"security_code": {"n": 8, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Axel 8"],
	"hooks": [],
	"gigs": [],
	"interior": "Flimsy building with second-hand everything; a chicken coop out back.",
	"cite": "NC2045 p.159"
}
```

### #2 Country Cars

Bunk housing built from worn-out NCART cars for newcomers with drive but no cash (p.161).

```world locations.locations.reclamation_zone_2
{
	"name": "Country Cars", "district": "reclamation_zone", "number": 2, "type": "housing",
	"owner": "", "owner_name": "",
	"security_code": {"n": 7, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Old train cars divided into container-sized bunks round a lively courtyard.",
	"cite": "NC2045 p.161"
}
```

### #3 Earl's Second Hand Shop

A cramped junk shop whose owner also makes fair loans and takes trade or services (p.161).

```world locations.locations.reclamation_zone_3
{
	"name": "Earl's Second Hand Shop", "district": "reclamation_zone", "number": 3, "type": "shop",
	"owner": "", "owner_name": "Earl Mahoney (Fixer 4)",
	"security_code": {"n": 8, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Earl Mahoney (Fixer 4)"],
	"hooks": [{"text": "Earl is said to run a healthy trade in porn BDs out the back.", "gigs": []}],
	"gigs": [],
	"interior": "Floor-to-ceiling second-hand goods, from third-hand firearms to toys.",
	"cite": "NC2045 p.161"
}
```

### #4 Flashback

An '80s-nostalgia diner so good that corp types come down from The Glen (p.161).

```world locations.locations.reclamation_zone_4
{
	"name": "Flashback", "district": "reclamation_zone", "number": 4, "type": "restaurant",
	"owner": "", "owner_name": "Turbo Overdrive (Nomad 3)",
	"security_code": {"n": 8, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Turbo Overdrive (Nomad 3)"],
	"hooks": [{"text": "Visiting suits get drunk on full cans of Smash and are easy to charm information out of.", "gigs": ["data_theft"]}],
	"gigs": ["data_theft"],
	"interior": "White tile, bright geometric colour, old movie posters and props.",
	"cite": "NC2045 p.161"
}
```

### #5 Foundry Tech School

A Night Corp-funded trade school teaching everything from plumbing to cyberware repair and train work (p.161).

```world locations.locations.reclamation_zone_5
{
	"name": "Foundry Tech School", "district": "reclamation_zone", "number": 5, "type": "school",
	"owner": "", "owner_name": "Torin Seanoa (Exec 2/Tech 4)",
	"security_code": {"n": 7, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Torin Seanoa (Exec 2/Tech 4)", "Imam Rojas (Rockerboy 2/Tech 4)"],
	"hooks": [{"text": "Graduates from outside the district keep vanishing; sources say Torin sells their contracts to shady buyers.", "gigs": ["rescue", "data_theft"]}],
	"gigs": ["rescue", "data_theft"],
	"interior": "",
	"cite": "NC2045 p.161"
}
```

### #6 Freddie Douglas School

An all-ages school that moved from an old RV into a nuke-proof bomb shelter found by Ziggurat cable crews
(p.162).

```world locations.locations.reclamation_zone_6
{
	"name": "Freddie Douglas School", "district": "reclamation_zone", "number": 6, "type": "school",
	"owner": "", "owner_name": "",
	"security_code": {"n": 9, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "An underground bomb shelter built to survive a nuclear strike.",
	"cite": "NC2045 p.162"
}
```

### #7 Gordon's Garage

Where you go to turn a car into a barricade-busting tank (p.162).

```world locations.locations.reclamation_zone_7
{
	"name": "Gordon's Garage", "district": "reclamation_zone", "number": 7, "type": "chop_shop",
	"owner": "", "owner_name": "Troy Gordon (Nomad 4/Tech 4)",
	"security_code": {"n": 8, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Troy Gordon (Nomad 4/Tech 4)"],
	"hooks": [],
	"gigs": [],
	"interior": "Vehicle armouring garage with a half-finished punknaught in the back yard; apartments above.",
	"cite": "NC2045 p.162"
}
```

### #8 McGee Speedway

A dirt racetrack that grew into the district's park, for picnics, parties, soccer and spur-of-the-moment
challenge races (p.162).

```world locations.locations.reclamation_zone_8
{
	"name": "McGee Speedway", "district": "reclamation_zone", "number": 8, "type": "stadium",
	"owner": "", "owner_name": "",
	"security_code": {"n": 8, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Santos Dorado (Nomad 4/Exec 6)", "Quinn Simone (Exec 4)"],
	"hooks": [],
	"gigs": [],
	"interior": "Dirt track with picnic and play grounds; Santos presides over special events.",
	"cite": "NC2045 p.162"
}
```

### #9 Herschel's Crematorium

A kindly crematorium that honours any creed and lets the broke sleep in a coffin for a bit of work (p.162).

```world locations.locations.reclamation_zone_9
{
	"name": "Herschel's Crematorium", "district": "reclamation_zone", "number": 9, "type": "civic",
	"owner": "", "owner_name": "Herschel (Medtech 4)",
	"security_code": {"n": 7, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Herschel (Medtech 4)"],
	"hooks": [],
	"gigs": [],
	"interior": "Crematorium with spare coffins for overnight guests; a few Tombstone Preservers usually on site.",
	"cite": "NC2045 p.162"
}
```

### #10 La Perrera

The brick-walled base of Los Perros Guardianes and the district jail, where every patrol's dog is bred and
trained (p.162).

```world locations.locations.reclamation_zone_10
{
	"name": "La Perrera", "district": "reclamation_zone", "number": 10, "type": "police",
	"owner": "los_perros_guardianes", "owner_name": "Chapel \"Titan\" Suluku (Solo 4/Tech 2)",
	"security_code": {"n": 9, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Chapel \"Titan\" Suluku (Solo 4/Tech 2)"],
	"hooks": [{"text": "Titan will pay for information on the rising Kill Krasher raids.", "gigs": ["gang_hit", "data_theft"]}],
	"gigs": ["gang_hit", "rescue"],
	"interior": "Brick-walled compound: militia HQ, jail cells, kennels and dog training.",
	"cite": "NC2045 p.162"
}
```

### #11 Metal Mountain

The district's badly run junkyard, a rusting heap with treasures for anyone braving tetanus (p.162-163).

```world locations.locations.reclamation_zone_11
{
	"name": "Metal Mountain", "district": "reclamation_zone", "number": 11, "type": "warehouse",
	"owner": "", "owner_name": "Mason Dorado (Tech 2)",
	"security_code": {"n": 5, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Mason Dorado (Tech 2)"],
	"hooks": [],
	"gigs": [],
	"interior": "An unsorted junk mountain.",
	"cite": "NC2045 p.162"
}
```

### #12 Mobile Mosque Prayer Center

A huge expanding truck serving as the district's mosque until a permanent one is built (p.163).

```world locations.locations.reclamation_zone_12
{
	"name": "Mobile Mosque Prayer Center", "district": "reclamation_zone", "number": 12, "type": "church",
	"owner": "", "owner_name": "Imam Rojas (Rockerboy 2/Tech 4)",
	"security_code": {"n": 8, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Imam Rojas (Rockerboy 2/Tech 4)"],
	"hooks": [{"text": "The Imam is in talks with Muslims working at the Spaceport to raise funds for a permanent mosque.", "gigs": []}],
	"gigs": [],
	"interior": "Expanding truck hall with white-noise walls, outdoor washing stations and call-to-prayer speakers.",
	"cite": "NC2045 p.163"
}
```

### #13 NCART Yards

The heart of the district, where the city's buses and trains are stored and repaired around the clock (p.163).
The district's history mentions occasional sabotage that locals pin on Haakensen (p.159).

```world locations.locations.reclamation_zone_13
{
	"name": "NCART Yards", "district": "reclamation_zone", "number": 13, "type": "rail",
	"owner": "ncart", "owner_name": "NCART (the Dorado Clan)",
	"security_code": {"n": 9, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": 3,
	"npcs": ["Santos Dorado (Nomad 4/Exec 6)"],
	"hooks": [{"text": "The district suffers occasional sabotage that locals suspect Haakensen of sponsoring.", "gigs": ["sabotage"]}],
	"gigs": ["sabotage"],
	"interior": "Engines, a dozen train cars and buses on the lot; repair vehicles, railcars and pump trucks for flooded tunnels; kombi mobile offices for Santos and managers; a bunk container for drivers; Solo guards.",
	"cite": "NC2045 p.163"
}
```

### #14 Reclamation Zone Station

A Dorado-restored Beaux-Arts NCART station with a day market under the main platform (p.163).

```world locations.locations.reclamation_zone_14
{
	"name": "Reclamation Zone Station", "district": "reclamation_zone", "number": 14, "type": "transport",
	"owner": "ncart", "owner_name": "NCART (the Dorado Clan)",
	"security_code": {"n": 8, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": 3,
	"npcs": ["Webspinner (Netrunner 4)"],
	"hooks": [{"text": "Eggheadz owner Webspinner is rumoured to be a Mudang Gumi agent.", "gigs": ["data_theft"]}],
	"gigs": ["data_theft"],
	"interior": "Beaux-Arts station; the Underground Market below the platform: Carmen's Cosmetics, Eggheadz (cyberdecks and programs), Forever Beautiful (plastic flowers), Forgotten Treasures (scrap jewellery), Underground Bodega (Mrs. Suzuki's chain).",
	"cite": "NC2045 p.163"
}
```

### #15 Second City Solos Firing Range

A favourite local hangout: cheap ammo, rifles and wings, Saturday sharpshooting contests with betting (p.163-164).

```world locations.locations.reclamation_zone_15
{
	"name": "Second City Solos Firing Range", "district": "reclamation_zone", "number": 15, "type": "venue",
	"owner": "", "owner_name": "Phoebe \"Deadeye\" Baro (Fixer 6)",
	"security_code": {"n": 8, "faction": "los_perros_guardianes", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Phoebe \"Deadeye\" Baro (Fixer 6)"],
	"hooks": [{"text": "Phoebe quietly handles jobs for most of the district's power players, the City Manager included.", "gigs": []}],
	"gigs": [],
	"interior": "Rifle range; apartments above.",
	"cite": "NC2045 p.163"
}
```

## Fixers

- Phoebe "Deadeye" Baro (Fixer 6), Second City Solos Firing Range: the district's sharpest fixer; side jobs for its power players, runs the range betting (p.164).
- Earl Mahoney (Fixer 4), Earl's Second Hand Shop: second-hand goods, fair loans, takes trade or services (p.161).

## Personalities

- Chapel "Titan" Suluku (Solo 4/Tech 2): leader of Los Perros Guardianes and their dogs; pays for intel on Kill Krasher raids (p.164).
- Mason Dorado (Tech 2): Santos' grandson, a poor junkyard manager who wants to be a metal sculptor in Upper Marina (p.164).
- Phoebe "Deadeye" Baro (Fixer 6): range owner and the district's most cunning fixer (p.164).
- Quinn Simone (Exec 4): the Dorados' head accountant and racing fanatic who knows every fast driver (p.164).
- Saint Ambrose: wandering street preacher; his daughter Bae (Medtech 4) treats people for free while he preaches (p.164).
- Tucker Twist (Nomad 4): Snake Nation brawler who sees the Dorados' settling down as a stain on nomad honour (p.164).
