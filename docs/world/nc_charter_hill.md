# Charter Hill

Charter Hill wraps around the Executive Zone and houses the managers who hope to move inside its walls one day.
Over the past ten years the comfortable-but-not-elite took a slice of New Westbrook and rebuilt it as a
suburb of identical houses and fake lawns. Militech is paid to keep the poor and the gangs out: patrols stop and
search outsiders, while residents are waved through. The City Manager, Symon Featherstonehaugh (no Role printed),
is a former City Hall clerk who bends to whoever bribed him last (NC2045 p.224-225).

```world city.districts.charter_hill
{
	"name": "Charter Hill",
	"region": "mainland",
	"manager": {
		"name": "Symon Featherstonehaugh",
		"role": ""
	},
	"population": "up-and-coming management-track execs and their families; menial staff are bussed in daily",
	"security_code": {
		"n": 9,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": 3,
	"provider": "militech",
	"gangs": [
		"inquisitors",
		"tombstone_preservers",
		"philharmonic_vampyres",
		"bozos",
		"prime_time_players"
	],
	"ncart": [
		"Charter Hill Station (Green Line)",
		"Charter Hill Station (Executive Monorail)"
	],
	"profile": "executive_zone",
	"look": [
		"suburban lawns",
		"cookie-cutter houses",
		"clean streets",
		"corporate patrols",
		"view of the Exec Zone walls"
	],
	"history": "Carved out of New Westbrook over the last decade by the merely wealthy; the new City Manager imports labour through a firm he part-owns.",
	"cite": "NC2045 p.224-231"
}
```

## Locations

### #1 92.9 Night FM

A dance-music radio station in an old substation overlooking the Executive Zone; its news director runs an open tip line.

```world locations.locations.charter_hill_1
{
	"name": "92.9 Night FM",
	"district": "charter_hill",
	"number": 1,
	"type": "media",
	"owner": "",
	"owner_name": "Vince \"Visible\" Mann (Exec 3)",
	"security_code": {
		"n": 6,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Vince \"Visible\" Mann (Exec 3)",
		"Genesis Toast (Rockerboy 4)",
		"Teddy Bernard (Media 4)"
	],
	"hooks": [
		{
			"text": "The station's newsroom tip line takes leaked data and promises to chase the story.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"data_theft"
	],
	"interior": "A decommissioned electrical substation on a quake-cracked hilltop, topped with a neon-lit aerial.",
	"cite": "NC2045 p.225"
}
```

### #2 Anjelika's

A host bar for cyberware and robot-romance fans, its staff sculpted to pass as androids. Star host Gavin has ripperdoc and full-body-conversion contacts.

```world locations.locations.charter_hill_2
{
	"name": "Anjelika's",
	"district": "charter_hill",
	"number": 2,
	"type": "bar",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 9,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Gavin (Rockerboy 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Host and hostess bar whose staff are bodysculpted to look like androids; booking a host has a months-long wait.",
	"cite": "NC2045 p.225"
}
```

### #3 Bella Mia

An ultra-fashionable club that doubles as a launch venue for model Velvet Lux's clothing label.

```world locations.locations.charter_hill_3
{
	"name": "Bella Mia",
	"district": "charter_hill",
	"number": 3,
	"type": "club",
	"owner": "",
	"owner_name": "Velvet Lux (Rockerboy 8)",
	"security_code": {
		"n": 9,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Velvet Lux (Rockerboy 8)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Bouncers chipped to judge fashion turn away the badly dressed; staff model the owner's next collection.",
	"cite": "NC2045 p.227"
}
```

### #4 Charter Hill Museum of All Art

An upmarket art museum stocked from wealthy collectors' vaults, curated by a high-rank fixer and guarded by Lazarus specialists. Entry is 100eb.

```world locations.locations.charter_hill_4
{
	"name": "Charter Hill Museum of All Art",
	"district": "charter_hill",
	"number": 4,
	"type": "venue",
	"owner": "",
	"owner_name": "Johnathan Downey (Fixer 8), curator",
	"security_code": {
		"n": 9,
		"faction": "lazarus",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Johnathan Downey (Fixer 8)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Four floors of art loaned from rich collectors' vaults; every visitor is scanned and anything usable for theft or damage is locked away at the door; Lazarus guards.",
	"cite": "NC2045 p.227"
}
```

### #5 Checkpoint Lincoln

The joint Militech/Lazarus checkpoint guarding the tunnel into the Executive Zone, with Militech's local command bunker beside it.

```world locations.locations.charter_hill_5
{
	"name": "Checkpoint Lincoln",
	"district": "charter_hill",
	"number": 5,
	"type": "military",
	"owner": "militech",
	"owner_name": "Militech (with Lazarus)",
	"security_code": {
		"n": 10,
		"faction": "militech",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Captain Rick Castor (Exec 5)"
	],
	"hooks": [],
	"gigs": [
		"sabotage"
	],
	"interior": "Tunnel mouth into the Executive Zone at the end of Lincoln Blvd: two anti-tank turrets, snipers, a drive-through vehicle scanner and Biotechnica security canines (joint Militech/Lazarus crew). Beside it, a concrete cube bunker serves as Militech's command post and barracks, and is noticeably less well guarded.",
	"cite": "NC2045 p.227"
}
```

### #6 Colonial Studios

A braindance studio that rebuilt itself in a smaller Charter Hill lot after the war; it makes serial BDs and is now gambling on a classic-film remake.

```world locations.locations.charter_hill_6
{
	"name": "Colonial Studios",
	"district": "charter_hill",
	"number": 6,
	"type": "media",
	"owner": "",
	"owner_name": "Magretta Cippolina (Exec 4/Fixer 5)",
	"security_code": {
		"n": 9,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Magretta Cippolina (Exec 4/Fixer 5)",
		"Renu Upadhyayula (Tech 4)"
	],
	"hooks": [
		{
			"text": "BD editor Renu Upadhyayula quietly lets Tech friends in after hours to use the studio's editing rigs.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "Freshly out of debt, the studio is betting big on remaking the president's father's classic film.",
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
	"interior": "One building of sound stages, a back lot, prop and scenery warehousing and a post-production suite.",
	"cite": "NC2045 p.227"
}
```

### #7 The Columbarium

Night Corp's memorial of steel niches for the city's cremated dead (burial is banned). The Tombstone Preservers guard it around the clock.

```world locations.locations.charter_hill_7
{
	"name": "The Columbarium",
	"district": "charter_hill",
	"number": 7,
	"type": "church",
	"owner": "tombstone_preservers",
	"owner_name": "built by Night Corp; kept by the Tombstone Preservers",
	"security_code": {
		"n": 10,
		"faction": "tombstone_preservers",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"gang_hit"
	],
	"interior": "Several columbarium buildings of labelled steel niche drawers; unclaimed remains go to an unmarked columbarium on the far side. The gang patrols day and night.",
	"cite": "NC2045 p.228"
}
```

### #8 DRGS 247

The newest and most profitable branch of a performance-drug chain co-owned by Biotechnica and Trauma Team.

```world locations.locations.charter_hill_8
{
	"name": "DRGS 247",
	"district": "charter_hill",
	"number": 8,
	"type": "shop",
	"owner": "biotechnica",
	"owner_name": "Biotechnica & Trauma Team (joint chain)",
	"security_code": {
		"n": 8,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Donna Mixer (Medtech 3/Tech 3)"
	],
	"hooks": [
		{
			"text": "Pharmacist Donna Mixer sells hard-to-trace poisons to corporate clients who want rivals quietly retired.",
			"gigs": [
				"assassination"
			]
		}
	],
	"gigs": [
		"assassination"
	],
	"interior": "",
	"cite": "NC2045 p.228"
}
```

### #9 Eye of the Tiger

A laser-tag arena where execs play at combat without risk.

```world locations.locations.charter_hill_9
{
	"name": "Eye of the Tiger",
	"district": "charter_hill",
	"number": 9,
	"type": "venue",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 8,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Laser-tag arena for team-building and parties.",
	"cite": "NC2045 p.228"
}
```

### #10 The Flow Megachurch

A prosperity-gospel megachurch selling tithes and coaching courses to junior execs.

```world locations.locations.charter_hill_10
{
	"name": "The Flow Megachurch",
	"district": "charter_hill",
	"number": 10,
	"type": "church",
	"owner": "",
	"owner_name": "Pastor Roger Joel Chandler (Rockerboy 7)",
	"security_code": {
		"n": 9,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Pastor Roger Joel Chandler (Rockerboy 7)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Megachurch that broadcasts sermons around the clock on its own radio station and Garden Patch.",
	"cite": "NC2045 p.228"
}
```

### #11 Hillside Country Club

The consolation-prize country club for those who can't get into the Executive Zone's.

```world locations.locations.charter_hill_11
{
	"name": "Hillside Country Club",
	"district": "charter_hill",
	"number": 11,
	"type": "club",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 10,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Pool, sauna, gym, a driving range instead of a golf course, and the restaurant The Ladder.",
	"cite": "NC2045 p.228"
}
```

### #12 Hotel Muy Caro

A five-storey luxury hotel for visiting executives, owned by an actress turned investor and fixer.

```world locations.locations.charter_hill_12
{
	"name": "Hotel Muy Caro",
	"district": "charter_hill",
	"number": 12,
	"type": "hotel",
	"owner": "",
	"owner_name": "Carolina Albaz (Fixer 4/Rockerboy 4)",
	"security_code": {
		"n": 9,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Carolina Albaz (Fixer 4/Rockerboy 4)",
		"Glenn Crowe (valet)"
	],
	"hooks": [
		{
			"text": "For a fat bribe, valet Glenn Crowe hands over keys to a guest car from the underground lot and loses the footage, if it comes back quickly.",
			"gigs": [
				"corp_extraction"
			]
		},
		{
			"text": "Owner Carolina Albaz hires edgerunners to sabotage projects of companies competing with her investments.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage",
		"corp_extraction",
		"data_theft"
	],
	"interior": "Five floors: ground floor has four private conference rooms, a valuables vault and the restaurant Café Divine; sixteen doubles on floors 2-3; deluxe suites on 4-5; underground valet car park.",
	"cite": "NC2045 p.229"
}
```

### #13 L'Ermitage

Luxury pied-à-terre conapts for out-of-towners that can be sublet short-term; an AV pilot runs a rooftop taxi service.

```world locations.locations.charter_hill_13
{
	"name": "L'Ermitage",
	"district": "charter_hill",
	"number": 13,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 9,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Sanger Connell (Exec 4/Nomad 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Secure block of high-end two-bedroom conapts, mostly empty and staff-kept; short sublets need a 5,000eb deposit; a private AV taxi flies from the roof.",
	"cite": "NC2045 p.229"
}
```

### #14 Many Hands

The employment agency that trucks day labour into Charter Hill under the City Manager's worker initiative.

```world locations.locations.charter_hill_14
{
	"name": "Many Hands",
	"district": "charter_hill",
	"number": 14,
	"type": "corp_office",
	"owner": "",
	"owner_name": "Many Hands (City Manager Featherstonehaugh is majority shareholder)",
	"security_code": {
		"n": 8,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Lorenzo Moyle (Exec 2)"
	],
	"hooks": [
		{
			"text": "Many Hands won the district's labour-import contract without bidding while the City Manager holds most of its shares.",
			"gigs": [
				"data_theft"
			]
		},
		{
			"text": "Paid per head, recruiter Lorenzo Moyle barely checks who he brings in for a day's work in the district.",
			"gigs": [
				"sabotage",
				"data_theft"
			]
		},
		{
			"text": "The agency buys up the contracts of skilled prisoners from the Hall of Justice at bargain rates.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"data_theft",
		"sabotage",
		"rescue"
	],
	"interior": "Plain office; incoming workers are deloused, put in identifiable jumpsuits and chipped with locator beacons before transport to job sites.",
	"cite": "NC2045 p.229"
}
```

### #15 Seral Grove

A secret underground art-installation cemetery where the wealthy bury their dead illegally and chat with AI recreations of them.

```world locations.locations.charter_hill_15
{
	"name": "Seral Grove",
	"district": "charter_hill",
	"number": 15,
	"type": "data_center",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 6,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Rich families illegally inter their dead here and talk to AI copies of them; Netwatch would want whoever builds the personalities.",
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
	"interior": "Hidden underground neon cemetery-art space reached only by those in the know; holographic SAAI personalities of the dead run on secure on-site NET Architectures.",
	"cite": "NC2045 p.229"
}
```

### #16 Ward Security

A bodyguard agency for the moderately rich and famous; the owner trains every agent himself.

```world locations.locations.charter_hill_16
{
	"name": "Ward Security",
	"district": "charter_hill",
	"number": 16,
	"type": "corp_office",
	"owner": "ward_security",
	"owner_name": "Tim Ward (Exec 4/Solo 4)",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Tim Ward (Exec 4/Solo 4)"
	],
	"hooks": [
		{
			"text": "Ward fills out its bodyguard roster with edgerunners who can protect a client and make them look good.",
			"gigs": [
				"corp_extraction"
			]
		}
	],
	"gigs": [
		"corp_extraction"
	],
	"interior": "Compact office building on the district's south side.",
	"cite": "NC2045 p.230"
}
```

### #17 Your Neighborhood

The classic suburb, alive and well: identical houses for upper-middle managers waiting to move up.

```world locations.locations.charter_hill_17
{
	"name": "Your Neighborhood",
	"district": "charter_hill",
	"number": 17,
	"type": "villa",
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
	"hooks": [],
	"gigs": [],
	"interior": "Rows of near-identical houses with fake lawns under a strict Home Owners' Association.",
	"cite": "NC2045 p.230"
}
```

### #18 Your Next Big Crèche

A two-tier crèche; Militech guards it but contractually protects the premium kids first.

```world locations.locations.charter_hill_18
{
	"name": "Your Next Big Crèche",
	"district": "charter_hill",
	"number": 18,
	"type": "school",
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
	"hooks": [],
	"gigs": [],
	"interior": "Childcare for ages 0-7 in two tiers: cheap tier uses cryostasis pods and educational BDs with an hour in an enclosed courtyard; premium tier has live tutors and combat training. Militech guards on site protect premium children first.",
	"cite": "NC2045 p.230"
}
```

## Fixers

- Johnathan Downey (Fixer 8): curator of the Charter Hill Museum of All Art (#4); fine art and cyber-art from collectors' vaults (NC2045 p.227).
- Magretta Cippolina (Exec 4/Fixer 5): president of Colonial Studios (#6); braindance and film productions, acting careers (NC2045 p.227, p.230).
- Carolina Albaz (Fixer 4/Rockerboy 4): owner of Hotel Muy Caro (#12); investments, hires edgerunners to sabotage rival companies (NC2045 p.229-230).

## Personalities

- Teddy Bernard (Media 4): news director at 92.9 Night FM and the district's guide; runs the tip line (NC2045 p.224).
- Captain Rick Castor (Exec 5): petty, ambitious head of Charter Hill's Militech detachment, angling for promotion (NC2045 p.229).
- Carolina Albaz (Fixer 4/Rockerboy 4): ex-star actress turned market prodigy who pays runners to sink her investments' rivals (NC2045 p.229-230).
- Donna Mixer (Medtech 3/Tech 3): DRGS 247 pharmacist who boosts street drugs and sells subtle poisons to corp clients (NC2045 p.230).
- Gavin (Rockerboy 4): Anjelika's top host; knows reliable ripperdocs and FBC people, saving for a full-body conversion (NC2045 p.230).
- Glenn Crowe: Hotel Muy Caro valet who lends guests' cars and wipes footage for a bribe (NC2045 p.230).
- Lorenzo Moyle (Exec 2): Many Hands recruiter paid per head, not fussy about who he hires (NC2045 p.230).
- Magretta Cippolina (Exec 4/Fixer 5): Colonial Studios' film-buff president, often at the city's last indie cinemas (NC2045 p.230).
- Renu Upadhyayula (Tech 4): Colonial Studios BD editor who sneaks friends in to use the gear; refuses to touch XBDs (NC2045 p.230).
- Sanger Connell (Exec 4/Nomad 4): AV taxi pilot on L'Ermitage's roof who sells 500eb 'snipe hunts' shooting scavvers in the Hot Zone (NC2045 p.230).
