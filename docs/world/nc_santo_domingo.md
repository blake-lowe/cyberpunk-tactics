# Santo Domingo

Night City's south-eastern edge on the Mainland (NC2045 p.264-273). Once a suburb, then a refugee camp, then the
Aldecaldo nomads' stronghold, it broke away from North Heywood and was nomad-run for three terms, until El
Norte-funded Theresa Valentino won the last election promising a district for everyone, not only nomads. Locals are
practical day-labourers who take work from corps, nomads and criminals alike; the Aldecaldo Peacekeepers still police
the streets on contract while an overstretched NCPD Precinct #2 watches from the air with drones.

```world city.districts.santo_domingo
{
	"name": "Santo Domingo",
	"region": "mainland",
	"manager": {
		"name": "Theresa Valentino",
		"role": "Rockerboy 7"
	},
	"population": "Mostly Latino/Hispanic working families making do on day work, plus nomads cycling through the Aldecaldo Camp",
	"security_code": {
		"n": 7,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 6,
	"provider": "aldecaldo_peacekeepers",
	"gangs": [
		"el_norte_cartel",
		"rat_kings"
	],
	"ncart": [
		"Green Line station (unnamed on the map)"
	],
	"profile": "mixed_residential",
	"look": [
		"nomad camp",
		"patchwork shanty roofs",
		"cargo containers",
		"highway overpass",
		"food trucks",
		"dust"
	],
	"history": "Split from Heywood, ran under Aldecaldo-backed managers for three terms, then fell to El Norte's candidate Theresa Valentino last year.",
	"cite": "NC2045 p.264-273"
}
```

## Locations

### #1 88.9 Nomad Presents Radio (NoPR)

News-and-talk station run by the Breaker 1-9s, a continent-wide nomad radio pack; it takes no advertising and lives on pledge drives.

```world locations.locations.santo_domingo_1
{
	"name": "88.9 Nomad Presents Radio (NoPR)",
	"district": "santo_domingo",
	"number": 1,
	"type": "media",
	"owner": "breaker_1_9s",
	"owner_name": "Breaker 1-9s (nomad pack); GM Bly Harjo (Media 4/Nomad 2)",
	"security_code": {
		"n": 7,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [
		"Bly Harjo (Media 4/Nomad 2)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.265"
}
```

### #2 Aldecaldo Camp

A whole town of semi-permanent nomad structures at the foot of Coronado Dam: the Aldecaldos' de facto capital and the hub of their trade, transport and labour network.

```world locations.locations.santo_domingo_2
{
	"name": "Aldecaldo Camp",
	"district": "santo_domingo",
	"number": 2,
	"type": "outskirts_site",
	"owner": "aldecaldos",
	"owner_name": "Aldecaldos; camp run by Izzy Lobo (Nomad 10)",
	"security_code": {
		"n": 9,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Izzy Lobo (Nomad 10)",
		"Skinny James (Fixer 4/Nomad 2)",
		"Doc Spindler (Medtech 4)",
		"Golem (Solo 3)"
	],
	"hooks": [],
	"gigs": [
		"rescue",
		"sabotage"
	],
	"interior": "Shifting camp; sub-sites: AllNations Construction (three containers on a MegaHauler, issues temp IDs and plates), Bazaar El Saber day market (Doc Spindler's ripper stall), Caitlin Market (groceries and guns, Peacekeeper Golem patrols), Doc P's school (K-12), Radio Tent comms hub, Skinny James' Lot (hire nomad crews), Sol Canela Park, Tepui overnight kombi lot.",
	"cite": "NC2045 p.267-268"
}
```

### #3 Aldecaldo Peacekeepers HQ

The deputized nomad police's reclaimed base, jammed up against Ciudad Techito and visible from most of the district.

```world locations.locations.santo_domingo_3
{
	"name": "Aldecaldo Peacekeepers HQ",
	"district": "santo_domingo",
	"number": 3,
	"type": "police",
	"owner": "aldecaldo_peacekeepers",
	"owner_name": "Aldecaldo Peacekeepers",
	"security_code": {
		"n": 9,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"rescue",
		"sabotage"
	],
	"interior": "Reclaimed complex: many vehicle garages, dormitories, a small holding jail.",
	"cite": "NC2045 p.268"
}
```

### #4 Aldecaldo Warriors Track

Home of the Aldecaldo Warriors, the Wonderland roller-derby league's only outdoor track; students from Doc P's use it when the team is away.

```world locations.locations.santo_domingo_4
{
	"name": "Aldecaldo Warriors Track",
	"district": "santo_domingo",
	"number": 4,
	"type": "stadium",
	"owner": "aldecaldos",
	"owner_name": "Aldecaldo Warriors (roller derby team)",
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
	"interior": "",
	"cite": "NC2045 p.268"
}
```

### #5 Altar a Nuestra Señora de la Santa Muerte

A Holy Death shrine hidden inside an abandoned Militech warehouse, kept by a priest-like counsellor who was never ordained.

```world locations.locations.santo_domingo_5
{
	"name": "Altar a Nuestra Señora de la Santa Muerte",
	"district": "santo_domingo",
	"number": 5,
	"type": "church",
	"owner": "",
	"owner_name": "Sebastian Ibarra (Rockerboy 4), keeper",
	"security_code": {
		"n": 7,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Sebastian Ibarra (Rockerboy 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Abandoned Militech warehouse housing the altar; steady foot traffic in and out.",
	"cite": "NC2045 p.268"
}
```

### #6 Ciudad Techito

'Lil' Roof Town': improvised housing patched together from scavenged suburb, a mosaic of zinc and door rooftops whose layout and borders keep changing.

```world locations.locations.santo_domingo_6
{
	"name": "Ciudad Techito",
	"district": "santo_domingo",
	"number": 6,
	"type": "squat",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 7,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Abuela"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Unmappable shifting sprawl; local kids guide visitors for 5-10eb.",
	"cite": "NC2045 p.268"
}
```

### #7 Coronado Dam

Holds back Laguna Reservoir and supplies the city's drinking water; Petrochem runs it on contract, though the reservoir drops every year.

```world locations.locations.santo_domingo_7
{
	"name": "Coronado Dam",
	"district": "santo_domingo",
	"number": 7,
	"type": "utility",
	"owner": "petrochem",
	"owner_name": "Petrochem (city contract)",
	"security_code": {
		"n": 9,
		"faction": "petrochem",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": 2,
	"npcs": [],
	"hooks": [
		{
			"text": "Kill Krasher crews sometimes try to RPG the dam to flood Santo Domingo; the nomads fight them off.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage",
		"data_theft"
	],
	"interior": "Dam with Petrochem Security teams on site; the Aldecaldo Camp sits at its base.",
	"cite": "NC2045 p.268-269"
}
```

### #8 East Cargo Village

Cargo-container housing where nomads bunk for a month or two, alongside non-nomads who work in the Camp.

```world locations.locations.santo_domingo_8
{
	"name": "East Cargo Village",
	"district": "santo_domingo",
	"number": 8,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 7,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.269"
}
```

### #9 Heywood Suites

Cube hotel and apartments crammed under the New Pacific Highway, so loud that residents chip noise dampers; people stay because the neighbours are cops, Zhirafa guards and cartel members.

```world locations.locations.santo_domingo_9
{
	"name": "Heywood Suites",
	"district": "santo_domingo",
	"number": 9,
	"type": "cube_hotel",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 10,
		"faction": "locals", "responder": "residents",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Carter"
	],
	"hooks": [],
	"gigs": [
		"gang_hit"
	],
	"interior": "Noise and vibration dampers, soundproofed units, furniture bolted down; road trains rumble overhead.",
	"cite": "NC2045 p.269"
}
```

### #10 Hunger Street

Food-truck street outside Megabuilding H4: cheap Kibble and SCOP dishes with garden-grown extras.

```world locations.locations.santo_domingo_10
{
	"name": "Hunger Street",
	"district": "santo_domingo",
	"number": 10,
	"type": "market",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 7,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Trucks include Buck-a-Slice, Cart Chrome (brain solution for FBC builders), Monster T, SharkBites, TacoSCOP.",
	"cite": "NC2045 p.269"
}
```

### #11 Live Wire Barb House

A beloved live-music club named by a misprinted sign; any decent band can play.

```world locations.locations.santo_domingo_11
{
	"name": "Live Wire Barb House",
	"district": "santo_domingo",
	"number": 11,
	"type": "club",
	"owner": "",
	"owner_name": "Purple Poison",
	"security_code": {
		"n": 7,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Purple Poison"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.269"
}
```

### #12 María's

A family beer tent at the very edge of town; real beer and tequila via Aldecaldo ties make it the caravans' last stop before the road.

```world locations.locations.santo_domingo_12
{
	"name": "María's",
	"district": "santo_domingo",
	"number": 12,
	"type": "bar",
	"owner": "",
	"owner_name": "Cruz family (heirs of María Cruz)",
	"security_code": {
		"n": 8,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Lupita \"Loba\" Garza (Medtech 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Open-air tent with lawn furniture chained down.",
	"cite": "NC2045 p.269-270"
}
```

### #13 Megabuilding H4

A megabuilding about a third built, pushed by the Arroyo Concern; its lower floors already house workers and a handful of shops, and Valentino is holding up permits to win housing for Ciudad Techito.

```world locations.locations.santo_domingo_13
{
	"name": "Megabuilding H4",
	"district": "santo_domingo",
	"number": 13,
	"type": "megabuilding",
	"owner": "",
	"owner_name": "Arroyo Concern (developer)",
	"security_code": {
		"n": 6,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Two-Toes (Fixer 3/Medtech 3)"
	],
	"hooks": [
		{
			"text": "El Norte is said to run an identity-swap operation behind the H4 Clinic.",
			"gigs": [
				"data_theft",
				"gang_hit"
			]
		},
		{
			"text": "Netwatch is probing Heywood Community Bank as a front for a cartel phone/CitiNet scam.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "The Bar of Gold BD den is a Rat Kings hangout.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"data_theft",
		"gang_hit"
	],
	"interior": "Lower levels occupied; tenants: Bar of Gold (BD den/club), Pink Mohawk (fashionware salon), Gatcha Hotel (100 capsules, 50eb/night), H4 Clinic (ripperdoc), Heywood Community Bank, YoBro! (gun shop and range).",
	"cite": "NC2045 p.270"
}
```

### #14 MetalStorm

Under the Pacifica Bridge, the FBC community's all-metal bar where full borgs drop the restraint; unwelcoming to flesh tourists.

```world locations.locations.santo_domingo_14
{
	"name": "MetalStorm",
	"district": "santo_domingo",
	"number": 14,
	"type": "bar",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 8,
		"faction": "locals", "responder": "patrons",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Everything solid metal; drinks in glasses or nutrient bags for access ports.",
	"cite": "NC2045 p.270"
}
```

### #15 NCPD Precinct #2

The Mainland's main NCPD station, a low fortress that rarely patrols in person and watches the district with drones instead.

```world locations.locations.santo_domingo_15
{
	"name": "NCPD Precinct #2",
	"district": "santo_domingo",
	"number": 15,
	"type": "police",
	"owner": "ncpd",
	"owner_name": "NCPD",
	"security_code": {
		"n": 10,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"rescue",
		"data_theft",
		"sabotage"
	],
	"interior": "Three storeys, thick walls, electrified fence, turrets; stairs plus one cargo lift; squad rooms, cells and armouries mixed on floors 1-2; floor 3 is drone ops with repair bays, a Zhirafa tech and netrunners flying about a dozen Savannah Eagles.",
	"cite": "NC2045 p.270-271"
}
```

### #16 Northern Light Supplies

A vendit-restocking firm with three trucks that appeared only after Valentino's win; its machines are everywhere now.

```world locations.locations.santo_domingo_16
{
	"name": "Northern Light Supplies",
	"district": "santo_domingo",
	"number": 16,
	"type": "warehouse",
	"owner": "el_norte_cartel",
	"owner_name": "Northern Light Supplies (El Norte front)",
	"security_code": {
		"n": 6,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Its vendits probably sell black-market goods to anyone with the right codes: a cartel distribution network.",
			"gigs": [
				"data_theft",
				"sabotage",
				"gang_hit"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage",
		"gang_hit"
	],
	"interior": "Plain logistics building with a three-truck fleet.",
	"cite": "NC2045 p.271"
}
```

### #17 Salón de Valentino

The district's seat of government in a converted automated factory, officially Salón de Santo Domingo; Valentino's people renamed it.

```world locations.locations.santo_domingo_17
{
	"name": "Salón de Valentino",
	"district": "santo_domingo",
	"number": 17,
	"type": "civic",
	"owner": "city_government",
	"owner_name": "Theresa Valentino (Rockerboy 7), City Manager",
	"security_code": {
		"n": 6,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Theresa Valentino (Rockerboy 7)",
		"La Llorona (Solo 7)",
		"El Sombrerón (Solo 7)",
		"Genesis Durcal (Nomad 6)",
		"Rubén Meza (Exec 5)"
	],
	"hooks": [
		{
			"text": "Rumour puts an El Norte operation in the basement bomb shelter; cartel boss Rubén Meza visits often.",
			"gigs": [
				"data_theft",
				"assassination"
			]
		},
		{
			"text": "Valentino's cartel-assigned bodyguard siblings may have switched their loyalty to her.",
			"gigs": [
				"assassination"
			]
		},
		{
			"text": "Nomads suspect losing candidate Genesis Durcal has been won over by Valentino.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"assassination",
		"data_theft",
		"corp_extraction"
	],
	"interior": "Floor 1 public offices; floor 2 the City Manager's apartment and staff offices; rumoured cartel bunker in the basement.",
	"cite": "NC2045 p.271"
}
```

### #18 SovOil Paint Factory

A round-the-clock latex paint plant from the early rebuild, claiming half the paint on the city's walls and pouring out pollution that local huffers breathe for a high.

```world locations.locations.santo_domingo_18
{
	"name": "SovOil Paint Factory",
	"district": "santo_domingo",
	"number": 18,
	"type": "factory",
	"owner": "sovoil",
	"owner_name": "SovOil",
	"security_code": {
		"n": 7,
		"faction": "sovoil",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": 4,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage",
		"data_theft"
	],
	"interior": "",
	"cite": "NC2045 p.271"
}
```

### #19 Woodchipper's Garage

Looks like a repair garage but is the home and office of Woodchipper, the fixer every nomad nation (and corps and city officials) trusts to mediate disputes.

```world locations.locations.santo_domingo_19
{
	"name": "Woodchipper's Garage",
	"district": "santo_domingo",
	"number": 19,
	"type": "chop_shop",
	"owner": "",
	"owner_name": "Woodchipper (Fixer 5/Nomad 4)",
	"security_code": {
		"n": 9,
		"faction": "aldecaldo_peacekeepers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Woodchipper (Fixer 5/Nomad 4)"
	],
	"hooks": [
		{
			"text": "Woodchipper and Theresa Valentino reportedly have bad blood from an old run-in.",
			"gigs": [
				"assassination"
			]
		}
	],
	"gigs": [],
	"interior": "Wide squat building with vehicle bays, lifts, benches and crates, none used for cars; her Night Market runs in a nearby cul-de-sac.",
	"cite": "NC2045 p.271"
}
```

## Fixers

- Skinny James (Fixer 4/Nomad 2) — Skinny James' Lot, Aldecaldo Camp: matches clients with nomad crews for transport, cargo and labour, fee from both sides.
- Woodchipper (Fixer 5/Nomad 4) — Woodchipper's Garage (#19): mediation between nomads, corps and government; runs a regular Night Market.
- Two-Toes (Fixer 3/Medtech 3) — H4 Clinic, Megabuilding H4 (#13): ripperdoc who asks no questions and answers none about other clients.

## Personalities

- Abuela — Ciudad Techito's honorary grandmother; teaches kids dominoes by day, hustles adults at night.
- Carter — deaf Heywood Suites resident who refuses cyberware and teaches sign language for extra eb.
- Colorama (Rockerboy 2) — salsa band of retirees who come alive on stage at district events.
- Genesis Durcal (Nomad 6) — lost the election; lobbies for nomads at the Salón, suspiciously close to Valentino.
- Izzy Lobo (Nomad 10) — reluctant boss of the Aldecaldo Camp, appointed by Santiago to protect the nomads in the city.
- Jorgito Arañas (Tech 4) — breeder of cat-sized tarantulas he pitches, unsuccessfully, as food animals.
- Killjoy (??) — unknown tagger (person or group) behind obscene and inspiring graffiti alike.
- Sibling assassins La Llorona and El Sombrerón (both Solo 7), 'El Norte's Butchers': Valentino's guards, their loyalty in doubt.
- Lupita "Loba" Garza (Medtech 4) — edgerunner medic who helps run María's between patch-up jobs.
- Mario "Corona" Fernandez (Solo 2) — Rat Kings founder, a lazy man who can't help organising.
- Rubén Meza (Exec 5) — nervous numbers man running El Norte's Night City expansion.
- Skinny James (Fixer 4/Nomad 2) — old road partner of Santiago; the statics' first contact for nomad business.
- Two-Toes (Fixer 3/Medtech 3) — tight-lipped ripperdoc at the H4 Clinic.
- Theresa Valentino (Rockerboy 7) — charismatic, ruthless City Manager backed by El Norte money; cartel members are now called 'Valentino's Fists' (p.265).
