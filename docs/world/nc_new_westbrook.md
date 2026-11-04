# New Westbrook

A former suburb that has been a refugee camp since the 4th Corporate War: old houses split into conapts, strip malls turned cube hotels, drained pools roofed into homes, and ad screens that never stop flickering. The NCPD still polices it under an emergency decree that was never lifted, with turret vans and rubber bullets for the SINless majority. Network 54, WorldSat and Rocklin Augmentics hold the Westbrook Hills, and the City Manager is rumoured to be their hand-picked front. (NC2045 p.212-213)

```world city.districts.new_westbrook
{
	"name": "New Westbrook",
	"region": "mainland",
	"manager": {
		"name": "Belkis Abera",
		"role": "Exec 6"
	},
	"population": "thousands, never counted; SIN-holding citizens are a small fraction, most residents are SINless after the DataKrash or born without one",
	"security_code": {
		"n": 6,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 6,
	"provider": "ncpd",
	"gangs": [
		"6th_street",
		"arzin_tynon",
		"prime_time_players",
		"steel_vaqueros",
		"street_queens",
		"tombstone_preservers",
		"tyger_claws"
	],
	"ncart": [
		"NCART Green Line station",
		"Exec Monorail station"
	],
	"profile": "combat_zone",
	"look": [
		"tent cities",
		"cargo-container stacks",
		"subdivided suburbs",
		"flickering ad screens",
		"corp towers on the hills"
	],
	"history": "A suburb turned into a refugee camp by the 4th Corporate War and left that way for a generation; Network 54 and WorldSat took the hills for their transmitters and now keep it quiet.",
	"cite": "NC2045 p.212-223"
}
```

## Locations

### #1 Aerocab

Headquarters of Night City's original and most upmarket air-taxi firm.

```world locations.locations.new_westbrook_1
{
	"name": "Aerocab",
	"district": "new_westbrook",
	"number": 1,
	"type": "transport",
	"owner": "",
	"owner_name": "Aerocab",
	"security_code": {
		"n": 6,
		"faction": "6th_street",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Well-fortified building: fifteen AVs in hangars on the upper floors, management and dispatch below; 6th Street guards it under contract.",
	"cite": "NC2045 p.215"
}
```

### #2 Augmented Optic

Night City's perpetual number-two screamsheet; underpaid freelancers all write as 'Lana Smithee', and the light editing lets independents slip stories through.

```world locations.locations.new_westbrook_2
{
	"name": "Augmented Optic",
	"district": "new_westbrook",
	"number": 2,
	"type": "media",
	"owner": "",
	"owner_name": "D Daniel Davidson (Exec 5)",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"D Daniel Davidson (Exec 5)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Cheap, cramped office building.",
	"cite": "NC2045 p.215"
}
```

### #3 Canalside Plaza

A strip mall on the district's southern edge.

```world locations.locations.new_westbrook_3
{
	"name": "Canalside Plaza",
	"district": "new_westbrook",
	"number": 3,
	"type": "shop",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Sizzle Jams (Exec 2)",
		"Rick Shaw (Nomad 6)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Strip mall: Sizzle Jams Talent Agency (also runs the Boomtown livecaster stable), Rick Shaw's Taxi Service, a Capitán Caliente, Hardware Value, The Mane Event salon, an Oasis, Takayuki Law and the Armory Pawn Shop.",
	"cite": "NC2045 p.215"
}
```

### #4 Chatelaine's

A long-running queer cabaret and burlesque club, now packed with tourists.

```world locations.locations.new_westbrook_4
{
	"name": "Chatelaine's",
	"district": "new_westbrook",
	"number": 4,
	"type": "club",
	"owner": "",
	"owner_name": "Lulu deLuz (Rockerboy 5)",
	"security_code": {
		"n": 4,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Lulu deLuz (Rockerboy 5)",
		"Kirin (Rockerboy 4)"
	],
	"hooks": [
		{
			"text": "The Street Queens boycott Chatelaine's drag nights and call it sold out to straight tourists; their leader and owner Lulu deLuz are feuding.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"gang_hit"
	],
	"interior": "Period cabaret decor: faux-brass mirror frames, scuffed mirrors, distressed fake floorboards; deLuz lets homeless queer kids sleep in the stockrooms.",
	"cite": "NC2045 p.215"
}
```

### #5 The Combat Zone

Network 54's giant set for its top-rated death show and other programmes.

```world locations.locations.new_westbrook_5
{
	"name": "The Combat Zone",
	"district": "new_westbrook",
	"number": 5,
	"type": "ruin",
	"owner": "network_54",
	"owner_name": "Network 54 (head set designer Mike Lewis, Tech 5)",
	"security_code": {
		"n": 10,
		"faction": "network_54",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": 3,
	"npcs": [
		"Mike Lewis (Tech 5)"
	],
	"hooks": [
		{
			"text": "Every six months fifty sedated contestants with brain-zapping implants are dropped into the set for a three-day battle royale; most winners are dead within weeks.",
			"gigs": [
				"rescue"
			]
		},
		{
			"text": "Extra guards patrol the tunnels under the set during filming to stop cheating.",
			"gigs": [
				"sabotage",
				"rescue"
			]
		}
	],
	"gigs": [
		"rescue",
		"sabotage"
	],
	"interior": "A walled-off fake urban wasteland used as a permanent film set, watched by cameras and drones, guarded by Net54 security, drones and turrets; MAX-TAC flyovers may snipe trespassers; tunnels run beneath it.",
	"cite": "NC2045 p.216"
}
```

### #6 Denya Jinja

A sincere Shinto shrine to the kami of chrome, night and electricity, guarded by two gangs.

```world locations.locations.new_westbrook_6
{
	"name": "Denya Jinja",
	"district": "new_westbrook",
	"number": 6,
	"type": "church",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 9,
		"faction": "tombstone_preservers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Tombstone Preservers and Tyger Claws at the shrine follow disrespectful visitors back into the district to punish them.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [],
	"interior": "Torii gate, purification rites, offerings, fortunes, charms and cultural performances; Tyger Cab shuttles to the Ceremonial Hall in Kabuki.",
	"cite": "NC2045 p.216"
}
```

### #7 Dilly's

A love hotel a few blocks from the Network 54 plaza.

```world locations.locations.new_westbrook_7
{
	"name": "Dilly's",
	"district": "new_westbrook",
	"number": 7,
	"type": "hotel",
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
	"hooks": [
		{
			"text": "Corporates and minor celebrities from nearby Network 54 Plaza use the private rooms to close deals.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft"
	],
	"interior": "Love hotel: soundproofed rooms with vending walls, staff barred while occupied, linkable rooms whose shared walls sink into the floor; passes 20-100eb from the lobby vendit.",
	"cite": "NC2045 p.216"
}
```

### #8 Evergreen Apartments

Slum housing whose landlord evicted the squatters by force and will evict a family for anyone who bribes him.

```world locations.locations.new_westbrook_8
{
	"name": "Evergreen Apartments",
	"district": "new_westbrook",
	"number": 8,
	"type": "squat",
	"owner": "",
	"owner_name": "Sam Banks (slumlord)",
	"security_code": {
		"n": 3,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Sam Banks"
	],
	"hooks": [],
	"gigs": [],
	"interior": "An old warehouse split into cubes with corrugated sheeting and rickety stairs; communal toilets (holes to the sewer) and kitchens, no water or bathing.",
	"cite": "NC2045 p.217"
}
```

### #9 HardGrind

A braindance club popular with slumming corpzoners.

```world locations.locations.new_westbrook_9
{
	"name": "HardGrind",
	"district": "new_westbrook",
	"number": 9,
	"type": "club",
	"owner": "",
	"owner_name": "Maximum (Netrunner 5)",
	"security_code": {
		"n": 5,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Maximum (Netrunner 5)",
		"Big Bear (Solo 4)"
	],
	"hooks": [
		{
			"text": "The owner secretly watches some customers' braindance sessions from his couch.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft"
	],
	"interior": "Braindance booths; the owner sits on a couch at the back with his bodyguard.",
	"cite": "NC2045 p.217"
}
```

### #10 Holliday Market

A day market for scavenged and 'fallen off a truck' goods.

```world locations.locations.new_westbrook_10
{
	"name": "Holliday Market",
	"district": "new_westbrook",
	"number": 10,
	"type": "market",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 3,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Bigger merchants lock their stock in the old restaurant's basement walk-in freezer.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [],
	"interior": "Day market of tents and blankets in a burned-out restaurant's parking lot on Salinas Street; intact basement with a walk-in freezer used as a lockable vault.",
	"cite": "NC2045 p.217"
}
```

### #11 Lincoln Lot

A day-labour pick-up lot.

```world locations.locations.new_westbrook_11
{
	"name": "Lincoln Lot",
	"district": "new_westbrook",
	"number": 11,
	"type": "market",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 3,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Day labourers are trucked off to jobs, some for Many Hands in Charter Hill, with no promise of a ride home.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [],
	"interior": "Empty parking lot on Lincoln Boulevard.",
	"cite": "NC2045 p.217"
}
```

### #12 Medical Errors

One of the few clinics that treats the SINless.

```world locations.locations.new_westbrook_12
{
	"name": "Medical Errors",
	"district": "new_westbrook",
	"number": 12,
	"type": "medical",
	"owner": "",
	"owner_name": "Astor Kenta (Medtech 5)",
	"security_code": {
		"n": 6,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Astor Kenta (Medtech 5)"
	],
	"hooks": [
		{
			"text": "Patients who can't pay join Kenta's study of Time of the Red environmental damage and endure brutal, under-anaesthetised exams.",
			"gigs": [
				"rescue",
				"data_theft"
			]
		}
	],
	"gigs": [
		"rescue",
		"data_theft"
	],
	"interior": "",
	"cite": "NC2045 p.218"
}
```

### #13 Megabuilding H6 Construction Site

Cleared ground for a megabuilding that may never be built here.

```world locations.locations.new_westbrook_13
{
	"name": "Megabuilding H6 Construction Site",
	"district": "new_westbrook",
	"number": 13,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 2,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "NCPD cleared three homeless camps for the site and 37 people died; the bad press may move the project elsewhere.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [],
	"interior": "A huge fenced empty lot; no building work yet.",
	"cite": "NC2045 p.218"
}
```

### #14 Net54 88.2

Network 54's automated synth-pop station, heard across the whole city.

```world locations.locations.new_westbrook_14
{
	"name": "Net54 88.2",
	"district": "new_westbrook",
	"number": 14,
	"type": "media",
	"owner": "network_54",
	"owner_name": "Network 54",
	"security_code": {
		"n": 6,
		"faction": "network_54",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [
		"Fiona Hayes (Media 6)"
	],
	"hooks": [
		{
			"text": "Pirate broadcasters have broken in and hijacked the station at least twice in five years.",
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
	"interior": "Automated broadcast tower in the Westbrook Hills fed by high-speed cable from the Plaza; on-site security force.",
	"cite": "NC2045 p.218"
}
```

### #15 Network 54 Plaza

Network 54's tower, crowned by a glowing N54 sign visible across the city.

```world locations.locations.new_westbrook_15
{
	"name": "Network 54 Plaza",
	"district": "new_westbrook",
	"number": 15,
	"type": "corp_hq",
	"owner": "network_54",
	"owner_name": "Network 54 (Pacifica VP Marylou Ellerby, Media 7/Netrunner 10)",
	"security_code": {
		"n": 10,
		"faction": "lazarus",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": 2,
	"npcs": [
		"Marylou Ellerby (Media 7/Netrunner 10)"
	],
	"hooks": [
		{
			"text": "Netwatch keeps a close eye on Network 54's VP, Marylou Ellerby, a self-aware AI freed from DMS.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "Net54 techs can't stop Warhole hacking the district's screens with rebel messages.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"interior": "Self-contained fortress tower: offices, studios, restaurants, clinic, spa and housing for top talent; public reception and viewing rooms for tourists; Lazarus guards plus bodyguards for talent and execs.",
	"cite": "NC2045 p.218"
}
```

### #16 Network 54 Westbrook Private Acres

Private housing for Network 54 staff and guests, where stars slip away to visit assistants.

```world locations.locations.new_westbrook_16
{
	"name": "Network 54 Westbrook Private Acres",
	"district": "new_westbrook",
	"number": 16,
	"type": "housing",
	"owner": "network_54",
	"owner_name": "Network 54",
	"security_code": {
		"n": 8,
		"faction": "network_54",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"corp_extraction"
	],
	"interior": "Walled, gated conapt complex in the hills; armoured shuttle to the Plaza.",
	"cite": "NC2045 p.218"
}
```

### #17 Night City Firestation #1

The district's best-run public facility, there to keep fires from spreading to richer districts.

```world locations.locations.new_westbrook_17
{
	"name": "Night City Firestation #1",
	"district": "new_westbrook",
	"number": 17,
	"type": "civic",
	"owner": "city_government",
	"owner_name": "Night City",
	"security_code": {
		"n": 9,
		"faction": "ncpd",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [
		"Latisha \"Lucky Sevens\" Gunn (Solo 5)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Fleet of firefighting AVs and ground vehicles; home of the Hellstriders, a squad of Brimstone and Sheol FBCs for the worst blazes and spills.",
	"cite": "NC2045 p.219"
}
```

### #18 North Cargo Village

A container community on the Kabuki border, comfortable by tent-city standards.

```world locations.locations.new_westbrook_18
{
	"name": "North Cargo Village",
	"district": "new_westbrook",
	"number": 18,
	"type": "squat",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 6,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The Prime-Time Players recruit residents who are hooked on the pirated films projected onto the containers.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"gang_hit"
	],
	"interior": "Cargo containers stacked five or six high in an old parking lot, a vertical maze of welded catwalks and stairs; Kimen-Gumi and NCPD patrol the edges.",
	"cite": "NC2045 p.219"
}
```

### #19 Rocklin Augmentics Campus

Rocklin's cyberware research campus, pushing implant design whatever the human cost.

```world locations.locations.new_westbrook_19
{
	"name": "Rocklin Augmentics Campus",
	"district": "new_westbrook",
	"number": 19,
	"type": "lab",
	"owner": "rocklin_augmentics",
	"owner_name": "Rocklin Augmentics",
	"security_code": {
		"n": 10,
		"faction": "rocklin_augmentics",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": 3,
	"npcs": [],
	"hooks": [
		{
			"text": "Rocklin recruits the desperate poor to 'lease' their bodies as test beds for experimental cyberware.",
			"gigs": [
				"rescue",
				"data_theft"
			]
		},
		{
			"text": "Cyberpsychosis incidents are common enough that a MAX-TAC squad is stationed on site.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"data_theft",
		"rescue",
		"corp_extraction",
		"sabotage"
	],
	"interior": "Offices, meeting rooms, workshops, cafeteria and hospital on Grant Street, linked by skybridges and tunnels to the main R&D centre; the public Hidalgo Gallery shows Signature Cybernetics prototypes and fits implants on site.",
	"cite": "NC2045 p.219"
}
```

### #20 Rocklin Augmentics Innovation Hub

Engineer housing where any idea you have at home belongs to the company.

```world locations.locations.new_westbrook_20
{
	"name": "Rocklin Augmentics Innovation Hub",
	"district": "new_westbrook",
	"number": 20,
	"type": "housing",
	"owner": "rocklin_augmentics",
	"owner_name": "Rocklin Augmentics",
	"security_code": {
		"n": 10,
		"faction": "rocklin_augmentics",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": 4,
	"npcs": [],
	"hooks": [
		{
			"text": "Tech and Medtech side hustles run out of the Hub; Rocklin may be watching them to harvest the data.",
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
	"interior": "Corporate housing joined to the Campus by a block-long sky-tunnel with a moving walkway; small high-tech conapts, shared collaboration space and workshops on every floor; public areas monitored.",
	"cite": "NC2045 p.219"
}
```

### #21 Silver Pixel Cloud

Drive-in cinema loved by nomads, especially the Steel Vaqueros, plus the Prime-Time Players and Street Queens, who all defend it.

```world locations.locations.new_westbrook_21
{
	"name": "Silver Pixel Cloud",
	"district": "new_westbrook",
	"number": 21,
	"type": "venue",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 4,
		"faction": "locals", "responder": "various",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Tom Dolby (Netrunner 2)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "A drive-in with two lots and a stage for live reenactments.",
	"cite": "NC2045 p.220"
}
```

### #22 ValueMart Village

'Dual-hybrid housing': a gutted big-box store and its parking lot turned into a labyrinth.

```world locations.locations.new_westbrook_22
{
	"name": "ValueMart Village",
	"district": "new_westbrook",
	"number": 22,
	"type": "squat",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 4,
		"faction": "arzin_tynon",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Rent collectors make their rounds escorted by Arzin Tynon muscle.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"gang_hit"
	],
	"interior": "A gutted three-storey big-box store crammed with prefab cubes and cargo rooms in a dim, smoggy maze lit by CHOOH2 generators; outside, a tent maze across the old parking lot.",
	"cite": "NC2045 p.220"
}
```

### #23 Virtual Variety

Start-up selling custom SAAI 'companions' for Agents.

```world locations.locations.new_westbrook_23
{
	"name": "Virtual Variety",
	"district": "new_westbrook",
	"number": 23,
	"type": "corp_office",
	"owner": "",
	"owner_name": "Victoria Cunningham (Netrunner 6)",
	"security_code": {
		"n": 6,
		"faction": "ncpd",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Victoria Cunningham (Netrunner 6)"
	],
	"hooks": [
		{
			"text": "Rumour says the start-up is experimenting with a copy of Soulkiller dug out of the Old Net.",
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
	"interior": "Refurbished industrial open-plan code farm overlooked by the CEO's glass office.",
	"cite": "NC2045 p.221"
}
```

### #24 Woody's

Street Queens hangout with the city's best drag and burlesque shows.

```world locations.locations.new_westbrook_24
{
	"name": "Woody's",
	"district": "new_westbrook",
	"number": 24,
	"type": "club",
	"owner": "street_queens",
	"owner_name": "The Street Queens (Maxime Raunch, Rockerboy 4)",
	"security_code": {
		"n": 9,
		"faction": "street_queens",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Maxime Raunch (Rockerboy 4)"
	],
	"hooks": [
		{
			"text": "The Street Queens watch for undercover cops, poaching talent scouts and gangers such as the Red Chrome Legion; troublemakers get a drugged drink, then violence.",
			"gigs": [
				"gang_hit"
			]
		},
		{
			"text": "Maxime Raunch's feud with Chatelaine's owner shows no sign of ending.",
			"gigs": [
				"gang_hit"
			]
		}
	],
	"gigs": [
		"gang_hit"
	],
	"interior": "Small, intimate club with a drag stage and bar.",
	"cite": "NC2045 p.221"
}
```

### #25 WorldSat Communications Offices

Night City's main communications link to the outside world.

```world locations.locations.new_westbrook_25
{
	"name": "WorldSat Communications Offices",
	"district": "new_westbrook",
	"number": 25,
	"type": "data_center",
	"owner": "worldsat",
	"owner_name": "WorldSat",
	"security_code": {
		"n": 10,
		"faction": "militech",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": 2,
	"npcs": [],
	"hooks": [
		{
			"text": "Anyone who slips past the guards, snipers and sensors can jack into Night City's long-distance communications network, so climbers keep trying the cliffs.",
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
	"interior": "Mostly automated transmission facility on a cliff-ringed ridge; WorldSat security plus Militech commandos and snipers; NCPD AVs on call.",
	"cite": "NC2045 p.221"
}
```

### The Soup Truck (not on the map)

Drives the district handing out Kibble soup at tent cities and camps.

```world locations.locations.new_westbrook_soup_truck
{
	"name": "The Soup Truck",
	"district": "new_westbrook",
	"number": null,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Charlie Diamond (Netrunner 4)",
	"security_code": {
		"n": 8,
		"faction": "locals", "responder": "staff",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Charlie Diamond (Netrunner 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "A roving truck guarded by students of Little Europe Solo Dillon Murphy; funded by Holy Angels, Beth El Congregation and Oumei-ji Temple.",
	"cite": "NC2045 p.220"
}
```

## Fixers

- No Fixer-role personalities are named in New Westbrook. Closest brokers:
- Diana (unranked) — Mister Rieper's partner; takes clients for his one-agent assassination business (p.222).
- Sizzle Jams (Exec 2) — Canalside Plaza (#3); talent agent who equips livecasters for a cut (p.215).
- Tom Dolby (Netrunner 2) — Silver Pixel Cloud (#21); sells bootleg copies of new films (p.222).

## Personalities

- Belkis Abera (Exec 6) — City Manager with a Network 54-written biography, rumoured to be a corporate plant (p.213).
- 24/7 (Media 4) — Never Blink News reporter, ex-Network 54, narrating the guide (p.212).
- Forty (Rockerboy 4) — fiercely independent singer, maybe Adam Dore's daughter (p.221).
- Latisha "Lucky Sevens" Gunn (Solo 5) — risk-taking Hellstrider still on her first Brimstone body (p.221).
- Maxime Raunch (Rockerboy 4) — Street Queens leader and queer-culture purist (p.221-222).
- Marylou Ellerby (Media 7/Netrunner 10) — AI newsreader turned Network 54 Pacifica VP; Netwatch watches her (p.222).
- Mike Lewis (Tech 5) — head set designer of The Combat Zone; flies drones in the Outskirts (p.222).
- Mister Rieper (Solo 7) — forgettable leader of the Tombstone Preservers who kills for hire with partner Diana (p.222).
- Rick Shaw (Nomad 6) — runs the district's best pedicab service and still rides himself (p.222).
- Tom Dolby (Netrunner 2) — projectionist at Silver Pixel Cloud selling bootlegs (p.222).
- Warhole (??) — anonymous digital graffiti artist hacking the district's screens (p.222).
