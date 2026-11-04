# NorCal Military Base

A sovereign military enclave that buys a seat on the City Council but answers only to base law: the COG's Military Police arrest, try and sometimes shoot offenders without Night City's courts. Every resident is military in some form, children train in the COG Scouts from school age, and Militech runs its Pacifica HQ inside the wire for a token lease. Visitors on business get an MP escort; the only open gate is on Sir Frances Drake Avenue. (NC2045 p.178-181)

```world city.districts.norcal_military_base
{
	"name": "NorCal Military Base",
	"region": "northside",
	"manager": {
		"name": "General Ash Giovanni",
		"role": "Exec 7/Solo 6"
	},
	"population": "almost all COG soldiers, sailors and airmen; civilians who move on base must enlist in the COG Reserve; Militech staff live on site",
	"security_code": {
		"n": 10,
		"faction": "norcal_cog_military_police",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": 2,
	"provider": "norcal_cog_military_police",
	"gangs": [
		"culper_ring"
	],
	"ncart": [],
	"profile": "corporate_center",
	"look": [
		"military base",
		"brutalist concrete",
		"walled checkpoints",
		"barracks",
		"hangars and docks",
		"parade lawns"
	],
	"history": "Founded by the 2016 treaty that freed NorCal; its units besieged Night City in the 4th Corporate War, then in 2027 swore to NorCal as the Estero Bay Military COG.",
	"cite": "NC2045 p.178-185"
}
```

## Locations

### #1 157th Tactical Air Squadron Airfield

Where the 157th parks and services its patchwork air fleet; supply-chain gaps since the 4CW mean no two aircraft types match.

```world locations.locations.norcal_military_base_1
{
	"name": "157th Tactical Air Squadron Airfield",
	"district": "norcal_military_base",
	"number": 1,
	"type": "military",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG, 157th Tactical Air Squadron",
	"security_code": {
		"n": 11,
		"faction": "norcal_cog_military_police",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage"
	],
	"interior": "Hangars and pads for a mixed fleet bought piecemeal: Gyrfalcon gunships, Thunderhawk fighters, PAPC helicopters, troop transports and an Overlord airship.",
	"cite": "NC2045 p.181"
}
```

### #2 COG Treatment Facility (CTF)

The base hospital: not Trauma Team grade, but better than most civilian clinics. Everyone on base is screened for cyberpsychosis, and therapy or forced cyberware removal is mandatory for those at risk.

```world locations.locations.norcal_military_base_2
{
	"name": "COG Treatment Facility (CTF)",
	"district": "norcal_military_base",
	"number": 2,
	"type": "medical",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG",
	"security_code": {
		"n": 10,
		"faction": "norcal_cog_military_police",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Base hospital with a combat-wound speciality and an outstanding burn ward; cyberware is fitted free to troops with a commander's sign-off.",
	"cite": "NC2045 p.182"
}
```

### #3 Estero Bay Military COG Academy

The school for every child on base, doubling as a hardened shelter for non-essential personnel during typhoons or missile strikes.

```world locations.locations.norcal_military_base_3
{
	"name": "Estero Bay Military COG Academy",
	"district": "norcal_military_base",
	"number": 3,
	"type": "school",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG",
	"security_code": {
		"n": 10,
		"faction": "norcal_cog_military_police",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Five floors: elementary on 1-2, middle school on 3, high school on 4-5; reinforced as a disaster shelter and the whole building can sink underground on an elevator system (triggered once, in 2041, by a SAAI glitch).",
	"cite": "NC2045 p.182"
}
```

### #4 Fire & Emergency Response Center

Run by the 120.8th Engineers; handles fires, hazmat spills and medical emergencies, anything short of combat.

```world locations.locations.norcal_military_base_4
{
	"name": "Fire & Emergency Response Center",
	"district": "norcal_military_base",
	"number": 4,
	"type": "civic",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG, 120.8th Engineer Battalion",
	"security_code": {
		"n": 10,
		"faction": "norcal_cog_military_police",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Garage for response vehicles, including Night City's only AV pumper truck and ground and air ambulances.",
	"cite": "NC2045 p.182"
}
```

### #5 Main Gate

The base's single public entrance on Sir Frances Drake Avenue, where every visitor's papers are checked.

```world locations.locations.norcal_military_base_5
{
	"name": "Main Gate",
	"district": "norcal_military_base",
	"number": 5,
	"type": "military",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG",
	"security_code": {
		"n": 10,
		"faction": "norcal_cog_military_police",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Fortified gatehouse with a small visitor lot where MPs check credentials; the only entry for outsiders. Other gates are kept shut and guarded; Militech keeps separate gates of its own (Mary E. Walker Street, Norton Drive).",
	"cite": "NC2045 p.182"
}
```

### #6 Mess Hall

Night City's largest kitchen: thousands of Kibble-and-SCOP meals a day for troops and reservists; officers can dine on fresh food at the Officers' Club instead.

```world locations.locations.norcal_military_base_6
{
	"name": "Mess Hall",
	"district": "norcal_military_base",
	"number": 6,
	"type": "restaurant",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG",
	"security_code": {
		"n": 9,
		"faction": "norcal_cog_military_police",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.182"
}
```

### #7 Military Police Headquarters

Home of the mixed-force MP unit that polices the base under military law; convictions are swift and prisoners seldom stay long.

```world locations.locations.norcal_military_base_7
{
	"name": "Military Police Headquarters",
	"district": "norcal_military_base",
	"number": 7,
	"type": "police",
	"owner": "norcal_cog_military_police",
	"owner_name": "Estero Bay Military COG Military Police",
	"security_code": {
		"n": 11,
		"faction": "norcal_cog_military_police",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Captain Jennifer Quick (Lawman 9)"
	],
	"hooks": [
		{
			"text": "General Giovanni has ordered the MPs to root out the Culper Ring, a secret society of troops who want NorCal back in the United States and are said to leak intel to US agents in the city.",
			"gigs": [
				"data_theft",
				"rescue",
				"assassination"
			]
		}
	],
	"gigs": [
		"data_theft",
		"rescue"
	],
	"interior": "Brutalist concrete block: ground floor lobby and garage (converted VMW Aerojeeps, two armed Militech Gorgon vans); floors 2-3 offices, meeting rooms, armory and interrogation rooms; basement morgue and crime lab. The stockade is a separate building next door.",
	"cite": "NC2045 p.181"
}
```

### #8 Militech Corporate Housing

Housing for about half of Militech's local workforce, near the main gate.

```world locations.locations.norcal_military_base_8
{
	"name": "Militech Corporate Housing",
	"district": "norcal_military_base",
	"number": 8,
	"type": "housing",
	"owner": "militech",
	"owner_name": "Militech",
	"security_code": {
		"n": 10,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Senior Militech Execs crowd the third-floor cigar lounge every night trading talk of strikes and counterstrikes.",
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
	"interior": "Spartan rooms in tough, high-grade materials; cigar lounge on the third floor; guests are searched; walled off from the base with an MP checkpoint onward.",
	"cite": "NC2045 p.183"
}
```

### #9 Militech Offices

Militech's regional headquarters, leased from the COG for 1eb a year; it looks small until you see the elevator panel.

```world locations.locations.norcal_military_base_9
{
	"name": "Militech Offices",
	"district": "norcal_military_base",
	"number": 9,
	"type": "corp_hq",
	"owner": "militech",
	"owner_name": "Militech (Pacifica Confederation HQ)",
	"security_code": {
		"n": 10,
		"faction": "militech",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The modest seven-storey tower's elevators list twenty sublevels; what is down there is guesswork.",
			"gigs": [
				"data_theft",
				"sabotage"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage",
		"corp_extraction"
	],
	"interior": "Seven floors above ground, twenty sublevels below; said to hold conference suites, rec rooms, infirmaries, cafeterias, firing ranges, an auditorium, a war room, a Tech lab, an AV garage and security suites, with heavy security on every floor. Visitors meet in a separate building with a showroom inside the Mary E. Walker Street gate; MP checkpoint onward into the base.",
	"cite": "NC2045 p.183"
}
```

### #10 Motor Pool

Where the 223rd keeps its armour and power-armour, assembled piecemeal like the air fleet.

```world locations.locations.norcal_military_base_10
{
	"name": "Motor Pool",
	"district": "norcal_military_base",
	"number": 10,
	"type": "military",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG, 223rd Battalion",
	"security_code": {
		"n": 11,
		"faction": "norcal_cog_military_police",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage"
	],
	"interior": "Vast vehicle depot: MT-4 tanks, Behemoth APCs, captured Arasaka Combat 10s and a squad of new Militech Commando ACPA suits; mechanics also fix residents' cars for a small fee.",
	"cite": "NC2045 p.183"
}
```

### #11 The Oaks

The residential quarter where most of the base lives, sorted strictly by rank and family status.

```world locations.locations.norcal_military_base_11
{
	"name": "The Oaks",
	"district": "norcal_military_base",
	"number": 11,
	"type": "housing",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG",
	"security_code": {
		"n": 9,
		"faction": "norcal_cog_military_police",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"General Ash Giovanni (Exec 7/Solo 6)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Co-ed group barracks of 10-100 for recruits and single enlisted; UOQ blocks of cube rooms and studios for single officers; 1-2 bedroom family apartments; free-standing houses for senior officers, the General's the biggest.",
	"cite": "NC2045 p.183"
}
```

### #12 Parade Ground

Drill field by day, picnic park the rest of the time.

```world locations.locations.norcal_military_base_12
{
	"name": "Parade Ground",
	"district": "norcal_military_base",
	"number": 12,
	"type": "park",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG",
	"security_code": {
		"n": 9,
		"faction": "norcal_cog_military_police",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Biotechnica Realgrass drill field with a non-denominational chapel at the east end, a firing range at the west end and a bandstand in the middle.",
	"cite": "NC2045 p.184"
}
```

### #13 The Potentilla

Command centre of the COG's four forces.

```world locations.locations.norcal_military_base_13
{
	"name": "The Potentilla",
	"district": "norcal_military_base",
	"number": 13,
	"type": "military",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG",
	"security_code": {
		"n": 11,
		"faction": "norcal_cog_military_police",
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
	"interior": "Five buildings set like petals around a courtyard memorial columbarium: HQs for Task Force 384, the 157th, the 223rd and the 120.8th, and a fifth for smaller units including military intelligence and drone operations; fortified and able to sink underground.",
	"cite": "NC2045 p.184"
}
```

### #14 Post Exchange (PX)

The only shop on base, and the nearest thing in Night City to a big-box store.

```world locations.locations.norcal_military_base_14
{
	"name": "Post Exchange (PX)",
	"district": "norcal_military_base",
	"number": 14,
	"type": "shop",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG",
	"security_code": {
		"n": 9,
		"faction": "norcal_cog_military_police",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Casey Thayer (Solo 2)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Big-box store selling groceries, firearms, media, clothes and electronics; Hot Dingo snack bar, Estero Bay Barber Shop and COG Credit Union at the front.",
	"cite": "NC2045 p.184"
}
```

### #15 The Rec Center

The base's entertainment block, run by the Community Services Officer.

```world locations.locations.norcal_military_base_15
{
	"name": "The Rec Center",
	"district": "norcal_military_base",
	"number": 15,
	"type": "venue",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG",
	"security_code": {
		"n": 9,
		"faction": "norcal_cog_military_police",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Major Herbert \"Showtime\" Brooks (Exec 5)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Bowling on the first floor, arcade and gym on the second, mini-golf and cinema on the third; reconfigurable Techgrass sports field outside.",
	"cite": "NC2045 p.184"
}
```

### #16 Task Force 384 Docks

Home port of the COG navy, which hunts pirates and leftover 4CW mines along the NorCal coast.

```world locations.locations.norcal_military_base_16
{
	"name": "Task Force 384 Docks",
	"district": "norcal_military_base",
	"number": 16,
	"type": "docks",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG, Task Force 384",
	"security_code": {
		"n": 11,
		"faction": "norcal_cog_military_police",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"sabotage"
	],
	"interior": "Berths for the carrier NCS John F. Kennedy (kept as a training centre with Militech instructors), the cruisers Ticonderoga and Washington, and coastal subs, minehunters and littoral combat ships.",
	"cite": "NC2045 p.184"
}
```

### #17 USO Hall

The base's social hall; the name is a leftover from US days.

```world locations.locations.norcal_military_base_17
{
	"name": "USO Hall",
	"district": "norcal_military_base",
	"number": 17,
	"type": "bar",
	"owner": "estero_bay_military_cog",
	"owner_name": "Estero Bay Military COG",
	"security_code": {
		"n": 7,
		"faction": "norcal_cog_military_police",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Major Herbert \"Showtime\" Brooks (Exec 5)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Two clubs: the larger Enlisted Club, nicknamed the Relief Valve, with drinks and dancing (MPs drop by to break up fights), and the quieter Officers' Club with better food and liquor.",
	"cite": "NC2045 p.185"
}
```

## Fixers

- Corporal Walt Henshaw (Fixer 4) — base supply clerk; quietly supplies residents with recreational drugs through his Piranhas contacts (NC2045 p.185).

## Personalities

- General Ash Giovanni (Exec 7/Solo 6) — Base Commander and City Manager; rose from private to three stars, kept sharp by neural implants and a custom linear frame (p.179).
- Captain Jennifer Quick (Lawman 9) — commands the base MPs; tolerant of rowdiness, merciless with crime, and always on the firing squad (p.185).
- Casey Thayer (Solo 2) — teenage PX clerk trained for artillery who dreams of playing for the Night City Slammers (p.185).
- Corporal Walt Henshaw (Fixer 4) — supply clerk and the base's off-the-books drug source via the Piranhas (p.185).
- Major Herbert "Showtime" Brooks (Exec 5) — Community Services Officer over the USO Hall and Rec Center; film buff lobbying Colonial Studios' CEO for a new war epic (p.185).
