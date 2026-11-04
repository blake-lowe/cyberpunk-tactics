# North Heywood

North Heywood is a working-class district where wage slaves and veterans try to hold on to a steady life. Shiny
corporate enclaves such as the Dynalar Campus sit beside tired neighbourhoods, cube hotels and empty factories.
City Manager Barry "Big Deal" Delvecchio (Fixer 6) keeps the corps and 6th Street both content. 6th Street started as a
veterans' guardian gang and is now the deputized police, though its patrols tend to come with "donation requests"
(NC2045 p.246-247).

```world city.districts.north_heywood
{
	"name": "North Heywood",
	"region": "mainland",
	"manager": {
		"name": "Barry \"Big Deal\" Delvecchio",
		"role": "Fixer 6"
	},
	"population": "working-class corp drones, junior Techs and dock and factory hands, plenty of ex-military; the poorest in cube hotels and container housing",
	"security_code": {
		"n": 6,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 5,
	"provider": "6th_street",
	"gangs": [
		"6th_street",
		"muses",
		"toecutters",
		"inquisitors"
	],
	"ncart": [
		"Pheasant Street (Green Line)",
		"Dynalar Station (Executive Monorail)"
	],
	"profile": "mixed_residential",
	"look": [
		"working-class sprawl",
		"neon strip",
		"cube hotels",
		"rusting factories",
		"corporate campus"
	],
	"history": "Split from Heywood in 2038, leaving Santo Domingo as the other half; last year rising Inquisitor and Toecutter attacks pushed the City Manager to deputize 6th Street.",
	"cite": "NC2045 p.246-255"
}
```

## Locations

### #1 Acorn Towers

Modern twin conapt towers for young Dynalar execs and techs.

```world locations.locations.north_heywood_1
{
	"name": "Acorn Towers",
	"district": "north_heywood",
	"number": 1,
	"type": "housing",
	"owner": "dynalar",
	"owner_name": "Dynalar",
	"security_code": {
		"n": 8,
		"faction": "dynalar",
		"intensity": "light",
		"hardened": false
	},
	"utility_code": 4,
	"npcs": [
		"Monique Curse (Fixer 3), Voodoo Boys"
	],
	"hooks": [
		{
			"text": "Voodoo Boy dealer Monique Curse supplies the drugs for the towers' frequent loud rooftop parties.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"corp_extraction"
	],
	"interior": "Twin-tower conapt building with a party patio and rooftop; houses about half of Dynalar's local staff.",
	"cite": "NC2045 p.247"
}
```

### #2 AmeriCar Distribution Center

The Midwestern carmaker's first Pacifica distribution hub, which the City Manager boasts about constantly.

```world locations.locations.north_heywood_2
{
	"name": "AmeriCar Distribution Center",
	"district": "north_heywood",
	"number": 2,
	"type": "warehouse",
	"owner": "americar",
	"owner_name": "AmeriCar",
	"security_code": {
		"n": 9,
		"faction": "6th_street",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Ford Clay (Exec 2/Solo 2)"
	],
	"hooks": [],
	"gigs": [
		"sabotage"
	],
	"interior": "A fortress of corrugated steel holding hundreds of new cars and vans; 6th Street guards it, and Aldecaldo convoys load and unload several times a month.",
	"cite": "NC2045 p.249"
}
```

### #3 The Armory

6th Street's fortified headquarters in a refitted National Guard armory.

```world locations.locations.north_heywood_3
{
	"name": "The Armory",
	"district": "north_heywood",
	"number": 3,
	"type": "gang_base",
	"owner": "6th_street",
	"owner_name": "6th Street",
	"security_code": {
		"n": 10,
		"faction": "6th_street",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Colonel Solomon \"X\" Wright (Solo 7)",
		"Mack \"Grill\" Herrera"
	],
	"hooks": [],
	"gigs": [
		"gang_hit",
		"data_theft",
		"sabotage"
	],
	"interior": "Nine-storey 1950s National Guard armory: armoured-vehicle garage, full weapon lockers, military comms suite; lower floors are barracks, canteen, rec and training rooms and storage; upper floors hold the brass's offices with war maps and trophies; a large stocked fallout shelter lies underneath as an emergency hideout.",
	"cite": "NC2045 p.249"
}
```

### #4 Blue Air Studio Apartments

A sky-blue roadside motel turned long-stay apartments, popular with nomads taking a break from the Aldecaldo Camp.

```world locations.locations.north_heywood_4
{
	"name": "Blue Air Studio Apartments",
	"district": "north_heywood",
	"number": 4,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 4,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Ex-motel of rent-by-night rooms converted into long-term units with kitchenettes; mostly nomads on long city contracts.",
	"cite": "NC2045 p.249"
}
```

### #5 Byte & Switch

A no-questions cyberware repair and black-market mod shop.

```world locations.locations.north_heywood_5
{
	"name": "Byte & Switch",
	"district": "north_heywood",
	"number": 5,
	"type": "shop",
	"owner": "",
	"owner_name": "Tweak (Tech 4)",
	"security_code": {
		"n": 6,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Tweak (Tech 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Cramped repair shop full of half-stripped tech, under a flickering neon sign.",
	"cite": "NC2045 p.249"
}
```

### #6 Dynalar Campus

Dynalar's Night City headquarters, the district's corporate powerhouse.

```world locations.locations.north_heywood_6
{
	"name": "Dynalar Campus",
	"district": "north_heywood",
	"number": 6,
	"type": "corp_hq",
	"owner": "dynalar",
	"owner_name": "Dynalar",
	"security_code": {
		"n": 10,
		"faction": "dynalar",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": 3,
	"npcs": [
		"Finn Fisher (Exec 5/Tech 3)"
	],
	"hooks": [
		{
			"text": "Regional manager Finn Fisher is rumoured to be in quiet talks with Rocklin Augmentics about defecting.",
			"gigs": [
				"corp_extraction"
			]
		}
	],
	"gigs": [
		"corp_extraction",
		"data_theft",
		"sabotage"
	],
	"interior": "A whole block on Grant Avenue in glass and steel: regional offices, R&D labs and a small manufacturing plant, plus cafeteria, fitness centre and virtuality arcade for staff.",
	"cite": "NC2045 p.250"
}
```

### #7 Evergreen Vista Park

The district's patch of green, used for lunch breaks by day and shady deals by night.

```world locations.locations.north_heywood_7
{
	"name": "Evergreen Vista Park",
	"district": "north_heywood",
	"number": 7,
	"type": "park",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 5,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "After dark the park hosts quiet deals, and behind the maintenance shed someone sells cheap guns, XBDs and drugs.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [],
	"interior": "Weedy fields, a creaky playground and a half-working fountain; poorly lit corners at night.",
	"cite": "NC2045 p.250"
}
```

### #8 The Forlorn Hope

A veterans' bar turned edgerunner hangout, moved here after the Little China original burned down. Its regulars are its security.

```world locations.locations.north_heywood_8
{
	"name": "The Forlorn Hope",
	"district": "north_heywood",
	"number": 8,
	"type": "bar",
	"owner": "",
	"owner_name": "John \"The Professor\" Freeman (Fixer 8) and Marianne Freeman (Fixer 6/Tech 4)",
	"security_code": {
		"n": 10,
		"faction": "patrons",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"John \"The Professor\" Freeman (Fixer 8)",
		"Marianne Freeman (Fixer 6/Tech 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Edgerunner bar with an in-house Tech, a ripperdoc clinic and rooms for favourite regulars. (Tales of the RED: Hope Reborn sets it in Little China #3 instead.)",
	"cite": "NC2045 p.250"
}
```

### #9 Haven Spa & Recovery

A trendy wellness spa whose back rooms remake people on the run, run by an ex-Trauma Team surgeon.

```world locations.locations.north_heywood_9
{
	"name": "Haven Spa & Recovery",
	"district": "north_heywood",
	"number": 9,
	"type": "medical",
	"owner": "",
	"owner_name": "Anika Raines (Fixer 3/Medtech 6)",
	"security_code": {
		"n": 5,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Anika Raines (Fixer 3/Medtech 6)"
	],
	"hooks": [
		{
			"text": "The back rooms give fugitives a new face and new ID papers, and for extra pay get them out of the city.",
			"gigs": [
				"corp_extraction",
				"rescue"
			]
		}
	],
	"gigs": [
		"corp_extraction",
		"rescue"
	],
	"interior": "Front of detox baths, neural recalibration pods and massage chairs; back rooms where Medtechs, Techs and Netrunners remake clients.",
	"cite": "NC2045 p.250"
}
```

### #10 Haywire Circuit Gym

A rough gym and sparring hall for local toughs and would-be Solos, run by a retired Solo.

```world locations.locations.north_heywood_10
{
	"name": "Haywire Circuit Gym",
	"district": "north_heywood",
	"number": 10,
	"type": "venue",
	"owner": "",
	"owner_name": "Rico \"Haywire\" Salazar (Solo 4)",
	"security_code": {
		"n": 7,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Rico \"Haywire\" Salazar (Solo 4)"
	],
	"hooks": [
		{
			"text": "Members who pay up or trade favours may get off-the-books gigs from Haywire.",
			"gigs": []
		}
	],
	"gigs": [],
	"interior": "Rundown former factory with rusted weights, patched sparring bots and glitchy virtuality chambers.",
	"cite": "NC2045 p.251"
}
```

### #11 Nana Meow's Nursery

A garden-supply shop run by a cheerful grandmother fixer and her techie grandson.

```world locations.locations.north_heywood_11
{
	"name": "Nana Meow's Nursery",
	"district": "north_heywood",
	"number": 11,
	"type": "shop",
	"owner": "",
	"owner_name": "Nana Meow (Fixer 4)",
	"security_code": {
		"n": 6,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Nana Meow (Fixer 4)",
		"Tavi (Tech 3)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Shop under LED-lit trellises selling soil and aquaponic gear and seeds, some of them rumoured to be tech-upgraded.",
	"cite": "NC2045 p.251"
}
```

### #12 Neon Hollow Strip

The district's nightlife strip. Its star attraction is Riley's Edgework Escapes virtuality arcade.

```world locations.locations.north_heywood_12
{
	"name": "Neon Hollow Strip",
	"district": "north_heywood",
	"number": 12,
	"type": "market",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 4,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Riley (Fixer 3/Tech 3)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "A few connected streets of bars, virtuality joints, smoky clubs, back-alley casinos and sex shops; Edgework Escapes runs combat and heist simulations.",
	"cite": "NC2045 p.251"
}
```

### #13 The Night City Animal Shelter

A clinic for exotics and bioexotics.

```world locations.locations.north_heywood_13
{
	"name": "The Night City Animal Shelter",
	"district": "north_heywood",
	"number": 13,
	"type": "medical",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 7,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Bee Eye NGO (Medtech 6)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Clinic for bodysculpting and treating exotics and bioexotics; its ripperdoc treats anyone who pays.",
	"cite": "NC2045 p.251"
}
```

### #14 North Heywood Civic Nexus

The district's political centre, with government offices and public services under one roof.

```world locations.locations.north_heywood_14
{
	"name": "North Heywood Civic Nexus",
	"district": "north_heywood",
	"number": 14,
	"type": "civic",
	"owner": "city_government",
	"owner_name": "District government (City Manager's office)",
	"security_code": {
		"n": 8,
		"faction": "6th_street",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Barry \"Big Deal\" Delvecchio (Fixer 6)"
	],
	"hooks": [
		{
			"text": "The City Manager's office watches who comes and goes; reportedly Delvecchio's own office is the only room without bugs.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft"
	],
	"interior": "Refurbished pre-Collapse municipal building with resin-reinforced walls and solar arrays; large atrium, press auditorium, cheap cafeteria and the City Manager's office; surveillance throughout.",
	"cite": "NC2045 p.251"
}
```

### #15 Perennial Heights/The Rupture

A dull office building above a secret fight club where furious execs come to brawl.

```world locations.locations.north_heywood_15
{
	"name": "Perennial Heights/The Rupture",
	"district": "north_heywood",
	"number": 15,
	"type": "venue",
	"owner": "",
	"owner_name": "Crux (Fixer 4), runs The Rupture",
	"security_code": {
		"n": 6,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Crux (Fixer 4)",
		"Ford Clay (Exec 2/Solo 2)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Beige office block (accountants, property managers, small law firms, a laundromat, lobby café); its forgotten sublevels host The Rupture, a secret fight club with rules of no guns, no cops and no advertising.",
	"cite": "NC2045 p.252"
}
```

### #16 Sleepeasy Home Solutions

A furniture and smart-home showroom selling the dream on high-interest credit.

```world locations.locations.north_heywood_16
{
	"name": "Sleepeasy Home Solutions",
	"district": "north_heywood",
	"number": 16,
	"type": "shop",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 5,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Ruby Spear",
		"Truvy (Medtech 2)"
	],
	"hooks": [
		{
			"text": "Sleepeasy hires freelancers as muscle on its delivery runs, and its 'procurement specialist' stocks whatever was acquired that week.",
			"gigs": []
		}
	],
	"gigs": [],
	"interior": "Clean prefab-furniture showroom in a decaying strip mall off 8th Street; plaza tenants: Kibbles, Cookies, and Smash (bar), Truvy's Salon (fashionware) and Flexo's Tires (nomad overnight parking).",
	"cite": "NC2045 p.252"
}
```

### #17 Turbine Alley

An abandoned industrial strip reclaimed by gearheads by day and drone racers by night.

```world locations.locations.north_heywood_17
{
	"name": "Turbine Alley",
	"district": "north_heywood",
	"number": 17,
	"type": "chop_shop",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 3,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Graveyard of rusted factories and gutted turbines; by day nomads and rogue mechanics run chop shops and workshops, by night it hosts betting on drone races through the narrow corridors.",
	"cite": "NC2045 p.252"
}
```

### #18 Woodland Park

A busy neighbourhood of old concrete blocks and neon shopfronts. It includes the Muses' Xanadu rink-club, a container village and a Biotechnica palm grove.

```world locations.locations.north_heywood_18
{
	"name": "Woodland Park",
	"district": "north_heywood",
	"number": 18,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 5,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Calliope (Exec 2/Rockerboy 2), Muses",
		"Nana (Tech 7)",
		"Pop Pop (Solo 6)",
		"Ella Corella (Fixer 2)",
		"Carri Zote (Rockerboy 4)",
		"Billy Flight (Fixer 3/Tech 2)"
	],
	"hooks": [
		{
			"text": "Local legend says one engineered palm at the edge of the Biotechnica grove eats small rodents, and now and then a drunk.",
			"gigs": []
		}
	],
	"gigs": [
		"gang_hit"
	],
	"interior": "Packed neighbourhood with these sub-sites: 18a Biotechnica Palm Grove (engineered palms with biomonitors, a research site); 18b Breeze, a drug shop with a famous basement kitchen, sharing a building with Burning Bright Bodega; 18c The Palms, a container community with the Terminus food truck; 18d The Shark, five-storey apartments with a rooftop guerrilla garden and the Choom Goes Vroom garage next door; 18e Xanadu, the Muses' roller rink and nightclub where they host derby bouts; 18f Zolletta, a cube hotel with small shops and the Navad nomads' prayer room.",
	"cite": "NC2045 p.252"
}
```

## Fixers

- Barry "Big Deal" Delvecchio (Fixer 6): City Manager, office in the Civic Nexus (#14); favours, zoning variances and keeping 6th Street happy (NC2045 p.247, p.252).
- John "The Professor" Freeman (Fixer 8): co-owner of The Forlorn Hope (#8); finds services and support for veterans (NC2045 p.250, p.253).
- Marianne Freeman (Fixer 6/Tech 4): runs The Forlorn Hope (#8) day to day; can call in heavy hitters fast (NC2045 p.250, p.253).
- Nana Meow (Fixer 4): Nana Meow's Nursery (#11); seeds and aquaponics, maybe tech-upgraded (NC2045 p.250-251).
- Crux (Fixer 4): runs The Rupture fight club under Perennial Heights (#15); bouts and betting (NC2045 p.252).
- Monique Curse (Fixer 3): Voodoo Boy who supplies drugs at Acorn Towers (#1) (NC2045 p.247).
- Anika Raines (Fixer 3/Medtech 6): Haven Spa & Recovery (#9); new faces, new IDs and exfiltration from the city (NC2045 p.251).
- Riley (Fixer 3/Tech 3): Edgework Escapes on the Neon Hollow Strip (#12); links clients to more than virtual thrills (NC2045 p.251).
- Billy Flight (Fixer 3/Tech 2): owns The Shark in Woodland Park (#18); small-time deals, vehicle repair and storage (NC2045 p.253).
- Ella Corella (Fixer 2): Burning Bright Bodega in Woodland Park (#18); stocks a bit of everything and keeps secrets (NC2045 p.253).

## Personalities

- Lester "Loudmouth" Lewis (Media 4): the district's guide, a resident for twenty-plus years (NC2045 p.246).
- Calliope (Exec 2/Rockerboy 2): manager of Xanadu and leader of the Muses; won over by bold individual fashion (NC2045 p.253).
- Carri Zote (Rockerboy 4): runs the Terminus food truck in The Palms and models for catalogues when money is tight (NC2045 p.253).
- Colonel Solomon "X" Wright (Solo 7): ex-military intelligence officer who founded 6th Street and wants it to rival Militech and Lazarus (NC2045 p.253-254).
- Finn Fisher (Exec 5/Tech 3): Dynalar regional manager who expects the cyberfinger push to fail; rumoured to be talking to Rocklin (NC2045 p.254).
- Ford Clay (Exec 2/Solo 2): AmeriCar shipment coordinator who fights other execs at The Rupture every week (NC2045 p.254).
- John "The Professor" Freeman (Fixer 8): PhD who has helped discarded veterans for decades; slowly dying of ALS (NC2045 p.254).
- Mack "Grill" Herrera: chrome-jawed 6th Street recruit with no military past, the new face of the gang (NC2045 p.254).
- Marianne Freeman (Fixer 6/Tech 4): the warm heart of The Forlorn Hope, never to be taken for soft (NC2045 p.254).
- Mohawk (Nomad 5/Solo 2): vicious leader of the Toecutters (NC2045 p.254).
