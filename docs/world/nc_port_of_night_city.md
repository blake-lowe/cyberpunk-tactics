# Port of Night City

Night City's main sea gate, handling about seventy percent of the city's goods, run by the Thelas sea nomads under
Harbormistress "Calypso" (NC2045 p.150-151). Thelas gunships patrol the whole coastline and Thelas Marines keep
order ashore, though they leave brawls alone. The corps resent nomad control: they built the rival Heywood and
Ebunike docks, and last year a DT&R flotilla tried to force the harbour without paying fees. The Russian
Consortium fought a long shadow war with the Thelas before Calypso and Valya made peace against the corps (p.151).

```world city.districts.port_of_night_city
{
	"name": "Port of Night City",
	"region": "island",
	"manager": {"name": "Angela \"Calypso\" Ng", "role": "Nomad 10"},
	"population": "working class: young Thelas on rotation, old Night City locals, Russian transplants; Flotsam turns over constantly",
	"security_code": {"n": 7, "faction": "thelas_marines", "intensity": "heavy", "hardened": false},
	"utility_code": 4,
	"provider": "thelas_marines",
	"gangs": ["consortium", "deadwoods"],
	"ncart": ["Port Station"],
	"profile": "industrial",
	"look": ["harbour", "cranes", "container stacks", "moored ships", "rail yard"],
	"history": "The Thelas rebuilt and took over the Port after the 4th Corporate War; it split from South Night City in 2036 and now fends off corp pressure.",
	"cite": "NC2045 p.150-157"
}
```

Snake Nation nomads keep the railyards running and the Aldecaldos and Jodes handle cargo to land transport
(p.151). Every Thelas is expected to take up arms if the Port is threatened.

### #1 The Amber Room

The Port's best bar, Consortium territory, with walls of faux-amber polyresin panels copied from the Catherine
Palace (p.151-153).

```world locations.locations.port_of_night_city_1
{
	"name": "The Amber Room", "district": "port_of_night_city", "number": 1, "type": "bar",
	"owner": "consortium", "owner_name": "Valya (Fixer 6)",
	"security_code": {"n": 10, "faction": "consortium", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Valya (Fixer 6)"],
	"hooks": [
		{"text": "The amber panels are rumoured to hide secret doors for Consortium members to slip out of a firefight.", "gigs": ["gang_hit", "assassination"]},
		{"text": "To meet Valya, slip a note to the bartender; talking mob business at her bar gets you thrown out.", "gigs": []},
		{"text": "Valya fled a father she stole from; her people may be more loyal to her than to the Bratva.", "gigs": ["assassination"]}
	],
	"gigs": ["gang_hit", "assassination", "data_theft"],
	"interior": "Wall panels of near-handgun-proof faux amber, said to conceal escape doors; bouncers.",
	"cite": "NC2045 p.151"
}
```

### #2 Dock 13

The loud storefront and occasional Night Market of the salvage-hawking fixer Mr. AMAAAZE! (p.153).

```world locations.locations.port_of_night_city_2
{
	"name": "Dock 13", "district": "port_of_night_city", "number": 2, "type": "market",
	"owner": "", "owner_name": "William \"Mr. AMAAAZE!\" Maze (Fixer 8)",
	"security_code": {"n": 2, "faction": "thelas_marines", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": ["William \"Mr. AMAAAZE!\" Maze (Fixer 8)"],
	"hooks": [{"text": "Maze's crews haul off crates of junk nobody wants and he spins them into hot sellers.", "gigs": []}],
	"gigs": [],
	"interior": "A dockside storefront with blaring speakers that hosts a Night Market now and then.",
	"cite": "NC2045 p.153"
}
```

### #3 Dock 14 Studio Apartments

Decent flats ruined by being next door to Maze's shop (p.153).

```world locations.locations.port_of_night_city_3
{
	"name": "Dock 14 Studio Apartments", "district": "port_of_night_city", "number": 3, "type": "housing",
	"owner": "", "owner_name": "",
	"security_code": {"n": 5, "faction": "thelas_marines", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.153"
}
```

### #4 Dock Cargo Community

A stacked container village between Docks 16 and 17, slowly sinking into the mud (p.153).

```world locations.locations.port_of_night_city_4
{
	"name": "Dock Cargo Community", "district": "port_of_night_city", "number": 4, "type": "housing",
	"owner": "", "owner_name": "",
	"security_code": {"n": 5, "faction": "thelas_marines", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "The bottom container rows are empty and underwater; homes are stacked above, with a new row added every few years.",
	"cite": "NC2045 p.153"
}
```

### #5 Flotsam

An artificial island of small ships, kelongs and floats anchored to three wrecks in the bay: the Thelas'
nearest thing to a home settlement, where elders retire and leaders work (p.153-154).

```world locations.locations.port_of_night_city_5
{
	"name": "Flotsam", "district": "port_of_night_city", "number": 5, "type": "ship",
	"owner": "thelas_marines", "owner_name": "the Thelas nomads (Calypso, Nomad 10)",
	"security_code": {"n": 10, "faction": "thelas_marines", "intensity": "heavy", "hardened": true},
	"utility_code": 3,
	"npcs": ["Angela \"Calypso\" Ng (Nomad 10)", "the Skipper (Nomad 4)", "Reverend Father Adelphe (Nomad 3)", "Keelhaul (Nomad 2)"],
	"hooks": [],
	"gigs": ["sabotage", "data_theft"],
	"interior": "A shifting village between three anchor ships: the OGV Lund (war-adrift container ship, under 2,000 of 5,000 containers salvaged), the Rose (submarine hub of Thelas comms, with the tug pilots' lounge) and the Sakata Maru (ex-Arasaka munitions ship, Port admin and Calypso's office, anti-aircraft guns); the Randy Dandy ferry-bar and a Greek Orthodox chapel.",
	"cite": "NC2045 p.153"
}
```

### #6 Harbor Patrol HQ

Base of the Thelas Marines who guard the Port and the city's waters (p.154).

```world locations.locations.port_of_night_city_6
{
	"name": "Harbor Patrol HQ", "district": "port_of_night_city", "number": 6, "type": "police",
	"owner": "thelas_marines", "owner_name": "Thelas Marines",
	"security_code": {"n": 8, "faction": "thelas_marines", "intensity": "heavy", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["sabotage", "rescue"],
	"interior": "Square three-storey block between thick concrete barriers: ground floor maintenance and armory; upper floors on-call bunks, briefing rooms, sickbay, mess; basement firing range, brig, medical station. Six patrol boats (three out at a time) and a garage of armoured groundcars.",
	"cite": "NC2045 p.154"
}
```

### #7 Main Port

The Thelas-built loading quays, working around the clock and moving about a third of the Pacifica
Confederation's goods (p.154-155).

```world locations.locations.port_of_night_city_7
{
	"name": "Main Port", "district": "port_of_night_city", "number": 7, "type": "docks",
	"owner": "thelas_marines", "owner_name": "the Thelas nomads",
	"security_code": {"n": 10, "faction": "thelas_marines", "intensity": "heavy", "hardened": true},
	"utility_code": 3,
	"npcs": [],
	"hooks": [{"text": "Corps like DT&R keep testing the Thelas' grip; the dry dock's first job was a DT&R ship from last year's clash over unpaid fees.", "gigs": ["sabotage"]}],
	"gigs": ["sabotage", "data_theft"],
	"interior": "Quay 1 (6 m, hand-offloaded, two ships); Quays 2-3 (9-12 m, two container cranes each, rail to the Yard, two ships each); Quay 4 (over 15 m, one ship, cranes plus a cargo-drone hangar and control); Quay 5 half built, for dangerous cargo; a dry dock.",
	"cite": "NC2045 p.154"
}
```

### #8 Maritime Supply

A general, marine-tech and clothing shop in a gutted machine shop, run by a respected ex-hauler fixer (p.155).

```world locations.locations.port_of_night_city_8
{
	"name": "Maritime Supply", "district": "port_of_night_city", "number": 8, "type": "shop",
	"owner": "", "owner_name": "Della Glass (Fixer 5)",
	"security_code": {"n": 7, "faction": "thelas_marines", "intensity": "heavy", "hardened": false},
	"utility_code": null,
	"npcs": ["Della Glass (Fixer 5)"],
	"hooks": [{"text": "Della Glass has high-seas work for edgerunners who get on her good side.", "gigs": []}],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.155"
}
```

### #9 Medical Technologies

A waterfront body bank that grows replacement limbs and installs cyberware without asking where it came from
(p.155).

```world locations.locations.port_of_night_city_9
{
	"name": "Medical Technologies", "district": "port_of_night_city", "number": 9, "type": "medical",
	"owner": "", "owner_name": "Medical Technologies",
	"security_code": {"n": 5, "faction": "various_gangs", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Rumour says Maelstrom is a major supplier of its implants, though the gang never shops there.", "gigs": ["data_theft", "gang_hit"]},
		{"text": "It holds the city's largest stock of cryosystem pods outside Trauma Team and City Medical.", "gigs": ["rescue"]}
	],
	"gigs": ["data_theft", "gang_hit"],
	"interior": "Limb vats, onsite ripperdocs and a large cryopod bank.",
	"cite": "NC2045 p.155"
}
```

### #10 Mestnyy Bank

The Consortium's openly mob-run community bank (p.155).

```world locations.locations.port_of_night_city_10
{
	"name": "Mestnyy Bank", "district": "port_of_night_city", "number": 10, "type": "bank",
	"owner": "consortium", "owner_name": "The Consortium",
	"security_code": {"n": 9, "faction": "consortium", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [{"text": "It reportedly \"loses\" payment records to squeeze borrowers whose skills the Consortium wants for a heist.", "gigs": ["data_theft", "rescue"]}],
	"gigs": ["data_theft"],
	"interior": "",
	"cite": "NC2045 p.155"
}
```

### #11 Naiad's Embrace

A Consortium nightclub and casino for dockworkers, with joytoys and rooms upstairs (p.155).

```world locations.locations.port_of_night_city_11
{
	"name": "Naiad's Embrace", "district": "port_of_night_city", "number": 11, "type": "casino",
	"owner": "consortium", "owner_name": "The Consortium",
	"security_code": {"n": 8, "faction": "consortium", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Jean-Pierre Kashiwagi (Solo 3)"],
	"hooks": [{"text": "The drinks are watered and the tables rigged.", "gigs": []}],
	"gigs": ["gang_hit", "data_theft"],
	"interior": "Club and gaming floor below, rented rooms upstairs.",
	"cite": "NC2045 p.155"
}
```

### #12 Reclaimed Studios

An ugly but sturdy apartment tower of identical furnished studios, full of cyber-addicted gangers (p.155).

```world locations.locations.port_of_night_city_12
{
	"name": "Reclaimed Studios", "district": "port_of_night_city", "number": 12, "type": "housing",
	"owner": "", "owner_name": "",
	"security_code": {"n": 5, "faction": "various_gangs", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["gang_hit"],
	"interior": "A tall block of identical furnished studios.",
	"cite": "NC2045 p.155"
}
```

### #13 The Reclamation Plant

The water-treatment works the Thelas rebuilt after finding the city's sewage pouring into the sea (p.155-156).

```world locations.locations.port_of_night_city_13
{
	"name": "The Reclamation Plant", "district": "port_of_night_city", "number": 13, "type": "utility",
	"owner": "thelas_marines", "owner_name": "the Thelas nomads",
	"security_code": {"n": 8, "faction": "thelas_marines", "intensity": "heavy", "hardened": false},
	"utility_code": 3,
	"npcs": [],
	"hooks": [{"text": "Treated solids are sold, mostly to Biotechnica; city Department of Water repair trucks go out under Marine guard.", "gigs": ["sabotage"]}],
	"gigs": ["sabotage"],
	"interior": "Treatment tanks where local workers filter and dose wastewater under Thelas Techs; also houses the city Department of Water.",
	"cite": "NC2045 p.155"
}
```

### #14 Rusty's Dive Shack

A barnacled dive bar built from a container sub's bridge welded to cargo containers; sailors brawl here without
guns (p.156).

```world locations.locations.port_of_night_city_14
{
	"name": "Rusty's Dive Shack", "district": "port_of_night_city", "number": 14, "type": "bar",
	"owner": "", "owner_name": "",
	"security_code": {"n": 5, "faction": "thelas_marines", "intensity": "heavy", "hardened": false},
	"utility_code": null,
	"npcs": ["Sweetheart (Medtech 3)"],
	"hooks": [],
	"gigs": [],
	"interior": "A salvaged sub bridge welded to containers; Sweetheart's tattoo parlour in a side container.",
	"cite": "NC2045 p.156"
}
```

### #15 The Yard

The railyard built with the Snake Nation to move Port cargo inland (p.156).

```world locations.locations.port_of_night_city_15
{
	"name": "The Yard", "district": "port_of_night_city", "number": 15, "type": "rail",
	"owner": "thelas_marines", "owner_name": "the Thelas nomads, with Snake Nation",
	"security_code": {"n": 7, "faction": "thelas_marines", "intensity": "heavy", "hardened": false},
	"utility_code": 3,
	"npcs": ["Sleepy Steve-o (Netrunner 4)"],
	"hooks": [{"text": "The DeadWoods keep a bunkhouse here, and gossip says Calypso is sweet on Gunslinger.", "gigs": []}],
	"gigs": ["sabotage", "data_theft"],
	"interior": "Rails and trains, warehouses, maintenance stations, open container stacks; netrunner-run gantry cranes, Linear Frames and forklifts; a DeadWoods bunkhouse and station.",
	"cite": "NC2045 p.156"
}
```

## Fixers

- Valya (Fixer 6), The Amber Room: head of the Consortium; mob business by note to the bartender (p.153, 156).
- William "Mr. AMAAAZE!" Maze (Fixer 8), Dock 13: sells salvaged junk and runs a Night Market (p.153).
- Della Glass (Fixer 5), Maritime Supply: ocean gear and high-seas gigs, connections across the Pacific (p.155-156).
- Skitter (Fixer 4), the Port: cleans up and resells anything of value flushed into the sewers (p.156).

## Personalities

- Della Glass (Fixer 5): ex-Pacific Run hauler; the go-to for gigs at sea (p.156).
- Jean-Pierre Kashiwagi (Solo 3): Naiad's Embrace croupier by day, pickpocket in other districts by night (p.156).
- Keelhaul (Nomad 2): apprentice tug pilot dreaming of an ocean crossing; listens to elders' tales on Flotsam (p.156).
- Ivan (Nomad 4): an unusually sociable Vyriy nomad, trying to drink in every bar in the city (p.156).
- Skitter (Fixer 4): resells valuables recovered from the city's waste (p.156).
- Sleepy Steve-o (Netrunner 4): forklift specialist who netruns with his eyes closed on shift (p.156).
- Valya (Fixer 6): ex-Moscow socialite who skimmed her father's accounts and resurfaced as the Bratva's Consortium chief; friendly with SovOil and Zhirafa execs (p.156).
