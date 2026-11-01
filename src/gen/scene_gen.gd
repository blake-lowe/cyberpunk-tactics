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
	var m := TacMap.new(int(p.w), int(p.h), int(p.floors) + 1)  # + roof level
	m.seed_value = seed_value
	m.algorithm = scene
	m.params = p
	p["scene"] = scene
	var c := {"m": m, "dice": dice, "hints": [], "p": p, "reserved": {}, "overrides": overrides, "related": []}
	match scene:
		"lone_building": _lone_building(c)
		"street_block": _city(c, 2, 1)
		"city_district": _city(c, 4, 3)
		"megablock": _megablock(c)
		"shipyard": _shipyard(c)
		"badlands": _badlands(c)
		"rail_yard": _rail_yard(c)
		"corp_campus": _corp_campus(c)
		_: push_error("unknown scene " + scene)
	_link_nets(c)
	_deploy_zone(c)
	_guard_posts(m)
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


static func building(c: Dictionary, shell: Rect2i, site: String, floors: int, security: int, target := false, base_zone := TacMap.Zone.PUBLIC, entry_side := "", mask := {}) -> Dictionary:
	# Only what the caller set explicitly; otherwise each site keeps its own defaults.
	var params: Dictionary = {}
	for k in ["density", "loops", "net_threat", "net_scale"]:
		if c.overrides.has(k):
			params[k] = c.overrides[k]
	for k in ["algorithm", "verticality"]:
		if target and c.overrides.has(k):
			params[k] = c.overrides[k]
	return BuildingGen.build(c.m, c.dice, c.hints, {"shell": shell, "site": site, "floors": floors, "security": security,
		"base_zone": base_zone, "target": target, "entry_side": entry_side, "params": params, "mask": mask})


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
		m.doors.append({"floor": 0, "pos": g, "a": -1, "b": inside_room.id, "security": sec, "structure": inside_room.structure, "gate": true})
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


## Skybridge between two buildings across a gap, on a shared upper floor, joining rooms that are
## at most staff zone (a bridge never bypasses secure areas). Returns true if one was built.
static func skybridge(c: Dictionary, a: Dictionary, b: Dictionary) -> bool:
	var m: TacMap = c.m
	var top := mini(int(a.floors), int(b.floors)) - 1
	if top < 1:
		return false
	var ra: Rect2i = a.rect
	var rb: Rect2i = b.rect
	if rb.end.x <= ra.position.x or rb.end.y <= ra.position.y:
		var t := ra; ra = rb; rb = t
		var ts := a; a = b; b = ts
	var horiz := ra.end.x <= rb.position.x
	if not horiz and not ra.end.y <= rb.position.y:
		return false
	var gap := (rb.position.x - ra.end.x) if horiz else (rb.position.y - ra.end.y)
	if gap < 1 or gap > 6:
		return false
	var lo := (maxi(ra.position.y, rb.position.y) if horiz else maxi(ra.position.x, rb.position.x)) + 1
	var hi := (mini(ra.end.y, rb.end.y) if horiz else mini(ra.end.x, rb.end.x)) - 2
	var floor_order := range(1, top + 1)
	Layouts._shuffle(c.dice, floor_order)
	var cands := []
	var f := 1
	for ff in floor_order:
		f = ff
		cands = _skybridge_cands(m, f, ra, rb, horiz, lo, hi)
		if not cands.is_empty():
			break
	if cands.is_empty():
		return false
	var pick: Array = cands[cands.size() / 2]
	var v2: Vector2i = pick[0] + pick[4]
	while v2 != pick[1]:
		m.set_t(f, v2.x, v2.y, TacMap.T.BRIDGE)
		v2 += pick[4]
	for k in 2:
		var w: Vector2i = pick[k]
		m.set_t(f, w.x, w.y, TacMap.T.DOOR)
		var st: Dictionary = a if k == 0 else b
		m.doors.append({"floor": f, "pos": w, "a": -1, "b": pick[2 + k], "security": false, "structure": st.id, "skybridge": true})
	return true


static func _skybridge_cands(m: TacMap, f: int, ra: Rect2i, rb: Rect2i, horiz: bool, lo: int, hi: int) -> Array:
	var cands := []
	for t in range(lo, hi + 1):
		var wa := Vector2i(ra.end.x - 1, t) if horiz else Vector2i(t, ra.end.y - 1)
		var wb := Vector2i(rb.position.x, t) if horiz else Vector2i(t, rb.position.y)
		var step := Vector2i(1, 0) if horiz else Vector2i(0, 1)
		var ia := wa - step
		var ib := wb + step
		if m.t(f, wa.x, wa.y) != TacMap.T.WALL or m.t(f, wb.x, wb.y) != TacMap.T.WALL:
			continue
		if m.t(f, ia.x, ia.y) != TacMap.T.FLOOR or m.t(f, ib.x, ib.y) != TacMap.T.FLOOR:
			continue
		var la := m.label(f, ia.x, ia.y)
		var lb := m.label(f, ib.x, ib.y)
		if la < 0 or lb < 0 or m.rooms[la].zone > TacMap.Zone.STAFF or m.rooms[lb].zone > TacMap.Zone.STAFF:
			continue
		var clear := true
		var v := wa + step
		while v != wb:
			if m.t(f, v.x, v.y) != TacMap.T.VOID:
				clear = false
			v += step
		if clear:
			cands.append([wa, wb, la, lb, step])
	return cands


## Footbridge over a road or tracks on floor `f`, with stairs at both ends. Straight line p0 → p1.
static func footbridge(c: Dictionary, p0: Vector2i, p1: Vector2i, f := 1) -> bool:
	var m: TacMap = c.m
	var step := Vector2i(signi(p1.x - p0.x), signi(p1.y - p0.y))
	var cells: Array[Vector2i] = []
	var v := p0
	while true:
		cells.append(v)
		if v == p1:
			break
		v += step
	for cell in cells:
		if f >= m.floors or m.t(f, cell.x, cell.y) != TacMap.T.VOID:
			return false
	for e in [p0, p1]:
		if m.t(0, e.x, e.y) != TacMap.T.OUTSIDE or m.has_cover_at(0, e):
			return false
	for cell in cells:
		m.set_t(f, cell.x, cell.y, TacMap.T.BRIDGE)
	for e in [p0, p1]:
		m.set_t(0, e.x, e.y, TacMap.T.STAIRS)
		m.set_t(f, e.x, e.y, TacMap.T.STAIRS)
		m.verticals.append({"type": "stairs", "pos": e, "from_floor": 0, "to_floor": f, "structure": -1})
		reserve(c, Rect2i(e - Vector2i.ONE, Vector2i(3, 3)))
	return true


## Mark two structures as related: after generation their NETs are linked with chance `p`
## (M2c review: NETs are mostly separate, sometimes linked).
static func related(c: Dictionary, sa: int, sb: int, p: float) -> void:
	c.related.append([sa, sb, p])


## Linked NETs (M2d review): a "socket" node in one structure's NET, hanging off one of its
## hubs below the vault, points at a hub in the related structure's NET. A runner who steps onto
## the socket crosses into the other NET (NetRun.cross).
static func _link_nets(c: Dictionary) -> void:
	var m: TacMap = c.m
	for r in c.related:
		var sa: int = r[0]
		var sb: int = r[1]
		if not (m.architectures.has(sa) and m.architectures.has(sb)) or c.dice.rng.randf() >= float(r[2]):
			continue
		var aa: NetArchitecture = m.architectures[sa]
		var ab: NetArchitecture = m.architectures[sb]
		# Bidirectional (M2e review): a socket on each side, each landing on the other, so you can
		# see where a crossing comes out.
		var hubs_a := aa.subnets.filter(func(s): return s.zone < TacMap.Zone.VAULT)
		var hubs_b := ab.subnets.filter(func(s): return s.zone < TacMap.Zone.VAULT)
		var ha: int = hubs_a[c.dice.rng.randi_range(0, hubs_a.size() - 1)].hub
		var hb: int = hubs_b[c.dice.rng.randi_range(0, hubs_b.size() - 1)].hub
		var sock := aa.add_node({"type": "socket", "zone": aa.nodes[ha].zone, "subnet": aa.nodes[ha].subnet, "target_structure": sb})
		var sock_b := ab.add_node({"type": "socket", "zone": ab.nodes[hb].zone, "subnet": ab.nodes[hb].subnet, "target_structure": sa})
		aa.nodes[sock]["target_node"] = sock_b
		ab.nodes[sock_b]["target_node"] = sock
		aa.link(ha, sock)
		ab.link(hb, sock_b)
		var to_hub := sock_b
		m.net_links.append({"a": sa, "a_node": sock, "b": sb, "b_node": to_hub})


## Parked cars parallel to the curb, in the outer lane next to each sidewalk only (M2d review:
## no cover in the middle of the road). Sparse: cars are rare in the Time of the Red.
static func curb_cars(c: Dictionary, r: Rect2i, horizontal: bool) -> void:
	var m: TacMap = c.m
	var lanes := [r.position.y + 1, r.end.y - 2] if horizontal else [r.position.x + 1, r.end.x - 2]
	for lane in lanes:
		var t: int = c.dice.rng.randi_range(0, 6)
		var span := r.size.x if horizontal else r.size.y
		while t < span - 2:
			# Cars are rare in the Time of the Red (user note): a few working ones, and the odd
			# stripped wreck left where it died.
			var roll: float = c.dice.rng.randf()
			if roll < 0.15:
				var rect := Rect2i(r.position.x + t, lane, 2, 1) if horizontal else Rect2i(lane, r.position.y + t, 1, 2)
				Furnish.try_prop(m, 0, rect, "car" if roll < 0.11 else "wreck", -1, {}, c.reserved)
			t += c.dice.rng.randi_range(4, 9)


## Paint a diagonal avenue (8 wide, sidewalks on both sides) across the map above the bottom road,
## with chance `chance`. Returns the cells buildings must keep clear of (avenue + 1 margin).
static func _diagonal_avenue(c: Dictionary, rw: int, chance: float) -> Dictionary:
	var m: TacMap = c.m
	var keep := {}
	if c.dice.rng.randf() >= float(c.p.get("diagonal_chance", chance)):
		return keep
	var x0 := float(c.dice.rng.randi_range(m.w / 5, m.w * 4 / 5))
	var ang: float = deg_to_rad(c.dice.rng.randf_range(25.0, 60.0)) * (1.0 if c.dice.d(2) == 1 else -1.0)
	var dir := Vector2(sin(ang), cos(ang))
	for y in m.h - rw:
		for x in m.w:
			var v := Vector2(x + 0.5 - x0, y + 0.5)
			var dist := absf(v.x * dir.y - v.y * dir.x)
			if dist <= 5.0:
				keep[Vector2i(x, y)] = true
			if dist <= 4.0:
				ground(c, Rect2i(x, y, 1, 1), G.SIDEWALK if dist > 3.0 else G.ASPHALT)
				if dist <= 1.0:
					c.reserved[Vector2i(x, y)] = true
	var bottom := x0 + (m.h - rw) * dir.x / dir.y
	spawn(c, Vector2i(clampi(int(x0), 0, m.w - 1), 0))
	if bottom >= 0 and bottom < m.w:
		spawn(c, Vector2i(int(bottom), m.h - rw))
	return keep


static func _rect_hits(r: Rect2i, cells: Dictionary) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if cells.has(Vector2i(x, y)):
				return true
	return false


## Cells of `shell` outside `avoid`, keeping only the largest 4-connected piece.
static func _largest_piece(shell: Rect2i, avoid: Dictionary) -> Dictionary:
	var free := {}
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			if not avoid.has(Vector2i(x, y)):
				free[Vector2i(x, y)] = true
	var best := {}
	var seen := {}
	for start in free:
		if seen.has(start):
			continue
		var comp := {start: true}
		seen[start] = true
		var q: Array = [start]
		while not q.is_empty():
			var v: Vector2i = q.pop_back()
			for d in MapGen.DIRS:
				var n: Vector2i = v + d
				if free.has(n) and not seen.has(n):
					seen[n] = true
					comp[n] = true
					q.append(n)
		if comp.size() > best.size():
			best = comp
	return best


## Shell with a triangle cut off one corner (a chamfered building).
static func _cut_corner(c: Dictionary, shell: Rect2i) -> Dictionary:
	var k := mini(shell.size.x, shell.size.y) / 3
	var corner: int = c.dice.d(4)
	var mask := {}
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			var dx := x - shell.position.x if corner in [1, 3] else shell.end.x - 1 - x
			var dy := y - shell.position.y if corner in [1, 2] else shell.end.y - 1 - y
			if dx + dy >= k:
				mask[Vector2i(x, y)] = true
	return mask


static func _unlabel(m: TacMap, room: Dictionary, cells: Dictionary) -> void:
	for v in cells:
		if m.label(0, v.x, v.y) == room.id:
			m.labels[0][v.y * m.w + v.x] = -1
			room.cells -= 1


## Crew deployment: the street spawn farthest from the target's main door becomes the player's
## insertion zone (the 6 nearest open squares); the other spawns stay reinforcement entry points.
static func _deploy_zone(c: Dictionary) -> void:
	var m: TacMap = c.m
	var door := Vector2i(m.w / 2, m.h / 2)
	for e in m.entrances:
		if e.main:
			door = e.pos
	var best := -1
	var best_d := -1
	for i in m.entrances.size():
		var e: Dictionary = m.entrances[i]
		if e.kind == "spawn" and m.walkable(0, e.pos):
			var dd := absi(e.pos.x - door.x) + absi(e.pos.y - door.y)
			if dd > best_d:
				best_d = dd
				best = i
	if best < 0:
		return
	var origin: Vector2i = m.entrances[best].pos
	m.entrances[best].kind = "deploy"
	var cells: Array = [origin]
	var seen := {origin: true}
	var q: Array = [origin]
	while not q.is_empty() and cells.size() < 6:
		var v: Vector2i = q.pop_front()
		for d in MapGen.DIRS:
			var n: Vector2i = v + d
			if not seen.has(n) and m.inb(n.x, n.y) and m.t(0, n.x, n.y) == TacMap.T.OUTSIDE and not m.has_cover_at(0, n):
				seen[n] = true
				q.append(n)
				if cells.size() < 6:
					cells.append(n)
	m.entrances[best]["cells"] = cells


## Guard posts for placing defenders in M3: the middle of guard rooms, and the secure side of
## every security door and gate.
const POST_ROOMS := ["security_office", "guard_booth", "armory", "vip_lounge", "bridge", "boss_room", "gangway_hall", "lobby", "compound_yard", "data_vault"]


static func _guard_posts(m: TacMap) -> void:
	for r in m.rooms:
		if r.cells == 0 or not r.kind in POST_ROOMS:
			continue
		var best := Vector2i(-1, -1)
		var mid: Vector2i = (r.bounds as Rect2i).get_center()
		for v in Furnish.room_cells(m, r):
			if m.walkable(r.floor, v) and (best.x < 0 or v.distance_squared_to(mid) < best.distance_squared_to(mid)):
				best = v
		if best.x >= 0:
			m.posts.append({"floor": r.floor, "pos": best, "structure": r.structure, "zone": r.zone, "kind": r.kind})
	for d in m.doors:
		if not d.security:
			continue
		for n in MapGen.DIRS:
			var v: Vector2i = d.pos + n
			var l := m.label(d.floor, v.x, v.y)
			if l == d.b and m.walkable(d.floor, v):
				m.posts.append({"floor": d.floor, "pos": v, "structure": d.structure, "zone": m.rooms[l].zone, "kind": "door"})
				break


static func _rand_size(c: Dictionary, lo: int, hi: int) -> int:
	return c.dice.rng.randi_range(lo, hi)


# --- Scenes ----------------------------------------------------------------------

## The original: one building on a street corner (street south, alley east).
static func _lone_building(c: Dictionary) -> void:
	var m: TacMap = c.m
	ground(c, Rect2i(0, m.h - 3, m.w, 3), G.ASPHALT)
	ground(c, Rect2i(m.w - 3, 0, 3, m.h), G.GRAVEL)
	building(c, Rect2i(0, 0, m.w - 3, m.h - 3), String(c.p.get("site", "corp_office")), int(c.p.floors), int(c.p.security), true, TacMap.Zone.PUBLIC, "S")
	spawn(c, Vector2i(0, m.h - 2))
	spawn(c, Vector2i(m.w - 2, 0))


## City blocks on a road grid (bx × by blocks; a road always runs along the south edge). Each
## block is split by an alley into lots holding buildings of mixed type and height; a few lots
## stay parking lots. The biggest lot is the target. Skybridges join neighbouring buildings
## above street level and footbridges cross the roads. street_block = 2×1, city_district = 4×3.
static func _city(c: Dictionary, bx: int, by: int) -> void:
	var m: TacMap = c.m
	var fl := int(c.p.floors)
	var rw := 8
	var xs := _splits(c, m.w, bx, rw)
	var ys := _splits(c, m.h - rw, by, rw)
	var roads_h: Array[Rect2i] = [Rect2i(0, m.h - rw, m.w, rw)]
	var roads_v: Array[Rect2i] = []
	for i in range(1, xs.size()):
		roads_v.append(Rect2i(xs[i - 1].y, 0, xs[i].x - xs[i - 1].y, m.h - rw))
	for j in range(1, ys.size()):
		roads_h.append(Rect2i(0, ys[j - 1].y, m.w, ys[j].x - ys[j - 1].y))
	for r in roads_v:
		road(c, r, false)
	for r in roads_h:
		road(c, r, true)
	var lots: Array[Rect2i] = []
	for xr in xs:
		for yr in ys:
			var block := Rect2i(xr.x, yr.x, xr.y - xr.x, yr.y - yr.x)
			ground(c, block, G.SIDEWALK)
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
	var others := ["apartments", "club", "shop", "gang_hideout", "warehouse", "apartments", "shop", "corp_office"]
	var parking := {}
	if lots.size() >= 4:
		parking[lots.size() - 1] = true
	for i in range(1, lots.size() - 1):
		if lots.size() > 12 and c.dice.rng.randf() < 0.1:
			parking[i] = true
	# M2d review: break the grid. Sometimes a diagonal avenue cuts across the blocks; lots it slices
	# keep their largest piece as a clipped footprint (or become parking), and a few other
	# buildings get a cut corner.
	var margin := _diagonal_avenue(c, rw, 0.25 if bx * by <= 2 else 0.6)
	var blds: Array[Dictionary] = []
	for i in lots.size():
		var shell := lots[i].grow(-1)
		if shell.size.x < 7 or shell.size.y < 7:
			continue
		var mask := {}
		var area := shell.get_area()
		if not margin.is_empty() and _rect_hits(lots[i], margin):
			mask = _largest_piece(shell, margin)
			if mask.size() < area * 0.55 or mask.size() < 60:
				parking[i] = true
		elif c.dice.rng.randf() < 0.15 and mini(shell.size.x, shell.size.y) >= 12:
			mask = _cut_corner(c, shell)
		if parking.has(i):
			var lot_sid := outdoor_structure(c, "lot", 0, lots[i])
			var lot_room := yard(c, lots[i], "parking_lot", TacMap.Zone.PUBLIC, lot_sid)
			_unlabel(m, lot_room, margin)
			Furnish.run_structure(m, c.dice, lot_sid)
			continue
		var target := i == 0
		var site: String = String(c.p.get("site", "corp_office")) if target else others[c.dice.rng.randi_range(0, others.size() - 1)]
		var floors: int = fl if target else c.dice.rng.randi_range(1, fl)
		blds.append(building(c, shell, site, floors, int(c.p.security) if target else c.dice.rng.randi_range(0, 1), target, TacMap.Zone.PUBLIC, "", mask))
	# Skybridges between neighbouring buildings (two storeys or more), roughly one per four.
	var pairs := []
	for i in blds.size():
		for j in range(i + 1, blds.size()):
			pairs.append([blds[i], blds[j]])
	Layouts._shuffle(c.dice, pairs)
	var bridges := 0
	for pr in pairs:
		if bridges >= maxi(1, blds.size() / 4):
			break
		if c.dice.rng.randf() < 0.7 and skybridge(c, pr[0], pr[1]):
			bridges += 1
			related(c, pr[0].id, pr[1].id, 0.7)  # bridged buildings likely share an owner
	# Footbridges over the roads, then street life: parked cars, dumpsters in the alleys.
	for r in roads_h:
		for tries in 20:
			var x: int = c.dice.rng.randi_range(4, m.w - 5)
			if roads_v.any(func(v): return x >= v.position.x - 1 and x < v.end.x + 1):
				continue
			if footbridge(c, Vector2i(x, r.position.y), Vector2i(x, r.end.y - 1)):
				break
	for r in roads_h:
		curb_cars(c, r, true)
	for r in roads_v:
		curb_cars(c, r, false)
	for y in m.h:
		for x in m.w:
			if m.ground[y * m.w + x] == G.GRAVEL and c.dice.rng.randf() < 0.012:
				Furnish.try_prop(m, 0, Rect2i(x, y, 1, 1), "dumpster", -1, {}, c.reserved)
	for r in roads_h:
		spawn(c, Vector2i(0, r.position.y + 3))
		spawn(c, Vector2i(m.w - 1, r.position.y + 3))
	for r in roads_v:
		spawn(c, Vector2i(r.position.x + 3, 0))


## Split `total` into n spans separated by `gap`, inner boundaries jittered. Returns [start, end) pairs.
static func _splits(c: Dictionary, total: int, n: int, gap: int) -> Array[Vector2i]:
	var size := (total - (n - 1) * gap) / n
	var out: Array[Vector2i] = []
	var x := 0
	for i in n:
		var w: int = size if i < n - 1 else total - x
		if i < n - 1:
			w += _rand_size(c, -4, 4)
		out.append(Vector2i(x, x + w))
		x += w + gap
	return out


## Megablock: a long apartment tower over a courtyard, with a parking lot and a corner shop.
static func _megablock(c: Dictionary) -> void:
	var m: TacMap = c.m
	road(c, Rect2i(0, m.h - 7, m.w, 7), true)
	road(c, Rect2i(m.w - 7, 0, 7, m.h - 7), false)
	ground(c, Rect2i(0, 0, m.w - 7, m.h - 7), G.CONCRETE)
	var tower := Rect2i(2, 2, m.w - 13, m.h / 2 - 2)
	var tower_st := building(c, tower, "apartments", int(c.p.floors), int(c.p.security), true, TacMap.Zone.PUBLIC, "S")
	var shop := Rect2i(2, m.h - 7 - 12, 14, 11)
	building(c, shop, "shop", 1, 0)
	var sid := outdoor_structure(c, "courtyard", 0, Rect2i(0, tower.end.y, m.w - 7, m.h - 7 - tower.end.y))
	ground(c, Rect2i(18, tower.end.y + 1, m.w - 7 - 18 - 20, m.h - 7 - tower.end.y - 2), G.GRASS)
	yard(c, Rect2i(18, tower.end.y + 1, m.w - 7 - 18 - 20, m.h - 7 - tower.end.y - 2), "courtyard", TacMap.Zone.PUBLIC, sid)
	yard(c, Rect2i(m.w - 27, tower.end.y + 1, 19, m.h - 7 - tower.end.y - 2), "parking_lot", TacMap.Zone.PUBLIC, sid)
	Furnish.run_structure(m, c.dice, sid)
	if m.devices.any(func(d): return d.structure == sid):
		m.architectures[sid] = NetGen.generate(m, c.dice, sid)
	related(c, tower_st.id, sid, 0.7)
	curb_cars(c, Rect2i(0, m.h - 7, m.w - 7, 7), true)
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
	var ship_st := building(c, ship, "ship", int(c.p.floors), sec, true, TacMap.Zone.STAFF, "S")
	# Compound: everything between quay and road, fenced with one gate.
	var comp := Rect2i(0, sea_h, m.w, road_y - sea_h)
	var sid := outdoor_structure(c, "compound", maxi(sec - 1, 0), comp)
	var gate := Vector2i(m.w / 2, road_y - 1)
	reserve(c, Rect2i(gate.x - 1, gate.y - 3, 3, 4))
	var wh := Rect2i(m.w - 30, sea_h + 9, 26, road_y - sea_h - 13)
	var wh_st := building(c, wh, "warehouse", 1, maxi(sec - 1, 0), false, TacMap.Zone.STAFF)
	var booth := Rect2i(gate.x + 3, road_y - 8, 6, 5)  # leave open ground between booth and fence
	var booth_st := building(c, booth, "guard_booth", 1, maxi(sec - 1, 0), false, TacMap.Zone.STAFF)
	related(c, ship_st.id, sid, 0.8)
	related(c, wh_st.id, sid, 0.7)
	related(c, booth_st.id, sid, 0.9)
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
	var hide_st := building(c, Rect2i(inner.position.x + inner.size.x / 2 - 9, inner.position.y, 18, 12), "gang_hideout", 1, sec, true, TacMap.Zone.STAFF)
	related(c, hide_st.id, sid, 0.9)
	var placed: Array[Rect2i] = [Rect2i(inner.position.x + inner.size.x / 2 - 9, inner.position.y, 18, 12)]
	for k in 60:
		if placed.size() >= 6:
			break
		var s := Rect2i(c.dice.rng.randi_range(inner.position.x, inner.end.x - 8), c.dice.rng.randi_range(inner.position.y, inner.end.y - 9),
			_rand_size(c, 6, 8), _rand_size(c, 5, 7))
		if placed.all(func(o): return not o.grow(1).intersects(s.grow(1))) and inner.encloses(s) and s.position.y + s.size.y < gate.y - 3:
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
	var train_st := building(c, train, "train", 1, sec, true, TacMap.Zone.PUBLIC, "S")
	# Footbridge from the platform over all tracks, stairs at both ends.
	var plat0: int = tracks[3] + 4
	for tries in 20:
		var bx: int = c.dice.rng.randi_range(10, m.w - 11)
		# One level above the train's roof (you can climb onto the train, too).
		if footbridge(c, Vector2i(bx, plat0), Vector2i(bx, 1), 2):
			break
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
	var station_st := building(c, station, "station", int(c.p.floors), maxi(sec - 1, 0), false, TacMap.Zone.PUBLIC, "N")
	related(c, train_st.id, station_st.id, 0.8)
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
	var hq_st := building(c, hq, "corp_hq", int(c.p.floors), sec, true, TacMap.Zone.PUBLIC, "S")
	var svc := Rect2i(hq.end.x - 14, hq.end.y + 4, grounds.end.x - 3 - (hq.end.x - 14), 12)
	var svc_st := building(c, svc, "warehouse", 2, maxi(sec - 1, 0), false, TacMap.Zone.PUBLIC)
	skybridge(c, hq_st, svc_st)
	var booth := Rect2i(gate.x + 3, grounds.end.y - 7, 6, 5)
	var booth_st := building(c, booth, "guard_booth", 1, maxi(sec - 1, 0), false, TacMap.Zone.PUBLIC)
	related(c, booth_st.id, hq_st.id, 0.9)
	related(c, sid, hq_st.id, 0.7)
	var plaza := yard(c, Rect2i(hq.position.x, hq.end.y, hq.size.x, 6), "plaza", TacMap.Zone.PUBLIC, sid)
	var park := yard(c, Rect2i(grounds.position.x + 1, hq.end.y + 6, svc.position.x - grounds.position.x - 3, grounds.end.y - hq.end.y - 7), "parking_lot", TacMap.Zone.PUBLIC, sid)
	yard(c, grounds.grow(-1), "courtyard", TacMap.Zone.PUBLIC, sid)
	fence(c, grounds, [gate], park, 3)
	m.doors[-1].b = m.label(0, gate.x, gate.y - 1)
	Furnish.run_structure(m, c.dice, sid)
	if m.devices.any(func(d): return d.structure == sid):
		m.architectures[sid] = NetGen.generate(m, c.dice, sid)
	curb_cars(c, Rect2i(0, m.h - 7, m.w, 7), true)
	spawn(c, Vector2i(0, m.h - 3))
	spawn(c, Vector2i(m.w - 1, m.h - 3))
