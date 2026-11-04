class_name SetPieces
extends RefCounted
## Set pieces (data/gen/setpieces.json): authored recipes for famous Night City places. A set
## piece names the scene it plays as, the planner that lays it out (SetPieceGen), the buildings it
## is made of (each a sites.json site with the set piece's own keys over it), the guard posts it
## mans first, the rooms every seed must have, where objectives go and its special rules.
## Pure lookups: SceneGen, BuildingGen, Encounter and World read set pieces through here.

## Objective kind → the role Encounter.secure_cell places (objectives.json kinds).
const ROLE_OF := {"assassinate": "vip", "rescue": "captive", "snatch": "package", "sabotage": "machine"}


static func all() -> Dictionary:
	var out := {}
	var d := RulesDB.gen("setpieces.json")
	for k in d:
		if not String(k).begins_with("_"):
			out[k] = d[k]
	return out


static func ids() -> Array:
	return all().keys()


static func has(id: String) -> bool:
	return id != "" and all().has(id)


## A set piece's recipe ({} if unknown).
static func get_def(id: String) -> Dictionary:
	return all().get(id, {})


## The set piece built for a World location ("" if it has none).
static func for_location(location_id: String) -> String:
	for id in all():
		if (all()[id].get("locations", {}) as Dictionary).has(location_id):
			return String(id)
	return ""


## The scene params a location adds to its set piece (which structure is the target, ...).
static func location_params(id: String, location_id: String) -> Dictionary:
	return (get_def(id).get("locations", {}) as Dictionary).get(location_id, {})


## The scene a set piece plays as (scenes.json id: its theme, doctrine and bystanders).
static func scene_of(id: String) -> String:
	return String(get_def(id).get("base", {}).get("scene", "lone_building"))


## SceneGen overrides for a set piece: its own params under the caller's, its location's params
## (overrides.location) and the target building's base site. The recipe owns the map's size and
## storeys (SIZE_KEYS): a caller's w / h / floors are ignored.
const SIZE_KEYS := ["w", "h", "floors"]

static func overrides(id: String, caller: Dictionary) -> Dictionary:
	var sp := get_def(id)
	var o: Dictionary = (sp.get("params", {}) as Dictionary).duplicate(true)
	o.merge(location_params(id, String(caller.get("location", ""))), true)
	for k in caller:
		if not (k in SIZE_KEYS):
			o[k] = caller[k]
	o["setpiece"] = id
	var target := String(o.get("target", "main"))
	o["target"] = target
	o["site"] = String(sp.get("sites", {}).get(target, {}).get("base", o.get("site", "corp_office")))
	return o


## The site definition a building is built from: sites.json[site], or, for a set piece's part, its
## base site with the part's keys over it (layout key by key, the rest replaced). Objective anchors
## come from the set piece's per-objective table, as the roles secure_cell reads.
static func site_def(site: String, setpiece := "", part := "") -> Dictionary:
	var sites := RulesDB.gen("sites.json")
	if not has(setpiece) or part == "":
		return sites.get(site, {})
	var sp := get_def(setpiece)
	var over: Dictionary = sp.get("sites", {}).get(part, {})
	var base: Dictionary = sites.get(String(over.get("base", site)), sites.get(site, {}))
	var out: Dictionary = base.duplicate(true)
	for k in over:
		if k == "base":
			continue
		if k == "layout" and out.get("layout") is Dictionary:
			var lay: Dictionary = (out.layout as Dictionary).duplicate(true)
			if String(over.layout.get("algorithm", lay.get("algorithm", ""))) != String(lay.get("algorithm", "")):
				lay = {}   # another algorithm: none of the base's tuning applies
			lay.merge(over.layout, true)
			out["layout"] = lay
		else:
			out[k] = over[k]
	if part == String(sp.get("params", {}).get("target", "main")) or sp.get("locations", {}).values().any(func(l): return String(l.get("target", "")) == part):
		var by_kind: Dictionary = over.get("anchors", sp.get("anchors", {}))   # a part's own, else the set piece's
		var anchors := {}
		for kind in by_kind:
			if ROLE_OF.has(kind):
				anchors[ROLE_OF[kind]] = by_kind[kind]
		out["anchors"] = anchors
	return out


## The site definition for a built structure (its set piece part, if it has one).
static func structure_def(st: Dictionary) -> Dictionary:
	return site_def(String(st.get("site", "")), String(st.get("setpiece", "")), String(st.get("part", "")))


## A special rule of the map's set piece (setpieces.json `rules`), or `fallback`.
static func rule(m: TacMap, name: String, fallback: Variant = null) -> Variant:
	if m == null:
		return fallback
	var id := String(m.params.get("setpiece", ""))
	if not has(id):
		return fallback
	return get_def(id).get("rules", {}).get(name, fallback)


## The briefing lines of a set piece's special rules (each rule's `brief`: "TOTENTANZ: NO FIGHTING
## ON THE FLOOR. ..."), in data order; [] for none. The job board and the gig's opening log show them.
static func briefs(id: String) -> Array[String]:
	var out: Array[String] = []
	var rules: Dictionary = get_def(id).get("rules", {})
	for k in rules:
		if rules[k] is Dictionary and String(rules[k].get("brief", "")) != "":
			out.append(String(rules[k].brief))
	return out


## The variant a set piece drew for this map (an estate's owner: SetPieceGen keeps it in the map's
## params as `variant`), {} for none.
static func variant(m: TacMap) -> Dictionary:
	if m == null or not has(String(m.params.get("setpiece", ""))):
		return {}
	return m.params.get("variant", {})


## The place's name for the HUD: the set piece's, with its variant's (The Estates · Kerry Eurodyne's).
static func place_name(m: TacMap) -> String:
	var sp := get_def(String(m.params.get("setpiece", "")))
	var v := variant(m)
	if v.has("name"):
		return "%s · %s" % [sp.get("name", ""), v.name]
	return String(sp.get("name", ""))


## Encounter options with the map's variant over them: a variant with its own Security Code (the
## one estate Danger Gal guards instead of Lazarus) answers calls and holds the posts with it.
static func encounter_opts(m: TacMap, opts: Dictionary) -> Dictionary:
	var v := variant(m)
	if not v.has("security_code"):
		return opts
	var o := opts.duplicate()
	o["security_code"] = v.security_code
	o["guards"] = String(v.security_code.get("faction", ""))
	return o
