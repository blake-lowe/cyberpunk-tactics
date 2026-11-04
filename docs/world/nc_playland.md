# Playland by the Sea

Pacifica's 24/7 theme-park resort, presented in the book as the park brochure annotated by Media Jericho Hunt
(NC2045 p.302-313). SoCal's Tower of Dark owns it; its own subsidiary Protective Lightning guards it with drones,
except the Segotari Discovery Zone, where Militech protects the sponsor's tech. Management tolerates the Piranhas as an
investment that keeps nastier gangs out (about half the staff are Piranhas) and works runaway kids in yogangs as near
slave labour. Entry is 100eb (200eb on event days), no re-entry, and no weapons; ride wristbands A-E (10-200eb)
gate attractions, and reactivating one is a DV13 Electronics/Security Tech check (p.303).

```world city.districts.playland
{
	"name": "Playland by the Sea",
	"region": "playland",
	"manager": null,
	"population": "Tourists day and night, overworked park staff (about half Piranhas) and runaway kids living in yogangs in the park's hidden corners",
	"security_code": {
		"n": 6,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": 2,
	"provider": "protective_lightning",
	"gangs": [
		"piranhas"
	],
	"ncart": [],
	"profile": "pacifica",
	"look": [
		"theme park",
		"neon rides",
		"drones",
		"boardwalk",
		"fake forest",
		"crowds"
	],
	"history": "Reopened in 2036 under Tower of Dark; two years ago Bozos slipped through the Haunted Woods' drone blind spots and killed 30+ staff, hushed up with payments to Net54 and WNS.",
	"cite": "NC2045 p.302-313"
}
```

## Park notes

- **Lands** (each its own Security Code, used by its attractions below): Thrill Hill 5 Protective Lightning, Medium
  (#1-8, p.311); Lovers Lane 6 Protective Lightning, Medium (#9-13, p.309); Haunted Woods 3 Protective Lightning,
  Medium (#14-20, p.308); Grand Junction 7 Protective Lightning, Medium (#21-33, p.307); Fantasy Island 8 Piranhas,
  Heavy, adults only, Red Chrome Legion, Voodoo Boys and Bozos banned (#34-42, p.306); Segotari Discovery Zone
  7 Militech, Hardened Light (#43-52, p.310). Map p.302.
- **Piranha house rules** (from Ricky Hamilton, p.304): no guns (offenders' heads go in the ocean), only Piranha drugs, drones can be
  messed with but not destroyed, staff and kids are protected, report clowns and voodoo costumes (Bozos and Voodoo
  Boys).
- **Yogangs** (p.304-305): Beaverdam, Children of the Night, Ecowarriors, Facers (rumoured kids who sculpt themselves
  into guests and replace them), Gearheads, Glitters, GoFasters, Guardians, Packrats, Taggers, Thrashers, Throwdown.
  Their lairs are noted on the attractions below. Staff tunnels run under the park, hubbed beneath the Trolley Yard.
- **Events calendar** (p.305-306): New Year bodysculpt sale (Jan 1-3), Date Knights joust (Feb), Parti Gras 48h
  adults-only lock-in on Fantasy Island (Mar), Junior Executive Job Fair with Segotari, Biotechnica, Rocklin,
  Continental Brands and Militech recruiters (Apr 22), Elflines Park Takeover, cosplay compulsory (May 1-7), Summer of
  Love (Jun), Western Celebration (Jun 29), Fourth of Freedom with Militech fireworks (Jul 4), NCPD Night, uniformed
  cops free (Aug 5), Corporate Center Memorial Day (Aug 20), End of Summer Family Days (Sep 1-7), Fright Nights
  every October weekend, Thrillsgiving (late Nov), Merry Merri all-drone parade every December night. Staff work
  24-36 hour shifts on busy days.
- **Mobile**: Torta Tortoise, a sandwich-cart mascot worn by Miguel (Solo 5), and the inescapable Troubadour Cart roam
  Lovers Lane (p.310).

## Lands and events (multi-map operations)

The park as the game's Playland operations read it (Campaign: an operation is a chain of legs across
the lands, data/gen/operations.json has the recipe). Each land lists its attractions (the locations
below, by number) and keeps the Security Code its entries carry. `profile` is the neighbourhood
generator a leg there is played on (data/gen/districts.json). The Haunted Woods' fake trees blind
the drones (p.308): no cameras or turrets on a leg there. Fantasy Island is adults only and bans
Red Chrome Legion, Voodoo Boys and Bozos (p.306). The replica San Francisco streetcars link the lands
from the Grand Trolley Yard (p.307).

```world playland.lands
{
	"thrill_hill": {"name": "Thrill Hill", "locations": [1, 2, 3, 4, 5, 6, 7, 8], "profile": "theme_park", "cite": "NC2045 p.311"},
	"lovers_lane": {"name": "Lovers Lane", "locations": [9, 10, 11, 12, 13], "profile": "theme_park", "cite": "NC2045 p.309"},
	"haunted_woods": {"name": "Haunted Woods", "locations": [14, 15, 16, 17, 18, 19, 20], "profile": "haunted_woods", "drone_blind": true, "cite": "NC2045 p.308"},
	"grand_junction": {"name": "Grand Junction", "locations": [21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33], "profile": "theme_park", "hub": true, "cite": "NC2045 p.307"},
	"fantasy_island": {"name": "Fantasy Island", "locations": [34, 35, 36, 37, 38, 39, 40, 41, 42], "profile": "theme_park", "adults_only": true, "cite": "NC2045 p.306"},
	"segotari_discovery_zone": {"name": "Segotari Discovery Zone", "locations": [43, 44, 45, 46, 47, 48, 49, 50, 51, 52], "profile": "theme_park", "cite": "NC2045 p.310"}
}
```

The events calendar (p.305-306), each with what it changes in play. `fx` maps only onto systems the
game has: `police` (uniformed NCPD in the crowd: on NCPD Night they get in free; HOUSE-RULE: the book says
"plenty of them come", the game puts that many officers on each leg's map), `civilians`
(stat blocks added to the crowd), `lights_off` (the lands played with the lights down: HOUSE-RULE reading of Fright Nights, the
scares are staged in the dark). Everything else is flavour on the offer. Entry is 200eb on event days instead of 100eb (p.303), paid by the fixer.

```world playland.events
[
	{"id": "new_year_sale", "name": "New Year Bodysculpt Sale", "when": "Jan 1-3", "text": "Bodysculpt clinics sell cut-price new looks; half the crowd wears someone else's face.", "fx": {}, "cite": "NC2045 p.305"},
	{"id": "date_knights", "name": "Date Knights", "when": "February", "text": "A Valentine's joust on Lovers Lane; couples everywhere.", "fx": {}, "cite": "NC2045 p.305"},
	{"id": "parti_gras", "name": "Parti Gras", "when": "March", "text": "A 48-hour adults-only lock-in on Fantasy Island: nobody leaves the island until it's over.", "fx": {}, "cite": "NC2045 p.305"},
	{"id": "job_fair", "name": "Junior Executive Job Fair", "when": "Apr 22", "text": "Segotari, Biotechnica, Rocklin, Continental Brands and Militech recruit the park's young guests.", "fx": {"civilians": ["junior_executive"]}, "cite": "NC2045 p.305"},
	{"id": "elflines_takeover", "name": "Elflines Park Takeover", "when": "May 1-7", "text": "Cosplay is compulsory for every guest.", "fx": {}, "cite": "NC2045 p.305"},
	{"id": "summer_of_love", "name": "Summer of Love", "when": "June", "text": "A month of romance packages.", "fx": {}, "cite": "NC2045 p.305"},
	{"id": "western_celebration", "name": "Western Celebration", "when": "Jun 29", "text": "Cowboy day across the park.", "fx": {}, "cite": "NC2045 p.305"},
	{"id": "fourth_of_freedom", "name": "Fourth of Freedom", "when": "Jul 4", "text": "Militech puts on the fireworks.", "fx": {}, "cite": "NC2045 p.305"},
	{"id": "ncpd_night", "name": "NCPD Night", "when": "Aug 5", "text": "Uniformed cops get in free, and plenty of them come.", "fx": {"police": 2}, "cite": "NC2045 p.305"},
	{"id": "memorial_day", "name": "Corporate Center Memorial Day", "when": "Aug 20", "text": "A day of remembrance for the Corporate Center.", "fx": {}, "cite": "NC2045 p.305"},
	{"id": "family_days", "name": "End of Summer Family Days", "when": "Sep 1-7", "text": "Families pack the park before school starts.", "fx": {}, "cite": "NC2045 p.306"},
	{"id": "fright_nights", "name": "Fright Nights", "when": "October weekends", "text": "Every October weekend the park turns to horror; the Haunted Woods' shows run fully staffed.", "fx": {"lights_off": ["haunted_woods"]}, "cite": "NC2045 p.306"},
	{"id": "thrillsgiving", "name": "Thrillsgiving", "when": "late November", "text": "Holiday rides and feasts.", "fx": {}, "cite": "NC2045 p.306"},
	{"id": "merry_merri", "name": "Merry Merri", "when": "December nights", "text": "An all-drone parade winds through the park every night.", "fx": {}, "cite": "NC2045 p.306"}
]
```

## Locations

### #1 Eco-Coaster

Biotechnica-sponsored coaster built from recycled materials (wristband E).

```world locations.locations.playland_1
{
	"name": "Eco-Coaster",
	"district": "playland",
	"number": 1,
	"type": "attraction",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark; sponsor Biotechnica",
	"security_code": {
		"n": 5,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Its vibration slowly unscrews the fasteners; the Gearheads re-tighten them daily and sleep in the maintenance shed beneath.",
	"cite": "NC2045 p.312"
}
```

### #2 Kibble Cakes

Stall selling Kibble pancake cones with a SCOP sausage; one in ten supposedly hides a free-ride token.

```world locations.locations.playland_2
{
	"name": "Kibble Cakes",
	"district": "playland",
	"number": 2,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 5,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.312"
}
```

### #3 Bumper Pandamonium

Panda bumper-car survival arena whose layout changes monthly, sometimes with jumps, loops or a drone hunter car (wristband C).

```world locations.locations.playland_3
{
	"name": "Bumper Pandamonium",
	"district": "playland",
	"number": 3,
	"type": "attraction",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 5,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "Arena with a maintenance corridor beneath, where the GoFasters live.",
	"cite": "NC2045 p.312"
}
```

### #4 Moo Moo Burger Pier

The last Moo Moo Burger in Night City: all SCOP, but clean; Continental Brands may swap it for a FūdHouse.

```world locations.locations.playland_4
{
	"name": "Moo Moo Burger Pier",
	"district": "playland",
	"number": 4,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 5,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.312"
}
```

### #5 The Big Wheel

NorCal's largest working observation wheel, twenty minutes a turn; mid-ride ads can be disabled with a DV13 Basic Tech check (wristband E).

```world locations.locations.playland_5
{
	"name": "The Big Wheel",
	"district": "playland",
	"number": 5,
	"type": "attraction",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 5,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.312"
}
```

### #6 Hammered Industries Beer Garden

Beer garden notorious for serving minors; after 10pm drunks get rolled by yogangers.

```world locations.locations.playland_6
{
	"name": "Hammered Industries Beer Garden",
	"district": "playland",
	"number": 6,
	"type": "bar",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark; sponsor Hammered Industries",
	"security_code": {
		"n": 5,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.312"
}
```

### #7 Depth Charge

The park's oldest coaster, built in 2019 and never updated; riders occasionally fall out (wristband E).

```world locations.locations.playland_7
{
	"name": "Depth Charge",
	"district": "playland",
	"number": 7,
	"type": "attraction",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 5,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.312"
}
```

### #8 Laser Light Arena

Laser-tag ride through a gamified Second Central American Conflict, co-presented by Militech (wristband D).

```world locations.locations.playland_8
{
	"name": "Laser Light Arena",
	"district": "playland",
	"number": 8,
	"type": "attraction",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark; sponsors Laser Light and Militech",
	"security_code": {
		"n": 5,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.312"
}
```

### #9 Grand Hotel

The park's biggest hotel and a streetcar stop, 250eb a night, mostly empty off-peak.

```world locations.locations.playland_9
{
	"name": "Grand Hotel",
	"district": "playland",
	"number": 9,
	"type": "hotel",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 6,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.309-310"
}
```

### #10 Playland Amphitheatre & Reflection Deck

Event centre and photo spot whose benches shock anyone who doesn't scan a wristband every 15 minutes (wristband A).

```world locations.locations.playland_10
{
	"name": "Playland Amphitheatre & Reflection Deck",
	"district": "playland",
	"number": 10,
	"type": "venue",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 6,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.310"
}
```

### #11 Memorial Zen Garden

Bonsai zen garden once sponsored by Arasaka and unsponsored since (wristband A).

```world locations.locations.playland_11
{
	"name": "Memorial Zen Garden",
	"district": "playland",
	"number": 11,
	"type": "park",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 6,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "The Ecowarriors tend it and live in a cave behind the waterfall.",
	"cite": "NC2045 p.310"
}
```

### #12 Lovers Café

Date café with live music and name-frosted crepes in private, not soundproof, cabanas.

```world locations.locations.playland_12
{
	"name": "Lovers Café",
	"district": "playland",
	"number": 12,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 6,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.310"
}
```

### #13 Mermaid Fountain

Fountain hosting hourly Merri the Mermaid swim shows by Biotechnica's AquaForm Bioexotics (wristband A).

```world locations.locations.playland_13
{
	"name": "Mermaid Fountain",
	"district": "playland",
	"number": 13,
	"type": "park",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark; show by Biotechnica",
	"security_code": {
		"n": 6,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Clementine (Rockerboy 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.310"
}
```

### #14 Circle of the Supernatural

Monster-themed dinner show, best during Fright Nights when it is fully staffed.

```world locations.locations.playland_14
{
	"name": "Circle of the Supernatural",
	"district": "playland",
	"number": 14,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 3,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.309"
}
```

### #15 Carnival of Screams

Carnival game booths, staffed by yogangers for Kibble since the Bozo massacre here.

```world locations.locations.playland_15
{
	"name": "Carnival of Screams",
	"district": "playland",
	"number": 15,
	"type": "attraction",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 3,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The fake trees blind the drones; Bozos used that two years ago to kill 30+ workers, and Tower of Dark paid Net54 and WNS to bury the story.",
			"gigs": [
				"data_theft",
				"sabotage"
			]
		}
	],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.308-309"
}
```

### #16 Manor of Terror

Haunted house of top-grade holography and animatronic drones, re-themed every year for Fright Nights (wristband D).

```world locations.locations.playland_16
{
	"name": "Manor of Terror",
	"district": "playland",
	"number": 16,
	"type": "attraction",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 3,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "The Taggers sleep in the staff tunnels beneath the Manor.",
	"cite": "NC2045 p.309"
}
```

### #17 GunMart Museum of Movie Weapons

Mostly empty museum of famous film weapons (wristband B); a Tech runs a custom build shop out the back.

```world locations.locations.playland_17
{
	"name": "GunMart Museum of Movie Weapons",
	"district": "playland",
	"number": 17,
	"type": "attraction",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark; exhibit by GunMart",
	"security_code": {
		"n": 3,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Never Naughty Nedd (Tech 7)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "Exhibit halls with Nedd's custom build shop in the back.",
	"cite": "NC2045 p.309"
}
```

### #18 Haunted Woods Warfare

Capture-the-runestone LARP with foam crossbows, dartguns and melee weapons (wristband D).

```world locations.locations.playland_18
{
	"name": "Haunted Woods Warfare",
	"district": "playland",
	"number": 18,
	"type": "attraction",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 3,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "The Children of the Night live in its big storage shed, 'The Dark Crypt'.",
	"cite": "NC2045 p.309"
}
```

### #19 Horror Classics Buffet Theatre

All-you-can-eat Kibble and movies, effectively the park's cheapest place to sleep.

```world locations.locations.playland_19
{
	"name": "Horror Classics Buffet Theatre",
	"district": "playland",
	"number": 19,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 3,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.309"
}
```

### #20 Frighthunter Society Lodge

Monster-hunter themed fireside restaurant.

```world locations.locations.playland_20
{
	"name": "Frighthunter Society Lodge",
	"district": "playland",
	"number": 20,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 3,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "The Guardians live in the attic and sometimes help staff it.",
	"cite": "NC2045 p.309"
}
```

### #21 Wharf Club

Closed former boat club of the elite, who now berth at Obsidian Equinox; Tower of Dark may rebuild it as the base for a planned cruise ship.

```world locations.locations.playland_21
{
	"name": "Wharf Club",
	"district": "playland",
	"number": 21,
	"type": "docks",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.308"
}
```

### #22 Wharf Hotel

Snooty 500eb-a-night hotel offering hammocks or beds.

```world locations.locations.playland_22
{
	"name": "Wharf Hotel",
	"district": "playland",
	"number": 22,
	"type": "hotel",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "The Beaverdam yogang lives in the attic.",
	"cite": "NC2045 p.308"
}
```

### #23 Paradiso Acqua

By-reservation Neo-Italian seafood at 500eb a head, credit check required.

```world locations.locations.playland_23
{
	"name": "Paradiso Acqua",
	"district": "playland",
	"number": 23,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Leonardo Calvano (Rockerboy 7), chef",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Leonardo Calvano (Rockerboy 7)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.308"
}
```

### #24 Artificial Beach

Fake sandy beach, no swimming.

```world locations.locations.playland_24
{
	"name": "Artificial Beach",
	"district": "playland",
	"number": 24,
	"type": "park",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "The Thrashers live in abandoned-looking cabanas at the back.",
	"cite": "NC2045 p.307"
}
```

### #25 Grand Trolley Yard

Hub of the replica San Francisco streetcars linking the lands (wristband B).

```world locations.locations.playland_25
{
	"name": "Grand Trolley Yard",
	"district": "playland",
	"number": 25,
	"type": "transport",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "The central nexus of the park's staff tunnels lies beneath; the Throwdown run a 3am drone fight club here and sleep in the janitor's closets.",
	"cite": "NC2045 p.307-308"
}
```

### #26 Meet & Greet Plaza

Photo-ops with the park mascots (wristband C).

```world locations.locations.playland_26
{
	"name": "Meet & Greet Plaza",
	"district": "playland",
	"number": 26,
	"type": "park",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.308"
}
```

### #27 Lemon-Aid Rx

Stand selling nitro lemonade that is essentially liquid Surge; Trauma Team answers more overdoses here than gang violence. A second dose within 24h inflicts the Brain Injury Critical Injury.

```world locations.locations.playland_27
{
	"name": "Lemon-Aid Rx",
	"district": "playland",
	"number": 27,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.308"
}
```

### #28 San Francisco Sweets

Real-sugar hand-pulled taffy, 25eb.

```world locations.locations.playland_28
{
	"name": "San Francisco Sweets",
	"district": "playland",
	"number": 28,
	"type": "shop",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.308"
}
```

### #29 Sourdough Central

Bakery whose free sample after an hour-long video is lunch for many yogang kids.

```world locations.locations.playland_29
{
	"name": "Sourdough Central",
	"district": "playland",
	"number": 29,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.308"
}
```

### #30 Grand Junction Gift Shop

Souvenirs (20-100eb) and 50eb/day scooter rental.

```world locations.locations.playland_30
{
	"name": "Grand Junction Gift Shop",
	"district": "playland",
	"number": 30,
	"type": "shop",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.307"
}
```

### #31 Ticket Gate

The park entrance (map only): entry fees, wristbands, the no-weapons and no-re-entry rules apply here.

```world locations.locations.playland_31
{
	"name": "Ticket Gate",
	"district": "playland",
	"number": 31,
	"type": "transport",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.302-303"
}
```

### #32 Lost & Found

Near the gate, where drones deposit lost items.

```world locations.locations.playland_32
{
	"name": "Lost & Found",
	"district": "playland",
	"number": 32,
	"type": "shop",
	"owner": "protective_lightning",
	"owner_name": "Protective Lightning",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "The Packrats live in the basement and keep what they like.",
	"cite": "NC2045 p.308"
}
```

### #33 Classique Corsets

Vintage clothing and 100eb historically accurate corsets.

```world locations.locations.playland_33
{
	"name": "Classique Corsets",
	"district": "playland",
	"number": 33,
	"type": "shop",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "protective_lightning",
		"intensity": "medium",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.307"
}
```

### #34 Garden of Desire

Ziggurat's dating algorithm sends guests to private garden niches, usually to a park joytoy, or a Piranha dealer if they ask for drugs (wristband A).

```world locations.locations.playland_34
{
	"name": "Garden of Desire",
	"district": "playland",
	"number": 34,
	"type": "club",
	"owner": "piranhas",
	"owner_name": "Piranhas (land); algorithm by Ziggurat",
	"security_code": {
		"n": 8,
		"faction": "piranhas",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [
		"gang_hit"
	],
	"interior": "",
	"cite": "NC2045 p.306"
}
```

### #35 Smash Bar & Grill

Sports bar with awful food and excellent Piranha-supplied Smash.

```world locations.locations.playland_35
{
	"name": "Smash Bar & Grill",
	"district": "playland",
	"number": 35,
	"type": "bar",
	"owner": "piranhas",
	"owner_name": "Piranhas (land)",
	"security_code": {
		"n": 8,
		"faction": "piranhas",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.307"
}
```

### #36 Aquarium Fantastique

The Piranhas' 'classy' club, Biotechnica-sponsored: glowing fish tanks and AquaForm Bioexotic performers (wristband E).

```world locations.locations.playland_36
{
	"name": "Aquarium Fantastique",
	"district": "playland",
	"number": 36,
	"type": "club",
	"owner": "piranhas",
	"owner_name": "Piranhas; sponsor Biotechnica",
	"security_code": {
		"n": 8,
		"faction": "piranhas",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Piranha initiations rumouredly end with the recruit thrown into a tank of real piranhas.",
			"gigs": [
				"rescue",
				"gang_hit"
			]
		}
	],
	"gigs": [
		"gang_hit"
	],
	"interior": "",
	"cite": "NC2045 p.306"
}
```

### #37 Hydrosubsidium Artificial Ocean

Indoor wave pool for drinking and floating safely, sponsored by Hydrosubsidium (wristband B).

```world locations.locations.playland_37
{
	"name": "Hydrosubsidium Artificial Ocean",
	"district": "playland",
	"number": 37,
	"type": "attraction",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark; sponsor Hydrosubsidium",
	"security_code": {
		"n": 8,
		"faction": "piranhas",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Often 'closed for maintenance': it is rented to PMCs for ocean-assault training.",
			"gigs": [
				"data_theft",
				"sabotage"
			]
		}
	],
	"gigs": [
		"data_theft"
	],
	"interior": "",
	"cite": "NC2045 p.307"
}
```

### #38 The Playtower

Observation tower with four rotating euro clubs (Elektrisch, Chrom, Rost, Neu) (wristband D).

```world locations.locations.playland_38
{
	"name": "The Playtower",
	"district": "playland",
	"number": 38,
	"type": "club",
	"owner": "piranhas",
	"owner_name": "Piranhas (land)",
	"security_code": {
		"n": 8,
		"faction": "piranhas",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [
		"Corpse Reviver (Exec 4)"
	],
	"hooks": [
		{
			"text": "The Piranhas' private VIPiranna club sits at the tower's centre, where Corpse Reviver stages shows of power for important clients.",
			"gigs": [
				"assassination",
				"gang_hit"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"assassination"
	],
	"interior": "Four spinning clubs around a central VIPiranna private club.",
	"cite": "NC2045 p.307"
}
```

### #39 Changing Rooms

Changing rooms and swimsuit rental by the Artificial Ocean (map only).

```world locations.locations.playland_39
{
	"name": "Changing Rooms",
	"district": "playland",
	"number": 39,
	"type": "park",
	"owner": "piranhas",
	"owner_name": "Piranhas (land)",
	"security_code": {
		"n": 8,
		"faction": "piranhas",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.302, p.307"
}
```

### #40 Island Dreams Hotel

Adults-only cabana suites, 200eb a night.

```world locations.locations.playland_40
{
	"name": "Island Dreams Hotel",
	"district": "playland",
	"number": 40,
	"type": "hotel",
	"owner": "piranhas",
	"owner_name": "Piranhas (land)",
	"security_code": {
		"n": 8,
		"faction": "piranhas",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.307"
}
```

### #41 Hall of Nightmares

Hall of twisted mirrors and old holograms (wristband A).

```world locations.locations.playland_41
{
	"name": "Hall of Nightmares",
	"district": "playland",
	"number": 41,
	"type": "attraction",
	"owner": "piranhas",
	"owner_name": "Piranhas (land)",
	"security_code": {
		"n": 8,
		"faction": "piranhas",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "The Glitters live in a basement storeroom beneath it.",
	"cite": "NC2045 p.307"
}
```

### #42 Submarine Tours

'Closed for renovations' since an accident four years ago.

```world locations.locations.playland_42
{
	"name": "Submarine Tours",
	"district": "playland",
	"number": 42,
	"type": "attraction",
	"owner": "piranhas",
	"owner_name": "Piranhas",
	"security_code": {
		"n": 8,
		"faction": "piranhas",
		"intensity": "heavy",
		"hardened": false
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "The Piranhas run a drug lab inside the closed ride.",
			"gigs": [
				"gang_hit",
				"sabotage"
			]
		}
	],
	"gigs": [
		"gang_hit",
		"sabotage"
	],
	"interior": "",
	"cite": "NC2045 p.307"
}
```

### #43 Continental Brands Kibble Court

Kibble canteen with a miniature Kibble-factory exhibit; staff eat here at a discount.

```world locations.locations.playland_43
{
	"name": "Continental Brands Kibble Court",
	"district": "playland",
	"number": 43,
	"type": "restaurant",
	"owner": "continental_brands",
	"owner_name": "Continental Brands",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.311"
}
```

### #44 Old Hero's Point LARP-A-Rinth

A costly Elflines Online recreation brought to life with holo-upgraded drones (wristband B).

```world locations.locations.playland_44
{
	"name": "Old Hero's Point LARP-A-Rinth",
	"district": "playland",
	"number": 44,
	"type": "attraction",
	"owner": "segotari",
	"owner_name": "Segotari",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "Techs were overheard calling it a 'live testing operation'.",
			"gigs": [
				"data_theft",
				"corp_extraction"
			]
		},
		{
			"text": "Militech guards the zone so Segotari's robotics and virtuality tech can't leak to competitors.",
			"gigs": [
				"data_theft",
				"corp_extraction"
			]
		}
	],
	"gigs": [
		"data_theft",
		"corp_extraction"
	],
	"interior": "",
	"cite": "NC2045 p.311"
}
```

### #45 The Hula Room

Luau dinner show by Rocklin Augmentics' chromed fire dancers and animatronic helpers; it caught fire twice this year.

```world locations.locations.playland_45
{
	"name": "The Hula Room",
	"district": "playland",
	"number": 45,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark; sponsor Rocklin Augmentics",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.311"
}
```

### #46 Klaws

Nail, light-tattoo and techhair salon charging double for fashionware; Piranha-owned.

```world locations.locations.playland_46
{
	"name": "Klaws",
	"district": "playland",
	"number": 46,
	"type": "shop",
	"owner": "piranhas",
	"owner_name": "Piranhas",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [
		"Scratcher (Medtech 4)"
	],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.311"
}
```

### #47 Bioexotic Cat Café

Maid café that books Biotechnica Bioexotics makeovers without a fixer; staff push hard for commission.

```world locations.locations.playland_47
{
	"name": "Bioexotic Cat Café",
	"district": "playland",
	"number": 47,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark; sponsor Biotechnica",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.311"
}
```

### #48 Boba World

Giant-sphere boba lounge that was meant to be Petrochem's World of Chemistry; its unreleased merch sells high to collectors.

```world locations.locations.playland_48
{
	"name": "Boba World",
	"district": "playland",
	"number": 48,
	"type": "restaurant",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.311"
}
```

### #49 Port Treasure Shipyard

Water ride battling cursed pirates on a heaving ship, same tech as Old Hero's Point (wristband C).

```world locations.locations.playland_49
{
	"name": "Port Treasure Shipyard",
	"district": "playland",
	"number": 49,
	"type": "attraction",
	"owner": "segotari",
	"owner_name": "Segotari",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.311"
}
```

### #50 Autumn Palace Hotel

Segotari's luxury recreation of an Elflines Online palace, 350eb a night.

```world locations.locations.playland_50
{
	"name": "Autumn Palace Hotel",
	"district": "playland",
	"number": 50,
	"type": "hotel",
	"owner": "segotari",
	"owner_name": "Segotari",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.310"
}
```

### #51 The Elflines Online Experience

Free, unlimited Elflines play on a complimentary Surge IV drip, with a Segotari Station arcade upstairs.

```world locations.locations.playland_51
{
	"name": "The Elflines Online Experience",
	"district": "playland",
	"number": 51,
	"type": "attraction",
	"owner": "segotari",
	"owner_name": "Segotari",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [
		{
			"text": "It can't be making money; players reportedly stay logged in for months. Something is wrong here.",
			"gigs": [
				"data_theft",
				"rescue"
			]
		},
		{
			"text": "Rumour places the Night City Elflines Online servers under the Discovery Zone.",
			"gigs": [
				"data_theft",
				"sabotage"
			]
		}
	],
	"gigs": [
		"data_theft",
		"rescue",
		"sabotage"
	],
	"interior": "Ground floor of immersion stations with IV drips; Segotari Station arcade upstairs.",
	"cite": "NC2045 p.311"
}
```

### #52 VIP Parking Lot

VIP parking at the Discovery Zone end of the park (map only).

```world locations.locations.playland_52
{
	"name": "VIP Parking Lot",
	"district": "playland",
	"number": 52,
	"type": "transport",
	"owner": "tower_of_dark",
	"owner_name": "Tower of Dark",
	"security_code": {
		"n": 7,
		"faction": "militech",
		"intensity": "light",
		"hardened": true
	},
	"utility_code": null,
	"npcs": [],
	"hooks": [],
	"gigs": [],
	"interior": "",
	"cite": "NC2045 p.302"
}
```

## Fixers

- Ricky Hamilton (Fixer 4) — Piranha leader in the park; sets and enforces the gang's Playland rules (p.304).

## Personalities

- No Personalities section for Playland; named people in the entries:
- Jericho Hunt (Media 5) — reporter who annotated the park brochure; has lived in the park for weeks on a hacked wristband.
- Ricky Hamilton (Fixer 4) — Piranha leader who laid down the gang's park rules.
- Corpse Reviver (Exec 4) — Piranhas boss, shows up at the Playtower's VIPiranna.
- Leonardo Calvano (Rockerboy 7) — celebrity chef of Paradiso Acqua; smug.
- Never Naughty Nedd (Tech 7) — movie-mad Tech with a custom build shop behind the GunMart Museum.
- Clementine (Rockerboy 4) — Piranha who performs as Merri the Mermaid.
- Miguel (Solo 5) — Samson FBC in a turtle-shell cart, Torta Tortoise; son of Torta-sienda's owners in Pacifica.
- Scratcher (Medtech 4) — day-shift lead stylist at Klaws.
