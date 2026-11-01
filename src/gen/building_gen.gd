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
	if float(p.get("density", -1.0)) < 0.0:
		p.density = float(sdef["density"])
	var floors := mini(int(ctx.get("floors", 1)), m.floors)
	var shell: Rect2i = ctx.shell
	var inner := shell.grow(-1)
	var sid := m.structures.size()
	var st := {"id": sid, "kind": "building", "site": ctx.site, "rect": shell, "floors": floors,
		"security": p.security, "target": ctx.get("target", false), "base_zone": int(ctx.get("base_zone", TacMap.Zone.PUBLIC)),
		"params": p, "algorithm": p.algorithm}
	m.structures.append(st)

	var first_id := hints.size()
	for f in floors:
		var local := PackedInt32Array()
		local.resize(m.w * m.h)
		local.fill(-1)
		var room_hints := Layouts.run(p.algorithm, dice, m.w, inner, local, p)
		_split_components(m, f, local, inner, room_hints, hints)
		_walls(m, f, shell, inner)
	_index_rooms(m, shell, floors, first_id, hints.size(), sid)
	for i in range(first_id, hints.size()):
		m.rooms[i]["layout_kind"] = hints[i].get("kind", "")
	_verticals(m, dice, shell, floors, int(p.verticality), sid)
	var door := _main_door(m, dice, shell, String(ctx.get("entry_side", "")), sdef.get("enter_corridor", false))
	if door.is_empty():
		push_warning("BuildingGen: no facade faces open ground for %s at %s" % [ctx.site, shell])
		return st
	var root: int = door.room
	_connect(m, dice, hints, p, first_id, root, int(st.base_zone))
	_place_main_door(m, door, sid, bool(st.target))
	_service_door(m, dice, shell, door.side, sid, int(st.base_zone))
	_wall_materials(m, shell, floors, int(sdef.get("exterior", 1)))
	_room_kinds(m, String(ctx.site), first_id, root)
	Furnish.run_structure(m, dice, sid)
	if sdef.get("networked", true) and m.devices.any(func(d): return d.structure == sid):
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


## A cell becomes wall if its east or south neighbour belongs to a different room; the shell
## boundary is the exterior wall.
static func _walls(m: TacMap, f: int, shell: Rect2i, inner: Rect2i) -> void:
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			if not inner.has_point(Vector2i(x, y)):
				m.set_t(f, x, y, TacMap.T.WALL)
				m.labels[f][y * m.w + x] = -1
				continue
			var l := m.label(f, x, y)
			var wall := false
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				var n: Vector2i = Vector2i(x, y) + d
				if inner.has_point(n) and m.label(f, n.x, n.y) != l:
					wall = true
			m.set_t(f, x, y, TacMap.T.WALL if wall else TacMap.T.FLOOR)
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			if m.t(f, x, y) == TacMap.T.WALL:
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
static func _main_door(m: TacMap, dice: Dice, shell: Rect2i, side: String, prefer_corridor: bool) -> Dictionary:
	var by_side := _facade_candidates(m, shell)
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


static func _facade_candidates(m: TacMap, shell: Rect2i) -> Dictionary:
	var out := {"N": [], "S": [], "E": [], "W": []}
	for x in range(shell.position.x + 1, shell.end.x - 1):
		_cand(m, out.N, Vector2i(x, shell.position.y), Vector2i.UP)
		_cand(m, out.S, Vector2i(x, shell.end.y - 1), Vector2i.DOWN)
	for y in range(shell.position.y + 1, shell.end.y - 1):
		_cand(m, out.W, Vector2i(shell.position.x, y), Vector2i.LEFT)
		_cand(m, out.E, Vector2i(shell.end.x - 1, y), Vector2i.RIGHT)
	return out


static func _cand(m: TacMap, list: Array, pos: Vector2i, outward: Vector2i) -> void:
	var inside := pos - outward
	var outside := pos + outward
	var l := m.label(0, inside.x, inside.y)
	if l >= 0 and m.t(0, inside.x, inside.y) == TacMap.T.FLOOR and m.t(0, pos.x, pos.y) == TacMap.T.WALL \
			and m.t(0, outside.x, outside.y) in [TacMap.T.OUTSIDE] and not m.has_cover_at(0, outside):
		list.append({"pos": pos, "room": l})


static func _place_main_door(m: TacMap, door: Dictionary, sid: int, target: bool) -> void:
	m.set_t(0, door.pos.x, door.pos.y, TacMap.T.DOOR)
	m.doors.append({"floor": 0, "pos": door.pos, "a": -1, "b": door.room, "security": false, "structure": sid})
	m.entrances.append({"floor": 0, "pos": door.pos, "main": target, "kind": "door", "structure": sid})


static func _service_door(m: TacMap, dice: Dice, shell: Rect2i, main_side: String, sid: int, base_zone: int) -> void:
	var by_side := _facade_candidates(m, shell)
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
static func _door_candidates(m: TacMap, first: int) -> Dictionary:
	var out := {}
	for f in m.floors:
		for y in m.h:
			for x in m.w:
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
	var cands := _door_candidates(m, first)
	var adj := {}
	for key in cands:
		adj.get_or_add(key.x, []).append(key.y)
		adj.get_or_add(key.y, []).append(key.x)
	var mz := maxi(MapGen.max_zone(int(p.security)), base_zone)
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
static func _wall_materials(m: TacMap, shell: Rect2i, floors: int, exterior_mat: int) -> void:
	for f in floors:
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				if m.t(f, x, y) != TacMap.T.WALL:
					continue
				var exterior := x == shell.position.x or y == shell.position.y or x == shell.end.x - 1 or y == shell.end.y - 1
				var z := 0
				for d in MapGen.DIRS + DIAG:
					var l := m.label(f, x + d.x, y + d.y)
					if l >= 0:
						z = maxi(z, m.rooms[l].zone)
				var mat := exterior_mat if exterior else 0
				if z >= TacMap.Zone.VAULT:
					mat = 2
				elif z >= TacMap.Zone.SECURE:
					mat = maxi(mat, 1)
				m.wall_mat[f][y * m.w + x] = mat


## Room kinds from the site type's per-zone rules (data/gen/sites.json).
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
