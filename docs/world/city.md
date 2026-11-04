# Night City

The city's districts, from the Night City 2045 sourcebook (cited as `NC2045 p.N`, PDF page numbers;
the printed page is one less). Each district section lives in its own doc, `docs/world/nc_<district>.md`,
next to that district's locations. Numbers and short paraphrases only; never paste the book's text.

## District schema

At `city.districts.<id>` (id: snake_case of the district name, e.g. `little_europe`):

- `name`, `region`: island | northside | mainland | southside | outskirts | playland.
- `manager`: `{"name": "...", "role": "Fixer 6"}` (the City Manager, Role and Rank as printed), or `null`.
- `population`: a short paraphrase (e.g. "~120,000, mostly corp families").
- `security_code`: `{"n": 6, "faction": "<faction id>", "intensity": "light|medium|heavy", "hardened": true}`
  (the book: `Security Code #: <Faction>, <[Hardened] Light|Medium|Heavy>`, p.7; a roll under `n` on 1d10 means a response; `n` 11 = always).
- `utility_code`: the number (p.8: roll 1d10 per utility; under it, that utility is out).
- `provider`: the security provider's faction id.
- `gangs`: faction ids with influence here (map icons and text).
- `ncart`: station names in the district.
- `profile`: the closest neighbourhood generator in `data/gen/districts.json`
  (corporate_center, executive_zone, market_streets, mixed_residential, combat_zone, hot_zone, burning_zone, industrial, pacifica).
- `look`: 3-6 short tags for the generated scenes (e.g. `["old stone", "neon", "tourist", "clean streets"]`).
- `history`: one paraphrased line.
- `cite`: `"NC2045 p.N-M"`.

```world city
{
	"_doc": "Night City's districts (World.district / World.districts), from the Night City 2045 sourcebook: manager, population, Security Code (n: faction, intensity, hardened), Utility Code, provider, gang influence, NCART stations, the neighbourhood generator profile, look tags, history, cite. Generated from docs/world/city.md and docs/world/nc_*.md.",
	"districts": {}
}
```
