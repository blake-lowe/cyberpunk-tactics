# Locations

Named places in Night City: who owns them, what neighbourhood or site they are, how well guarded,
and which jobs happen there. When a gig's target faction owns a location that fits the job, the
fixer board sends the crew there (`Campaign._place_for`); otherwise the gig gets a generic place as
before. Data blocks build `data/world/locations.json`.

Status: **empty, by design**. This is the slot the Night City 2047 pass fills: one section per
place, a page-cited paraphrase, and a data block. Numbers and short paraphrases only.

## Schema

Each entry, at `locations.locations.<id>`:

- `name`: what the board calls it.
- `owner`: a faction id from `factions.md`.
- Where it is, one of:
  - `profile`: a neighbourhood profile from `data/gen/districts.json` (plays as a neighbourhood);
  - `site`: a building type from `data/gen/sites.json` (plays as a raid on that building);
  - `scene`: a scene from `data/gen/scenes.json` (or a themed scene: undercity, arcology, warzone).
- `security`: `[min, max]` security level for gigs here (1-3).
- `gigs`: gig kinds (gigs.json templates) that can happen here.
- `cite`: the source page, e.g. `NC2047 p.NN`, or `RULES-UNVERIFIED`.

An example entry (not data: no `world` tag):

```json
{"name": "Example depot", "owner": "militech", "site": "warehouse", "security": [2, 3],
 "gigs": ["sabotage", "corp_extraction"], "cite": "RULES-UNVERIFIED"}
```

## Registry

```world locations
{
	"_doc": "Named Night City locations (World.location / World.locations_for): owner faction, place (profile | site | scene), security range, gig kinds, cite. Generated from docs/world/locations.md.",
	"locations": {}
}
```
