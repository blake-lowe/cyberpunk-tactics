# Pacifica Playground

Southside's pleasure district, built by Richard Night for entertainment and still selling every vice: casinos,
brothels, drugs and parties, with Playland by the Sea as its crown jewel (NC2045 p.276-285). Playland's 2036 reopening,
Tanson Group's arrival in 2040 and the Jodes nomads' camp in 2041 pulled it back from Rancho Coronado's blight. The
Piranhas are everywhere and the Voodoo Boys lurk; their feud made the City Manager hire Militech to patrol, while
smaller businesses hire 6th Street. Tanson's complex and the Jodes Camp police themselves.

```world city.districts.pacifica_playground
{
	"name": "Pacifica Playground",
	"region": "southside",
	"manager": {
		"name": "Elliot Kane",
		"role": "Exec 5"
	},
	"population": "Workers for Playland, Tanson, the Jodes and the vice trade; tourists nearly match residents at peak; Korean enclave around Tanson, Jodes nomads on the south edge",
	"security_code": {
		"n": 8,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 2,
	"provider": "militech",
	"gangs": [
		"6th_street",
		"mudang_gumi",
		"piranhas",
		"voodoo_boys"
	],
	"ncart": [
		"Orange Line station (unnamed on the map)"
	],
	"profile": "pacifica",
	"look": [
		"seaside",
		"neon",
		"casinos",
		"tourist crowds",
		"boardwalk",
		"corporate domes"
	],
	"history": "Playland reopened in 2036, Tanson moved in in 2040 and the Jodes camped here in 2041; Militech was hired this year when NCPD could not stop the Piranha-Voodoo Boys war.",
	"cite": "NC2045 p.276-285"
}
```

## Locations

### #1 The Ascension

A giant cruise liner that never left drydock, reborn as a floating sin city of gambling, dining, BD clubs, instant weddings and Weng Fang Tong joytoys.

```world locations.locations.pacifica_playground_1
{
	"name": "The Ascension",
	"district": "pacifica_playground",
	"number": 1,
	"type": "casino",
	"owner": "belko_entertainment",
	"owner_name": "Belko Entertainment Company (Anaheim)",
	"security_code": {
		"n": 9,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Cyrus Finch (Fixer 3/Media 3)",
		"Ryu Sakai (Solo 6)",
		"Betty \"Rage\" Ragnoli (Netrunner 2/Solo 3)"
	],
	"hooks": [
		{
			"text": "Netwatch rents the aft of Deck Three as its Night City headquarters.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "The Piranhas run Pacifica Parties, an event service, from Deck Five.",
			"gigs": [
				"gang_hit"
			]
		},
		{
			"text": "Chef Ryu Sakai's blade work suggests training in more than cooking.",
			"gigs": [
				"assassination"
			]
		}
	],
	"gigs": [
		"data_theft",
		"assassination",
		"corp_extraction"
	],
	"interior": "Drydocked liner crewed by Thelas nomads; casino floor, Daiseikō restaurant, Enervate lounge, BD clubs, wedding chapel; Netwatch HQ aft on Deck Three; Pacifica Parties on Deck Five.",
	"cite": "NC2045 p.277-279"
}
```

### #2 Bits'n'Bolts

Honest tool and tech repair shop that also sells scavver salvage from building sites.

```world locations.locations.pacifica_playground_2
{
	"name": "Bits'n'Bolts",
	"district": "pacifica_playground",
	"number": 2,
	"type": "shop",
	"owner": "",
	"owner_name": "Patchz (Tech 3)",
	"security_code": {
		"n": 6,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Patchz (Tech 3)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.279"
}
```

### #3 Cubeland by the Sea

A leaky, leaning pre-war workers' cube hotel full of Playland fans chasing the resident ticket discount.

```world locations.locations.pacifica_playground_3
{
	"name": "Cubeland by the Sea",
	"district": "pacifica_playground",
	"number": 3,
	"type": "cube_hotel",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 5,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.279"
}
```

### #4 Dream Forest Development

Tanson's seven-storey, multi-block employee near-arcology (locals call it H0), closed to anyone but staff, family and invited guests.

```world locations.locations.pacifica_playground_4
{
	"name": "Dream Forest Development",
	"district": "pacifica_playground",
	"number": 4,
	"type": "megabuilding",
	"owner": "tanson",
	"owner_name": "Tanson Group",
	"security_code": {
		"n": 10,
		"faction": "tanson",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The Mudang Gumi digital theft ring operates from inside; nobody knows which residents are members.",
			"gigs": [
				"data_theft",
				"gang_hit"
			]
		}
	],
	"gigs": [
		"data_theft",
		"corp_extraction"
	],
	"interior": "Basement mall 'The Roots of the Forest' (shops, spas, arcades, galleries, rival sculpt clinics SykoStyles and EverSmilE); six residential floors each with a bodega, playground and lounge; 7th floor indoor park with pool and mini golf for staff rated 'exceeds expectations'.",
	"cite": "NC2045 p.279"
}
```

### #5 Flaire

Same-day full-body conversion clinic fitting rich clients into custom Gemini FBC bodies, with therapy and brain solution included.

```world locations.locations.pacifica_playground_5
{
	"name": "Flaire",
	"district": "pacifica_playground",
	"number": 5,
	"type": "medical",
	"owner": "",
	"owner_name": "Doctor Gray Wilkes (Medtech 6/Tech 4)",
	"security_code": {
		"n": 8,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Doctor Gray Wilkes (Medtech 6/Tech 4)"
	],
	"hooks": [
		{
			"text": "Rumour: patients' brains are fed Enhanced propaganda blips while they are under the knife.",
			"gigs": [
				"data_theft",
				"sabotage"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"interior": "",
	"cite": "NC2045 p.279-280"
}
```

### #6 Jodes Camp

The Jodes Nation's home base: a container community and trailer park where convoys refuel, swap cargo and resupply; it polices itself.

```world locations.locations.pacifica_playground_6
{
	"name": "Jodes Camp",
	"district": "pacifica_playground",
	"number": 6,
	"type": "outskirts_site",
	"owner": "jodes",
	"owner_name": "Jodes Nation; run by Solomon \"Old Greenjeans\" LaPlante (Nomad 10)",
	"security_code": {
		"n": 7,
		"faction": "jodes",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Solomon \"Old Greenjeans\" LaPlante (Nomad 10)",
		"Doc Miles (Medtech 4)",
		"Ojo (Fixer 6)",
		"Old Grace (Nomad 3/Solo 5)"
	],
	"hooks": [],
	"gigs": [
		"rescue"
	],
	"interior": "Container blocks and trailer park; Doc Miles' tent clinic; Nomad's Market in five containers (Ojo in container three, Diego Motors vehicles and upgrades); The Ring sumo and wrestling school; Militech and NCPD stop at its border.",
	"cite": "NC2045 p.280"
}
```

### #7 Mister Rice Guy

Conveyor-belt diner with colour-coded tiers from cheap Kibble up to real fish sushi; the mascot Hime Cat sends diners fortunes.

```world locations.locations.pacifica_playground_7
{
	"name": "Mister Rice Guy",
	"district": "pacifica_playground",
	"number": 7,
	"type": "restaurant",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.280"
}
```

### #8 Obsidian Equinox Marina & Docks

Where the Exec Zone and Charter Hill elite berth their yachts for 1,000eb a month and throw parties aboard.

```world locations.locations.pacifica_playground_8
{
	"name": "Obsidian Equinox Marina & Docks",
	"district": "pacifica_playground",
	"number": 8,
	"type": "docks",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 9,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "A Piranha shoal keeps the yacht owners supplied; some prefer the Voodoo Boys' XBDs instead.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"assassination",
		"corp_extraction",
		"gang_hit"
	],
	"interior": "",
	"cite": "NC2045 p.280"
}
```

### #9 Pacifica Arcology Ruins

A wrecked arcology sticking out of the sea down the coast, sealed since the nuke; its security code is unknown ('?: ??, ??').

```world locations.locations.pacifica_playground_9
{
	"name": "Pacifica Arcology Ruins",
	"district": "pacifica_playground",
	"number": 9,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": null,
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Scavver crews who try to break in never return; since part of it collapsed, toxic fleshy blobs wash ashore in Pacifica.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"rescue"
	],
	"interior": "Self-sufficient refuge built for Hong Kong investors, sealed with residents inside; southwest corner fell into the ocean a few months ago.",
	"cite": "NC2045 p.281"
}
```

### #10 Playhouse

Apartment block that once hosted a deadly reality show; the landlord swears the cameras and the 'murder elevator' are gone, but tenants report cold spots and wails.

```world locations.locations.pacifica_playground_10
{
	"name": "Playhouse",
	"district": "pacifica_playground",
	"number": 10,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 6,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.281"
}
```

### #11 Pleasant Valley Apartments

Eight storeys of deliberately retro, low-tech living.

```world locations.locations.pacifica_playground_11
{
	"name": "Pleasant Valley Apartments",
	"district": "pacifica_playground",
	"number": 11,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 8,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "No NET Architecture; analog locks, manual lights, climate and water; push-button elevator.",
	"cite": "NC2045 p.281"
}
```

### #12 Pursuit Security Inc Showroom

Small showroom for less-than-lethal weaponry trucked up by the Jodes from the SoCal factory.

```world locations.locations.pacifica_playground_12
{
	"name": "Pursuit Security Inc Showroom",
	"district": "pacifica_playground",
	"number": 12,
	"type": "gun_shop",
	"owner": "pursuit_security",
	"owner_name": "Pursuit Security Inc",
	"security_code": {
		"n": 8,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.281"
}
```

### #13 Quaid Winston Memorial De-Salinization Plant

Desalination plant named for an engineer who drank its first, unpurified glass; most of its water now goes to Playland, not residents.

```world locations.locations.pacifica_playground_13
{
	"name": "Quaid Winston Memorial De-Salinization Plant",
	"district": "pacifica_playground",
	"number": 13,
	"type": "utility",
	"owner": "hydrosubsidium",
	"owner_name": "Hydrosubsidium",
	"security_code": {
		"n": 8,
		"faction": "hydrosubsidium",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Hydrosubsidium blamed the fatal first run on sabotage, covered it up and paid the family off.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"sabotage",
		"data_theft"
	],
	"interior": "",
	"cite": "NC2045 p.281"
}
```

### #14 ShellShock Central

Top-of-the-line roller-derby arena of the Pacifica Sea Shells, funded by local businesses, beside Playland.

```world locations.locations.pacifica_playground_14
{
	"name": "ShellShock Central",
	"district": "pacifica_playground",
	"number": 14,
	"type": "stadium",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 8,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Betty \"Rage\" Ragnoli (Netrunner 2/Solo 3)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Glass-roofed arena with an underground gym.",
	"cite": "NC2045 p.281-282"
}
```

### #15 Scenic Cubes

Windowless cube hotel with a sociable roof overlooking the ocean and graffiti by resident artists on every floor.

```world locations.locations.pacifica_playground_15
{
	"name": "Scenic Cubes",
	"district": "pacifica_playground",
	"number": 15,
	"type": "cube_hotel",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 6,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.282"
}
```

### #16 Smile Another Day

Sells retired Playland merch, ride scraps and costumes, unaffiliated with the park; its owner hired 6th Street for protection.

```world locations.locations.pacifica_playground_16
{
	"name": "Smile Another Day",
	"district": "pacifica_playground",
	"number": 16,
	"type": "shop",
	"owner": "",
	"owner_name": "Dalton \"Dizzy\" Knee (Fixer 5)",
	"security_code": {
		"n": 6,
		"faction": "6th_street",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Dalton \"Dizzy\" Knee (Fixer 5)"
	],
	"hooks": [
		{
			"text": "Playland's owners would be glad if someone firebombed the shop.",
			"gigs": [
				"sabotage"
			]
		},
		{
			"text": "Dizzy sells the best items he 'liberated' from the park at a yearly Night Market in Volkodav's Party Room.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"sabotage"
	],
	"interior": "",
	"cite": "NC2045 p.282"
}
```

### #17 Stop. Shop. Stitch.

A bodega and a ripperdoc clinic whose quarrelling owners married and merged.

```world locations.locations.pacifica_playground_17
{
	"name": "Stop. Shop. Stitch.",
	"district": "pacifica_playground",
	"number": 17,
	"type": "medical",
	"owner": "",
	"owner_name": "Ruth Blue and Rohit Patel (Medtech 3)",
	"security_code": {
		"n": 8,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Ruth Blue",
		"Rohit Patel (Medtech 3)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Bodega downstairs, clinic upstairs.",
	"cite": "NC2045 p.282"
}
```

### #18 Tanson Group Headquarters

The Korean megacorp's self-policed complex in southern Pacifica; it ships goods to other West Coast cities but barely sells in Night City.

```world locations.locations.pacifica_playground_18
{
	"name": "Tanson Group Headquarters",
	"district": "pacifica_playground",
	"number": 18,
	"type": "corp_hq",
	"owner": "tanson",
	"owner_name": "Tanson Group",
	"security_code": {
		"n": 10,
		"faction": "tanson",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Mirei Park (Exec 5)"
	],
	"hooks": [
		{
			"text": "Tanson is said to be eyeing the gap left by IEC's destruction.",
			"gigs": [
				"data_theft",
				"corp_extraction"
			]
		},
		{
			"text": "Unauthorised visitors are captured and interrogated; some disappear.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage",
		"rescue"
	],
	"interior": "Five concrete domes: administration, two manufacturing, R&D, warehousing; Council advisory seat makes it self-policed; no-fly zone with AA guns on every dome roof.",
	"cite": "NC2045 p.282"
}
```

### #19 Torta-sienda

Hole-in-the-wall torta joint run by Paz and Renata Moreno, sourcing fresh ingredients through the Jodes. The text heads it #18; the map index gives #19.

```world locations.locations.pacifica_playground_19
{
	"name": "Torta-sienda",
	"district": "pacifica_playground",
	"number": 19,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Paz and Renata Moreno",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Paz Moreno",
		"Renata Moreno",
		"Miguel (Solo 5)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.283"
}
```

### #20 Volkodav Racetrack

Down-market gambling on old robot police dogs chasing plastic rabbits, 24/7; the Voodoo Boys took it over a few years ago. (Text #19, map #20.)

```world locations.locations.pacifica_playground_20
{
	"name": "Volkodav Racetrack",
	"district": "pacifica_playground",
	"number": 20,
	"type": "casino",
	"owner": "voodoo_boys",
	"owner_name": "Voodoo Boys",
	"security_code": {
		"n": 9,
		"faction": "voodoo_boys",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The Voodoo Boys cook and store drugs in the basement and hold joytoys and XBD 'stars' from Rancho Coronado there.",
			"gigs": [
				"gang_hit",
				"rescue",
				"sabotage"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	],
	"interior": "Dog track with betting; the Party Room (mattress-strewn XBD rental space); basement drug lab, storage and captives.",
	"cite": "NC2045 p.283"
}
```

### #21 WNS Offices

World News Service's gaudy Night City newsroom, in practice a name leased to Diverse Media Systems. (Text #20, map #21.)

```world locations.locations.pacifica_playground_21
{
	"name": "WNS Offices",
	"district": "pacifica_playground",
	"number": 21,
	"type": "media",
	"owner": "dms",
	"owner_name": "World News Service (run as a DMS franchise)",
	"security_code": {
		"n": 8,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "DMS talent scouts at WNS 100.2 sign new acts to predatory contracts.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"data_theft"
	],
	"interior": "Newsroom and broadcast studio; adjoining building holds WNS 100.2 radio and the DMS scouts.",
	"cite": "NC2045 p.283"
}
```

### #22 The XX (The Twenty)

Dive bar that serves only juice, owned by punk band Breakfist, with Pacifica's best live acts. (Text #21, map #22.)

```world locations.locations.pacifica_playground_22
{
	"name": "The XX (The Twenty)",
	"district": "pacifica_playground",
	"number": 22,
	"type": "club",
	"owner": "",
	"owner_name": "Breakfist (punk band)",
	"security_code": {
		"n": 6,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Ten Ton (Rockerboy 6)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.283-284"
}
```

## Fixers

- Cyrus Finch (Fixer 3/Media 3) — works the Ascension casino floor (#1); trades in gossip overheard at the tables.
- Ojo (Fixer 6) — Nomad's Market, container three, Jodes Camp (#6): sources Diego Motors vehicles, repairs and upgrades.
- Dalton "Dizzy" Knee (Fixer 5) — Smile Another Day (#16): Playland memorabilia and goods 'liberated' from the park; yearly Night Market.
- Rex Royale (Fixer 5): ours, not NC2045's: a casino-themed Fixer selling weapons and combat gear (SPM p.57), placed among the casinos (docs/world/fixers.md).

## Personalities

- Baron D (Exec 4) — Voodoo Boys leader who wants to ditch the voodoo image; may reward or murder whoever suggests how.
- Betty "Rage" Ragnoli (Netrunner 2/Solo 3) — Ascension 'hospitality specialist' and Sea Shells blocker.
- Captain Rochelle Draiman (Exec 4/Lawman 4) — Militech's district commander; walks the streets alone, covered by rooftop snipers.
- Corpse Reviver (Exec 4) — Piranhas leader who turned a party gang into an entertainment business.
- Dan Renzer (Lawman 1) — ex-cop Netwatch agent stuck with the worst cases.
- Mirei Park (Exec 5) — Tanson's Regional Director of Business Relationships, the door to doing business with the corp.
- Ryu Sakai (Solo 6) — chef-owner of Daiseikō aboard the Ascension, suspiciously good with blades.
- Solomon "Old Greenjeans" LaPlante (Nomad 10) — runs the Jodes Camp; sole survivor of a Petrochem-hired raid on his father's farm.
- Ten Ton (Rockerboy 6) — Breakfist's bassist-manager, a sober punk who fled London's police.
- Yor Life (Rockerboy 4) — indie BD star recording mundane lives for slumming rich viewers.
