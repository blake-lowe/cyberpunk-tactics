# Downtown

A working-class district fighting gentrification by the Chamber of Commerce, a cabal of money men led by
Mister Kernaghan (NC2045 p.80-81). The Chamber appointed ex-cargo-ship captain Emilia Ortega as City Manager;
she lets old businesses die and arranges buyouts for new towers. Whitewater Security, her private force, protects
businesses that pay their dues. The Undertow bombs and shoots, the Eastern Tigers Triad and Whitewater trade
fire on the waterfront, and the Skiv Family sabotages construction run by crews without mob ties.

The Chamber of Commerce (owner id `chamber_of_commerce`) holds the district's Council seat and owns the New
Libertine Tower and Clocktower Residences. Stat blocks (p.89): NCFD Firefighter (Hardened Mook), Undertow Mook,
Triad Enforcer and Whitewater Guard (Hardened Mooks).

## District

```world city.districts.downtown
{
	"name": "Downtown",
	"region": "island",
	"manager": {"name": "Emilia Ortega", "role": "Exec 6"},
	"population": "old post-nuke working families running small shops and repair joints, squeezed by Chamber-backed newcomers opening clinics, designer stores and bodysculpt shops",
	"security_code": {"n": 8, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": 3,
	"provider": "whitewater_security",
	"gangs": ["eastern_tigers_triad", "julliard_guild", "undertow", "skiv_family"],
	"ncart": ["Smith Street", "Continental Brands Station"],
	"profile": "market_streets",
	"look": ["old-world charm", "gentrifying", "corp towers", "small shops", "goth clubs", "day markets"],
	"history": "Once elegant West Hill Gardens; folded into Little Europe after the 4CW, then carved out as its own district in 2042 when the Chamber of Commerce bought a Council seat after years of squeezing supplies; Continental Plaza broke ground the next day.",
	"cite": "NC2045 p.80-89"
}
```

## Locations

### #1 Acacia Way

The last of old West Hill Gardens: a single walled street of bungalows for the not-quite-top-rung rich, patrolled by Whitewater like clockwork.

```world locations.locations.downtown_1
{
	"name": "Acacia Way",
	"district": "downtown",
	"number": 1,
	"type": "villa",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 9, "faction": "whitewater_security", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": ["assassination", "corp_extraction"],
	"interior": "One walled-off street of bungalows with scheduled Whitewater patrols.",
	"cite": "NC2045 p.81"
}
```

### #2 Bella Vista Market

A string-lit day market inside an old parking garage, full of families, tourists and handmade goods.

```world locations.locations.downtown_2
{
	"name": "Bella Vista Market",
	"district": "downtown",
	"number": 2,
	"type": "market",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 6, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Some nights it turns into a Night Market where Fixers outside the Chamber deal braindance, cyberware, weapons and rarer goods for those who know the right people.", "gigs": ["gang_hit", "data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Former parking garage; stalls include Digg's (tiny bodega), Refrosh Wash (footbath cafe-bar), Rainbow Art Supply (paint and drugs) and Fade Forever barber.",
	"cite": "NC2045 p.83"
}
```

### #3 Café Bouchon

A pseudo-European cafe spared by gentrification because the City Manager likes it; one of the few places serving real food.

```world locations.locations.downtown_3
{
	"name": "Café Bouchon",
	"district": "downtown",
	"number": 3,
	"type": "restaurant",
	"owner": "",
	"owner_name": "Monsieur Jacques (Fixer 4)",
	"security_code": {"n": 9, "faction": "whitewater_security", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Monsieur Jacques (Fixer 4)"],
	"hooks": [
		{"text": "Word is the owner runs an info-broker sideline; bring secrets to trade.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "",
	"cite": "NC2045 p.83"
}
```

### #4 Clocktower Residences

Upscale units wrapped around a clock tower that survived the war: vintage outside, modern tech inside.

```world locations.locations.downtown_4
{
	"name": "Clocktower Residences",
	"district": "downtown",
	"number": 4,
	"type": "housing",
	"owner": "chamber_of_commerce",
	"owner_name": "the Chamber of Commerce",
	"security_code": {"n": 9, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Whispers say the Chamber bugged the appliances and hid cameras in the decor, making it a honeypot of residents' secrets.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Flats around an old clock tower; rumoured hidden bugs and cameras.",
	"cite": "NC2045 p.83"
}
```

### #5 Continental Brands Office

Continental Brands' local HQ tower, with a public showcase below, locked-down working floors and executive suites on top.

```world locations.locations.downtown_5
{
	"name": "Continental Brands Office",
	"district": "downtown",
	"number": 5,
	"type": "corp_office",
	"owner": "continental_brands",
	"owner_name": "Continental Brands",
	"security_code": {"n": 10, "faction": "continental_brands", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Rumour: an unused premium office is kept stocked with chilled Triti-Fizz and uncut synthcoke in case Kibble Queen Olivia Forsythe visits.", "gigs": ["data_theft"]},
		{"text": "Labs on the staff floors mix up who knows what.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": ["data_theft", "sabotage", "corp_extraction"],
	"interior": "Lower floors public: Oasis Megamart, ticketed tours of the Oasis Test Kitchen, Cooking with Kibble; middle floors staff-only offices, marketing rooms and labs under Continental security; top five floors executive suites.",
	"cite": "NC2045 p.83"
}
```

### #6 Continental Plaza

A plaza promised as the district's friendly heart, now hostile concrete with spiked benches around a three-tier faux-Roman fountain.

```world locations.locations.downtown_6
{
	"name": "Continental Plaza",
	"district": "downtown",
	"number": 6,
	"type": "park",
	"owner": "continental_brands",
	"owner_name": "Continental Brands",
	"security_code": {"n": 9, "faction": "continental_brands", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Every so often a dead body is fished out of the fountain.", "gigs": ["assassination"]}
	],
	"gigs": [],
	"interior": "Concrete plaza with anti-homeless design and a three-tier fountain.",
	"cite": "NC2045 p.84"
}
```

### #7 Cortex Complex

A multi-use office tower shaped like a human brain, loved by the Chamber and loathed by locals.

```world locations.locations.downtown_7
{
	"name": "Cortex Complex",
	"district": "downtown",
	"number": 7,
	"type": "corp_office",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 6, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Jack Skorkowsky (Solo 4/Fixer 5)"],
	"hooks": [
		{"text": "Reclon does unexplained chemistry on floors eight and nine.", "gigs": ["data_theft", "sabotage"]}
	],
	"gigs": ["data_theft"],
	"interior": "3: Allworld Insurance; 4: Screaming Eagle Law; 5-6: Bodyweight Fitness gym; 7: Jack Skorkowsky's real-estate office; 8-9: Reclon chemicals; 10-12: Bioflugh bio-polymers; 20: DizCom industrial design; vacant commercial space in between.",
	"cite": "NC2045 p.84"
}
```

### #8 Delirium

A three-storey nightclub, a staple of the punk and goth scenes, where every guest gets proprietary "Dee Vee" virtuality goggles.

```world locations.locations.downtown_8
{
	"name": "Delirium",
	"district": "downtown",
	"number": 8,
	"type": "club",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 5, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Three floors; first virtual environment free, 20eb per switch.",
	"cite": "NC2045 p.84"
}
```

### #9 The Eldritch Mirage

A members-only Gothic club hidden in a forgotten alley, serving 50eb absinthe to live pipe organ; its owner, a Chamber member, does her real business upstairs.

```world locations.locations.downtown_9
{
	"name": "The Eldritch Mirage",
	"district": "downtown",
	"number": 9,
	"type": "club",
	"owner": "",
	"owner_name": "Cassandra Vey (Fixer 6)",
	"security_code": {"n": 9, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Cassandra Vey (Fixer 6)"],
	"hooks": [],
	"gigs": ["data_theft", "assassination"],
	"interior": "Velvet drapes and iron chandeliers behind an oil-soaked alley door; Vey works from the VIP lounge with her crew.",
	"cite": "NC2045 p.84"
}
```

### #10 Europa Meatworks

An artisanal butcher in an old industrial site selling exotic old-world sausages and cuts to adventurous foodies.

```world locations.locations.downtown_10
{
	"name": "Europa Meatworks",
	"district": "downtown",
	"number": 10,
	"type": "shop",
	"owner": "",
	"owner_name": "Todd Lovett (Exec 2)",
	"security_code": {"n": 5, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Todd Lovett (Exec 2)"],
	"hooks": [
		{"text": "No one knows where the meat comes from: rumours say a Biotechnica test lab, cloning Techs in the back, or Solos hired to acquire cuts.", "gigs": ["data_theft", "rescue"]}
	],
	"gigs": ["data_theft"],
	"interior": "Butcher shop in a converted industrial building; rumoured cloning lab out back.",
	"cite": "NC2045 p.85"
}
```

### #11 Folio

A cosy fortune teller's parlour in the back room of a bodega, run by Madame Folio and her "granddaughters".

```world locations.locations.downtown_11
{
	"name": "Folio",
	"district": "downtown",
	"number": 11,
	"type": "shop",
	"owner": "",
	"owner_name": "Madame Folio (Media 6)",
	"security_code": {"n": 4, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Madame Folio (Media 6)"],
	"hooks": [
		{"text": "It's a con: the tea is drugged and hidden scanners read clients' vitals to feed the cold reading.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Back room of a bodega with hidden vital-sign scanners.",
	"cite": "NC2045 p.85"
}
```

### #12 Gilded Phoenix Arcade

A two-floor neon arcade owned by the Eastern Tigers Triad and used to launder money.

```world locations.locations.downtown_12
{
	"name": "Gilded Phoenix Arcade",
	"district": "downtown",
	"number": 12,
	"type": "attraction",
	"owner": "eastern_tigers_triad",
	"owner_name": "Eastern Tigers Triad",
	"security_code": {"n": 10, "faction": "eastern_tigers_triad", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Every eb fed to the machines is laundered to fund the Triad's counterfeit-goods operation.", "gigs": ["data_theft", "sabotage"]},
		{"text": "Private rooms upstairs offer braindances, including XBDs.", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit", "data_theft", "sabotage"],
	"interior": "Ground floor: classic arcade cabinets and pinball; second floor: private braindance rooms.",
	"cite": "NC2045 p.85"
}
```

### #13 Goosetopia

An upmarket store selling costumed vinyl geese in numbered runs with rare variants, feeding a speculative collectors' market.

```world locations.locations.downtown_13
{
	"name": "Goosetopia",
	"district": "downtown",
	"number": 13,
	"type": "shop",
	"owner": "petrochem",
	"owner_name": "Goosetopia (a Petrochem subsidiary)",
	"security_code": {"n": 5, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.85"
}
```

### #14 Guns & Dolls

A pre-war gun store turned gun shop, strip club and brothel whose sculpted, cybered workers personify famous weapons.

```world locations.locations.downtown_14
{
	"name": "Guns & Dolls",
	"district": "downtown",
	"number": 14,
	"type": "club",
	"owner": "",
	"owner_name": "Valian Violet (Medtech 5)",
	"security_code": {"n": 8, "faction": "eastern_tigers_triad", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Valian Violet (Medtech 5)"],
	"hooks": [
		{"text": "Violet switched protection from the Weng Fang Tong to the Eastern Tigers Triad; the Gold Dragons jumped one of her joytoys last week and more trouble is coming.", "gigs": ["gang_hit"]},
		{"text": "Violet refuses to play ball with the Chamber and is said to be close to cyberpsychosis (p.88).", "gigs": ["assassination"]}
	],
	"gigs": ["gang_hit", "assassination"],
	"interior": "Gun store, strip club and brothel under one roof.",
	"cite": "NC2045 p.86"
}
```

### #15 Jade Blossom Spa

A luxury spa for corporate elites and tourists that fronts for the Eastern Tigers Triad's stronghold.

```world locations.locations.downtown_15
{
	"name": "Jade Blossom Spa",
	"district": "downtown",
	"number": 15,
	"type": "gang_base",
	"owner": "eastern_tigers_triad",
	"owner_name": "Eastern Tigers Triad",
	"security_code": {"n": 10, "faction": "eastern_tigers_triad", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The back rooms hold boxes of counterfeits from Rancho Coronado sweatshops awaiting shipment to stores and Fixers.", "gigs": ["sabotage", "data_theft"]},
		{"text": "Rumour: the Triad hijacked one of Mister Kernaghan's shipments from Asia, sparking a waterfront shootout with Whitewater (p.81).", "gigs": ["gang_hit"]}
	],
	"gigs": ["gang_hit", "sabotage"],
	"interior": "Public front of herbal baths, massage and meditation rooms; Triad stronghold and counterfeit stockroom in the back.",
	"cite": "NC2045 p.86"
}
```

### #16 Moleharty's Books & Antiques

A dusty rare-book shop owned by an old-school Fixer and Chamber member with more secrets than stock.

```world locations.locations.downtown_16
{
	"name": "Moleharty's Books & Antiques",
	"district": "downtown",
	"number": 16,
	"type": "shop",
	"owner": "",
	"owner_name": "Hercule Moleharty (Fixer 7)",
	"security_code": {"n": 9, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["Hercule Moleharty (Fixer 7)"],
	"hooks": [
		{"text": "A vault under the floorboards holds black-market artifacts found in no museum.", "gigs": ["data_theft"]}
	],
	"gigs": ["data_theft"],
	"interior": "Shop crammed with rare books; vault beneath the floor.",
	"cite": "NC2045 p.86"
}
```

### #17 Munch Munch Munch

A private Victorian-style social club for exotics only (500eb a year), with a lounge, rentable cube rooms and themed nights.

```world locations.locations.downtown_17
{
	"name": "Munch Munch Munch",
	"district": "downtown",
	"number": 17,
	"type": "club",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 10, "faction": "locals", "intensity": "heavy", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Lounge serving meals and drinks; cube rooms at 20eb a night.",
	"cite": "NC2045 p.86"
}
```

### #18 New Libertine Tower

A generic teal tower where the Chamber of Commerce keeps its pet businesses and politicians.

```world locations.locations.downtown_18
{
	"name": "New Libertine Tower",
	"district": "downtown",
	"number": 18,
	"type": "corp_office",
	"owner": "chamber_of_commerce",
	"owner_name": "the Chamber of Commerce",
	"security_code": {"n": 11, "faction": "whitewater_security", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": ["Emilia Ortega (Exec 6)", "Rael Sanschez (Medtech 6)", "Helene Riese (Solo 6)"],
	"hooks": [],
	"gigs": ["data_theft", "assassination", "sabotage"],
	"interior": "Whitewater Security on the bottom three floors; City Manager Ortega's offices on the top two; tenants include GHP Architectural, law firm Gueller and Stravinsky, and Rael Sanschez's private clinic on floor five.",
	"cite": "NC2045 p.86"
}
```

### #19 Night City Firestation #2

The heavily fortified centre of the district's war on fires, staffed by armed, armoured, cybered firefighters; locals joke that arson is the fastest way to get a response.

```world locations.locations.downtown_19
{
	"name": "Night City Firestation #2",
	"district": "downtown",
	"number": 19,
	"type": "police",
	"owner": "ncfd",
	"owner_name": "Night City Fire Department",
	"security_code": {"n": 9, "faction": "ncpd", "intensity": "medium", "hardened": true},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The station's own deputised detectives rarely bring arsonists to court; they tend to end up at the bottom of the bay.", "gigs": ["assassination"]}
	],
	"gigs": [],
	"interior": "Massive fortified fire station with its own detectives.",
	"cite": "NC2045 p.87"
}
```

### #20 The Nightingale Theater

A worn old opera house hosting fringe shows, indie bands and raves, owned by the Julliard Guild, a guardian gang turned union.

```world locations.locations.downtown_20
{
	"name": "The Nightingale Theater",
	"district": "downtown",
	"number": 20,
	"type": "venue",
	"owner": "julliard_guild",
	"owner_name": "Julliard Guild",
	"security_code": {"n": 10, "faction": "julliard_guild", "intensity": "medium", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "Rising rent and corps trying to take over the space; the Guild will fight to keep it.", "gigs": ["sabotage", "gang_hit"]}
	],
	"gigs": ["sabotage"],
	"interior": "Opera house with velvet seats and crystal chandeliers.",
	"cite": "NC2045 p.87"
}
```

### #21 Studio Blocks A thru D

Four blocks of good studios once let at cube prices to artists; rent hikes since the Chamber took over drove most out.

```world locations.locations.downtown_21
{
	"name": "Studio Blocks A thru D",
	"district": "downtown",
	"number": 21,
	"type": "housing",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 4, "faction": "whitewater_security", "intensity": "light", "hardened": true},
	"utility_code": null,
	"npcs": ["BlueRaven (Tech 6)", "Lotos (Netrunner 5/Tech 7)"],
	"hooks": [],
	"gigs": [],
	"interior": "Blocks A and D: run-down, nearly empty, covered in graffiti; C: full of corp-friendly artists; B: fashion designers, weapon customisers and cyberware detailers, incl. BlueRaven and Lotos.",
	"cite": "NC2045 p.87"
}
```

### #22 West Hill Church of God

A church abandoned in the war, now the Undertow's clubhouse where they plot their "rebellion" against the Chamber.

```world locations.locations.downtown_22
{
	"name": "West Hill Church of God",
	"district": "downtown",
	"number": 22,
	"type": "gang_base",
	"owner": "undertow",
	"owner_name": "The Undertow",
	"security_code": {"n": 8, "faction": "undertow", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "The Undertow build pipe bombs and Molotovs here for attacks on construction sites and corp cars.", "gigs": ["gang_hit", "sabotage"]},
		{"text": "Rumour: Skiv lieutenant Corwen Recknagel funds the Undertow to sabotage sites not run by HF&S Construction (p.88).", "gigs": ["gang_hit", "sabotage"]}
	],
	"gigs": ["gang_hit"],
	"interior": "Derelict church used as clubhouse and bomb workshop.",
	"cite": "NC2045 p.87"
}
```

### #23 West Hill Park

A surviving sliver of the old park: a circle of dying trees around a dry, cracked fountain; quiet by day, a den of shady deals by night.

```world locations.locations.downtown_23
{
	"name": "West Hill Park",
	"district": "downtown",
	"number": 23,
	"type": "park",
	"owner": "",
	"owner_name": "",
	"security_code": {"n": 3, "faction": "whitewater_security", "intensity": "light", "hardened": false},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{"text": "After dark gangers and drifters deal here, and urban legends tell of something watching from the shadows.", "gigs": ["gang_hit"]}
	],
	"gigs": [],
	"interior": "Ring of dying trees around a dry fountain.",
	"cite": "NC2045 p.88"
}
```

## Fixers

- Mister Kernaghan (Fixer 9) — Chamber of Commerce head, mostly in The Glen; controls Downtown's supply lines.

- Hercule Moleharty (Fixer 7) — Moleharty's Books & Antiques (#16); Chamber member, black-market artifacts.

- Cassandra Vey (Fixer 6) — The Eldritch Mirage (#9); Chamber member doing deals in the VIP lounge.

- Jack Skorkowsky (Solo 4/Fixer 5) — Cortex Complex (#7), 7th floor; edgerunner turned real-estate shark.

- Monsieur Jacques (Fixer 4) — Café Bouchon (#3); info broker, trades in secrets.

- Leo Stone (Fixer 1) — street-side chrome-shine stand; 5eb shine, more for information on his clients.

- Unnamed non-Chamber Fixers — Bella Vista Night Market (#2); braindance, cyberware, weapons.


## Personalities

- BlueRaven (Tech 6): Studio Block B weaponsmith making weapons into art; just signed with Midnight Arms' Designer Partnership Program.

- Corwen Recknagel (Exec 4): youngest Skiv Family lieutenant, building a mob foothold by sabotaging sites not run by HF&S Construction; rumoured to fund the Undertow.

- Johnny Rydell (Rockerboy 4/Solo 1): dim but charismatic 1950s-obsessed leader of the Undertow.

- Giorgio "Papa" Moretti (Solo 4): retired construction foreman, unofficial leader of the old residents.

- Helene Riese (Solo 6): Whitewater commander, Ortega's old shipboard security chief; takes the odd bribe.

- Leo Stone (Fixer 1): chrome-shine kid who sells information about his clients.

- Lu Zho (Exec 5): young, shrewd leader of the Eastern Tigers Triad; scorns David Ling Po.

- Mister Kernaghan (Fixer 9): one of the city's most powerful Fixers; wants Downtown as a fortress of commerce for his own profit.

- Valian Violet (Medtech 5): risk-taking owner of Guns & Dolls, near cyberpsychosis, at odds with the Weng Fang Tong and the Chamber.
