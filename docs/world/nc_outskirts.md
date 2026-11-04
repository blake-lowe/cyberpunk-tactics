# The Outskirts

The badlands around Night City (NC2045 p.294-301): cracked roads, stunted scrub and wind turbines across a desert that
has crept outward since the Collapse. It is nominally San Luis Obispo County but nobody really governs it; you stake a
claim or drive to the county seat to make it legal. Reclaimers, farmers, hermits and company towns live here, braced
against dust storms and Raffen Shiv raids. The underfunded Sheriff's deputies are bullies who couldn't make NCPD, and
the NorCal Marshals' Highway Patrol keeps to the main roads. Utility Code varies by site.

```world city.districts.outskirts
{
	"name": "The Outskirts",
	"region": "outskirts",
	"manager": null,
	"population": "Reclaimers, hermits, farmers and stubborn independents by choice, plus corporate company towns and passing nomads",
	"security_code": {
		"n": 5,
		"faction": "san_luis_obispo_county_sheriff",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"provider": "san_luis_obispo_county_sheriff",
	"gangs": [
		"deadwoods",
		"toecutters"
	],
	"ncart": [],
	"profile": "industrial",
	"look": [
		"badlands",
		"cracked highways",
		"wind turbines",
		"dust storms",
		"oil rigs",
		"farmsteads"
	],
	"history": "Lush land turned desert since the Collapse; locals care more about gossip than Raffen Shiv raids or the airport's crashes.",
	"cite": "NC2045 p.294-301"
}
```

## Locations

### #1 107.3 Morro Rock Radio

A volunteer station that Orbital Air took over to pipe music, instructions and quota reminders to its Morro Rock workforce.

```world locations.locations.outskirts_1
{
	"name": "107.3 Morro Rock Radio",
	"district": "outskirts",
	"number": 1,
	"type": "media",
	"owner": "orbital_air",
	"owner_name": "Orbital Air",
	"security_code": {
		"n": 9,
		"faction": "orbital_air",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 3,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage"
	],
	"interior": "",
	"cite": "NC2045 p.295"
}
```

### #2 Independent Farms

Family farms mostly franchised into Biotechnica's TradFarm Initiative, which supplies and buys everything and keeps Continental Brands from razing them.

```world locations.locations.outskirts_2
{
	"name": "Independent Farms",
	"district": "outskirts",
	"number": 2,
	"type": "farm",
	"owner": "",
	"owner_name": "Independent families under Biotechnica's TradFarm franchise",
	"security_code": {
		"n": 6,
		"faction": "san_luis_obispo_county_sheriff",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [
		"Jack Boles (Exec 3)"
	],
	"hooks": [
		{
			"text": "The Ingalls family skims harvest and sells it to high-end city restaurants, breaking their Biotechnica contract.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "Jack Boles' Poppy Farm grows Biotechnica-engineered opium poppies, guarded full-time by Biotechnica (Security Code 10: Biotechnica Security, Medium).",
			"gigs": [
				"sabotage",
				"data_theft"
			]
		},
		{
			"text": "Continental Brands sends troops to burn competing farms; only Biotechnica's stake protects these.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage",
		"data_theft"
	],
	"interior": "2a Edgewood Farm (Harris family dairy, turrets on barn and house); 2b Ingalls Farm (vegetables); 2c Poppy Farm (Jack Boles, full-time Biotechnica guards).",
	"cite": "NC2045 p.295-297"
}
```

### #3 Jackson Plains Regional Airport

A compact regional airport in the Highrider-built network, flown by Folk Nation pilots; aircrews go armed.

```world locations.locations.outskirts_3
{
	"name": "Jackson Plains Regional Airport",
	"district": "outskirts",
	"number": 3,
	"type": "transport",
	"owner": "",
	"owner_name": "Scannelli-Odujinrin Highrider clan; administrator Sionnach Taylor (Nomad 7)",
	"security_code": {
		"n": 9,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [
		"Sionnach Taylor (Nomad 7)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Small airfield with the Calbraith Diner; Aldecaldo Peacekeepers on security.",
	"cite": "NC2045 p.297"
}
```

### #4 Laguna Bend

A reclaimer town on Laguna Reservoir modelled on pre-Collapse small-town life, well armed against raiders and still mourning last year's school shooting (four children and two teachers killed).

```world locations.locations.outskirts_4
{
	"name": "Laguna Bend",
	"district": "outskirts",
	"number": 4,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 7,
		"faction": "san_luis_obispo_county_sheriff",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [
		"Flo Castleberry"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Town square; public school in two wings (east elementary/middle, west high school) now guarded by 6th Street; Flo's Diner; independent CHOOH2 station with bodega; Saint Catherine's church and community centre.",
	"cite": "NC2045 p.297"
}
```

### #5 Municipal Landfill

The city's landfill, run jointly by Petrochem's Coastal Carting and SovOil's SMKP Hauling (security 'Petrochem/SovOil').

```world locations.locations.outskirts_5
{
	"name": "Municipal Landfill",
	"district": "outskirts",
	"number": 5,
	"type": "utility",
	"owner": "petrochem",
	"owner_name": "Coastal Carting (Petrochem) and SMKP Hauling (SovOil)",
	"security_code": {
		"n": 8,
		"faction": "petrochem",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": 5,
	"npcs": [],
	"hooks": [
		{
			"text": "Bored crews from both firms arm up and hunt the scavvers picking through the trash.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"rescue",
		"sabotage"
	],
	"interior": "Dump with both firms' refuse-truck fleets, storage and maintenance yards.",
	"cite": "NC2045 p.297"
}
```

### #6 Night City Spaceport

Orbital Air's rocket and delta spaceport (NCX) on Morro Rock, due to open within three years.

```world locations.locations.outskirts_6
{
	"name": "Night City Spaceport",
	"district": "outskirts",
	"number": 6,
	"type": "transport",
	"owner": "orbital_air",
	"owner_name": "Orbital Air",
	"security_code": {
		"n": 10,
		"faction": "orbital_air",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": 2,
	"npcs": [],
	"hooks": [
		{
			"text": "Orbital Air never built the promised mass driver; Night Corp and the Council quietly scrubbed it from the record.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage",
		"corp_extraction"
	],
	"interior": "Construction site; ~1,000 workers in float homes and cube hotels, mid-ranking staff in Orbital Air Housing Block #1.",
	"cite": "NC2045 p.298"
}
```

### #7 NorCal Marshal Station

The Marshals' mid-sized base outside the city: Highway Patrol HQ and home to a Ranger squad between fugitive hunts.

```world locations.locations.outskirts_7
{
	"name": "NorCal Marshal Station",
	"district": "outskirts",
	"number": 7,
	"type": "police",
	"owner": "norcal_marshal_service",
	"owner_name": "NorCal Marshal Service",
	"security_code": {
		"n": 8,
		"faction": "norcal_marshal_service",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": 3,
	"npcs": [
		"Hilda Forrest (Solo 6)"
	],
	"hooks": [],
	"gigs": [
		"rescue"
	],
	"interior": "Heavily fortified compound; thick razor-wire walls; turrets at each corner.",
	"cite": "NC2045 p.298"
}
```

### #8 Militech Ballistics and Explosives Range

Signposted live-fire and demolition range north of the city, littered with unexploded munitions; also rented to the Estero Bay COG, NCPD and security firms.

```world locations.locations.outskirts_8
{
	"name": "Militech Ballistics and Explosives Range",
	"district": "outskirts",
	"number": 8,
	"type": "military",
	"owner": "militech",
	"owner_name": "Militech",
	"security_code": {
		"n": 3,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 5,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage"
	],
	"interior": "",
	"cite": "NC2045 p.298"
}
```

### #9 Night Corp Solar Station

A big solar array built with PacCon Electric that covers much of the city's power.

```world locations.locations.outskirts_9
{
	"name": "Night Corp Solar Station",
	"district": "outskirts",
	"number": 9,
	"type": "utility",
	"owner": "night_corp",
	"owner_name": "Night Corp with PacCon Electric",
	"security_code": {
		"n": 9,
		"faction": "lazarus",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": 2,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage",
		"data_theft"
	],
	"interior": "Solar field; at least one Lazarus squad with drone surveillance on patrol at all times.",
	"cite": "NC2045 p.298"
}
```

### #10 Northern Oil Fields

Dying oil fields split between Petrochem and SovOil after a decades-old lease dispute that Night Corp brokered into an uneasy peace (security 'Petrochem/SovOil').

```world locations.locations.outskirts_10
{
	"name": "Northern Oil Fields",
	"district": "outskirts",
	"number": 10,
	"type": "factory",
	"owner": "petrochem",
	"owner_name": "Petrochem and SovOil (each runs its own rigs)",
	"security_code": {
		"n": 9,
		"faction": "petrochem",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": 4,
	"npcs": [],
	"hooks": [
		{
			"text": "Rival rig crews squabble constantly; damage is usually minor but workers sometimes turn up murdered.",
			"gigs": [
				"sabotage",
				"assassination"
			]
		}
	],
	"gigs": [
		"sabotage",
		"assassination"
	],
	"interior": "",
	"cite": "NC2045 p.298-299"
}
```

### #11 Petrochem CHOOH2 Station

Small Petrochem fuel stop off Interstate 9 with a little Hundred Under Haven.

```world locations.locations.outskirts_11
{
	"name": "Petrochem CHOOH2 Station",
	"district": "outskirts",
	"number": 11,
	"type": "shop",
	"owner": "petrochem",
	"owner_name": "Petrochem",
	"security_code": {
		"n": 6,
		"faction": "san_luis_obispo_county_sheriff",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 5,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.299"
}
```

### #12 Pol-Bud Cement Factory

The rebuilding city's largest cement supplier, run by a SoCal firm that owns its whole supply chain down to security and housing.

```world locations.locations.outskirts_12
{
	"name": "Pol-Bud Cement Factory",
	"district": "outskirts",
	"number": 12,
	"type": "factory",
	"owner": "pol_bud",
	"owner_name": "Pol-Bud (founded by Franz and Tonya Yanovsky)",
	"security_code": {
		"n": 7,
		"faction": "pol_bud",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [
		"Paweł Ward (Fixer 4)"
	],
	"hooks": [],
	"gigs": [
		"sabotage",
		"data_theft"
	],
	"interior": "",
	"cite": "NC2045 p.299"
}
```

### #13 Pol-Bud Miasto

Pol-Bud's company town for its workers, where everything is company property and bought on wage-garnished credit.

```world locations.locations.outskirts_13
{
	"name": "Pol-Bud Miasto",
	"district": "outskirts",
	"number": 13,
	"type": "housing",
	"owner": "pol_bud",
	"owner_name": "Pol-Bud (Regional Director Dr. Karen Davies lives in the Executive Zone)",
	"security_code": {
		"n": 5,
		"faction": "pol_bud",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 6,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Cargo-container community: homes, bar, CHOOH2 station, bodega, Polish Orthodox chapel.",
	"cite": "NC2045 p.299"
}
```

### #14 Pol-Bud Mine

Pol-Bud's largest limestone mine, worked 24/7 in two shifts at an estimated four or five deaths a month.

```world locations.locations.outskirts_14
{
	"name": "Pol-Bud Mine",
	"district": "outskirts",
	"number": 14,
	"type": "factory",
	"owner": "pol_bud",
	"owner_name": "Pol-Bud",
	"security_code": {
		"n": 6,
		"faction": "pol_bud",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage",
		"rescue"
	],
	"interior": "Pits and tunnels prone to collapses, falls and machinery failures.",
	"cite": "NC2045 p.299"
}
```

### Nomad Campsites

Short-stay nomad groups camp out here instead of the city; approach slowly, hands visible, ideally bearing a gift. Utility Code varies.

```world locations.locations.outskirts_nomad_campsites
{
	"name": "Nomad Campsites",
	"district": "outskirts",
	"number": null,
	"type": "outskirts_site",
	"owner": "",
	"owner_name": "Visiting nomad packs",
	"security_code": {
		"n": 8,
		"faction": "nomads",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.298"
}
```

### Raffen Shiv Campsites

Hidden camps of Raffen Shiv packs such as the Toecutters, exiles who broke the nomad code: the worst danger in the Outskirts. Utility Code varies.

```world locations.locations.outskirts_raffen_shiv_campsites
{
	"name": "Raffen Shiv Campsites",
	"district": "outskirts",
	"number": null,
	"type": "outskirts_site",
	"owner": "toecutters",
	"owner_name": "Raffen Shiv packs (e.g. the Toecutters)",
	"security_code": {
		"n": 2,
		"faction": "san_luis_obispo_county_sheriff",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"interior": "",
	"cite": "NC2045 p.299"
}
```

### #15 Sheriff's Station

The San Luis Obispo County Sheriff's unimpressive concrete outpost in the middle of nowhere.

```world locations.locations.outskirts_15
{
	"name": "Sheriff's Station",
	"district": "outskirts",
	"number": 15,
	"type": "police",
	"owner": "san_luis_obispo_county_sheriff",
	"owner_name": "San Luis Obispo County Sheriff",
	"security_code": {
		"n": 8,
		"faction": "san_luis_obispo_county_sheriff",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"rescue"
	],
	"interior": "One big open space shared by officers and vehicles; razor-wire-topped concrete bollards and a single turret.",
	"cite": "NC2045 p.300"
}
```

### #16 SovOil CHOOH2 Station

Small SovOil fuel stop off the New Pacific Highway with an attached Oasis store.

```world locations.locations.outskirts_16
{
	"name": "SovOil CHOOH2 Station",
	"district": "outskirts",
	"number": 16,
	"type": "shop",
	"owner": "sovoil",
	"owner_name": "SovOil",
	"security_code": {
		"n": 6,
		"faction": "san_luis_obispo_county_sheriff",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 5,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.300"
}
```

### #17 Sunshine Motel

A 20eb-a-night roadside motel with a vendit hall for lone travellers avoiding a night in the city; the Block clan keeps a rocket launcher on the roof for Raffen Shiv.

```world locations.locations.outskirts_17
{
	"name": "Sunshine Motel",
	"district": "outskirts",
	"number": 17,
	"type": "hotel",
	"owner": "",
	"owner_name": "Block clan (Ma Block, Fixer 2)",
	"security_code": {
		"n": 7,
		"faction": "staff",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": 3,
	"npcs": [
		"Ma Block (Fixer 2)",
		"Tony Block (Solo 2)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Locked rooms, vendit hall, front counter; a rooftop lookout most nights.",
	"cite": "NC2045 p.300"
}
```

### #18 Union Railroad Station

Major cargo transfer point run by a Snake Nation pack on computers too antiquated to netrun; Marshals check it for smuggling and train robbers.

```world locations.locations.outskirts_18
{
	"name": "Union Railroad Station",
	"district": "outskirts",
	"number": 18,
	"type": "rail",
	"owner": "groundhog_gulpers",
	"owner_name": "Groundhog Gulpers (Snake Nation nomad pack)",
	"security_code": {
		"n": 7,
		"faction": "norcal_marshal_service",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage",
		"gang_hit"
	],
	"interior": "Rail yard and station; no netrunnable systems; DeadWoods supply depot and bunkhouse.",
	"cite": "NC2045 p.300"
}
```

## Fixers

- Paweł Ward (Fixer 4) — Pol-Bud Cement Factory (#12) by day: bookie taking bets on anything, sports to Body Lotto to the weather.
- Ma Block (Fixer 2) — Sunshine Motel (#17) front counter with her son Tony.

## Personalities

- Flo Castleberry — owner of Flo's Diner in Laguna Bend, who makes SCOP taste like food.
- Hilda Forrest (Solo 6) — newly posted Ranger at the Marshal Station, daughter of the legendary Susan Forrest.
- Paweł Ward (Fixer 4) — Pol-Bud machine operator and night-time bookie.
