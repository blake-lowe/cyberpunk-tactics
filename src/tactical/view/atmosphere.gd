class_name Atmosphere
extends RefCounted
## The weather over a gig (data/gen/atmospheres.json): a mood (clear neon-noir, acid rain, dust
## storm, heavy smog, cold drizzle) picked from the gig's seed and weighted by its district, kept
## on the gig as `mood` (Campaign.tower_mood) and handed to the map's params (Campaign.scene_opts),
## so a save reloads the same weather. It tints the sky, the fog and the smog (greybox
## _scene_look: never the ambient, key or lamp light the play area and the units are lit by), and
## the tower dressing's far city, street grid, smog layers, rain and dust (TowerDress). Tower bands
## use it now; nothing in it is tower-only, so ordinary maps can take it up later. Pure data plus
## lookups (headless-testable).

## The scene-light keys a mood may set (greybox LOOKS): the air and the palette the frame is drawn
## in, never the light on the play area.
const LIGHT_KEYS := ["fog", "fog_d", "fog_h", "fog_hd", "sky", "smog", "palette"]


static func data() -> Dictionary:
	return RulesDB.gen("atmospheres.json")


## The default mood's id (clear: changes nothing).
static func default_id() -> String:
	return String(data().get("default", "clear"))


## Every mood id, in data order.
static func ids() -> Array:
	return (data().get("moods", {}) as Dictionary).keys()


static func has(id: String) -> bool:
	return (data().get("moods", {}) as Dictionary).has(id)


## How likely each mood is over district `did` (city.json): the base weights, plus its region's,
## its profile's, each of its look tags', and its own. Unknown district: the base weights.
static func weights(did: String) -> Dictionary:
	var w: Dictionary = data().get("weights", {})
	var out: Dictionary = (w.get("base", {}) as Dictionary).duplicate()
	var d := World.district(did) if did != "" else {}
	var adds: Array = [w.get("region", {}).get(String(d.get("region", "")), {}),
		w.get("profile", {}).get(String(d.get("profile", "")), {})]
	for tag in d.get("look", []):
		adds.append(w.get("look", {}).get(String(tag), {}))
	adds.append(w.get("district", {}).get(did, {}))
	for a in adds:
		for k in a:
			out[k] = int(out.get(k, 0)) + int(a[k])
	for k in out.keys():   # only moods we have, never below nothing
		if not has(String(k)) or int(out[k]) <= 0:
			out.erase(k)
	return out


## The mood of a gig seeded `seed_value` over district `did`: a weighted draw, the same every time
## for the same seed and district (no global randomness: a hash of the seed).
static func pick(seed_value: int, did: String) -> String:
	var w := weights(did)
	var total := 0
	for k in w:
		total += int(w[k])
	if total <= 0:
		return default_id()
	var r := posmod(hash(Vector3i(seed_value, 41, 7)), total)
	for k in ids():   # data order, so the draw never depends on how a dictionary was built
		if not w.has(k):
			continue
		r -= int(w[k])
		if r < 0:
			return String(k)
	return default_id()


## A map's mood (its params' `mood`, from the gig), else the default.
static func of(m: TacMap) -> String:
	if m == null:
		return default_id()
	var id := String(m.params.get("mood", ""))
	return id if has(id) else default_id()


## A mood's look by day or night: its day / night block over its own top-level keys (wet, rain,
## dust...), with its id. Unknown: the default's.
static func look(id: String, day := false) -> Dictionary:
	var moods: Dictionary = data().get("moods", {})
	var md: Dictionary = moods.get(id, moods.get(default_id(), {}))
	var out := {}
	for k in md:
		if not k in ["night", "day", "_why"]:
			out[k] = md[k]
	out.merge(md.get("day" if day else "night", {}), true)
	out["id"] = id if moods.has(id) else default_id()
	return out


## The part of a mood's look that goes over the scene's light (LIGHT_KEYS only).
static func light(id: String, day := false) -> Dictionary:
	var lk := look(id, day)
	var out := {}
	for k in LIGHT_KEYS:
		if lk.has(k):
			out[k] = lk[k]
	return out


## A colour key of a look (fallback when missing or "").
static func col(lk: Dictionary, key: String, fallback: Color) -> Color:
	var s := String(lk.get(key, ""))
	return Color(s) if s != "" else fallback
