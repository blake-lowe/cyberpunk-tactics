# Heywood Docks

Heywood Docks is a mob-run port. The Skiv Family built it with money from the Heywood Industrial Zone corporations
(the Arroyo Concern) and shipper Decker, Tanaka & Rogers, so that small and mid-sized cargo ships can dock more cheaply
than at the nomad-run Port of Night City. SK Securities, the Skivs' firm, both runs the district and polices it. Its CEO and
City Manager is Andrea Lee (Exec 5), sister-in-law of crime boss Lynn Skiv (Fixer 7). Lee's guards shoot trespassers on
sight; about half are convicts on long-term contracts, and nearly all take bribes (NC2045 p.240-241).

```world city.districts.heywood_docks
{
	"name": "Heywood Docks",
	"region": "mainland",
	"manager": {
		"name": "Andrea Lee",
		"role": "Exec 5"
	},
	"population": "the smallest outside the Executive Zone; little housing, most dockers commute from North Heywood or New Westbrook",
	"security_code": {
		"n": 6,
		"faction": "sk_securities",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"provider": "sk_securities",
	"gangs": [
		"skiv_family",
		"deadwoods",
		"maelstrom"
	],
	"ncart": [
		"Heywood Docks Station (Red Line)",
		"Heywood Docks Rail Yard (cargo rail)"
	],
	"profile": "industrial",
	"look": [
		"cargo cranes",
		"container walls",
		"rail yard",
		"canal water",
		"blue-uniformed guards"
	],
	"history": "Built by the Skiv Family with money from the Arroyo Concern corps and shipper DT&R, to undercut the nomad-run Port of Night City.",
	"cite": "NC2045 p.240-245"
}
```

## Locations

### #1 The Cylinders

Cheap housing made from old tanker trucks. The residents' coughing says more about safety than the SK manager does.

```world locations.locations.heywood_docks_1
{
	"name": "The Cylinders",
	"district": "heywood_docks",
	"number": 1,
	"type": "cube_hotel",
	"owner": "sk_securities",
	"owner_name": "SK Securities",
	"security_code": {
		"n": 4,
		"faction": "sk_securities",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Matthias John (Solo 2), Perdivers"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Rusting Petrochem CHOOH2 tanker trucks crudely partitioned into cubes; home to the Perdivers underwater-salvage scavvers and most of the docks' permanent residents.",
	"cite": "NC2045 p.243"
}
```

### #2 Decker, Tanaka & Rogers

The recovering shipping giant's local office, which handles about half the docks' cargo.

```world locations.locations.heywood_docks_2
{
	"name": "Decker, Tanaka & Rogers",
	"district": "heywood_docks",
	"number": 2,
	"type": "corp_office",
	"owner": "decker_tanaka_rogers",
	"owner_name": "Decker, Tanaka & Rogers (DT&R)",
	"security_code": {
		"n": 7,
		"faction": "sk_securities",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Reyan (Exec 5)"
	],
	"hooks": [
		{
			"text": "DT&R is always hiring edgerunners for convoy and ship security; recruiter Reyan scouts at the Afterlife.",
			"gigs": []
		},
		{
			"text": "Manifests here come out accurate or not, depending on who pays.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "DT&R's on-site execs know secret nomad routes and security, which hints that a major nomad power is secretly involved.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "A DT&R ship blew up leaving the docks last month; many blame Thelas nomads warning DT&R off their business.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"interior": "Logistics office for DT&R ships and trucks; the company moves about half of the docks' traffic.",
	"cite": "NC2045 p.243"
}
```

### #3 Dockside Billhooks Track

Home track of the Dockside Billhooks roller derby team, marked by black-hook-on-blue graffiti.

```world locations.locations.heywood_docks_3
{
	"name": "Dockside Billhooks Track",
	"district": "heywood_docks",
	"number": 3,
	"type": "venue",
	"owner": "",
	"owner_name": "Dockside Billhooks roller derby squad",
	"security_code": {
		"n": 5,
		"faction": "sk_securities",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Level derby track ringed by girders and crash barriers inside a wall of cargo containers; penalty boxes in the centre; seating on improvised scaffolding.",
	"cite": "NC2045 p.243"
}
```

### #4 Greenbox Storage Units

Storage lockers that double as illegal homes; the security cameras are only for show.

```world locations.locations.heywood_docks_4
{
	"name": "Greenbox Storage Units",
	"district": "heywood_docks",
	"number": 4,
	"type": "warehouse",
	"owner": "sk_securities",
	"owner_name": "SK Securities",
	"security_code": {
		"n": 4,
		"faction": "sk_securities",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Armoured, climate-controlled storage units, some lived in illegally; a guard station by the gate has vending machines and the only toilet; patrols are irregular and the cameras have been dead for months.",
	"cite": "NC2045 p.243"
}
```

### #5 HF&S Construction

The Skiv Family's construction firm, a major player in rebuilding the city.

```world locations.locations.heywood_docks_5
{
	"name": "HF&S Construction",
	"district": "heywood_docks",
	"number": 5,
	"type": "warehouse",
	"owner": "skiv_family",
	"owner_name": "Halsey, Ferris & Skiv (Skiv Family)",
	"security_code": {
		"n": 7,
		"faction": "sk_securities",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The company's warehouses hold building materials, equipment and the odd dead body.",
			"gigs": [
				"gang_hit",
				"data_theft"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"sabotage"
	],
	"interior": "Main offices, a large open yard and three warehouses.",
	"cite": "NC2045 p.243"
}
```

### #6 LoadStar Continental Shipping

Continental Brands' own shipping line, which undercuts nomad freight rates by a quarter.

```world locations.locations.heywood_docks_6
{
	"name": "LoadStar Continental Shipping",
	"district": "heywood_docks",
	"number": 6,
	"type": "docks",
	"owner": "continental_brands",
	"owner_name": "Continental Brands",
	"security_code": {
		"n": 8,
		"faction": "continental_brands",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Dwight Frye (Exec 5)"
	],
	"hooks": [
		{
			"text": "LoadStar crews its fleet with nomads exiled from their families, offered a job or a bullet.",
			"gigs": [
				"rescue",
				"sabotage"
			]
		},
		{
			"text": "Feuding SK Securities and LoadStar dockworkers regularly come to blows.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage",
		"data_theft"
	],
	"interior": "Handles loading, unloading and maintenance of the company's docked ships and parked trucks.",
	"cite": "NC2045 p.244"
}
```

### #7 Rail Yard

Where Snake Nation cargo trains load at the docks, with DeadWoods on hand to protect the railway.

```world locations.locations.heywood_docks_7
{
	"name": "Rail Yard",
	"district": "heywood_docks",
	"number": 7,
	"type": "rail",
	"owner": "snake_nation",
	"owner_name": "Snake Nation nomads (cargo railways)",
	"security_code": {
		"n": 8,
		"faction": "deadwoods",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The Snake Nation can't refuse dock cargo but fears angering the Thelas who run the Port; so far the Thelas haven't made them pick a side.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage"
	],
	"interior": "Cargo rail tracks through the docks; dockers load Snake-run trains, and DeadWoods guard the line.",
	"cite": "NC2045 p.244"
}
```

### #8 Shipping Yard

A small imitation of the Port's yards where cargo waits for onward transport.

```world locations.locations.heywood_docks_8
{
	"name": "Shipping Yard",
	"district": "heywood_docks",
	"number": 8,
	"type": "docks",
	"owner": "sk_securities",
	"owner_name": "SK Securities",
	"security_code": {
		"n": 8,
		"faction": "sk_securities",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "About once a month someone tries to hijack a cargo truck in or out of the district, and sometimes it works.",
			"gigs": [
				"sabotage"
			]
		},
		{
			"text": "Andrea Lee knows too many thefts or blasts will send the investors back to the Port of Night City.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage"
	],
	"interior": "Open lots and warehouses holding crates, pallets and containers in transit; SK's best guards patrol it.",
	"cite": "NC2045 p.244"
}
```

### #9 SK Securities

HQ of SK Securities, which runs the district. It is also, in practice, the Skiv Family's HQ.

```world locations.locations.heywood_docks_9
{
	"name": "SK Securities",
	"district": "heywood_docks",
	"number": 9,
	"type": "police",
	"owner": "sk_securities",
	"owner_name": "Andrea Lee (Exec 5), CEO",
	"security_code": {
		"n": 8,
		"faction": "sk_securities",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Andrea Lee (Exec 5)",
		"Lynn Skiv (Fixer 7)"
	],
	"hooks": [
		{
			"text": "Andrea Lee wants Council votes to dredge and widen Morro Canal, which would cost three neighbouring districts land.",
			"gigs": [
				"sabotage",
				"data_theft"
			]
		},
		{
			"text": "ERI, the Thelas, the Weng Fang Tong and the Tyger Claws would all like Andrea Lee dead.",
			"gigs": [
				"assassination"
			]
		},
		{
			"text": "Lynn Skiv half expects her sister-in-law to make a play for the family.",
			"gigs": [
				"assassination",
				"data_theft"
			]
		},
		{
			"text": "Lee wants a cheap underwater salvage crew to clear canal wrecks, likely so she can pocket part of the Arroyo Concern's funds.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"assassination",
		"data_theft",
		"gang_hit"
	],
	"interior": "Two ugly twin bunkers housing offices, records rooms, NET Architectures, meeting rooms, an armoury, break rooms and jail cells; Lynn Skiv keeps an office; Piccolo, a small bodega, is in a shed on one side.",
	"cite": "NC2045 p.244"
}
```

### #10 Warehouse 13

A big no-questions rental space, rarely empty.

```world locations.locations.heywood_docks_10
{
	"name": "Warehouse 13",
	"district": "heywood_docks",
	"number": 10,
	"type": "warehouse",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 4,
		"faction": "sk_securities",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Large turnstile warehouse rented short-term, no questions asked, for raves, Night Markets, projects or op staging.",
	"cite": "NC2045 p.244"
}
```

## Fixers

- Lynn Skiv (Fixer 7): SK Securities HQ (#9); boss of the Skiv Family, the city's crime boss of bosses; construction, embezzlement, smuggling (NC2045 p.241, p.245).
- Tony "Nutcracker" Vilshenko (Fixer 5): head of the Vilshenkos, a mob family under the Skivs (NC2045 p.244-245).

## Personalities

- Angela "Jumpshot" Banks (Media 4): reporter digging into the docks' shell companies and the district's guide (NC2045 p.240).
- Tony "Nutcracker" Vilshenko (Fixer 5): ex-ballet-dancer mob boss whose family is pushing him to challenge the Skivs (NC2045 p.244-245).
- Dwight Frye (Exec 5): LoadStar branch director, fanatically loyal to Continental Brands and openly bigoted against nomads (NC2045 p.245).
- Lynn Skiv (Fixer 7): last of the Skivs after the nuke; history graduate using the docks as legitimate cover to retake the underworld (NC2045 p.245).
- Matthias John (Solo 2): youngest Perdiver, expert night diver who salvages Morro Canal wrecks; would make a good underwater guide (NC2045 p.245).
- Reyan (Exec 5): DT&R recruiter who drinks at the Afterlife hunting talent for transport security (NC2045 p.245).
- Toby Hunter: dockhand with an eidetic memory who can find any crate, for a price (NC2045 p.245).
