# Heywood Industrial Zone

The Heywood Industrial Zone is where Night City's corporations do their unglamorous work: factories, warehouses and
depots under the worst smog in the city. The district was founded by the Arroyo Concern, a corporate partnership that
also picks its City Manager. The current one, Theodore Walker (no Role printed), is a harmless compromise candidate who
has gone bald from the stress. NCPD patrols heavily, hoping a foiled crime will earn a corporate job, and most sites also
have their own corporate guards (NC2045 p.256-257).

```world city.districts.heywood_industrial_zone
{
	"name": "Heywood Industrial Zone",
	"region": "mainland",
	"manager": {
		"name": "Theodore Walker",
		"role": ""
	},
	"population": "few residents: most workers commute; Zhirafa housing, a few container communities, contract Techs and teenage bike couriers",
	"security_code": {
		"n": 8,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": 3,
	"provider": "ncpd",
	"gangs": [
		"consortium",
		"deadwoods",
		"enhanced",
		"fixies_couriers"
	],
	"ncart": [
		"Industrial Zone Station (Red and Green Lines)"
	],
	"profile": "industrial",
	"look": [
		"yellow smog",
		"factories",
		"warehouses",
		"rail depot",
		"canal-side sheds"
	],
	"history": "Created after the 4th Corporate War by the Arroyo Concern (Militech, Petrochem, Raven, SovOil, Trauma Team) as a regional manufacturing hub; this year a start-up's hostile takeover of the couriers' ship briefly paralysed city deliveries.",
	"cite": "NC2045 p.256-263"
}
```

## Locations

### #1 Aldecaldo Depot

The Aldecaldos' in-city depot for doing transport deals with corporate clients.

```world locations.locations.heywood_industrial_zone_1
{
	"name": "Aldecaldo Depot",
	"district": "heywood_industrial_zone",
	"number": 1,
	"type": "warehouse",
	"owner": "aldecaldo_peacekeepers",
	"owner_name": "the Aldecaldos",
	"security_code": {
		"n": 6,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Plain warehouse outside; inside, a miniature Aldecaldo Camp of tents and vehicles on bare concrete, with a rep who 'speaks corporate' always on hand.",
	"cite": "NC2045 p.259"
}
```

### #2 Agron's Boxed Lunches

A no-frills lunch counter for factory workers, run by a loan shark.

```world locations.locations.heywood_industrial_zone_2
{
	"name": "Agron's Boxed Lunches",
	"district": "heywood_industrial_zone",
	"number": 2,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Boris Agron (Fixer 3)",
	"security_code": {
		"n": 7,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Boris Agron (Fixer 3)"
	],
	"hooks": [
		{
			"text": "Owner Boris Agron is also a loan shark, and borrowers who miss payments get a visit from his Consortium friends.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"gang_hit"
	],
	"interior": "Concrete bunker at the water's edge; no seating, no choice, 10eb a box.",
	"cite": "NC2045 p.259"
}
```

### #3 Arroyo Concern Offices

Seat of the corporate consortium that runs the district.

```world locations.locations.heywood_industrial_zone_3
{
	"name": "Arroyo Concern Offices",
	"district": "heywood_industrial_zone",
	"number": 3,
	"type": "corp_office",
	"owner": "arroyo_concern",
	"owner_name": "Arroyo Concern (City Manager Theodore Walker)",
	"security_code": {
		"n": 8,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Theodore Walker",
		"Boots McCoy (Solo 4)"
	],
	"hooks": [
		{
			"text": "Walker is negotiating to bring Revere Courier Services into the district, preferring a defended corp to Fixie's teenage couriers.",
			"gigs": [
				"sabotage",
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"interior": "Bland five-storey office block on Arroyo Street; the City Manager's small staff plus an office for each member corp (Continental Brands, GunMart, Militech, Petrochem, Raven, Rocklin, SovOil, Trauma Team, Zhirafa, Ziggurat, Yang's Wheels), mostly unattended.",
	"cite": "NC2045 p.259"
}
```

### #4 Continental Brands Manufacturing

Where the city's Kibble and SCOP are made, in open-topped vats.

```world locations.locations.heywood_industrial_zone_4
{
	"name": "Continental Brands Manufacturing",
	"district": "heywood_industrial_zone",
	"number": 4,
	"type": "factory",
	"owner": "continental_brands",
	"owner_name": "Continental Brands",
	"security_code": {
		"n": 8,
		"faction": "continental_brands",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage"
	],
	"interior": "Multi-building complex, one building per product line; open chutes feed open mixing vats, then moulds, ovens and packaging; white-coated QA staff on day shift.",
	"cite": "NC2045 p.259"
}
```

### #5 D.V. Rambling Rose

A beached cargo ship turned mixed-use block and hub of Fixie's Couriers.

```world locations.locations.heywood_industrial_zone_5
{
	"name": "D.V. Rambling Rose",
	"district": "heywood_industrial_zone",
	"number": 5,
	"type": "ship",
	"owner": "fixies_couriers",
	"owner_name": "Fixie (Fixer 6)",
	"security_code": {
		"n": 9,
		"faction": "fixies_couriers",
		"intensity": "light",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Fixie (Fixer 6)",
		"Boots McCoy (Solo 4)"
	],
	"hooks": [
		{
			"text": "Start-up Lightning Logistics tried a hostile takeover of the Rose earlier this year, which halted deliveries across the city until the Couriers won.",
			"gigs": [
				"sabotage",
				"gang_hit"
			]
		},
		{
			"text": "The City Manager would rather replace the Couriers with Revere Courier Services.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage",
		"gang_hit"
	],
	"interior": "Rusted ship stuck in dry dock since the nuke: containers on deck serve as apartments; the old command centre is the Couriers' logistics hub; the holds are warehouses; Fixie's team uses the crew quarters; the Industrial Zone Skidz derby squad lives aboard.",
	"cite": "NC2045 p.259"
}
```

### #6 GunMart Manufacturing

GunMart's assembly-line gun factory, staffed largely by members of the Enhanced.

```world locations.locations.heywood_industrial_zone_6
{
	"name": "GunMart Manufacturing",
	"district": "heywood_industrial_zone",
	"number": 6,
	"type": "factory",
	"owner": "gunmart",
	"owner_name": "GunMart",
	"security_code": {
		"n": 10,
		"faction": "gunmart",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Judging by their engraved cyberware, about half the line workers belong to the Enhanced, and turnover is high, often through MAX-TAC.",
			"gigs": [
				"gang_hit"
			]
		},
		{
			"text": "When the rooftop air systems fail, workers prop doors and windows open, and the guards ignore it until a supervisor appears.",
			"gigs": [
				"sabotage",
				"data_theft"
			]
		}
	],
	"gigs": [
		"sabotage",
		"gang_hit",
		"data_theft"
	],
	"interior": "Robots machine parts onto conveyor belts and each human worker adds one part down the line; two large rooftop HVAC units that often break down.",
	"cite": "NC2045 p.260"
}
```

### #7 The Interchange

The district's cargo and passenger rail depot, run by an ancient stationmaster and his dog.

```world locations.locations.heywood_industrial_zone_7
{
	"name": "The Interchange",
	"district": "heywood_industrial_zone",
	"number": 7,
	"type": "rail",
	"owner": "",
	"owner_name": "Calvert (Tech 5), stationmaster",
	"security_code": {
		"n": 8,
		"faction": "deadwoods",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Calvert (Tech 5)"
	],
	"hooks": [],
	"gigs": [
		"sabotage"
	],
	"interior": "The zone's rail depot moving cargo from the Port and the Docks to the factories; Snake Nation crews run the trains, NCPD and DeadWoods jointly guard it, and only the ancient stationmaster understands the punch-card rail switches.",
	"cite": "NC2045 p.260"
}
```

### #8 Militech Manufacturing Plant

Militech's flexible production plant, close to impossible to enter uninvited.

```world locations.locations.heywood_industrial_zone_8
{
	"name": "Militech Manufacturing Plant",
	"district": "heywood_industrial_zone",
	"number": 8,
	"type": "factory",
	"owner": "militech",
	"owner_name": "Militech",
	"security_code": {
		"n": 10,
		"faction": "militech",
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
	"interior": "Sprawling flexible-production plant (sidearms one week, armour plating the next) with an R&D department and a live-fire test range; patrols sweep halls and checkpoints to keep everyone in authorised areas.",
	"cite": "NC2045 p.260"
}
```

### #9 The Old Ironworks Building

The zone's largest non-corporate housing: junior execs, contract Techs and senior guards.

```world locations.locations.heywood_industrial_zone_9
{
	"name": "The Old Ironworks Building",
	"district": "heywood_industrial_zone",
	"number": 9,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 7,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Stacked containers on the roof linked by ladders and catwalks; ex-offices split into studios and two-bedroom units; the old factory floor holds the Furnace bar-bodega and street carts.",
	"cite": "NC2045 p.260"
}
```

### #10 Petrochem Plastics Plant

Petrochem's plastics plant, staffed by easily replaced workers.

```world locations.locations.heywood_industrial_zone_10
{
	"name": "Petrochem Plastics Plant",
	"district": "heywood_industrial_zone",
	"number": 10,
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
			"text": "Constant shipments and staff turnover mean the guards rarely know who anyone is, and they don't care unless trouble starts.",
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
	"interior": "East wing turns shipped chemicals into plastic pellets; west wing moulds and extrudes them; one line makes the resin used to patch buildings; little automation.",
	"cite": "NC2045 p.260"
}
```

### #11 Raven Microcybernetics Factory

Raven's sleek, mostly automated cyberware factory, guarded by McCain Security.

```world locations.locations.heywood_industrial_zone_11
{
	"name": "Raven Microcybernetics Factory",
	"district": "heywood_industrial_zone",
	"number": 11,
	"type": "factory",
	"owner": "raven_microcybernetics",
	"owner_name": "Raven Microcybernetics",
	"security_code": {
		"n": 10,
		"faction": "mccain_security",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Raven keeps losing its best Techs to Rocklin, so staff with design-level access now must live on site.",
			"gigs": [
				"corp_extraction",
				"data_theft"
			]
		}
	],
	"gigs": [
		"corp_extraction",
		"data_theft"
	],
	"interior": "Multi-storey factory with one product line per floor, mostly automated and eerily empty; luxurious corporate apartments in the building for design staff.",
	"cite": "NC2045 p.261"
}
```

### #12 Rocklin Augmentics Manufacturing

Rocklin's comfortable but heavily watched plant, where flagged workers vanish.

```world locations.locations.heywood_industrial_zone_12
{
	"name": "Rocklin Augmentics Manufacturing",
	"district": "heywood_industrial_zone",
	"number": 12,
	"type": "factory",
	"owner": "rocklin_augmentics",
	"owner_name": "Rocklin Augmentics",
	"security_code": {
		"n": 11,
		"faction": "rocklin_augmentics",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Crawling drones hunt for saboteurs, spies and disloyal staff, and anyone they flag tends to disappear.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage",
		"corp_extraction"
	],
	"interior": "Realgrass lawns with paths, benches and smog fans inside the outer wall; wide halls lead to locker rooms, breakfast bars and a decon suite before the factory floor; mandatory music headsets; fitness centre; constant surveillance by small crawler drones.",
	"cite": "NC2045 p.261"
}
```

### #13 The Rodeo

A disused warehouse squatted by the Industrial Zone Skidz roller derby squad.

```world locations.locations.heywood_industrial_zone_13
{
	"name": "The Rodeo",
	"district": "heywood_industrial_zone",
	"number": 13,
	"type": "venue",
	"owner": "fixies_couriers",
	"owner_name": "Industrial Zone Skidz (Fixie's Couriers' derby squad)",
	"security_code": {
		"n": 6,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Boots McCoy (Solo 4)"
	],
	"hooks": [
		{
			"text": "The Arroyo Concern tolerates the squat only because the Skidz captain is the City Manager's niece; if she leaves, NCPD will evict them.",
			"gigs": []
		}
	],
	"gigs": [],
	"interior": "Officially disused warehouse squatted as a derby practice track; bouts against other squads every few weeks.",
	"cite": "NC2045 p.261"
}
```

### #14 SovOil Plastics Plant

SovOil's plastics plant, a near twin of Petrochem's.

```world locations.locations.heywood_industrial_zone_14
{
	"name": "SovOil Plastics Plant",
	"district": "heywood_industrial_zone",
	"number": 14,
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
			"text": "Constant shipments and staff turnover mean the guards rarely know who anyone is, and they don't care unless trouble starts.",
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
	"interior": "North wing makes pellets, south wing moulds them; one line turns out cheap housewares for Oasis stores; little automation.",
	"cite": "NC2045 p.261"
}
```

### #15 Trauma Team Pharmaceutical Plant

Trauma Team's drug plant, hidden in an old public works site.

```world locations.locations.heywood_industrial_zone_15
{
	"name": "Trauma Team Pharmaceutical Plant",
	"district": "heywood_industrial_zone",
	"number": 15,
	"type": "lab",
	"owner": "trauma_team",
	"owner_name": "Trauma Team",
	"security_code": {
		"n": 8,
		"faction": "trauma_team",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"interior": "Above ground, only a single-storey cylindrical entrance; below, three levels of former utility storage divided into a dozen clean rooms where a few Medtechs work 14-hour shifts.",
	"cite": "NC2045 p.262"
}
```

### #16 Yang's Wheels

The city's top seller of bicycles and cheap personal transport, with a well-paid, safe workforce.

```world locations.locations.heywood_industrial_zone_16
{
	"name": "Yang's Wheels",
	"district": "heywood_industrial_zone",
	"number": 16,
	"type": "factory",
	"owner": "",
	"owner_name": "Gabriel Yang (Fixer 4/Nomad 2)",
	"security_code": {
		"n": 7,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Gabriel Yang (Fixer 4/Nomad 2)",
		"Edith Lamarr (Tech 5)"
	],
	"hooks": [
		{
			"text": "Yang is reportedly planning a second factory just for an expanded metrocar line.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [],
	"interior": "Retrofitted factory with one crew scavenging and refurbishing parts and another assembling bikes, skates, scooters and metrocars; a skate park out back where gangers are welcome if they don't draw guns.",
	"cite": "NC2045 p.262"
}
```

### #17 Zhirafa Office Park

Zhirafa's Night City offices, growing piece by piece and patrolled by drones.

```world locations.locations.heywood_industrial_zone_17
{
	"name": "Zhirafa Office Park",
	"district": "heywood_industrial_zone",
	"number": 17,
	"type": "corp_office",
	"owner": "zhirafa",
	"owner_name": "Zhirafa",
	"security_code": {
		"n": 10,
		"faction": "zhirafa",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Darya Ishkova (Exec 5/Netrunner 5)"
	],
	"hooks": [
		{
			"text": "Regional director Darya Ishkova is rumoured to have blackmailed her way up, and she is a skilled Netrunner.",
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
	"interior": "Old office park with extra floors stacked on top, factory wings tacked on and outbuildings for vehicles and drones; gutted interiors refitted with cafeterias and rec spaces; guards walk with Savannah Panther drones, Savannah Eagle drones on the roofs act as cameras, and every visitor gets an escort drone that records everything and may use force.",
	"cite": "NC2045 p.262"
}
```

### #18 Zhirafa MicroVillage

Zhirafa's staff conapt complex, built to look like a container pile.

```world locations.locations.heywood_industrial_zone_18
{
	"name": "Zhirafa MicroVillage",
	"district": "heywood_industrial_zone",
	"number": 18,
	"type": "housing",
	"owner": "zhirafa",
	"owner_name": "Zhirafa",
	"security_code": {
		"n": 5,
		"faction": "zhirafa",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Father Tikhon (Tech 3)",
		"Drago (Solo 4)"
	],
	"hooks": [
		{
			"text": "Rough-looking non-employees with Consortium-style tattoos have recently moved into some units.",
			"gigs": [
				"gang_hit"
			]
		},
		{
			"text": "New resident Drago does unexplained 'special projects' for Zhirafa and looks more like a leg-breaker than a Tech.",
			"gigs": [
				"data_theft",
				"assassination"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"data_theft"
	],
	"interior": "Comfortable conapts disguised as stacked containers around a courtyard of upscale cart vendors; the Vodka Container bar on the first floor; Trinity Church, a small Russian Orthodox chapel.",
	"cite": "NC2045 p.262"
}
```

### #19 Ziggurat Warehouses

Shabby sheds that hold the spare parts for keeping the CitiNet running.

```world locations.locations.heywood_industrial_zone_19
{
	"name": "Ziggurat Warehouses",
	"district": "heywood_industrial_zone",
	"number": 19,
	"type": "warehouse",
	"owner": "ziggurat",
	"owner_name": "Ziggurat",
	"security_code": {
		"n": 7,
		"faction": "ziggurat",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Despite recent upgrades, the warehouses that supply the CitiNet backbone are worryingly poorly guarded.",
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
	"interior": "Old sheds of recycled girders and corrugated metal full of cable spools and electronics for CitiNet repairs; electrified chain-link fence; Netrunners steer a small pack of Savannah Panther drones on patrol.",
	"cite": "NC2045 p.263"
}
```

## Fixers

- Fixie (Fixer 6): D.V. Rambling Rose (#5); runs Fixie's Couriers as a dabbawala-style collective; deliveries anywhere in the city (NC2045 p.259, p.263).
- Gabriel Yang (Fixer 4/Nomad 2): Yang's Wheels (#16); bicycles, scooters and metrocars (NC2045 p.262).
- Boris Agron (Fixer 3): Agron's Boxed Lunches (#2); no-questions loans backed by the Consortium (NC2045 p.259).
- Memo (Fixer 1): moves his carts around the district selling dry goods, chips and gossip (NC2045 p.263).

## Personalities

- Miller Marcus (Media 4/Tech 2): tech and supply-chain journalist and the district's guide (NC2045 p.256).
- Boots McCoy (Solo 4): Industrial Zone Skidz captain, the City Manager's niece and an accountant at the Arroyo Concern Offices (NC2045 p.263).
- Darya Ishkova (Exec 5/Netrunner 5): Zhirafa's young Pacifica regional director, who greets guests with private trivia about them (NC2045 p.263).
- Drago (Solo 4): MicroVillage newcomer doing secret 'special projects' for Zhirafa (NC2045 p.263).
- Fixie (Fixer 6): head of the Couriers, who calls herself only first among equals (NC2045 p.263).
- Lieutenant Abishola "Terror" Tye (Lawman 6): top NCPD officer in the district, focused on keeping goods flowing (NC2045 p.263).
- Memo (Fixer 1): itinerant cart vendor and dreadful gossip (NC2045 p.263).
