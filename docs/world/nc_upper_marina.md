# Upper Marina

A waterfront district rebuilding fast on the surface (NC2045 p.66-67): new ventures, pumped-out NCART stations
and jobs, but absentee investors profit while locals see little, and the art scene is mostly cynics cosplaying
bohemia. City Manager Kabria Chung, elected by property owners to a six-year term, dreams of houseboats and
wrought-iron glass arcades while her staff take kickbacks. NCPD polices with a lighter touch for the rich; the
Skiv Family edges in across the canal and Maelstrom holds the western edge, with Ziggurat towering over all.

Recent history (p.67): the Slammers chase the West Coast Series, UR sold out the stadium, Hydrosubsidium is
expanding on the waterfront, two dissolving-concrete towers were razed and their land sits empty with a
speculator, and Fixers can still find tickets for a Kira <3 concert. Stat blocks (p.79): Maelstrom Mook, REO
Meatwagon EMT and Driver, Ziggurat Guard (Hardened Mooks).

## District

```world city.districts.upper_marina
{
	"name": "Upper Marina",
	"region": "island",
	"manager": {"name": "Kabria Chung", "role": "Rockerboy 5"},
	"population": "stratified: yacht-owning rich in pieds-a-terre at the top, service and construction workers struggling with rent below",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": 2,
	"provider": "ncpd",
	"gangs": ["enhanced", "gold_dragons", "maelstrom", "prime_time_players", "street_queens", "skiv_family"],
	"ncart": ["Stadium Station", "Ziggurat Station"],
	"profile": "mixed_residential",
	"look": ["marina", "yachts", "gentrifying", "art galleries", "quick-build towers", "corp megastructure"],
	"history": "Pitched as Richard Night's bohemian waterfront; Chung's staff sell approvals for quick-build projects that rot, then pocket commissions reselling the land, and two new towers had to be demolished when their concrete dissolved in blood rain.",
	"cite": "NC2045 p.66-79"
}
```

## Locations

### #1 The Afterlife

The legendary edgerunner bar and hired-muscle marketplace, furnished like the mortuary it began in; drinks are named for fallen patrons (the Silverhand, 20eb).

```world locations.locations.upper_marina_1
{
	"name": "The Afterlife",
	"district": "upper_marina",
	"number": 1,
	"type": "bar",
	"owner": "",
	"owner_name": "Rogue Amendiares (Solo 7/Fixer 7)",
	"security_code": {"n": 11, "faction": "locals", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Rogue Amendiares (Solo 7/Fixer 7)"],
	"hooks": [
		{"text": "Screens list available combat jobs; grudges must be taken outside.", "gigs": ["gang_hit", "assassination"]}
	],
	"gigs": [],
	"interior": "Salvaged autopsy tables and corpse coolers; three nested rooms: the Antechamber for rookies at the front, the Crypt main room, and Hades at the back where Rogue sits with the elite.",
	"cite": "NC2045 p.69"
}
```

### #2 Bay Bridge Residences

A former residential hotel near the Hot Zone, a third now long-term units, where tenants trade labour and security shifts for lower rent. Pockmarked outside, clean inside.

```world locations.locations.upper_marina_2
{
	"name": "Bay Bridge Residences",
	"district": "upper_marina",
	"number": 2,
	"type": "housing",
	"owner": "",
	"owner_name": "Tenants' Committee led by Marnie Maxwell (Exec 2)",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Marnie Maxwell (Exec 2)"],
	"hooks": [],
	"gigs": [],
	"interior": "Lobby Combat Concierge bodega sells guns and ammo, repairs armour and hires out armed escorts; the always-open Night Owl bar on the top floor has soundproofed booths popular with Medias.",
	"cite": "NC2045 p.69"
}
```

### #3 Bless Your Heart

A relentlessly perky Kibble-cuisine cafe run by an ex-N54 cooking host turned shrewd chain owner; the arty crowd eats there ironically.

```world locations.locations.upper_marina_3
{
	"name": "Bless Your Heart",
	"district": "upper_marina",
	"number": 3,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Cosina Tigo (Rockerboy 6)",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Cosina Tigo (Rockerboy 6)"],
	"hooks": [
		{"text": "Rumour: Continental Brands secretly funds the cafe, which is how it gets new Kibble flavours before market.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Green-and-yellow cafe, always immaculate.",
	"cite": "NC2045 p.69"
}
```

### #4 Bright Forest Casino

An old Customs House turned glamorous casino for the wealthy and aspiring, with pleasant staff and pricey drinks.

```world locations.locations.upper_marina_4
{
	"name": "Bright Forest Casino",
	"district": "upper_marina",
	"number": 4,
	"type": "casino",
	"owner": "",
	"owner_name": "Marion Robinson (Fixer 6)",
	"security_code": {"n": 8, "faction": "6th_street", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Marion Robinson (Fixer 6)"],
	"hooks": [
		{"text": "Robinson allegedly ploughs the profits into low-interest loans for working-class small businesses and nonprofits.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Faux woodwork and vintage roulette wheels in the former \"Anything to Declare\" hall.",
	"cite": "NC2045 p.69"
}
```

### #5 Brownstone Waterfront

A stylish new office high-rise full of small firms, whose overworked management and high turnover make it easy to borrow an empty unit for a few days.

```world locations.locations.upper_marina_5
{
	"name": "Brownstone Waterfront",
	"district": "upper_marina",
	"number": 5,
	"type": "corp_office",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Danny D Palma (Nomad 6)"],
	"hooks": [
		{"text": "Scammers and criminals squat in empty units for days before security notices.", "gigs": ["data_theft", "gang_hit"]}
	],
	"gigs": ["data_theft"],
	"interior": "Tenants: Chrysalis Therapy (drug/talk/braindance therapy), Corporate Cool (uniforms for NCPD, Many Hands, City Medical), Henson and Cox (defence law), High T Medicine (sports clinic), No/Brainer Software (GunMart-owned), Wolf's Crime Scene and Hazard Cleanup, WaveMo Water Taxi offices (Danny D Palma, a Prime-Time Player).",
	"cite": "NC2045 p.70"
}
```

### #6 Buffalo's

A seemingly cursed restaurant site where nothing lasts; the new owner relaunched it under the old name his bartender father worked for before a body-dumping incident closed it.

```world locations.locations.upper_marina_6
{
	"name": "Buffalo's",
	"district": "upper_marina",
	"number": 6,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Patrice Marsh (Fixer 3)",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Patrice Marsh (Fixer 3)"],
	"hooks": [],
	"gigs": [],
	"interior": "Clean, modern restaurant.",
	"cite": "NC2045 p.70"
}
```

### #7 City Medical Center

The city's premier hospital, which bought up nuke-wrecked land after the war; the Island's best medical and psychiatric care, for those who can pay.

```world locations.locations.upper_marina_7
{
	"name": "City Medical Center",
	"district": "upper_marina",
	"number": 7,
	"type": "medical",
	"owner": "",
	"owner_name": "City Medical Center",
	"security_code": {"n": 9, "faction": "militech", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Locals resent it for turning away poor patients and swallowing nearby homes as it keeps expanding.", "gigs": ["sabotage"]}
	],
	"gigs": ["rescue", "corp_extraction"],
	"interior": "Huge hospital complex behind bulletproof windows overlooking the Flowertown tent city.",
	"cite": "NC2045 p.70"
}
```

### #8 CMax

A war-shuttered indie cinema the Prime-Time Players posergang made its HQ, screening and arguing over old reruns.

```world locations.locations.upper_marina_8
{
	"name": "CMax",
	"district": "upper_marina",
	"number": 8,
	"type": "gang_base",
	"owner": "prime_time_players",
	"owner_name": "The Prime-Time Players",
	"security_code": {"n": 9, "faction": "prime_time_players", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Visitors to the lobby food booths risk a shakedown by costumed gangers.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit"],
	"interior": "Cinema with themed food booths in the lobby; \"fashion night\" parties in the abandoned warehouse next door.",
	"cite": "NC2045 p.71"
}
```

### #9 Court Towers

Two high-rises abandoned by Merrill, Asukaga & Finch when it moved to The Glen, now pricey conapts.

```world locations.locations.upper_marina_9
{
	"name": "Court Towers",
	"district": "upper_marina",
	"number": 9,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 8, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Monitors disguised as windows show the Marina; plush carpets, marble stairs, and a glass elevator over a massive atrium.",
	"cite": "NC2045 p.71"
}
```

### #10 Crystal Park Market

A glass-roofed day market on the site of the Rainbow Cadenza, where Samurai once played; Chung's showcase "walkable bohemian" retail.

```world locations.locations.upper_marina_10
{
	"name": "Crystal Park Market",
	"district": "upper_marina",
	"number": 10,
	"type": "market",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Will Maine (Fixer 4)", "Jessup Maxwell Junior (Tech 4)", "Benicio"],
	"hooks": [],
	"gigs": [],
	"interior": "Stalls: Bill's salon, Cybershack (programs and deck hardware; Will Maine), Maxwell's cobbler, Other Lives (movies, braindance, blue glass), Pizza to Go, Skinlight fashionware, Tech Time tools and scrap, Torch's Total Repairs drop-off (Benicio).",
	"cite": "NC2045 p.71"
}
```

### #11 Digital Divinity Incorporated, NC

Night City headquarters of a corporate church that worships the online singularity and preaches the Old Net as humanity's next divine stage; celebrities come to connect and be purified.

```world locations.locations.upper_marina_11
{
	"name": "Digital Divinity Incorporated, NC",
	"district": "upper_marina",
	"number": 11,
	"type": "church",
	"owner": "digital_divinity",
	"owner_name": "Digital Divinity Incorporated",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Constant boardroom churn hints at schisms, especially since Netwatch raided DDI offices worldwide in 2037.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": ["data_theft"],
	"interior": "Gleaming high-security tower with AV pads for high-profile adherents; the \"All-Spring of Deus\" NET Architecture.",
	"cite": "NC2045 p.71"
}
```

### #12 Flowertown

A tent city spreading from the ruins of a once-famous florist below City Medical Center, organised into a resistance by an odd alliance of scavvers and the Street Queens.

```world locations.locations.upper_marina_12
{
	"name": "Flowertown",
	"district": "upper_marina",
	"number": 12,
	"type": "squat",
	"owner": "street_queens",
	"owner_name": "scavver groups and the Street Queens",
	"security_code": {"n": 3, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The squatters have so far beaten off district cleanup programs and NCPD raids meant to close the camp.", "gigs": ["gang_hit", "sabotage"]}
	],
	"gigs": ["gang_hit"],
	"interior": "Shanties and tents where greenhouses stood.",
	"cite": "NC2045 p.72"
}
```

### #13 The Forge

An ex-bookstore Maelstrom took after a days-long siege, now an assembly line refurbishing salvaged chrome; friends of the gang can buy direct.

```world locations.locations.upper_marina_13
{
	"name": "The Forge",
	"district": "upper_marina",
	"number": 13,
	"type": "chop_shop",
	"owner": "maelstrom",
	"owner_name": "Maelstrom",
	"security_code": {"n": 9, "faction": "maelstrom", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Maelstrom's \"employees\" are watched by guards in case they try to \"leave work early\".", "gigs": ["rescue", "gang_hit"]}
	],
	"gigs": ["gang_hit", "rescue", "sabotage"],
	"interior": "Open retail floor run as a repair line with clear guard sight lines; armoured shutters and walls scarred by bullets and rockets.",
	"cite": "NC2045 p.72"
}
```

### #14 The Garden of Earthly Delights

A discreet, very expensive pleasure house: guests order food, drugs and companions from menus, bathe, then retire to private rooms. The Gold Dragons provide security for their patron.

```world locations.locations.upper_marina_14
{
	"name": "The Garden of Earthly Delights",
	"district": "upper_marina",
	"number": 14,
	"type": "club",
	"owner": "gold_dragons",
	"owner_name": "patron David Ling Po (Fixer 8)",
	"security_code": {"n": 8, "faction": "gold_dragons", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": ["David Ling Po (Fixer 8)"],
	"hooks": [
		{"text": "Rumour: guests can indulge sadistic or even murderous impulses here.", "gigs": ["rescue", "data_theft"]}
	],
	"gigs": ["rescue", "assassination"],
	"interior": "Menus, then a bathhouse, then private rooms; staff live in on-site dorms; food delivered by bike courier from local restaurants.",
	"cite": "NC2045 p.72"
}
```

### #15 GraffitiX

A gallery for up-and-coming artists; free ground-floor exhibitions and a ticketed upper floor, currently Helga Wise firing clay portraits with a flamethrower.

```world locations.locations.upper_marina_15
{
	"name": "GraffitiX",
	"district": "upper_marina",
	"number": 15,
	"type": "venue",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 6, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Helga Wise (Rockerboy 4/Tech 2)", "Lola Lola (Rockerboy 4/Fixer 4)"],
	"hooks": [
		{"text": "Lola Lola's upcoming show here is rumoured to be worth over fifty million in total (p.67).", "gigs": ["data_theft"]}
	],
	"gigs": [],
	"interior": "Two floors of white space: free ground-floor hall, ticketed upper floor for special shows and artists in residence; exit through the gift shop.",
	"cite": "NC2045 p.72"
}
```

### #16 The Grand Illusion

The music club Kerry Eurodyne and Johnny Silverhand bought; shuttered after the war, it was cleared of squatters by hired edgerunners and reopened in 2035. Its manager is said to tip Kerry off about real talent.

```world locations.locations.upper_marina_16
{
	"name": "The Grand Illusion",
	"district": "upper_marina",
	"number": 16,
	"type": "club",
	"owner": "",
	"owner_name": "Kerry Eurodyne (owner), managed by Filomena Reyes (Exec 5)",
	"security_code": {"n": 6, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Filomena Reyes (Exec 5)", "Kerry Eurodyne"],
	"hooks": [],
	"gigs": [],
	"interior": "Weapons checked at the door are always returned; ceiling mural of Samurai made from plastic wreckage; Thursday new-discoveries night.",
	"cite": "NC2045 p.72"
}
```

### #17 Great River Storehouse

Ziggurat's pilot shop-by-Garden service, delivering by drone within the hour, but only to secure areas (Security Code 6+).

```world locations.locations.upper_marina_17
{
	"name": "Great River Storehouse",
	"district": "upper_marina",
	"number": 17,
	"type": "warehouse",
	"owner": "ziggurat",
	"owner_name": "Ziggurat",
	"security_code": {"n": 7, "faction": "lazarus", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "A warehouse overflowing with goods and Transporter drones tempts thieves, so Ziggurat hired Lazarus to guard it.", "gigs": ["sabotage", "data_theft"]}
	],
	"gigs": ["sabotage", "data_theft"],
	"interior": "Warehouse of commercial goods and Transporter delivery drones.",
	"cite": "NC2045 p.73"
}
```

### #18 Hydrosubsidium R&D

A quietly expanding R&D operation in nondescript twin waterfront warehouses; sleek black boats and helicopters land, load crates and leave.

```world locations.locations.upper_marina_18
{
	"name": "Hydrosubsidium R&D",
	"district": "upper_marina",
	"number": 18,
	"type": "lab",
	"owner": "hydrosubsidium",
	"owner_name": "Hydrosubsidium",
	"security_code": {"n": 10, "faction": "hydrosubsidium", "intensity": "heavy", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "A homeless Navy vet swears a dropped crate spilled gold and jewels, maybe treasure raised from the sea floor.", "gigs": ["data_theft", "sabotage"]},
		{"text": "Nobody knows what the R&D department is working on.", "gigs": ["data_theft", "corp_extraction"]}
	],
	"gigs": ["data_theft", "sabotage", "corp_extraction"],
	"interior": "Twin warehouses with direct marina access, discreet signs, gate guards and a new chain-link fence closing the waterfront.",
	"cite": "NC2045 p.73"
}
```

### #19 JC Homes

"Luxury" flats that burned twice during construction and sat empty; now filled with squatters and Maelstrom gangers.

```world locations.locations.upper_marina_19
{
	"name": "JC Homes",
	"district": "upper_marina",
	"number": 19,
	"type": "squat",
	"owner": "maelstrom",
	"owner_name": "squatters and Maelstrom",
	"security_code": {"n": 4, "faction": "maelstrom", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Corp security tries to evict the occupants whenever the property goes to auction, and the battles wreck it further.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit"],
	"interior": "Fire-damaged, unfinished apartment block.",
	"cite": "NC2045 p.73"
}
```

### #20 Kraken Line Water Taxis

The largest and best organised water-taxi service across Del Coronado Bay, its boats marked with a cheery green kraken; about 20eb a crossing.

```world locations.locations.upper_marina_20
{
	"name": "Kraken Line Water Taxis",
	"district": "upper_marina",
	"number": 20,
	"type": "docks",
	"owner": "",
	"owner_name": "Kraken Line",
	"security_code": {"n": 6, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Dockside ticket kiosk and moorings.",
	"cite": "NC2045 p.73"
}
```

### #21 La Lune Bleue

A very exclusive two-floor French restaurant in a circular building; about 500eb a meal for two, if the maitre d' lets you in.

```world locations.locations.upper_marina_21
{
	"name": "La Lune Bleue",
	"district": "upper_marina",
	"number": 21,
	"type": "restaurant",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Maurice (Fixer 3)"],
	"hooks": [],
	"gigs": ["assassination"],
	"interior": "Solid door staff, then Maurice in the lobby, who admits only people on his updated list of the prestigious.",
	"cite": "NC2045 p.73"
}
```

### #22 Marina Breeze Apartments

A botched luxury condo project turned cheap subdivided flats; affordable, adequately secure.

```world locations.locations.upper_marina_22
{
	"name": "Marina Breeze Apartments",
	"district": "upper_marina",
	"number": 22,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Attached docks hold water taxis and small sport-fishing boats.",
	"cite": "NC2045 p.74"
}
```

### #23 Marina FloatHomes

A fleet of houseboats and floating docks by McCartney Stadium, mixing corpzoner homes, seasonal cubes for fans and floating firetraps for the poor.

```world locations.locations.upper_marina_23
{
	"name": "Marina FloatHomes",
	"district": "upper_marina",
	"number": 23,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 4, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Motorhome-sized units moored between three-storey structures piled on disguised cargo barges; semi-legal water taxis.",
	"cite": "NC2045 p.74"
}
```

### #24 McCartney Cubes

A low-rent cube hotel whose only selling point is the stadium next door; deafening and riotous on game days.

```world locations.locations.upper_marina_24
{
	"name": "McCartney Cubes",
	"district": "upper_marina",
	"number": 24,
	"type": "cube_hotel",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 3, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Cubes plastered with sports posters.",
	"cite": "NC2045 p.74"
}
```

### #25 McCartney Field Stadium

A 75,000-seat stadium that served as refugee shelter and morgue after the war and was repaired with Night Corp grants; now the hub of event entertainment, from four franchises to bloodsport and UR's seminars.

```world locations.locations.upper_marina_25
{
	"name": "McCartney Field Stadium",
	"district": "upper_marina",
	"number": 25,
	"type": "stadium",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 9, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Hyun-Jae Jong (Solo 5)", "Shivani Carson (Solo 6)", "Sara Dominguez (Exec 5)", "Louis \"Kappa\" Ochs (Solo 7)", "Kaku \"Anansi\" Obeng (Solo 6)", "The Kidd (Rockerboy 6)", "Iron Chic (Rockerboy 5)", "Masked Athena (Rockerboy 5)"],
	"hooks": [
		{"text": "Rumour: the Nuke just poached a star murderball player from Vancouver (p.67).", "gigs": ["corp_extraction"]},
		{"text": "The Heat are one strong star away from contention.", "gigs": ["corp_extraction"]}
	],
	"gigs": ["assassination", "corp_extraction"],
	"interior": "Home of the Slammers (baseball), Heat (basketball), Death Dealers (combat soccer), Nuke (murderball) and the NBCL Tanks in the Tank cage fights over electrified water.",
	"cite": "NC2045 p.74"
}
```

### #26 Megabuilding H8 Construction Site

A megabuilding the Council hired AllNations Construction to build, pushed by Night Corp and Ziggurat over City Manager Chung's objections.

```world locations.locations.upper_marina_26
{
	"name": "Megabuilding H8 Construction Site",
	"district": "upper_marina",
	"number": 26,
	"type": "megabuilding",
	"owner": "allnations_construction",
	"owner_name": "AllNations Construction",
	"security_code": {"n": 8, "faction": "aldecaldo_peacekeepers", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Swinger (Netrunner 2)"],
	"hooks": [
		{"text": "Chung publicly calls it affordable housing but would love to see it burn.", "gigs": ["sabotage"]},
		{"text": "Swinger, an AllNations equipment driver, takes bribes to lend out heavy machines for a quick job (p.78).", "gigs": ["sabotage"]},
		{"text": "Morro Strand Yacht Club members file nuisance suits against anyone tied to the project.", "gigs": ["sabotage"]}
	],
	"gigs": ["sabotage"],
	"interior": "Active construction site guarded by Aldecaldos.",
	"cite": "NC2045 p.75"
}
```

### #27 Metal Heaven

The city's best music store, moved to a renovated warehouse on the Hot Zone's edge; any track or part found, any instrument custom-built.

```world locations.locations.upper_marina_27
{
	"name": "Metal Heaven",
	"district": "upper_marina",
	"number": 27,
	"type": "shop",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The Prime-Time Players feud with the store over its thin stock of theme songs and soundtracks and sometimes cause trouble.", "gigs": ["gang_hit"]},
		{"text": "Peace is kept by hired edgerunners and payoffs to Maelstrom.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit"],
	"interior": "Renovated warehouse store with in-house instrument Techs.",
	"cite": "NC2045 p.75"
}
```

### #28 Midnight Arms Regional Office

The old Mustang Arms plant, taken over by retailer Midnight Arms after the Mark III flopped and rebranded once Mustang's CEO died street racing.

```world locations.locations.upper_marina_28
{
	"name": "Midnight Arms Regional Office",
	"district": "upper_marina",
	"number": 28,
	"type": "gun_shop",
	"owner": "midnight_arms",
	"owner_name": "Midnight Arms",
	"security_code": {"n": 8, "faction": "6th_street", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "A crate of Mustang Arms-labelled Mark IIIs might still sit in the back of the warehouse.", "gigs": ["data_theft"]}
	],
	"gigs": ["sabotage", "data_theft"],
	"interior": "Manufacturing lines and warehouse behind a small public showroom.",
	"cite": "NC2045 p.75"
}
```

### #29 Morro Strand Yacht Club

A marina for those too poor for Pacifica Playground but rich enough to be snobs; members back Chung's bohemian vision and hate the megabuilding.

```world locations.locations.upper_marina_29
{
	"name": "Morro Strand Yacht Club",
	"district": "upper_marina",
	"number": 29,
	"type": "docks",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 6, "faction": "militech", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Private marina slips.",
	"cite": "NC2045 p.75"
}
```

### #30 The Neon Johnson

A basement jazz-and-blues bar framed in red neon with a portrait of Robert Johnson; chromed, armed regulars and performers looping through AudioVox implants.

```world locations.locations.upper_marina_30
{
	"name": "The Neon Johnson",
	"district": "upper_marina",
	"number": 30,
	"type": "bar",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Basement bar; regulars dislike strangers interrupting the music.",
	"cite": "NC2045 p.76"
}
```

### #31 Night City Bubbles

A spa offering baths, massage and sauna with attentive "therapists", many also hired out as party escorts.

```world locations.locations.upper_marina_31
{
	"name": "Night City Bubbles",
	"district": "upper_marina",
	"number": 31,
	"type": "club",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 10, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Pixie Stix (Fixer 3)"],
	"hooks": [
		{"text": "Masseuse Pixie Stix will talk about her regulars in useful detail for a mint rare Goosetopia figure (p.78).", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft", "assassination"],
	"interior": "Door security by off-duty NCPD; bodyguards wait in the Associates' Lounge.",
	"cite": "NC2045 p.76"
}
```

### #32 Night City Convention Center

The NC3: a new convention centre big enough for several events at once, with district government offices and the City Manager's office in its towers.

```world locations.locations.upper_marina_32
{
	"name": "Night City Convention Center",
	"district": "upper_marina",
	"number": 32,
	"type": "civic",
	"owner": "",
	"owner_name": "the NC3",
	"security_code": {"n": 9, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["assassination", "data_theft"],
	"interior": "Two large lower floors of halls and auditoriums; two glass towers above for staff, district offices, the City Manager and VIP lounges; skybridge Night Sky Room; public areas decent, towers locked down hard.",
	"cite": "NC2045 p.76"
}
```

### #33 Oceanside Docks

Nominally a private marina for young Execs, mostly full of water taxis and small fishing and salvage boats.

```world locations.locations.upper_marina_33
{
	"name": "Oceanside Docks",
	"district": "upper_marina",
	"number": 33,
	"type": "docks",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The occasional suspiciously well-equipped, guarded speedboat moors here.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.76"
}
```

### #34 Otter Docks Transfer Station

Sorts, packs and exports material from demolition projects across the city.

```world locations.locations.upper_marina_34
{
	"name": "Otter Docks Transfer Station",
	"district": "upper_marina",
	"number": 34,
	"type": "factory",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 3, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Scavvers dodge security and stow away in trailers for choice salvage; most weeks someone dies in the machinery.", "gigs": ["rescue"]}
	],
	"gigs": [],
	"interior": "Sorting machinery and trailers.",
	"cite": "NC2045 p.76"
}
```

### #35 Quarantine

The old animal quarantine pens, now a cheap bar and burger joint for tired workers who gang up on any troublemaker.

```world locations.locations.upper_marina_35
{
	"name": "Quarantine",
	"district": "upper_marina",
	"number": 35,
	"type": "bar",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Booths are repurposed kennels; back room with pool tables hosts Fixit Fridays; communal toolkit kept behind the bar.",
	"cite": "NC2045 p.77"
}
```

### #36 REO Meatwagon

The cut-rate ambulance company for people without Trauma Team cover; it won't enter combat zones or leave city limits.

```world locations.locations.upper_marina_36
{
	"name": "REO Meatwagon",
	"district": "upper_marina",
	"number": 36,
	"type": "medical",
	"owner": "reo_meatwagon",
	"owner_name": "REO Meatwagon",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Massive bunker by the brackish channel: garage of Ambunaughts, repair workshops, offices, dispatch, bunk rooms and an armory.",
	"cite": "NC2045 p.77"
}
```

### #37 TravlStay CityCenter

A 2018 cube hotel a few blocks from Totentanz that annexed the glass tower next door when its owners fled the war; utilities run as long as tenants pay Maelstrom's collector.

```world locations.locations.upper_marina_37
{
	"name": "TravlStay CityCenter",
	"district": "upper_marina",
	"number": 37,
	"type": "cube_hotel",
	"owner": "maelstrom",
	"owner_name": "TravlStay (rent collected by Maelstrom)",
	"security_code": {"n": 3, "faction": "maelstrom", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["gang_hit"],
	"interior": "Paper-thin cubes in the hotel and the annexed high-rise.",
	"cite": "NC2045 p.77"
}
```

### #38 Upper Marina Substation 2

A power substation dressed as a Victorian conservatory, its windows screens of art and city footage, set in a park the locals use.

```world locations.locations.upper_marina_38
{
	"name": "Upper Marina Substation 2",
	"district": "upper_marina",
	"number": 38,
	"type": "utility",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 9, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["sabotage"],
	"interior": "Substation inside a wrought-iron facade; Realgrass park with a dedicated NCPD presence.",
	"cite": "NC2045 p.77"
}
```

### #39 Ziggurat Corporate Terrace

"The Hanging Garden": Ziggurat staff housing hung under the curve of the HQ, where residents must keep their Garden Patch updated or face fines, demotion or eviction.

```world locations.locations.upper_marina_39
{
	"name": "Ziggurat Corporate Terrace",
	"district": "upper_marina",
	"number": 39,
	"type": "housing",
	"owner": "ziggurat",
	"owner_name": "Ziggurat",
	"security_code": {"n": 10, "faction": "ziggurat", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["corp_extraction"],
	"interior": "Apartments under the HQ curve; saunas, infinity pools and gym for Rank Z3+; door screens show each resident's Patch; windows sealed after a viral suicide.",
	"cite": "NC2045 p.77"
}
```

### #40 Ziggurat Headquarters

Ziggurat's curved global HQ looming over the district; it runs the CitiNet and the Data Pool.

```world locations.locations.upper_marina_40
{
	"name": "Ziggurat Headquarters",
	"district": "upper_marina",
	"number": 40,
	"type": "corp_hq",
	"owner": "ziggurat",
	"owner_name": "Ziggurat (CEO UR (Exec 10/Rockerboy 7))",
	"security_code": {"n": 10, "faction": "ziggurat", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["UR (Exec 10/Rockerboy 7)", "Beansie"],
	"hooks": [
		{"text": "Where in the tower the city's CitiNet servers sit is a closely guarded secret, kept even from the NCFD.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": ["data_theft", "sabotage", "corp_extraction", "assassination"],
	"interior": "Lower floors: bays for CitiNet repair vehicles and tech squads; middle: development, CitiNet and Data Pool content control, sales; upper: executives, UR's suite at the apex of the curve; public first floor with the Ihara-Grubb Net Museum and a press auditorium; private fire/EMS station at the base.",
	"cite": "NC2045 p.78"
}
```

## Fixers

- Rogue Amendiares (Solo 7/Fixer 7) — The Afterlife (#1); combat jobs and hired muscle.

- Marion Robinson (Fixer 6) — Bright Forest Casino (#4); low-interest loans for small businesses.

- Patrice Marsh (Fixer 3) — Buffalo's (#6); restaurateur.

- Will Maine (Fixer 4) — Cybershack, Crystal Park Market (#10); programs and cyberdeck hardware.

- Maurice (Fixer 3) — maitre d' at La Lune Bleue (#21); gatekeeper of the prestige list.

- Pixie Stix (Fixer 3) — Night City Bubbles (#31); gossip about her regulars.

- Lola Lola (Rockerboy 4/Fixer 4) — GraffitiX art scene; art and drug connections.

- Ricardo Ashanti (Fixer 3/Exec 5) — property broker; construction contracts and rebuild deals.

- Dino Dinovic (Fixer 4) — club scene; cheap drugs and side doors left unlocked.


## Personalities

- Beansie: ageless chief custodian of Ziggurat's fire and EMS station; talks of wars before the Collapse.

- Dino Dinovic (Fixer 4): club drug dealer and self-styled musician; can get a club side door left open.

- Lola Lola (Rockerboy 4/Fixer 4): famous district artist who shares art- and drug-scene contacts with those she likes.

- Marion Robinson (Fixer 6): runs Bright Forest Casino; fairy godmother to local small businesses.

- Pixie Stix (Fixer 3): Bubbles masseuse and Goosetopia collector who trades gossip for rare figures.

- Ricardo Ashanti (Fixer 3/Exec 5): property speculator who has hidden behind aliases to profit from a dozen rebuilds of abandoned, collapsed or exploded buildings.

- Swinger (Netrunner 2): AllNations heavy-equipment driver on Megabuilding H8; bribable.

- UR (Exec 10/Rockerboy 7): Ziggurat's ever-changing, bodysculpt-addicted CEO and Data Pool prophet.

- Vicktor Vang (Rockerboy 5): 2010s Vietnamese action star who leads the Prime-Time Players; at least seven Vicktor Vangs are around.

- Warlock (Solo 6): Maelstrom's business-minded leader at Totentanz; slows development near it and is rumoured to be eyeing a move out.
