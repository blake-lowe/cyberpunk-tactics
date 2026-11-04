# The Glen

The Glen is Night City's new seat of government. Night Corp and its allies built it after the 4th Corporate War over
what was half of South Night City, and it is still under near-constant construction (NC2045 p.114-117). Most
residents are corpzoners or government staff, and the district was designed for people who earn steady money. NCPD
is strong and heavy-handed here, with Lazarus or Militech on contract for important buildings; only the Exec Zone is
better guarded. Recent trouble includes a Zoner march that turned into a riot after Night Corp moved South Night City
repair money into The Glen, and a new high-rise brought down by explosives planted in its foundation. The bomb squad
now has MAX-TAC helping it check other buildings.

```world city.districts.the_glen
{
	"name": "The Glen",
	"region": "island",
	"manager": {"name": "Zohara Freeman", "role": "Exec 7/Solo 2"},
	"population": "very multicultural; mostly corpzoners and government employees, a district built for steady earners",
	"security_code": {"n": 8, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": 3,
	"provider": "ncpd",
	"gangs": ["deadwoods", "julliard_guild", "kill_krashers", "piranhas", "reckoners", "voodoo_boys"],
	"ncart": ["City Hall Station", "Harlem Street", "MA&F Station"],
	"profile": "corporate_center",
	"look": ["civic monuments", "glass towers", "construction cranes", "green plazas", "checkpoints and drones"],
	"history": "Built by Night Corp and its allies after the war on half of old South Night City to hold the new government; the Night Corp board appointed its City Manager last year.",
	"cite": "NC2045 p.114-127"
}
```

## Locations

### #1 1st Night City Bank
The bank where most of the city's earners keep their money. Night Corp also uses it to pay out funds to the companies
and people who keep the city running, and about half of all cash spent in Night City passes through it.

```world locations.locations.the_glen_1
{
	"name": "1st Night City Bank",
	"district": "the_glen",
	"number": 1,
	"type": "bank",
	"owner": "first_night_city_bank",
	"owner_name": "1st Night City Bank",
	"security_code": {"n": 11, "faction": "militech", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Night Corp's money for the city's contractors and companies passes through this bank.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft", "sabotage"],
	"interior": "The ground floor is public: marble, bulletproof windows, human tellers and side offices for loans. The vault is on the second floor, and getting between floors takes an ID card and a retina scan. On-site security and NCPD watch the cameras 24/7.",
	"cite": "NC2045 p.117"
}
```

### #2 96.1 Fever Dream
A Reckoner radio station near the Old Japantown border that broadcasts end-times sermons. Now and then a mysterious DJ,
Sickle's Tear, cuts in with excellent techno.

```world locations.locations.the_glen_2
{
	"name": "96.1 Fever Dream",
	"district": "the_glen",
	"number": 2,
	"type": "media",
	"owner": "reckoners",
	"owner_name": "The Reckoners",
	"security_code": {"n": 5, "faction": "reckoners", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": ["Sickle's Tear (Rockerboy 4)"],
	"hooks": [
		{"text": "Urban legends say Sickle's Tear's tracks carry subliminal messages; DJ Nova says they don't.", "gigs": []}
	],
	"gigs": ["gang_hit", "sabotage"],
	"interior": "",
	"cite": "NC2045 p.117"
}
```

### #3 Air
An oxygen bar for corpzoners: a sterile white cube with masks hanging over the bars. A one-minute hit costs 10eb.

```world locations.locations.the_glen_3
{
	"name": "Air",
	"district": "the_glen",
	"number": 3,
	"type": "bar",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Glass bars, rows of oxygen masks and steel stools.",
	"cite": "NC2045 p.117-118"
}
```

### #4 Archer & Li
Two former street kids bluffed their way into designing Thurgood Towers for Night Corp. When the building turned out
well, they were given backdated architecture degrees, and their firm has been in demand ever since.

```world locations.locations.the_glen_4
{
	"name": "Archer & Li",
	"district": "the_glen",
	"number": 4,
	"type": "corp_office",
	"owner": "",
	"owner_name": "Jamal Archer (Exec 6) and Zhao Li (Fixer 6)",
	"security_code": {"n": 8, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Jamal Archer (Exec 6)", "Zhao Li (Fixer 6)", "Patricia Hawthorn (Tech 4)"],
	"hooks": [
		{"text": "Patricia Hawthorn, a junior architect buried in student debt, will sell blueprints for bribes.", "gigs": ["data_theft"]},
		{"text": "The partners' architecture degrees were quietly backdated to cover how they won the Thurgood Towers contract.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "An office next to Thurgood Towers.",
	"cite": "NC2045 p.118"
}
```

### #5 Bear's
A microbrewery named after its huge owner, who also does the bouncing. The Berry Beer, a 9% blackberry ale, costs 10eb.

```world locations.locations.the_glen_5
{
	"name": "Bear's",
	"district": "the_glen",
	"number": 5,
	"type": "bar",
	"owner": "",
	"owner_name": "Bear Young (Solo 5)",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Bear Young (Solo 5)"],
	"hooks": [],
	"gigs": [],
	"interior": "A brewpub with an old bear's head over the bar and a short SCOP menu.",
	"cite": "NC2045 p.118"
}
```

### #6 Beth El Congregation
The city's largest Reform synagogue. A crashing GRAF3 badly damaged it in 2042, and it has just reopened as a
three-storey Art Deco building that seats more than a thousand. NCPD quadruples its presence on the high holidays.

```world locations.locations.the_glen_6
{
	"name": "Beth El Congregation",
	"district": "the_glen",
	"number": 6,
	"type": "church",
	"owner": "",
	"owner_name": "Rabbi Avis Solomon (Media 8)",
	"security_code": {"n": 9, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Rabbi Avis Solomon (Media 8)"],
	"hooks": [],
	"gigs": [],
	"interior": "Three storeys, seating for more than 1,000, and 20 full-time staff.",
	"cite": "NC2045 p.118-119"
}
```

### #7 City Hall
A new wooden, colonial-style City Hall, opened in 2037 and heavily defended. So many lobbyists and staff pass through
that a careful intruder can slip in.

```world locations.locations.the_glen_7
{
	"name": "City Hall",
	"district": "the_glen",
	"number": 7,
	"type": "civic",
	"owner": "city_government",
	"owner_name": "Night City government (City Manager Zohara Freeman, Exec 7/Solo 2)",
	"security_code": {"n": 10, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Zohara Freeman (Exec 7/Solo 2)", "Edna Wilston (Fixer 4)"],
	"hooks": [
		{"text": "There is so much foot traffic that it's easy to slip into City Hall unnoticed if you're smart about it.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": ["data_theft", "sabotage", "assassination"],
	"interior": "A wooden government building guarded by turrets, scanners, drones and NCPD's best, with maintenance crews working round the clock.",
	"cite": "NC2045 p.119"
}
```

### #8 Club Atlantis
A flashy multilevel club owned by the city's biggest Fixer. Danger Gal keeps gangers out. Suits unwind here while
Fixers make deals and collect blackmail.

```world locations.locations.the_glen_8
{
	"name": "Club Atlantis",
	"district": "the_glen",
	"number": 8,
	"type": "club",
	"owner": "",
	"owner_name": "Mister Kernaghan (Fixer 9)",
	"security_code": {"n": 11, "faction": "danger_gal", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Mister Kernaghan (Fixer 9)", "DJ Nova (Rockerboy 6)"],
	"hooks": [
		{"text": "Fixers work the corporate crowd here to make connections or gather blackmail.", "gigs": ["data_theft"]},
		{"text": "Kernaghan's invite-only Midnight Market on the top two floors sells luxury goods to guests who can spend 10k eb.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": ["data_theft", "assassination"],
	"interior": "Several levels with sliding staircases, moving mirror walls, robot dancers and a floating stage over the dance floor. The Midnight Market is on the top two floors, and Piranha dealers work the parking lot. The signature drink, the HALO Drop, costs 100eb.",
	"cite": "NC2045 p.119"
}
```

### #9 Consulate Causeway
The foreign missions sit behind a huge concrete wall. The only ways in are by AV or through two gates guarded by
Lazarus, with access codes, layered biometric scans and escorts for visitors.

```world locations.locations.the_glen_9
{
	"name": "Consulate Causeway",
	"district": "the_glen",
	"number": 9,
	"type": "civic",
	"owner": "",
	"owner_name": "foreign governments (six missions)",
	"security_code": {"n": 10, "faction": "lazarus", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Saoirse Gallagher (Exec 5)", "Masaru Hayanami (Exec 6)", "Ariel Flores (Fixer 6)", "Josiah Jackson (Exec 5)", "Francisco Andrés Pineda (Exec 5)", "Kris Kane (Fixer 8)"],
	"hooks": [
		{"text": "Arasaka agents are rumoured to work out of the Japanese consulate.", "gigs": ["data_theft", "assassination"]},
		{"text": "It is an open secret that the US consulate hides intelligence operatives spying on NorCal with reunification in mind.", "gigs": ["data_theft", "corp_extraction"]},
		{"text": "Persons unknown broke into the Southern California official's office at the US consulate and spray-painted TRAITOR on the walls.", "gigs": ["sabotage"]}
	],
	"gigs": ["data_theft", "assassination", "corp_extraction"],
	"interior": "A walled compound with a gatehouse where visitors wait for escorts. Missions: 9a EEC consulate (code 10, EEC troops, hardened light, 8 resident officials); 9b Japanese consulate (code 10, Japanese Self-Defence Force, hardened heavy, 20+ officials); 9c Mexican consulate (code 10, Mexican Army with chromed plain-clothes operatives, heavy); 9d Pacifica Confederation offices (code 10, NorCal Marshals, hardened heavy); 9e Organization of American States mission (code 10, OAS troops, heavy); 9f US consulate (code 10, Militech, hardened heavy, 4 resident officials plus the SoCal representative).",
	"cite": "NC2045 p.119-120"
}
```

### #10 Diplomatic Immunity
An exclusive two-storey club where dignitaries meet their local contacts. Entry needs a silver card printed with the
appointment, and the basement holds a sex club for the political elite.

```world locations.locations.the_glen_10
{
	"name": "Diplomatic Immunity",
	"district": "the_glen",
	"number": 10,
	"type": "club",
	"owner": "",
	"owner_name": "a Fixer posing as a low-level City Hall official (rumoured)",
	"security_code": {"n": 9, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The basement sex club, posing as a secret society, caters to politicians from a dozen countries, and the Weng Fang Tong supplies the workers.", "gigs": ["data_theft"]},
		{"text": "The club is rumoured to belong to a Fixer who poses as a minor City Hall official.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft", "assassination"],
	"interior": "A two-storey box with three entrances, each guarded inside by chromed bodyguards in suits. The sex club is in the basement.",
	"cite": "NC2045 p.120"
}
```

### #11 DMV
The hated vehicle registry, inconveniently placed in the sub-basement of the AV Traffic Control Tower.

```world locations.locations.the_glen_11
{
	"name": "DMV",
	"district": "the_glen",
	"number": 11,
	"type": "civic",
	"owner": "city_government",
	"owner_name": "Night City government",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "In the sub-basement of the AV Traffic Control Tower.",
	"cite": "NC2045 p.121"
}
```

### #12 EuroBank
The regional EuroBank is also the city's mint, printing both physical and digital eurobucks. The money printing is
controlled by an AI, John Good, and Netwatch keeps an office on site.

```world locations.locations.the_glen_12
{
	"name": "EuroBank",
	"district": "the_glen",
	"number": 12,
	"type": "bank",
	"owner": "eurobank",
	"owner_name": "EuroBank",
	"security_code": {"n": 11, "faction": "lazarus", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["John Good (Netrunner 10, AI)"],
	"hooks": [
		{"text": "The mint's printing is run by the AI John Good inside guarded NET Architectures, with Netwatch on site.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft", "sabotage"],
	"interior": "A two-storey, block-long faux-Tudor building behind an electric fence, with steel-reinforced walls and screens instead of windows. It has an unknown number of secret sublevels (probably 3-4). Inside: layered biometrics, full-body scanners, many armed guards and several NET Architectures staffed 24/7. Divisions: retail, investment, loans and the mint.",
	"cite": "NC2045 p.121"
}
```

### #13 First Baptist Church of Night City
The oldest building on the Island, founded in the 1850s by Black parishioners who had escaped slavery. Richard Night
had it moved here brick by brick. 6th Street guards it as "community outreach".

```world locations.locations.the_glen_13
{
	"name": "First Baptist Church of Night City",
	"district": "the_glen",
	"number": 13,
	"type": "church",
	"owner": "",
	"owner_name": "Reverend Ernest Turk (Rockerboy 6)",
	"security_code": {"n": 8, "faction": "6th_street", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Reverend Ernest Turk (Rockerboy 6)"],
	"hooks": [
		{"text": "Reverend Turk is rumoured to sympathise with the Zoners and to hide their members when needed.", "gigs": ["rescue"]}
	],
	"gigs": [],
	"interior": "A three-storey brick church.",
	"cite": "NC2045 p.121"
}
```

### #14 Glenlife Perfected
An apartment block that looks glamorous from the street and is a cramped, mildewed firetrap inside. Being so close to
City Hall makes it safe from gunfire, at least.

```world locations.locations.the_glen_14
{
	"name": "Glenlife Perfected",
	"district": "the_glen",
	"number": 14,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 6, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "A showy lobby and manager's office. Above them: a barely working elevator, flickering power and many tiny studios per floor.",
	"cite": "NC2045 p.121"
}
```

### #15 Hall of Justice
A brutalist, medieval-style courthouse and jail designed to frighten. The worse the crime, the higher the floor it is
tried on. Executions and public electro-whippings take place in an amphitheatre outside, where tickets are sold.

```world locations.locations.the_glen_15
{
	"name": "Hall of Justice",
	"district": "the_glen",
	"number": 15,
	"type": "police",
	"owner": "city_government",
	"owner_name": "Night City government",
	"security_code": {"n": 11, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["The Judge (Netrunner 10, AI)", "Doctor Kirk Klau (Medtech 4/Tech 5)", "Donald Daniel Draper"],
	"hooks": [
		{"text": "The judicial AI, The Judge, is rumoured to sit in a NET Architecture on the top floor, and a Netwatch AV is always parked on the roof.", "gigs": ["data_theft", "sabotage"]},
		{"text": "In eight years no one has escaped from the underground cells without an expensive lawyer.", "gigs": ["rescue"]},
		{"text": "Donald Daniel Draper, a clerk in the DA's office, leaks and loses data for the Weng Fang Tong to pay off his gambling debts.", "gigs": ["data_theft"]}
	],
	"gigs": ["rescue", "data_theft", "sabotage"],
	"interior": "Towers, black steel doors and a portcullis. The stone halls echo, and drones, scanners and automated defences cover every room; NCPD stop-and-frisks staff at random. Civil matters on the lower floors, the DA and senior clerks in the middle, criminal trials on the upper floors. Prisoners are packed underground in tiny cells rigged with chemsprayers. The execution amphitheatre outside charges 20eb for a seat, 100eb for premium.",
	"cite": "NC2045 p.122"
}
```

### #16 Kasim's
A Turkish coffee and water-pipe house that serves no alcohol. The coffee and tobacco come from the owner's contacts
among the Thelas, and his mother runs the kitchen and reads coffee grounds. Closed on Fridays.

```world locations.locations.the_glen_16
{
	"name": "Kasim's",
	"district": "the_glen",
	"number": 16,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Kasymbek (Fixer 4)",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Kasymbek (Fixer 4)", "Elif (Tech 4)"],
	"hooks": [],
	"gigs": [],
	"interior": "Comfortable chairs and water pipes. Coffee is 10eb a cup, tobacco 20eb a packet.",
	"cite": "NC2045 p.122"
}
```

### #17 Lazarus Regional HQ
The Pacifica Confederation command of the elite mercenary company, housed in a plain converted community centre. It
handles administration; training happens in South Night City and elsewhere.

```world locations.locations.the_glen_17
{
	"name": "Lazarus Regional HQ",
	"district": "the_glen",
	"number": 17,
	"type": "military",
	"owner": "lazarus",
	"owner_name": "Lazarus (Colonel Viola Basset, Exec 7/Solo 6)",
	"security_code": {"n": 11, "faction": "lazarus", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Colonel Viola Basset (Exec 7/Solo 6)"],
	"hooks": [],
	"gigs": ["data_theft", "sabotage"],
	"interior": "A plain-looking building with reinforced walls, guarded by staff and technology inside.",
	"cite": "NC2045 p.122"
}
```

### #18 Le Jardin
A very expensive Baroque restaurant outside the Causeway gates, owned by an unnamed French company that is said to be
looking at a second site in Charter Hill.

```world locations.locations.the_glen_18
{
	"name": "Le Jardin",
	"district": "the_glen",
	"number": 18,
	"type": "restaurant",
	"owner": "",
	"owner_name": "an unnamed French company",
	"security_code": {"n": 8, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.123"
}
```

### #19 Merrill, Asukaga & Finch Offices
The financial firm occupies the top floors of Thurgood Towers: twin white skyscrapers joined by walkways every ten
floors. It takes new clients by referral only, and every visitor gets an armed escort.

```world locations.locations.the_glen_19
{
	"name": "Merrill, Asukaga & Finch Offices",
	"district": "the_glen",
	"number": 19,
	"type": "corp_office",
	"owner": "merrill_asukaga_finch",
	"owner_name": "Merrill, Asukaga & Finch",
	"security_code": {"n": 9, "faction": "lazarus", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Lisa Parker (Exec 5)"],
	"hooks": [
		{"text": "Every employee has a brain implant that opens doors and elevators, and it is rumoured to explode if the firm decides they have betrayed it.", "gigs": ["corp_extraction"]}
	],
	"gigs": ["data_theft", "corp_extraction", "assassination"],
	"interior": "Twin towers with walkways every 10 floors. MA&F has the top floors, reached by appointment only with armed escorts, plus the usual guards, defences and cameras. About half the other floors are empty. Ground-floor tenants: 2A, a shooting range and gun shop (east tower); Ebony Chair barbers and the Body Lotto Office (west tower).",
	"cite": "NC2045 p.123"
}
```

### #20 The Molly May
The DeadWoods' sprawling three-storey Western-themed casino and hotel. The house always has the edge.

```world locations.locations.the_glen_20
{
	"name": "The Molly May",
	"district": "the_glen",
	"number": 20,
	"type": "casino",
	"owner": "deadwoods",
	"owner_name": "The DeadWoods",
	"security_code": {"n": 10, "faction": "deadwoods", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Kelly Marion (blackjack dealer)", "Missy Kitty (sex worker)"],
	"hooks": [
		{"text": "Blackjack dealer Kelly Marion isn't a DeadWood and has a synthcoke habit that could get someone into the casino.", "gigs": ["data_theft", "sabotage", "gang_hit"]},
		{"text": "Missy Kitty will talk about her clients in exchange for real chocolate.", "gigs": ["data_theft"]}
	],
	"gigs": ["gang_hit", "data_theft", "sabotage"],
	"interior": "Floor 1: card casino with player pianos, two bars and a 24/7 kitchen. Floor 2: Western-style rooms at 20eb an hour or 100eb a day. The basement (supplies) and top floor (armoury, security centre, bunk room) need a rotating access code.",
	"cite": "NC2045 p.123"
}
```

### #21 NCPD Precinct #1
The fortress precinct on the border with the Old Combat Zone and Old Japantown, built to keep the boostergangs out. Its
deliberately confusing layout has hallway defences that escalate with the alert level.

```world locations.locations.the_glen_21
{
	"name": "NCPD Precinct #1",
	"district": "the_glen",
	"number": 21,
	"type": "police",
	"owner": "ncpd",
	"owner_name": "NCPD",
	"security_code": {"n": 10, "faction": "ncpd", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Deputy Chief Evie Lark (Lawman 8)"],
	"hooks": [
		{"text": "Only this precinct holds the central server of NCPD's private CitiNet and a vault of classified paper files.", "gigs": ["data_theft"]},
		{"text": "NCPD auctions seized goods in the ground-floor auditorium on the third Friday of every month.", "gigs": []},
		{"text": "Deputy Chief Lark of Special Operations hires edgerunners for off-the-books jobs.", "gigs": ["gang_hit", "rescue"]}
	],
	"gigs": ["data_theft", "rescue"],
	"interior": "Ground floor: decontamination chamber, cyberware and weapon scanner, waiting area, fine-payment machine and an armed front desk. Above and below, the corridors form a maze with stun and lethal defences. Comms centre, holding cells, armoury, morgue, crime lab, drone rookery, central server and records vault. Neighbouring towers hold the AVs, copters and TAC armoured vehicles.",
	"cite": "NC2045 p.123-124"
}
```

### #22 Night City News Today
The city's best-read screamsheet. Its owner pays well for scoops and is no one's friend, which has made him enemies
among corps, cops and gangs.

```world locations.locations.the_glen_22
{
	"name": "Night City News Today",
	"district": "the_glen",
	"number": 22,
	"type": "media",
	"owner": "",
	"owner_name": "Fred Tallson (Exec 6/Media 4)",
	"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Fred Tallson (Exec 6/Media 4)"],
	"hooks": [
		{"text": "Tallson is said to have got rich by burying stories at the Bay Journal, which he later bought and merged into NCNT.", "gigs": ["data_theft"]},
		{"text": "Tallson's sensational scoops are angering powerful people with guns.", "gigs": ["assassination"]}
	],
	"gigs": ["data_theft", "assassination"],
	"interior": "",
	"cite": "NC2045 p.124"
}
```

### #23 Night City Plaza
A free, year-round park at the heart of The Glen, with a concert stage, a Richard Night statue and a nuke memorial
that is kept under guard. Julliard Guild buskers are licensed to perform here.

```world locations.locations.the_glen_23
{
	"name": "Night City Plaza",
	"district": "the_glen",
	"number": 23,
	"type": "park",
	"owner": "city_government",
	"owner_name": "Night City government",
	"security_code": {"n": 8, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["DJ Nova (Rockerboy 6)"],
	"hooks": [],
	"gigs": [],
	"interior": "A lush park with a central concert stage. The statue and memorial on the south side are guarded.",
	"cite": "NC2045 p.124"
}
```

### #24 Raven Microcybernetics
Raven's regional offices occupy floors 40-50 of a deliberately forgettable skyscraper. The lobby has one McCain
Security desk, whose main job is to call NCPD.

```world locations.locations.the_glen_24
{
	"name": "Raven Microcybernetics",
	"district": "the_glen",
	"number": 24,
	"type": "corp_office",
	"owner": "raven_microcybernetics",
	"owner_name": "Raven Microcybernetics",
	"security_code": {"n": 10, "faction": "mccain_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Ziv Ellis (Exec 6)", "Doctor William Galen (Medtech 7)"],
	"hooks": [
		{"text": "Ziv Ellis is rumoured to have taken over Clean Sweep by assassinating its owner during the war; staff who sell client information die.", "gigs": ["data_theft", "assassination"]}
	],
	"gigs": ["data_theft", "corp_extraction"],
	"interior": "The lobby has opaque windows and a bulletproof door. Floors 1-39 hold Raven-affiliated tenants: Clean Sweep Enterprises (cleaning and bug sweeps), Dayton Aeronautics, Everest VentureWare, KillStrom Music (an EBM subsidiary) and Dr. William Galen's surgery. Raven itself is on floors 40-50.",
	"cite": "NC2045 p.124-125"
}
```

### #25 Seafoam
A cube hotel next to Club Atlantis. A rave starts there every night around 2 a.m.

```world locations.locations.the_glen_25
{
	"name": "Seafoam",
	"district": "the_glen",
	"number": 25,
	"type": "cube_hotel",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 4, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The Voodoo Boys and Reckoners deal at the rave in a quiet alliance, and the Reckoners rob passed-out guests and leave a thank-you note.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit"],
	"interior": "",
	"cite": "NC2045 p.125"
}
```

### #26 Souls Respite
A Reckoner-run refuge that hands out food, blankets and basic medical care to anyone who sits through two hours of
Harvest-of-Souls preaching.

```world locations.locations.the_glen_26
{
	"name": "Souls Respite",
	"district": "the_glen",
	"number": 26,
	"type": "church",
	"owner": "reckoners",
	"owner_name": "The Reckoners",
	"security_code": {"n": 5, "faction": "reckoners", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": ["Reverend William"],
	"hooks": [],
	"gigs": ["gang_hit"],
	"interior": "A brick building on the edge of The Glen.",
	"cite": "NC2045 p.125"
}
```

### #27 World Stock Exchange
A four-storey exchange that trades around the clock on human trading floors, since the DataKrash. NCPD needs
management's permission to enter, which makes it a handy place to lose a pursuit.

```world locations.locations.the_glen_27
{
	"name": "World Stock Exchange",
	"district": "the_glen",
	"number": 27,
	"type": "corp_office",
	"owner": "",
	"owner_name": "World Stock Exchange",
	"security_code": {"n": 11, "faction": "lazarus", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "NCPD needs at least five minutes to get permission to enter, and the Lazarus guards only chase people who cause chaos, so fugitives who look the part can hide here.", "gigs": []}
	],
	"gigs": ["data_theft"],
	"interior": "Four storeys of trading floors and brokerage offices, open 24/7.",
	"cite": "NC2045 p.125"
}
```

### #28 Worthy Housing
Cheap stacked shipping containers fitted out for full-body conversions, with big doors, reinforced floors and a
brain-solution dispenser. The residents handle their own security.

```world locations.locations.the_glen_28
{
	"name": "Worthy Housing",
	"district": "the_glen",
	"number": 28,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 10, "faction": "residents", "intensity": "heavy", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Stacked high-cube containers with oversized doors, reinforced floors and metal furniture, next to a bulk brain-solution DRGS 247.",
	"cite": "NC2045 p.125"
}
```

## Fixers

- Mister Kernaghan (Fixer 9): the city's biggest Fixer. He owns Club Atlantis and runs its elite Midnight Market in luxury goods (p.119).
- Kris Kane (Fixer 8): head of the US consulate on the Causeway (p.120).
- Zhao Li (Fixer 6): co-founder of Archer & Li; architecture and a talent for grifts (p.118).
- Ariel Flores (Fixer 6): head of the Mexican consulate; visas and Mexico-bound business (p.120).
- Kasymbek (Fixer 4): owns Kasim's and gets coffee and tobacco through Thelas contacts (p.122).
- Edna Wilston (Fixer 4): a City Hall file clerk since 2020 who knows more local gossip than anyone (p.126).
- An unnamed Fixer, rumoured to own Diplomatic Immunity while posing as a low-level City Hall official (p.120).

## Personalities

- Carrion (Solo ??): the near-mythical leader of the Kill Krashers, said to have served with Blackhand in the war (p.126).
- Crusher (Solo 8): a cyberpsycho ex-Maelstrom leader who comes out of the Hot Zone, wrecks things and vanishes; even MAX-TAC hasn't caught him (p.126).
- Donald Daniel Draper: a DA's office clerk who leaks data to pay his gambling debts to the Weng Fang Tong (p.126).
- Deputy Chief Evie Lark (Lawman 8): ex-Danger Gal investigator who runs NCPD Special Operations and hires edgerunners off the books (p.126).
- Edna Wilston (Fixer 4): a long-serving City Hall clerk and gossip (p.126).
- Kelly Marion: Molly May blackjack dealer with a synthcoke habit (p.126).
- Lisa Parker (Exec 5): a ruthless MA&F day trader who has a soft spot for street kids (p.126).
- Missy Kitty: Molly May worker who trades client gossip for chocolate (p.126).
- Patricia Hawthorn (Tech 4): an Archer & Li graduate in debt who sells blueprints (p.126).
- Reverend William: a Reckoner street preacher and disgraced cop who shares what he knows about NCPD once you've heard his sermon (p.126).
- Ziv Ellis (Exec 6): owner of Clean Sweep Enterprises, rumoured to have got it by assassination (p.126).
- DJ Nova (Rockerboy 6): the narrator; spins at Club Atlantis on Sundays and busks in Night City Plaza (p.114, p.119, p.124).
