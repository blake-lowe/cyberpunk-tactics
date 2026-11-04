# Watson Development

Night City's boomtown, built over North Oak and old Westbrook with money from the Night City Co-Prosperity Sphere (Kiroshi, Kendachi, Segotari, Sanroo, Makigai, Towa). Megabuildings H10 and H11 rise beside new factories in the Fork, while Petrochem and SovOil glare at each other across the street. The NCCS-backed Tyger Claws rule the underworld but the rebuilding Kanzaki Family pushes back, and the Arzin Tynon have turned smuggler. (NC2045 p.186-187)

```world city.districts.watson_development
{
	"name": "Watson Development",
	"region": "northside",
	"manager": {
		"name": "Lucius Rhyne",
		"role": "Rockerboy 7"
	},
	"population": "young and fast-growing: Night City locals, Pacifica job-seekers, Asian immigrants brought in by the NCCS and settled ex-nomads; the city's highest birth rate",
	"security_code": {
		"n": 7,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": 3,
	"provider": "ncpd",
	"gangs": [
		"tyger_claws",
		"kanzaki_family",
		"arzin_tynon",
		"dragula_racers",
		"g3",
		"wild_things"
	],
	"ncart": [
		"NCART Red Line station",
		"NCART Green Line station",
		"Exec Monorail station"
	],
	"profile": "mixed_residential",
	"look": [
		"neon",
		"new megabuildings",
		"construction sites",
		"factories",
		"crowded conapts",
		"Japanese signage"
	],
	"history": "Raised on the ruins of North Oak and old Westbrook with NCCS money; last year a three-day district-wide strike forced open elections that swept organiser Lucius Rhyne in as City Manager.",
	"cite": "NC2045 p.186-199"
}
```

## Locations

### #1 Akagi-ryu Karate

A dojo teaching karate plus Japanese language and culture; the family's son runs the Tyger Claws' Kimen-Gumi.

```world locations.locations.watson_development_1
{
	"name": "Akagi-ryu Karate",
	"district": "watson_development",
	"number": 1,
	"type": "school",
	"owner": "",
	"owner_name": "Akagi family",
	"security_code": {
		"n": 8,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Kenji Akagi (Solo 5)",
		"Takeru Akagi (Solo 4)"
	],
	"hooks": [
		{
			"text": "Patriarch Kenji Akagi trained Arasaka troops before the 4CW, and nobody is sure where his loyalties lie now.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "Takeru Akagi, head of the Kimen-Gumi, drops by to scout recruits.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"data_theft"
	],
	"interior": "",
	"cite": "NC2045 p.187"
}
```

### #2 Canadian Consulate

Canada's mission in Night City, run by an overworked consul with several secrets.

```world locations.locations.watson_development_2
{
	"name": "Canadian Consulate",
	"district": "watson_development",
	"number": 2,
	"type": "civic",
	"owner": "canadian_consulate",
	"owner_name": "Canadian Consulate (Lexi Kane, Exec 4/Netrunner 5/Solo 3)",
	"security_code": {
		"n": 10,
		"faction": "canadian_consulate",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Lexi Kane (Exec 4/Netrunner 5/Solo 3)"
	],
	"hooks": [
		{
			"text": "Rumour says the consulate covers a Canadian operation to recover Old Net data.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "Kane helps Petrochem in its efforts against SovOil.",
			"gigs": [
				"data_theft",
				"sabotage"
			]
		},
		{
			"text": "Kane is having an affair with City Manager Lucius Rhyne.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"interior": "Clean, heavily automated offices guarded by a detachment of Canadian soldiers; Kane and three clerks live on site.",
	"cite": "NC2045 p.189"
}
```

### #3 City Tot Daycare

A well-run daycare for under-sixes that doubles as a smuggling hub.

```world locations.locations.watson_development_3
{
	"name": "City Tot Daycare",
	"district": "watson_development",
	"number": 3,
	"type": "school",
	"owner": "arzin_tynon",
	"owner_name": "Arzin Tynon",
	"security_code": {
		"n": 6,
		"faction": "arzin_tynon",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The daycare is an Arzin Tynon front; smuggled goods move through its garage in diaper-service trucks several times a day.",
			"gigs": [
				"gang_hit",
				"sabotage",
				"data_theft"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"sabotage"
	],
	"interior": "Daycare with a garage that service trucks pull in and out of all day.",
	"cite": "NC2045 p.189"
}
```

### #4 Ebunike Docks

Just outside the district but crewed by Watson residents; Kimen-Gumi keep order.

```world locations.locations.watson_development_4
{
	"name": "Ebunike Docks",
	"district": "watson_development",
	"number": 4,
	"type": "docks",
	"owner": "nccs",
	"owner_name": "Night City Co-Prosperity Sphere",
	"security_code": {
		"n": 9,
		"faction": "kimen_gumi",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The docks let NCCS corps land Asian cargo from Darangen sea nomads without going through the Thelas-run Port; relations with the Thelas are cordial for now.",
			"gigs": [
				"sabotage"
			]
		},
		{
			"text": "Tyger Claws sell drugs and gambling to the dock workers.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"sabotage",
		"gang_hit"
	],
	"interior": "Laborers in linear frames unload crates onto trucks for the Fork; a ship is said to be permanently moored here.",
	"cite": "NC2045 p.189"
}
```

### #5 Faisal's Customs

Two businesses under one name: Faisal's bespoke weapon workshop, and partner Buggy's factory of knock-offs.

```world locations.locations.watson_development_5
{
	"name": "Faisal's Customs",
	"district": "watson_development",
	"number": 5,
	"type": "gun_shop",
	"owner": "",
	"owner_name": "Faisal (Tech 8) and Bobby \"Buggy\" Ballard (Fixer 5)",
	"security_code": {
		"n": 8,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Faisal (Tech 8)",
		"Bobby \"Buggy\" Ballard (Fixer 5)"
	],
	"hooks": [
		{
			"text": "Genius weaponsmith Faisal keeps moving, convinced a big arms maker will snatch him with an assault squad.",
			"gigs": [
				"corp_extraction",
				"rescue"
			]
		},
		{
			"text": "Buggy mass-produces cheap guns from Faisal's unfinished sketches.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"corp_extraction",
		"data_theft"
	],
	"interior": "A small factory where low-level Techs turn out vendit and bodega firearms around the clock.",
	"cite": "NC2045 p.189"
}
```

### #6 The Fork

Factories and warehouses on poisoned land, many running day and night; the NCCS corps moved in first and others followed for cheap land and labour.

```world locations.locations.watson_development_6
{
	"name": "The Fork",
	"district": "watson_development",
	"number": 6,
	"type": "factory",
	"owner": "",
	"owner_name": "NCCS member corporations and others",
	"security_code": {
		"n": 7,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Rumour puts Night City's Elflines Online servers in the basement of the Segotari console plant.",
			"gigs": [
				"data_theft",
				"sabotage"
			]
		},
		{
			"text": "Gibson Battlegear wants to expand but Towa owns the best nearby land.",
			"gigs": [
				"sabotage"
			]
		},
		{
			"text": "After dark gogangs, nomads and street racers own the roads; the Dragula Racers hold the monthly wins record.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"sabotage",
		"data_theft",
		"gang_hit"
	],
	"interior": "Polluted industrial zone west of the base. Code drops to 4 (NCPD, Hardened Light) at night. Sites: 6a Bodyweight distribution centre, 6b Cactus Water bottling plant (closed), 6c Gibson Battlegear armour plant, 6d Hammered Industries chemical warehouse, 6e Kendachi distribution hub, 6f Kiroshi cyberoptics plant, 6g Makigai auto factory (awaiting parts), 6h Segotari console plant, 6i Towa weapons plant (just broke ground).",
	"cite": "NC2045 p.189"
}
```

### #7 FūdHouse

Continental Brands' new fast-food chain: cheap prepak, loud corporate pop, and a claw-machine token in every box.

```world locations.locations.watson_development_7
{
	"name": "FūdHouse",
	"district": "watson_development",
	"number": 7,
	"type": "restaurant",
	"owner": "continental_brands",
	"owner_name": "Continental Brands",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.190"
}
```

### #8 Gibson Battlegear Outlet

Watson's go-to armour store; occasionally stocks pricier pieces, and off-duty cops are regulars.

```world locations.locations.watson_development_8
{
	"name": "Gibson Battlegear Outlet",
	"district": "watson_development",
	"number": 8,
	"type": "shop",
	"owner": "",
	"owner_name": "Gibson Battlegear",
	"security_code": {
		"n": 8,
		"faction": "ncpd",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage"
	],
	"interior": "",
	"cite": "NC2045 p.190"
}
```

### #9 Hammered Up Liquor

Liquor store selling Hammered Industries' cheap chemical-mix drinks.

```world locations.locations.watson_development_9
{
	"name": "Hammered Up Liquor",
	"district": "watson_development",
	"number": 9,
	"type": "shop",
	"owner": "",
	"owner_name": "Hammered Industries",
	"security_code": {
		"n": 6,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.190"
}
```

### #10 HTown

A tent city cleared by bribed cops to make way for an Exec suburb, which promptly regrew against the suburb's wall.

```world locations.locations.watson_development_10
{
	"name": "HTown",
	"district": "watson_development",
	"number": 10,
	"type": "squat",
	"owner": "arzin_tynon",
	"owner_name": "Arzin Tynon (Jimmy \"Dequiallo\" Miles, Nomad 4/Solo 4)",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Jimmy \"Dequiallo\" Miles (Nomad 4/Solo 4)"
	],
	"hooks": [
		{
			"text": "Every few weeks NCPD or hired muscle tries to clear the camp, and the Arzin Tynon lead its residents in the fight back.",
			"gigs": [
				"gang_hit"
			]
		},
		{
			"text": "The Arzin Tynon run their smuggling operation from the camp.",
			"gigs": [
				"gang_hit",
				"sabotage"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"sabotage"
	],
	"interior": "A homeless camp rebuilt against the east wall of a half-empty gated Exec community put up by Future BuildWorks.",
	"cite": "NC2045 p.190"
}
```

### #11 Hundred Under Haven

Petrochem's 'Euro Shop' chain, everything 100eb or less; its stock tracking is so poor that shoplifting and back-room sales are routine.

```world locations.locations.watson_development_11
{
	"name": "Hundred Under Haven",
	"district": "watson_development",
	"number": 11,
	"type": "shop",
	"owner": "petrochem",
	"owner_name": "Petrochem",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.191"
}
```

### #12 Joint Temporary Housing Solution

Stopgap housing that Petrochem and SovOil staff are forced to share.

```world locations.locations.watson_development_12
{
	"name": "Joint Temporary Housing Solution",
	"district": "watson_development",
	"number": 12,
	"type": "housing",
	"owner": "petrochem",
	"owner_name": "Petrochem and SovOil",
	"security_code": {
		"n": 5,
		"faction": "petrochem",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Both corps' previous housing blocks were destroyed by unknown parties.",
			"gigs": [
				"sabotage"
			]
		},
		{
			"text": "A Rhyne-brokered truce splits elevators and tennis courts between the rival staff; one bad day could turn it into a war zone.",
			"gigs": [
				"sabotage",
				"assassination"
			]
		}
	],
	"gigs": [
		"sabotage"
	],
	"interior": "Cheaply thrown-together block: left elevator Petrochem, right SovOil; east tennis court Petrochem, west SovOil; shared rooftop jacuzzi; the pool is still disputed.",
	"cite": "NC2045 p.191"
}
```

### #13 Megabuilding H10

Night City's first finished megabuilding, sold as proof of the city's recovery.

```world locations.locations.watson_development_13
{
	"name": "Megabuilding H10",
	"district": "watson_development",
	"number": 13,
	"type": "megabuilding",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 7,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Dahlia VDB (Netrunner 2/Fixer 5)",
		"Byeol Jeong (Solo 5)",
		"Zillah Zane (Exec 7)"
	],
	"hooks": [
		{
			"text": "G3 is rumoured to be sabotaging 98.2 Shiv FM's Saturday parties, which have turned violent.",
			"gigs": [
				"sabotage",
				"gang_hit"
			]
		},
		{
			"text": "G3 sell media chips, drugs and sex on the lower levels, to NCPD's annoyance.",
			"gigs": [
				"gang_hit"
			]
		},
		{
			"text": "Most of Watson Community College's Night Corp grant went into the owner's pocket.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"sabotage",
		"data_theft"
	],
	"interior": "Cubes on the lower floors, then container-size units, conapts and apartments, up to luxury suites with private bars and the members-only Highwall Club; courtyard basketball. Tenants: 98.2 Shiv FM (roof), Big H Casino (pachinko, monthly high-stakes poker), Data Inc, Hammer Me Nail Salon, United Martial Arts, Watson Community College.",
	"cite": "NC2045 p.191"
}
```

### #14 Megabuilding H11

The second megabuilding, built by a Yakuza-backed developer.

```world locations.locations.watson_development_14
{
	"name": "Megabuilding H11",
	"district": "watson_development",
	"number": 14,
	"type": "megabuilding",
	"owner": "kanzaki_family",
	"owner_name": "Future BuildWorks (Kanzaki-backed; CEO Yasume Ishioda, Exec 4)",
	"security_code": {
		"n": 7,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Yumeko (Netrunner 4)",
		"Yasume Ishioda (Exec 4)"
	],
	"hooks": [
		{
			"text": "Rumour says H11's foundations are full of the bodies of people who crossed the Kanzaki Family.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "The Kanzakis are said to plant subliminal messages through Delta 777's braindances.",
			"gigs": [
				"data_theft",
				"sabotage"
			]
		},
		{
			"text": "The Wild Things recruit fighters at Iron Spirit.",
			"gigs": [
				"gang_hit"
			]
		},
		{
			"text": "Future BuildWorks CEO Yasume Ishioda still pines for PI Kenshiro Saeba and might leave her loveless Kanzaki marriage for him.",
			"gigs": [
				"corp_extraction",
				"rescue"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage",
		"gang_hit",
		"corp_extraction"
	],
	"interior": "Only partly built; lower floors already house factory and dock workers. Tenants: 107.2 KCP2, Delta 777 braindance parlour, Divine Tastes, Future BuildWorks office, Iron Spirit boxing gym, Savage Docs North (two Medtechs).",
	"cite": "NC2045 p.192"
}
```

### #15 Morgan's

Pistols and basic armour for anyone; the heavy stuff only for regulars, and he knows who has what he lacks.

```world locations.locations.watson_development_15
{
	"name": "Morgan's",
	"district": "watson_development",
	"number": 15,
	"type": "gun_shop",
	"owner": "",
	"owner_name": "Morgan (Fixer 3)",
	"security_code": {
		"n": 7,
		"faction": "locals",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Morgan (Fixer 3)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "A weapons-and-armour food truck, usually parked on Jankel Street.",
	"cite": "NC2045 p.192"
}
```

### #16 NCPD Precinct #3

Watson's veteran-heavy precinct, unusually well armed thanks to a Militech training-and-discount deal.

```world locations.locations.watson_development_16
{
	"name": "NCPD Precinct #3",
	"district": "watson_development",
	"number": 16,
	"type": "police",
	"owner": "ncpd",
	"owner_name": "NCPD (Captain Tom Stone, Lawman 7)",
	"security_code": {
		"n": 10,
		"faction": "ncpd",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Tom Stone (Lawman 7)",
		"Leila Amani (Medtech 4)"
	],
	"hooks": [
		{
			"text": "Excessive-force complaints are up 50% since the strike, and Captain Stone nearly came to blows with City Manager Rhyne.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft",
		"rescue"
	],
	"interior": "Ground floor: small lobby, motor pool and high-speed pursuit unit; upper floors: offices, squad and briefing rooms, armories, evidence lock-up, interrogation; top two floors the NCPD Academy; roof AV and gyrocopter pads; basement morgue and holding cells. The Blue Ranger seized-goods store is across the street.",
	"cite": "NC2045 p.192"
}
```

### #17 NeoSoviet Consulate

The NeoSoviet mission, placed in Watson rather than the Glen because of the government's closeness to SovOil.

```world locations.locations.watson_development_17
{
	"name": "NeoSoviet Consulate",
	"district": "watson_development",
	"number": 17,
	"type": "civic",
	"owner": "sovoil",
	"owner_name": "NeoSoviet Consulate (Tanya Makarova, Exec 5)",
	"security_code": {
		"n": 10,
		"faction": "sovoil",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Tanya Makarova (Exec 5)"
	],
	"hooks": [
		{
			"text": "At least one of the consul's seven clerks spies for the Consortium.",
			"gigs": [
				"data_theft",
				"corp_extraction"
			]
		}
	],
	"gigs": [
		"data_theft",
		"corp_extraction"
	],
	"interior": "Brutalist building built to survive an invasion, guarded by SovOil security; no staff live on site.",
	"cite": "NC2045 p.193"
}
```

### #18 The Obituary

Home base of the Dragula Racers gogang.

```world locations.locations.watson_development_18
{
	"name": "The Obituary",
	"district": "watson_development",
	"number": 18,
	"type": "gang_base",
	"owner": "dragula_racers",
	"owner_name": "Dragula Racers (Frankie Sparks, Nomad 6)",
	"security_code": {
		"n": 8,
		"faction": "dragula_racers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Frankie Sparks (Nomad 6)"
	],
	"hooks": [],
	"gigs": [
		"gang_hit"
	],
	"interior": "Converted warehouse with room for dozens of vehicles, horror-movie decor; the leader lives in the old manager's office above the main floor.",
	"cite": "NC2045 p.193"
}
```

### #19 Old Black Rum Pub

Dockside pub whose bartender also injects Surge (20eb) to keep laborers awake through triple shifts.

```world locations.locations.watson_development_19
{
	"name": "Old Black Rum Pub",
	"district": "watson_development",
	"number": 19,
	"type": "bar",
	"owner": "",
	"owner_name": "Doc Brutus (Medtech 1/Nomad 2)",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Doc Brutus (Medtech 1/Nomad 2)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.193"
}
```

### #20 Oumei-ji Temple

Buddhist memorial to Japanese-American 4CW victims and a sanctuary for the Tyger Claws.

```world locations.locations.watson_development_20
{
	"name": "Oumei-ji Temple",
	"district": "watson_development",
	"number": 20,
	"type": "church",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 7,
		"faction": "tyger_claws",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Houses an 18 m hollow Buddha (the Night City Daibutsu) said to hold scriptures, a list of 4CW dead and some of their ashes; Tyger Claws loyalists run street-food stalls out front.",
	"cite": "NC2045 p.193"
}
```

### #21 Petrochem Offices

Petrochem's Night City offices, across the street from its hated rival SovOil.

```world locations.locations.watson_development_21
{
	"name": "Petrochem Offices",
	"district": "watson_development",
	"number": 21,
	"type": "corp_office",
	"owner": "petrochem",
	"owner_name": "Petrochem (Night City ops: William Joseph \"Billy Joe\" Brentwood, Exec 8)",
	"security_code": {
		"n": 9,
		"faction": "petrochem",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"William Joseph \"Billy Joe\" Brentwood (Exec 8)"
	],
	"hooks": [
		{
			"text": "NCPD detectives come about once a week to look into another murder.",
			"gigs": [
				"assassination"
			]
		},
		{
			"text": "Billy Joe Brentwood's vices make him a favourite blackmail target, though blackmailers tend to end up in the harbour.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "Brentwood hates his SovOil counterpart across the street with a murderous passion.",
			"gigs": [
				"assassination",
				"sabotage"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage",
		"assassination",
		"corp_extraction"
	],
	"interior": "Fortified; public access only to a small propaganda museum and gift shop, everything beyond biometrically locked and patrolled around the clock.",
	"cite": "NC2045 p.193"
}
```

### #22 Petrochem Oil Refinery

Refines crude from fields north of the city into oils and plastics.

```world locations.locations.watson_development_22
{
	"name": "Petrochem Oil Refinery",
	"district": "watson_development",
	"number": 22,
	"type": "factory",
	"owner": "petrochem",
	"owner_name": "Petrochem",
	"security_code": {
		"n": 9,
		"faction": "petrochem",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The strip between the Petrochem and SovOil refineries is a no man's land where guards from both sides shoot intruders.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage"
	],
	"interior": "",
	"cite": "NC2045 p.194"
}
```

### #23 The Pochinko Carnival

A nomad carnival that has stayed put for four years since its founder fell ill.

```world locations.locations.watson_development_23
{
	"name": "The Pochinko Carnival",
	"district": "watson_development",
	"number": 23,
	"type": "attraction",
	"owner": "",
	"owner_name": "Pochinko clan of Blood Nation nomads (Libby Manseau, Nomad 4/Rockerboy 5)",
	"security_code": {
		"n": 10,
		"faction": "locals",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Libby Manseau (Nomad 4/Rockerboy 5)"
	],
	"hooks": [
		{
			"text": "The carnival pays a 10eb bounty for every genuine Bozo nose.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"gang_hit"
	],
	"interior": "Small boardwalk of well-kept rides and games; nightly show by classically trained clowns.",
	"cite": "NC2045 p.194"
}
```

### #24 Red Oktober

Soviet-sub themed bar and restaurant with costumed staff and 20eb vodka.

```world locations.locations.watson_development_24
{
	"name": "Red Oktober",
	"district": "watson_development",
	"number": 24,
	"type": "bar",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Built in a disused subway station, dressed as a Soviet submarine.",
	"cite": "NC2045 p.194"
}
```

### #25 Redline

Nightly bloodsport between Wild Things and challengers; even the Yakuza and Tyger Claws leave it alone.

```world locations.locations.watson_development_25
{
	"name": "Redline",
	"district": "watson_development",
	"number": 25,
	"type": "bar",
	"owner": "wild_things",
	"owner_name": "Wild Things (Jenny Nails, Fixer 3/Solo 6)",
	"security_code": {
		"n": 10,
		"faction": "wild_things",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Jenny Nails (Fixer 3/Solo 6)"
	],
	"hooks": [
		{
			"text": "Redline has long been rumoured to host death matches; nobody has proved it.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"data_theft"
	],
	"interior": "A bar built around a fighting pit.",
	"cite": "NC2045 p.194"
}
```

### #26 Sakura's

A decades-old izakaya, moved from Old Japantown; neutral ground for the Tyger Claws and the Kanzaki Family.

```world locations.locations.watson_development_26
{
	"name": "Sakura's",
	"district": "watson_development",
	"number": 26,
	"type": "bar",
	"owner": "",
	"owner_name": "Toru Evans",
	"security_code": {
		"n": 6,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Toru Evans"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.194"
}
```

### #27 SkidRow Limited

The hottest new West Coast design house, the street-merc's label of choice.

```world locations.locations.watson_development_27
{
	"name": "SkidRow Limited",
	"district": "watson_development",
	"number": 27,
	"type": "shop",
	"owner": "",
	"owner_name": "SkidRow Limited",
	"security_code": {
		"n": 6,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "SkidRow is said to be negotiating with Danger Gal on a Puma Squad-style armour line, and rival Gibson Battlegear is furious; a bloody fashion war may be coming.",
			"gigs": [
				"sabotage",
				"data_theft",
				"corp_extraction"
			]
		}
	],
	"gigs": [
		"sabotage",
		"data_theft",
		"corp_extraction"
	],
	"interior": "",
	"cite": "NC2045 p.195"
}
```

### #28 Smash/Cut

Dance club owned by the EDM band UBRIS: dancing, drugs and hookups.

```world locations.locations.watson_development_28
{
	"name": "Smash/Cut",
	"district": "watson_development",
	"number": 28,
	"type": "club",
	"owner": "",
	"owner_name": "UBRIS (EDM band)",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "A few tables around a huge dance floor, wall vidscreens and floor/ceiling holoprojectors; staff use sign language over the noise.",
	"cite": "NC2045 p.195"
}
```

### #29 Snack & Shack

A container bodega and flophouse with something much worse at the back.

```world locations.locations.watson_development_29
{
	"name": "Snack & Shack",
	"district": "watson_development",
	"number": 29,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 4,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Tyger Claws 'artists' record XBDs in the rear containers; ignore the screams.",
			"gigs": [
				"rescue",
				"gang_hit"
			]
		}
	],
	"gigs": [
		"rescue",
		"gang_hit"
	],
	"interior": "Cargo containers: the front two welded into a bodega, the middle rented as month-to-month housing, the rear used as an XBD studio.",
	"cite": "NC2045 p.195"
}
```

### #30 SovOil Offices

SovOil's Night City offices, mirror image of Petrochem's across the street.

```world locations.locations.watson_development_30
{
	"name": "SovOil Offices",
	"district": "watson_development",
	"number": 30,
	"type": "corp_office",
	"owner": "sovoil",
	"owner_name": "SovOil (regional director Jami \"Sharkeater\" Tealov, Exec 8)",
	"security_code": {
		"n": 9,
		"faction": "sovoil",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Jami \"Sharkeater\" Tealov (Exec 8)"
	],
	"hooks": [
		{
			"text": "NCPD detectives come about once a week to look into another murder.",
			"gigs": [
				"assassination"
			]
		},
		{
			"text": "Tealov keeps up his feud with Petrochem's Brentwood, some say mostly for laughs.",
			"gigs": [
				"assassination",
				"sabotage"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage",
		"assassination",
		"corp_extraction"
	],
	"interior": "Fortified; public access only to a small propaganda museum and gift shop, everything beyond biometrically locked and patrolled around the clock.",
	"cite": "NC2045 p.195"
}
```

### #31 SovOil Oil Refinery

SovOil's refinery, twin of Petrochem's next door.

```world locations.locations.watson_development_31
{
	"name": "SovOil Oil Refinery",
	"district": "watson_development",
	"number": 31,
	"type": "factory",
	"owner": "sovoil",
	"owner_name": "SovOil",
	"security_code": {
		"n": 9,
		"faction": "sovoil",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The strip between the SovOil and Petrochem refineries is a no man's land where guards from both sides shoot intruders.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage"
	],
	"interior": "",
	"cite": "NC2045 p.195"
}
```

### #32 Trauma Team Tower

Trauma Team's Night City base and Pacifica Confederation regional HQ, with the best medical facilities in the city.

```world locations.locations.watson_development_32
{
	"name": "Trauma Team Tower",
	"district": "watson_development",
	"number": 32,
	"type": "corp_hq",
	"owner": "trauma_team",
	"owner_name": "Trauma Team",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"interior": "Client-only hospital, AV maintenance and launch bays for each squad, tactical air control tower; dispatch and executive offices buried in the subbasement. Lazarus guards it and all TT staff carry arms on duty.",
	"cite": "NC2045 p.195"
}
```

### #33 Trauma Team Corporate Living Center

Secure, sterile housing for Trauma Team staff and their families.

```world locations.locations.watson_development_33
{
	"name": "Trauma Team Corporate Living Center",
	"district": "watson_development",
	"number": 33,
	"type": "housing",
	"owner": "trauma_team",
	"owner_name": "Trauma Team",
	"security_code": {
		"n": 9,
		"faction": "trauma_team",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Every surface is covered in biosensors, and residents suspect the data goes to management despite promises of confidentiality.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft",
		"corp_extraction"
	],
	"interior": "'The Ward': linked to the Tower by an access tunnel; gym and rec centre with smoothie bar, urgent care clinic, in-house therapists.",
	"cite": "NC2045 p.196"
}
```

### #34 Turbo Neon Motors

Custom car shop whose builds even nomads respect.

```world locations.locations.watson_development_34
{
	"name": "Turbo Neon Motors",
	"district": "watson_development",
	"number": 34,
	"type": "chop_shop",
	"owner": "",
	"owner_name": "Cesar (Tech 8) and Akira-119 (Fixer 5)",
	"security_code": {
		"n": 7,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Cesar (Tech 8)",
		"Akira-119 (Fixer 5)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Two storeys, six service bays, on-site custom parts fabrication.",
	"cite": "NC2045 p.196"
}
```

### #35 UnoMas Mexican Bar & Grill

Cheap beer, tequila and SCOP tacos for H11 builders and Fork workers; its real Mexican beer probably comes via the Jodes.

```world locations.locations.watson_development_35
{
	"name": "UnoMas Mexican Bar & Grill",
	"district": "watson_development",
	"number": 35,
	"type": "bar",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.196"
}
```

### #36 Vargtimmen

Viking-themed meadery run by a neo-pagan priestess who won't say where her honey comes from.

```world locations.locations.watson_development_36
{
	"name": "Vargtimmen",
	"district": "watson_development",
	"number": 36,
	"type": "bar",
	"owner": "",
	"owner_name": "Freki (Rockerboy 2/Tech 4)",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Freki (Rockerboy 2/Tech 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.196"
}
```

### #37 Watson Central Cubelife

Soul-crushingly bland cube block for low-level corporate drones.

```world locations.locations.watson_development_37
{
	"name": "Watson Central Cubelife",
	"district": "watson_development",
	"number": 37,
	"type": "cube_hotel",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 4,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.196"
}
```

### #38 Whammer Arena

Home of the Watson Whammers and offices of the Wonderland Roller Derby League.

```world locations.locations.watson_development_38
{
	"name": "Whammer Arena",
	"district": "watson_development",
	"number": 38,
	"type": "stadium",
	"owner": "",
	"owner_name": "Watson Whammers / Wonderland Roller Derby League",
	"security_code": {
		"n": 8,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "3,000 seats with modern broadcast gear; also rented for concerts.",
	"cite": "NC2045 p.196"
}
```

## Fixers

- Bobby "Buggy" Ballard (Fixer 5) — Faisal's Customs (#5); sells mass-made guns from Faisal's designs and is the easy way to reach Faisal (p.189).
- Morgan (Fixer 3) — Morgan's truck (#15), Jankel Street; weapons and armour, serious gear for regulars, knows other sources (p.192).
- Dahlia VDB (Netrunner 2/Fixer 5) — Data Inc in Megabuilding H10 (#13); reliable, favours Netrunners and crews that work without gunfire (p.196).
- Akira-119 (Fixer 5) — Turbo Neon Motors (#34); custom vehicles and parts (p.196).
- Jenny Nails (Fixer 3/Solo 6) — Redline (#25); Wild Things leader, books fights (p.194).

## Personalities

- Lucius Rhyne (Rockerboy 7) — City Manager; radical organiser elected after his strike, popular weekly radio talks (p.187).
- Tom Stone (Lawman 7) — captain of Precinct #3, openly at odds with Rhyne (p.187).
- Dahlia VDB (Netrunner 2/Fixer 5) — Netrunner-friendly fixer at Data Inc (p.196).
- Frankie Sparks (Nomad 6) — Frankenstein-sculpted leader of the Dragula Racers, races her Hearse most nights (p.197).
- Jami "Sharkeater" Tealov (Exec 8) — SovOil regional director, rose from pipeline guard; jokey rival of Brentwood (p.197).
- Jimmy "Dequiallo" Miles (Nomad 4/Solo 4) — turned the Arzin Tynon into a smuggling outfit; respects anyone who arm-wrestles him hard (p.197).
- Leila Amani (Medtech 4) — idealistic assistant coroner at Precinct #3's morgue (p.197).
- Libby Manseau (Nomad 4/Rockerboy 5) — ailing founder of the Pochinko Carnival (p.197).
- Shin Kanzaki (Exec 6) — Kanzaki Family Oyabun who kept the family alive by investing in Future BuildWorks (p.197).
- Tabitha "TSpooks" Evanovich (Media 4) — urban-legend livecaster who hires edgerunner crews as escorts on shoots (p.197).
- William Joseph "Billy Joe" Brentwood (Exec 8) — Texan head of Petrochem's Night City ops, a magnet for blackmailers (p.197).
- Yasume Ishioda (Exec 4) — Shin's sister and Future BuildWorks CEO, unhappily married to Kanzaki lieutenant Jo Ishioda (Solo 5) (p.197).
- Zillah Zane (Exec 7) — Hammered Industries regional manager, famous for parties in her H10 suite (p.197).
- Jackie McGee (Media 5) — the reporter narrating the district guide (p.186).
