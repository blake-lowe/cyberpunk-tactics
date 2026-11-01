class_name MapGen
extends RefCounted
## Builds a TacMap: building footprint on a street corner → per-floor room layout (Layouts) →
## walls → stair/elevator shafts → doors + security zones → wall materials → room kinds →
## furnishing (Furnish) → coupled NET Architecture (NetGen).
##
## Security gradient: rooms are connected with a Prim-style tree from the entrance where each
## step can raise the zone by at most one (street → public → staff → secure → vault), so the
## deeper you go physically, the deeper you are in the architecture.

const DEFAULTS := {
	"w": 40, "h": 32, "floors": 2,
	"security": 1,       # 0-3 → Basic/Standard/Uncommon/Advanced (p210)
	"density": 0.5,      # cover density 0-1
	"loops": 0.35,       # chance of extra doors between same/adjacent-zone rooms (flanking routes)
	"verticality": 1,    # 0 = single floor, 1 = stairs, 2 = stairs + elevator
	"net_style": "stack",  # "stack" (rules-as-written shape) or "mirrored" (branch per building floor)
}
const STREET := 3  # street rows (south) and alley columns (east)
const MIN_ROOM_CELLS := 4

static var DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func generate(seed_value: int, algorithm: String, overrides: Dictionary = {}) -> TacMap:
	var p := DEFAULTS.duplicate()
	p.merge(overrides, true)
	if int(p.verticality) == 0:
		p.floors = 1
	var dice := Dice.new(seed_value)
	var m := TacMap.new(int(p.w), int(p.h), int(p.floors))
	m.seed_value = seed_value
	m.algorithm = algorithm
	m.params = p
	var shell := Rect2i(0, 0, m.w - STREET, m.h - STREET)      # building incl. exterior walls
	var inner := Rect2i(1, 1, shell.size.x - 2, shell.size.y - 2)

	_outside(m)
	var hints := []  # global room id → hint dict
	for f in m.floors:
		var local := PackedInt32Array()
		local.resize(m.w * m.h)
		local.fill(-1)
		var room_hints := Layouts.run(algorithm, dice, m.w, inner, local, p)
		_split_components(m, f, local, inner, room_hints, hints)
		_walls(m, f, shell, inner)
	_index_rooms(m)
	for r in m.rooms:
		r["layout_kind"] = hints[r.id].get("kind", "") if r.id < hints.size() else ""
	_verticals(m, dice, int(p.verticality))
	_connect(m, dice, hints, p)
	_entrances(m, shell)
	_wall_materials(m, shell)
	_room_kinds(m)
	Furnish.run(m, dice)
	m.architecture = NetGen.generate(m, dice)
	return m


static func max_zone(security: int) -> int:
	return [TacMap.Zone.STAFF, TacMap.Zone.SECURE, TacMap.Zone.VAULT, TacMap.Zone.VAULT][clampi(security, 0, 3)]


static func _outside(m: TacMap) -> void:
	for f in m.floors:
		for y in m.h:
			for x in m.w:
				if f == 0 and (y >= m.h - STREET or x >= m.w - STREET):
					m.set_t(f, x, y, TacMap.T.OUTSIDE)


## Re-label each layout room by connected component (corridors can cut rooms in two), merging
## slivers into a neighbour, and append to the map's global room list.
static func _split_components(m: TacMap, f: int, local: PackedInt32Array, inner: Rect2i, room_hints: Array, hints: Array) -> void:
	var seen := {}
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
				for d in DIRS:
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
	# Merge slivers into a neighbouring room.
	var counts := {}
	for i in m.labels[f].size():
		var l := m.labels[f][i]
		if l >= 0:
			counts[l] = counts.get(l, 0) + 1
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			var gid := m.labels[f][y * m.w + x]
			if gid < 0 or counts.get(gid, 0) >= MIN_ROOM_CELLS:
				continue
			for d in DIRS:
				var n := m.label(f, x + d.x, y + d.y)
				if n >= 0 and n != gid:
					counts[n] = counts.get(n, 0) + counts[gid]
					counts[gid] = 0
					_relabel(m, f, inner, gid, n)
					break


static func _relabel(m: TacMap, f: int, r: Rect2i, from: int, to: int) -> void:
	for i in m.labels[f].size():
		if m.labels[f][i] == from:
			m.labels[f][i] = to


## A cell becomes wall if its east or south neighbour belongs to a different room; the shell
## boundary is the exterior wall. Gives 1-cell walls without eating both sides.
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


static func _index_rooms(m: TacMap) -> void:
	var by_id := {}
	for f in m.floors:
		for y in m.h:
			for x in m.w:
				var l := m.label(f, x, y)
				if l < 0:
					continue
				if not by_id.has(l):
					by_id[l] = {"id": l, "floor": f, "zone": -1, "kind": "", "cells": 0, "bounds": Rect2i(x, y, 1, 1)}
				by_id[l].cells += 1
				by_id[l].bounds = (by_id[l].bounds as Rect2i).expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	var max_id := -1
	for k in by_id:
		max_id = maxi(max_id, k)
	m.rooms.clear()
	for i in max_id + 1:
		m.rooms.append(by_id.get(i, {"id": i, "floor": -1, "zone": -1, "kind": "void", "cells": 0, "bounds": Rect2i()}))


## Stair shaft through every floor (and an elevator at verticality 2): a cell that is open floor
## with open floor around it on all floors.
static func _verticals(m: TacMap, dice: Dice, verticality: int) -> void:
	if m.floors < 2:
		return
	var kinds := [TacMap.T.STAIRS]
	if verticality >= 2:
		kinds.append(TacMap.T.ELEVATOR)
	for kind in kinds:
		var candidates: Array[Vector2i] = []
		for y in m.h:
			for x in m.w:
				var ok := true
				for f in m.floors:
					if m.t(f, x, y) != TacMap.T.FLOOR:
						ok = false
						break
					for d in DIRS:
						if m.t(f, x + d.x, y + d.y) != TacMap.T.FLOOR:
							ok = false
				if ok:
					candidates.append(Vector2i(x, y))
		if candidates.is_empty():
			continue
		# Stairs prefer the south half (near the entrance), elevators the middle.
		candidates.sort_custom(func(a, b): return a.y > b.y if kind == TacMap.T.STAIRS else absi(a.x - m.w / 2) < absi(b.x - m.w / 2))
		var pos: Vector2i = candidates[dice.rng.randi_range(0, mini(5, candidates.size() - 1))]
		for f in m.floors:
			m.set_t(f, pos.x, pos.y, kind)
		m.verticals.append({"type": "stairs" if kind == TacMap.T.STAIRS else "elevator", "pos": pos, "from_floor": 0, "to_floor": m.floors - 1})


## Door candidates between two rooms: wall cells with open floor of each room on opposite sides.
static func _door_candidates(m: TacMap) -> Dictionary:
	var out := {}  # Vector2i(a,b) sorted → Array of [floor, pos]
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
					if a >= 0 and b >= 0 and a != b and m.t(f, p1.x, p1.y) == TacMap.T.FLOOR and m.t(f, p2.x, p2.y) == TacMap.T.FLOOR:
						var key := Vector2i(mini(a, b), maxi(a, b))
						if not out.has(key):
							out[key] = []
						out[key].append([f, Vector2i(x, y)])
	return out


static func _connect(m: TacMap, dice: Dice, hints: Array, p: Dictionary) -> void:
	var cands := _door_candidates(m)
	var adj := {}
	for key in cands:
		adj.get_or_add(key.x, []).append(key.y)
		adj.get_or_add(key.y, []).append(key.x)
	var mz := max_zone(int(p.security))

	# Depth-derived hints for rooms whose layout gave none (BSP): rank rooms by BFS depth from the
	# entrance and hand out zones by cumulative floor area, using the treemap zone shares.
	var root0 := _entrance_room(m)
	var depth := _bfs_depth(adj, root0, m)
	var shares: Array = Layouts.ZONE_WEIGHTS[clampi(int(p.security), 0, 3)]
	var ranked := m.rooms.filter(func(r): return r.cells > 0 and int(hints[r.id].zone_hint) < 0)
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
	for r in m.rooms:
		if r.cells > 0:
			hints[r.id].zone_eff = clampi(int(hints[r.id].zone_hint), TacMap.Zone.PUBLIC, mz)

	# Prim-style growth from the entrance: each step raises the zone by at most one.
	var in_tree := {root0: true}
	m.rooms[root0].zone = TacMap.Zone.PUBLIC
	var connected := {}
	var stairs_rooms := _vertical_rooms(m)
	# Rooms on a shaft share the zone of the lowest connected one; join them as the tree reaches them.
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
			# Join any shaft rooms not yet in the tree via their shaft.
			var added := false
			for shaft in stairs_rooms:
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

	# Extra loops between rooms of equal/adjacent zone (never into the vault) for flanking routes.
	for key in cands:
		if connected.has(key) or not in_tree.has(key.x) or not in_tree.has(key.y):
			continue
		var za: int = m.rooms[key.x].zone
		var zb: int = m.rooms[key.y].zone
		if absi(za - zb) <= 1 and maxi(za, zb) < TacMap.Zone.VAULT and dice.rng.randf() < float(p.loops):
			_add_door(m, dice, cands, key.x, key.y)
	# Rooms the tree never reached are sealed off: fill them in as solid structure.
	for r in m.rooms:
		if r.cells > 0 and not in_tree.has(r.id):
			r.kind = "void"
			for i in m.labels[r.floor].size():
				if m.labels[r.floor][i] == r.id:
					m.tiles[r.floor][i] = TacMap.T.WALL
					m.labels[r.floor][i] = -1
			r.cells = 0


static func _add_door(m: TacMap, dice: Dice, cands: Dictionary, a: int, b: int) -> void:
	var list: Array = cands[Vector2i(mini(a, b), maxi(a, b))]
	# Prefer a candidate near the middle of the shared wall.
	var pick: Array = list[clampi(list.size() / 2 + dice.rng.randi_range(-1, 1), 0, list.size() - 1)]
	var f: int = pick[0]
	var pos: Vector2i = pick[1]
	m.set_t(f, pos.x, pos.y, TacMap.T.DOOR)
	var za: int = m.rooms[a].zone
	var zb: int = m.rooms[b].zone
	m.doors.append({"floor": f, "pos": pos, "a": a, "b": b, "security": za != zb and maxi(za, zb) >= TacMap.Zone.SECURE})


static func _entrance_room(m: TacMap) -> int:
	var best := -1
	var best_d := 1 << 30
	var y := m.h - STREET - 2  # interior row just north of the south exterior wall
	for x in m.w:
		var l := m.label(0, x, y)
		if l >= 0 and m.t(0, x, y) == TacMap.T.FLOOR and absi(x - (m.w - STREET) / 2) < best_d:
			best_d = absi(x - (m.w - STREET) / 2)
			best = l
	return best


static func _bfs_depth(adj: Dictionary, root: int, m: TacMap) -> Dictionary:
	var depth := {root: 0}
	var q := [root]
	# Shafts connect floors for depth purposes.
	var shafts := _vertical_rooms(m)
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
	return depth


static func _vertical_rooms(m: TacMap) -> Array:
	var out := []
	for v in m.verticals:
		var rs := []
		for f in range(v.from_floor, v.to_floor + 1):
			# The shaft cell itself is unlabeled-safe: use its label (shaft cells keep their room label).
			var l := m.label(f, v.pos.x, v.pos.y)
			if l >= 0:
				rs.append(l)
		out.append(rs)
	return out


static func _entrances(m: TacMap, shell: Rect2i) -> void:
	# Main entrance: south wall door into the entrance room. Service door: east wall into the
	# least-public staff room touching it. Spawn points sit on the street/alley map edges.
	var lobby := _entrance_room(m)
	var y := shell.end.y - 1
	var best_x := -1
	for x in range(1, shell.end.x - 1):
		if m.label(0, x, y - 1) == lobby and m.t(0, x, y - 1) == TacMap.T.FLOOR and (best_x < 0 or absi(x - shell.size.x / 2) < absi(best_x - shell.size.x / 2)):
			best_x = x
	if best_x >= 0:
		m.set_t(0, best_x, y, TacMap.T.DOOR)
		m.doors.append({"floor": 0, "pos": Vector2i(best_x, y), "a": -1, "b": lobby, "security": false})
		m.entrances.append({"floor": 0, "pos": Vector2i(best_x, y), "main": true, "kind": "door"})
	var ex := shell.end.x - 1
	var best_y := -1
	var best_zone := -1
	for yy in range(1, shell.end.y - 1):
		var l := m.label(0, ex - 1, yy)
		if l < 0 or m.t(0, ex - 1, yy) != TacMap.T.FLOOR:
			continue
		var z: int = m.rooms[l].zone
		if z <= TacMap.Zone.STAFF and z > best_zone:
			best_zone = z
			best_y = yy
	if best_y >= 0:
		var l := m.label(0, ex - 1, best_y)
		m.set_t(0, ex, best_y, TacMap.T.DOOR)
		m.doors.append({"floor": 0, "pos": Vector2i(ex, best_y), "a": -1, "b": l, "security": false})
		m.entrances.append({"floor": 0, "pos": Vector2i(ex, best_y), "main": false, "kind": "door"})
	# Reinforcement spawns: far ends of the street and the alley.
	m.entrances.append({"floor": 0, "pos": Vector2i(0, m.h - 2), "main": false, "kind": "spawn"})
	m.entrances.append({"floor": 0, "pos": Vector2i(m.w - 2, 0), "main": false, "kind": "spawn"})


static func _wall_materials(m: TacMap, shell: Rect2i) -> void:
	for f in m.floors:
		for y in m.h:
			for x in m.w:
				if m.t(f, x, y) != TacMap.T.WALL:
					continue
				var exterior := x == shell.position.x or y == shell.position.y or x == shell.end.x - 1 or y == shell.end.y - 1
				var z := 0
				for d in DIRS + [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					var l := m.label(f, x + d.x, y + d.y)
					if l >= 0:
						z = maxi(z, m.rooms[l].zone)
				var mat := 1 if exterior else 0  # concrete / plaster
				if z >= TacMap.Zone.VAULT:
					mat = 2
				elif z >= TacMap.Zone.SECURE:
					mat = maxi(mat, 1)
				m.wall_mat[f][y * m.w + x] = mat


static func _room_kinds(m: TacMap) -> void:
	var lobby := _entrance_room(m)
	var by_zone := {}
	for r in m.rooms:
		if r.cells == 0:
			continue
		by_zone.get_or_add(r.zone, []).append(r)
	for z in by_zone:
		var list: Array = by_zone[z]
		list.sort_custom(func(a, b): return a.cells > b.cells)
		var i := 0
		for r in list:
			var long_thin: bool = mini(r.bounds.size.x, r.bounds.size.y) <= 3 and r.cells >= 12
			if r.id == lobby:
				r.kind = "lobby"
			elif long_thin or r.get("layout_kind", "") == "corridor":
				r.kind = "corridor"
			else:
				match z:
					TacMap.Zone.PUBLIC:
						r.kind = "restroom" if r.cells <= 16 else ("atrium" if r.cells >= 60 else "waiting")
					TacMap.Zone.STAFF:
						r.kind = "storage" if r.cells <= 16 else ["office", "office", "meeting", "break_room", "office"][i % 5]
					TacMap.Zone.SECURE:
						r.kind = ["server_room", "security_office", "lab"][mini(i, 2)] if i < 3 else "lab"
					TacMap.Zone.VAULT:
						r.kind = "data_vault" if i == 0 else "exec_office"
				i += 1
