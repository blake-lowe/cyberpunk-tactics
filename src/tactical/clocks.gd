class_name Clocks
extends RefCounted
## Solo Play Clocks in an encounter (SPM p.25-26; the Clock in src/core/clock.gd): which clocks a
## gig runs (Encounter.clocks), the triggers that roll them, what happens when one empties, and
## winning dice back (Reclaiming Their Time, SPM p.26). Tuning and the HOUSE-RULE reasons are
## data/gen/clocks.json. Rules only (no Nodes): every roll on the encounter's Dice; the view reads
## Encounter.clocks and plays the `clock` / `clock_add` events.
##
## - The detection clock (the book's Corporate Heist pattern) runs on a stealth gig from the start.
##   It adds pressure to the sight-based alarm, it doesn't replace it: guards still spot the crew
##   and call it in as before. When it empties, the alarm goes to 2 and the site's response timer
##   starts (Encounter.call_it_in: the NC2045 response times are unchanged). With Degrees of
##   Consequence (two or more dice on the last roll) the response comes one intensity step heavier.
##   Once the alarm is up some other way, it stops.
## - The Time Limit clock went with its plot twist (owner cut, twists.json time_limit: unmodelled).
##
## Trigger kinds (Encounter calls trigger()): round, failed_stealth, failed_tech, room_time,
## body_seen, noise, objective. Rate limits are per kind: see clocks.json `_triggers`.

const KINDS := ["round", "failed_stealth", "failed_tech", "room_time", "body_seen", "noise", "objective"]
const LIMIT_ROUND := ["failed_stealth", "room_time", "body_seen", "round"]   ## once a round (per crew member for failed_stealth)


static func db() -> Dictionary:
	return RulesDB.gen("clocks.json")


## A clock from its clocks.json entry at security `level` (1-3; the detection pools differ by level).
static func make(id: String, level := 2) -> Clock:
	var d: Dictionary = db().get(id, {})
	var lv := str(clampi(level, 1, 3))
	var pool: Variant = d.get("pool", 4)
	var drop: Variant = d.get("drop_on", [1])
	var n := int((pool as Dictionary).get(lv, 5)) if pool is Dictionary else int(pool)
	var faces: Array = (drop as Dictionary).get(lv, [1]) if drop is Dictionary else drop
	var c := Clock.make(id, n, faces, bool(d.get("escalate", true)), d.get("triggers", []), String(d.get("label", id.to_upper())))
	return c


## The running clock with this id, or null.
static func get_clock(e: Encounter, id: String) -> Clock:
	for c in e.clocks:
		if (c as Clock).id == id:
			return c
	return null


## Is this a stealth gig (clocks.json detection `_objectives`)? It starts quiet: no alarm, nobody
## on the opposition alerted, guards posted, responses on, and the objective isn't a straight hit.
static func stealth_gig(e: Encounter) -> bool:
	if e.alarm > 0 or not e.reinforcements or e.obj == null:
		return false
	if String(e.objective.get("kind", "")) in (db().detection.get("skip_objectives", []) as Array):
		return false
	var guards := e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and not u.c.dead)
	return not guards.is_empty() and not guards.any(func(u): return bool(u.alerted))


## Start the gig's clocks (Encounter.setup, last): the detection clock on a stealth gig. `force`:
## "auto" decides (stealth_gig: campaign gigs); true / false runs it or not whatever the gig.
static func start(e: Encounter, force: Variant = "auto") -> void:
	var on: bool = stealth_gig(e) if (force == null or (force is String and force == "auto")) else bool(force)
	if on and get_clock(e, "detection") == null:
		var c := make("detection", int(e.m.params.get("security", 1)) if e.m != null else 1)
		c.meta["event"] = "alarm"
		e.clocks.append(c)


## Add a clock mid-gig (a plot twist's `clock` fx). Returns it.
static func add(e: Encounter, id: String) -> Clock:
	var have := get_clock(e, id)
	if have != null:
		return have
	var c := make(id, int(e.m.params.get("security", 1)) if e.m != null else 1)
	c.meta["event"] = String(db().get(id, {}).get("event", id))
	e.clocks.append(c)
	e.events.append({"type": "clock_new", "unit": _anchor(e), "clock": id, "size": c.size})
	return c


static func _anchor(e: Encounter, uid := -1) -> int:
	if uid >= 0 and uid < e.units.size():
		return uid
	if not e.cur.is_empty():
		return int(e.cur.id)
	return 0


## A trigger of `kind` happened (Encounter's hooks): every running clock that listens to it rolls
## once, within the kind's rate limit. `uid`: the crew member it's about (-1 none); `why` names it
## for the log and the HUD. `forced`: the faces (review renders). Returns the rolls made.
static func trigger(e: Encounter, kind: String, uid := -1, why := "", forced: Array = []) -> Array:
	var out := []
	if e.state != "playing":
		return out
	for c0 in e.clocks.duplicate():
		var c: Clock = c0
		if not c.running() or not kind in c.triggers:
			continue
		var key := _limit_key(e, c, kind, uid)
		if not key.is_empty():
			if e._clock_hits.has(key):
				continue
			e._clock_hits[key] = true
		var r := c.trigger(e.dice, forced)
		if r.is_empty():
			continue
		r["clock"] = c.id
		r["why"] = why if why != "" else kind
		out.append(r)
		var gone := (r.removed as Array).size()
		e.say("%s clock: %s. %d dice rolled, %s." % [c.label.capitalize(), r.why, (r.faces as Array).size(),
			("%d gone, %d left" % [gone, int(r.left)]) if gone > 0 else "none gone"])
		e.events.append({"type": "clock", "unit": _anchor(e, uid), "clock": c.id, "faces": r.faces, "removed": r.removed,
			"left": r.left, "emptied": r.emptied, "escalated": r.escalated, "why": r.why})
		if bool(r.emptied):
			_empty(e, c)
	return out


## The rate-limit key for a trigger ([] none: every one rolls).
static func _limit_key(e: Encounter, c: Clock, kind: String, uid: int) -> Array:
	var rn := e.init.round_num if e.init else 0
	match kind:
		"failed_stealth":
			return [c.id, kind, uid, rn]
		"room_time", "body_seen", "round":
			return [c.id, kind, rn]
		"noise":
			return [c.id, kind, int(e.cur.get("id", -1)), rn]
		"objective":
			return [c.id, kind]
	return []


## The clock ran out: its event.
static func _empty(e: Encounter, c: Clock) -> void:
	match String(c.meta.get("event", c.id)):
		"alarm":
			e.say("The detection clock runs out.")
			raise_alarm(e, c.escalated)
		_:
			e.say("%s clock: time's up." % c.label.capitalize())


## The alarm goes up with nobody having seen the crew: the guard best placed to notice (the
## highest-ranked on the opposition, nearest the crew on a tie) calls it in, as one who spotted
## them would (Encounter.call_it_in: the site's code rolls, the response timer starts). With
## `escalated` (Degrees of Consequence) the responses it plans come one intensity step heavier.
const ALARM_WHY := "DETECTION CLOCK RAN OUT"   ## the alarm's cause (Encounter.alarm_cause) when the clock empties


static func raise_alarm(e: Encounter, escalated := false) -> void:
	if e.alarm >= 2:
		return
	var rank := {"mini_boss": 3, "lieutenant": 2, "mook": 1}
	var crew := e.alive(Encounter.CREW)
	var best: Dictionary = {}
	var bs := -INF
	for g in e.units:
		if int(g.team) != Encounter.OPFOR or g.c.dead or not g.c.can_act() or g.has("broke") or g.get("vip", false):
			continue
		var near := INF
		for u in crew:
			near = minf(near, Vector3(g.pos - u.pos).length())
		var s := float(rank.get(String(g.c.role), 0)) * 1000.0 - near
		if s > bs:
			bs = s
			best = g
	if best.is_empty():
		e.alarm = 2
		e._set_alarm_cause(ALARM_WHY)
		e.say("The alarm goes up.")
		e.events.append({"type": "alarm", "unit": _anchor(e), "rounds": -1, "clock": true})
		return
	if not best.alerted:
		best.alerted = true
		e.init.add(best.c)
	e.call_it_in(best, ALARM_WHY)
	if e.alarm < 2:   # responses switched off (balance tests): the alarm still goes up
		e.alarm = 2
		e._set_alarm_cause(ALARM_WHY)
	if escalated:
		escalate(e)


## Degrees of Consequence (SPM p.26): the planned responses come one intensity step heavier
## (Light → Medium → Heavy, NC2045 p.7; a Heavy one comes Hardened).
static func escalate(e: Encounter) -> void:
	var up := func(r: Dictionary) -> void:
		if r.is_empty() or not r.has("code"):
			return
		var code: Dictionary = (r.code as Dictionary).duplicate()
		var i := SecurityCode.INTENSITIES.find(String(code.get("intensity", "medium")))
		if i >= SecurityCode.INTENSITIES.size() - 1:
			code["hardened"] = true
		else:
			code["intensity"] = SecurityCode.INTENSITIES[i + 1]
		r["code"] = code
	up.call(e._response)
	up.call(e._street)
	e.say("The response will come in heavier.")
	e.events.append({"type": "clock_escalate", "unit": _anchor(e)})


## Once a round, at its start (Encounter.next_turn): the round trigger, a minute in a secured room,
## a body in an unalerted guard's sight.
static func round_start(e: Encounter) -> void:
	if e.clocks.is_empty():
		return
	trigger(e, "round", -1, "a round passes")
	var d: Dictionary = db().detection
	var zone := int(d.get("room_zone", TacMap.Zone.SECURE))
	var need := int(d.get("room_rounds", SecurityCode.ROUNDS_PER_MINUTE))
	var lingering := -1
	for u in e.alive(Encounter.CREW):
		var l := e.m.label(u.pos.z, u.pos.x, u.pos.y)
		var key := int(u.id)
		if l < 0 or int(e.m.rooms[l].zone) < zone:
			e._room_rounds.erase(key)
			continue
		var was: Array = e._room_rounds.get(key, [-1, 0])
		var n := int(was[1]) + 1 if int(was[0]) == l else 1
		e._room_rounds[key] = [l, n]
		if n >= need and lingering < 0:
			lingering = key
	if lingering >= 0:
		trigger(e, "room_time", lingering, "%s lingers in a secured room" % e.units[lingering].c.display_name)
	for g in e.units:
		if int(g.team) == Encounter.OPFOR and e.is_guard(g) and not g.alerted and g.c.can_act() and e._body_in_sight(g):
			trigger(e, "body_seen", -1, "a body in %s's sight" % g.c.display_name)
			break


## The crew took the objective (Objective.near_done turned true): the detection clock rolls once.
static func check_objective(e: Encounter) -> void:
	if e.clocks.is_empty() or e.obj == null or e._clock_obj_seen or not e.obj.near_done():
		return
	e._clock_obj_seen = true
	trigger(e, "objective", int(e.cur.get("id", -1)) if not e.cur.is_empty() and int(e.cur.team) == Encounter.CREW else -1, "the objective is taken")


## The alarm went up some other way: the detection clock is moot.
static func on_alarm(e: Encounter) -> void:
	var c := get_clock(e, "detection")
	if c != null and c.running():
		c.stop()
		e.events.append({"type": "clock_stop", "unit": _anchor(e), "clock": c.id})


# --- Reclaiming Their Time (SPM p.26) ------------------------------------------------------

## The running clock a reclaim works on this turn (the detection clock), or null when there is none
## or it already won a die back this turn.
static func reclaimable(e: Encounter) -> Clock:
	var c := get_clock(e, "detection")
	if c == null or not c.running() or c.pool >= c.size:
		return null
	if e._clock_hits.has([c.id, "reclaim", e.init.round_num, int(e.cur.get("id", -1))]):
		return null
	return c


## A device a SPOOF can work from where `u` stands: a live camera or an alarm panel within reach on
## the floor with no wall between that hasn't been spoofed for this clock. {} for none.
static func spoof_target(e: Encounter, u: Dictionary) -> Dictionary:
	var rc: Dictionary = db().reclaim
	var reach := int(rc.get("range", 3))
	var types: Array = rc.get("devices", ["camera", "alarm_panel"])
	var best := {}
	var bd := INF
	for d in e.m.devices:
		if not String(d.type) in types or int(d.floor) != u.pos.z or e._spoofed.has(int(d.id)):
			continue
		if String(d.type) == "camera" and e.disabled_devices.has(d.id):
			continue   # dead or already looped: nothing to fool
		var cp := Vector3i(d.pos.x, d.pos.y, d.floor)
		var dist := maxi(absi(cp.x - u.pos.x), absi(cp.y - u.pos.y))
		if dist <= reach and not e._wall_between(u.pos, cp) and dist < bd:
			bd = dist
			best = d
	return best


## Can the active crew member SPOOF right now (a clock to win time on, a device in reach, the Action)?
static func can_spoof(e: Encounter) -> bool:
	return not e.cur.is_empty() and int(e.cur.team) == Encounter.CREW and e.turn != null and e.turn.action_available \
		and reclaimable(e) != null and not spoof_target(e, e.cur).is_empty()


static func spoof_base(c: Combatant) -> int:
	return c.skill_base("electronics_security_tech") + int(c.maker.get("field", 0)) - c.action_penalty()


## SPOOF: an Action, TECH + Electronics/Security Tech vs DV15 at a camera or alarm panel in reach.
## Success loops the camera by hand (or fools the panel) and adds a die back; failure is a failed
## Electronics/Security Tech check, and the clock rolls. {ok, success?, reason?}.
static func spoof(e: Encounter) -> Dictionary:
	var c := reclaimable(e)
	if c == null:
		return {"ok": false, "reason": "no clock to win time on" if get_clock(e, "detection") == null or not get_clock(e, "detection").running() else ("the clock is full" if get_clock(e, "detection").pool >= get_clock(e, "detection").size else "already won time this turn")}
	var d := spoof_target(e, e.cur)
	if d.is_empty():
		return {"ok": false, "reason": "no camera or alarm panel within %d squares" % int(db().reclaim.get("range", 3))}
	if not e.turn.use_action():
		return {"ok": false, "reason": "no action left"}
	var dv := int(db().reclaim.get("dv", 15))
	var check := Check.vs_dv(e.dice, spoof_base(e.cur.c), dv)
	var who: String = e.cur.c.display_name
	var what := "camera" if String(d.type) == "camera" else "alarm panel"
	if check.success:
		e._spoofed[int(d.id)] = true
		if String(d.type) == "camera":
			e.looped[int(d.id)] = int(e.cur.id)
			e.disabled_devices[int(d.id)] = true
		e.events.append({"type": "spoof", "unit": e.cur.id, "device": d.id, "ok": true})
		e.say("%s spoofs the %s." % [who, what])
		reclaim(e, c, "%s spoofs the %s" % [who, what])
	else:
		e.events.append({"type": "spoof", "unit": e.cur.id, "device": d.id, "ok": false})
		e.say("%s fumbles the %s spoof." % [who, what])
		trigger(e, "failed_tech", int(e.cur.id), "%s's spoof fails" % who)
	return {"ok": true, "success": check.success, "dv": dv}


## A NET Action worked a device that fools the site (looping cameras, cutting the alarm line:
## clocks.json reclaim net_ops): the detection clock wins a die back, once a turn, once per device.
static func on_net_device(e: Encounter, did: int, op: String, now_on: bool) -> void:
	if not now_on or not op in (db().reclaim.get("net_ops", []) as Array) or e._spoofed.has(did):
		return
	var c := reclaimable(e)
	if c == null:
		return
	e._spoofed[did] = true
	reclaim(e, c, "%s %s from the NET" % [e.cur.c.display_name, "loops the cameras" if op == "loop" else "cuts the alarm line"])


## Add a die back to `c` (once per clock per turn).
static func reclaim(e: Encounter, c: Clock, why: String) -> int:
	var n := c.add_die(1)
	if n <= 0:
		return 0
	e._clock_hits[[c.id, "reclaim", e.init.round_num, int(e.cur.get("id", -1))]] = true
	e.say("%s clock: %s. A die back, %d now." % [c.label.capitalize(), why, c.pool])
	e.events.append({"type": "clock_add", "unit": _anchor(e), "clock": c.id, "left": c.pool, "why": why})
	return n


# --- Text ----------------------------------------------------------------------------------

## The hover card for a clock: what it tracks, its triggers, what happens when it empties.
static func tip(c: Clock) -> String:
	var d: Dictionary = db().get(c.id, {})
	var drop := " or ".join(c.drop_on.map(func(f): return str(f)))
	var t := String(d.get("tip", "")).replace("{drop}", "a " + drop)
	var head := "%d of %d dice left. A die goes on a %s.%s" % [c.pool, c.size, drop,
		" Lose two at once on the last roll and the response is heavier." if c.escalate else ""]
	return head + "\n" + t
