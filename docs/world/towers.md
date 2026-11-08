# Towers

Night City's tall buildings as data, for tower gigs (docs/plans/towers.md, owner-approved 2026-11-08). A tower
gig plays one **band** of a tall building: a few storeys a gig can happen on, e.g. Raven Microcybernetics'
floors 48-50 and the roof. The crew rides a lift car up to the band's lift lobby and rides it down again to
get out; responders come up the lift or the fire stairs. The HUD names the floors by their real storey.

Each block below sets `locations.locations.<id>.tower` (the place's own entry is in its district's doc):

- `id`: a short name for dev flags (`--tower=raven`); `name`: what the floor strip calls the building.
- `storeys`: storeys above the street, the roof not counted. `storeys_ours`: true when the book gives no height
  and the total is ours (owner decision 9: plausible values where floors are a reasonable expectation).
- `recipe`: the site in `data/gen/sites.json` the band is built from (`tower_corp`, `tower_hotel`): its floor
  plate, its storey programmes and how its rooms are guarded.
- `plate`: optional `[[w min, w max], [d min, d max]]` floor plate in squares (2 m), else the recipe's. Ours.
- `bands.<band>`: `storeys` [first, last], `roof` (the band's roof is played: R on the strip),
  `programme` (one storey programme of the recipe per storey, bottom up), `gigs` (the jobs the band hosts).
  Stage 1a builds the **sky** band only (the top of the building); the street, staging and mid bands come with
  stages 1b and 2 and are only described here.
- `ours`: which numbers the book does not give. `cite`: the book page.

Not band towers (plan section 1): Eurasiabank Plaza (sunken, BasementGen's set piece), Totentanz/Burleson Tower
(played at the club), Militech Offices and Trauma Team Tower (downward bands, later). Tyger Works, Guăngbō
Tower, Megabuilding H10, Nakagawa Kabuki Theater, the Hall of Justice, the Convention Center and Digital
Divinity need gang, civic or theatre storey programmes and wait for stage 4 (canon towers).

## Raven Microcybernetics (The Glen #24)

The pilot. A deliberately forgettable skyscraper: tenants on floors 1-39, Raven on 40-50 (p.124-125). The book
tops out at 50; the sky band is Raven's top three floors and the roof. Ours: which three of Raven's eleven floors
are played (48 a reception and office floor, 49 labs, 50 the executive floor where Ziv Ellis sits), the plate.

```world locations.locations.the_glen_24.tower
{
	"id": "raven",
	"name": "Raven Microcybernetics",
	"storeys": 50,
	"storeys_ours": false,
	"recipe": "tower_corp",
	"bands": {
		"sky": {"storeys": [48, 50], "roof": true, "programme": ["reception", "lab", "exec"],
			"gigs": ["data_theft", "corp_extraction", "assassination"]}
	},
	"ours": ["sky band storeys 48-50 of Raven's 40-50", "storey programmes", "plate"],
	"cite": "NC2045 p.124-125"
}
```

## Merrill, Asukaga & Finch, Thurgood Towers (The Glen #19)

Twin white skyscrapers joined by walkways every 10 floors; MA&F holds the top floors, seen by appointment and
under armed escort, and about half the other floors stand empty; a staff implant works the doors and lifts
(p.123). The book gives no height: ours 60, so the walkways fall on 10, 20 ... 60 and the sky band is 58-60.

```world locations.locations.the_glen_19.tower
{
	"id": "maf",
	"name": "Thurgood Towers (MA&F)",
	"storeys": 60,
	"storeys_ours": true,
	"recipe": "tower_corp",
	"bands": {
		"sky": {"storeys": [58, 60], "roof": true, "programme": ["office", "exec", "exec"],
			"gigs": ["data_theft", "corp_extraction", "assassination"]}
	},
	"ours": ["storeys 60", "sky band 58-60", "storey programmes", "plate"],
	"cite": "NC2045 p.123"
}
```

## Continental Brands Office (Downtown #5)

Public floors low (a Megamart, test-kitchen tours), staff-only offices and labs in the middle, executive suites on
the top five floors (p.83). Height ours: 40, so the suites are 36-40 and the sky band takes the top three.

```world locations.locations.downtown_5.tower
{
	"id": "continental",
	"name": "Continental Brands",
	"storeys": 40,
	"storeys_ours": true,
	"recipe": "tower_corp",
	"bands": {
		"sky": {"storeys": [38, 40], "roof": true, "programme": ["exec", "lab", "exec"],
			"gigs": ["data_theft", "sabotage", "corp_extraction"]}
	},
	"ours": ["storeys 40", "sky band 38-40 of the top five", "storey programmes", "plate"],
	"cite": "NC2045 p.83"
}
```

## Ziggurat Headquarters (Upper Marina #40)

The curved tower: CitiNet repair bays low, development and the CitiNet/Data Pool control floors in the middle,
executives high and the founder's suite at the apex (p.78). Its street level is the `ziggurat_hq` set piece;
the tower gig plays the apex. Height ours: 70; the apex band is 68-70 with the suite on top.

```world locations.locations.upper_marina_40.tower
{
	"id": "ziggurat",
	"name": "Ziggurat HQ",
	"storeys": 70,
	"storeys_ours": true,
	"recipe": "tower_corp",
	"bands": {
		"sky": {"storeys": [68, 70], "roof": true, "programme": ["exec", "exec", "apex"],
			"gigs": ["data_theft", "sabotage", "corp_extraction", "assassination"]}
	},
	"ours": ["storeys 70", "apex band 68-70", "storey programmes", "plate"],
	"cite": "NC2045 p.78"
}
```

## Haakensen Tower (South Night City #6)

The district's only new skyscraper: a café on the ground floor, Scythe Security on 2F and in the garage, and
Haakensen's offices on the top floors (p.143). Height ours: 45; the band is a tenant floor under Haakensen's two.

```world locations.locations.south_night_city_6.tower
{
	"id": "haakensen",
	"name": "Haakensen Tower",
	"storeys": 45,
	"storeys_ours": true,
	"recipe": "tower_corp",
	"bands": {
		"sky": {"storeys": [43, 45], "roof": true, "programme": ["office", "exec", "exec"],
			"gigs": ["data_theft", "assassination", "sabotage"]}
	},
	"ours": ["storeys 45", "sky band 43-45", "storey programmes", "plate"],
	"cite": "NC2045 p.143"
}
```

## New Libertine Tower (Downtown #18)

A teal tower: Whitewater Security on floors 1-3, a private clinic on 5, City Manager Ortega on the top two
(p.86). Height ours: 36; the band is the floor under Ortega's and his two.

```world locations.locations.downtown_18.tower
{
	"id": "libertine",
	"name": "New Libertine Tower",
	"storeys": 36,
	"storeys_ours": true,
	"recipe": "tower_corp",
	"bands": {
		"sky": {"storeys": [34, 36], "roof": true, "programme": ["office", "exec", "exec"],
			"gigs": ["data_theft", "assassination", "sabotage"]}
	},
	"ours": ["storeys 36", "sky band 34-36", "storey programmes", "plate"],
	"cite": "NC2045 p.86"
}
```

## Segotari HQ / EXCEL-1 (Kabuki #19)

The bottom nine floors are EXCEL-1's entertainment hub, the offices are above, a cube hotel is in the basement
(p.206). Height ours: 30.

```world locations.locations.kabuki_19.tower
{
	"id": "segotari",
	"name": "Segotari HQ",
	"storeys": 30,
	"storeys_ours": true,
	"recipe": "tower_corp",
	"bands": {
		"sky": {"storeys": [28, 30], "roof": true, "programme": ["office", "lab", "exec"],
			"gigs": ["data_theft", "sabotage"]}
	},
	"ours": ["storeys 30", "sky band 28-30", "storey programmes", "plate"],
	"cite": "NC2045 p.206"
}
```

## Network 54 Plaza (New Westbrook #15)

A self-contained fortress tower crowned by the N54 sign: offices, studios, talent housing and public viewing
rooms (p.218). Heights ours: 55, talent and executive floors at the top.

```world locations.locations.new_westbrook_15.tower
{
	"id": "n54",
	"name": "Network 54 Plaza",
	"storeys": 55,
	"storeys_ours": true,
	"recipe": "tower_corp",
	"bands": {
		"sky": {"storeys": [53, 55], "roof": true, "programme": ["office", "exec", "exec"],
			"gigs": ["data_theft", "corp_extraction", "sabotage"]}
	},
	"ours": ["storeys 55", "sky band 53-55", "storey programmes", "plate"],
	"cite": "NC2045 p.218"
}
```

## Highcourt Plaza Hotel (Old Japantown #8)

An expensive Art Deco hotel in a combat zone: indoor pools, spas and fine dining, guests flown in and out by
Aerocab AV (p.132). The book gives no height and does not call it a tower; the plan (section 1) names it the hotel
tower candidate. Ours: 30 storeys, guest rooms, suites and the spa at the top. There is no Aerocab insertion yet
(owner decision 4): the crew comes up the lift like everyone else. Flagged for owner review.

```world locations.locations.old_japantown_8.tower
{
	"id": "highcourt",
	"name": "Highcourt Plaza",
	"storeys": 30,
	"storeys_ours": true,
	"recipe": "tower_hotel",
	"bands": {
		"sky": {"storeys": [28, 30], "roof": true, "programme": ["guest", "suite", "spa"],
			"gigs": ["assassination", "corp_extraction", "data_theft"]}
	},
	"ours": ["storeys 30", "a tower at all (the book gives no height)", "sky band 28-30", "storey programmes", "plate"],
	"cite": "NC2045 p.132"
}
```
