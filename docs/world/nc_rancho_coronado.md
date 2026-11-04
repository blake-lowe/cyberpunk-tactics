# Rancho Coronado

The district Night City forgot (NC2045 p.286-293): a corporate beaverville gutted in the 4th Corporate War, when
strike teams treated corp families as targets, and since filled with survivors and refugees. Its one City Manager,
DDI splinter-cult leader Sister Shelly, was blown up with her compound in 2037 and nobody has bought the seat since,
so there is no budget and no services. NCPD "patrols" are armoured cars driving through; the cops only respond on the
New Pacific Highway and the Playland Overpass, and MAX-TAC is contracted to hit anyone tampering with the power lines
to Pacifica.

```world city.districts.rancho_coronado
{
	"name": "Rancho Coronado",
	"region": "southside",
	"manager": null,
	"population": "War survivors of every background mixed with refugees, stuck and fending for themselves",
	"security_code": {
		"n": 2,
		"faction": "ncpd",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": 9,
	"provider": "ncpd",
	"gangs": [
		"6th_street",
		"albino_alligators",
		"dirty_hippies",
		"steel_vaqueros",
		"voodoo_boys",
		"weng_fang_tong"
	],
	"ncart": [],
	"profile": "combat_zone",
	"look": [
		"ruined suburb",
		"tent cities",
		"dead malls",
		"sweatshops",
		"gated subdivisions",
		"dust"
	],
	"history": "Wrecked in the 4th Corporate War; leaderless since its cult-leader City Manager died in a 2037 bombing, now a static churn of gang scraps and drive-by raids.",
	"cite": "NC2045 p.286-293"
}
```

## Locations

### #1 106.9 Sangre y arena

Mostly Spanish-language local station broadcasting survival news (cheap produce, gunfights to detour) from a concrete bunker that has outlasted gang, scavver and mob sieges.

```world locations.locations.rancho_coronado_1
{
	"name": "106.9 Sangre y arena",
	"district": "rancho_coronado",
	"number": 1,
	"type": "media",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 2,
		"faction": "ncpd",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Leo Paez (Media 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Concrete bunker; short-range transmitter covering the district.",
	"cite": "NC2045 p.287-289"
}
```

### #2 Albino Alligator Car Wash

The Albino Alligators' HQ sits on working water pipes they tapped, making a joke party gang one of the district's powers; they don't gouge for water.

```world locations.locations.rancho_coronado_2
{
	"name": "Albino Alligator Car Wash",
	"district": "rancho_coronado",
	"number": 2,
	"type": "gang_base",
	"owner": "albino_alligators",
	"owner_name": "Albino Alligators (Big Bruno, Solo 3)",
	"security_code": {
		"n": 10,
		"faction": "albino_alligators",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": 2,
	"npcs": [
		"Big Bruno (Solo 3)"
	],
	"hooks": [
		{
			"text": "The city can't cut their water without also cutting off Tanson Group HQ in Pacifica.",
			"gigs": [
				"sabotage",
				"gang_hit"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"sabotage"
	],
	"interior": "Old car wash over tapped water mains (utility code 2 applies to water only); wet t-shirt parties under the wash spray with a foosball tournament.",
	"cite": "NC2045 p.289"
}
```

### #3 Bread and Roses

Former mini-golf course turned the Dirty Hippies' drug farm; they hire desperate locals and fire warning shots to drive off surplus job-seekers.

```world locations.locations.rancho_coronado_3
{
	"name": "Bread and Roses",
	"district": "rancho_coronado",
	"number": 3,
	"type": "gang_base",
	"owner": "dirty_hippies",
	"owner_name": "Dirty Hippies (Canary, Exec 3)",
	"security_code": {
		"n": 10,
		"faction": "dirty_hippies",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Canary (Exec 3)"
	],
	"hooks": [],
	"gigs": [
		"gang_hit",
		"sabotage"
	],
	"interior": "Holes dug up for weed beds; storage sheds converted to smokehouses; chemicals cooked in an old SCOPdog cart.",
	"cite": "NC2045 p.289"
}
```

### #4 Coronado Heights

The district's fanciest address, a studio block by the Pacifica border with mostly-working power and water; Playland staff live beside Voodoo Boys and Steel Vaqueros.

```world locations.locations.rancho_coronado_4
{
	"name": "Coronado Heights",
	"district": "rancho_coronado",
	"number": 4,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 6,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.289"
}
```

### #5 The Culms

A thicket of ever-growing mutant bamboo in an old garden centre, harvested round the clock by Weng Fang Tong press gangs and sold as scaffolding.

```world locations.locations.rancho_coronado_5
{
	"name": "The Culms",
	"district": "rancho_coronado",
	"number": 5,
	"type": "farm",
	"owner": "weng_fang_tong",
	"owner_name": "Weng Fang Tong",
	"security_code": {
		"n": 10,
		"faction": "weng_fang_tong",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Anyone who goes inside is press-ganged; slow workers are staked over cut stalks and left for the bamboo to grow through.",
			"gigs": [
				"rescue",
				"gang_hit"
			]
		},
		{
			"text": "Workers whisper of a long-legged 'hantu galah' that kills by snapping its legs together — likely a cyberpsycho with extending legs.",
			"gigs": [
				"assassination"
			]
		}
	],
	"gigs": [
		"rescue",
		"gang_hit"
	],
	"interior": "Overgrown garden-centre lot full of hissing, creaking bamboo; harvest crews work 24/7.",
	"cite": "NC2045 p.289-290"
}
```

### #6 Digital Divinity Ruins

The crater left when Sister Shelly's DDI splinter compound was blown up, less than a decade ago.

```world locations.locations.rancho_coronado_6
{
	"name": "Digital Divinity Ruins",
	"district": "rancho_coronado",
	"number": 6,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 2,
		"faction": "ncpd",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Locals say the hole is cursed: whoever crawls in never comes out.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"rescue"
	],
	"interior": "Demolished compound; a hole in the ground leading underneath.",
	"cite": "NC2045 p.290"
}
```

### #7 Eagle Rock Stadium

Cargo-container homes where the Steel Vaqueros keep extended family; relatively safe, near Precinct #2 and MetalStorm, and a good place to lie low.

```world locations.locations.rancho_coronado_7
{
	"name": "Eagle Rock Stadium",
	"district": "rancho_coronado",
	"number": 7,
	"type": "housing",
	"owner": "steel_vaqueros",
	"owner_name": "Steel Vaqueros",
	"security_code": {
		"n": 6,
		"faction": "steel_vaqueros",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Granny Bliss (Fixer 5)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Container community at an old stadium; Destiny Street nearby changes gang hands weekly.",
	"cite": "NC2045 p.290"
}
```

### #8 The Henhouse

An old sporting-goods store, stripped and then a tent town, rebuilt by Big Bruno as a roller-derby stadium for his partner's team, the Rancho Coronado Roosters.

```world locations.locations.rancho_coronado_8
{
	"name": "The Henhouse",
	"district": "rancho_coronado",
	"number": 8,
	"type": "stadium",
	"owner": "albino_alligators",
	"owner_name": "Big Bruno (Solo 3); team managed by Vernie Shirley (Solo 2)",
	"security_code": {
		"n": 6,
		"faction": "albino_alligators",
		"intensity": "light",
		"hardened": false
	},
	"utility_code": 6,
	"npcs": [
		"Big Bruno (Solo 3)",
		"Vernie Shirley (Solo 2)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Big leaky-roofed store floor converted into a derby track.",
	"cite": "NC2045 p.290"
}
```

### #9 The Island

The Voodoo Boys' Rancho Coronado HQ, a fortified former multiplex ringed by a 'sea' of blue tarp tents.

```world locations.locations.rancho_coronado_9
{
	"name": "The Island",
	"district": "rancho_coronado",
	"number": 9,
	"type": "gang_base",
	"owner": "voodoo_boys",
	"owner_name": "Voodoo Boys (Tonton Macoute, Exec 4)",
	"security_code": {
		"n": 10,
		"faction": "voodoo_boys",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": 6,
	"npcs": [
		"Tonton Macoute (Exec 4)"
	],
	"hooks": [
		{
			"text": "The gang doles out food and water to the tent dwellers to keep them in debt slavery: a source of labour, mules, recruits and XBD 'stars'.",
			"gigs": [
				"rescue",
				"gang_hit"
			]
		},
		{
			"text": "Tonton Macoute grooms streetrats with drugs and ships them to Pacifica for XBDs and tourist rentals.",
			"gigs": [
				"rescue",
				"assassination"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	],
	"interior": "Fortified multiplex holding drug storehouses and the armoury; only ranked members live inside; prospects sleep in the tent ring.",
	"cite": "NC2045 p.290"
}
```

### #10 Jack 'N' the Green

Night City's biggest guerrilla garden, built in a fenced former Petrochem subdivision after Cheech's people drove out a squatter gang; it supplies top restaurants.

```world locations.locations.rancho_coronado_10
{
	"name": "Jack 'N' the Green",
	"district": "rancho_coronado",
	"number": 10,
	"type": "farm",
	"owner": "",
	"owner_name": "Cheech (Exec 3)",
	"security_code": {
		"n": 10,
		"faction": "locals",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": 5,
	"npcs": [
		"Cheech (Exec 3)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Fenced subdivision of rotting houses and yards turned into gardens; thieves go into the composter.",
	"cite": "NC2045 p.290-291"
}
```

### The Maquiladoras

Generator-powered sweatshops scattered across the district (not on the map; security 'Various'), paying about half an eb an hour and drugging workers to keep output up.

```world locations.locations.rancho_coronado_maquiladoras
{
	"name": "The Maquiladoras",
	"district": "rancho_coronado",
	"number": null,
	"type": "factory",
	"owner": "",
	"owner_name": "Various: clothing labels, 6th Street, El Norte Cartel, Weng Fang Tong",
	"security_code": null,
	"utility_code": 5,
	"npcs": [],
	"hooks": [
		{
			"text": "6th Street runs one turning out ammunition and armour.",
			"gigs": [
				"sabotage"
			]
		},
		{
			"text": "El Norte Cartel workers assemble guns from parts smuggled up from SoCal.",
			"gigs": [
				"sabotage",
				"gang_hit"
			]
		},
		{
			"text": "The Weng Fang Tong just stole a knock-off goods shop from the Eastern Tigers Triad, who will likely take it back.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"sabotage",
		"gang_hit",
		"rescue"
	],
	"interior": "Workshop floors; overseers rent dorm beds, everyone else sleeps on cardboard in storerooms.",
	"cite": "NC2045 p.291"
}
```

### #11 Minimallism

A dead pre-war mall now infested with fixers running Night Markets, cheap enough to draw buyers from outside; a fixer consortium hired 6th Street to guard it.

```world locations.locations.rancho_coronado_11
{
	"name": "Minimallism",
	"district": "rancho_coronado",
	"number": 11,
	"type": "market",
	"owner": "",
	"owner_name": "Fixer consortium; guarded by 6th Street's Pickens Squad (One-K, Lawman 4)",
	"security_code": {
		"n": 8,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [
		"One-K (Lawman 4)",
		"Ms. Mynah (Fixer 6)",
		"Sara Snow (Medtech 3/Tech 2)",
		"Ximena Rose (Fixer 4/Nomad 1)"
	],
	"hooks": [
		{
			"text": "6th Street's founder X sent One-K to map the district's power structure ahead of a bid for the City Manager seat.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "Sara Snow's discount patients agree to test her experimental panacea serums.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"data_theft",
		"gang_hit"
	],
	"interior": "6th Street Station in an old electronics store; half a dozen fixers' RC Night Markets weekly; Ms. Mynah's office off the central plaza; The Samaritan clinic in a former sculpt shop; XOOX bodega in the old food court (Steel Vaqueros kin).",
	"cite": "NC2045 p.291"
}
```

## Fixers

- Granny Bliss (Fixer 5) — Eagle Rock Stadium (#7): organises gigs for the edgerunners who hang out there.
- Ms. Mynah (Fixer 6) — Minimallism (#11), office off the central plaza: apparel Night Market on the 5th of each month.
- Ximena Rose (Fixer 4/Nomad 1) — XOOX in Minimallism (#11): coordinates the Steel Vaqueros' business in the district.

## Personalities

- Big Bruno (Solo 3) — Albino Alligators founder; calm, laconic, and will stand on your head with a linear frame.
- Canary (Exec 3) — Dirty Hippies founder who plays the ditz but is a shark.
- Granny Bliss (Fixer 5) — 'old lady' fixer at Eagle Rock, probably a bodysculpted disguise.
- Leo Paez (Media 4) — daytime DJ at 106.9 with a wide Agent network of informants.
- One-K (Lawman 4) — Pickens Squad leader for 6th Street, souring on X's plan to take the district.
- Tonton Macoute (Exec 4) — Voodoo Boys' boss here, a sleaze who traffics groomed streetrats to Pacifica.
- Ximena Rose (Fixer 4/Nomad 1) — carsick Steel Vaquero who runs the pack's local business from XOOX.
