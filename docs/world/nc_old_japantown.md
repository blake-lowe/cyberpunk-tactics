# Old Japantown

The 2023 nuke did not hit Japantown directly, but the ground beneath it liquefied and fallout blew across it. Anyone
who could afford to leave moved north to what is now Kabuki (NC2045 p.128-129). The Japanese corp Sanroo later bought
the district government outright, and its branch manager, Adriane Casselle, is the City Manager. She is allied with
the Tyger Claws, whose masked Kimen-Gumi police the district. Old Japantown matters less to the Claws than Kabuki, so
the Kimen-Gumi are understaffed and see a posting here as exile. Casselle and her lover, Kimen-Gumi lieutenant Ryuji
Shimazaki, are quietly turning the troops' loyalty to her. Meanwhile the Iron Sights, backed by the Fixer Hornet, have
pushed the Red Chrome Legion north in a nightly war, Maelstrom raids from the Hot Zone, and cancer rates are rising.
That suggests something in the rubble is still radioactive.

```world city.districts.old_japantown
{
	"name": "Old Japantown",
	"region": "island",
	"manager": {"name": "Adriane Casselle", "role": "Exec 7"},
	"population": "a core of residents of Japanese descent, increasingly mixed with gangers and Glen workers who can't afford The Glen",
	"security_code": {"n": 5, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": 7,
	"provider": "kimen_gumi",
	"gangs": ["iron_sights", "maelstrom", "red_chrome_legion", "tyger_claws"],
	"ncart": ["Sanroo Station"],
	"profile": "combat_zone",
	"look": ["liquefied rubble", "faded Japanese signage", "pastel corporate blocks", "gang war graffiti", "fallout dust"],
	"history": "Wrecked by ground liquefaction and fallout from the 2023 nuke and abandoned for Kabuki; Sanroo later bought the district's government.",
	"cite": "NC2045 p.128-137"
}
```

## Locations

### #1 The Basement
A pawnshop for rare goods in the surviving basement of the ruined Japan Trade Center. The stock on show is cheap; the
owner brings out better pieces for buyers who impress him.

```world locations.locations.old_japantown_1
{
	"name": "The Basement",
	"district": "old_japantown",
	"number": 1,
	"type": "shop",
	"owner": "",
	"owner_name": "Yomotsu Hirasaka (Fixer 5)",
	"security_code": {"n": 6, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Yomotsu Hirasaka (Fixer 5)"],
	"hooks": [],
	"gigs": [],
	"interior": "The intact basement under a rubble-covered building, with cheap goods on display and better ones kept back.",
	"cite": "NC2045 p.129"
}
```

### #2 The Bodukkan
The Kimen-Gumi's Old Japantown base, in the old Bodukkan performing-arts centre where the Nakagawa Kabuki Troupe used
to play. Residents are arrested, processed and interrogated here, and many of the officers care more about lining
their pockets.

```world locations.locations.old_japantown_2
{
	"name": "The Bodukkan",
	"district": "old_japantown",
	"number": 2,
	"type": "police",
	"owner": "kimen_gumi",
	"owner_name": "Kimen-Gumi (Captain Ippei Midorikawa, Solo 4)",
	"security_code": {"n": 9, "faction": "kimen_gumi", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Ippei Midorikawa \"Fuurai\" (Solo 4)", "Ryuji Shimazaki (Lawman 3)"],
	"hooks": [
		{"text": "Casselle and her lover Shimazaki, second in command here, are quietly building a Kimen-Gumi splinter loyal to her.", "gigs": ["assassination", "data_theft"]},
		{"text": "Captain Midorikawa knows he is losing the district and is rumoured to drink Smash by the pallet.", "gigs": []}
	],
	"gigs": ["gang_hit", "data_theft", "rescue"],
	"interior": "The old stages and halls are now bunk rooms, lounges, offices, practice spaces, armouries and cages for seized property.",
	"cite": "NC2045 p.131"
}
```

### #3 Crisis Medical Center
A no-questions-asked clinic that also locks up cyberpsychos. Biotechnica, Rocklin and Dynalar pay for its equipment,
and it runs constant drug, cyberware and psychiatric trials.

```world locations.locations.old_japantown_3
{
	"name": "Crisis Medical Center",
	"district": "old_japantown",
	"number": 3,
	"type": "medical",
	"owner": "",
	"owner_name": "Crisis Medical (sponsors Biotechnica, Rocklin Augmentics, Dynalar)",
	"security_code": {"n": 6, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": 5,
	"npcs": ["Thea Octavius (Exec 3/Medtech 4)"],
	"hooks": [
		{"text": "Rumour says anyone who comes in for treatment could end up as a test subject.", "gigs": ["rescue", "data_theft"]},
		{"text": "The clinic is always running sponsored drug, cyberware and psychiatric trials.", "gigs": ["data_theft", "corp_extraction"]}
	],
	"gigs": ["data_theft", "rescue", "corp_extraction"],
	"interior": "Top-line equipment, sponsor adverts everywhere and secure holding for cyberpsychos.",
	"cite": "NC2045 p.131"
}
```

### #4 The Cutting Edge
A former women's fashion shop reborn as a designer boutique with a hair, nails and fashionware salon. It serves
Segotari and Sanroo staff.

```world locations.locations.old_japantown_4
{
	"name": "The Cutting Edge",
	"district": "old_japantown",
	"number": 4,
	"type": "shop",
	"owner": "",
	"owner_name": "Comme il Faut (Medtech 4)",
	"security_code": {"n": 6, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Comme il Faut (Medtech 4)", "Hornet (Fixer 9/Medtech 4/Tech 4)"],
	"hooks": [
		{"text": "The boutique's most important customer is Hornet, the Fixer who sponsors the Iron Sights.", "gigs": ["assassination"]}
	],
	"gigs": [],
	"interior": "A boutique with a salon.",
	"cite": "NC2045 p.131"
}
```

### #5 Dine 'n Dash
A food cart attached to a motorcycle. Its owner livecasts every customer, and the map pin marks one of her usual stops.

```world locations.locations.old_japantown_5
{
	"name": "Dine 'n Dash",
	"district": "old_japantown",
	"number": 5,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Hidori Shirakawa (Media 4)",
	"security_code": {"n": 4, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Hidori Shirakawa (Media 4)"],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.131"
}
```

### #6 Gazebo Park
A littered patch of ground around a wooden gazebo that locals claim is Richard Night's original from Lake Park. It is
the nearest thing the district has to a playground.

```world locations.locations.old_japantown_6
{
	"name": "Gazebo Park",
	"district": "old_japantown",
	"number": 6,
	"type": "park",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 3, "faction": "kimen_gumi", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Unknown people leave body parts in the gazebo as tributes to \"The Claw\", a cyberpsycho serial killer who used to stage his victims there.", "gigs": []}
	],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.131"
}
```

### #7 The Grateful Crane
A Tyger Claws-linked Fixer runs a guarded guerrilla garden in the ruins of a bank. Poor locals tend it for low pay,
and the best produce goes north to restaurants. Rejected crops go into crane-game machines at 1eb a try.

```world locations.locations.old_japantown_7
{
	"name": "The Grateful Crane",
	"district": "old_japantown",
	"number": 7,
	"type": "shop",
	"owner": "tyger_claws",
	"owner_name": "Kanezou Tsuruta (Fixer 5)",
	"security_code": {"n": 6, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Kanezou Tsuruta (Fixer 5)"],
	"hooks": [],
	"gigs": ["gang_hit", "sabotage"],
	"interior": "Plant beds inside a ruined bank, with a row of crane-game machines.",
	"cite": "NC2045 p.131-132"
}
```

### #8 Highcourt Plaza Hotel
An expensive Art Deco hotel that doesn't belong in a combat zone. Guests come precisely because fans, paparazzi and
detectives struggle to reach it.

```world locations.locations.old_japantown_8
{
	"name": "Highcourt Plaza Hotel",
	"district": "old_japantown",
	"number": 8,
	"type": "hotel",
	"owner": "",
	"owner_name": "Highcourt Plaza Hotel",
	"security_code": {"n": 9, "faction": "highcourt_security", "intensity": "light", "hardened": true},
	"utility_code": 4,
	"npcs": [],
	"hooks": [
		{"text": "Celebrities and other guests hide here from stalkers and spies, and the well-paid guards quietly remove trespassers' bodies.", "gigs": ["assassination", "corp_extraction"]}
	],
	"gigs": ["assassination", "corp_extraction", "data_theft"],
	"interior": "Art Deco throughout, with indoor pools, spas and fine dining. Guests fly in and out by Aerocab AV. Staff ride an armoured shuttle bus from the Kue Street NCART station in Little China.",
	"cite": "NC2045 p.132"
}
```

### #9 Honest Hiro's Used Cars
A used-car lot that runs day and night, stocked with cars the Steel Vaqueros don't want. Hiro's husband Steve, an
ex-Lazarus operative, guards it.

```world locations.locations.old_japantown_9
{
	"name": "Honest Hiro's Used Cars",
	"district": "old_japantown",
	"number": 9,
	"type": "chop_shop",
	"owner": "",
	"owner_name": "Hiro (Fixer 5)",
	"security_code": {"n": 10, "faction": "locals", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Hiro (Fixer 5)", "Steve (Solo 6)"],
	"hooks": [],
	"gigs": [],
	"interior": "A lot with at least a dozen used vehicles and some parked RVs that broke edgerunners are sometimes allowed to sleep in. Cars can be rented for a gig at 50-100eb.",
	"cite": "NC2045 p.132"
}
```

### #10 Imperial Bank
Once the district's main bank, it now only makes payday loans at outrageous interest.

```world locations.locations.old_japantown_10
{
	"name": "Imperial Bank",
	"district": "old_japantown",
	"number": 10,
	"type": "bank",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Someone robbed the bank last week, rumoured to have got away with a few thousand eb.", "gigs": []}
	],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.132"
}
```

### #11 Kaifū Corner
An abandoned strip mall that even the gangs avoid, circled day and night by armed drones. It is the lair of Recluse,
a legendary Netrunner who charges at least 10,000eb a gig and meets clients only as a giant spider in her NET
Architecture.

```world locations.locations.old_japantown_11
{
	"name": "Kaifū Corner",
	"district": "old_japantown",
	"number": 11,
	"type": "data_center",
	"owner": "recluse",
	"owner_name": "Recluse (Netrunner ??)",
	"security_code": {"n": 11, "faction": "recluse", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Recluse (Netrunner ??)"],
	"hooks": [
		{"text": "Recluse is the Netrunner people go to when every other runner has failed; she is rumoured to be ex-Netwatch, an AI or a Net ghost.", "gigs": ["data_theft"]},
		{"text": "The inside is said to be a maze of turrets, traps and drones built to kill any strike team.", "gigs": ["sabotage", "assassination"]}
	],
	"gigs": ["data_theft"],
	"interior": "A ruined strip mall under constant armed-drone patrol, rumoured to be a death maze of turrets and traps inside. Clients jack into the lobby of her NET Architecture.",
	"cite": "NC2045 p.132"
}
```

### #12 Kid Kamp
A cheap daycare that is really a child sweatshop. Its manager is married to a Red Chrome Legion member, and the goods
probably fund the hate gang.

```world locations.locations.old_japantown_12
{
	"name": "Kid Kamp",
	"district": "old_japantown",
	"number": 12,
	"type": "school",
	"owner": "red_chrome_legion",
	"owner_name": "Imgard Huber (Exec 3)",
	"security_code": {"n": 5, "faction": "red_chrome_legion", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": ["Imgard Huber (Exec 3)"],
	"hooks": [
		{"text": "The children at Kid Kamp work in a sweatshop, and the goods they make probably fund the Red Chrome Legion.", "gigs": ["rescue", "sabotage"]}
	],
	"gigs": ["rescue", "sabotage"],
	"interior": "A daycare that is a sweatshop in practice.",
	"cite": "NC2045 p.133"
}
```

### #13 Kakoi-chō
A gated enclave of pre-war Japantown, rebuilt by wealthy families who refused to leave. Most residents are elderly,
their grandchildren are moving back in, and the Kimen-Gumi are well paid to guard it.

```world locations.locations.old_japantown_13
{
	"name": "Kakoi-chō",
	"district": "old_japantown",
	"number": 13,
	"type": "villa",
	"owner": "",
	"owner_name": "the old Japantown families",
	"security_code": {"n": 10, "faction": "kimen_gumi", "intensity": "medium", "hardened": true},
	"utility_code": 6,
	"npcs": ["Sachiko Evans (Media 3)"],
	"hooks": [],
	"gigs": [],
	"interior": "A fenced neighbourhood of restored pre-war homes. Locals from outside work there as attendants, carers, drivers and cleaners.",
	"cite": "NC2045 p.133"
}
```

### #14 Lovely Drone Heroes Café
A bar-café on the Glen border with bad food and watered drinks. Drones with anime-girl holograms of Night City
legends serve customers and coax them into buying drinks and digital gifts.

```world locations.locations.old_japantown_14
{
	"name": "Lovely Drone Heroes Café",
	"district": "old_japantown",
	"number": 14,
	"type": "bar",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 6, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Drone servers carrying Agents projected as hologram hostesses.",
	"cite": "NC2045 p.133"
}
```

### #15 Miyasaka Clinic
A clinic that grew out of an EMT's aid station set up after the nuke. The founder's niece runs it now and will trade
treatment for favours.

```world locations.locations.old_japantown_15
{
	"name": "Miyasaka Clinic",
	"district": "old_japantown",
	"number": 15,
	"type": "medical",
	"owner": "",
	"owner_name": "Asahi (Medtech 4)",
	"security_code": {"n": 5, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Asahi (Medtech 4)"],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.133"
}
```

### #16 Mrs. Suzuki's Bodega
The flagship of a small chain of Japanese grocery bodegas. It is the only outlet for Shroomer mushrooms and lichen,
which earns it a discount on its Kimen-Gumi protection fees.

```world locations.locations.old_japantown_16
{
	"name": "Mrs. Suzuki's Bodega",
	"district": "old_japantown",
	"number": 16,
	"type": "shop",
	"owner": "",
	"owner_name": "Mrs. Suzuki (Exec 6/Fixer 5)",
	"security_code": {"n": 7, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Mrs. Suzuki (Exec 6/Fixer 5)"],
	"hooks": [
		{"text": "Once a month the Suzuki family holds an invitation-only Night Market in an abandoned big-box store.", "gigs": []}
	],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.133-134"
}
```

### #17 Neo Galaxy Cards and Comics
A mouldy but lively game shop at the centre of the Island's Elflines Online card scene. The Iron Sights run it and
sell drugs from the back room.

```world locations.locations.old_japantown_17
{
	"name": "Neo Galaxy Cards and Comics",
	"district": "old_japantown",
	"number": 17,
	"type": "shop",
	"owner": "iron_sights",
	"owner_name": "Iron Sights (manager Anthony Russ, Exec 2)",
	"security_code": {"n": 8, "faction": "iron_sights", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Anthony Russ (Exec 2)", "Sigma K (Solo 4)"],
	"hooks": [
		{"text": "The Iron Sights deal drugs from the back room.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit"],
	"interior": "A shop floor of card tables with a back room used for dealing.",
	"cite": "NC2045 p.134"
}
```

### #18 Oni-Yama Jail
The old Hotel Yamagami, cleared of squatters at gunpoint and turned into the Kimen-Gumi's jail. Prisoners pay a
"fine", are handed to NCPD, or do "community service": long labour shifts for Claw businesses.

```world locations.locations.old_japantown_18
{
	"name": "Oni-Yama Jail",
	"district": "old_japantown",
	"number": 18,
	"type": "police",
	"owner": "kimen_gumi",
	"owner_name": "Kimen-Gumi",
	"security_code": {"n": 9, "faction": "kimen_gumi", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The Kimen-Gumi find excuses to extend the sentences of their most useful prisoners.", "gigs": ["rescue"]}
	],
	"gigs": ["rescue", "gang_hit"],
	"interior": "A former hotel with coffin beds stacked four high on every wall. Prisoners work 16-hour shifts. Sentences of community service run from a week to a month.",
	"cite": "NC2045 p.134"
}
```

### #19 The Precipice
A cargo-container community near Crisis Medical. Many residents earn extra money as test subjects there.

```world locations.locations.old_japantown_19
{
	"name": "The Precipice",
	"district": "old_japantown",
	"number": 19,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 3, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Stacked cargo containers.",
	"cite": "NC2045 p.134"
}
```

### #20 Sanroo Complex
Sanroo's Pacifica Confederation HQ, a huge pastel-pink complex that stands out against the rubble. About 65% of the
Sanroo goods sold in Night City are made here, and the rest arrive from Japan with Darangen sea nomads.

```world locations.locations.old_japantown_20
{
	"name": "Sanroo Complex",
	"district": "old_japantown",
	"number": 20,
	"type": "corp_hq",
	"owner": "sanroo",
	"owner_name": "Sanroo (Branch Manager Adriane Casselle, Exec 7)",
	"security_code": {"n": 10, "faction": "kimen_gumi", "intensity": "medium", "hardened": true},
	"utility_code": 4,
	"npcs": ["Adriane Casselle (Exec 7)"],
	"hooks": [
		{"text": "Casselle is considering paying Hornet to back the Iron Sights so they can drive the Red Chrome Legion out of the district, but Hornet will want more than bribes and turf.", "gigs": ["data_theft", "sabotage"]},
		{"text": "Sanroo has hired the Snake Nation nomads to haul its goods around the Pacifica Confederation.", "gigs": ["sabotage"]}
	],
	"gigs": ["data_theft", "sabotage", "corp_extraction"],
	"interior": "Offices, a factory, a shipping yard and warehouses. Security is listed as \"Various\": Kimen-Gumi guards, a Danger Gal team of snipers and agents, and well-armed Snake Nation nomads in the shipping yard.",
	"cite": "NC2045 p.134"
}
```

### #21 Segotari Factory
A dull factory that makes the plush prizes for crane games. A reliable source says the main Night City servers for
Elflines Online are in its basement.

```world locations.locations.old_japantown_21
{
	"name": "Segotari Factory",
	"district": "old_japantown",
	"number": 21,
	"type": "factory",
	"owner": "segotari",
	"owner_name": "Segotari",
	"security_code": {"n": 7, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Sigma K (Solo 4)"],
	"hooks": [
		{"text": "The main Night City servers for Elflines Online are said to be well protected in the basement, and players would pay a fortune for access.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": ["data_theft", "sabotage"],
	"interior": "A plush-toy factory floor with a server basement.",
	"cite": "NC2045 p.135"
}
```

### #22 Segotari Station Japantown
Segotari's arcade (a gaming centre, not a train station), with Elflines PvP tournaments and dance, fighting and racing
games. Most gangs, even the Legion, treat it as neutral ground.

```world locations.locations.old_japantown_22
{
	"name": "Segotari Station Japantown",
	"district": "old_japantown",
	"number": 22,
	"type": "attraction",
	"owner": "segotari",
	"owner_name": "Segotari",
	"security_code": {"n": 6, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "After the last brawl closed it for three months, Segotari warned that one more major disruption would shut the arcade for good.", "gigs": ["sabotage"]}
	],
	"gigs": [],
	"interior": "An arcade with tournament stations and game cabinets.",
	"cite": "NC2045 p.135"
}
```

### #23 Tartarus
The Iron Sights' central stronghold in the tunnels under the ruined Nichiban Mall. Gangs fought over the mall for
years, the Tyger Claws gave it up, and the Sights moved in.

```world locations.locations.old_japantown_23
{
	"name": "Tartarus",
	"district": "old_japantown",
	"number": 23,
	"type": "gang_base",
	"owner": "iron_sights",
	"owner_name": "Iron Sights (BloodGuts, Solo 6)",
	"security_code": {"n": 10, "faction": "iron_sights", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["BloodGuts (Solo 6)"],
	"hooks": [],
	"gigs": ["gang_hit", "sabotage"],
	"interior": "The mall above ground is wrecked. The stronghold is in the tunnels underneath.",
	"cite": "NC2045 p.135"
}
```

### #24 Tsukuyomi
One of Night City's few employee-owned brothels: plain, clean and respectful. Its manager expects a takeover and is
negotiating with the Piranhas for protection.

```world locations.locations.old_japantown_24
{
	"name": "Tsukuyomi",
	"district": "old_japantown",
	"number": 24,
	"type": "club",
	"owner": "",
	"owner_name": "employee-owned (manager Kotone Shiomi, Rockerboy 2/Fixer 5)",
	"security_code": {"n": 4, "faction": "kimen_gumi", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Kotone Shiomi (Rockerboy 2/Fixer 5)"],
	"hooks": [
		{"text": "Shiomi expects the Tyger Claws or someone else to take over soon, so she is negotiating to put Tsukuyomi under Piranha protection.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit"],
	"interior": "",
	"cite": "NC2045 p.135"
}
```

### #25 Unnamed Cube Hotel
A cube hotel with no staff, no cameras and no known owner. Rent is paid at a lobby vendit, and ceiling water jets clean
the rooms and drench anyone who doesn't pay until they leave.

```world locations.locations.old_japantown_25
{
	"name": "Unnamed Cube Hotel",
	"district": "old_japantown",
	"number": 25,
	"type": "cube_hotel",
	"owner": "",
	"owner_name": "unknown",
	"security_code": {"n": 2, "faction": "kimen_gumi", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Unstaffed cubes with ceiling water jets and gutters, and a payment vendit in the lobby.",
	"cite": "NC2045 p.135"
}
```

### #26 White Side
A scavver trading post on the Hot Zone edge that has changed hands a dozen times. The Red Chrome Legion holds it now
and has covered it in fascist graffiti, but it has clean water and Kibble.

```world locations.locations.old_japantown_26
{
	"name": "White Side",
	"district": "old_japantown",
	"number": 26,
	"type": "market",
	"owner": "red_chrome_legion",
	"owner_name": "Red Chrome Legion",
	"security_code": {"n": 9, "faction": "red_chrome_legion", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["gang_hit"],
	"interior": "A graffiti-covered trading post selling non-irradiated water and Kibble to scavvers.",
	"cite": "NC2045 p.135"
}
```

## Fixers

- Hornet (Fixer 9/Medtech 4/Tech 4): sponsors the Iron Sights and supplies BloodGuts' upgrades; a regular at The Cutting Edge (p.129, p.131, p.136).
- Yomotsu Hirasaka (Fixer 5): runs The Basement pawnshop and deals in rare goods (p.129).
- Kanezou Tsuruta (Fixer 5): Tyger Claws-linked; runs The Grateful Crane garden and sells its produce north (p.131).
- Hiro (Fixer 5): Honest Hiro's Used Cars; cars without much paperwork and rentals for gigs (p.132).
- Mrs. Suzuki (Exec 6/Fixer 5): runs the bodega chain, sells Shroomer produce and holds a monthly invite-only Night Market (p.133-134).
- Kotone Shiomi (Rockerboy 2/Fixer 5): manages Tsukuyomi (p.135).
- Matsu (Fixer 3): recruits day labourers in Old Japantown for construction firms across the city (p.136).

## Personalities

- BloodGuts (Solo 6): leader of the Iron Sights, a sharp strategist with Hornet-supplied upgrades who hates the Legion (p.136).
- Ippei Midorikawa "Fuurai" (Solo 4): Kimen-Gumi captain who is loyal to the Claws but losing the fight (p.136).
- Matsu (Fixer 3): a day-labour broker (p.136).
- Matt Kushida (Tech 4): freelance tech for small bands, and a source of free concert tickets (p.136).
- Maxim (Solo 5): a charismatic Red Chrome Legion lieutenant who knows the war is lost and might take over the gang (p.136).
- Mrs. Suzuki (Exec 6/Fixer 5): the third Mrs. Suzuki to run the family bodegas (p.136).
- Ryuji Shimazaki (Lawman 3): Kimen-Gumi second in command, exiled here, and Casselle's lover and tool (p.136).
- Sachiko Evans (Media 3): an original Night City resident and photographer who is racing to finish a book on the city's history (p.136).
- Sigma K (Solo 4): war veteran and Segotari factory guard who plays cards at Neo Galaxy (p.136).
- Thea Octavius (Exec 3/Medtech 4): runs clinical trials at Crisis Medical and is a single mother (p.136).
- Adriane Casselle (Exec 7): City Manager and Sanroo branch manager (p.129).
