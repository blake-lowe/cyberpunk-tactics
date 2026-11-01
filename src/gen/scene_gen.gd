class_name SceneGen
extends RefCounted
## Builds whole scenes: outdoor ground, roads, water, fences and yards, with buildings filled by
## BuildingGen. Each scene type has a planner below; data/gen/scenes.json lists them for tools.
## Outdoor areas that matter (parking lots, compounds, quays) are yard "rooms" with a zone, so
## zoning, furnishing, devices and NETs work the same indoors and out. Open street is zone STREET.

const G := TacMap.G


static func scene_types() -> Array:
	return RulesDB.gen("scenes.json").keys().filter(func(k): return not k.begins_with("_"))


static func generate(seed_value: int, scene: String, overrides: Dictionary = {}) -> TacMap:
	var sdef: Dictionary = RulesDB.gen("scenes.json")[scene]
	var p: Dictionary = MapGen.DEFAULTS.duplicate()
	p.merge(sdef.get("params", {}), true)
	p.merge(overrides, true)
	if int(p.get("verticality", 1)) == 0:
		p.floors = 1
	var dice := Dice.new(seed_value)
	var m := TacMap.new(int(p.w), int(p.h), int(p.floors))
	m.seed_value = seed_value
	m.algorithm = scene
	m.params = p
	p["scene"] = scene
	var c := {"m": m, "dice": dice, "hints": [], "p": p, "reserved": {}, "overrides": overrides}
	match scene:
		"lone_building": _lone_building(c)
		"street_block": _street_block(c)
		"megablock": _megablock(c)
		"shipyard": _shipyard(c)
		"badlands": _badlands(c)
		"rail_yard": _rail_yard(c)
		"corp_campus": _corp_campus(c)
		_: push_error("unknown scene " + scene)
	for st in m.structures:
		if st.target and m.architectures.has(st.id):
			m.architecture = m.architectures[st.id]
			m.algorithm = st.get("algorithm", scene) if scene == "lone_building" else scene
	return m


# --- Shared building blocks ----------------------------------------------------

static func ground(c: Dictionary, r: Rect2i, g: int) -> void:
	var m: TacMap = c.m
	for y in range(maxi(r.position.y, 0), mini(r.end.y, m.h)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, m.w)):
			m.set_t(0, x, y, TacMap.T.OUTSIDE)
			m.set_ground(x, y, g)


static func water(c: Dictionary, r: Rect2i) -> void:
	var m: TacMap = c.m
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			m.set_t(0, x, y, TacMap.T.WATER)
			m.set_ground(x, y, G.NONE)


static func reserve(c: Dictionary, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			c.reserved[Vector2i(x, y)] = true


## Road with 1-square sidewalks on both long sides; the two middle lanes stay clear of props.
static func road(c: Dictionary, r: Rect2i, horizontal: bool) -> void:
	ground(c, r, G.ASPHALT)
	if horizontal:
		ground(c, Rect2i(r.position.x, r.position.y, r.size.x, 1), G.SIDEWALK)
		ground(c, Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), G.SIDEWALK)
		reserve(c, Rect2i(r.position.x, r.position.y + r.size.y / 2 - 1, r.size.x, 2))
	else:
		ground(c, Rect2i(r.position.x, r.position.y, 1, r.size.y), G.SIDEWALK)
		ground(c, Rect2i(r.end.x - 1, r.position.y, 1, r.size.y), G.SIDEWALK)
		reserve(c, Rect2i(r.position.x + r.size.x / 2 - 1, r.position.y, 2, r.size.y))


static func building(c: Dictionary, shell: Rect2i, site: String, floors: int, security: int, target := false, base_zone := TacMap.Zone.PUBLIC, entry_side := "") -> Dictionary:
	# Only what the caller set explicitly; otherwise each site keeps its own defaults.
	var params: Dictionary = {}
	for k in ["density", "loops", "net_threat", "net_scale"]:
		if c.overrides.has(k):
			params[k] = c.overrides[k]
	for k in ["algorithm", "verticality"]:
		if target and c.overrides.has(k):
			params[k] = c.overrides[k]
	return BuildingGen.build(c.m, c.dice, c.hints, {"shell": shell, "site": site, "floors": floors, "security": security,
		"base_zone": base_zone, "target": target, "entry_side": entry_side, "params": params})


## An outdoor structure (open lot, compound) to own yards, fences and their devices/NET.
static func outdoor_structure(c: Dictionary, kind: String, security: int, rect: Rect2i) -> int:
	var m: TacMap = c.m
	var sid := m.structures.size()
	var params := {"density": 0.35, "net_threat": c.p.get("net_threat", 1.0), "net_scale": c.p.get("net_scale", "")}
	m.structures.append({"id": sid, "kind": kind, "site": kind, "rect": rect, "floors": 1, "security": security,
		"target": false, "base_zone": TacMap.Zone.PUBLIC, "params": params})
	return sid


## Turn the open (OUTSIDE, unlabeled) cells of `r` into a yard room. Returns the room.
static func yard(c: Dictionary, r: Rect2i, kind: String, zone: int, sid: int) -> Dictionary:
	var m: TacMap = c.m
	var id: int = c.hints.size()
	c.hints.append({"zone_hint": zone, "kind": kind, "floor": 0})
	var room := {"id": id, "floor": 0, "zone": zone, "kind": kind, "cells": 0, "bounds": Rect2i(), "structure": sid, "outdoor": true}
	while m.rooms.size() < id:
		m.rooms.append({"id": m.rooms.size(), "floor": -1, "zone": -1, "kind": "void", "cells": 0, "bounds": Rect2i(), "structure": -1})
	m.rooms.append(room)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if m.inb(x, y) and m.t(0, x, y) == TacMap.T.OUTSIDE and m.label(0, x, y) < 0:
				m.labels[0][y * m.w + x] = id
				room.bounds = Rect2i(x, y, 1, 1) if room.cells == 0 else (room.bounds as Rect2i).expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
				room.cells += 1
	return room


## Fence the border of `r` (WALL, fence material) with gates (DOOR) at the given positions.
## Gates into secure yards are security doors.
static func fence(c: Dictionary, r: Rect2i, gates: Array, inside_room: Dictionary, mat := 3) -> void:
	var m: TacMap = c.m
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1:
				if m.t(0, x, y) == TacMap.T.OUTSIDE and not c.reserved.has(Vector2i(x, y)):
					m.set_t(0, x, y, TacMap.T.WALL)
					m.wall_mat[0][y * m.w + x] = mat
					m.labels[0][y * m.w + x] = -1
	for g in gates:
		m.set_t(0, g.x, g.y, TacMap.T.DOOR)
		var sec: bool = inside_room.zone >= TacMap.Zone.SECURE
		m.doors.append({"floor": 0, "pos": g, "a": -1, "b": inside_room.id, "security": sec, "structure": inside_room.structure})
		m.entrances.append({"floor": 0, "pos": g, "main": false, "kind": "gate", "structure": inside_room.structure})
		c.reserved[g] = true


static func spawn(c: Dictionary, pos: Vector2i) -> void:
	c.m.entrances.append({"floor": 0, "pos": pos, "main": false, "kind": "spawn"})


## Scatter multi-cell props over open, unreserved, unlabeled cells of `r`.
static func props(c: Dictionary, r: Rect2i, piece: String, count: int) -> void:
	var m: TacMap = c.m
	var sz: Array = Furnish.PROP_SIZES.get(piece, [1, 1])
	var tries := count * 12
	var placed := 0
	while placed < count and tries > 0:
		tries -= 1
		var fp := Vector2i(sz[0], sz[1]) if c.dice.d(2) == 1 else Vector2i(sz[1], sz[0])
		var pos := Vector2i(c.dice.rng.randi_range(r.position.x, r.end.x - fp.x), c.dice.rng.randi_range(r.position.y, r.end.y - fp.y))
		if Furnish.try_prop(m, 0, Rect2i(pos, fp), piece, m.label(0, pos.x, pos.y), {}, c.reserved):
			placed += 1


## Natural rock outcrops by cellular automata (cave-style smoothing), kept off reserved cells.
## Afterwards any pocket cut off from `anchor` is reconnected by carving a straight passage.
static func rocks(c: Dictionary, r: Rect2i, fill: float, anchor: Vector2i) -> void:
	var m: TacMap = c.m
	var rock := {}
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if m.t(0, x, y) == TacMap.T.OUTSIDE and m.label(0, x, y) < 0 and not c.reserved.has(Vector2i(x, y)) and not m.has_cover_at(0, Vector2i(x, y)) and c.dice.rng.randf() < fill:
				rock[Vector2i(x, y)] = true
	for it in 4:
		var nxt := {}
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var v := Vector2i(x, y)
				if c.reserved.has(v) or m.t(0, x, y) != TacMap.T.OUTSIDE or m.label(0, x, y) >= 0 or m.has_cover_at(0, v):
					continue
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if (dx != 0 or dy != 0) and rock.has(v + Vector2i(dx, dy)):
							n += 1
				if n >= 5 or (rock.has(v) and n >= 4):
					nxt[v] = true
		rock = nxt
	for v in rock:
		m.set_t(0, v.x, v.y, TacMap.T.WALL)
		m.wall_mat[0][v.y * m.w + v.x] = 4
	_reconnect(c, anchor)


## Carve passages so every open outdoor cell connects to `anchor` (removes rock and fence only).
static func _reconnect(c: Dictionary, anchor: Vector2i) -> void:
	var m: TacMap = c.m
	for pass_i in 40:
		var reach := m.reachable(Vector3i(anchor.x, anchor.y, 0))
		var lost := Vector2i(-1, -1)
		for y in m.h:
			for x in m.w:
				if m.t(0, x, y) == TacMap.T.OUTSIDE and not reach.has(Vector3i(x, y, 0)) and not m.has_cover_at(0, Vector2i(x, y)):
					lost = Vector2i(x, y)
					break
			if lost.x >= 0:
				break
		if lost.x < 0:
			return
		# Walk from the lost cell towards the anchor, opening rock until we hit reachable ground.
		var p := lost
		while not reach.has(Vector3i(p.x, p.y, 0)) and p != anchor:
			var step := Vector2i(signi(anchor.x - p.x), 0) if absi(anchor.x - p.x) >= absi(anchor.y - p.y) else Vector2i(0, signi(anchor.y - p.y))
			p += step
			if m.t(0, p.x, p.y) == TacMap.T.WALL and m.wall_mat[0][p.y * m.w + p.x] == 4:
				m.set_t(0, p.x, p.y, TacMap.T.OUTSIDE)
			elif m.t(0, p.x, p.y) in [TacMap.T.WALL, TacMap.T.WATER, TacMap.T.VOID]:
				break


static func _rand_size(c: Dictionary, lo: int, hi: int) -> int:
	return c.dice.rng.randi_range(lo, hi)


# --- Scenes ----------------------------------------------------------------------

## The original: one building on a street corner (street south, alley east).
static func _lone_building(c: Dictionary) -> void:
	var m: TacMap = c.m
	ground(c, Rect2i(0, m.h - 3, m.w, 3), G.ASPHALT)
	ground(c, Rect2i(m.w - 3, 0, 3, m.h), G.GRAVEL)
	building(c, Rect2i(0, 0, m.w - 3, m.h - 3), String(c.p.get("site", "corp_office")), m.floors, int(c.p.security), true, TacMap.Zone.PUBLIC, "S")
	spawn(c, Vector2i(0, m.h - 2))
	spawn(c, Vector2i(m.w - 2, 0))


## City block: two roads, two blocks split into lots by alleys, mixed buildings of different
## heights, one lot left as a parking lot. The target is the biggest lot.
static func _street_block(c: Dictionary) -> void:
	var m: TacMap = c.m
	var road_h := Rect2i(0, m.h - 8, m.w, 8)
	var vx := m.w / 2 - 4 + _rand_size(c, -6, 6)
	road(c, road_h, true)
	road(c, Rect2i(vx, 0, 8, m.h - 8), false)
	var lots: Array[Rect2i] = []
	for block in [Rect2i(0, 0, vx, m.h - 8), Rect2i(vx + 8, 0, m.w - vx - 8, m.h - 8)]:
		ground(c, block, G.SIDEWALK)
		# Alley across the block, then split each half into 1-2 lots.
		var ay: int = block.position.y + block.size.y / 2 + _rand_size(c, -4, 4)
		ground(c, Rect2i(block.position.x, ay, block.size.x, 2), G.GRAVEL)
		for half in [Rect2i(block.position.x, block.position.y, block.size.x, ay - block.position.y), Rect2i(block.position.x, ay + 2, block.size.x, block.end.y - ay - 2)]:
			if half.size.x >= 30 and c.dice.d(3) > 1:
				var cut: int = half.position.x + half.size.x / 2 + _rand_size(c, -5, 5)
				lots.append(Rect2i(half.position.x, half.position.y, cut - half.position.x, half.size.y))
				lots.append(Rect2i(cut, half.position.y, half.end.x - cut, half.size.y))
			else:
				lots.append(half)
	lots.sort_custom(func(a, b): return a.get_area() > b.get_area())
	var others := ["apartments", "club", "shop", "gang_hideout", "warehouse", "apartments", "shop"]
	Layouts._shuffle(c.dice, others)
	var lot_sid := -1
	for i in lots.size():
		var shell := lots[i].grow(-1)
		if shell.size.x < 7 or shell.size.y < 7:
			continue
		if i == lots.size() - 1 and lots.size() >= 4:
			lot_sid = outdoor_structure(c, "lot", 0, lots[i])
			var lot := yard(c, lots[i], "parking_lot", TacMap.Zone.PUBLIC, lot_sid)
			Furnish.run_structure(m, c.dice, lot_sid)
			continue
		var target := i == 0
		var site: String = String(c.p.get("site", "corp_office")) if target else others[i % others.size()]
		var floors: int = m.floors if target else c.dice.rng.randi_range(1, m.floors)
		building(c, shell, site, floors, int(c.p.security) if target else c.dice.rng.randi_range(0, 1), target)
	# Street life: parked cars along the curbs, dumpsters in the alleys.
	props(c, Rect2i(0, road_h.position.y + 1, m.w, 2), "car", m.w / 10)
	props(c, Rect2i(0, road_h.end.y - 3, m.w, 2), "car", m.w / 12)
	props(c, Rect2i(vx + 1, 0, 2, m.h - 8), "car", m.h / 14)
	for y in m.h:
		for x in m.w:
			if m.ground[y * m.w + x] == G.GRAVEL and c.dice.rng.randf() < 0.012:
				Furnish.try_prop(m, 0, Rect2i(x, y, 1, 1), "dumpster", -1, {}, c.reserved)
	spawn(c, Vector2i(0, m.h - 4))
	spawn(c, Vector2i(m.w - 1, m.h - 4))
	spawn(c, Vector2i(vx + 4, 0))


## Megablock: a long apartment tower over a courtyard, with a parking lot and a corner shop.
static func _megablock(c: Dictionary) -> void:
	var m: TacMap = c.m
	road(c, Rect2i(0, m.h - 7, m.w, 7), true)
	road(c, Rect2i(m.w - 7, 0, 7, m.h - 7), false)
	ground(c, Rect2i(0, 0, m.w - 7, m.h - 7), G.CONCRETE)
	var tower := Rect2i(2, 2, m.w - 13, m.h / 2 - 2)
	building(c, tower, "apartments", m.floors, int(c.p.security), true, TacMap.Zone.PUBLIC, "S")
	var shop := Rect2i(2, m.h - 7 - 12, 14, 11)
	building(c, shop, "shop", 1, 0)
	var sid := outdoor_structure(c, "courtyard", 0, Rect2i(0, tower.end.y, m.w - 7, m.h - 7 - tower.end.y))
	ground(c, Rect2i(18, tower.end.y + 1, m.w - 7 - 18 - 20, m.h - 7 - tower.end.y - 2), G.GRASS)
	yard(c, Rect2i(18, tower.end.y + 1, m.w - 7 - 18 - 20, m.h - 7 - tower.end.y - 2), "courtyard", TacMap.Zone.PUBLIC, sid)
	yard(c, Rect2i(m.w - 27, tower.end.y + 1, 19, m.h - 7 - tower.end.y - 2), "parking_lot", TacMap.Zone.PUBLIC, sid)
	Furnish.run_structure(m, c.dice, sid)
	props(c, Rect2i(0, m.h - 6, m.w - 7, 2), "car", m.w / 12)
	spawn(c, Vector2i(0, m.h - 3))
	spawn(c, Vector2i(m.w - 4, 0))


## Shipyard: a cargo ship moored at the quay (boarded over a gangway), cranes on the quay, a
## fenced container yard with lanes, a warehouse and a gate booth on the road.
static func _shipyard(c: Dictionary) -> void:
	var m: TacMap = c.m
	var sec := int(c.p.security)
	var sea_h := 15
	water(c, Rect2i(0, 0, m.w, sea_h))
	var road_y := m.h - 6
	road(c, Rect2i(0, road_y, m.w, 6), true)
	ground(c, Rect2i(0, sea_h, m.w, road_y - sea_h), G.CONCRETE)
	ground(c, Rect2i(0, sea_h, m.w, 6), G.DOCK)
	# Ship + gangway onto the quay.
	var ship := Rect2i(14, 3, m.w - 30, 11)
	var gx := ship.position.x + ship.size.x / 3
	ground(c, Rect2i(gx, ship.end.y, 2, sea_h - ship.end.y), G.DOCK)
	reserve(c, Rect2i(gx - 1, ship.end.y, 4, sea_h - ship.end.y + 2))
	building(c, ship, "ship", m.floors, sec, true, TacMap.Zone.STAFF, "S")
	# Compound: everything between quay and road, fenced with one gate.
	var comp := Rect2i(0, sea_h, m.w, road_y - sea_h)
	var sid := outdoor_structure(c, "compound", maxi(sec - 1, 0), comp)
	var gate := Vector2i(m.w / 2, road_y - 1)
	reserve(c, Rect2i(gate.x - 1, gate.y - 3, 3, 4))
	var wh := Rect2i(m.w - 30, sea_h + 9, 26, road_y - sea_h - 13)
	building(c, wh, "warehouse", 1, maxi(sec - 1, 0), false, TacMap.Zone.STAFF)
	var booth := Rect2i(gate.x + 3, road_y - 7, 6, 5)
	building(c, booth, "guard_booth", 1, maxi(sec - 1, 0), false, TacMap.Zone.STAFF)
	# Cranes on the quay: pairs of steel legs.
	for k in 3:
		var cx := 8 + k * (m.w - 20) / 3
		for leg in [Vector2i(cx, sea_h + 1), Vector2i(cx, sea_h + 4), Vector2i(cx + 5, sea_h + 1), Vector2i(cx + 5, sea_h + 4)]:
			if not c.reserved.has(leg):
				m.add_cover(Furnish.cover_entry("crane_leg", 0, leg, -1))
	# Container stacks: 2 × 6 blocks in a grid, 2-square lanes between them.
	var yard_r := Rect2i(3, sea_h + 8, wh.position.x - 6, road_y - sea_h - 11)
	for by in range(yard_r.position.y, yard_r.end.y - 2, 5):
		for bx in range(yard_r.position.x, yard_r.end.x - 6, 9):
			if c.dice.rng.randf() < 0.8:
				for dy in 2:
					for dx in 6:
						var v := Vector2i(bx + dx, by + dy)
						if m.t(0, v.x, v.y) == TacMap.T.OUTSIDE and not c.reserved.has(v) and not m.has_cover_at(0, v):
							m.add_cover(Furnish.cover_entry("container", 0, v, -1, bx * 1000 + by))
	var quay := yard(c, Rect2i(0, sea_h, m.w, 6), "quay", TacMap.Zone.STAFF, sid)
	yard(c, Rect2i(1, sea_h + 6, m.w - 2, road_y - sea_h - 7), "container_yard", TacMap.Zone.STAFF, sid)
	fence(c, Rect2i(-1, sea_h - 1, m.w + 2, road_y - sea_h + 1), [gate], quay, 3)
	m.doors[-1].b = m.label(0, gate.x, gate.y - 1)
	Furnish.run_structure(m, c.dice, sid)
	if m.devices.any(func(d): return d.structure == sid):
		m.architectures[sid] = NetGen.generate(m, c.dice, sid)
	spawn(c, Vector2i(0, m.h - 3))
	spawn(c, Vector2i(m.w - 1, m.h - 3))


## Badlands: open desert with rock outcrops, a dry riverbed, a winding dirt road, wrecks, and a
## fenced raider camp of shacks around a main hideout.
static func _badlands(c: Dictionary) -> void:
	var m: TacMap = c.m
	var sec := int(c.p.security)
	ground(c, Rect2i(0, 0, m.w, m.h), G.SAND)
	# Winding road west → east.
	var y := m.h / 2 + 10
	for x in m.w:
		if x % 6 == 0:
			y = clampi(y + c.dice.rng.randi_range(-1, 1), m.h / 2, m.h - 6)
		ground(c, Rect2i(x, y, 1, 3), G.DIRT)
		reserve(c, Rect2i(x, y, 1, 3))
	# Dry riverbed north → south.
	var rx := m.w / 4
	for yy in m.h:
		if yy % 5 == 0:
			rx = clampi(rx + c.dice.rng.randi_range(-2, 2), 6, m.w / 2)
		ground(c, Rect2i(rx, yy, 4, 1), G.GRAVEL)
	# Raider camp.
	var camp := Rect2i(m.w - 46, 6, 40, 30)
	var sid := outdoor_structure(c, "compound", sec, camp)
	var gate := Vector2i(camp.position.x + camp.size.x / 2, camp.end.y - 1)
	reserve(c, Rect2i(camp.position.x - 1, camp.position.y - 1, camp.size.x + 2, camp.size.y + 2))
	for xx in range(gate.x - 1, gate.x + 2):
		for yy in range(gate.y, y + 1):
			ground(c, Rect2i(xx, yy, 1, 1), G.DIRT)
			reserve(c, Rect2i(xx, yy, 1, 1))
	var inner := camp.grow(-2)
	building(c, Rect2i(inner.position.x + inner.size.x / 2 - 9, inner.position.y, 18, 12), "gang_hideout", 1, sec, true, TacMap.Zone.STAFF)
	var placed: Array[Rect2i] = [Rect2i(inner.position.x + inner.size.x / 2 - 11, inner.position.y, 22, 14)]
	for k in 60:
		if placed.size() >= 6:
			break
		var s := Rect2i(c.dice.rng.randi_range(inner.position.x, inner.end.x - 8), c.dice.rng.randi_range(inner.position.y, inner.end.y - 9),
			_rand_size(c, 6, 8), _rand_size(c, 5, 7))
		if placed.all(func(o): return not o.grow(2).intersects(s)) and inner.encloses(s) and s.position.y + s.size.y < gate.y - 3:
			building(c, s, "shack", 1, sec, false, TacMap.Zone.STAFF)
			placed.append(s)
	var yard_room := yard(c, camp.grow(-1), "compound_yard", TacMap.Zone.STAFF, sid)
	fence(c, camp, [gate], yard_room, 3)
	Furnish.run_structure(m, c.dice, sid)
	if m.devices.any(func(d): return d.structure == sid):
		m.architectures[sid] = NetGen.generate(m, c.dice, sid)
	# Wrecks and boulders out in the open, then the rock outcrops.
	props(c, Rect2i(0, 0, m.w, m.h), "wreck", m.w * m.h / 900)
	for k in m.w * m.h / 250:
		var v := Vector2i(c.dice.rng.randi_range(0, m.w - 1), c.dice.rng.randi_range(0, m.h - 1))
		Furnish.try_prop(m, 0, Rect2i(v, Vector2i.ONE), "boulder", -1, {}, c.reserved)
	var anchor := Vector2i(0, _road_y_at(c, 0))
	rocks(c, Rect2i(0, 0, m.w, m.h), 0.42, anchor)
	spawn(c, anchor)
	spawn(c, Vector2i(m.w - 1, _road_y_at(c, m.w - 1)))


static func _road_y_at(c: Dictionary, x: int) -> int:
	var m: TacMap = c.m
	for yy in m.h:
		if m.ground[yy * m.w + x] == G.DIRT and c.reserved.has(Vector2i(x, yy)):
			return yy + 1
	return m.h / 2


## Rail yard: parallel tracks with a stopped train you can board, freight cars as long cover on
## the other tracks, a platform and a two-storey station.
static func _rail_yard(c: Dictionary) -> void:
	var m: TacMap = c.m
	var sec := int(c.p.security)
	ground(c, Rect2i(0, 0, m.w, m.h), G.GRAVEL)
	var tracks := [4, 11, 18, 25]
	for ty in tracks:
		ground(c, Rect2i(0, ty, m.w, 2), G.RAIL)
	var train := Rect2i(6, tracks[2] - 2, m.w - 12, 5)
	building(c, train, "train", 1, sec, true, TacMap.Zone.PUBLIC, "S")
	# Freight cars on the other tracks, with gaps to slip between.
	for ty in [tracks[0], tracks[1], tracks[3]]:
		var x: int = c.dice.rng.randi_range(0, 6)
		while x < m.w - 8:
			if c.dice.rng.randf() < 0.75:
				Furnish.try_prop(m, 0, Rect2i(x, ty, 7, 2), "freight_car", -1, {}, c.reserved)
			x += 8 + c.dice.rng.randi_range(0, 4)
	var plat_y: int = tracks[3] + 4
	var sid := outdoor_structure(c, "station_grounds", maxi(sec - 1, 0), Rect2i(0, plat_y, m.w, m.h - plat_y))
	ground(c, Rect2i(0, plat_y, m.w, 6), G.CONCRETE)
	var station := Rect2i(m.w / 2 - 22, plat_y + 8, 44, m.h - plat_y - 10)
	ground(c, Rect2i(0, plat_y + 6, m.w, m.h - plat_y - 6), G.SIDEWALK)
	building(c, station, "station", m.floors, maxi(sec - 1, 0), false, TacMap.Zone.PUBLIC, "N")
	yard(c, Rect2i(0, plat_y, m.w, 6), "platform", TacMap.Zone.PUBLIC, sid)
	Furnish.run_structure(m, c.dice, sid)
	spawn(c, Vector2i(0, plat_y + 7))
	spawn(c, Vector2i(m.w - 1, plat_y + 7))
	spawn(c, Vector2i(0, tracks[0]))


## Corporate campus: fenced grounds with a gate booth, parking, a plaza and the HQ tower, plus a
## service building. Gate and HQ lobby are public; security deepens inside the HQ.
static func _corp_campus(c: Dictionary) -> void:
	var m: TacMap = c.m
	var sec := int(c.p.security)
	road(c, Rect2i(0, m.h - 7, m.w, 7), true)
	var grounds := Rect2i(3, 3, m.w - 6, m.h - 11)
	ground(c, Rect2i(0, 0, m.w, m.h - 7), G.GRASS)
	ground(c, grounds, G.CONCRETE)
	var sid := outdoor_structure(c, "campus", maxi(sec - 1, 0), grounds)
	var gate := Vector2i(m.w / 2, grounds.end.y - 1)
	for yy in range(gate.y, m.h - 6):
		ground(c, Rect2i(gate.x - 1, yy, 3, 1), G.ASPHALT)
		reserve(c, Rect2i(gate.x - 1, yy, 3, 1))
	reserve(c, Rect2i(gate.x - 1, gate.y - 4, 3, 5))
	var hq := Rect2i(grounds.position.x + 10, grounds.position.y + 3, grounds.size.x - 20, grounds.size.y / 2 - 2)
	building(c, hq, "corp_hq", m.floors, sec, true, TacMap.Zone.PUBLIC, "S")
	var svc := Rect2i(grounds.end.x - 16, hq.end.y + 4, 13, 12)
	building(c, svc, "warehouse", 1, maxi(sec - 1, 0), false, TacMap.Zone.PUBLIC)
	var booth := Rect2i(gate.x + 3, grounds.end.y - 7, 6, 5)
	building(c, booth, "guard_booth", 1, maxi(sec - 1, 0), false, TacMap.Zone.PUBLIC)
	var plaza := yard(c, Rect2i(hq.position.x, hq.end.y, hq.size.x, 6), "plaza", TacMap.Zone.PUBLIC, sid)
	var park := yard(c, Rect2i(grounds.position.x + 1, hq.end.y + 6, svc.position.x - grounds.position.x - 3, grounds.end.y - hq.end.y - 7), "parking_lot", TacMap.Zone.PUBLIC, sid)
	yard(c, grounds.grow(-1), "courtyard", TacMap.Zone.PUBLIC, sid)
	fence(c, grounds, [gate], park, 3)
	m.doors[-1].b = m.label(0, gate.x, gate.y - 1)
	Furnish.run_structure(m, c.dice, sid)
	if m.devices.any(func(d): return d.structure == sid):
		m.architectures[sid] = NetGen.generate(m, c.dice, sid)
	props(c, Rect2i(0, m.h - 6, m.w, 2), "car", m.w / 14)
	spawn(c, Vector2i(0, m.h - 3))
	spawn(c, Vector2i(m.w - 1, m.h - 3))
