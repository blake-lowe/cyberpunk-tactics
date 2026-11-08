class_name World
extends RefCounted
## Night City as data: factions now, locations and security doctrines as they land
## (data/world/*.json). Pure lookups, no Nodes, so rules code and tests use it headless.

const RELATIONS := ["hostile", "neutral", "ally"]   ## most hostile first
const DEFAULT_OPFOR := "security"


static func factions() -> Dictionary:
	return RulesDB.world("factions.json")["factions"]


static func has_faction(id: String) -> bool:
	return factions().has(id)


## A faction's definition with its id filled in. Unknown ids fall back to generic security.
static func faction(id: String) -> Dictionary:
	var fs := factions()
	var f: Dictionary = (fs.get(id, fs[DEFAULT_OPFOR]) as Dictionary).duplicate()
	f["id"] = id if fs.has(id) else DEFAULT_OPFOR
	return f


static func kind(id: String) -> String:
	return String(faction(id).get("kind", "corp"))


static func display_name(id: String) -> String:
	return String(faction(id).get("name", id))


## How two factions stand with each other: "hostile", "neutral" or "ally". Symmetric. The kind
## defaults (kind_relations, either direction, most hostile wins) give a base; a faction's own
## override for the other faction (by id, else by kind) replaces it, so 6th Street can get along
## with the police and Maelstrom can hate other gangs. If both sides override, most hostile wins.
static func relation(a: String, b: String) -> String:
	if a == b:
		return "ally"
	var fa := faction(a)
	var fb := faction(b)
	var ka := String(fa.get("kind", "corp"))
	var kb := String(fb.get("kind", "corp"))
	var overrides: Array = []
	for pair in [[fa, b, kb], [fb, a, ka]]:
		var ov: Dictionary = (pair[0] as Dictionary).get("relations", {})
		if ov.has(pair[1]):
			overrides.append(String(ov[pair[1]]))
		elif ov.has(pair[2]):
			overrides.append(String(ov[pair[2]]))
	if not overrides.is_empty():
		return _most_hostile(overrides)
	var kr: Dictionary = RulesDB.world("factions.json")["kind_relations"]
	var base: Array = []
	for pair in [[ka, kb], [kb, ka]]:
		var row: Dictionary = kr.get(pair[0], {})
		if row.has(pair[1]):
			base.append(String(row[pair[1]]))
	return _most_hostile(base) if not base.is_empty() else "neutral"


static func _most_hostile(rs: Array) -> String:
	var worst := RELATIONS.size() - 1
	for r in rs:
		worst = mini(worst, maxi(0, RELATIONS.find(String(r))))
	return RELATIONS[worst]


## Factions a gig kind (gigs.json template kind) can be aimed at, in data order.
static func targets_for(gig_kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in factions():
		if gig_kind in (factions()[id].get("gigs", []) as Array):
			out.append(String(id))
	return out


## The gig kinds a faction can be the target of.
static func targets_for_any(id: String) -> Array:
	return faction(id).get("gigs", [])


## The name a faction gives an NPC tier ("Militech Trooper"), or the tier's own name ("Mook").
static func rank(id: String, tier: String) -> String:
	var ranks: Dictionary = faction(id).get("roster", {}).get("ranks", {})
	if ranks.has(tier):
		return String(ranks[tier])
	return String(RulesDB.load_json("npcs.json")["tiers"][tier]["name"])


## One of the faction's people at `tier`: a stat block from its roster's pool for the tier (or the
## tier's default pool, npcs.json), named "<rank> <n>". Everything they carry comes from the block.
## `hardened` (a Hardened Security Code, NC2045 p.7) prefers the Hardened blocks (SecurityCode.tier_pool).
static func npc(dice: Dice, id: String, tier: String, n: int, rank_override := "", hardened := false) -> Combatant:
	var pool: Array = SecurityCode.tier_pool(id, tier, hardened)
	var name := "%s %d" % [rank_override if rank_override != "" else rank(id, tier), n]
	var c := Recruit.npc(dice, tier, name, pool)
	c.faction = faction(id).id
	return c


## How the faction turns up when called (Trauma Team, NCPD, MaxTac): {tiers: [...], rank, armor}.
static func responder(id: String) -> Dictionary:
	var r: Dictionary = (faction(id).get("roster", {}).get("responder", {}) as Dictionary).duplicate()
	if not r.has("tiers"):
		var t: Array = []
		for i in int(r.get("count", 3)):
			t.append(String(r.get("tier", "mook")))
		r["tiers"] = t
	return r


## What the view dresses the faction in (see factions.json look).
static func look(id: String) -> Dictionary:
	return faction(id).get("look", {})


# --- Locations (data/world/locations.json) ----------------------------------------------

static func locations() -> Dictionary:
	return RulesDB.world("locations.json").get("locations", {})


## A location with its id and what the game derives from the data: where it's played (site /
## profile / scene from its `type`, locations.types) and the old 1-3 security range (from its
## Security Code, SecurityCode.level) when the entry doesn't name them itself.
static func location(id: String) -> Dictionary:
	var l: Dictionary = (locations().get(id, {}) as Dictionary).duplicate()
	if l.is_empty():
		return l
	l["id"] = id
	if not (l.has("site") or l.has("profile") or l.has("scene")):
		l.merge(location_types().get(String(l.get("type", "")), {}))
	var code := SecurityCode.normalise(l.get("security_code"))
	if not l.has("security") and not code.is_empty():
		var lv := SecurityCode.level(code)
		l["security"] = [lv, lv]
	# A famous place with an authored recipe (data/gen/setpieces.json): play it as that set piece
	# (SceneGen overrides {setpiece, location}; the recipe picks the scene and the target).
	var sp := SetPieces.for_location(id)
	if sp != "":
		l["setpiece"] = sp
	return l


## Towers (docs/world/towers.md): every location with a `tower` record, {location id: record}, in
## data order. A tower gig plays one band of it (TowerGen); see docs/plans/towers.md.
static func towers() -> Dictionary:
	var out := {}
	for id in locations():
		var t: Variant = (locations()[id] as Dictionary).get("tower")
		if t is Dictionary and not (t as Dictionary).is_empty():
			out[String(id)] = t
	return out


## The location id of a tower named by its location id or its short id ("raven"), else "".
static func tower_location(id: String) -> String:
	var all := towers()
	if all.has(id):
		return id
	for lid in all:
		if String(all[lid].get("id", "")) == id:
			return String(lid)
	return ""


## A tower's record with its `location` filled in ({} if `id` names no tower). `id`: a location id
## or the tower's short id.
static func tower(id: String) -> Dictionary:
	var lid := tower_location(id)
	if lid == "":
		return {}
	var t: Dictionary = (towers()[lid] as Dictionary).duplicate(true)
	t["location"] = lid
	return t


## Location type → generator (docs/world/locations.md).
static func location_types() -> Dictionary:
	return RulesDB.world("locations.json").get("types", {})


# --- Districts (data/world/city.json) ----------------------------------------------------

static func districts() -> Dictionary:
	return RulesDB.world("city.json").get("districts", {})


## A district with its id filled in ({} if unknown).
static func district(id: String) -> Dictionary:
	var d: Dictionary = (districts().get(id, {}) as Dictionary).duplicate()
	if not d.is_empty():
		d["id"] = id
	return d


## Districts whose neighbourhood generator is `profile` (data/gen/districts.json), in data order.
static func districts_with_profile(profile: String) -> Array[String]:
	var out: Array[String] = []
	for id in districts():
		if String((districts()[id] as Dictionary).get("profile", "")) == profile:
			out.append(String(id))
	return out


## Locations `faction` owns where a `gig_kind` job can happen, in data order.
static func locations_for(faction: String, gig_kind: String) -> Array[String]:
	var out: Array[String] = []
	for id in locations():
		var l: Dictionary = locations()[id]
		if String(l.get("owner", "")) == faction and gig_kind in (l.get("gigs", []) as Array):
			out.append(String(id))
	return out



# --- Fixers (data/world/fixers.json) ------------------------------------------------------

static func fixers() -> Dictionary:
	return RulesDB.world("fixers.json").get("fixers", {})


## A fixer with its id filled in ({} if unknown).
static func fixer(id: String) -> Dictionary:
	var f: Dictionary = (fixers().get(id, {}) as Dictionary).duplicate()
	if not f.is_empty():
		f["id"] = id
	return f


## Fixers who work district `did` (their own district or one of their `also`), in data order.
static func fixers_in(did: String) -> Array[String]:
	var out: Array[String] = []
	for id in fixers():
		var f: Dictionary = fixers()[id]
		if String(f.get("district", "")) == did or did in (f.get("also", []) as Array):
			out.append(String(id))
	return out


## Districts next to `did` on the city map (city.map.districts.<id>.neighbours).
static func neighbours(did: String) -> Array:
	return ((RulesDB.world("city.json").get("map", {}) as Dictionary).get("districts", {}) as Dictionary).get(did, {}).get("neighbours", [])
