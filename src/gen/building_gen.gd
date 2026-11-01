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
##       params (density, loops, verticality, algorithm override, net_scale, net_threat)}
## `hints` is the scene-wide room hint list (index = global room id). Returns the structure dict.
static func build(m: TacMap, dice: Dice, hints: Array, ctx: Dictionary) -> Dictionary:
	var sdef: Dictionary = RulesDB.gen("sites.json")[ctx.site]
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
	m.structures.append(st)

	var first_id := hints.size()
	for f in floors:
		var local := PackedInt32Array()
		local.resize(m.w * m.h)
		local.fill(-1)
		var room_hints := Layouts.run(p.algorithm, dice, m.w, inner, local, p)
		for y in range(inner.position.y, inner.end.y):
			for x in range(inner.position.x, inner.end.x):
				if not fp.interior(Vector2i(x, y)):
					local[y * m.w + x] = -1
		_split_components(m, f, local, inner, room_hints, hints)
		_walls(m, f, fp)
		_fix_fragments(m, f, fp, hints)
	_index_rooms(m, shell, floors, first_id, hints.size(), sid)
	for i in range(first_id, hints.size()):
		m.rooms[i]["layout_kind"] = hints[i].get("kind", "")
	_verticals(m, dice, shell, floors, int(p.verticality), sid)
	var door := _main_door(m, dice, fp, String(ctx.get("entry_side", "")), sdef.get("enter_corridor", false))
	if door.is_empty():
		push_warning("BuildingGen: no facade faces open ground for %s at %s" % [ctx.site, shell])
		return st
	var root: int = door.room
	_connect(m, dice, hints, p, first_id, root, int(st.base_zone))
	_place_main_door(m, door, sid, bool(st.target))
	_service_door(m, dice, fp, door.side, sid, int(st.base_zone))
	_wall_materials(m, fp, floors, int(sdef.get("exterior", 1)))
	_room_kinds(m, String(ctx.site), first_id, root)
	_roof(m, dice, hints, fp, floors, sid, int(st.base_zone))
	_windows(m, dice, fp, floors, float(sdef.get("windows", 0.5)))
	var cy: Rect2i = ctx.get("courtyard", Rect2i())
	if cy.has_area():
		_courtyard(m, dice, hints, fp, cy, sid)
	var decay := float(p.get("decay", sdef.get("decay", 0.0)))
	if decay > 0.0:
		_decay(m, dice, fp, floors, decay)
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
static func _verticals(m: TacMap, dice: Dice, shell: Rect2i, floors: int, verticality: int, sid: int) -> void:
	if floors < 2:
		return
	var kinds := [TacMap.T.STAIRS]
	if verticality >= 2:
		kinds.append(TacMap.T.ELEVATOR)
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
		if candidates.is_empty():
			continue
		var c := shell.get_center()
		candidates.sort_custom(func(a, b): return a.distance_squared_to(c) < b.distance_squared_to(c))
		var pos: Vector2i = candidates[dice.rng.randi_range(0, mini(8, candidates.size() - 1))]
		for f in floors:
			m.set_t(f, pos.x, pos.y, kind)
		m.verticals.append({"type": "stairs" if kind == TacMap.T.STAIRS else "elevator", "pos": pos, "from_floor": 0, "to_floor": floors - 1, "structure": sid})


## Facade door candidates: exterior wall cells (not corners) with a room inside and open ground
## outside. Returns {side, pos, room} for the best one, preferring `side` when given.
static func _main_door(m: TacMap, dice: Dice, fp: Footprint, side: String, prefer_corridor: bool) -> Dictionary:
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


static func _service_door(m: TacMap, dice: Dice, fp: Footprint, main_side: String, sid: int, base_zone: int) -> void:
	var by_side := _facade_candidates(m, fp)
	var best: Dictionary = {}
	for s in by_side:
		if s == main_side:
			continue
		for c in by_side[s]:
			var z: int = m.rooms[c.room].zone
			if z >= 0 and z <= base_zone + 1 and (best.is_empty() or z > best.zone):
				best = {"pos": c.pos, "room": c.room, "zone": z}
	if best.is_empty() or dice.rng.randf() < 0.2:
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
		if absi(za - zb) <= 1 and maxi(za, zb) < TacMap.Zone.VAULT and dice.rng.randf() < float(p.loops):
			_add_door(m, dice, cands, key.x, key.y)
	# Rooms the tree never reached are sealed off: solid structure.
	for r in mine:
		if not in_tree.has(r.id):
			r.kind = "void"
			for i in m.labels[r.floor].size():
				if m.labels[r.floor][i] == r.id:
					m.tiles[r.floor][i] = TacMap.T.WALL
					m.labels[r.floor][i] = -1
			r.cells = 0


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
static func _wall_materials(m: TacMap, fp: Footprint, floors: int, exterior_mat: int) -> void:
	var shell := fp.shell
	for f in floors:
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


static func _room_kinds(m: TacMap, site: String, first: int, entrance_room: int) -> void:
	var zones: Dictionary = RulesDB.gen("sites.json")[site]["zones"]
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
			if r.id == entrance_room and rule.has("entrance"):
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
static func _roof(m: TacMap, dice: Dice, hints: Array, fp: Footprint, floors: int, sid: int, base_zone: int) -> void:
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
		if v.get("structure", -1) == sid and v.type == "stairs" and dice.rng.randf() < 0.6:
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


## Windows on straight exterior walls (not next to doors or ladders), every few squares by the
## site's window rate. Ordinary glass stops movement but not bullets or sight; rooms at secure
## level or deeper get bulletproof glass (thin, 15 HP, see-through — p182).
static func _windows(m: TacMap, dice: Dice, fp: Footprint, floors: int, rate: float) -> void:
	if rate <= 0.0:
		return
	var shell := fp.shell
	for f in floors:
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				var v := Vector2i(x, y)
				if not fp.exterior(v) or m.t(f, x, y) != TacMap.T.WALL or (x + y) % 3 == 0 or dice.rng.randf() >= rate:
					continue
				var room := -1
				for side in SIDES:
					var d: Vector2i = SIDES[side]
					var perp := Vector2i(d.y, d.x)
					if not fp.has(v + d) and fp.interior(v - d) and m.t(f, v.x - d.x, v.y - d.y) == TacMap.T.FLOOR \
							and m.t(f, v.x + perp.x, v.y + perp.y) == TacMap.T.WALL and m.t(f, v.x - perp.x, v.y - perp.y) == TacMap.T.WALL:
						room = m.label(f, v.x - d.x, v.y - d.y)
				if room < 0:
					continue
				var near := false
				for d2 in MapGen.DIRS + DIAG:
					var n: Vector2i = v + d2
					if m.t(f, n.x, n.y) == TacMap.T.DOOR or m.is_connector_end(0, n) or m.is_connector_end(f, n):
						near = true
				if near or m.is_connector_end(f + 1, v):
					continue
				m.wall_mat[f][y * m.w + x] = 6 if m.rooms[room].zone >= TacMap.Zone.SECURE else 5


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
static func _decay(m: TacMap, dice: Dice, fp: Footprint, floors: int, decay: float) -> void:
	var shell := fp.shell
	for f in floors + 1:
		if f >= m.floors:
			break
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
				elif t == TacMap.T.ROOF and dice.rng.randf() < decay * 0.1 and not m.is_connector_end(f, v):
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
