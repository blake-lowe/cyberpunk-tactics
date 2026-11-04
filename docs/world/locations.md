# Locations

Named places in Night City: who owns them, what neighbourhood or site they are, how well guarded,
and which jobs happen there. When a gig's target faction owns a location that fits the job, the
fixer board sends the crew there (`Campaign._place_for`); otherwise the gig gets a generic place as
before. Data blocks build `data/world/locations.json`.

Status: being filled from the Night City 2045 sourcebook (M9 phase 1), one doc per district (`docs/world/nc_<district>.md`). Numbers and short paraphrases only.

## Schema

Each entry, at `locations.locations.<id>` (id: `<district id>_<number>` for numbered places, e.g.
`little_europe_15`; `outskirts_7`, `playland_<land>_<n>`), written in `docs/world/nc_<district>.md`:

- `name`, `district` (a `city.districts` id), `number` (its map pin; `null` if none).
- `type`: one of the vocabulary below; it decides which generator plays the place.
- `owner`: a faction id (gang, corp, crime family, provider) when a faction owns or runs it, else `""`;
  `owner_name`: the owning person or company as printed, e.g. `"Rosa Ito (Fixer 5)"`.
- `security_code`: `{"n": 6, "faction": "<faction id>", "intensity": "light|medium|heavy", "hardened": true}`
  as printed for the location (p.7). `utility_code`: the number if it differs from the district's, else `null`.
- `npcs`: named people as printed, `"Name (Role Rank)"`, short.
- `hooks`: rumours, secrets, feuds or jobs in the entry, each `{"text": "<one-line paraphrase>",
  "gigs": [<gig kinds it could become>]}`; gig kinds: data_theft, gang_hit, corp_extraction,
  assassination, rescue, sabotage.
- `gigs`: gig kinds that fit the place overall (from its owner and hooks); `[]` for places that are
  only scenery (a park, a public square).
- `interior`: one short paraphrase of any layout the book gives (floors, wings, guards, vaults), or `""`.
- `cite`: `"NC2045 p.N"`.

`site` / `profile` / `scene` and the old `security` range are derived by the game from `type` and
`security_code` (World.location), so the entries don't repeat them.

### Type vocabulary → generator (`locations.types`)

```world locations.types
{
	"bar": {"site": "bar"}, "club": {"site": "club"}, "casino": {"site": "club"},
	"shop": {"site": "shop"}, "gun_shop": {"site": "gun_shop"}, "chop_shop": {"site": "chop_shop"},
	"market": {"profile": "market_streets"}, "restaurant": {"site": "restaurant"},
	"housing": {"site": "apartments"}, "cube_hotel": {"site": "capsule_hotel"}, "hotel": {"site": "hotel"},
	"megabuilding": {"scene": "megablock"}, "squat": {"site": "squat"}, "villa": {"site": "villa"},
	"corp_office": {"site": "corp_office"}, "corp_hq": {"site": "corp_hq"}, "data_center": {"site": "data_center"},
	"bank": {"site": "bank"}, "media": {"site": "corp_office"}, "lab": {"site": "corp_office"},
	"factory": {"site": "factory"}, "warehouse": {"site": "warehouse"}, "utility": {"site": "substation_booth"},
	"docks": {"scene": "shipyard"}, "ship": {"site": "ship"}, "transport": {"site": "station"}, "rail": {"scene": "rail_yard"},
	"medical": {"site": "clinic"}, "police": {"site": "ncpd_precinct"}, "military": {"scene": "corp_campus"},
	"gang_base": {"site": "gang_hideout"}, "church": {"site": "temple"}, "school": {"site": "school"},
	"civic": {"site": "corp_office"}, "venue": {"site": "club"}, "stadium": {"scene": "street_block"},
	"park": {"scene": "street_block"}, "ruin": {"profile": "hot_zone"}, "farm": {"scene": "badlands"},
	"outskirts_site": {"scene": "badlands"}, "attraction": {"site": "club"}
}
```

Restaurants, hotels, banks and schools have programmed sites of their own (M9 phase 3: sites.json
`restaurant`, `hotel`, `bank`, `school`, laid out room by room from an architectural brief). Types
still without a generator of their own (civic, stadium, park, media, lab) borrow the nearest one.

## Registry

```world locations
{
	"_doc": "Named Night City locations (World.location / World.locations_for): owner faction, place (profile | site | scene), security range, gig kinds, cite. Generated from docs/world/locations.md.",
	"locations": {}
}
```
