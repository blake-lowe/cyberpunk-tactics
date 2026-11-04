# Kabuki

A district built by and for Night City's Japanese-descended community after anti-Japanese violence drove them out of Japantown; Shinobu Nakagawa funded it, rallied the NCCS corps behind it and gave the orphaned Tyger Claws a new job as its guardians. It is one of the cleanest and richest districts, policed by the Claws' masked Kimen-Gumi, who protect locals from outside criminals but rarely touch Tyger Claws. Since the War of Succession the Claws, the Nakagawa Foundation and the NCCS have drifted apart, and a spark could start a war. (NC2045 p.200-201)

```world city.districts.kabuki
{
	"name": "Kabuki",
	"region": "northside",
	"manager": {
		"name": "Yoshiki Murakami",
		"role": "Fixer 6"
	},
	"population": "overwhelmingly Japanese-descended refugees from Japantown and their children; a third have never lived anywhere else",
	"security_code": {
		"n": 8,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": 2,
	"provider": "kimen_gumi",
	"gangs": [
		"tyger_claws",
		"g3"
	],
	"ncart": [],
	"profile": "market_streets",
	"look": [
		"clean streets",
		"Japanese signage",
		"neon",
		"lanterns and shrines",
		"kabuki theatre",
		"street-food market"
	],
	"history": "Founded by kabuki star Shinobu Nakagawa for Japantown refugees after the nuke, with NCCS corps and the Tyger Claws as patrons; his death in 2042 set off the bloody War of Succession.",
	"cite": "NC2045 p.200-209"
}
```

## Locations

### #1 100.0 G3 Gun-Gal Station

G3's anime-music radio station, with talk shows and J-Pop interviews.

```world locations.locations.kabuki_1
{
	"name": "100.0 G3 Gun-Gal Station",
	"district": "kabuki",
	"number": 1,
	"type": "media",
	"owner": "g3",
	"owner_name": "G3",
	"security_code": {
		"n": 9,
		"faction": "g3",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "G3 sell copies of a hoard of anime music chips they found in a forgotten Old Japantown bomb shelter.",
			"gigs": [
				"gang_hit",
				"data_theft"
			]
		}
	],
	"gigs": [
		"gang_hit"
	],
	"interior": "Radio station upstairs; The Cabbit café, a G3 hangout, on the ground floor.",
	"cite": "NC2045 p.203"
}
```

### #2 91.9 Royal Blue

A jazz station and studio founded by a pianist friend of the late Shinobu Nakagawa.

```world locations.locations.kabuki_2
{
	"name": "91.9 Royal Blue",
	"district": "kabuki",
	"number": 2,
	"type": "media",
	"owner": "",
	"owner_name": "Takako Aoyama (Rockerboy 5)",
	"security_code": {
		"n": 8,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Takako Aoyama (Rockerboy 5)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Music studio and radio station, with apartments in the same building where Aoyama houses orphans of the War of Succession.",
	"cite": "NC2045 p.203"
}
```

### #3 Animelocaris

Otaku goods and cosplay supplies; the owner gives G3 discounts in return for protection, mostly from G3 itself.

```world locations.locations.kabuki_3
{
	"name": "Animelocaris",
	"district": "kabuki",
	"number": 3,
	"type": "shop",
	"owner": "",
	"owner_name": "Tezuka",
	"security_code": {
		"n": 7,
		"faction": "g3",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Tezuka"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.203"
}
```

### #4 Cyborg Station

A cyberware tuning workshop whose master pushes implants far beyond spec; edgerunners come from all over the city.

```world locations.locations.kabuki_4
{
	"name": "Cyborg Station",
	"district": "kabuki",
	"number": 4,
	"type": "medical",
	"owner": "",
	"owner_name": "Android Ace (Tech 7)",
	"security_code": {
		"n": 9,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Android Ace (Ken Katagai, Tech 7)"
	],
	"hooks": [
		{
			"text": "The Tyger Claws guard Android Ace's workshop around the clock to keep him from leaving Kabuki.",
			"gigs": [
				"corp_extraction"
			]
		}
	],
	"gigs": [
		"corp_extraction"
	],
	"interior": "",
	"cite": "NC2045 p.203"
}
```

### #5 Delphi X

Tyger Claws strip club and brothel, the safest place in Kabuki to buy sex, with a new star dancer.

```world locations.locations.kabuki_5
{
	"name": "Delphi X",
	"district": "kabuki",
	"number": 5,
	"type": "club",
	"owner": "tyger_claws",
	"owner_name": "Tyger Claws",
	"security_code": {
		"n": 7,
		"faction": "tyger_claws",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Lizzie Borden (Rockerboy 6)"
	],
	"hooks": [
		{
			"text": "Foundation chair Ryoko Fujiwara keeps pressing her husband to close Delphi X or move it out of Kabuki.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"sabotage"
	],
	"interior": "",
	"cite": "NC2045 p.203"
}
```

### #6 Hiroto Miyamoto Memorial Clinic

Hospital named for Shinobu the Second's murdered best friend, funded by the Nakagawa Foundation.

```world locations.locations.kabuki_6
{
	"name": "Hiroto Miyamoto Memorial Clinic",
	"district": "kabuki",
	"number": 6,
	"type": "medical",
	"owner": "nakagawa_foundation",
	"owner_name": "Nakagawa Foundation",
	"security_code": {
		"n": 9,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Bomb threats come in constantly, probably from REO Meatwagon staff who resent the clinic's ambulances.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage"
	],
	"interior": "New hospital with a training programme and three ambulances; swept for explosives regularly.",
	"cite": "NC2045 p.203"
}
```

### #7 Houou

Nightclub-casino of the Tyger Phoenix, the faction that lost the War of Succession.

```world locations.locations.kabuki_7
{
	"name": "Houou",
	"district": "kabuki",
	"number": 7,
	"type": "casino",
	"owner": "tyger_claws",
	"owner_name": "Tyger Phoenix (Tyger Claws faction)",
	"security_code": {
		"n": 7,
		"faction": "tyger_claws",
		"intensity": "light",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Tyger Phoenix is rumoured to be negotiating an alliance with the Kanzaki Family; a Kimen-Gumi raid on the second floor may be coming.",
			"gigs": [
				"gang_hit",
				"data_theft"
			]
		},
		{
			"text": "The second-floor identity shop sells bodysculpts and fake SINs.",
			"gigs": [
				"data_theft"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"data_theft"
	],
	"interior": "Gambling (pachinko, mahjong, chō-han, blackjack) at the front, J-Pop dance floor at the back, the Mini-Tyger Room with cat drones, and an identity shop on the second floor.",
	"cite": "NC2045 p.204"
}
```

### #8 Kabuki Ceremonial Hall

A one-stop mall of ceremonies, from weddings to funerals.

```world locations.locations.kabuki_8
{
	"name": "Kabuki Ceremonial Hall",
	"district": "kabuki",
	"number": 8,
	"type": "church",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 8,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Cylindrical, Colosseum-styled building holding a Shinto shrine (Sankai Jinja), Buddhist temple (Sankai-ji), Christian chapel (Sankai Church), hotel and restaurant (Sankai-tei), a crematorium with arc furnace and a sentō bath; Tyger Cab shuttles to Denya Jinja in New Westbrook.",
	"cite": "NC2045 p.204"
}
```

### #9 Kabuki Market

Street-food bazaar whose stalls are licensed by a Tyger Claws fixer and get first pick of Darangen imports.

```world locations.locations.kabuki_9
{
	"name": "Kabuki Market",
	"district": "kabuki",
	"number": 9,
	"type": "market",
	"owner": "tyger_claws",
	"owner_name": "Hamada (Fixer 4), Tyger Claws",
	"security_code": {
		"n": 7,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Hamada (Fixer 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Open-air bazaar in the roundabout where Nakagawa Avenue meets Charter Street; Shou-an tea house is the only permanent building.",
	"cite": "NC2045 p.204"
}
```

### #10 Matsura Food Products

Darangen-founded importer of Asian non-perishable food.

```world locations.locations.kabuki_10
{
	"name": "Matsura Food Products",
	"district": "kabuki",
	"number": 10,
	"type": "warehouse",
	"owner": "",
	"owner_name": "Matsura Food Products",
	"security_code": {
		"n": 7,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Neutral between the Tyger Claws, Kanzaki, Weng Fang Tong and Eastern Tigers, Matsura expects pressure to pick a side and is hiring edgerunner crews to guard its facilities.",
			"gigs": [
				"sabotage",
				"gang_hit"
			]
		}
	],
	"gigs": [
		"sabotage",
		"gang_hit"
	],
	"interior": "",
	"cite": "NC2045 p.204"
}
```

### #11 Murakami Suiun Imports

One of the Pacifica Confederation's biggest Japanese importers, owned by the City Manager.

```world locations.locations.kabuki_11
{
	"name": "Murakami Suiun Imports",
	"district": "kabuki",
	"number": 11,
	"type": "warehouse",
	"owner": "",
	"owner_name": "Yoshiki Murakami (Fixer 6); run by Hikaru Murakami (Fixer 5)",
	"security_code": {
		"n": 8,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Hikaru Murakami (Fixer 5)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Imports electronics, weapons, armour, household goods and vehicles; a monthly on-site Night Market sells street-legal Japanese cars and bikes.",
	"cite": "NC2045 p.205"
}
```

### #12 Nakagawa Academy

Foundation-funded school, 100eb a month.

```world locations.locations.kabuki_12
{
	"name": "Nakagawa Academy",
	"district": "kabuki",
	"number": 12,
	"type": "school",
	"owner": "nakagawa_foundation",
	"owner_name": "Nakagawa Foundation",
	"security_code": {
		"n": 7,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"SHO (Yuuki) (Solo 3)"
	],
	"hooks": [
		{
			"text": "NCCS reps keep an office here and lock promising students into contracts before graduation.",
			"gigs": [
				"corp_extraction"
			]
		},
		{
			"text": "Laser-tag champion Yuuki is courted by Militech, Lazarus and other PMCs.",
			"gigs": [
				"corp_extraction"
			]
		}
	],
	"gigs": [
		"corp_extraction"
	],
	"interior": "K-12 school with daycare, athletic facilities and rooftop batting cages; NCCS office on site.",
	"cite": "NC2045 p.205"
}
```

### #13 Nakagawa Garage Tower

Kabuki's most secure car park; Tyger Cabs wait out front.

```world locations.locations.kabuki_13
{
	"name": "Nakagawa Garage Tower",
	"district": "kabuki",
	"number": 13,
	"type": "transport",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 7,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Five storeys up and five down, fully automated with drone defences; cars are turntabled into armoured containers and shelved; AV pad and Aerocab landing pad on the roof. 20eb/hour or 100eb/day, vehicles forfeited after a week unpaid.",
	"cite": "NC2045 p.205"
}
```

### #14 Nakagawa Kabuki Theater

Kabuki's grandest building, home of the Nakagawa Kabuki Troupe, the Foundation and the Tyger Claws' leader.

```world locations.locations.kabuki_14
{
	"name": "Nakagawa Kabuki Theater",
	"district": "kabuki",
	"number": 14,
	"type": "venue",
	"owner": "nakagawa_foundation",
	"owner_name": "Nakagawa Foundation (chair Ryoko Fujiwara, Exec 6)",
	"security_code": {
		"n": 10,
		"faction": "kimen_gumi",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Ryoko Fujiwara (Exec 6)",
		"Shinobu the Second (Rockerboy 4/Solo 4)"
	],
	"hooks": [
		{
			"text": "Fujiwara refuses to spend Foundation money on Shinobu the Second's backers, and disgruntled Tyger Claws leaders talk of a coup or of defecting to the Kanzaki.",
			"gigs": [
				"assassination",
				"gang_hit"
			]
		},
		{
			"text": "The sniper Zen is said to watch the rooftops to protect Shinobu the Second.",
			"gigs": [
				"assassination"
			]
		}
	],
	"gigs": [
		"assassination",
		"data_theft"
	],
	"interior": "Floors 1-5 a huge kabuki theatre, floor 6 a district history museum and gift shop, the next four Nakagawa Foundation offices, and a penthouse on top where Fujiwara and Shinobu the Second live.",
	"cite": "NC2045 p.205"
}
```

### #15 No-Tell Motel

Where nobody checks in for innocent reasons.

```world locations.locations.kabuki_15
{
	"name": "No-Tell Motel",
	"district": "kabuki",
	"number": 15,
	"type": "hotel",
	"owner": "",
	"owner_name": "",
	"security_code": {
		"n": 3,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Execs hold affairs, Fixers close quiet deals and crews stage jobs or lie low here.",
			"gigs": [
				"data_theft",
				"assassination"
			]
		}
	],
	"gigs": [
		"data_theft"
	],
	"interior": "Five-storey automated motel; rooms 10eb/hour or 100eb/day; overstayers are gassed with sedative.",
	"cite": "NC2045 p.206"
}
```

### #16 Oasis (Kabuki)

A convenience store nobody in Kabuki wants.

```world locations.locations.kabuki_16
{
	"name": "Oasis (Kabuki)",
	"district": "kabuki",
	"number": 16,
	"type": "shop",
	"owner": "continental_brands",
	"owner_name": "Continental Brands",
	"security_code": {
		"n": 2,
		"faction": "kimen_gumi",
		"intensity": "light",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Tyger Claws factions, G3 and local yogangs have all trashed the store, and Continental Brands keeps rebuilding it.",
			"gigs": [
				"sabotage"
			]
		}
	],
	"gigs": [
		"sabotage"
	],
	"interior": "",
	"cite": "NC2045 p.206"
}
```

### #17 Rokumei-kan

A maid/butler café styled as a British tearoom, run by a maid FBC with titanium antlers; afternoon tea 50eb.

```world locations.locations.kabuki_17
{
	"name": "Rokumei-kan",
	"district": "kabuki",
	"number": 17,
	"type": "restaurant",
	"owner": "",
	"owner_name": "YouYou (Rockerboy 4)",
	"security_code": {
		"n": 6,
		"faction": "g3",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"YouYou (Rockerboy 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.206"
}
```

### #18 Sanroo Neuro-land

Sanroo's weapons showroom and store.

```world locations.locations.kabuki_18
{
	"name": "Sanroo Neuro-land",
	"district": "kabuki",
	"number": 18,
	"type": "shop",
	"owner": "sanroo",
	"owner_name": "Sanroo",
	"security_code": {
		"n": 10,
		"faction": "kimen_gumi",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"data_theft"
	],
	"interior": "Showroom with virtuality simulators and braindance try-outs; an invitation-only back room sells limited-edition weapons to prestige clients. Kimen-Gumi guard it around the clock and G3 defend it fiercely.",
	"cite": "NC2045 p.206"
}
```

### #19 Segotari HQ/EXCEL-1

Pacifica HQ of the world's largest video game company above Night City's biggest entertainment hub.

```world locations.locations.kabuki_19
{
	"name": "Segotari HQ/EXCEL-1",
	"district": "kabuki",
	"number": 19,
	"type": "corp_hq",
	"owner": "segotari",
	"owner_name": "Segotari",
	"security_code": {
		"n": 9,
		"faction": "kimen_gumi",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"SHO (Yuuki) (Solo 3)"
	],
	"hooks": [
		{
			"text": "Night City's Elflines Online servers are rumoured to sit in a subbasement beneath the hotel.",
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
	"interior": "Segotari offices on the upper floors; bottom nine floors are EXCEL-1 (arcades, karaoke, net café, bath, bowling, laser tag, go-karts, food court; 20eb/hour, closed 4-8am for cleaning); Elfhold cube hotel in the basement (20eb/night).",
	"cite": "NC2045 p.206"
}
```

### #20 Tengen Towers

Regional HQ of Kiroshi and Kendachi.

```world locations.locations.kabuki_20
{
	"name": "Tengen Towers",
	"district": "kabuki",
	"number": 20,
	"type": "corp_office",
	"owner": "kiroshi",
	"owner_name": "Kiroshi and Kendachi",
	"security_code": {
		"n": 9,
		"faction": "kimen_gumi",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"data_theft",
		"corp_extraction"
	],
	"interior": "Two towers on a shared three-floor base of shops, showrooms and a cyberware clinic; from the fourth floor the east tower is Kiroshi's, the west Kendachi's.",
	"cite": "NC2045 p.207"
}
```

### #21 Toranoko Gakuen

A Tyger Claws orphanage that trains children for NCCS factory jobs.

```world locations.locations.kabuki_21
{
	"name": "Toranoko Gakuen",
	"district": "kabuki",
	"number": 21,
	"type": "school",
	"owner": "tyger_claws",
	"owner_name": "Tyger Claws",
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
			"text": "The children's fierce loyalty fuels rumours that the vocational training includes braindance brainwashing.",
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
	"cite": "NC2045 p.207"
}
```

### #22 Tyger Dojo/Tora-no-Ana

Martial arts school: Arasaka-te for beginners, advanced arts in Tora-no-Ana; the old master is rumoured to be an FBC.

```world locations.locations.kabuki_22
{
	"name": "Tyger Dojo/Tora-no-Ana",
	"district": "kabuki",
	"number": 22,
	"type": "school",
	"owner": "",
	"owner_name": "Ryu Sensei (Solo 6)",
	"security_code": {
		"n": 10,
		"faction": "staff",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Ryu Sensei (Solo 6)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Behind Toranoko Gakuen.",
	"cite": "NC2045 p.207"
}
```

### #23 Tyger Works Tower

The Tyger Claws' central stronghold; every business inside belongs to the gang.

```world locations.locations.kabuki_23
{
	"name": "Tyger Works Tower",
	"district": "kabuki",
	"number": 23,
	"type": "gang_base",
	"owner": "tyger_claws",
	"owner_name": "Tyger Claws",
	"security_code": {
		"n": 10,
		"faction": "tyger_claws",
		"intensity": "heavy",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Burai (Takeru Akagi) (Solo 4)"
	],
	"hooks": [
		{
			"text": "Tyger Eats on the seventh floor delivers drugs along with meals across Kabuki and Watson.",
			"gigs": [
				"gang_hit",
				"sabotage"
			]
		},
		{
			"text": "Suspects held by the Kimen-Gumi wait in the tower's jail for NCPD transfer.",
			"gigs": [
				"rescue"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"rescue",
		"data_theft"
	],
	"interior": "Ten-storey brutalist block with bulletproof windows. Floors 1-2 Kimen-Gumi HQ (meeting rooms, offices, squad rooms, armory); 3-4 holding jail; 5 coffin bunks; 6 Tyger Cab; 7 Tyger Eats; 8 Ameku Clinic and Yagami Law Offices (Tyger Claws only); 9-10 senior gang offices; garage underneath.",
	"cite": "NC2045 p.207"
}
```

### #24 Yum Seng

Upscale seafood restaurant and hostess karaoke bar.

```world locations.locations.kabuki_24
{
	"name": "Yum Seng",
	"district": "kabuki",
	"number": 24,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Alan Lam (Fixer 5)",
	"security_code": {
		"n": 10,
		"faction": "danger_gal",
		"intensity": "medium",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Alan Lam (Fixer 5)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Restaurant with soundproofed karaoke boxes; every guest gets a host or hostess, so no booth is private. Security is privately paid Danger Gal, not the Tyger Claws.",
	"cite": "NC2045 p.207"
}
```

## Fixers

- Yoshiki Murakami (Fixer 6) — City Manager and importer; Murakami Suiun Imports (#11) (p.201, 205).
- Hikaru Murakami (Fixer 5) — runs Murakami Suiun Imports (#11); electronics, weapons, armour, monthly Night Market for Japanese vehicles (p.205).
- Hamada (Fixer 4) — Tyger Claws fixer who governs the Kabuki Market (#9) food stalls (p.204).
- Alan Lam (Fixer 5) — owner of Yum Seng (#24); brokers deals between Night City's criminal organisations as a neutral party (p.207).
- "The Knife" (Solo ??) — not a fixer, but a few select Fixers know the ZChat account where you send "Katana" to hire this assassin (p.208).

## Personalities

- Yoshiki Murakami (Fixer 6) — NCCS-appointed City Manager juggling the NCCS, the Foundation and the Tyger Claws (p.201).
- Alan Lam (Fixer 5) — Cantonese-American raconteur, owner of Yum Seng and neutral vice broker (p.207).
- Burai (Takeru Akagi) (Solo 4) — red-masked captain of the Kimen-Gumi, unbribable and loyal to Shinobu the Second (p.207).
- Darius Powell (Netrunner 4) — freelance security expert searching for his Arasaka-employee parents lost in the 4CW (p.208).
- Hazumi Ihara (Karen Frost) (Solo 7) — G3's anime-obsessed leader whose lieutenants fear she'll go cyberpsycho (p.208).
- Ken Koutsu (Nomad 2) — Tyger Cab driver running 50eb paranormal tours of Watson and Kabuki (p.208).
- "The Knife" (Solo ??) — legendary Yakuza-linked assassin, maybe several people, maybe Zen (p.208).
- Nana-chan (Media 4/Rockerboy 4) — anonymous fox-avatar VCaster who narrates the district guide (p.208).
- Nigashiya (Netrunner ??) — legendary runner said to help anyone who feeds 100eb to an Oinari shrine escape pursuit (p.208).
- Ryoko Fujiwara (Exec 6) — Nakagawa Foundation chair, arts patron, wants Delphi X gone (p.208).
- Shinobu the Second (Solo 4/Rockerboy 4) — theatrical Tyger Claws leader with a shaky grip and escalating cyberware (p.208).
- SHO (Yuuki) (Solo 3) — EXCEL-1 laser-tag queen and Nakagawa Academy senior courted by PMCs (p.208).
- Zen (Solo 4) — rooftop sniper guarding Shinobu the Second to repay a debt to his father (p.208).
