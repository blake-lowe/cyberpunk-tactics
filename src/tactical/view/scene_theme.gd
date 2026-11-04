class_name SceneTheme
extends RefCounted
## A scene's visual identity beyond its light (greybox LOOKS): material recolours, light colours,
## the post-process palette, what surrounds the map, and ambient effects. Scenes without an entry
## keep the night-city defaults. Pure data plus lookups, so LightPlan stays testable headless.
##
## mats: LIB name → {color, color2, pattern, scale, rough, metal, glow, emit, ...} (WorldBuilder.mat)
## lamp / neon / zone_light / fire: colours LightPlan uses instead of its defaults
## lamp_style: "pole" (street lamp) or "bulkhead" (caged lamp on the nearest wall)
## surround: "skyline" (lit towers), "desert", "bedrock" (solid rock at wall height), "atrium" (white
## arcology walls and columns), "ruins" (dark, burning skyline)
## ambient: effects layered over the scene: "embers", "steam", "drips", "motes"
## blaze: share of wrecks/cars (and fewer rubble heaps) set on fire; lamp_keep: share of lamps lit

## The data: data/gen/themes.json (themes by scene id, palettes by name).
static func themes() -> Dictionary:
	return RulesDB.gen("themes.json")["themes"]


## Palettes for the post shader as name → [neutral count, colours]. Neutrals (ramps of the scene's
## materials) come first; the saturated ramps after them are only used by saturated pixels.
static func palettes() -> Dictionary:
	var out := {}
	var p: Dictionary = RulesDB.gen("themes.json")["palettes"]
	for k in p:
		out[k] = [int(p[k].neutrals), p[k].colors]
	return out


## The scene's theme; a scene without one wears its gig's district look (DistrictLook: the same
## keys plus light, walls, signs and grime), else the night-city defaults ({}).
static func of(m: TacMap) -> Dictionary:
	if m == null:
		return {}
	var t: Dictionary = themes().get(String(m.params.get("scene", "")), {})
	return t if not t.is_empty() else DistrictLook.of_params(m.params)


## Sign density (0 none, 1 the default, 2 a market street's), from the district look.
static func signs(m: TacMap) -> float:
	return clampf(float(of(m).get("signs", 1.0)), 0.0, 2.0)


## Street litter and overhead cables (0 swept clean, 1 the default, 2 a slum's).
static func grime(m: TacMap) -> float:
	return clampf(float(of(m).get("grime", 1.0)), 0.0, 2.0)


## A building's facade colour from the look's pool for wall material `name` (walls.<name>:
## {colors, pattern, scale}), picked by `pick`; {} when the look has no pool for it.
static func wall_look(m: TacMap, name: String, pick: int) -> Dictionary:
	var w: Dictionary = of(m).get("walls", {}).get(name, {})
	var cols: Array = w.get("colors", [])
	if cols.is_empty():
		return {}
	var col := Color(String(cols[posmod(pick, cols.size())]))
	var out := {"color": col, "color2": col.darkened(0.42)}
	if w.has("pattern"):
		out["pattern"] = int(w.pattern)
	if w.has("scale"):
		out["scale"] = float(w.scale)
	return out


## A LIB entry with this scene's recolour applied: [color, color2, pattern, scale, rough, metal, extra].
static func lib_entry(m: TacMap, name: String, base: Array) -> Array:
	var t: Dictionary = of(m).get("mats", {}).get(name, {})
	if t.is_empty():
		return base
	var d := base.duplicate()
	while d.size() < 7:
		d.append({})
	d[6] = (d[6] as Dictionary).duplicate()
	for k in t:
		match k:
			"color": d[0] = Color(t[k])
			"color2": d[1] = Color(t[k])
			"pattern": d[2] = int(t[k])
			"scale": d[3] = float(t[k])
			"rough": d[4] = float(t[k])
			"metal": d[5] = float(t[k])
			"emit": d[6][k] = Color(t[k])
			_: d[6][k] = t[k]
	return d


## Colours for a LightPlan role ("lamp", "neon", "zone_light"), or `fallback`.
static func colors(m: TacMap, role: String, fallback: Array) -> Array:
	var a: Array = of(m).get(role, [])
	if a.is_empty():
		return fallback
	return a.map(func(h): return Color(h))
