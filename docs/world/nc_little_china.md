# Little China

Little China is half rebuilt and half war zone (NC2045 p.96-97). City Manager David Ling Po runs it like a private
estate through the Little China Redevelopment Association (LCRA). Fixed-up buildings in the north and centre are held
together with bamboo scaffolding and Petrochem resin. The south, which the LCRA ignores, belongs to the Red Chrome
Legion, and the Legion and the Gold Dragons skirmish along that border. The Gold Dragons are the LCRA's hired security:
a former boostergang now led by Edwina "Eddy" Sing (Solo 4/Exec 2), who settles disputes with martial-arts duels. The
narrator says one rumour is true: Ling Po heads the Weng Fang Tong (p.97).

```world city.districts.little_china
{
	"name": "Little China",
	"region": "island",
	"manager": {"name": "David Ling Po", "role": "Fixer 8"},
	"population": "north and centre ~50% ethnic Chinese, ~35% other Asian ancestry, ~15% other; LCRA aid favours Chinese residents, and those pushed out drift south to the Legion",
	"security_code": {"n": 5, "faction": "gold_dragons", "intensity": "light", "hardened": true},
	"utility_code": 6,
	"provider": "gold_dragons",
	"gangs": ["gold_dragons", "red_chrome_legion", "weng_fang_tong"],
	"ncart": ["Pigeon Boulevard", "Kue Street"],
	"profile": "market_streets",
	"look": ["bamboo scaffolding", "resin-patched ruins", "night markets", "incense and shrines", "flooded sinkholes"],
	"history": "Parts of old Charter Hill and Studio City were annexed after Ling Po bought the council seat; the LCRA rebuilds the north while the south stays a combat zone.",
	"cite": "NC2045 p.96-103"
}
```

## Locations

### #1 Bridgetown
The worst slum in Little China. Nobody protects it, and the rents are low enough that people still move in. Residents
burn a lot of incense: for the dead, and to cover the smell of bodies that wash up on the waterfront.

```world locations.locations.little_china_1
{
	"name": "Bridgetown",
	"district": "little_china",
	"number": 1,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 3, "faction": "gold_dragons", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Tenements beside the water, with a bodega that sells incense.",
	"cite": "NC2045 p.99"
}
```

### #2 Chrome Cross
The Red Chrome Legion's local dive. It has survived only because the LCRA is busy in the north, and the Legion is a
handy scapegoat for violence.

```world locations.locations.little_china_2
{
	"name": "Chrome Cross",
	"district": "little_china",
	"number": 2,
	"type": "gang_base",
	"owner": "red_chrome_legion",
	"owner_name": "Red Chrome Legion",
	"security_code": {"n": 10, "faction": "red_chrome_legion", "intensity": "heavy", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The LCRA leaves the Legion's hangout alone so it can blame convenient outbreaks of violence on the gang.", "gigs": ["gang_hit", "sabotage"]}
	],
	"gigs": ["gang_hit", "sabotage"],
	"interior": "",
	"cite": "NC2045 p.99"
}
```

### #3 The Forlorn Hope Wreckage
The rubble of the old edgerunner bar, whose owners reopened it in North Heywood. Someone keeps a brazier and offerings
here for the people who died in it. (For the Hope Reborn campaign the book swaps in The Hope entry on p.249.)

```world locations.locations.little_china_3
{
	"name": "The Forlorn Hope Wreckage",
	"district": "little_china",
	"number": 3,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 3, "faction": "gold_dragons", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Red Chrome Legion members swagger in and steal the offerings left for the bar's dead.", "gigs": ["gang_hit"]}
	],
	"gigs": [],
	"interior": "A rubble lot with an incense brazier and offerings of Smash and Kibble.",
	"cite": "NC2045 p.99"
}
```

### #4 Guăngbō Tower
The old KLIA radio tower. The LCRA saved it with resin and turned it into an upscale container tower that pushes local
rents up. It is the showpiece of the redevelopment, and the official Gold Dragons Security has its base in the basement.

```world locations.locations.little_china_4
{
	"name": "Guăngbō Tower",
	"district": "little_china",
	"number": 4,
	"type": "corp_office",
	"owner": "lcra",
	"owner_name": "Little China Redevelopment Association (David Ling Po, Fixer 8)",
	"security_code": {"n": 10, "faction": "gold_dragons", "intensity": "heavy", "hardened": false},
	"utility_code": 4,
	"npcs": ["Darius Ling Po (Exec 5)"],
	"hooks": [
		{"text": "The LCRA's offices share floors with the Ling Po Benevolence Association, the Weng Fang Tong's front.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": ["data_theft", "sabotage", "gang_hit"],
	"interior": "Basement: Gold Dragons Security, with a firing range, gym, martial hall, garage and short-term holding cells. Bottom four floors above the lobby: Ling Po Imports. Floors 9-10: LCRA offices, the Tong's front charity and a small clinic. Floor 10: the public library. Floors 15-16: Libertine Lanes, a 30-lane wooden bowling alley with a bar, where the Dragons hang out. Top floor: Virtex's VR arcade, closed for renovation.",
	"cite": "NC2045 p.99-100"
}
```

### #5 Guānyīn Temple
A small Buddhist temple that also serves Chinese folk worshippers. About six nuns run it, and volunteers and the odd
devout Gold Dragon guard it.

```world locations.locations.little_china_5
{
	"name": "Guānyīn Temple",
	"district": "little_china",
	"number": 5,
	"type": "church",
	"owner": "",
	"owner_name": "The Reverend Ānxīn (Exec 4)",
	"security_code": {"n": 4, "faction": "gold_dragons", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["The Reverend Ānxīn (Exec 4)"],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.100"
}
```

### #6 The Hong Kong Market
A market that has run since before the war and is now owned by the Pham family, who are Vietnamese. Ling Po and the
Phams disagree about the district's future, and the Dragons barely protect them.

```world locations.locations.little_china_6
{
	"name": "The Hong Kong Market",
	"district": "little_china",
	"number": 6,
	"type": "market",
	"owner": "",
	"owner_name": "the Pham family (Mrs. Pham, Exec 5)",
	"security_code": {"n": 4, "faction": "gold_dragons", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Mrs. Pham (Exec 5)", "The Bonesetter (Medtech 3)", "Sangeetha Jayaraman (Nomad 4)", "Maurice Teo (Tech 3)", "Old Yau (Fixer 4)", "Ginkgo (Tech 4)"],
	"hooks": [
		{"text": "Saboteurs tied to Continental Brands keep hitting the market, and the Gold Dragons do little about it.", "gigs": ["sabotage", "gang_hit"]},
		{"text": "Mrs. Pham is thinking of hiring local edgerunners as guards and paying them in food.", "gigs": ["gang_hit"]}
	],
	"gigs": ["sabotage", "gang_hit"],
	"interior": "Stalls: the Bonesetter's clinic (bone-setting and basic dentistry); Jayaraman's fish stall; the Little Red Book, a 1930s Shanghai-style bar tent with a private lounge for queer customers who know the handshake (Maotai 20eb); and the Yuenyang Tea Shop, where Old Yau feeds the Dragons for free and Ginkgo keeps a table.",
	"cite": "NC2045 p.100-101"
}
```

### #7 Hydrosubsidium
The desalination and ocean-survey company did well out of the rebuilding, and it locates sunken cargo for a share of
the salvage. Ling Po hates having an independent corp on his turf, but Night Corp backs it.

```world locations.locations.little_china_7
{
	"name": "Hydrosubsidium",
	"district": "little_china",
	"number": 7,
	"type": "corp_office",
	"owner": "hydrosubsidium",
	"owner_name": "Hydrosubsidium (CEO Thomasin Blake, Exec 9)",
	"security_code": {"n": 10, "faction": "hydrosubsidium", "intensity": "heavy", "hardened": false},
	"utility_code": 3,
	"npcs": ["Thomasin Blake (Exec 9)"],
	"hooks": [
		{"text": "The LCRA blocks every property purchase by Hydrosubsidium and wants the company out of Little China, but Night Corp protects it.", "gigs": ["sabotage", "data_theft"]},
		{"text": "Hydrosubsidium's radar surveys pinpoint sunken cargo containers that it recovers for a share.", "gigs": ["data_theft"]}
	],
	"gigs": ["sabotage", "data_theft", "corp_extraction"],
	"interior": "",
	"cite": "NC2045 p.101"
}
```

### #8 Ling Husan's New China Pharmacy
An old herbal pharmacy with a resin-patched front. Mr. Ling sells traditional remedies and new street drugs, and his
niece Madeline makes the bigger batches.

```world locations.locations.little_china_8
{
	"name": "Ling Husan's New China Pharmacy",
	"district": "little_china",
	"number": 8,
	"type": "medical",
	"owner": "",
	"owner_name": "Ling Husan (Medtech 4)",
	"security_code": {"n": 8, "faction": "gold_dragons", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Ling Husan (Medtech 4)", "Madeline Ling (Medtech 2)"],
	"hooks": [
		{"text": "Madeline wants out from under her family. She is secretly David Ling Po's daughter, being tested as his heir, and she is dating an Eastern Tigers Triad member.", "gigs": ["corp_extraction", "rescue"]}
	],
	"gigs": ["corp_extraction", "rescue"],
	"interior": "",
	"cite": "NC2045 p.101"
}
```

### #9 Ling Po Imports Wreckage
The company's old premises, cratered during the war by what locals call a "stray" space rock. Some say Ling Po blew it
up himself for the insurance. The Gold Dragons guard the empty lot around the clock.

```world locations.locations.little_china_9
{
	"name": "Ling Po Imports Wreckage",
	"district": "little_china",
	"number": 9,
	"type": "ruin",
	"owner": "",
	"owner_name": "Ling Po Imports (Darius Ling Po, Exec 5)",
	"security_code": {"n": 9, "faction": "gold_dragons", "intensity": "heavy", "hardened": false},
	"utility_code": null,
	"npcs": ["Darius Ling Po (Exec 5)"],
	"hooks": [
		{"text": "Darius Ling Po is said to have crews quietly digging under the site for lost antiques and drug caches.", "gigs": ["data_theft", "sabotage"]},
		{"text": "Rumours disagree about why the site was hit; one says Ling Po destroyed it for the insurance money.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft", "sabotage"],
	"interior": "A guarded crater with hidden digging underneath.",
	"cite": "NC2045 p.101"
}
```

### #10 Madam Yap's
A ripperdoc and acupuncturist who works out of a converted small hotel. She belongs to the Weng Fang Tong but treats
anyone who pays. She makes no secret that every room is bugged.

```world locations.locations.little_china_10
{
	"name": "Madam Yap's",
	"district": "little_china",
	"number": 10,
	"type": "medical",
	"owner": "weng_fang_tong",
	"owner_name": "Madam Yap (Medtech 5)",
	"security_code": {"n": 5, "faction": "gold_dragons", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Madam Yap (Medtech 5)"],
	"hooks": [
		{"text": "Every recovery suite is bugged for audio and video, so Yap holds recordings of wealthy patients.", "gigs": ["data_theft"]},
		{"text": "The Phoenix Suite is kept for the Tong's most important members.", "gigs": ["assassination"]}
	],
	"gigs": ["data_theft", "assassination"],
	"interior": "A former small hotel. The top floor's six suites are luxury recovery rooms, and the best one, the Phoenix Suite, is kept for Tong leaders.",
	"cite": "NC2045 p.101"
}
```

### #11 Madame Lin's Massage Parlor
The parlour used to front for sex work. The new owner, a distant cousin, didn't know that and retrained the staff as
real masseurs, and it makes more money than before.

```world locations.locations.little_china_11
{
	"name": "Madame Lin's Massage Parlor",
	"district": "little_china",
	"number": 11,
	"type": "shop",
	"owner": "",
	"owner_name": "Freddy Lin (Medtech 4)",
	"security_code": {"n": 4, "faction": "gold_dragons", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": ["Freddy Lin (Medtech 4)"],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.101-102"
}
```

### #12 The Parisian
A themed luxury hotel from the early 2000s, once Yakuza-owned. The LCRA bought it and cleared out the squatters with
gunfire. It is being restored and has already been rented out for a movie shoot.

```world locations.locations.little_china_12
{
	"name": "The Parisian",
	"district": "little_china",
	"number": 12,
	"type": "hotel",
	"owner": "lcra",
	"owner_name": "Little China Redevelopment Association",
	"security_code": {"n": 3, "faction": "gold_dragons", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "A damaged hotel under restoration, with a cracked façade and an interior wrecked by squatters.",
	"cite": "NC2045 p.102"
}
```

### #13 Prosperity Garden Tenements
An overcrowded block of apartments that Auntie Hung keeps clean. It is somehow the safest place to live in Little
China: troublemakers disappear and later turn up concussed and tied to lamp posts near Guăngbō Tower.

```world locations.locations.little_china_13
{
	"name": "Prosperity Garden Tenements",
	"district": "little_china",
	"number": 13,
	"type": "housing",
	"owner": "",
	"owner_name": "Auntie Hung (Solo 6)",
	"security_code": {"n": 3, "faction": "locals", "responder": "residents", "intensity": "heavy", "hardened": true},
	"utility_code": null,
	"npcs": ["Auntie Hung (Solo 6)"],
	"hooks": [
		{"text": "An unknown vigilante protects the block, and the tenants won't say what happened to the troublemakers it dealt with.", "gigs": []}
	],
	"gigs": [],
	"interior": "Crowded mixed-use apartments. The lucky ones share a bathroom; the rest use a standpipe downstairs. On the ground floor: a tailor, a cruller shop and a dry-goods bodega.",
	"cite": "NC2045 p.102"
}
```

### #14 Richard Night Aquarium
The war wrecked the aquarium and killed every animal in it. Hydrosubsidium bought it and reopened it as a public
service and an advert. Lazarus shuttles carry visitors in from the Upper Marina.

```world locations.locations.little_china_14
{
	"name": "Richard Night Aquarium",
	"district": "little_china",
	"number": 14,
	"type": "attraction",
	"owner": "hydrosubsidium",
	"owner_name": "Hydrosubsidium (Director Krista Chung, Exec 5)",
	"security_code": {"n": 3, "faction": "lazarus", "intensity": "medium", "hardened": true},
	"utility_code": 3,
	"npcs": ["Krista Chung (Exec 5)"],
	"hooks": [
		{"text": "Director Chung pays freelancers to bring in specimens and is getting a tank ready for a great white shark.", "gigs": []}
	],
	"gigs": ["sabotage"],
	"interior": "Most of the tanks are still empty.",
	"cite": "NC2045 p.102"
}
```

### #15 The Seep
A temple to Mazu fell into a sinkhole after the nuke, and Hot Zone runoff has turned it into a flooded pit. The old
groundskeeper looks after a surviving statue and warns visitors away from the edge.

```world locations.locations.little_china_15
{
	"name": "The Seep",
	"district": "little_china",
	"number": 15,
	"type": "ruin",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 2, "faction": "gold_dragons", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": ["Mr. Low (groundskeeper)"],
	"hooks": [
		{"text": "The Gold Dragons hold honour duels at night around the pit's edge.", "gigs": ["gang_hit"]},
		{"text": "An urban legend says anyone who falls into the pool is mutated.", "gigs": []}
	],
	"gigs": ["gang_hit"],
	"interior": "A flooded sinkhole crater with a makeshift shrine around the Mazu statue.",
	"cite": "NC2045 p.102"
}
```

## Fixers

- David Ling Po (Fixer 8): City Manager. The narrator says he heads the Weng Fang Tong. He takes a cut of nearly every deal in the district (p.97).
- Old Yau (Fixer 4): runs the Yuenyang Tea Shop in the Hong Kong Market and stays on good terms with the Gold Dragons by feeding them for free (p.100-101).
- Grease (Fixer 2): ours, not NC2045's: a street-level Fixer still making his name (SPM p.57), placed here as a new crew's first contact (docs/world/fixers.md).
- Ginkgo (Tech 4): the district's finder, not a Fixer by Role. He takes jobs at his table in the Yuenyang Tea Shop and finds missing people and lost things (p.103).

## Personalities

- Auntie Hung (Solo 6): slumlord of Prosperity Garden and a Hung-gar kung fu master. Her former pupils include Tong lieutenants and edgerunners; the way to win her favour is cognac, cigarettes or seafood (p.103).
- Thomasin Blake (Exec 9): CEO of Hydrosubsidium, who rose through sales. She gives away purification plants and overcharges for the filters. She recently joined Night Corp's board (p.103).
- Darius Ling Po (Exec 5): David Ling Po's nephew and the only person he fully trusts. He turned Ling Po Imports into a regional trader (p.103).
- Ginkgo (Tech 4): a shabby, friendly finder with no office (p.103).
- Madeline Ling (Medtech 2): NCU student and pharmacy apprentice, secretly Ling Po's daughter and his possible heir. She is dating an Eastern Tigers Triad member (p.103).
- The Reverend Ānxīn (Exec 4): abbess of the Guānyīn Temple. Her charity is one of the few that doesn't depend on Ling Po's money (p.103).
- Edwina "Eddy" Sing (Solo 4/Exec 2): head of the Gold Dragons, who brought in a code of honour duels (p.97).
