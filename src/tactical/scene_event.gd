class_name SceneEvent
extends RefCounted
## Scene events: the street around a gig (Cyberpunk RED: Single Player Mode, Random Encounters,
## SPM p.77-84; owner verdict 2026-11-09 "build now"). Data: data/gen/scene_events.json, the book's
## twelve tables (Corporate/Executive, Moderate, Combat Zone, Outskirts x day, night, after
## midnight) by the book's numbering, our own labels and notes, an `fx` per row.
##
## Keying (HOUSE-RULE, scene_events.json bands/times): the band is the lower of the location's own
## Security Code and its district's (band_of), the time the campaign clock's (time_of), a tower
## gig's sky winning. A scene event is the street around the gig, not a turn of the job (Twist).
##
## Rolling: once, when a gig starts (Campaign._start_gig), from the gig's seed (roll): about half
## the gigs get one (`chance`); the row is kept on the gig (gig.scene_event = {table, band, time,
## row, roll, id, label, note}), so a reload plays the same street. null: none.
##
## In the encounter: dress() puts its set dressing on the map before anything reads it (cover
## pieces, and lights LightPlan picks up from m.params.event_lights); pre() takes an outage in with
## the Utility Codes; apply() puts its people on the map with the existing systems (bystander
## crowds, witness sides, at-war sides, the site's patrols, Trauma Team's call, MaxTac) and logs
## one quiet line; poll() runs MaxTac's countdown each round. Show, don't tell (owner verdict
## 2026-11-09): no HUD line and no deploy card; the people on the street tell it.
##
## FX: text, crowd, watch, gangs, patrol, trauma, psycho, outage, alarm, dress, sound, sky (see
## scene_events.json `fx._why`). `mood` (the weather seam) is read by nothing yet: the dust storm
## row is unmodelled until the weather pass.

const FX := ["text", "crowd", "watch", "gangs", "patrol", "trauma", "psycho", "outage", "alarm", "dress", "sound", "sky"]
const BANDS := ["corporate", "moderate", "combat_zone", "outskirts"]
const TIMES := ["day", "night", "after_midnight"]
const NONE := "none"
const SALT := 4637            ## the roll's dice: Dice.new(seed * 31 + SALT), apart from the gig's own
const MIN_FROM_DEPLOY := 10.0 ## people and dressing keep this far from the deploy zone
const FAR_FROM_DEPLOY := 16.0 ## anyone who fights (gangs, the psycho) starts at least this far
const TT_ROUND := 2           ## HOUSE-RULE: Trauma Team lands for a street client in round 2 (the crew sees them down first)


static func db() -> Dictionary:
	return RulesDB.gen("scene_events.json")


static func tables() -> Dictionary:
	return db().tables


static func table_key(band: String, time: String) -> String:
	return "%s.%s" % [band, time]


static func rows(key: String) -> Array:
	return (tables().get(key, {}) as Dictionary).get("rows", [])


## The row of table `key` whose id is `id_or_roll`, or whose die range holds that number ({} none).
static func row(key: String, id_or_roll: String) -> Dictionary:
	for r in rows(key):
		if String(r.id) == id_or_roll:
			return r
	if id_or_roll.is_valid_int():
		var n := int(id_or_roll)
		for r in rows(key):
			if n >= int(r.roll[0]) and n <= int(r.roll[1]):
				return r
	return {}


## The table holding row `id` ("" none): ids are unique across the twelve tables.
static func table_of(id: String) -> String:
	for k in tables():
		for r in rows(String(k)):
			if String(r.id) == id:
				return String(k)
	return ""


## Does the game play row `r`? No `unmodelled`, and every fx key one SceneEvent implements.
static func enabled(r: Dictionary) -> bool:
	if r.is_empty() or r.has("unmodelled"):
		return false
	var fx: Dictionary = r.get("fx", {})
	return not fx.is_empty() and fx.keys().all(func(k): return String(k) in FX)


static func enabled_rows(key: String) -> Array:
	return rows(key).filter(func(r): return enabled(r))


# --- Keying ---------------------------------------------------------------------------------

## The street's band for a place whose own Security Code number is `code_n` in a district whose
## code is `district_n` (-1: none), drawn as `profile`, on `scene` in district `did`: "" for none
## (the undercity's tunnels have no street). HOUSE-RULE (scene_events.json bands).
static func band_of(code_n: int, district_n: int, profile: String, scene: String, did: String) -> String:
	var b: Dictionary = db().bands
	if scene in (b.none_scenes as Array):
		return ""
	if scene in (b.outskirts_scenes as Array) or did in (b.outskirts_districts as Array):
		return "outskirts"
	var n := code_n
	if district_n >= 0 and (n < 0 or district_n < n):
		n = district_n
	if n < 0:
		n = int(SecurityCode.STREET_FALLBACK.n)
	var band := "moderate"
	for k in ["combat_zone", "moderate", "corporate"]:
		var lh: Array = b[k]
		if n >= int(lh[0]) and n <= int(lh[1]):
			band = k
	if profile in (b.cz_profiles as Array) and band == "corporate":
		band = "moderate"
	return band


## The band for a gig dict (its security_code, its district's code and profile, its scene).
static func band_for(gig: Dictionary) -> String:
	var did := String(gig.get("district", ""))
	var d := World.district(did) if did != "" else {}
	var code := SecurityCode.normalise(gig.get("security_code"))
	var dcode := SecurityCode.normalise(gig.get("district_code", d.get("security_code")))
	return band_of(int(code.get("n", -1)) if not code.is_empty() else -1, int(dcode.get("n", -1)) if not dcode.is_empty() else -1,
		String(d.get("profile", gig.get("profile", ""))), String(gig.get("scene", "")), did)


## The book's time of day for the campaign clock (`minutes` past midnight) and a tower gig's sky
## ("day" / "night" / ""). HOUSE-RULE (scene_events.json times).
static func time_of(minutes: int, sky := "") -> String:
	var t: Dictionary = db().times
	var by_clock := "night"
	for k in TIMES:
		var lh: Array = t[k]
		if minutes >= int(lh[0]) and minutes <= int(lh[1]):
			by_clock = k
	if sky == "day":
		return "day"
	if sky == "night":
		return "after_midnight" if by_clock == "after_midnight" else "night"
	return by_clock


# --- The roll (Campaign._start_gig) ----------------------------------------------------------

## The chance a gig has a scene event (HOUSE-RULE: about half).
static func chance() -> float:
	return int(db().chance.in_10) / 10.0


## The scene event for `gig` starting at `minutes` past midnight: null, or {table, band, time, row,
## roll, id, label, note}. From the gig's seed alone (with the clock), so the same gig at the same
## hour rolls the same. `force` (the dev builder, CustomGig, greybox --street): "none", "" / "auto"
## (the roll), or a row id, or "<band>.<time>:<id or roll>".
static func roll(gig: Dictionary, minutes: int, force := "") -> Variant:
	if force == NONE:
		return null
	var band := band_for(gig)
	var time := time_of(minutes, String(gig.get("sky", "")))
	var dice := Dice.new(int(gig.get("seed", 1)) * 31 + SALT)
	if force != "" and force != "auto":
		var key := force.get_slice(":", 0) if force.contains(":") else table_of(force)
		var r := row(key, force.get_slice(":", 1) if force.contains(":") else force)
		if not enabled(r):
			return null
		return make(key, r, int(r.roll[0]))
	if band == "" or dice.d(10) > int(db().chance.in_10):
		return null
	var key := table_key(band, time)
	var t: Dictionary = tables().get(key, {})
	var ok := enabled_rows(key)
	if ok.is_empty():
		return null
	var die := int(t.get("die", 100))
	for i in 100:   # the book's die until a row that plays comes up (as Twist.roll_row does)
		var n := dice.d(die)
		var r := row(key, str(n))
		if enabled(r):
			return make(key, r, n)
	return make(key, ok[0], int(ok[0].roll[0]))


static func make(key: String, r: Dictionary, n: int) -> Dictionary:
	return {"table": key, "band": key.get_slice(".", 0), "time": key.get_slice(".", 1), "row": int(r.roll[0]), "roll": n,
		"id": String(r.id), "label": String(r.label), "note": String(r.get("note", ""))}


## Is `s` a scene event in the saved shape (or null)?
static func valid(s: Variant) -> bool:
	if s == null:
		return true
	if not s is Dictionary:
		return false
	var r := row(String(s.get("table", "")), String(s.get("id", "")))
	return enabled(r) and int(s.get("row", -1)) == int(r.roll[0])


static func fx_of(spec: Variant) -> Dictionary:
	if not spec is Dictionary or (spec as Dictionary).is_empty():
		return {}
	var r := row(String(spec.get("table", "")), String(spec.get("id", "")))
	return (r.get("fx", {}) as Dictionary) if enabled(r) else {}


# --- On the map (Encounter.setup) -----------------------------------------------------------

## The deploy zone's middle (the street-level deploy entrance).
static func _deploy(m: TacMap) -> Vector2i:
	for en in m.entrances:
		if String(en.kind) == "deploy":
			return en.pos
	return Vector2i(-100, -100)


static func _target_rect(m: TacMap) -> Rect2i:
	for st in m.structures:
		if st.target and st.has("rect"):
			return st.rect
	return Rect2i(-1000, -1000, 0, 0)


## Squares away from rect `r` (0 inside).
static func _off_rect(r: Rect2i, v: Vector2i) -> float:
	var dx := maxi(0, maxi(r.position.x - v.x, v.x - (r.end.x - 1)))
	var dy := maxi(0, maxi(r.position.y - v.y, v.y - (r.end.y - 1)))
	return Vector2(dx, dy).length()


## Open street squares (outdoors at street level, on no building's ground), `far` from the deploy
## zone, `off` squares clear of the target building, optionally on `ground` (TacMap.G) only.
static func street_cells(m: TacMap, far: float, off: float, ground := -1) -> Array:
	var dep := _deploy(m)
	var tr := _target_rect(m)
	var out: Array = []
	var sl := m.street
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if m.t(sl, x, y) != TacMap.T.OUTSIDE or m.has_cover_at(sl, Vector2i(x, y)):
				continue
			var l := m.label(sl, x, y)
			if l >= 0 and not bool(m.rooms[l].get("outdoor", false)):
				continue
			if ground >= 0 and m.ground[y * m.w + x] != ground:
				continue
			var v := Vector2i(x, y)
			if Vector2(v - dep).length() < far or _off_rect(tr, v) < off:
				continue
			out.append(v)
	return out


## Set dressing (Furnish pieces as cover; fires and sparks as lights LightPlan reads from
## m.params.event_lights). Before anything reads the map (Encounter.setup's first step); once per
## map. Its own dice (the map's seed and the row), so dressing never shifts the gig's rolls.
## Where it went is kept in m.params.event_spots (kind → [Vector2i]) for apply() to gather people at.
static func dress(m: TacMap, spec: Variant) -> void:
	var fx := fx_of(spec)
	if fx.is_empty() or m.params.get("event_dressed", false):
		return
	m.params["event_dressed"] = true
	var d := Dice.new(m.seed_value * 13 + hash(String(spec.id)) % 100003)
	var spots: Dictionary = {}
	var lights: Array = []
	for kind in fx.get("dress", []):
		var at := _dress_one(m, d, String(kind), lights)
		if at.x >= 0:
			spots.get_or_add(String(kind), []).append(at)
	m.params["event_spots"] = spots
	m.params["event_lights"] = lights


## Wall-side pieces stand on a pavement square beside a building wall (vendits, stalls).
const WALL_PIECES := {"vendit": "vending", "stall": "stall", "cart": "stall", "dumpster": "dumpster"}


static func _dress_one(m: TacMap, d: Dice, kind: String, lights: Array) -> Vector2i:
	var sl := m.street
	var any := street_cells(m, MIN_FROM_DEPLOY, 3.0)
	if any.is_empty():
		return Vector2i(-1, -1)
	var road := street_cells(m, MIN_FROM_DEPLOY, 3.0, TacMap.G.ASPHALT)
	var walls: Array = any.filter(func(v): return MapGen.DIRS.any(func(o): return m.t(sl, v.x + o.x, v.y + o.y) == TacMap.T.WALL))
	match kind:
		"car", "wreck", "wreck_burning":
			var pool := road if not road.is_empty() else any
			for i in 60:
				var v: Vector2i = pool[d.d(pool.size()) - 1]
				var fp := Vector2i(2, 2) if kind != "car" else (Vector2i(2, 1) if d.d(2) == 1 else Vector2i(1, 2))
				if Furnish.try_prop(m, sl, Rect2i(v, fp), "car" if kind == "car" else "wreck", -1):
					if kind == "wreck_burning":
						lights.append({"kind": "blaze", "cell": Vector3i(v.x, v.y, sl), "out": Vector2i.ZERO, "energy": 2.8, "range": 9.0})
					return v
		"blaze":   # a fire against a building front: burning rubble
			var pool := walls if not walls.is_empty() else any
			for i in 60:
				var v: Vector2i = pool[d.d(pool.size()) - 1]
				if Furnish.try_prop(m, sl, Rect2i(v, Vector2i.ONE), "rubble", -1):
					lights.append({"kind": "blaze", "cell": Vector3i(v.x, v.y, sl), "out": Vector2i.ZERO, "energy": 2.8, "range": 9.0})
					return v
		"barrel_fire":   # a fire in a barrel on the pavement (walk-through: the view draws the pit)
			var v: Vector2i = any[d.d(any.size()) - 1]
			lights.append({"kind": "fire", "cell": Vector3i(v.x, v.y, sl), "out": Vector2i.ZERO, "energy": 2.2, "range": 7.0})
			return v
		"drone_wreck", "sparks":   # a sparking drone or a tech shop's sparks (view: sparks and a flicker)
			var pool := walls if kind == "sparks" and not walls.is_empty() else any
			var v: Vector2i = pool[d.d(pool.size()) - 1]
			lights.append({"kind": "sparks", "cell": Vector3i(v.x, v.y, sl), "out": Vector2i.ZERO, "color": "8fd8ff", "energy": 0.9, "range": 3.5, "drone": kind == "drone_wreck"})
			return v
		"barricade":   # three pieces across a road, a square apart: a checkpoint you can still walk through
			var pool := road if not road.is_empty() else any
			for i in 60:
				var v: Vector2i = pool[d.d(pool.size()) - 1]
				var step := Vector2i(2, 0) if d.d(2) == 1 else Vector2i(0, 2)
				var ok := true
				for k in 3:
					var c := v + step * k
					if not (c in pool):
						ok = false
				if not ok:
					continue
				var placed := 0
				for k in 3:
					if Furnish.try_prop(m, sl, Rect2i(v + step * k, Vector2i.ONE), "barrier" if k != 1 else "sandbags", -1):
						placed += 1
				if placed > 0:
					return v + step
		_:
			var piece := String(WALL_PIECES.get(kind, ""))
			if piece == "":
				return Vector2i(-1, -1)
			var pool := walls if not walls.is_empty() else any
			for i in 60:
				var v: Vector2i = pool[d.d(pool.size()) - 1]
				if Furnish.try_prop(m, sl, Rect2i(v, Vector2i.ONE), piece, -1):
					return v
	return Vector2i(-1, -1)


## Before the Utility Codes are applied (Encounter.setup): an outage row's utility goes out.
static func pre(e: Encounter, spec: Variant) -> void:
	var fx := fx_of(spec)
	var u := String(fx.get("outage", ""))
	if u in SecurityCode.UTILITIES and not (u in e.outages):
		e.outages.append(u)


## Put the row's people on the map (Encounter.setup, after the bystanders) and log it. Records on
## e.scene_event: {.. the gig's spec, applied, skipped, units, sound, sky}.
static func apply(e: Encounter, spec: Variant) -> void:
	var fx := fx_of(spec)
	if fx.is_empty():
		return
	e.scene_event = (spec as Dictionary).duplicate(true)
	var out := {"applied": [], "skipped": [], "units": [], "crowd": Vector2i(-1, -1)}
	for k in ["crowd", "gangs", "watch", "patrol", "trauma", "psycho"]:   # crowds first: watchers can stand by them
		if not fx.has(k):
			continue
		match k:
			"crowd": _crowd(e, fx.crowd, out)
			"watch": _watch(e, fx.watch, out)
			"gangs": _gangs(e, fx.gangs, out)
			"patrol": _patrol(e, fx.patrol, out)
			"trauma": _trauma(e, out)
			"psycho": _psycho(e, fx.psycho, out)
	if fx.has("outage"):
		(out.applied if String(fx.outage) in e.outages else out.skipped).append("outage")
	if fx.has("alarm"):
		e.alarm = maxi(e.alarm, int(fx.alarm))
		out.applied.append("alarm")
	if fx.has("dress"):
		(out.applied if not (e.m.params.get("event_spots", {}) as Dictionary).is_empty() or not (e.m.params.get("event_lights", []) as Array).is_empty() else out.skipped).append("dress")
	for k in ["text", "sound", "sky"]:
		if fx.has(k):
			out.applied.append(k)
	var note := String(e.scene_event.get("note", ""))
	e.scene_event["applied"] = out.applied
	e.scene_event["skipped"] = out.skipped
	e.scene_event["units"] = out.units
	e.scene_event["sound"] = String(fx.get("sound", ""))
	e.scene_event["sky"] = String(fx.get("sky", ""))
	e.say("On the street: %s." % note)   # one quiet line in the log: the street itself tells the rest


## Once a round (Encounter.next_turn): MaxTac's countdown to a cyberpsycho; a street client's
## Trauma Team call cleared once it's over, so a cardholder of the gig's can still call one.
static func poll(e: Encounter) -> void:
	if e.scene_event.is_empty():
		return
	if bool(e.tt.get("scene", false)) and String(e.tt.get("state", "")) in ["gone", "cancelled"]:
		e.tt = {}
	var due := int(e.scene_event.get("maxtac_round", -1))
	if due < 0 or e.init.round_num < due:
		return
	e.scene_event["maxtac_round"] = -1
	var psy := int(e.scene_event.get("psycho", -1))
	if psy < 0 or e.units[psy].c.dead or not e.units[psy].c.can_act():
		e.say("MaxTac's AV peels away: the psycho is down.")
		return
	_maxtac_for(e, e.units[psy])


## A clear spot of `cells` at least `apart` from every other placed spot: up to `n` of them.
static func _spread(e: Encounter, cells: Array, n: int, apart: float) -> Array:
	var occ := e.occupied()
	var out: Array = []
	for k in n * 25:
		if out.size() >= n or cells.is_empty():
			break
		var v: Vector2i = cells[e.dice.d(cells.size()) - 1]
		var c3 := Vector3i(v.x, v.y, e.m.street)
		if occ.has(c3) or out.any(func(q): return Vector2(q.x - v.x, q.y - v.y).length() < apart):
			continue
		out.append(c3)
	return out


## Up to `n` free walkable squares on the street floor within `r` of `at`, nearest first.
static func _around(e: Encounter, at: Vector3i, n: int, r: int = 4) -> Array:
	var occ := e.occupied()
	var reach: Dictionary = e._keys(func(): return e.nav.reachable(at, r, {}))   # through people: a crowd mustn't wall its own middle in
	var cells: Array = reach.keys().filter(func(v): return v.z == at.z and not occ.has(v) and not StreetLife.blocked_spot(e, v))
	cells.sort_custom(func(a, b): return int(reach[a]) < int(reach[b]) or (int(reach[a]) == int(reach[b]) and Vector3(a - at).length() < Vector3(b - at).length()))
	return cells.slice(0, n)


static func _n(e: Encounter, v: Variant) -> int:
	if v is Array:
		var a: Array = v
		return int(a[0]) + e.dice.d(int(a[-1]) - int(a[0]) + 1) - 1
	return int(v)


## Where a crowd gathers: by the set dressing it is about (a stall, a cart, a fire), at a street
## door of a building other than the target (a club queue, a protest), else out on the street.
static func _gather(e: Encounter, at: String) -> Vector3i:
	var m := e.m
	var spots: Dictionary = m.params.get("event_spots", {})
	if at == "vendor" or not spots.is_empty():
		for k in ["stall", "cart", "barrel_fire", "vendit", "car", "wreck", "wreck_burning", "drone_wreck"]:
			if spots.has(k):
				var v: Vector2i = spots[k][0]
				return Vector3i(v.x, v.y, m.street)
	if at in ["door", "building"]:
		var doors := _street_doors(e)
		if not doors.is_empty():
			return doors[e.dice.d(doors.size()) - 1]
	var cells := street_cells(m, MIN_FROM_DEPLOY + 2.0, 4.0, TacMap.G.SIDEWALK)
	if cells.is_empty():
		cells = street_cells(m, MIN_FROM_DEPLOY, 3.0)
	if cells.is_empty():
		return Vector3i(-1, -1, -1)
	var v: Vector2i = cells[e.dice.d(cells.size()) - 1]
	return Vector3i(v.x, v.y, m.street)


## Street doors (the outside square in front of them) of buildings other than the target, away
## from the deploy zone.
static func _street_doors(e: Encounter) -> Array:
	var m := e.m
	var dep := _deploy(m)
	var out: Array = []
	for en in m.entrances:
		if String(en.kind) != "door" or int(en.get("floor", m.street)) != m.street:
			continue
		var sid := int(en.get("structure", -1))
		if sid >= 0 and sid < m.structures.size() and bool(m.structures[sid].get("target", false)):
			continue
		var face := LightPlan._outward(m, m.street, en.pos)
		if face == Vector2i.ZERO:
			continue
		var v: Vector2i = en.pos + face
		if Vector2(v - dep).length() < MIN_FROM_DEPLOY or not m.walkable(m.street, v):
			continue
		out.append(Vector3i(v.x, v.y, m.street))
	return out


## A crowd of bystanders (Encounter civilians: they panic at gunfire, block and can be hit), posed
## for the view (`pose`: protest, queue, audience, gawk, party, market, talk, argue, vendor, work,
## walk, sit, loiter, play, warm, phone).
static func _crowd(e: Encounter, spec: Dictionary, out: Dictionary) -> void:
	var at := _gather(e, String(spec.get("at", "street")))
	if at.x < 0:
		out.skipped.append("crowd")
		return
	var n := _n(e, spec.get("n", [3, 5]))
	var cells := _around(e, at, n, 5)
	if cells.is_empty():
		out.skipped.append("crowd")
		return
	var pose := String(spec.get("pose", "gawk"))
	var ids := []
	var pool := Recruit.civilian_blocks(e.district)
	for i in cells.size():
		e._add_civilian(Recruit.civilian(e.dice, pool[e.dice.d(pool.size()) - 1]), cells[i], StreetLife.armed_locals(e))
		var u: Dictionary = e.units[-1]
		u["life"] = "vendor" if pose == "vendor" and i == 0 else ("vendor_customer" if pose == "vendor" else pose)
		u["street_event"] = true
		u.facing = Vector2(at.x - u.pos.x, at.y - u.pos.y).normalized() if u.pos != at else Vector2(0, 1)
		u["look_at"] = at
		ids.append(u.id)
	out.crowd = Vector2i(at.x, at.y)
	out.applied.append("crowd")
	out.units.append_array(ids)


## Who a `who` key names (scene_events.json who): a faction id.
static func who(e: Encounter, key: String) -> String:
	var w: Dictionary = db().who
	match key:
		"street":
			var f := String(e.street_code.get("faction", ""))
			return f if World.has_faction(f) else String(w.street_fallback)
		"gang":
			var gs := _gangs_here(e)
			return String(gs[e.dice.d(gs.size()) - 1]) if not gs.is_empty() else String(w.gang_fallback)
	return String(w.get(key, w.gang_fallback))


## The district's gangs that aren't the gig's own people.
static func _gangs_here(e: Encounter) -> Array:
	return (World.district(e.district).get("gangs", []) as Array).filter(func(g): return World.has_faction(String(g)) \
		and String(g) != e.opfor_faction and String(g) != e.post_faction)


## People on a witness side (Encounter.witness_side: neutral to the crew until they see a crime),
## holding a spot (at a building's door: a standoff; across a road: a checkpoint; by the crowd) or
## walking a beat (roam).
static func _watch(e: Encounter, spec: Dictionary, out: Dictionary) -> void:
	var fid := who(e, String(spec.get("who", "street")))
	var n := _n(e, spec.get("n", [2, 3]))
	var at := Vector3i(-1, -1, -1)
	var where := String(spec.get("at", ""))
	var spots: Dictionary = e.m.params.get("event_spots", {})
	if String(spec.get("near", "")) == "crowd" and out.crowd.x >= 0:
		at = Vector3i(out.crowd.x, out.crowd.y, e.m.street)
	elif where == "road" and spots.has("barricade"):
		var b: Vector2i = spots.barricade[0]
		at = Vector3i(b.x, b.y, e.m.street)
	elif where in ["building", "door"]:
		at = _gather(e, "door")
	if at.x < 0:
		at = _gather(e, "street")
	if at.x < 0:
		out.skipped.append("watch")
		return
	var cells := _watch_cells(e, spec, at, n)
	if cells.is_empty() and where in ["building", "door"]:   # that door opens on a squeeze: another one
		for d in _street_doors(e):
			cells = _watch_cells(e, spec, d, n)
			if not cells.is_empty():
				at = d
				break
	if cells.is_empty():
		out.skipped.append("watch")
		return
	var team := e.witness_side(fid)
	var tier := String(spec.get("tier", "mook"))
	var ids := []
	for i in cells.size():
		var c := World.npc(e.dice, fid, tier if i == 0 else "mook", i + 1)
		e._add(c, cells[i], team)
		var u: Dictionary = e.units[-1]
		u["street_event"] = true
		var look := Vector2(at.x - u.pos.x, at.y - u.pos.y)
		u.facing = look.normalized() if look.length() > 0.1 else Vector2(0, 1)
		if bool(spec.get("roam", false)):
			_beat(e, u)
		else:
			u["hold"] = u.facing
		ids.append(u.id)
	out.applied.append("watch")
	out.units.append_array(ids)


## Where a watch of `n` stands round `at`: a ring round a building's door, else a knot by it.
static func _watch_cells(e: Encounter, spec: Dictionary, at: Vector3i, n: int) -> Array:
	var where := String(spec.get("at", ""))
	var cells := _around(e, at, n if where != "building" else n * 5, 6 if where == "building" or String(spec.get("near", "")) == "crowd" else 4)
	if where == "building":   # a ring round the door, not a queue at it
		cells = cells.filter(func(v): return Vector3(v - at).length() >= 2.0)
		var ring: Array = []
		for v in cells:   # spread round it, two squares apart
			if ring.size() < n and not ring.any(func(q): return Vector3(q - v).length() < 2.0):
				ring.append(v)
		cells = ring
	return cells


## A beat to walk between here and a spot 4-9 squares off (Encounter._post_guards' routes).
static func _beat(e: Encounter, u: Dictionary) -> void:
	var reach: Dictionary = e._keys(func(): return e.nav.reachable(u.pos, 9, e.occupied(u)))
	var far := []
	for v in reach:
		if v.z == u.pos.z and int(reach[v]) >= 4:
			far.append(v)
	if not far.is_empty():
		u.patrol = [u.pos, far[e.dice.d(far.size()) - 1]]
		u.patrol_i = 1


## One or two sides at war with the site's people (FreeForAll's rule) and with each other: two
## gangs squaring off (cold: they face each other until someone shoots) or already shooting (hot:
## alerted, in the initiative order). Placed far from the deploy zone and the target building.
## Neutral to the crew (owner verdict 2026-11-09, `spares_crew`): a gang leaves the crew alone and
## isn't the gig's opposition until the crew attacks it or hits one of its own (Encounter._provoke).
static func _gangs(e: Encounter, spec: Dictionary, out: Dictionary) -> void:
	var sides := clampi(int(spec.get("sides", 2)), 1, 2)
	var hot := bool(spec.get("hot", false))
	var fids: Array = []
	for f in spec.get("factions", []):
		fids.append(who(e, String(f)))
	var local := _gangs_here(e)
	while fids.size() < sides:
		var pool: Array = local.filter(func(g): return not (g in fids))
		if pool.is_empty():
			pool = ["scavvers", "maelstrom", "tyger_claws", "6th_street"].filter(func(g): return not (g in fids) and g != e.opfor_faction)
		fids.append(String(pool[e.dice.d(pool.size()) - 1]))
	var cells := street_cells(e.m, FAR_FROM_DEPLOY, float(Encounter.GUNFIRE_RANGE))
	if cells.is_empty():
		cells = street_cells(e.m, FAR_FROM_DEPLOY, 6.0)
	if cells.is_empty():
		out.skipped.append("gangs")
		return
	var mid: Vector2i = cells[e.dice.d(cells.size()) - 1]
	var c0 := Vector3i(mid.x, mid.y, e.m.street)
	var ring := _around(e, c0, 14, 7)
	if ring.size() < 2:
		out.skipped.append("gangs")
		return
	# split the squares about the middle: one gang each side of a line through it
	var axis := Vector2(1, 0) if e.dice.d(2) == 1 else Vector2(0, 1)
	var halves: Array = [ring.filter(func(v): return Vector2(v.x - c0.x, v.y - c0.y).dot(axis) < 0), ring.filter(func(v): return Vector2(v.x - c0.x, v.y - c0.y).dot(axis) >= 0)]
	if sides == 1:
		halves = [ring]
	var ids := []
	for s in sides:
		var team := e.add_side(String(fids[s]), "guard", false, {"at_war": true, "street": true, "spares_crew": true})
		var n := _n(e, spec.get("n", [2, 3]))
		var mine: Array = halves[s]
		for i in mini(n, mine.size()):
			var c := World.npc(e.dice, String(fids[s]), "mook", i + 1)
			e._add(c, mine[i], team)
			var u: Dictionary = e.units[-1]
			u["street_event"] = true
			var look := Vector2(c0.x - u.pos.x, c0.y - u.pos.y)
			u.facing = look.normalized() if look.length() > 0.1 else axis
			if hot:
				u.alerted = true
				e.init.add(c)
			elif sides == 1:
				u["roam"] = true
				_beat(e, u)
			ids.append(u.id)
	if ids.is_empty():
		out.skipped.append("gangs")
		return
	out.applied.append("gangs")
	out.units.append_array(ids)


## More of the site's own people walking the street (Encounter._outer_patrols' Mooks).
static func _patrol(e: Encounter, spec: Dictionary, out: Dictionary) -> void:
	var cells := street_cells(e.m, FAR_FROM_DEPLOY, 2.0)
	var spots := _spread(e, cells, _n(e, spec.get("n", [1, 2])), 6.0)
	if spots.is_empty():
		out.skipped.append("patrol")
		return
	var ids := []
	for v in spots:
		var g := World.npc(e.dice, e.post_faction, "mook", ids.size() + 1, "Patrol", e._hardened_posts)
		e._add(g, v, Encounter.OPFOR)
		var u: Dictionary = e.units[-1]
		u["outer"] = true
		u["street_event"] = true
		u.facing = Vector2(0, 1)
		_beat(e, u)
		ids.append(u.id)
	out.applied.append("patrol")
	out.units.append_array(ids)


## Trauma Team on a pickup: a cardholder down on the street (unconscious, by a door) and the call
## already made (Encounter.tt, `scene`): the AV lands in round TT_ROUND and takes them away.
static func _trauma(e: Encounter, out: Dictionary) -> void:
	if not e.tt.is_empty():
		out.skipped.append("trauma")
		return
	var at := _gather(e, "door")
	var cells := _around(e, at, 1, 3) if at.x >= 0 else []
	if cells.is_empty():   # that door opens on a squeeze: the client went down outside another
		for d in _street_doors(e):
			cells = _around(e, d, 1, 3)
			if not cells.is_empty():
				break
	if cells.is_empty():
		out.skipped.append("trauma")
		return
	var pool := Recruit.civilian_blocks(e.district)
	e._add_civilian(Recruit.civilian(e.dice, pool[e.dice.d(pool.size()) - 1], "TT Client"), cells[0], false)
	var u: Dictionary = e.units[-1]
	u.c.hp = maxi(1, u.c.max_hp() / 4)
	u.c.unconscious = true
	u["trauma_card"] = true
	u["street_event"] = true
	u["life"] = "down"
	e.tt = {"patient": u.id, "round": TT_ROUND, "state": "called", "scene": true}
	out.applied.append("trauma")
	out.units.append(u.id)


## A cyberpsycho (the Cyberpsycho block, CPR core p.416) at war with everyone, bystanders too,
## already raging (alerted, in the initiative order), far from the crew; MaxTac drops on them after
## `maxtac` rounds (rolled now) unless they're down by then.
static func _psycho(e: Encounter, spec: Dictionary, out: Dictionary) -> void:
	var cells := street_cells(e.m, FAR_FROM_DEPLOY + 4.0, 8.0)
	if cells.is_empty():
		cells = street_cells(e.m, FAR_FROM_DEPLOY, 4.0)
	var spots := _spread(e, cells, 1, 1.0)
	if spots.is_empty():
		out.skipped.append("psycho")
		return
	var c := Recruit.from_block(e.dice, String(db().fx.psycho_block), "Cyberpsycho")
	c.role = "boss"
	c.faction = "cyberpsycho"
	var team := e.add_side("cyberpsycho", "guard", false, {"at_war": true, "street": true})
	e.set_relation(team, Encounter.CIV_TEAM, "hostile")
	e._add(c, spots[0], team)
	var u: Dictionary = e.units[-1]
	u.alerted = true
	u["street_event"] = true
	e.init.add(c)
	e.scene_event["psycho"] = u.id
	out.applied.append("psycho")
	out.units.append(u.id)
	if spec.has("maxtac"):
		var rounds := _n(e, spec.maxtac)
		e.scene_event["maxtac_round"] = rounds + 1


## MaxTac drops near the psycho (Encounter._maxtac_drop's landing), on a witness side: they're
## here for the psycho, not the crew, unless the crew gives them a reason.
static func _maxtac_for(e: Encounter, psy: Dictionary) -> void:
	var team := e.witness_side("maxtac")
	var spot := e.av_spot(psy.pos, 4, 30)
	var ids: Array = []
	if spot.x >= 0:
		ids = e._responders("maxtac", team, e._av_exits(spot, 3), 4)
		for id in ids:
			e.units[id]["maxtac"] = true
		if not ids.is_empty():
			e.events.append({"type": "av_land", "unit": ids[0], "kind": "maxtac", "cell": spot, "units": ids, "yaw": e.av_fit.yaw, "scale": e.av_fit.scale})
	else:
		var r := World.responder("maxtac")
		var tiers: Array[String] = []
		for t in r.tiers:
			tiers.append(String(t))
		e._spawn_wave(tiers, "MAXTAC", team, "maxtac", String(r.get("rank", "")))
	e.say("MaxTac drops in for the cyberpsycho.")

