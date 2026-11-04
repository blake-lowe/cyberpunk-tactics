# University District

The district grew up around Night City University, the city's only surviving university. Long-serving Dean Edward
Michaels walled the campus in and armed it to get through the 4th Corporate War (NC2045 p.104-105). To keep it
running, he later gave Biotechnica two of the five trustee seats and land for its regional HQ, and the east side of
the district is now a Biotechnica campus of domes. NCU Campus Security, known as "the Maxes", mostly wants things
kept quiet, but it has an armoury of heavy weapons for when boostergangs such as the Kill Krashers attack. Two odd
gangs live here: the Philharmonic Vampyres and the Princesses of Justice.

```world city.districts.university_district
{
	"name": "University District",
	"region": "island",
	"manager": {"name": "Dr. Edward Michaels", "role": "Exec 4/Fixer 6/Tech 4"},
	"population": "NCU students and faculty around the walled campus, professors in brick houses further out, Biotechnica scientists and staff in the east; most support workers commute in",
	"security_code": {"n": 6, "faction": "ncu_campus_security", "intensity": "light", "hardened": true},
	"utility_code": 5,
	"provider": "ncu_campus_security",
	"gangs": ["dirty_hippies", "philharmonic_vampyres", "piranhas", "princesses_of_justice", "voodoo_boys", "kill_krashers"],
	"ncart": ["NCU Station", "Biotechnica Station"],
	"profile": "mixed_residential",
	"look": ["walled campus", "brown brick", "geodesic domes", "student bars", "razor wire and gun emplacements"],
	"history": "The Dean used NCU's endowment to buy the council seat and fortified the campus through the war, then traded Biotechnica board seats and an HQ site for cash.",
	"cite": "NC2045 p.104-113"
}
```

## Locations

### #1 94.4 NCU Radio
The campus radio station is also a sticky local nightclub with small-time bands. Campus Security raids it about once
a month to enforce the 3 a.m. noise limit. Piranhas dance and deal here most nights.

```world locations.locations.university_district_1
{
	"name": "94.4 NCU Radio",
	"district": "university_district",
	"number": 1,
	"type": "club",
	"owner": "",
	"owner_name": "NCU campus radio",
	"security_code": {"n": 5, "faction": "ncu_campus_security", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "A run-down brick building with a stage and a bar whose drink machine never gets the order right.",
	"cite": "NC2045 p.107"
}
```

### #2 Biograph Theater
A two-screen theatre from the 1970s that still uses film projectors. The porn screen pays for the art-house screen.

```world locations.locations.university_district_2
{
	"name": "Biograph Theater",
	"district": "university_district",
	"number": 2,
	"type": "venue",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 4, "faction": "ncu_campus_security", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Two screens, with film projectors kept running by volunteer engineering students.",
	"cite": "NC2045 p.107"
}
```

### #3 Biotechnica Campus
Biotechnica's regional HQ and home of its Home and Garden division. Only one dome, a zoo and museum, is open to the
public. Locals report hearing metal scraping, howls and screams from behind the fences at night.

```world locations.locations.university_district_3
{
	"name": "Biotechnica Campus",
	"district": "university_district",
	"number": 3,
	"type": "corp_hq",
	"owner": "biotechnica",
	"owner_name": "Biotechnica",
	"security_code": {"n": 10, "faction": "biotechnica", "intensity": "heavy", "hardened": true},
	"utility_code": 3,
	"npcs": ["Hugh Hunter (Tech 4)"],
	"hooks": [
		{"text": "Strange metal-on-metal sounds, howls and screams come from the locked domes at night, which doesn't fit Biotechnica's claim that the work there is botanical.", "gigs": ["data_theft", "sabotage"]},
		{"text": "Hugh Hunter, a cyberpet cloning technician, smuggles rejected pets off campus to new homes.", "gigs": ["corp_extraction", "data_theft"]}
	],
	"gigs": ["data_theft", "sabotage", "corp_extraction"],
	"interior": "Office blocks, geodesic domes and rooftop terraces. Attraction Sphere Sigma is public (zoo, natural-history museum, Cyberpets); the other domes are locked. Armed guards patrol constantly with Custom Security Canines. A small green space survives from old Lake Park.",
	"cite": "NC2045 p.107"
}
```

### #4 Biotechnica Habitation Sphere Alpha
About half of Biotechnica's workforce lives in this dome. Tunnels with harsh decontamination stations link it to the
other domes and offices.

```world locations.locations.university_district_4
{
	"name": "Biotechnica Habitation Sphere Alpha",
	"district": "university_district",
	"number": 4,
	"type": "housing",
	"owner": "biotechnica",
	"owner_name": "Biotechnica",
	"security_code": {"n": 10, "faction": "biotechnica", "intensity": "heavy", "hardened": true},
	"utility_code": 3,
	"npcs": [],
	"hooks": [
		{"text": "Workers won't say why decontamination is so harsh; the narrator suspects drug or chemical-weapon development.", "gigs": ["data_theft", "corp_extraction"]}
	],
	"gigs": ["data_theft", "corp_extraction"],
	"interior": "A residential dome tied into the campus by tunnels with decontamination stations.",
	"cite": "NC2045 p.107"
}
```

### #5 Campus Chapel
A non-denominational chapel on campus that runs mostly Christian services, food drives and outreach.

```world locations.locations.university_district_5
{
	"name": "Campus Chapel",
	"district": "university_district",
	"number": 5,
	"type": "church",
	"owner": "",
	"owner_name": "NCU (Minister Hilda Gustav)",
	"security_code": {"n": 8, "faction": "ncu_campus_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Minister Hilda Gustav"],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.108"
}
```

### #6 Carriage Street Books/Afterwords Café
A bookshop that sells course chips. Upstairs is a café serving real-bean coffee, which Biotechnica supplies as a PR
gesture.

```world locations.locations.university_district_6
{
	"name": "Carriage Street Books/Afterwords Café",
	"district": "university_district",
	"number": 6,
	"type": "shop",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 6, "faction": "ncu_campus_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Bookshop on the ground floor; study café upstairs.",
	"cite": "NC2045 p.108"
}
```

### #7 Fashion Cuts
A salon behind the bookshop that does hair and installs fashionware. The owner is one of the best stylists in the city.

```world locations.locations.university_district_7
{
	"name": "Fashion Cuts",
	"district": "university_district",
	"number": 7,
	"type": "shop",
	"owner": "",
	"owner_name": "Sam Yurrid (Medtech 4)",
	"security_code": {"n": 4, "faction": "ncu_campus_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Sam Yurrid (Medtech 4)"],
	"hooks": [
		{"text": "The Piranhas have tried several times to recruit Sam, who would rather own a shop than join a gang.", "gigs": ["gang_hit"]}
	],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.108"
}
```

### #8 Food Truck Plaza
Food trucks rotate through a plaza of metal picnic tables, and NCU charges them for parking.

```world locations.locations.university_district_8
{
	"name": "Food Truck Plaza",
	"district": "university_district",
	"number": 8,
	"type": "market",
	"owner": "",
	"owner_name": "NCU",
	"security_code": {"n": 8, "faction": "ncu_campus_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Mister Hung (Exec 2)", "Psi Britcher (Tech 3)"],
	"hooks": [],
	"gigs": [],
	"interior": "Trucks include Buck-a-Slice, Captain Cajun's, Green Pretzels (made with Shroomer lichen), Happy Noodles, Kibble Cookie Kraze, Ramen Late, SoSushiMe and a vendit wagon. The NCU Yum app (5eb) tracks where they are.",
	"cite": "NC2045 p.108"
}
```

### #9 Kosmos Hospital
A small private hospital and vet clinic with top equipment. Downtown's Chamber of Commerce pays for it, and it treats
only rich patients from Downtown, not students.

```world locations.locations.university_district_9
{
	"name": "Kosmos Hospital",
	"district": "university_district",
	"number": 9,
	"type": "medical",
	"owner": "",
	"owner_name": "Downtown Chamber of Commerce",
	"security_code": {"n": 10, "faction": "whitewater_security", "intensity": "heavy", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["corp_extraction"],
	"interior": "",
	"cite": "NC2045 p.108-109"
}
```

### #10 Night City Symphony Hall
A grand concert hall that stood empty after the war until the Philharmonic Vampyres moved in seven years ago. They
restored it, and it is now their HQ and stage.

```world locations.locations.university_district_10
{
	"name": "Night City Symphony Hall",
	"district": "university_district",
	"number": 10,
	"type": "gang_base",
	"owner": "philharmonic_vampyres",
	"owner_name": "Philharmonic Vampyres (The Master, Rockerboy 6/Tech 2)",
	"security_code": {"n": 5, "faction": "ncu_campus_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["The Master (Rockerboy 6/Tech 2)", "Acme (Tech 4)"],
	"hooks": [
		{"text": "The Master's goth faction is at odds with Acme's prankster wing over where the gang is headed.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit"],
	"interior": "Marble staircase, columns, huge doors and a red-velvet lobby. The gang uses it as HQ and stage; this semester's show is a mixed-style Dracula.",
	"cite": "NC2045 p.109"
}
```

### #11 Night City University
Founded in 1994, NCU has over 7,000 students and faculty, all now inside the walled central campus. Tuition is
1,000eb per credit. NCU sometimes cuts or waives fees for edgerunners and nomads who work for it.

```world locations.locations.university_district_11
{
	"name": "Night City University",
	"district": "university_district",
	"number": 11,
	"type": "school",
	"owner": "ncu_campus_security",
	"owner_name": "Night City University (Dean Edward Michaels, Exec 4/Fixer 6/Tech 4)",
	"security_code": {"n": 9, "faction": "ncu_campus_security", "intensity": "medium", "hardened": true},
	"utility_code": 4,
	"npcs": ["Dr. Edward Michaels (Exec 4/Fixer 6/Tech 4)", "Renee Dorn (Solo 5)", "Professor Alice Bloom (Netrunner 5/Tech 7)", "Melanie Brooks (Medtech 4)", "Professor Trunk (Nomad 4)", "Rip Jackson (Nomad 6)", "Jackson Row (Exec 1)"],
	"hooks": [
		{"text": "Continental Brands is lobbying the trustees to replace the campus bodega with an Oasis, and Petrochem wants a Hundred Under Haven there instead.", "gigs": ["sabotage", "data_theft"]},
		{"text": "Knute Hall houses NCU's private CitiNet, run by a department head who helped build the Old Net.", "gigs": ["data_theft"]},
		{"text": "A professor exposed as a serial killer of students was stopped by edgerunners, not Campus Security, and students backed by the Princesses are thinking of protesting.", "gigs": []}
	],
	"gigs": ["data_theft", "sabotage", "corp_extraction"],
	"interior": "A walled campus of 13 buildings (11a-m). Administration (dean's office; Faculty Club in the basement). Blaine Building (social sciences; the Max-Pad security HQ in the basement). Brooks Library (underground study cells). The Cells (dorms with a shared lounge every other floor). Howard Wong Building (business). Michaels Hall (humanities). Knute Hall (computer science, private CitiNet). Loggagia Science Labs (scaffolded until 2047). Lombardy Groceries (bodega). NCU Clinic (ripperdoc). Schumacher Hall (arts). Science Tower (tallest; labs below, offices in the top third). Thompson Hall (gym, track, courts, firing range).",
	"cite": "NC2045 p.109-110"
}
```

### #12 Parkside Living
A studio apartment building let mostly to NCU students, close to campus and to The Glen's clubs. Its lobby lounge is
the best place in the district for gossip.

```world locations.locations.university_district_12
{
	"name": "Parkside Living",
	"district": "university_district",
	"number": 12,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "ncu_campus_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Studio flats above a main-floor lounge.",
	"cite": "NC2045 p.110"
}
```

### #13 Princessland
A travelling carnival was abandoned near NCU when the war broke out. The Princesses of Justice turned it into their
fortified home and a shelter for people escaping abuse.

```world locations.locations.university_district_13
{
	"name": "Princessland",
	"district": "university_district",
	"number": 13,
	"type": "gang_base",
	"owner": "princesses_of_justice",
	"owner_name": "Princesses of Justice (Adorable, Solo 6)",
	"security_code": {"n": 10, "faction": "princesses_of_justice", "intensity": "heavy", "hardened": false},
	"utility_code": null,
	"npcs": ["Adorable (Solo 6)"],
	"hooks": [
		{"text": "Abusers who follow their victims to the shelter run into the Princesses' very real weapons.", "gigs": ["rescue"]},
		{"text": "Adorable personally killed her roommate's murderer, the son of a prominent Biotechnica exec.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit", "rescue"],
	"interior": "An old carnival ground. Open spaces are now gardens, the rides are fortifications and the stalls are housing. The gates turn away anyone who isn't bringing gifts or help.",
	"cite": "NC2045 p.110-111"
}
```

### #14 Retail Resale
A consignment clothing shop in an old, creaky building. Clothes too worn to sell are given to the Princesses to make
blankets.

```world locations.locations.university_district_14
{
	"name": "Retail Resale",
	"district": "university_district",
	"number": 14,
	"type": "shop",
	"owner": "",
	"owner_name": "Bebe Gcabashe (Fixer 3)",
	"security_code": {"n": 3, "faction": "ncu_campus_security", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": ["Bebe Gcabashe (Fixer 3)"],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.111"
}
```

### #15 Stems & Seeds
A fortified four-storey brick grow-house outside the campus walls. It sells produce at a day market and by coded
special order, and it moves Dirty Hippies weed.

```world locations.locations.university_district_15
{
	"name": "Stems & Seeds",
	"district": "university_district",
	"number": 15,
	"type": "shop",
	"owner": "",
	"owner_name": "Lily Larson (Medtech 4/Tech 2) and two partners",
	"security_code": {"n": 7, "faction": "ncu_campus_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Lily Larson (Medtech 4/Tech 2)"],
	"hooks": [
		{"text": "Because of an alliance with the Dirty Hippies, customers can collect ganja shipments here alongside their coded veg orders.", "gigs": ["gang_hit", "sabotage"]}
	],
	"gigs": ["gang_hit", "sabotage"],
	"interior": "Four floors of grow lights behind metal window shutters, with a turret on each corner and a day market outside.",
	"cite": "NC2045 p.111"
}
```

### #16 Tumble and Dry
A 24/7 laundromat owned by NCU, with light security. The Princesses and the Voodoo Boys often clash here.

```world locations.locations.university_district_16
{
	"name": "Tumble and Dry",
	"district": "university_district",
	"number": 16,
	"type": "shop",
	"owner": "",
	"owner_name": "NCU",
	"security_code": {"n": 4, "faction": "ncu_campus_security", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Voodoo Boys sell drugs here, and Princesses of Justice on patrol keep clashing with them.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit"],
	"interior": "",
	"cite": "NC2045 p.111"
}
```

### #17 University Crèche
NCU's childcare centre, staffed by education students. Two Campus Security guards are on site during opening hours,
and the Princesses pass by at night.

```world locations.locations.university_district_17
{
	"name": "University Crèche",
	"district": "university_district",
	"number": 17,
	"type": "school",
	"owner": "",
	"owner_name": "NCU",
	"security_code": {"n": 8, "faction": "ncu_campus_security", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Two guards on site during opening hours.",
	"cite": "NC2045 p.111"
}
```

### #18 University Cubes
A waterfront cube hotel stacked like toy blocks, with bubble windows. Its tenants are adjuncts, TAs and support staff.

```world locations.locations.university_district_18
{
	"name": "University Cubes",
	"district": "university_district",
	"number": 18,
	"type": "cube_hotel",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 4, "faction": "ncu_campus_security", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.111"
}
```

### #19 Yewtree
A bright neo-hipster bar that lets underage students in with fake IDs. It is secretly in league with Campus Security:
it never gets raided, and the cops come fast when it calls.

```world locations.locations.university_district_19
{
	"name": "Yewtree",
	"district": "university_district",
	"number": 19,
	"type": "bar",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 7, "faction": "ncu_campus_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Jessie Stuart-Hedley (Fixer 2)"],
	"hooks": [
		{"text": "Yewtree has a quiet deal with Campus Security, and its bartenders pass campus gossip on to the cops.", "gigs": []}
	],
	"gigs": [],
	"interior": "A well-lit neon bar with bouncers.",
	"cite": "NC2045 p.112"
}
```

## Fixers

- Dr. Edward Michaels (Exec 4/Fixer 6/Tech 4): Dean of NCU and City Manager. He trades favours with edgerunners and nomad clans and pays in tuition breaks (p.105, p.109).
- Bebe Gcabashe (Fixer 3): owner of Retail Resale; consignment clothing (p.111).
- Jessie Stuart-Hedley (Fixer 2): bartender at Yewtree who hears all the campus gossip and passes some to Campus Security (p.112).

## Personalities

- Acme (Tech 4), real name Kaliska Williams: engineering student who leads the Philharmonic Vampyres' prankster wing. She reprogrammed the lights on Night Corp's HQ to flip off the city (p.112).
- Adorable (Solo 6): leader of the Princesses of Justice. She killed her roommate's murderer, a Biotechnica exec's son (p.112).
- Hugh Hunter (Tech 4): Biotechnica cyberpet cloning tech who smuggles out the rejects (p.112).
- Jackson Row (Exec 1): a professor's 13-year-old son who runs errands around campus (p.112).
- Jessie Stuart-Hedley (Fixer 2): Yewtree bartender and gossip (p.112).
- The Master (Rockerboy 6/Tech 2), real name Mason Evings: leader of the Vampyres' goth wing who rarely grants an audience at the Symphony Hall (p.112).
- Professor Trunk (Nomad 4): eccentric literature professor and street racer (p.112).
- Renee Dorn (Solo 5): chief of NCU Campus Security and a former edgerunner who practically lives in her office (p.112).
- Rip Jackson (Nomad 6): history professor with a classic muscle car; rumoured to be a former edgerunner (p.112).
