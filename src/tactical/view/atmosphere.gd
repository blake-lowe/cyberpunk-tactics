class_name Atmosphere
extends RefCounted
## The weather over a gig (data/gen/atmospheres.json): a mood (clear, overcast, light rain, heavy
## rain, and the Strange Weather rows: acid and blood rain, ash, dust and radioactive windstorms,
## a thunderstorm, inversion smog, a heat wave, a cold snap, flooding, a blackout) picked from the
## gig's seed at the official Night City Weather odds (NCW p.3, year-round) and leaned by its
## district, kept on the gig as `mood` (Campaign.gig_mood) and handed to the map's params
## (Campaign.scene_opts), so a save reloads the same weather. Every map with sky over it takes it:
## the sky and the fog's colour (greybox scene_look: never the ambient, key or lamp light the play
## area and the units are lit by), the rain, ash, dust and haze over the open ground (WeatherFx),
## and a tower band's far city, street grid and smog (TowerDress). The rules effects (sight, heat,
## an outage) are Weather's (src/tactical/weather.gd). Pure data plus lookups (headless-testable).

## The scene-light keys a mood may set over a tower band (greybox LOOKS): the air outside, never the
## frame's palette (owner: the weather mustn't tint indoors) and never the light on the play area.
const LIGHT_KEYS := ["fog", "fog_d", "fog_h", "fog_hd", "sky", "smog"]   # no palette: owner, the weather mustn't tint indoors
## The keys a mood sets over any other map (ground_air): the fog's colour, the sky, and fog_k.
const GROUND_KEYS := ["fog", "sky", "fog_k"]


static func data() -> Dictionary:
	return RulesDB.gen("atmospheres.json")


## The default mood's id (clear: changes nothing).
static func default_id() -> String:
	return String(data().get("default", "clear"))


## Every mood id, in data order.
static func ids() -> Array:
	return (data().get("moods", {}) as Dictionary).keys()


## Does a map of `scene` have sky over it (atmospheres.json no_sky_scenes: the undercity's tunnels,
## the arcology's atrium)? Those gigs have no weather.
static func has_sky(scene: String) -> bool:
	return not scene in (data().get("no_sky_scenes", []) as Array)


## A mood's display name ("Light rain"): player-facing, never a page.
static func label(id: String) -> String:
	return String((data().get("moods", {}) as Dictionary).get(id, {}).get("name", id))


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
	for k in out.keys():   # only moods we have, never below nothing (a `_why` note is no mood)
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
		if not k in ["night", "day", "_why", "book"]:
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


## The air over a map that isn't a tower band (greybox scene_look): the mood's fog colour and sky
## by day or night, and `fog_k`, the scale on the scene's own fog density (a tower's fog numbers are
## for a drop of hundreds of metres; a street keeps its own, a little thicker in heavy weather).
## The default mood: nothing.
static func ground_air(id: String, day := false) -> Dictionary:
	if not has(id) or id == default_id():
		return {}
	var lk := look(id, day)
	var out := {}
	for k in GROUND_KEYS:
		if lk.has(k):
			out[k] = lk[k]
	return out


## A colour key of a look (fallback when missing or "").
static func col(lk: Dictionary, key: String, fallback: Color) -> Color:
	var s := String(lk.get(key, ""))
	return Color(s) if s != "" else fallback
