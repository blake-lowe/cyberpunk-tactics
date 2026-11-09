class_name TowerLook
extends RefCounted
## A tower's look (data/gen/tower_looks.json): its facade, window light and crown, picked by the
## tower's short id (docs/world/towers.md), else by its recipe (sites.json tower_*), laid over the
## default so every key is there. TowerDress builds the impostor facade, crown and greebles from
## it, and WorldBuilder dresses the band's own outer walls with it, so the band and the facade under
## it read as one building. Pure data plus lookups (headless-testable).

## Window heights in a storey (from its floor, world units; WorldBuilder.FH = 1.6) for the band's
## glass runs and the impostor's glass cells: the strip from sill to lintel is glass.
const SILL := 0.32
const LINTEL := 1.32
## A punched window (a hotel's rooms; WorldBuilder._punched_window): its pane and heights.
const PUNCH_W := 0.46
const PUNCH_SILL := 0.42
const PUNCH_LINTEL := 1.2


static func data() -> Dictionary:
	return RulesDB.gen("tower_looks.json")


## The look of tower `id` (its short id, "raven") built from `recipe` (tower_corp / tower_hotel):
## the default, then the recipe's, then the tower's own keys. `id` = "" or unknown: no tower layer.
static func resolve(id: String, recipe := "") -> Dictionary:
	var d := data()
	var out: Dictionary = (d.get("default", {}) as Dictionary).duplicate(true)
	out.merge(d.get("recipes", {}).get(recipe, {}), true)
	out.merge(d.get("towers", {}).get(id, {}), true)
	out.erase("_why")
	out["id"] = id
	return out


## The look of a tower band's map ({} off a tower).
static func of(m: TacMap) -> Dictionary:
	if m == null or not m.is_tower():
		return {}
	return resolve(String(m.tower.get("id", "")), String(m.tower.get("recipe", "")))


## A colour key of a look (fallback when missing or "": no such light).
static func col(lk: Dictionary, key: String, fallback := Color.BLACK) -> Color:
	var s := String(lk.get(key, ""))
	return Color(s) if s != "" else fallback


## Whether a look has a key's light (a seam, a ledge, a trim...).
static func has(lk: Dictionary, key: String) -> bool:
	return String(lk.get(key, "")) != ""


## 0..1 from a few ints, the same on every machine (hash() of a Vector4i is deterministic).
static func h01(a: int, b: int, c: int, d: int) -> float:
	return float(posmod(hash(Vector4i(a, b, c, d)), 10007)) / 10007.0


## Whether room `room` of storey `storey` is lit at night on a tower seeded `seed` (the band's own
## lit panes; the impostor's shader draws the same odds): a share of storeys stay dark, a few are
## lit end to end, the rest light room by room at the look's `lit` share.
static func room_lit(lk: Dictionary, storey: int, room: int, seed_value: int) -> bool:
	if h01(storey, 0, seed_value, 1) < float(lk.get("dark_floors", 0.2)):
		return false
	if h01(storey, 0, seed_value, 2) < 0.06:
		return true
	return h01(storey, room, seed_value, 3) < float(lk.get("lit", 0.32))


## A lit room's light: warm or cool by the look's warm_share, one of its colours.
static func room_color(lk: Dictionary, storey: int, room: int, seed_value: int) -> Color:
	var warm := h01(storey, room, seed_value, 4) < float(lk.get("warm_share", 0.5))
	var list: Array = lk.get("warm" if warm else "cool", ["ffc890"])
	return Color(String(list[int(h01(storey, room, seed_value, 5) * list.size()) % list.size()]))


## Where the vertical light seams fall along a face from `lo` to `hi` (world units, measured from
## the plate's corner `origin`): every seam_every squares, none within a square of a corner.
static func seams(lk: Dictionary, origin: float, lo: float, hi: float) -> Array[float]:
	var out: Array[float] = []
	var every := float(lk.get("seam_every", 0))
	if every <= 0.0 or not has(lk, "seam"):
		return out
	var k := 1
	while origin + k * every < hi - 1.0:
		var x := origin + k * every
		if x > lo + 1.0:
			out.append(x)
		k += 1
	return out


## Setback tiers under the band: [[top y, grow per side]], top down, the band's own plate first
## ([0, 0]). `fh` the storey height.
static func tiers(lk: Dictionary, fh: float) -> Array:
	var out: Array = [[0.0, 0.0]]
	var sb: Array = lk.get("setbacks", [])
	for s in sb:
		out.append([-float(s[0]) * fh, float(s[1])])
	return out
