class_name Weather
extends RefCounted
## The weather's rules effects in a gig (data/gen/atmospheres.json; its look is Atmosphere's and
## WeatherFx's). The official Night City Weather supplement (NCW p.4-5) lets the GM, at their
## discretion, take a penalty off Perception checks to see and off ranged attacks at a target at
## a distance in heavy rain, a thunderstorm, blood rain, an ash or dust storm and inversion smog,
## raises armor penalties in a heat wave, and has storms take the power down. All of it is in the
## data (a mood's `sight`, `heat`, `outage`; `effects` false turns it off), so the owner can drop it.
##
## - sight_penalty: Perception to see (a guard spotting the crew, Encounter._spots) when either
##   end stands out under the open sky (open_sky), as the book has it only for things done outside.
## - ranged_penalty: the same, for a ranged attack past the first range band. HOUSE-RULE reading of
##   "a target at a distance": farther than 6 m/yds, the closest band of the range table (CPR core
##   p.173). Melee and anything closer never take it.
## - optics_sight: how much of `sight` still reaches someone seeing with Low Light/Infrared/UV
##   (Combatant.sees_through_obscurement). HOUSE-RULE (owner ruling 2026-11-11, "do what makes
##   physical sense"): the book's text (CPR core p.360) zeroes darkness and "smoke, fog, etc." and
##   says nothing of weather; NCW p.4-5 gives the weather penalties and no optics exception. We split
##   them by physics. Thermal infrared (8-14 um) passes through fine particulates far smaller than its
##   wavelength - smoke, fog, haze, inversion smog, ash and blown dust - so those moods have 0. Rain
##   is different: drops are millimetres across, hundreds of times the wavelength, so they scatter
##   infrared just as they scatter visible light, and liquid water is close to opaque to it besides
##   (it absorbs strongly across the thermal band); the falling water also cools every surface toward
##   one temperature, washing out the contrast a thermal image runs on. So heavy rain, a thunderstorm
##   and blood rain keep their full penalty for chromed eyes too, not a reduced one: nothing in the
##   physics makes IR see better through a downpour than the naked eye does. Unset means the full
##   penalty (an unknown mood is assumed not to be seen through).
## - heat: added to a worn armor's penalty to REF, DEX and MOVE (Combatant.heat; NCW p.5: +2 in a
##   heat wave). No armor penalty, nothing added.
## - outage: a Utility Codes outage (Encounter.outages) the mood brings (blackout: power, NCW p.4).
## - turn: the Weather Turns twist (SPM p.76 row 97-98): a Strange Weather row blows in mid-gig.
##
## Left out on purpose (each takes longer than a gig lasts or is wholly the GM's call): acid rain's
## armor ablation and the ash, smog and blood rain poisons (a full minute, 20 rounds, unprotected),
## the dust storm's Foreign Object (five minutes), lightning strikes (one roll per ten minutes),
## radioactive bursts, exposure, black ice and flooded basements.

const RANGE_BAND_M := 6.0   ## CPR core p.173: the closest band of the range table, 0-6 m/yds
const OPEN := [TacMap.T.OUTSIDE, TacMap.T.ROOF, TacMap.T.BRIDGE, TacMap.T.WATER]


## Are the mechanics on (atmospheres.json effects)?
static func on() -> bool:
	return bool(Atmosphere.data().get("effects", true))


static func _mood(id: String) -> Dictionary:
	return (Atmosphere.data().get("moods", {}) as Dictionary).get(id, {})


## Mood `id`'s player-facing name ("Dust storm"), "weather" if unknown.
static func name_of(id: String) -> String:
	return String(_mood(id).get("name", "weather"))


## The penalty mood `id` puts on seeing and on shots at a distance (NCW p.4-5), 0 if none or off.
static func sight(id: String) -> int:
	return int(_mood(id).get("sight", 0)) if on() else 0


## The part of mood `id`'s sight penalty Low Light/Infrared/UV still takes (`optics_sight`, at most
## `sight`; unset: all of it), 0 if none or off.
static func optics_sight(id: String) -> int:
	var s := sight(id)
	return clampi(int(_mood(id).get("optics_sight", s)), 0, s) if s > 0 else 0


## Does Low Light/Infrared/UV see through mood `id` entirely (a sight penalty that optics zero)?
static func optics_clear(id: String) -> bool:
	return sight(id) > 0 and optics_sight(id) == 0


## How much worse mood `id` makes an existing armor penalty (NCW p.5: heat wave +2), 0 if none or off.
static func heat(id: String) -> int:
	return int(_mood(id).get("heat", 0)) if on() else 0


## The utility mood `id` takes out (SecurityCode.UTILITIES: "power" for a blackout), "" if none or off.
static func outage(id: String) -> String:
	var u := String(_mood(id).get("outage", "")) if on() else ""
	return u if u in SecurityCode.UTILITIES else ""


## The highest floor at square (x, y) that is open to the sky (street, roof, bridge or water with
## nothing built over it), -1 if none: where the rain lands.
static func surface(m: TacMap, x: int, y: int) -> int:
	if not m.inb(x, y):
		return -1
	for f in range(m.floors - 1, -1, -1):
		var t := m.t(f, x, y)
		if t == TacMap.T.VOID:
			continue
		return f if t in OPEN and m.label(f, x, y) < 0 else -1
	return -1


## Is square `v` out under the open sky (the weather reaches whoever stands there)?
static func open_sky(m: TacMap, v: Vector3i) -> bool:
	return surface(m, v.x, v.y) == v.z


## The penalty to see `to` from `from` in mood `id`: the mood's sight penalty when either of them is
## out under the open sky, else 0. `optics`: the viewer sees with Low Light/Infrared/UV (optics_sight).
static func sight_penalty(m: TacMap, id: String, from: Vector3i, to: Vector3i, optics := false) -> int:
	var p := optics_sight(id) if optics else sight(id)
	if p <= 0:
		return 0
	return p if open_sky(m, from) or open_sky(m, to) else 0


## The penalty to a ranged attack from `from` at `to`, `dist_m` away, in mood `id`: the sight
## penalty past the first range band (RANGE_BAND_M), else 0.
static func ranged_penalty(m: TacMap, id: String, from: Vector3i, to: Vector3i, dist_m: float, optics := false) -> int:
	return sight_penalty(m, id, from, to, optics) if dist_m > RANGE_BAND_M else 0


## The round tab's line for mood `id` ("" when it changes no rule): "DUST STORM · SIGHT -2".
static func hud_line(id: String) -> String:
	var name := String(_mood(id).get("hud", ""))
	if name == "" or not on():
		return ""
	var parts: Array[String] = [name]
	if sight(id) > 0:
		parts.append("SIGHT -%d" % sight(id))
	if heat(id) > 0:
		parts.append("ARMOR PENALTY +%d" % heat(id))
	return " · ".join(parts) if parts.size() > 1 else ""


## The Strange Weather rows that can blow in mid-gig (atmospheres.json twist_pool), less `current`.
static func turn_pool(current: String) -> Array:
	return (Atmosphere.data().get("twist_pool", []) as Array).filter(func(k): return Atmosphere.has(String(k)) and String(k) != current)


## The Weather Turns twist: one of turn_pool, evenly, on the encounter's dice; the encounter takes
## it (Encounter.set_weather). Returns the new mood ("" if none could come).
static func turn(e: Encounter) -> String:
	var pool := turn_pool(e.weather)
	if pool.is_empty():
		return ""
	var id := String(pool[e.dice.d(pool.size()) - 1])
	e.set_weather(id)
	return id
