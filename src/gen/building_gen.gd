class_name BuildingGen
extends RefCounted
## Fills one building plot of a scene: per-floor room layout (Layouts) → walls → stair/elevator
## shafts → facade entrance → doors + security zones → wall materials → room kinds → furnishing →
## the building's own NET. Scoped to `shell`, so a scene can hold many buildings.
##
## Security gradient: rooms are joined by a Prim-style tree from the entrance where each step can
## raise the zone by at most one, starting from the plot's base zone (public for street-facing
## buildings, deeper for buildings inside a fenced compound).

const MIN_ROOM_CELLS := 4
const DIAG: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]


## ctx: {shell: Rect2i, site, floors, security, base_zone, target: bool, entry_side ("" = any),
##       params (density, loops, verticality, algorithm override, net_scale, net_threat),
##       setpiece + part (a set piece's building: SetPieces.site_def puts its keys over the site's)}
## `hints` is the scene-wide room hint list (index = global room id). Returns the structure dict.
static func build(m: TacMap, dice: Dice, hints: Array, ctx: Dictionary) -> Dictionary:
	var sdef: Dictionary = SetPieces.site_def(String(ctx.site), String(ctx.get("setpiece", "")), String(ctx.get("part", "")))
	var p: Dictionary = MapGen.DEFAULTS.duplicate()
	p.merge(sdef["layout"], true)
	p.merge(ctx.get("params", {}), true)
	p["security"] = int(ctx.get("security", 1))
	p["levels"] = int(sdef.get("levels", 4))
	if float(p.get("density", -1.0)) < 0.0:
		p.density = float(sdef["density"])
	var floors := mini(int(ctx.get("floors", 1)), m.floors)
	var shell: Rect2i = ctx.shell
	var inner := shell.grow(-1)
	var fp := Footprint.make(shell, ctx.get("mask", {}))
	fp.hole = ctx.get("courtyard", Rect2i())
	var sid := m.structures.size()
	var st := {"id": sid, "kind": "building", "site": ctx.site, "rect": shell, "floors": floors,
		"security": p.security, "target": ctx.get("target", false), "base_zone": int(ctx.get("base_zone", TacMap.Zone.PUBLIC)),
		"params": p, "algorithm": p.algorithm,
		"max_zone": maxi(mini(MapGen.max_zone(int(p.security)), int(ctx.get("base_zone", TacMap.Zone.PUBLIC)) + int(p.levels) - 1), int(ctx.get("base_zone", TacMap.Zone.PUBLIC)))}
	if String(ctx.get("setpiece", "")) != "":
		st["setpiece"] = String(ctx.setpiece)
		st["part"] = String(ctx.get("part", ""))
		st["name"] = String(sdef.get("name", ctx.site))
	m.structures.append(st)

	var fps := _massing(dice, fp, floors, sdef.get("massing", {}))   # each floor's footprint (setbacks)
	var first_id := hints.size()
	var entry_side := String(ctx.get("entry_side", ""))
	if p.algorithm == "program":
		# A programmed building is planned from its entrance facade inwards, so fix that side first.
		if entry_side == "":
			entry_side = _open_side(m, shell)
		p["entry_side"] = entry_side
		p["floors"] = floors
		p["plan"] = Layouts.program_plan(dice, inner, p)
		_keep(fps, fp, inner, p, floors)
	for f in floors:
		var local := PackedInt32Array()
		local.resize(m.w * m.h)
		local.fill(-1)
		p["floor"] = f
		var room_hints := Layouts.run(p.algorithm, dice, m.w, inner, local, p)
		for y in range(inner.position.y, inner.end.y):
			for x in range(inner.position.x, inner.end.x):
				if not (fps[f] as Footprint).interior(Vector2i(x, y)):
					local[y * m.w + x] = -1
		_split_components(m, f, local, inner, room_hints, hints)
		_walls(m, f, fps[f])
		_fix_fragments(m, f, fps[f], hints)
	_index_rooms(m, shell, floors, first_id, hints.size(), sid)
	for i in range(first_id, hints.size()):
		m.rooms[i]["layout_kind"] = hints[i].get("kind", "")
		if hints[i].has("room"):   # a programmed room: its kind, the rooms it opens onto, its facade side
			m.rooms[i]["program_kind"] = hints[i].room
			m.rooms[i]["program_doors"] = hints[i].doors
			m.rooms[i]["glass"] = hints[i].glass
			m.rooms[i]["front"] = hints[i].front
	_verticals(m, dice, shell, floors, int(p.verticality), sid, p.get("stair_in", []), int(p.get("stairs", 1)), p.get("lift_in", []))
	var door := _main_door(m, dice, fp, entry_side, sdef.get("enter_corridor", false), p.get("enter", []))
	if door.is_empty():
		push_warning("BuildingGen: no facade faces open ground for %s at %s" % [ctx.site, shell])
		return st
	var root: int = door.room
	_connect(m, dice, hints, p, first_id, root, int(st.base_zone))
	_place_main_door(m, door, sid, bool(st.target))
	_service_door(m, dice, fp, door.side, sid, int(st.base_zone), p.get("service", []))
	_wall_materials(m, fps, floors, int(sdef.get("exterior", 1)))
	_glass_fronts(m, first_id)
	_room_kinds(m, sdef["zones"], first_id, root)
	_terraces(m, hints, fps, floors, sid)
	_roof(m, dice, hints, fps[floors - 1], floors, sid, int(st.base_zone), String(ctx.site), bool(p.get("roof_access", false)))
	_windows(m, dice, fps, floors, float(sdef.get("windows", 0.5)), bool(sdef.get("armored_windows", false)), sdef.get("room_windows", []))
	if not (sdef.get("room_windows", []) as Array).is_empty():
		st["punched_windows"] = true   # the viewer draws its single-square windows as punched openings
	var cy: Rect2i = ctx.get("courtyard", Rect2i())
	if cy.has_area():
		_courtyard(m, dice, hints, fp, cy, sid)
	var decay := float(p.get("decay", sdef.get("decay", 0.0)))
	if decay > 0.0:
		_decay(m, dice, fps, floors, decay)
	Furnish.run_structure(m, dice, sid)
	# M2d review: NETs only where they matter — always for the target, otherwise by site type.
	var wants_net: bool = sdef.get("networked", true) and (st.target or dice.rng.randf() < float(sdef.get("net_chance", 1.0)))
	if wants_net and m.devices.any(func(d): return d.structure == sid):
		m.architectures[sid] = NetGen.generate(m, dice, sid)
	return st


static func structure_rooms(m: TacMap, sid: int) -> Array:
	return m.rooms.filter(func(r): return r.cells > 0 and r.get("structure", -1) == sid)


## Re-label each layout room by connected component (corridors can cut rooms in two), merging
## slivers into a neighbour. New ids continue the scene-wide `hints` list.
static func _split_components(m: TacMap, f: int, local: PackedInt32Array, inner: Rect2i, room_hints: Array, hints: Array) -> void:
	var seen := {}
	var first := hints.size()
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			var l := local[y * m.w + x]
			if l < 0 or seen.has(Vector2i(x, y)):
				continue
			var comp: Array[Vector2i] = []
			var q: Array[Vector2i] = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not q.is_empty():
				var c: Vector2i = q.pop_back()
				comp.append(c)
				for d in MapGen.DIRS:
					var n := c + d
					if inner.has_point(n) and not seen.has(n) and local[n.y * m.w + n.x] == l:
						seen[n] = true
						q.append(n)
			var gid := hints.size()
			var h: Dictionary = room_hints[l].duplicate() if l < room_hints.size() else {"zone_hint": -1, "kind": ""}
			h["floor"] = f
			hints.append(h)
			for c in comp:
				m.labels[f][c.y * m.w + c.x] = gid
	var counts := {}
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			var l := m.labels[f][y * m.w + x]
			if l >= first:
				counts[l] = counts.get(l, 0) + 1
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			var gid := m.labels[f][y * m.w + x]
			if gid < first or counts.get(gid, 0) >= MIN_ROOM_CELLS:
				continue
			for d in MapGen.DIRS:
				var n := m.label(f, x + d.x, y + d.y)
				if n >= first and n != gid and inner.has_point(Vector2i(x + d.x, y + d.y)):
					counts[n] = counts.get(n, 0) + counts[gid]
					counts[gid] = 0
					for yy in range(inner.position.y, inner.end.y):
						for xx in range(inner.position.x, inner.end.x):
							if m.labels[f][yy * m.w + xx] == gid:
								m.labels[f][yy * m.w + xx] = n
					break


## Exterior ring of the footprint is wall; inside, a cell becomes wall if its east or south
## neighbour belongs to a different room (1-cell walls without eating both sides).
static func _walls(m: TacMap, f: int, fp: Footprint) -> void:
	var shell := fp.shell
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			var v := Vector2i(x, y)
			if not fp.has(v):
				continue
			if not fp.interior(v):
				m.set_t(f, x, y, TacMap.T.WALL)
				m.labels[f][y * m.w + x] = -1
				continue
			var l := m.label(f, x, y)
			var wall := false
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				var n: Vector2i = v + d
				if fp.interior(n) and m.label(f, n.x, n.y) != l:
					wall = true
			m.set_t(f, x, y, TacMap.T.WALL if wall else TacMap.T.FLOOR)
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			if fp.has(Vector2i(x, y)) and m.t(f, x, y) == TacMap.T.WALL:
				m.labels[f][y * m.w + x] = -1


static func _index_rooms(m: TacMap, shell: Rect2i, floors: int, first: int, end_id: int, sid: int) -> void:
	while m.rooms.size() < end_id:
		var i := m.rooms.size()
		m.rooms.append({"id": i, "floor": -1, "zone": -1, "kind": "void", "cells": 0, "bounds": Rect2i(), "structure": sid})
	for f in floors:
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				var l := m.label(f, x, y)
				if l < first:
					continue
				var r: Dictionary = m.rooms[l]
				if r.cells == 0:
					r.floor = f
					r.kind = ""
					r.bounds = Rect2i(x, y, 1, 1)
				r.cells += 1
				r.bounds = (r.bounds as Rect2i).expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))


## Stair shaft through all of the building's floors (and an elevator at verticality 2).
## `prefer`: room kinds (a program's stair halls) the shafts go in, on every floor; elevators go
## nowhere else (`lift`, if given, narrows that to the lift lobby). `stairs`: how many stair shafts
## (2 = a second, separate stair at the other end: two means of escape).
static func _verticals(m: TacMap, dice: Dice, shell: Rect2i, floors: int, verticality: int, sid: int, prefer: Array = [], stairs := 1, lift: Array = []) -> void:
	if floors < 2:
		return
	var kinds := [TacMap.T.STAIRS]
	for i in stairs - 1:
		kinds.append(TacMap.T.STAIRS)
	if verticality >= 2:
		kinds.append(TacMap.T.ELEVATOR)
	var used := {}   # ground-floor rooms that already hold a stair shaft
	for kind in kinds:
		var candidates: Array[Vector2i] = []
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				var ok := true
				for f in floors:
					if m.t(f, x, y) != TacMap.T.FLOOR:
						ok = false
						break
					for d in MapGen.DIRS:
						if m.t(f, x + d.x, y + d.y) != TacMap.T.FLOOR:
							ok = false
				if ok:
					candidates.append(Vector2i(x, y))
		if not prefer.is_empty():
			var want: Array = lift if kind == TacMap.T.ELEVATOR and not lift.is_empty() else prefer
			var inside := candidates.filter(func(v): return _in_kinds(m, v, floors, want) \
				and not (kind == TacMap.T.STAIRS and used.has(m.label(0, v.x, v.y))))
			if not inside.is_empty() or kind == TacMap.T.ELEVATOR:
				candidates.assign(inside)
			elif not used.is_empty():
				continue   # the extra stair needs a stair hall of its own
		if candidates.is_empty() and kind == TacMap.T.STAIRS and used.is_empty():
			# small or stepped upper floors: any square that is floor on every storey, else force one
			candidates = _forced_shaft(m, shell, floors)
		if candidates.is_empty():
			continue
		var c := shell.get_center()
		candidates.sort_custom(func(a, b): return a.distance_squared_to(c) < b.distance_squared_to(c))
		var pos: Vector2i = candidates[dice.rng.randi_range(0, mini(8, candidates.size() - 1))]
		if kind == TacMap.T.STAIRS:
			used[m.label(0, pos.x, pos.y)] = true
		for f in floors:
			m.set_t(f, pos.x, pos.y, kind)
		m.verticals.append({"type": "stairs" if kind == TacMap.T.STAIRS else "elevator", "pos": pos, "from_floor": 0, "to_floor": floors - 1, "structure": sid})


## Every storey's room at `v` is one of `kinds` (by program kind).
static func _in_kinds(m: TacMap, v: Vector2i, floors: int, kinds: Array) -> bool:
	for f in floors:
		var l := m.label(f, v.x, v.y)
		if l < 0 or not (String(m.rooms[l].get("program_kind", "")) in kinds):
			return false
	return true


## The side of a plot facing the most open ground (a programmed building's entrance facade).
static func _open_side(m: TacMap, shell: Rect2i) -> String:
	var best := "S"
	var best_n := -1
	for side in ["S", "E", "W", "N"]:
		var d: Vector2i = SIDES[side]
		var n := 0
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				var v := Vector2i(x, y)
				if not shell.has_point(v + d) and m.t(0, v.x + d.x, v.y + d.y) == TacMap.T.OUTSIDE:
					n += 1
		if n > best_n:
			best_n = n
			best = side
	return best


## Fallback stair spots: squares that are floor on every storey (no clearance asked); failing that,
## the squares nearest the middle that are inside on every storey, opened up (a wall square there
## joins the room beside it).
static func _forced_shaft(m: TacMap, shell: Rect2i, floors: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var inside: Array[Vector2i] = []
	for y in range(shell.position.y + 1, shell.end.y - 1):
		for x in range(shell.position.x + 1, shell.end.x - 1):
			var all_floor := true
			var all_in := true
			for f in floors:
				var t := m.t(f, x, y)
				if t != TacMap.T.FLOOR:
					all_floor = false
				if not (t in [TacMap.T.FLOOR, TacMap.T.WALL]) or not _enclosed(m, f, Vector2i(x, y)):
					all_in = false
			if all_floor:
				out.append(Vector2i(x, y))
			elif all_in:
				inside.append(Vector2i(x, y))
	if not out.is_empty() or inside.is_empty():
		return out
	var c := shell.get_center()
	inside.sort_custom(func(a, b): return a.distance_squared_to(c) < b.distance_squared_to(c))
	var v: Vector2i = inside[0]
	for f in floors:
		if m.t(f, v.x, v.y) == TacMap.T.WALL:
			for d in MapGen.DIRS:
				if m.t(f, v.x + d.x, v.y + d.y) == TacMap.T.FLOOR and m.label(f, v.x + d.x, v.y + d.y) >= 0:
					m.set_t(f, v.x, v.y, TacMap.T.FLOOR)
					m.labels[f][v.y * m.w + v.x] = m.label(f, v.x + d.x, v.y + d.y)
					break
	if range(floors).all(func(f): return m.t(f, v.x, v.y) == TacMap.T.FLOOR):
		out.append(v)
	return out


## A square with this storey's floor or walls all round (not on the outer wall line).
static func _enclosed(m: TacMap, f: int, v: Vector2i) -> bool:
	for d in MapGen.DIRS:
		if not (m.t(f, v.x + d.x, v.y + d.y) in [TacMap.T.FLOOR, TacMap.T.WALL]):
			return false
	return m.label(f, v.x, v.y) >= 0 or m.t(f, v.x, v.y) == TacMap.T.WALL


## Facade door candidates: exterior wall cells (not corners) with a room inside and open ground
## outside. Returns {side, pos, room} for the best one, preferring `side` when given.
static func _main_door(m: TacMap, dice: Dice, fp: Footprint, side: String, prefer_corridor: bool, enter: Array = []) -> Dictionary:
	var by_side := _facade_candidates(m, fp)
	var order := ["S", "E", "W", "N"]
	order.sort_custom(func(a, b): return by_side[a].size() > by_side[b].size())
	if side != "" and not by_side[side].is_empty():
		order.erase(side)
		order.push_front(side)
	for s in order:
		var list: Array = by_side[s]
		if list.is_empty():
			continue
		if not enter.is_empty():   # a programmed building: the door opens into its public front room
			var front := list.filter(func(c): return String(m.rooms[c.room].get("program_kind", "")) in enter)
			if not front.is_empty():
				list = front
		if prefer_corridor:
			var corr := list.filter(func(c): return m.rooms[c.room].get("layout_kind", "") == "corridor")
			if not corr.is_empty():
				list = corr
		var pick: Dictionary = list[clampi(list.size() / 2 + dice.rng.randi_range(-2, 2), 0, list.size() - 1)]
		pick["side"] = s
		return pick
	return {}


const SIDES := {"N": Vector2i.UP, "S": Vector2i.DOWN, "E": Vector2i.RIGHT, "W": Vector2i.LEFT}


## Facade spots: straight stretches of exterior wall with a room inside and open ground outside,
## grouped by the side they face.
static func _facade_candidates(m: TacMap, fp: Footprint, into_hole := false) -> Dictionary:
	var out := {"N": [], "S": [], "E": [], "W": []}
	var shell := fp.shell
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			var v := Vector2i(x, y)
			if not fp.exterior(v) or m.t(0, x, y) != TacMap.T.WALL:
				continue
			for side in SIDES:
				var d: Vector2i = SIDES[side]
				var outside := v + d
				var inside := v - d
				var perp := Vector2i(d.y, d.x)
				if fp.has(outside) or not fp.interior(inside) or not fp.exterior(v + perp) or not fp.exterior(v - perp):
					continue
				if fp.hole.has_area() and fp.hole.has_point(outside) != into_hole:
					continue
				var l := m.label(0, inside.x, inside.y)
				if l >= 0 and m.t(0, inside.x, inside.y) == TacMap.T.FLOOR and m.t(0, outside.x, outside.y) == TacMap.T.OUTSIDE \
						and not m.has_cover_at(0, outside):
					out[side].append({"pos": v, "room": l})
	return out


static func _place_main_door(m: TacMap, door: Dictionary, sid: int, target: bool) -> void:
	m.set_t(0, door.pos.x, door.pos.y, TacMap.T.DOOR)
	m.doors.append({"floor": 0, "pos": door.pos, "a": -1, "b": door.room, "security": false, "structure": sid})
	m.entrances.append({"floor": 0, "pos": door.pos, "main": target, "kind": "door", "structure": sid})


## A second door on another side, into a staff room. `service`: a program's back-of-house rooms that
## take deliveries (stores, kitchens): the door goes into one of those, and always exists.
static func _service_door(m: TacMap, dice: Dice, fp: Footprint, main_side: String, sid: int, base_zone: int, service: Array = []) -> void:
	var by_side := _facade_candidates(m, fp)
	var best: Dictionary = {}
	var goods := []
	for s in by_side:
		if s == main_side:
			continue
		for c in by_side[s]:
			var z: int = m.rooms[c.room].zone
			if z >= 0 and z <= base_zone + 1 and (best.is_empty() or z > best.zone):
				best = {"pos": c.pos, "room": c.room, "zone": z}
			if z >= 0 and z <= base_zone + 1 and String(m.rooms[c.room].get("program_kind", "")) in service:
				goods.append({"pos": c.pos, "room": c.room, "zone": z})
	if not goods.is_empty():
		best = goods[dice.rng.randi_range(0, goods.size() - 1)]
	elif best.is_empty() or dice.rng.randf() < 0.2:
		return
	m.set_t(0, best.pos.x, best.pos.y, TacMap.T.DOOR)
	m.doors.append({"floor": 0, "pos": best.pos, "a": -1, "b": best.room, "security": false, "structure": sid})
	m.entrances.append({"floor": 0, "pos": best.pos, "main": false, "kind": "door", "structure": sid})


## Door candidates between two of this building's rooms (ids ≥ first).
static func _shell_of(m: TacMap, first: int) -> Rect2i:
	return m.structures[m.rooms[first].structure].rect


static func _door_candidates(m: TacMap, first: int, shell: Rect2i) -> Dictionary:
	var out := {}
	for f in m.floors:
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				if m.t(f, x, y) != TacMap.T.WALL:
					continue
				for axis in [[Vector2i.LEFT, Vector2i.RIGHT], [Vector2i.UP, Vector2i.DOWN]]:
					var p1: Vector2i = Vector2i(x, y) + axis[0]
					var p2: Vector2i = Vector2i(x, y) + axis[1]
					var a := m.label(f, p1.x, p1.y)
					var b := m.label(f, p2.x, p2.y)
					if a >= first and b >= first and a != b and m.t(f, p1.x, p1.y) == TacMap.T.FLOOR and m.t(f, p2.x, p2.y) == TacMap.T.FLOOR:
						out.get_or_add(Vector2i(mini(a, b), maxi(a, b)), []).append([f, Vector2i(x, y)])
	return out


static func _connect(m: TacMap, dice: Dice, hints: Array, p: Dictionary, first: int, root: int, base_zone: int) -> void:
	var cands := _door_candidates(m, first, _shell_of(m, first))
	var adj := {}
	for key in cands:
		adj.get_or_add(key.x, []).append(key.y)
		adj.get_or_add(key.y, []).append(key.x)
	var mz := maxi(mini(MapGen.max_zone(int(p.security)), base_zone + int(p.get("levels", 4)) - 1), base_zone)
	var shafts := _shaft_rooms(m, first)

	# Depth-derived hints for rooms whose layout gave none: rank by BFS depth from the entrance and
	# hand out zones by cumulative floor area, using the treemap zone shares.
	var depth := {root: 0}
	var q := [root]
	while not q.is_empty():
		var r: int = q.pop_front()
		var nexts: Array = adj.get(r, []).duplicate()
		for s in shafts:
			if r in s:
				nexts.append_array(s)
		for n in nexts:
			if not depth.has(n):
				depth[n] = depth[r] + 1
				q.append(n)
	var shares: Array = Layouts.ZONE_WEIGHTS[clampi(int(p.security), 0, 3)]
	var mine := m.rooms.slice(first).filter(func(r): return r.cells > 0)
	var ranked := mine.filter(func(r): return int(hints[r.id].zone_hint) < 0)
	ranked.sort_custom(func(a, b): return depth.get(a.id, 999) < depth.get(b.id, 999))
	var total := 0
	for r in ranked:
		total += r.cells
	var acc := 0
	for r in ranked:
		var frac: float = (acc + r.cells * 0.5) / maxf(1.0, total)
		var z := TacMap.Zone.PUBLIC
		var cum := 0.0
		for i in shares.size():
			cum += shares[i]
			if frac <= cum + 0.0001:
				z = TacMap.Zone.PUBLIC + i
				break
		hints[r.id].zone_hint = z
		acc += r.cells
	for r in mine:
		hints[r.id].zone_eff = clampi(int(hints[r.id].zone_hint) + base_zone - TacMap.Zone.PUBLIC, base_zone, mz)

	var in_tree := {root: true}
	m.rooms[root].zone = base_zone
	var connected := {}
	while true:
		var best_key = null
		var best_w := INF
		for a in in_tree:
			for b in adj.get(a, []):
				if in_tree.has(b):
					continue
				var hb: int = hints[b].zone_eff
				var za: int = m.rooms[a].zone
				var wgt := dice.rng.randf() + 4.0 * absf(hb - (za + 0.5)) + (0.0 if hb >= za else 2.0)
				if not _door_ok(m, a, b):
					wgt += 8.0   # a programmed room opens onto the rooms its brief names, if it can

				if wgt < best_w:
					best_w = wgt
					best_key = [a, b]
		if best_key == null:
			var added := false
			for shaft in shafts:
				var inside: Array = shaft.filter(func(r): return in_tree.has(r))
				if inside.is_empty():
					continue
				for r in shaft:
					if not in_tree.has(r):
						in_tree[r] = true
						m.rooms[r].zone = m.rooms[inside[0]].zone
						added = true
			if not added:
				break
			continue
		var a: int = best_key[0]
		var b: int = best_key[1]
		in_tree[b] = true
		m.rooms[b].zone = clampi(hints[b].zone_eff, m.rooms[a].zone, mini(m.rooms[a].zone + 1, mz))
		_add_door(m, dice, cands, a, b)
		connected[Vector2i(mini(a, b), maxi(a, b))] = true

	for key in cands:
		if connected.has(key) or not in_tree.has(key.x) or not in_tree.has(key.y):
			continue
		var za: int = m.rooms[key.x].zone
		var zb: int = m.rooms[key.y].zone
		if absi(za - zb) <= 1 and maxi(za, zb) < TacMap.Zone.VAULT and dice.rng.randf() < float(p.loops) and _door_ok(m, key.x, key.y):
			_add_door(m, dice, cands, key.x, key.y)
	# Rooms the tree never reached are sealed off: solid structure.
	var sealed := {}
	for r in mine:
		if not in_tree.has(r.id):
			r.kind = "void"
			for i in m.labels[r.floor].size():
				if m.labels[r.floor][i] == r.id:
					m.tiles[r.floor][i] = TacMap.T.WALL
					m.labels[r.floor][i] = -1
					sealed[Vector3i(i % m.w, i / m.w, r.floor)] = true
			r.cells = 0
	# A stair shaft in a sealed room went solid with it: it no longer links its floors.
	if not sealed.is_empty():
		m.verticals.assign(m.verticals.filter(func(v): return not range(int(v.from_floor), int(v.to_floor) + 1).any(
				func(f): return sealed.has(Vector3i(v.pos.x, v.pos.y, f)))))


static func _add_door(m: TacMap, dice: Dice, cands: Dictionary, a: int, b: int) -> void:
	var list: Array = cands[Vector2i(mini(a, b), maxi(a, b))]
	var pick: Array = list[clampi(list.size() / 2 + dice.rng.randi_range(-1, 1), 0, list.size() - 1)]
	var f: int = pick[0]
	var pos: Vector2i = pick[1]
	m.set_t(f, pos.x, pos.y, TacMap.T.DOOR)
	var za: int = m.rooms[a].zone
	var zb: int = m.rooms[b].zone
	m.doors.append({"floor": f, "pos": pos, "a": a, "b": b, "security": za != zb and maxi(za, zb) >= TacMap.Zone.SECURE,
		"structure": m.rooms[a].structure})


## Rooms from a program may only open onto the kinds their brief lists (none listed: any).
static func _door_ok(m: TacMap, a: int, b: int) -> bool:
	var ra: Dictionary = m.rooms[a]
	var rb: Dictionary = m.rooms[b]
	var da: Array = ra.get("program_doors", [])
	var db: Array = rb.get("program_doors", [])
	return (da.is_empty() or String(rb.get("program_kind", "")) in da) and (db.is_empty() or String(ra.get("program_kind", "")) in db)


## Program rooms with `glass` (a bank's teller line) look onto the named rooms through
## bulletproof glass (thin, 15 HP, see-through: p182) instead of a solid wall; the squares beside
## a door keep their wall as the frame.
static func _glass_fronts(m: TacMap, first: int) -> void:
	for r in m.rooms.slice(first):
		var onto: Array = r.get("glass", [])
		if r.cells == 0 or onto.is_empty():
			continue
		for c in Furnish.room_cells(m, r):
			for d in MapGen.DIRS:
				var wcell: Vector2i = c + d
				var beyond: Vector2i = wcell + d
				var l := m.label(r.floor, beyond.x, beyond.y)
				if m.t(r.floor, wcell.x, wcell.y) != TacMap.T.WALL or l < 0 or l == r.id or not (String(m.rooms[l].get("program_kind", "")) in onto):
					continue
				var perp := Vector2i(d.y, d.x)
				if m.t(r.floor, wcell.x + perp.x, wcell.y + perp.y) == TacMap.T.DOOR or m.t(r.floor, wcell.x - perp.x, wcell.y - perp.y) == TacMap.T.DOOR:
					continue
				m.wall_mat[r.floor][wcell.y * m.w + wcell.x] = 6


static func _shaft_rooms(m: TacMap, first: int) -> Array:
	var out := []
	for v in m.verticals:
		var rs := []
		for f in range(v.from_floor, v.to_floor + 1):
			var l := m.label(f, v.pos.x, v.pos.y)
			if l >= first:
				rs.append(l)
		if rs.size() > 1:
			out.append(rs)
	return out


## Exterior walls use the site's material (concrete by default, steel for hulls and train cars);
## interior walls are plaster, hardened to concrete around secure rooms and steel around vaults.
static func _wall_materials(m: TacMap, fps: Array, floors: int, exterior_mat: int) -> void:
	var shell := (fps[0] as Footprint).shell
	for f in floors:
		var fp: Footprint = fps[f]
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				if not fp.has(Vector2i(x, y)) or m.t(f, x, y) != TacMap.T.WALL:
					continue
				var z := 0
				for d in MapGen.DIRS + DIAG:
					var l := m.label(f, x + d.x, y + d.y)
					if l >= 0:
						z = maxi(z, m.rooms[l].zone)
				var mat := exterior_mat if fp.exterior(Vector2i(x, y)) else 0
				if z >= TacMap.Zone.VAULT:
					mat = 2
				elif z >= TacMap.Zone.SECURE:
					mat = maxi(mat, 1)
				m.wall_mat[f][y * m.w + x] = mat


static func _room_kinds(m: TacMap, zones: Dictionary, first: int, entrance_room: int) -> void:
	var by_zone := {}
	for r in m.rooms.slice(first):
		if r.cells > 0:
			by_zone.get_or_add(r.zone, []).append(r)
	for z in by_zone:
		var rule: Dictionary = zones.get(TacMap.ZONE_NAMES[z], zones.get("staff", {"rotation": ["storage"]}))
		var rot: Array = rule["rotation"]
		var list: Array = by_zone[z]
		list.sort_custom(func(a, b): return a.cells > b.cells)
		var i := 0
		for r in list:
			var long_thin: bool = mini(r.bounds.size.x, r.bounds.size.y) <= 3 and r.cells >= 12
			if String(r.get("program_kind", "")) != "":
				r.kind = r.program_kind   # the brief names every room
			elif r.id == entrance_room and rule.has("entrance"):
				r.kind = rule["entrance"]
			elif (long_thin or r.get("layout_kind", "") == "corridor") and not rule.get("no_corridors", false):
				r.kind = "corridor"
			elif r.get("layout_kind", "") != "" and r.layout_kind != "corridor" and rule.has(r.layout_kind):
				r.kind = rule[r.layout_kind]
			elif r.cells <= 16 and rule.has("small"):
				r.kind = rule["small"]
			elif r.cells >= 60 and rule.has("large") and i > 0:
				r.kind = rule["large"]
			else:
				r.kind = rot[0] if i == 0 or rot.size() == 1 else rot[1 + (i - 1) % (rot.size() - 1)]
				i += 1


## Roof level above the top floor: walkable ROOF over the whole footprint, reached by extending
## the stair shaft (roof hatch) and/or an external ladder / fire escape from the street. A roof
## with no way up is left as plain structure (no room, no furniture).
static func _roof(m: TacMap, dice: Dice, hints: Array, fp: Footprint, floors: int, sid: int, base_zone: int, site := "", force := false) -> void:
	var shell := fp.shell
	var rf := floors
	if rf >= m.floors:
		return
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			if fp.has(Vector2i(x, y)):
				m.set_t(rf, x, y, TacMap.T.ROOF)
	var access := false
	for v in m.verticals:
		# only a shaft that still runs up to the top floor (room connection can wall off a dead one)
		if v.get("structure", -1) == sid and v.type == "stairs" and m.t(rf - 1, v.pos.x, v.pos.y) == TacMap.T.STAIRS and (dice.rng.randf() < 0.6 or force):
			v.to_floor = rf
			m.set_t(rf, v.pos.x, v.pos.y, TacMap.T.STAIRS)
			access = true
	var by_side := _facade_candidates(m, fp)
	var ladder_spots := []
	for side in by_side:
		var out_dir: Vector2i = SIDES[side]
		for cnd in by_side[side]:
			var base: Vector2i = cnd.pos + out_dir
			var near_door := false
			for d in MapGen.DIRS + DIAG:
				if m.t(0, base.x + d.x, base.y + d.y) == TacMap.T.DOOR:
					near_door = true
			if not near_door and m.t(0, cnd.pos.x, cnd.pos.y) == TacMap.T.WALL:
				ladder_spots.append([base, cnd.pos])
	if not ladder_spots.is_empty() and (not access or dice.rng.randf() < 0.7):
		var spot: Array = ladder_spots[dice.rng.randi_range(0, ladder_spots.size() - 1)]
		m.connectors.append({"type": "ladder", "a": Vector3i(spot[0].x, spot[0].y, 0), "b": Vector3i(spot[1].x, spot[1].y, rf), "structure": sid})
		access = true
	if not access:
		return
	var id := hints.size()
	hints.append({"zone_hint": TacMap.Zone.STAFF, "kind": "roof", "floor": rf})
	while m.rooms.size() < id:
		m.rooms.append({"id": m.rooms.size(), "floor": -1, "zone": -1, "kind": "void", "cells": 0, "bounds": Rect2i(), "structure": -1})
	m.rooms.append({"id": id, "floor": rf, "zone": maxi(base_zone, TacMap.Zone.STAFF), "kind": "roof", "cells": fp.count,
		"bounds": shell, "structure": sid, "outdoor": true})
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			if fp.has(Vector2i(x, y)):
				m.labels[rf][y * m.w + x] = id
	if site in ["warehouse", "factory"]:   # exhaust stacks: tall cover on an industrial roof
		var placed := 0
		for k in 30:
			if placed >= 2 + dice.rng.randi_range(0, 1):
				break
			var v := Vector2i(dice.rng.randi_range(shell.position.x + 2, shell.end.x - 3), dice.rng.randi_range(shell.position.y + 2, shell.end.y - 3))
			var near := false
			for d in MapGen.DIRS + DIAG:
				if m.t(rf, v.x + d.x, v.y + d.y) == TacMap.T.STAIRS or m.is_connector_end(rf, v + d):
					near = true
			if not near and m.t(rf, v.x, v.y) == TacMap.T.ROOF and Furnish.try_prop(m, rf, Rect2i(v, Vector2i.ONE), "stack", id):
				placed += 1


## Windows on straight exterior walls (not next to doors or ladders), every few squares by the
## site's window rate. Ordinary glass stops movement but not bullets or sight; rooms at secure
## level or deeper get bulletproof glass (thin, 15 HP, see-through — p182). Rooms of the kinds in
## `per_room` (a hotel's guest rooms) instead get one window centred on each outside wall (two on a
## long one), so a slab of identical rooms shows the same window over and over.
static func _windows(m: TacMap, dice: Dice, fps: Array, floors: int, rate: float, armored := false, per_room: Array = []) -> void:
	if rate <= 0.0:
		return
	var shell := (fps[0] as Footprint).shell
	var glass := func(f: int, v: Vector2i, room: int) -> void:
		m.wall_mat[f][v.y * m.w + v.x] = 6 if armored or m.rooms[room].zone >= TacMap.Zone.SECURE else 5
	for f in floors:
		var fp: Footprint = fps[f]
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				var v := Vector2i(x, y)
				if not fp.exterior(v) or m.t(f, x, y) != TacMap.T.WALL or (x + y) % 3 == 0 or dice.rng.randf() >= rate:
					continue
				var room := int(_window_spot(m, fp, f, v)[0])
				if room >= 0 and not String(m.rooms[room].get("program_kind", m.rooms[room].kind)) in per_room:
					glass.call(f, v, room)
	if per_room.is_empty():
		return
	for f in floors:
		var fp: Footprint = fps[f]
		var sides := {}   # [room, side] → wall squares that can take a window
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				var v := Vector2i(x, y)
				if not fp.exterior(v) or m.t(f, x, y) != TacMap.T.WALL:
					continue
				var spot := _window_spot(m, fp, f, v)
				var room := int(spot[0])
				if room >= 0 and String(m.rooms[room].get("program_kind", m.rooms[room].kind)) in per_room:
					sides.get_or_add([room, spot[1]], []).append(v)
		for k in sides:
			var cells: Array = sides[k]
			var d: Vector2i = k[1]
			var r: Rect2i = m.rooms[k[0]].bounds
			var along := func(v: Vector2i) -> float: return float(v.x) if d.x == 0 else float(v.y)
			var lo := float(r.position.x if d.x == 0 else r.position.y)
			var span := float(r.size.x if d.x == 0 else r.size.y)
			var marks: Array = [lo + (span - 1) / 2.0] if span < 7 else [lo + span / 3.0 - 0.5, lo + span * 2.0 / 3.0 - 0.5]
			for mk in marks:
				cells.sort_custom(func(a, b): return absf(along.call(a) - mk) < absf(along.call(b) - mk))
				glass.call(f, cells[0], int(k[0]))


## [room, side] when wall square `v` can hold a window: a straight outside wall with a room's floor
## behind it, not beside a doorway or a ladder; [-1, ZERO] otherwise.
static func _window_spot(m: TacMap, fp: Footprint, f: int, v: Vector2i) -> Array:
	var room := -1
	var side := Vector2i.ZERO
	for sd in SIDES:
		var d: Vector2i = SIDES[sd]
		var perp := Vector2i(d.y, d.x)
		if not fp.has(v + d) and fp.interior(v - d) and m.t(f, v.x - d.x, v.y - d.y) == TacMap.T.FLOOR \
				and m.t(f, v.x + perp.x, v.y + perp.y) == TacMap.T.WALL and m.t(f, v.x - perp.x, v.y - perp.y) == TacMap.T.WALL:
			room = m.label(f, v.x - d.x, v.y - d.y)
			side = d
	if room < 0:
		return [-1, Vector2i.ZERO]
	for d2 in MapGen.DIRS + DIAG:
		var n: Vector2i = v + d2
		if m.t(f, n.x, n.y) == TacMap.T.DOOR or m.is_connector_end(0, n) or m.is_connector_end(f, n):
			return [-1, Vector2i.ZERO]
	if m.is_connector_end(f + 1, v):
		return [-1, Vector2i.ZERO]
	return [room, side]


## A courtyard building: a door from the ground floor into the yard, which becomes an outdoor
## room of this building at the zone of the room it opens from.
static func _courtyard(m: TacMap, dice: Dice, hints: Array, fp: Footprint, yard: Rect2i, sid: int) -> void:
	var cands := []
	for side in _facade_candidates(m, fp, true).values():
		for cnd in side:
			cands.append(cnd)
	if cands.is_empty():
		return
	var pick: Dictionary = cands[dice.rng.randi_range(0, cands.size() - 1)]
	m.set_t(0, pick.pos.x, pick.pos.y, TacMap.T.DOOR)
	m.doors.append({"floor": 0, "pos": pick.pos, "a": -1, "b": pick.room, "security": false, "structure": sid})
	var id := hints.size()
	hints.append({"zone_hint": m.rooms[pick.room].zone, "kind": "courtyard", "floor": 0})
	while m.rooms.size() < id:
		m.rooms.append({"id": m.rooms.size(), "floor": -1, "zone": -1, "kind": "void", "cells": 0, "bounds": Rect2i(), "structure": -1})
	var room := {"id": id, "floor": 0, "zone": m.rooms[pick.room].zone, "kind": "courtyard", "cells": 0, "bounds": yard, "structure": sid, "outdoor": true}
	m.rooms.append(room)
	for y in range(yard.position.y, yard.end.y):
		for x in range(yard.position.x, yard.end.x):
			if m.t(0, x, y) == TacMap.T.OUTSIDE and m.label(0, x, y) < 0:
				m.labels[0][y * m.w + x] = id
				room.cells += 1


## Ruin a building by `decay` (0-1): breached exterior walls (openings on the ground floor, gaps
## on upper floors), collapsed interior walls, and holes in the roof. Only ever adds openings, so
## nothing that was reachable stops being reachable.
static func _decay(m: TacMap, dice: Dice, fps: Array, floors: int, decay: float) -> void:
	var shell := (fps[0] as Footprint).shell
	for f in floors + 1:
		if f >= m.floors:
			break
		var fp: Footprint = fps[mini(f, floors - 1)]
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				var v := Vector2i(x, y)
				if not fp.has(v):
					continue
				var t := m.t(f, x, y)
				if t == TacMap.T.WALL and f < floors:
					if fp.exterior(v) and dice.rng.randf() < decay * 0.12:
						if f == 0:
							m.set_t(0, x, y, TacMap.T.OUTSIDE)
						else:
							m.set_t(f, x, y, TacMap.T.VOID)
						m.labels[f][y * m.w + x] = -1
					elif fp.interior(v) and dice.rng.randf() < decay * 0.18:
						for d in MapGen.DIRS:
							var l := m.label(f, x + d.x, y + d.y)
							if l >= 0 and m.t(f, x + d.x, y + d.y) == TacMap.T.FLOOR:
								m.set_t(f, x, y, TacMap.T.FLOOR)
								m.labels[f][y * m.w + x] = l
								break
				elif t == TacMap.T.ROOF and dice.rng.randf() < decay * 0.1 and not m.is_connector_end(f, v) and not m.has_cover_at(f, v):
					var near := false
					for d in MapGen.DIRS + DIAG:
						if m.t(f, x + d.x, y + d.y) == TacMap.T.STAIRS:
							near = true
					if not near:
						m.set_t(f, x, y, TacMap.T.VOID)
						m.labels[f][y * m.w + x] = -1


## Wall carving can cut a clipped room into pieces that share one label. Keep each room's
## largest piece; tiny leftovers (≤ 6 squares) become solid wall, bigger ones become rooms of
## their own, before doors are planned.
static func _fix_fragments(m: TacMap, f: int, fp: Footprint, hints: Array) -> void:
	var shell := fp.shell
	var seen := {}
	var comps_by_label := {}
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			var v := Vector2i(x, y)
			var l := m.label(f, x, y)
			if l < 0 or seen.has(v) or m.t(f, x, y) != TacMap.T.FLOOR:
				continue
			var comp: Array[Vector2i] = [v]
			seen[v] = true
			var i := 0
			while i < comp.size():
				var u := comp[i]
				i += 1
				for d in MapGen.DIRS:
					var n := u + d
					if not seen.has(n) and shell.has_point(n) and m.label(f, n.x, n.y) == l and m.t(f, n.x, n.y) == TacMap.T.FLOOR:
						seen[n] = true
						comp.append(n)
			comps_by_label.get_or_add(l, []).append(comp)
	for l in comps_by_label:
		var comps: Array = comps_by_label[l]
		if comps.size() < 2:
			continue
		comps.sort_custom(func(a, b): return a.size() > b.size())
		for k in range(1, comps.size()):
			var comp: Array = comps[k]
			if comp.size() <= 6:
				for v in comp:
					m.set_t(f, v.x, v.y, TacMap.T.WALL)
					m.labels[f][v.y * m.w + v.x] = -1
			else:
				var gid := hints.size()
				hints.append((hints[l] as Dictionary).duplicate())
				for v in comp:
					m.labels[f][v.y * m.w + v.x] = gid


# --- Massing: upper floors on smaller footprints ------------------------------------------------

## Each floor's footprint. By the site's massing weights (sites.json): "podium" (the upper floors
## set back on all sides: a tower on a base), "step" (set back on one or two sides from some
## floor up), "wing" (only part of the building rises: a low wing beside a taller block) or none.
## Upper footprints keep at least 9 squares a side so rooms and a stair still fit.
static func _massing(dice: Dice, fp: Footprint, floors: int, w: Dictionary) -> Array:
	var out := []
	for f in floors:
		out.append(fp)
	var sh := fp.shell
	if floors < 2 or w.is_empty() or fp.hole.has_area() or mini(sh.size.x, sh.size.y) < 11:
		return out
	var names := w.keys()
	var wts := PackedFloat32Array()
	for n in names:
		wts.append(float(w[n]))
	var style: String = names[dice.rng.rand_weighted(wts)]
	var r := sh
	var start := dice.rng.randi_range(1, floors - 1)
	var horiz := sh.size.x >= sh.size.y
	match style:
		"podium":
			var d := clampi(roundi(mini(sh.size.x, sh.size.y) * 0.2), 2, 5)
			r = sh.grow(-d)
			start = 1
		"step":
			var dx := clampi(roundi(sh.size.x * 0.3), 3, 6)
			var dy := clampi(roundi(sh.size.y * 0.3), 3, 6)
			var two := dice.rng.randf() < 0.5
			var left := dice.rng.randf() < 0.5
			var top := dice.rng.randf() < 0.5
			if horiz or two:
				r = r.grow_individual(-dx if left else 0, 0, 0 if left else -dx, 0)
			if not horiz or two:
				r = r.grow_individual(0, -dy if top else 0, 0, 0 if top else -dy)
		"wing":
			var keep := dice.rng.randf_range(0.5, 0.65)
			var first := dice.rng.randf() < 0.5
			if horiz:
				var kw := roundi(sh.size.x * keep)
				r = Rect2i(sh.position.x if first else sh.end.x - kw, sh.position.y, kw, sh.size.y)
			else:
				var kh := roundi(sh.size.y * keep)
				r = Rect2i(sh.position.x, sh.position.y if first else sh.end.y - kh, sh.size.x, kh)
		_:
			return out
	if mini(r.size.x, r.size.y) < 9:
		return out
	var mask := {}
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if fp.has(Vector2i(x, y)):
				mask[Vector2i(x, y)] = true
	if mask.size() < 70:
		return out
	var up := Footprint.make(sh, mask)
	for f in range(start, floors):
		out[f] = up
	return out


## A set piece's program keeps only part of the plan on some storeys (Layouts.program_keep): those
## floors stand on that part of the footprint (its outer ring becomes the new exterior wall).
static func _keep(fps: Array, fp: Footprint, inner: Rect2i, p: Dictionary, floors: int) -> void:
	if not p.program.has("keep"):
		return
	for f in floors:
		var r := Layouts.program_keep(inner, p, f).grow(1)
		if not r.has_area():
			continue
		var mask := {}
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if (fps[f] as Footprint).has(Vector2i(x, y)):
					mask[Vector2i(x, y)] = true
		if mask.size() >= 25:
			fps[f] = Footprint.make(fp.shell, mask)


## Where an upper floor is set back, the roof of the floor below becomes a terrace: walkable roof,
## an outdoor room of the building with a door from the floor beside it. A terrace no door can
## reach stays plain roof.
static func _terraces(m: TacMap, hints: Array, fps: Array, floors: int, sid: int) -> void:
	for f in range(1, floors):
		var lower: Footprint = fps[f - 1]
		var upper: Footprint = fps[f]
		if lower == upper:
			continue
		var cells := {}
		var sh := lower.shell
		for y in range(sh.position.y, sh.end.y):
			for x in range(sh.position.x, sh.end.x):
				var v := Vector2i(x, y)
				if lower.has(v) and not upper.has(v):
					cells[v] = true
					m.set_t(f, x, y, TacMap.T.ROOF)
					m.labels[f][y * m.w + x] = -1
		var seen := {}
		for v0 in cells:
			if seen.has(v0):
				continue
			var comp: Array[Vector2i] = [v0]
			seen[v0] = true
			var i := 0
			while i < comp.size():
				var u := comp[i]
				i += 1
				for d in MapGen.DIRS:
					var n: Vector2i = u + d
					if cells.has(n) and not seen.has(n):
						seen[n] = true
						comp.append(n)
			var in_comp := {}
			for v in comp:
				in_comp[v] = true
			var cands := []
			for v in comp:
				for side in SIDES:
					var d: Vector2i = SIDES[side]
					var wcell: Vector2i = v - d   # the upper floor's outer wall, the room behind it
					var room_c: Vector2i = wcell - d
					var perp := Vector2i(d.y, d.x)
					if m.t(f, wcell.x, wcell.y) == TacMap.T.WALL and upper.exterior(wcell) and upper.interior(room_c) \
							and m.t(f, room_c.x, room_c.y) == TacMap.T.FLOOR and m.label(f, room_c.x, room_c.y) >= 0 \
							and m.t(f, wcell.x + perp.x, wcell.y + perp.y) == TacMap.T.WALL and m.t(f, wcell.x - perp.x, wcell.y - perp.y) == TacMap.T.WALL:
						cands.append([wcell, m.label(f, room_c.x, room_c.y)])
			if cands.is_empty() or comp.size() < 4:
				continue
			var pick: Array = cands[cands.size() / 2]
			var room: int = pick[1]
			var id := hints.size()
			hints.append({"zone_hint": m.rooms[room].zone, "kind": "terrace", "floor": f})
			while m.rooms.size() < id:
				m.rooms.append({"id": m.rooms.size(), "floor": -1, "zone": -1, "kind": "void", "cells": 0, "bounds": Rect2i(), "structure": -1})
			var b := Rect2i(comp[0], Vector2i.ONE)
			for v in comp:
				b = b.expand(v).expand(v + Vector2i.ONE)
				m.labels[f][v.y * m.w + v.x] = id
			m.rooms.append({"id": id, "floor": f, "zone": m.rooms[room].zone, "kind": "terrace", "cells": comp.size(),
				"bounds": b, "structure": sid, "outdoor": true})
			var wp: Vector2i = pick[0]
			m.set_t(f, wp.x, wp.y, TacMap.T.DOOR)
			m.doors.append({"floor": f, "pos": wp, "a": id, "b": room, "security": false, "structure": sid})
