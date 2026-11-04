class_name DistrictLook
extends RefCounted
## A Night City district's look (data/gen/district_looks.json), from its look tags and the book's
## description: what its streets wear (SceneTheme keys: palette, neon, lamps, light, facades,
## sign density, grime) and how its neighbourhood is built (DistrictGen keys: ruin, height,
## greenery, street furniture, cars, extra lot uses). A gig carries its district in
## params.district; scenes with a theme of their own (undercity, arcology, warzone) ignore it.

## Numeric keys every look has, with their allowed range.
const RANGES := {"signs": [0.0, 2.0], "grime": [0.0, 2.0], "ruin": [0.0, 1.0], "height": [-1, 2], "green": [0.0, 1.0],
	"props": [0.0, 2.0], "cars": [0.0, 2.0]}
## Optional numeric keys, with their allowed range.
const OPTIONAL := {"lamp_keep": [0.0, 1.0], "blaze": [0.0, 1.0], "wrecks": [0.0, 1.0]}
## Street furniture without a district (DistrictGen's old fixed set).
const STREET := ["vending", "vending", "bench", "kiosk", "barrel"]


static func looks() -> Dictionary:
	return RulesDB.gen("district_looks.json")["looks"]


static func has(id: String) -> bool:
	return looks().has(id)


## District `id`'s look ({} for none or unknown).
static func of(id: String) -> Dictionary:
	return looks().get(id, {})


## The look of the district a map's gig is in ({} if none, or if the scene has a theme of its own).
static func of_params(p: Dictionary) -> Dictionary:
	if RulesDB.gen("themes.json")["themes"].has(String(p.get("scene", ""))):
		return {}
	return of(String(p.get("district", "")))


## A numeric look value, `fallback` when the look doesn't set it.
static func num(look: Dictionary, key: String, fallback: float) -> float:
	return float(look.get(key, fallback))


## A neighbourhood profile (districts.json) as the district builds it: its mix plus the look's
## lot uses (and park weight for greenery), decay from the look's ruin, floors shifted by its
## height (capped by `cap`), parked cars scaled. The profile itself is not modified.
static func profile(prof: Dictionary, look: Dictionary, cap: int) -> Dictionary:
	if look.is_empty():
		return prof
	var p := prof.duplicate(true)
	var mix: Dictionary = p.mix
	for k in look.get("mix", {}):
		mix[k] = float(mix.get(k, 0.0)) + float(look.mix[k])
	var green := num(look, "green", 0.0)
	if green > 0.0:
		mix["park"] = float(mix.get("park", 0.0)) + green * 3.0
	if look.has("ruin"):
		var r := num(look, "ruin", 0.0)
		p.decay = [r * 0.6, minf(1.0, r * 1.2 + 0.05)] if r > 0.0 else [0.0, 0.0]
	var h := int(look.get("height", 0))
	var lo := clampi(int(p.floors[0]) + h, 1, cap)
	p.floors = [lo, clampi(int(p.floors[1]) + h, lo, cap)]
	p.cars = float(p.cars) * num(look, "cars", 1.0)
	if look.has("wrecks"):
		p.wreck_ratio = num(look, "wrecks", 0.0)
	return p
