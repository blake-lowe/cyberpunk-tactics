class_name StreetLife
extends RefCounted
## Everyday life on every map (owner note 2026-11-09: "more everyday events around maps to give it
## more life"). The bystanders Encounter places (_place_civilians) get something to do, and a few
## more join them where a street has places for it: a vendor at a stall with people queuing, a pair
## talking, someone smoking by a wall, people walking between two spots on the pavement, patrons in
## a bar or club, a few office workers. They are ordinary bystanders under the existing rules (the
## CIV_TEAM side): they panic at gunfire and run (Encounter._civilians_tick), block squares and can
## be hit. Each has `life` (what the view poses them doing) and walkers a `route`.
##
## HOUSE-RULE (readability, the known corridor problem): nobody ambient stands in a 1-wide passage,
## in a doorway or the square in front of one, on stairs, or in or beside the rooms the objective is
## about (blocked_spot); walkers' routes never cross such a square, and they never stop where
## anyone stands. A walker takes up to WALK_STEP squares a round, only while calm.
##
## Its own dice (the map's seed), so everyday life never shifts the gig's rolls.

const WALK_STEP := 3                     ## squares a calm walker covers a round (a stroll, not a Move)
const OBJ_CLEAR := 4.0                   ## squares kept clear round the objective's squares
const MAX_CIVS := 28                     ## HOUSE-RULE: bystanders on a map at most (frame budget: each is a skinned body)
const NEAR_DEPLOY := 7.0                 ## everyday life starts this far from the deploy zone (the old bystanders: 10)
const OUTDOOR_LIFE := ["phone", "talk", "loiter", "smoke", "fold"]
## Rooms where people sit, drink, dance or wait (rooms.json kinds) and how they spend the time.
const PATRON_ROOMS := {"bar": ["sit", "talk", "drink"], "dance_floor": ["dance", "dance", "talk"], "lounge": ["sit", "talk", "drink"],
	"vip_lounge": ["sit", "drink"], "shop_floor": ["browse", "talk"], "clinic_waiting": ["sit", "phone"], "waiting": ["sit", "phone"],
	"lobby": ["phone", "talk"], "concourse": ["phone", "talk", "loiter"], "front_desk": ["phone"], "temple_hall": ["sit"],
	"mess": ["sit", "talk"], "dining_car": ["sit", "talk"], "passenger_car": ["sit", "phone"]}
## Rooms where a few people work (office staff).
const WORK_ROOMS := {"office": ["work", "phone"], "bullpen": ["work", "work", "phone"], "meeting": ["talk", "sit"]}
const SIT_DECOR := ["side_chair", "stool"]


static func _dice(m: TacMap) -> Dice:
	return Dice.new(m.seed_value * 17 + 3)


# --- Where nobody ambient stands -------------------------------------------------------------

## A 1-wide passage: walkable, with both squares to its sides (left and right, or front and back)
## not walkable, and the way through open. Doors, stairs and lifts count.
static func is_choke(m: TacMap, v: Vector3i) -> bool:
	var f := v.z
	var p := Vector2i(v.x, v.y)
	if m.t(f, p.x, p.y) in [TacMap.T.DOOR, TacMap.T.STAIRS, TacMap.T.ELEVATOR] or m.is_connector_end(f, p):
		return true
	var open := func(d: Vector2i) -> bool: return m.inb(p.x + d.x, p.y + d.y) and m.walkable(f, p + d)
	var ew: bool = not open.call(Vector2i(1, 0)) and not open.call(Vector2i(-1, 0)) and (open.call(Vector2i(0, 1)) or open.call(Vector2i(0, -1)))
	var ns: bool = not open.call(Vector2i(0, 1)) and not open.call(Vector2i(0, -1)) and (open.call(Vector2i(1, 0)) or open.call(Vector2i(-1, 0)))
	return ew or ns


## Beside a door, stair or lift (standing there would block the way in).
static func by_door(m: TacMap, v: Vector3i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if m.inb(v.x + dx, v.y + dy) and m.t(v.z, v.x + dx, v.y + dy) in [TacMap.T.DOOR, TacMap.T.STAIRS, TacMap.T.ELEVATOR]:
				return true
	return false


## The rooms the objective is about and the squares it marks (Objective focus_cell, focus_unit,
## marks, zones), cached on the encounter: {rooms: {id: true}, cells: [Vector3i]}.
static func objective_area(e: Encounter) -> Dictionary:
	if e.has_meta("obj_area"):
		return e.get_meta("obj_area")
	var cells: Array = []
	if e.obj != null:
		var fc := e.obj.focus_cell()
		if fc.x >= 0:
			cells.append(fc)
		var fu := e.obj.focus_unit()
		if fu >= 0 and fu < e.units.size():
			cells.append(e.units[fu].pos)
		if not e.cur.is_empty() or not e.units.is_empty():
			for mk in e.obj.marks(false):
				if mk is Dictionary and mk.has("cell"):
					cells.append(mk.cell)
		for z in e.obj.zones():
			for c in z.get("cells", []):
				cells.append(c)
	for u in e.units:   # the people the job is about: a mark, a captive, a client
		if u.get("vip", false) or int(u.team) == Encounter.CAPTIVE:
			cells.append(u.pos)
	for st in e.m.structures:   # every way into the target's NET (the marker shows the nearest one to whoever's up)
		if bool(st.get("target", false)) and e.m.architectures.has(int(st.id)):
			var a: NetArchitecture = e.m.architectures[int(st.id)]
			for ap in a.access_points:
				var d: Dictionary = e.m.devices[ap.device]
				cells.append(Vector3i(d.pos.x, d.pos.y, d.floor))
	var rooms := {}
	for c in cells:
		var l := e.m.label(c.z, c.x, c.y)
		if l >= 0 and not bool(e.m.rooms[l].get("outdoor", false)):
			rooms[l] = true
	var area := {"rooms": rooms, "cells": cells}
	e.set_meta("obj_area", area)
	return area


## Where no ambient bystander may stand: a 1-wide passage, beside a door or stair, in a room the
## objective is about or within OBJ_CLEAR squares of its squares.
static func blocked_spot(e: Encounter, v: Vector3i) -> bool:
	var m := e.m
	if not m.inb(v.x, v.y) or not m.walkable(v.z, Vector2i(v.x, v.y)) or is_choke(m, v) or by_door(m, v):
		return true
	var area := objective_area(e)
	var l := m.label(v.z, v.x, v.y)
	if l >= 0 and area.rooms.has(l):
		return true
	for c in area.cells:
		if c.z == v.z and Vector2(c.x - v.x, c.y - v.y).length() <= OBJ_CLEAR:
			return true
	return false


# --- Placing everyday life (Encounter.setup, after the bystanders) ------------------------------

static func civ_count(e: Encounter) -> int:
	return e.units.filter(func(u): return u.get("civ", false)).size()


## Give the bystanders something to do and add the vendors, queues, talkers, smokers, walkers and
## patrons the map has places for. `deploy`: the deploy zone's middle (nobody within 10 squares).
static func place(e: Encounter, deploy: Vector2i) -> void:
	var scene := String(e.m.params.get("scene", ""))
	if scene in ["badlands", "undercity"]:
		return
	var d := _dice(e.m)
	for u in e.units:   # the bystanders already out: indoors patrons, outdoors one in three walks
		if not u.get("civ", false) or u.has("life"):
			continue
		var l := e.m.label(u.pos.z, u.pos.x, u.pos.y)
		var kind := String(e.m.rooms[l].kind) if l >= 0 else ""
		if l >= 0 and not bool(e.m.rooms[l].get("outdoor", false)):
			var acts: Array = PATRON_ROOMS.get(kind, ["phone", "talk"])
			u["life"] = _pose_at(e, u.pos, String(acts[d.d(acts.size()) - 1]))
		elif d.d(5) <= 2 and _give_route(e, d, u, deploy):   # two in five walk
			u["life"] = "walk"
		else:
			u["life"] = String(OUTDOOR_LIFE[d.d(OUTDOOR_LIFE.size()) - 1])
	var budget := clampi(int(e.m.w * e.m.h / 550.0), 3, 14)
	budget = mini(budget, MAX_CIVS - civ_count(e))
	var outside := _outdoor_spots(e, deploy)
	budget -= _vendors(e, d, outside, deploy, mini(budget, 5))
	budget -= _pairs(e, d, outside, deploy, mini(budget, 4))
	budget -= _walkers(e, d, outside, deploy, mini(budget, 4))
	budget -= _smokers(e, d, outside, deploy, mini(budget, 2))
	_patrons(e, d, deploy, mini(6, MAX_CIVS - civ_count(e)))


## A pose that needs furniture falls back to standing where there's none: sitting needs a chair
## or stool (walk-through decor) under them.
static func _pose_at(e: Encounter, v: Vector3i, pose: String) -> String:
	if pose != "sit":
		return pose
	for dc in e.m.decor:
		if int(dc.floor) == v.z and Vector2i(dc.pos) == Vector2i(v.x, v.y) and String(dc.kind) in SIT_DECOR:
			return "sit"
	return "drink" if pose == "sit" else pose


## Open pavement and street squares where an ambient bystander may stand: NEAR_DEPLOY+ squares
## from the deploy zone, off the target building, not blocked (blocked_spot). On a big map, the
## streets round the target (within AROUND_TARGET squares) when there's room there: life goes
## where the crew will be looking.
const AROUND_TARGET := 28.0


static func _outdoor_spots(e: Encounter, deploy: Vector2i) -> Array:
	var m := e.m
	var out: Array = []
	var occ := e.occupied()
	var tr := SceneEvent._target_rect(m)
	var near: Array = []
	for v2 in SceneEvent.street_cells(m, NEAR_DEPLOY, 1.0):
		var v := Vector3i(v2.x, v2.y, m.street)
		if not occ.has(v) and not blocked_spot(e, v):
			out.append(v)
			if SceneEvent._off_rect(tr, v2) <= AROUND_TARGET:
				near.append(v)
	return near if near.size() >= 60 else out


static func _free(e: Encounter, v: Vector3i) -> bool:
	return not e.occupied().has(v) and not blocked_spot(e, v)


## A place whose Security Code answers with its own patrons (`locals`, a club's regulars): its
## people keep their printed weapons, as Encounter._place_civilians has it.
static func armed_locals(e: Encounter) -> bool:
	return String(e.code.get("faction", "")) == SecurityCode.VENUE


static func _add(e: Encounter, d: Dice, v: Vector3i, life: String, face: Vector2 = Vector2.ZERO) -> Dictionary:
	var pool := Recruit.civilian_blocks(e.district) if d.d(3) <= 2 else Recruit.civilian_blocks()
	e._add_civilian(Recruit.civilian(d, pool[d.d(pool.size()) - 1]), v, armed_locals(e))
	var u: Dictionary = e.units[-1]
	u["life"] = life
	u["ambient"] = true
	if face != Vector2.ZERO:
		u.facing = face.normalized()
	return u


## A street vendor at a stall or kiosk (standing beside it), and one to three customers queued at a
## stall or a vending machine, facing it.
static func _vendors(e: Encounter, d: Dice, spots: Array, deploy: Vector2i, n: int) -> int:
	if n <= 0:
		return 0
	var m := e.m
	var placed := 0
	var shops: Array = m.cover.filter(func(c): return int(c.floor) == m.street and String(c.kind) in ["stall", "kiosk", "vending"] \
		and int(c.get("room", -1)) < 0 and Vector2(Vector2i(c.pos) - deploy).length() >= NEAR_DEPLOY)
	for i in range(shops.size() - 1, 0, -1):
		var j := d.rng.randi_range(0, i)
		var t: Variant = shops[i]
		shops[i] = shops[j]
		shops[j] = t
	for s in shops:
		if placed >= n:
			break
		var p := Vector3i(s.pos.x, s.pos.y, m.street)
		var front: Array = []
		for dir in MapGen.DIRS:
			var v := p + Vector3i(dir.x, dir.y, 0)
			if _free(e, v):
				front.append([v, dir])
		if front.is_empty():
			continue
		if String(s.kind) != "vending":   # the vendor stands at the stall's side
			var f0: Array = front[0]
			_add(e, d, f0[0], "vendor", Vector2(-f0[1].x, -f0[1].y))
			placed += 1
			front.remove_at(0)
		if front.is_empty() or placed >= n:
			continue
		var f1: Array = front[d.d(front.size()) - 1]   # the queue, away from the counter in a line
		var dir: Vector2i = f1[1]
		for k in mini(d.d(3), n - placed):
			var v: Vector3i = f1[0] + Vector3i(dir.x, dir.y, 0) * k
			if not _free(e, v):
				break
			_add(e, d, v, "queue", Vector2(-dir.x, -dir.y))
			placed += 1
	return placed


## Two people talking face to face on the pavement.
static func _pairs(e: Encounter, d: Dice, spots: Array, deploy: Vector2i, n: int) -> int:
	var placed := 0
	for k in 30:
		if placed + 2 > n or spots.is_empty():
			break
		var v: Vector3i = spots[d.d(spots.size()) - 1]
		var dir: Vector2i = MapGen.DIRS[d.d(4) - 1]
		var w := v + Vector3i(dir.x, dir.y, 0)
		if not _free(e, v) or not _free(e, w) or _crowded(e, v, 3.0):
			continue
		_add(e, d, v, "talk", Vector2(dir))
		_add(e, d, w, "talk", -Vector2(dir))
		placed += 2
	return placed


## Someone smoking against a wall.
static func _smokers(e: Encounter, d: Dice, spots: Array, deploy: Vector2i, n: int) -> int:
	var m := e.m
	var walls := spots.filter(func(v): return MapGen.DIRS.any(func(o): return m.t(v.z, v.x + o.x, v.y + o.y) == TacMap.T.WALL))
	var placed := 0
	for k in 20:
		if placed >= n or walls.is_empty():
			break
		var v: Vector3i = walls[d.d(walls.size()) - 1]
		if not _free(e, v) or _crowded(e, v, 4.0):
			continue
		var away := Vector2.ZERO
		for o in MapGen.DIRS:
			if m.t(v.z, v.x + o.x, v.y + o.y) == TacMap.T.WALL:
				away -= Vector2(o)
		_add(e, d, v, "smoke", away)
		placed += 1
	return placed


## People walking a route between two pavement squares.
static func _walkers(e: Encounter, d: Dice, spots: Array, deploy: Vector2i, n: int) -> int:
	var placed := 0
	for k in 20:
		if placed >= n or spots.is_empty():
			break
		var v: Vector3i = spots[d.d(spots.size()) - 1]
		if not _free(e, v) or _crowded(e, v, 3.0):
			continue
		var u := _add(e, d, v, "walk")
		if not _give_route(e, d, u, deploy):
			u["life"] = String(OUTDOOR_LIFE[d.d(OUTDOOR_LIFE.size()) - 1])
		placed += 1
	return placed


static func _crowded(e: Encounter, v: Vector3i, r: float) -> bool:
	return e.units.any(func(u): return u.get("civ", false) and u.pos.z == v.z and Vector2(u.pos.x - v.x, u.pos.y - v.y).length() < r)


## Out in the open at street level: no room, or an outdoor one (a plaza, a market, a lot).
static func outdoors(m: TacMap, v: Vector3i) -> bool:
	if v.z != m.street or m.t(v.z, v.x, v.y) != TacMap.T.OUTSIDE:
		return false
	var l := m.label(v.z, v.x, v.y)
	return l < 0 or bool(m.rooms[l].get("outdoor", false))


## A route for walker `u`: to an outdoor square 6-16 squares off whose path crosses no blocked
## square and keeps 8+ squares from the deploy zone. False if none was found.
static func _give_route(e: Encounter, d: Dice, u: Dictionary, deploy: Vector2i) -> bool:
	if not outdoors(e.m, u.pos):
		return false
	var reach: Dictionary = e._keys(func(): return e.nav.reachable(u.pos, 16, e.occupied(u)))
	var ends: Array = reach.keys().filter(func(v): return v.z == u.pos.z and int(reach[v]) >= 6 and outdoors(e.m, v))
	for k in 12:
		if ends.is_empty():
			return false
		var goal: Vector3i = ends[d.d(ends.size()) - 1]
		var path: Array = e._keys(func(): return e.nav.path(u.pos, goal, {}))
		if path.is_empty() or path.any(func(p): return blocked_spot(e, p) or Vector2(p.x - deploy.x, p.y - deploy.y).length() < 8.0):
			continue
		u["route"] = [u.pos, goal]
		u["route_i"] = 1
		return true
	return false


## Patrons in the public rooms of the street floor that suit them (bars, clubs, shops, waiting
## rooms) and a few office workers, never in a room the objective is about.
static func _patrons(e: Encounter, d: Dice, deploy: Vector2i, n: int) -> int:
	var m := e.m
	var placed := 0
	var rooms: Array = m.rooms.filter(func(r): return int(r.floor) == m.street and not bool(r.get("outdoor", false)) \
		and (PATRON_ROOMS.has(String(r.kind)) or WORK_ROOMS.has(String(r.kind))) and not objective_area(e).rooms.has(int(r.id)))
	for r in rooms:
		if placed >= n:
			break
		var acts: Array = PATRON_ROOMS.get(String(r.kind), WORK_ROOMS.get(String(r.kind), ["talk"]))
		var want := clampi(int(r.cells) / 14, 1, 3) if PATRON_ROOMS.has(String(r.kind)) else (1 if d.d(2) == 1 else 0)
		var have := e.units.filter(func(u): return u.get("civ", false) and m.label(u.pos.z, u.pos.x, u.pos.y) == int(r.id)).size()
		var b: Rect2i = r.bounds
		for k in 30:
			if have >= want or placed >= n:
				break
			var v := Vector3i(d.rng.randi_range(b.position.x, b.end.x - 1), d.rng.randi_range(b.position.y, b.end.y - 1), m.street)
			if m.label(v.z, v.x, v.y) != int(r.id) or not _free(e, v) or Vector2(v.x - deploy.x, v.y - deploy.y).length() < 10.0 or _crowded(e, v, 2.0):
				continue
			var life := _pose_at(e, v, String(acts[d.d(acts.size()) - 1]))
			var to := Vector2(b.get_center()) - Vector2(v.x, v.y)
			_add(e, d, v, life, to if to.length() > 0.5 else Vector2(0, 1))
			have += 1
			placed += 1
	return placed


# --- A round of everyday life (Encounter._civilians_tick) ---------------------------------------

## Calm walkers take a few squares along their route (turning back at its end); never onto anyone,
## never to stop on a blocked square. Emits `stroll` events the view plays all at once.
static func tick(e: Encounter) -> void:
	for u in e.units:
		if not u.has("route") or u.get("panic", false) or u.c.dead or not u.c.can_act() or u.get("fled", false):
			continue
		var goal: Vector3i = u.route[u.route_i]
		if u.pos == goal:
			u.route_i = (int(u.route_i) + 1) % (u.route as Array).size()
			goal = u.route[u.route_i]
		var path: Array[Vector3i] = e._keys(func(): return e.nav.path(u.pos, goal, e.occupied(u)))
		if path.is_empty():
			continue
		var stop := -1
		for i in mini(WALK_STEP, path.size()):
			var p: Vector3i = path[i]
			if p.z != u.pos.z:
				break
			if not e.occupied(u).has(p) and not blocked_spot(e, p):
				stop = i
		if stop < 0:
			continue
		var full: Array = [u.pos]
		full.append_array(path.slice(0, stop + 1))
		var last: Vector3i = full[-1]
		u.facing = Vector2(last.x - full[-2].x, last.y - full[-2].y).normalized()
		u.pos = last
		e.events.append({"type": "stroll", "unit": u.id, "path": full})
