# Executive Zone

The Executive Zone is a walled, gated enclave for the city's richest few, guarded by Lazarus operatives who wear a
brain-stem bomb as a condition of the posting. Fewer than a hundred people live here, yet the district holds a full
Council seat. It is governed by a Home Owners' Association whose president is City Manager: Dr. Karen Davies (Exec 6) of
Pol-Bud, who beat Biotechnica's Dr. Heather Stein (Exec 5/Tech 4) by one vote. Labourers wear locked tracking anklets and
keep to strict check-in times (NC2045 p.232-233).

```world city.districts.executive_zone
{
	"name": "Executive Zone",
	"region": "mainland",
	"manager": {
		"name": "Dr. Karen Davies",
		"role": "Exec 6"
	},
	"population": "under 100 permanent residents, plus tracked day labourers and live-in servants",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": 2,
	"provider": "lazarus",
	"gangs": [],
	"ncart": [
		"Executive Zone Station (Executive Monorail)"
	],
	"profile": "executive_zone",
	"look": [
		"walled estates",
		"manicured lawns",
		"drones and turrets",
		"golf tower",
		"gated community"
	],
	"history": "A walled enclave run by its Home Owners' Association; the HOA president sits as City Manager and the last election was won by one vote.",
	"cite": "NC2045 p.232-239"
}
```

## Locations

### #1 The Estates

Around twenty walled estates of the ultra-rich, guarded by Lazarus drones, turrets and decon sprayers. Twelve owners are confirmed (map pins 1a-1l).

```world locations.locations.executive_zone_1
{
	"name": "The Estates",
	"district": "executive_zone",
	"number": 1,
	"type": "villa",
	"owner": "",
	"owner_name": "~20 private owners (residents A-L listed)",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Artyom Sokolov (Exec 10/Tech 6), Zhirafa CEO",
		"Denny (Rockerboy 8)",
		"Eran Malour (Tech 10) and Marie-Louise (Netrunner 4)",
		"Kerry Eurodyne (Rockerboy 9)",
		"Franklin M'bolu (Exec 7/Tech 8), Orbital Air",
		"Heather Stein (Exec 5/Tech 4), Biotechnica",
		"Jami \"Sharkeater\" Tealov (Exec 8), SovOil",
		"Karen Davies (Exec 6), Pol-Bud",
		"Michiko Sanderson (Exec 10)",
		"Mister Kernaghan (Fixer 9)",
		"William Joseph \"Billy Joe\" Brentwood (Exec 8), Petrochem",
		"UR (Exec 10/Rockerboy 7), Ziggurat CEO"
	],
	"hooks": [
		{
			"text": "Ex-HOA president Heather Stein is campaigning to wreck Karen Davies' reputation before the next election; a killing is expected sooner or later.",
			"gigs": [
				"sabotage",
				"assassination"
			]
		},
		{
			"text": "Retired gun designer Eran Malour still tinkers with new firearm designs in his mansion workshop.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "Ziggurat's CEO UR runs his estate with drones instead of servants, all controlled by what may be the city's most elaborate NET Architecture.",
			"gigs": [
				"data_theft",
				"sabotage"
			]
		},
		{
			"text": "Someone sprayed 'Save Morro Rock' across the walls of spaceport chief Franklin M'bolu's estate last year.",
			"gigs": [
				"sabotage"
			]
		},
		{
			"text": "Michiko Sanderson's mansion is the one estate guarded by Danger Gal (Security Code 10, Hardened Heavy) instead of Lazarus.",
			"gigs": [
				"corp_extraction",
				"assassination"
			]
		},
		{
			"text": "Fixer Mister Kernaghan finds anything residents want, including heirs lost on drug binges in the combat zones.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"assassination",
		"corp_extraction",
		"data_theft",
		"sabotage"
	],
	"interior": "About twenty estates, from compact multilevel mansions to sprawling multi-building compounds; each has Lazarus drones, automated turrets and decontamination sprayers plus whatever private security the owner adds. Sanderson's estate (1i) is guarded by Danger Gal instead. The Petrochem and SovOil chiefs' estates share a border.",
	"cite": "NC2045 p.235"
}
```

### #2 Executive Zone Casino/Country Club

The enclave's members' club; outsiders who buy membership get a look at the estates, and bringing a rival as a guest is a power move.

```world locations.locations.executive_zone_2
{
	"name": "Executive Zone Casino/Country Club",
	"district": "executive_zone",
	"number": 2,
	"type": "casino",
	"owner": "",
	"owner_name": "Dallas McKennon (Fixer 8), manager",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Dallas McKennon (Fixer 8)",
		"Vibol Jen (Netrunner 6)"
	],
	"hooks": [
		{
			"text": "Manager Dallas McKennon is rumoured to keep a very rare Goosetopia collectible on show in his office.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "More deals are made in the cigar lounge than in boardrooms, and landscaping chief Vibol Jen overhears far more than he admits.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft"
	],
	"interior": "Casino open 19:00-03:00 with table games only; squash and tennis courts, gym, Segotari arcade, hot tubs, indoor pool; the 18-storey Executive Zone Links tower with one golf hole per floor; restaurant Zest!, poolside bar Seacliff, cigar lounge; a private rink for the Executive Zone Unicorns roller derby squad.",
	"cite": "NC2045 p.235"
}
```

### #3 Firebird Tearoom & Steam Baths

A Slavic tearoom and steam bath where residents take their shadier business meetings.

```world locations.locations.executive_zone_3
{
	"name": "Firebird Tearoom & Steam Baths",
	"district": "executive_zone",
	"number": 3,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Zinaida (Solo 4) and Dragomir (Solo 4), managers",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Zinaida (Solo 4)",
		"Dragomir (Solo 4)"
	],
	"hooks": [
		{
			"text": "Residents bring prospective partners to the private rooms here to settle shadier deals.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "The one-eyed managing cousins are suspected of Consortium ties but actually hate the Russian mob, perhaps over their missing eyes.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"data_theft"
	],
	"interior": "Opulent Slavic tearoom with private dining rooms, each with a samovar; the priciest table has an antique samovar said to be the Romanovs'; saunas kept at winter temperatures with cold plunge pools.",
	"cite": "NC2045 p.236"
}
```

### #4 Groundskeeper Shed

Where netrunning groundskeepers remotely run the irrigation, fertiliser and mowing drones for the district's Realgrass lawns.

```world locations.locations.executive_zone_4
{
	"name": "Groundskeeper Shed",
	"district": "executive_zone",
	"number": 4,
	"type": "data_center",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The anti-Stein faction, quietly backed by the HOA president, hires Netrunners to hack the lawn-care NET Architecture so the grass yellows and Stein loses the vote.",
			"gigs": [
				"sabotage",
				"data_theft"
			]
		}
	],
	"gigs": [
		"sabotage",
		"data_theft"
	],
	"interior": "Netrunners in comfortable chairs jack into the district's landscape NET Architecture, running Control Nodes for irrigation and fertiliser and a fleet of gardening drones.",
	"cite": "NC2045 p.236"
}
```

### #5 Growing Shoots Daycare

The city's most expensive daycare, where every minute of a rich child's day is scheduled.

```world locations.locations.executive_zone_5
{
	"name": "Growing Shoots Daycare",
	"district": "executive_zone",
	"number": 5,
	"type": "school",
	"owner": "",
	"owner_name": "Crane Henshaw (Exec 4), manager",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Crane Henshaw (Exec 4)"
	],
	"hooks": [
		{
			"text": "Lazarus identity checks at pickup have stopped at least three kidnapping attempts in the past year.",
			"gigs": [
				"corp_extraction"
			]
		}
	],
	"gigs": [
		"corp_extraction"
	],
	"interior": "One caretaker per child and a tightly scheduled day; strict ID checks before any child leaves with an adult.",
	"cite": "NC2045 p.236"
}
```

### #6 HOA Offices

The HOA's offices, where neighbours scream about property values and every dispute is on file.

```world locations.locations.executive_zone_6
{
	"name": "HOA Offices",
	"district": "executive_zone",
	"number": 6,
	"type": "civic",
	"owner": "",
	"owner_name": "Executive Zone HOA (President Dr. Karen Davies, Exec 6)",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Dr. Karen Davies (Exec 6)",
		"Dr. Heather Stein (Exec 5/Tech 4)"
	],
	"hooks": [
		{
			"text": "The HOA's records of contractors, votes and dispute case files sit in a custom NET Architecture built by Ziggurat.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"interior": "Lavish offices with a board meeting room, members' chambers and a reception area usually full of shouting; records held in a Ziggurat-designed NET Architecture.",
	"cite": "NC2045 p.236"
}
```

### #7 Lazarus Base of Operations

Lazarus's dedicated base for its biggest Night City contract.

```world locations.locations.executive_zone_7
{
	"name": "Lazarus Base of Operations",
	"district": "executive_zone",
	"number": 7,
	"type": "military",
	"owner": "lazarus",
	"owner_name": "Lazarus",
	"security_code": {
		"n": 11,
		"faction": "lazarus",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Captain Pete Neilson (Exec 2/Solo 5)"
	],
	"hooks": [],
	"gigs": [
		"sabotage",
		"data_theft"
	],
	"interior": "Small walled compound with barracks, mess, a training and exercise yard, a records room with up-to-date resident dossiers, an armoury, anti-aircraft guns and offices.",
	"cite": "NC2045 p.237"
}
```

### #8 Monorail Station

The start of the private executive monorail, which stops in Charter Hill and then runs to corporate sites across the city.

```world locations.locations.executive_zone_8
{
	"name": "Monorail Station",
	"district": "executive_zone",
	"number": 8,
	"type": "transport",
	"owner": "lazarus",
	"owner_name": "Lazarus (operates the Executive Monorail)",
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
		"corp_extraction"
	],
	"interior": "Members-only high-speed monorail start point: boarding needs a CIN card and biometrics; seats ranked by status with a CEO car mid-train; Lazarus guards every station and sweeps cars for bombs, bugs and stowaways.",
	"cite": "NC2045 p.237"
}
```

### #9 Oasis (Exec Zone)

A luxury Oasis store (fresh flowers included) that drone-delivers anywhere in the enclave.

```world locations.locations.executive_zone_9
{
	"name": "Oasis (Exec Zone)",
	"district": "executive_zone",
	"number": 9,
	"type": "shop",
	"owner": "continental_brands",
	"owner_name": "Continental Brands",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Margaret \"Peggy\" Pacer (Fixer 4)"
	],
	"hooks": [
		{
			"text": "Long-serving clerk Peggy Pacer fills 'special orders' for residents' teenage heirs and is said to be close to the Piranhas.",
			"gigs": [
				"gang_hit"
			]
		},
		{
			"text": "Last year a vetted employee cut off his anklet, broke into Puddleforge Games and took staff hostage over a game franchise's plot.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"gang_hit"
	],
	"interior": "Mostly automated luxury store with a few vetted human staff; any item delivered by drone to an estate within minutes.",
	"cite": "NC2045 p.237"
}
```

### #10 Puddleforge Games

A tabletop-game publisher that got rich and moved its whole business into an Executive Zone mansion, to the HOA's fury.

```world locations.locations.executive_zone_10
{
	"name": "Puddleforge Games",
	"district": "executive_zone",
	"number": 10,
	"type": "corp_office",
	"owner": "",
	"owner_name": "the Puddleforge family",
	"security_code": {
		"n": 8,
		"faction": "lazarus",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The HOA board keeps trying to ban home businesses to drive the publisher out; the bylaws keep narrowly failing.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage",
		"rescue"
	],
	"interior": "A mansion converted into family home, staff housing, offices, printing press, warehouse and distribution centre.",
	"cite": "NC2045 p.237"
}
```

### Substations (unnumbered)

Unmapped city utility substations. Lazarus guards them, but they are the weak point in the enclave's security.

```world locations.locations.executive_zone_substations
{
	"name": "Substations",
	"district": "executive_zone",
	"number": null,
	"type": "utility",
	"owner": "city_government",
	"owner_name": "Night City government",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Lazarus struggles to vet the changing roster of maintenance labourers and techs called out to the substations, the one gap in the district's armour.",
			"gigs": [
				"sabotage",
				"data_theft"
			]
		}
	],
	"gigs": [
		"sabotage"
	],
	"interior": "City substations for power, water, sewer, garbage and CitiNet, guarded by Lazarus.",
	"cite": "NC2045 p.237"
}
```

## Fixers

- Mister Kernaghan (Fixer 9): Estates (#1j); the city's top high-end fixer, gets residents anything from party resources to lost heirs (NC2045 p.235).
- Dallas McKennon (Fixer 8): manager of the Casino/Country Club (#2); novelty entertainments for bored rich members (NC2045 p.238).
- Audrey Sanchez (Fixer 5): head of the garbage collection team; disposes of (and profits from) what the ultrarich throw away (NC2045 p.238).
- Margaret "Peggy" Pacer (Fixer 4): Oasis clerk (#9); 'special orders' for residents' teenagers, linked to the Piranhas (NC2045 p.238).

## Personalities

- Ransom: anonymous corporate-gossip source and the district's guide (NC2045 p.232).
- Audrey Sanchez (Fixer 5): runs garbage collection and decides what rich people's trash is worth (NC2045 p.238).
- Captain Pete Neilson (Exec 2/Solo 5): leader of Lazarus's Executive Zone detachment, worn down by entitled residents (NC2045 p.238).
- Crane Henshaw (Exec 4): polite, well-connected Growing Shoots manager who gives away nothing (NC2045 p.238).
- Dallas McKennon (Fixer 8): Casino/Country Club manager hunting for new thrills for members; rumoured rare collectible in his office (NC2045 p.238).
- Margaret "Peggy" Pacer (Fixer 4): veteran Oasis clerk with a side trade for rich teens; reportedly tight with the Piranhas (NC2045 p.238).
- Vibol Jen (Netrunner 6): head of landscaping at the country club who hears more than he lets on (NC2045 p.238).
- Zinaida (Solo 4) and Dragomir (Solo 4): one-eyed identical cousins managing the Firebird; no love for the Consortium (NC2045 p.238).
