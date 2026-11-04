# Little Europe

A divided district (NC2045 p.54-55): crumbling brick blocks beside new towers, small blue-collar businesses
beside the corps that look down on them, with the spaceport site to the west and the Hot Zone to the east.
Its City Manager, ex-Solo Amanda Polishchuk, is elected by property owners every four years, feuds with
Downtown's Emilia Ortega and is rumoured to fund the Undertow's "protests" there. NCPD answers calls here and
likes to stop and frisk anyone who walks around looking like an armory.

District NCART stations are read off the station flashmap (p.28) against the district map (p.56); the two Blue
Line stops besides Ferris Boulevard are a best guess. Stat blocks (p.65): Danger Gal Detective and NCPD Beat Cop
(Hardened Mooks), Eurotrashers Mook, Short Circuit Tech.

## District

```world city.districts.little_europe
{
	"name": "Little Europe",
	"region": "island",
	"manager": {"name": "Amanda Polishchuk", "role": "Solo 6"},
	"population": "mostly working class, barely covering rent; artists, mercs, suits and blue-collar workers; home of Night Corp and Danger Gal HQs",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": 3,
	"provider": "ncpd",
	"gangs": ["6th_street", "eurotrashers", "maelstrom"],
	"ncart": ["Ferris Boulevard", "Fisk Street", "Gold Beach Street", "Danger Gal Station"],
	"profile": "mixed_residential",
	"look": ["old brick", "art deco", "skyscrapers", "street markets", "pubs", "neon"],
	"history": "Stitched together after the 4CW from Little Italy, Northside and part of West Hill; Downtown split off in 2042 and the border is redrawn every year; a synthcoke gift-box bomb in a day market set off the Bozo Civil War.",
	"cite": "NC2045 p.54-65"
}
```

## Locations

### #1 101.1 Killzone

A pirate-ish hard-rock station rebuilt three years ago from abandoned KJBR Studios gear in the old, somehow still-standing KJBR building; rare singles make it popular.

```world locations.locations.little_europe_1
{
	"name": "101.1 Killzone",
	"district": "little_europe",
	"number": 1,
	"type": "media",
	"owner": "",
	"owner_name": "unknown (rumoured: Rockaby Rozalyn (Rockerboy 5))",
	"security_code": {"n": 6, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Rockaby Rozalyn (Rockerboy 5)"],
	"hooks": [
		{"text": "Nobody knows for sure who rebuilt the station; rumour points at one-time star DJ Rockaby Rozalyn.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Broadcast studio in the old KJBR Studios building.",
	"cite": "NC2045 p.57"
}
```

### #2 Biotechnica Reference Forest RF-14

A thin strip of gene-modded cypress and eucalyptus between the rebuilding centre and the polluted bay, bred to survive urban pollution. Public until last year.

```world locations.locations.little_europe_2
{
	"name": "Biotechnica Reference Forest RF-14",
	"district": "little_europe",
	"number": 2,
	"type": "park",
	"owner": "biotechnica",
	"owner_name": "Biotechnica",
	"security_code": {"n": 10, "faction": "biotechnica", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Closed to the public after a Eurotrashers-Undertow brawl burned trees; now patrolled against further damage.", "gigs": ["sabotage"]},
		{"text": "The trees are a live Biotechnica gene-modification experiment.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft", "sabotage"],
	"interior": "Narrow forest strip by Del Coronado Bay patrolled by Biotechnica guards with a pack of cyberwolves.",
	"cite": "NC2045 p.57"
}
```

### #3 Bristol Business Park

"The Bristol": an eight-storey container building the local owners bought from a bankrupt Fax-Press, now a stack of small tenants from bathhouse to recording studio.

```world locations.locations.little_europe_3
{
	"name": "Bristol Business Park",
	"district": "little_europe",
	"number": 3,
	"type": "corp_office",
	"owner": "",
	"owner_name": "local property owners (bought from Fax-Press)",
	"security_code": {"n": 6, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The Night City Tourism Concern offices are rumoured to front for a corp, a scam or a cult; no tourists ever go there.", "gigs": ["data_theft"]},
		{"text": "Software Solutions on the top floor makes unspecified software and has never released anything.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Ground: public Turkish bathhouse; 2: DC&H tax accountants; 3: indoor park behind bulletproof glass, rented for events; 4-5: Fax-Press; 6: Black Stone Gaming, E-Z Cyberware ripperdoc, Night City Tourism Concern; 7: Hotdesk Co-op coworking; 8: Aural Experiences studio and Software Solutions.",
	"cite": "NC2045 p.57"
}
```

### #4 Camden Court

A pre-4CW apartment block the City Manager bought and restored in 2040 into the district's most fortified address, home to rich retired edgerunners, working Solos and careful Execs. Even Maelstrom treats it as off-limits.

```world locations.locations.little_europe_4
{
	"name": "Camden Court",
	"district": "little_europe",
	"number": 4,
	"type": "housing",
	"owner": "",
	"owner_name": "Amanda Polishchuk (Solo 6)",
	"security_code": {"n": 8, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Amanda Polishchuk (Solo 6)"],
	"hooks": [],
	"gigs": ["assassination", "corp_extraction"],
	"interior": "Restored luxury block with heavy physical and NET security; the City Manager lives in the Penthouse, so NCPD responds fast; most flats hold a private armory.",
	"cite": "NC2045 p.58"
}
```

### #5 Chopper's

Not a biker bar: an old butcher shop turned bar when its freezer died, serving 10eb drinks off the old ice boxes. Eurotrashers drink here because Fiddler's Green bans them.

```world locations.locations.little_europe_5
{
	"name": "Chopper's",
	"district": "little_europe",
	"number": 5,
	"type": "bar",
	"owner": "",
	"owner_name": "Norman",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Norman", "80/20 (Fixer 3)"],
	"hooks": [
		{"text": "80/20 sells cheap second-hand cyberware out of the back room, where the meat grinder still works; don't ask where it came from.", "gigs": ["gang_hit", "rescue"]},
		{"text": "The Eurotrashers hang out here because Kate Mulvaney won't let them into Fiddler's Green.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit"],
	"interior": "Old butcher shop; walk-in ice boxes double as bar and booze storage; Fixer 80/20's back room with a working meat grinder.",
	"cite": "NC2045 p.58"
}
```

### #6 Continental Brands Vertical Neighborhood

"Flavors of the World": corp housing for Continental Brands staff, opened to outsiders when it had room to spare. Notoriously impossible to navigate.

```world locations.locations.little_europe_6
{
	"name": "Continental Brands Vertical Neighborhood",
	"district": "little_europe",
	"number": 6,
	"type": "housing",
	"owner": "continental_brands",
	"owner_name": "Continental Brands",
	"security_code": {"n": 8, "faction": "continental_brands", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Fast Eddie (Fixer 1)"],
	"hooks": [
		{"text": "The maze breeds ambushes; local kids like Fast Eddie sell guided, ambush-free passage for 10eb.", "gigs": ["gang_hit"]}
	],
	"gigs": ["corp_extraction"],
	"interior": "Each floor is a movie-set old-world market of a different country: winding streets, holographic vendors, scent vents; conapt doors are disguised as storefronts.",
	"cite": "NC2045 p.59"
}
```

### #7 Cube-A-Rama

A decent cube hotel cut into uneven cubes inside an old brick apartment building that keeps its pre-war facade.

```world locations.locations.little_europe_7
{
	"name": "Cube-A-Rama",
	"district": "little_europe",
	"number": 7,
	"type": "cube_hotel",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "A Netrunner collective that used to meet at Short Circuit rents most of one floor; nobody knows its aims.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Old brick block behind its original facade, sliced into uneven cubes; one floor mostly rented by a Netrunner collective.",
	"cite": "NC2045 p.59"
}
```

### #8 Danger Gal Housing Facility

The "Danger Zone", across the street from the Danger Gal Offices: an Art Deco compound in pink, neon and black light built for the company's work-hard, play-hard staff. Piranhas and Eurotrashers sometimes hang out.

```world locations.locations.little_europe_8
{
	"name": "Danger Gal Housing Facility",
	"district": "little_europe",
	"number": 8,
	"type": "housing",
	"owner": "danger_gal",
	"owner_name": "Danger Gal",
	"security_code": {"n": 10, "faction": "danger_gal", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["data_theft"],
	"interior": "Art Deco compound with arcade machines, beanbag pits, obstacle courses and snack machines; gym, pool and built-in firing range are residents-only.",
	"cite": "NC2045 p.59"
}
```

### #9 Danger Gal Offices

Headquarters of the anime-styled detective agency, behind a stately Art Deco front with a vintage clock tower. Some of the best security in the district.

```world locations.locations.little_europe_9
{
	"name": "Danger Gal Offices",
	"district": "little_europe",
	"number": 9,
	"type": "corp_hq",
	"owner": "danger_gal",
	"owner_name": "Danger Gal (CEO Michiko Sanderson (Exec 10))",
	"security_code": {"n": 10, "faction": "danger_gal", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Michiko Sanderson (Exec 10)"],
	"hooks": [
		{"text": "Rumour: the maids and butlers of the public maid cafe are undercover operatives gathering intel from smitten customers.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft", "sabotage"],
	"interior": "Art Deco tower under a clock tower; thirteen floors of pink shag, plushies and model robots; only the first floor is public (client meeting offices and an upscale maid cafe).",
	"cite": "NC2045 p.59"
}
```

### #10 Everything and More

Once the area's premier department store, now an oversized upscale bodega that mostly serves Camden Court residents.

```world locations.locations.little_europe_10
{
	"name": "Everything and More",
	"district": "little_europe",
	"number": 10,
	"type": "shop",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 6, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.60"
}
```

### #11 Fiddler's Green

A cheerfully fake Irish pub with a real imported stout (20eb a pint), favoured by NCPD officers and war vets who stop fights more than start them. Edgerunners come for a pint and gossip about new jobs.

```world locations.locations.little_europe_11
{
	"name": "Fiddler's Green",
	"district": "little_europe",
	"number": 11,
	"type": "bar",
	"owner": "",
	"owner_name": "Kate Mulvaney (Solo 6)",
	"security_code": {"n": 9, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Kate Mulvaney (Solo 6)", "Audrey"],
	"hooks": [
		{"text": "Edgerunners swap gossip here about new Little Europe jobs.", "gigs": ["data_theft", "gang_hit"]},
		{"text": "Kate holds packages and messages for regulars as an unofficial post office and dead drop.", "gigs": ["data_theft"]},
		{"text": "Kate bans the Eurotrashers.", "gigs": ["gang_hit"]}
	],
	"gigs": [],
	"interior": "Family-style pub run by Kate, her wife Audrey and family; doubles as a drop for regulars' packages and messages.",
	"cite": "NC2045 p.60"
}
```

### #12 Greta's

Once a lesbian dive bar, now the city's pool hall, where the best players live off bets and the bar sells 20eb Sunk Pockets to the crowd.

```world locations.locations.little_europe_12
{
	"name": "Greta's",
	"district": "little_europe",
	"number": 12,
	"type": "bar",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Jack Sawyer (Tech 6)"],
	"hooks": [],
	"gigs": [],
	"interior": "Dive bar turned pool hall.",
	"cite": "NC2045 p.60"
}
```

### #13 Holy Angels Church

A three-storey faux-Gothic stone Catholic church that offers sanctuary and counsel. The fathers ban weapons and violence inside and will invoke sanctuary in front of NCPD.

```world locations.locations.little_europe_13
{
	"name": "Holy Angels Church",
	"district": "little_europe",
	"number": 13,
	"type": "church",
	"owner": "",
	"owner_name": "Father Kevin (Solo 7)",
	"security_code": {"n": 8, "faction": "6th_street", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Father Kevin (Solo 7)", "Father Paul (Rockerboy 4)", "Lucy (Exec 3)"],
	"hooks": [
		{"text": "No weapons and church sanctuary make it neutral ground where gangers meet to talk business.", "gigs": ["gang_hit"]},
		{"text": "6th Street guards the door for free; cynics call it a stunt to drum up security business.", "gigs": ["gang_hit"]}
	],
	"gigs": ["rescue"],
	"interior": "Three-storey faux-Gothic stone church; no weapons inside; a 6th Street contingent posted outside.",
	"cite": "NC2045 p.60"
}
```

### #14 Kaito Market

A little-known open-air day market set up Thursday to Sunday on an empty lot, with rotating weekly stalls and a few permanent plascrete ones.

```world locations.locations.little_europe_14
{
	"name": "Kaito Market",
	"district": "little_europe",
	"number": 14,
	"type": "market",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Artie Murdock (Fixer 3)", "Madame Zorina (Media 5)"],
	"hooks": [
		{"text": "Imported Goods 4 Cheap is rumoured to front for an organised crime group.", "gigs": ["gang_hit", "data_theft"]},
		{"text": "Madame Zorina's fortune-telling stall is really a paid message drop.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft", "gang_hit"],
	"interior": "Stalls: Apocalypse Zone Tattoo, App Shack (knock-off software), Cheek Turn (sidearms, light armour, ammo; Artie Murdock), Fifty Farms (fresh produce), Greg's coffee truck, Imported Goods 4 Cheap, Madame Zorina, Sagar Hair Saloon (ganger-wannabe hangout), Stone Mill bakery, Taco Taco.",
	"cite": "NC2045 p.61"
}
```

### #15 Night Corp HQ

Headquarters of the self-styled heir of Richard Night: a developer and contractor behind public works from construction to garbage, which brokered the current City Council and pays people to clear the Hot Zone.

```world locations.locations.little_europe_15
{
	"name": "Night Corp HQ",
	"district": "little_europe",
	"number": 15,
	"type": "corp_hq",
	"owner": "night_corp",
	"owner_name": "Night Corp",
	"security_code": {"n": 10, "faction": "lazarus", "intensity": "heavy", "hardened": true},
	"utility_code": 2,
	"npcs": [],
	"hooks": [
		{"text": "Nobody knows what Night Corp is really up to or where its bottomless money comes from.", "gigs": ["data_theft"]},
		{"text": "Rumour: the free cyberware given to Hot Zone cleanup workers hides biomonitors that scrape medical data.", "gigs": ["data_theft", "sabotage"]},
		{"text": "Rumour: the company preys on the desperate to experiment on them.", "gigs": ["rescue", "data_theft"]}
	],
	"gigs": ["data_theft", "sabotage", "corp_extraction"],
	"interior": "",
	"cite": "NC2045 p.61"
}
```

### #16 Old Saint Christopher Center

A five-star hotel and convention centre for corporate events, lavish inside but keeping its crumbling old facade like a mask.

```world locations.locations.little_europe_16
{
	"name": "Old Saint Christopher Center",
	"district": "little_europe",
	"number": 16,
	"type": "hotel",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 8, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Word is a casino for the hotel's most exclusive guests is hidden in the basement.", "gigs": ["data_theft", "assassination"]}
	],
	"gigs": ["assassination", "data_theft"],
	"interior": "Grand lobby with a swanky bar and boutiques; attached convention centre; rumoured private casino in the basement.",
	"cite": "NC2045 p.62"
}
```

### #17 Paradiso Terrestre

Superstar chef Leonardo Calvano's ultra-exclusive private dining room, opened this year: one party at a time, cooked and served by Calvano himself.

```world locations.locations.little_europe_17
{
	"name": "Paradiso Terrestre",
	"district": "little_europe",
	"number": 17,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Leonardo Calvano (Rockerboy 7)",
	"security_code": {"n": 8, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Leonardo Calvano (Rockerboy 7)", "Polly (Fixer 3)"],
	"hooks": [
		{"text": "The underpaid dishwasher Polly leaks gossip and the reservation schedule for more than Calvano pays.", "gigs": ["assassination", "data_theft"]}
	],
	"gigs": ["assassination"],
	"interior": "Guests are fetched and returned by an armed, armoured luxury AV with an onboard mixologist; the party has the restaurant to itself.",
	"cite": "NC2045 p.62"
}
```

### #18 Red Cab Company

Main dispatch and garage of the city's largest private transport firm, famous for its armoured red groundcars and Neo-Soviet branding, in the district's rough end.

```world locations.locations.little_europe_18
{
	"name": "Red Cab Company",
	"district": "little_europe",
	"number": 18,
	"type": "transport",
	"owner": "red_cab",
	"owner_name": "Red Cab Company",
	"security_code": {"n": 6, "faction": "maelstrom", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Rumour: Red Cab ships Maelstrom's goods around the city free in return for Maelstrom's security.", "gigs": ["sabotage", "gang_hit", "data_theft"]}
	],
	"gigs": ["sabotage", "gang_hit"],
	"interior": "Garage for the groundcars and a small AV fleet, dispatch office and a small pistol range for cabbies; Maelstrom guards it.",
	"cite": "NC2045 p.62"
}
```

### #19 Revere Courier Services

The closest thing Night City has to a mail service, moved here from City Center; it earns on emergency deliveries and secure physical data transfers for corps that distrust the CitiNet.

```world locations.locations.little_europe_19
{
	"name": "Revere Courier Services",
	"district": "little_europe",
	"number": 19,
	"type": "warehouse",
	"owner": "",
	"owner_name": "Revere Courier Services",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Revere pays edgerunners promptly and well to protect high-priority shipments.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Courier depot handling routine freight in and out of the city.",
	"cite": "NC2045 p.63"
}
```

### #20 Shady Oaks Elementary

A pricey "in-person" private school that actually plugs children into custom braindance units all day while the owners pocket the fees.

```world locations.locations.little_europe_20
{
	"name": "Shady Oaks Elementary",
	"district": "little_europe",
	"number": 20,
	"type": "school",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 4, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The school's bespoke teaching is a con: kids spend the day in braindance rigs.", "gigs": ["data_theft", "rescue"]}
	],
	"gigs": ["data_theft"],
	"interior": "School building with banks of custom braindance units.",
	"cite": "NC2045 p.63"
}
```

### #21 Short Circuit

A Tech and Netrunner bar (20eb Code Freeze) that is really a tech refurbishment collective for freelancers working Hot Zone wrecks; reopened here after the 2020 original was nuked.

```world locations.locations.little_europe_21
{
	"name": "Short Circuit",
	"district": "little_europe",
	"number": 21,
	"type": "bar",
	"owner": "",
	"owner_name": "Brain (Tech 6/Netrunner 2) and 3-Piece (Fixer 5/Media 2)",
	"security_code": {"n": 9, "faction": "patrons", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": ["Brain (Tech 6/Netrunner 2)", "3-Piece (Fixer 5/Media 2)"],
	"hooks": [
		{"text": "Trusted Netrunners settle bets in The Gauntlet, a Black ICE NET Architecture arena.", "gigs": ["data_theft"]},
		{"text": "3-Piece runs a tech Night Market on the top floor for hard-to-find parts.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Rentable workshops with techprinter and microfactory (5eb/h); two NET Architectures (the Brain Bar hangout and The Gauntlet); top-floor Night Market; refurbished drones and armed regulars defend it; carbon-scored walls.",
	"cite": "NC2045 p.63"
}
```

### #22 Soprano's

The original branch of a mafia-themed pasta chain, staff dressed as hitmen serving pun-named SCOP noodles.

```world locations.locations.little_europe_22
{
	"name": "Soprano's",
	"district": "little_europe",
	"number": 22,
	"type": "restaurant",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Real wiseguys, who once ran this part of town, resent the chain as a mockery.", "gigs": ["sabotage"]}
	],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.63"
}
```

### #23 Torrell and Chiang's

A high-end tailor whose real speciality is discreet, stain-proof armoured clothing for Solos and security staff, with a dry-cleaning service that removes blood and worse.

```world locations.locations.little_europe_23
{
	"name": "Torrell and Chiang's",
	"district": "little_europe",
	"number": 23,
	"type": "shop",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Bespoke tailor shop; also runs stalls at Night and Midnight Markets.",
	"cite": "NC2045 p.64"
}
```

## Fixers

- 80/20 (Fixer 3) — back room of Chopper's (#5); second-hand cyberware, cheap and unquestioned.

- 3-Piece (Fixer 5/Media 2) — Short Circuit (#21); runs 3-Piece's Joint, a tech Night Market on the top floor.

- Artie Murdock (Fixer 3) — Cheek Turn stall, Kaito Market (#14); sidearms, light armour, ammunition.

- Fast Eddie (Fixer 1) — Continental Brands Vertical Neighborhood (#6); guide through the maze, 10eb.

- Polly (Fixer 3) — dishwasher at Paradiso Terrestre (#17); sells restaurant gossip and reservations.


## Personalities

- 3-Piece (Fixer 5/Media 2): runs the tech Night Market above Short Circuit and a business-advice Garden Patch.

- 80/20 (Fixer 3): second-hand cyberware dealer working out of Chopper's.

- Dillon Murphy (Solo 6): the "White Knight of Night City", a mostly retired troubleshooter who protects the defenceless for little pay.

- Dimitri (Nomad 4): gossipy Red Cab driver who knows the Island's streets; rumoured founder or ex-leader of the Eurotrashers.

- Fast Eddie (Fixer 1): the most respected (or feared) guide kid at the Continental Brands Vertical Neighborhood.

- Father Kevin (Solo 7): Irish ex-Solo turned priest; gives sanctuary and mediates disputes.

- Jack Sawyer (Tech 6): weaponsmith working for Faisal and pool shark at Greta's; sister of Danger Gal's Lynx, rumoured lover of Marie-Louise Malour.

- Kate Mulvaney (Solo 6): SouthAm War vet who owns Fiddler's Green; spars with Father Kevin, dislikes Dillon Murphy.

- Kenshiro Saeba (Lawman 6/Solo 6): "The Night Hunter", PI who finds missing people; still in love with Yasume Kanzaki, whom her brother Shin keeps from him.

- Polly (Fixer 3): Paradiso Terrestre dishwasher selling information to get a better job.

- Michiko Sanderson (Exec 10): Danger Gal's CEO, bubbly detective in public and ruthless businesswoman in private; married to detective Marc Sanderson.
