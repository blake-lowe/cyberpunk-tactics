class_name DistrictGen
extends RefCounted
## City neighbourhoods from a profile (data/gen/districts.json): roads are polylines and circles
## of any angle rasterised onto the grid (grid / organic / radial patterns, plus diagonal avenues
## and curves), blocks are whatever the roads leave, lots come from splitting blocks (with alleys),
## and each lot gets a building or an outdoor use from the profile's mix. Buildings use any
## footprint (clipped lots, L/U/T/courtyard shapes) and the profile's decay for ruined areas.

const G := TacMap.G
const YARDS := {"market": [G.CONCRETE, "market"], "park": [G.GRASS, "park"], "plaza": [G.CONCRETE, "plaza"],
	"parking_lot": [G.ASPHALT, "parking_lot"], "rubble_field": [G.DIRT, "rubble_field"], "substation": [G.GRAVEL, "substation_yard"]}


static func generate(c: Dictionary, profile_name: String) -> void:
	var m: TacMap = c.m
	var prof: Dictionary = RulesDB.gen("districts.json")[profile_name]
	c.p["profile"] = profile_name
	SceneGen.ground(c, Rect2i(0, 0, m.w, m.h), G.SIDEWALK)
	var roads := {}
	var hw := float(prof.road_w) / 2.0
	var lines := _road_network(c, prof, hw)
	for ln in lines:
		_raster(c, ln, roads)
	var lots := _lots(c, prof, roads)
	_fill_lots(c, prof, lots)
	_footbridges(c, lines)
	_parked(c, prof, roads)
	_edge_spawns(c)


# --- Road networks -------------------------------------------------------------
# A road is {pts: Array[Vector2], hw: float} (a polyline) or {center, r, hw} (a ring).

static func _road_network(c: Dictionary, prof: Dictionary, hw: float) -> Array:
	var m: TacMap = c.m
	var lines := []
	var b: Array = prof.block
	match String(prof.pattern):
		"grid":
			var x := float(c.dice.rng.randi_range(b[0], b[1])) * 0.6
			while x < m.w - 6:
				var full: bool = c.dice.rng.randf() > 0.15
				var y_end := float(m.h) if full else float(c.dice.rng.randi_range(m.h / 3, m.h))
				lines.append({"pts": [Vector2(x, 0), Vector2(x + c.dice.rng.randf_range(-2, 2), y_end)], "hw": hw, "straight": true})
				x += float(c.dice.rng.randi_range(b[0], b[1])) + hw * 2
			var y := float(c.dice.rng.randi_range(b[0], b[1])) * 0.6
			while y < m.h - 6:
				var full2: bool = c.dice.rng.randf() > 0.15
				var x_end := float(m.w) if full2 else float(c.dice.rng.randi_range(m.w / 3, m.w))
				lines.append({"pts": [Vector2(0, y), Vector2(x_end, y + c.dice.rng.randf_range(-2, 2))], "hw": hw, "straight": true, "horizontal": true})
				y += float(c.dice.rng.randi_range(b[0], b[1])) + hw * 2
		"organic":
			var n := maxi(3, roundi(m.w * m.h / float(b[1] * b[1]) / 1.6))
			for i in n:
				lines.append({"pts": _wander(c, Vector2(m.w, m.h)), "hw": hw})
			var all_pts := []
			for ln in lines:
				all_pts.append_array(ln.pts)
			for i in n:
				var a: Vector2 = all_pts[c.dice.rng.randi_range(0, all_pts.size() - 1)]
				var best := Vector2.INF
				for p2 in all_pts:
					var d: float = a.distance_to(p2)
					if d > b[0] * 0.8 and d < b[1] * 1.4 and d < a.distance_to(best):
						best = p2
				if best != Vector2.INF:
					lines.append({"pts": [a, best], "hw": hw - 1.0})
		"radial":
			var center := Vector2(m.w / 2.0 + c.dice.rng.randf_range(-8, 8), m.h / 2.0 + c.dice.rng.randf_range(-6, 6))
			var r0: float = c.dice.rng.randf_range(7, 10)
			lines.append({"center": center, "r": r0 + hw, "hw": hw})
			var ring := minf(m.w, m.h) * 0.33
			lines.append({"center": center, "r": ring, "hw": hw})
			var spokes: int = c.dice.rng.randi_range(5, 7)
			var a0: float = c.dice.rng.randf_range(0, TAU)
			for i in spokes:
				var ang: float = a0 + TAU * i / spokes + c.dice.rng.randf_range(-0.2, 0.2)
				var dir := Vector2(cos(ang), sin(ang))
				lines.append({"pts": [center + dir * (r0 + hw), center + dir * maxf(m.w, m.h)], "hw": hw})
			c["plaza_center"] = center
			c["plaza_r"] = r0
	# Overlays that break any pattern.
	if c.dice.rng.randf() < float(c.p.get("diagonal_chance", prof.diag)):
		var x0: float = c.dice.rng.randf_range(m.w * 0.2, m.w * 0.8)
		var ang2 := deg_to_rad(c.dice.rng.randf_range(25, 60)) * (1.0 if c.dice.d(2) == 1 else -1.0)
		lines.append({"pts": [Vector2(x0, 0), Vector2(x0 + tan(ang2) * m.h, m.h)], "hw": hw})
	if c.dice.rng.randf() < float(prof.curve):
		var p0 := Vector2(0, c.dice.rng.randf_range(m.h * 0.2, m.h * 0.8))
		var p2 := Vector2(m.w, c.dice.rng.randf_range(m.h * 0.2, m.h * 0.8))
		var p1 := Vector2(m.w / 2.0, c.dice.rng.randf_range(-m.h * 0.3, m.h * 1.3))
		var pts := []
		for i in 25:
			var t := i / 24.0
			pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
		lines.append({"pts": pts, "hw": hw})
	return lines


## A wandering arterial from one edge across the map.
static func _wander(c: Dictionary, size: Vector2) -> Array:
	var side: int = c.dice.d(4)
	var p := Vector2(c.dice.rng.randf_range(0, size.x), 0) if side == 1 else Vector2(c.dice.rng.randf_range(0, size.x), size.y) if side == 2 \
		else Vector2(0, c.dice.rng.randf_range(0, size.y)) if side == 3 else Vector2(size.x, c.dice.rng.randf_range(0, size.y))
	var ang: float = (size / 2.0 - p).angle() + c.dice.rng.randf_range(-0.5, 0.5)
	var pts := [p]
	for i in 200:
		ang += c.dice.rng.randf_range(-0.22, 0.22)
		p += Vector2(cos(ang), sin(ang)) * 6.0
		pts.append(p)
		if p.x < -4 or p.y < -4 or p.x > size.x + 4 or p.y > size.y + 4:
			break
	return pts


## Rasterise a road: asphalt core, sidewalk edge, centre lanes reserved (no props).
static func _raster(c: Dictionary, ln: Dictionary, roads: Dictionary) -> void:
	var m: TacMap = c.m
	var hw: float = ln.hw
	if ln.has("center"):
		var ctr: Vector2 = ln.center
		var r: float = ln.r
		for y in range(maxi(0, int(ctr.y - r - hw - 1)), mini(m.h, int(ctr.y + r + hw + 2))):
			for x in range(maxi(0, int(ctr.x - r - hw - 1)), mini(m.w, int(ctr.x + r + hw + 2))):
				_road_cell(c, roads, Vector2i(x, y), absf(Vector2(x + 0.5, y + 0.5).distance_to(ctr) - r), hw)
		return
	var pts: Array = ln.pts
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(hw + 1, hw + 1)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(hw + 1, hw + 1)
		for y in range(maxi(0, int(lo.y)), mini(m.h, int(hi.y) + 1)):
			for x in range(maxi(0, int(lo.x)), mini(m.w, int(hi.x) + 1)):
				var q := Vector2(x + 0.5, y + 0.5)
				_road_cell(c, roads, Vector2i(x, y), q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)), hw)


static func _road_cell(c: Dictionary, roads: Dictionary, v: Vector2i, d: float, hw: float) -> void:
	if d > hw:
		return
	var m: TacMap = c.m
	var core := d <= hw - 1.0
	if core or not roads.has(v):
		m.set_ground(v.x, v.y, G.ASPHALT if core else G.SIDEWALK)
	if core:
		roads[v] = true
	elif not roads.has(v):
		roads[v] = false  # sidewalk edge of a road
	if d <= 1.0:
		c.reserved[v] = true


# --- Blocks and lots -------------------------------------------------------------

static func _lots(c: Dictionary, prof: Dictionary, roads: Dictionary) -> Array:
	var m: TacMap = c.m
	var seen := {}
	var lots := []
	var b: Array = prof.block
	for y in m.h:
		for x in m.w:
			var v := Vector2i(x, y)
			if roads.has(v) or seen.has(v):
				continue
			var block := {v: true}
			seen[v] = true
			var q: Array = [v]
			var bb := Rect2i(v, Vector2i.ONE)
			while not q.is_empty():
				var u: Vector2i = q.pop_back()
				bb = bb.expand(u).expand(u + Vector2i.ONE)
				for d in MapGen.DIRS:
					var n: Vector2i = u + d
					if m.inb(n.x, n.y) and not roads.has(n) and not seen.has(n):
						seen[n] = true
						block[n] = true
						q.append(n)
			if block.size() >= 30:
				_split(c, block, bb, int(b[1] * 0.7), float(prof.alley), lots)
	return lots


static func _split(c: Dictionary, block: Dictionary, r: Rect2i, lot_max: int, alley: float, out: Array) -> void:
	if r.size.x <= lot_max and r.size.y <= lot_max or r.size.x < 16 and r.size.y < 16:
		var cells := {}
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if block.has(Vector2i(x, y)):
					cells[Vector2i(x, y)] = true
		if cells.size() >= 30:
			out.append(cells)
		return
	var vertical := r.size.x >= r.size.y
	var span := r.size.x if vertical else r.size.y
	var cut := int(span * c.dice.rng.randf_range(0.35, 0.65))
	var gap := 2 if c.dice.rng.randf() < alley else 0
	if gap > 0:
		var g := Rect2i(r.position.x + cut, r.position.y, gap, r.size.y) if vertical else Rect2i(r.position.x, r.position.y + cut, r.size.x, gap)
		for y in range(g.position.y, g.end.y):
			for x in range(g.position.x, g.end.x):
				if block.has(Vector2i(x, y)):
					c.m.set_ground(x, y, G.GRAVEL)
	var a := Rect2i(r.position, Vector2i(cut, r.size.y)) if vertical else Rect2i(r.position, Vector2i(r.size.x, cut))
	var b := Rect2i(r.position.x + cut + gap, r.position.y, r.size.x - cut - gap, r.size.y) if vertical \
		else Rect2i(r.position.x, r.position.y + cut + gap, r.size.x, r.size.y - cut - gap)
	_split(c, block, a, lot_max, alley, out)
	_split(c, block, b, lot_max, alley, out)


## Fill lots: erode by one square (a walkway around every lot), keep the largest piece, then a
## building or an outdoor use by the profile's mix. The largest suitable lot holds the target.
static func _fill_lots(c: Dictionary, prof: Dictionary, lots: Array) -> void:
	var m: TacMap = c.m
	var pieces := []
	for cells in lots:
		var er := {}
		for v in cells:
			if MapGen.DIRS.all(func(d): return cells.has(v + d)):
				er[v] = true
		var piece := SceneGen._largest_piece(_bbox(er), _complement(er))
		if piece.size() >= 40:
			pieces.append(piece)
	pieces.sort_custom(func(a, b): return a.size() > b.size())
	var mix: Dictionary = prof.mix
	var names := mix.keys()
	var wts := PackedFloat32Array()
	for n in names:
		wts.append(float(mix[n]))
	var fl := int(c.p.floors)
	var target_site: String = String(c.overrides.get("site", prof.target))
	var target_done := false
	var blds: Array[Dictionary] = []
	for piece in pieces:
		var bb := _bbox(piece)
		var use: String = names[c.dice.rng.rand_weighted(wts)]
		var is_target := not target_done and mini(bb.size.x, bb.size.y) >= 12
		if is_target:
			use = target_site
			target_done = true
		if YARDS.has(use) or mini(bb.size.x, bb.size.y) < 7:
			_yard_lot(c, piece, use if YARDS.has(use) else "plaza")
			continue
		if not is_target and not use in BIG_SITES and maxi(bb.size.x, bb.size.y) >= 15 and c.dice.rng.randf() < float(prof.get("cluster", 0.0)):
			_cluster(c, prof, piece, bb, names, wts, fl, blds)
			continue
		var mask: Dictionary = {} if piece.size() == bb.get_area() else piece
		var floors: int = fl if is_target else c.dice.rng.randi_range(int(prof.floors[0]), mini(int(prof.floors[1]), fl))
		var sec: int = int(c.p.security) if is_target else c.dice.rng.randi_range(int(prof.security[0]), int(prof.security[1]))
		c["decay"] = c.dice.rng.randf_range(float(prof.decay[0]), float(prof.decay[1]))
		blds.append(SceneGen.building(c, bb, use, floors, sec, is_target, TacMap.Zone.PUBLIC, "", mask))
		c.erase("decay")
	# Skybridges between neighbours; bridged buildings are often linked in the NET too.
	var bridges := 0
	for i in blds.size():
		for j in range(i + 1, blds.size()):
			if bridges < maxi(1, blds.size() / 5) and c.dice.rng.randf() < 0.5 and SceneGen.skybridge(c, blds[i], blds[j]):
				bridges += 1
				SceneGen.related(c, blds[i].id, blds[j].id, 0.7)


## Sites that keep one big building per lot (owner: corp and industrial stay big).
const BIG_SITES := ["corp_office", "corp_hq", "warehouse", "factory", "data_center", "station"]


## A lot of small buildings (owner round 6: big flat blocks were dull): the lot is cut into plots
## of 7-12 squares with 1-2 square gravel passages between, each plot its own building, each a
## different height from the one before. Plots too small or too clipped stay open ground.
static func _cluster(c: Dictionary, prof: Dictionary, piece: Dictionary, bb: Rect2i, names: Array, wts: PackedFloat32Array, fl: int, blds: Array) -> void:
	var plots: Array[Rect2i] = []
	_cut(c, piece, bb, plots)
	var last_floors := -1
	for r in plots:
		var mask := {}
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if piece.has(Vector2i(x, y)):
					mask[Vector2i(x, y)] = true
		if mask.size() < 40 or mini(r.size.x, r.size.y) < 7:
			continue
		var use := "shop"
		for k in 8:
			var u: String = names[c.dice.rng.rand_weighted(wts)]
			if not YARDS.has(u) and not u in BIG_SITES:
				use = u
				break
		var lo := int(prof.floors[0])
		var hi := mini(int(prof.floors[1]), fl)
		var floors: int = c.dice.rng.randi_range(lo, hi)
		if floors == last_floors and hi > lo:   # neighbours differ: a broken skyline
			floors = lo + (floors - lo + 1 + c.dice.rng.randi_range(0, hi - lo - 1)) % (hi - lo + 1)
		last_floors = floors
		var sec: int = c.dice.rng.randi_range(int(prof.security[0]), int(prof.security[1]))
		c["decay"] = c.dice.rng.randf_range(float(prof.decay[0]), float(prof.decay[1]))
		blds.append(SceneGen.building(c, r, use, floors, sec, false, TacMap.Zone.PUBLIC, "", {} if mask.size() == r.get_area() else mask))
		c.erase("decay")


static func _cut(c: Dictionary, piece: Dictionary, r: Rect2i, out: Array[Rect2i]) -> void:
	var vertical := r.size.x >= r.size.y
	var span := r.size.x if vertical else r.size.y
	var gap := 1 if c.dice.rng.randf() < 0.6 else 2
	if (r.size.x <= 12 and r.size.y <= 12) or span - gap < 14:
		out.append(r)
		return
	var cut: int = c.dice.rng.randi_range(7, span - 7 - gap)
	var g := Rect2i(r.position.x + cut, r.position.y, gap, r.size.y) if vertical else Rect2i(r.position.x, r.position.y + cut, r.size.x, gap)
	for y in range(g.position.y, g.end.y):
		for x in range(g.position.x, g.end.x):
			if piece.has(Vector2i(x, y)):
				c.m.set_ground(x, y, G.GRAVEL)
	_cut(c, piece, Rect2i(r.position, Vector2i(cut, r.size.y)) if vertical else Rect2i(r.position, Vector2i(r.size.x, cut)), out)
	_cut(c, piece, Rect2i(r.position.x + cut + gap, r.position.y, r.size.x - cut - gap, r.size.y) if vertical
		else Rect2i(r.position.x, r.position.y + cut + gap, r.size.x, r.size.y - cut - gap), out)


static func _yard_lot(c: Dictionary, cells: Dictionary, use: String) -> void:
	var m: TacMap = c.m
	var spec: Array = YARDS[use]
	for v in cells:
		m.set_ground(v.x, v.y, spec[0])
	var sid := SceneGen.outdoor_structure(c, use, 0 if use != "substation" else 1, _bbox(cells))
	var id: int = c.hints.size()
	c.hints.append({"zone_hint": TacMap.Zone.PUBLIC, "kind": spec[1], "floor": 0})
	while m.rooms.size() < id:
		m.rooms.append({"id": m.rooms.size(), "floor": -1, "zone": -1, "kind": "void", "cells": 0, "bounds": Rect2i(), "structure": -1})
	var zone := TacMap.Zone.STAFF if use == "substation" else TacMap.Zone.PUBLIC
	var room := {"id": id, "floor": 0, "zone": zone, "kind": spec[1], "cells": 0, "bounds": _bbox(cells), "structure": sid, "outdoor": true}
	m.rooms.append(room)
	for v in cells:
		if m.t(0, v.x, v.y) == TacMap.T.OUTSIDE and m.label(0, v.x, v.y) < 0:
			m.labels[0][v.y * m.w + v.x] = id
			room.cells += 1
	if use == "substation":
		# Fenced: the lot's outer ring becomes fence with one gate toward the street.
		var bb := _bbox(cells)
		var gate := Vector2i(-1, -1)
		for v in cells:
			var edge := MapGen.DIRS.any(func(d): return not cells.has(v + d))
			if edge:
				m.set_t(0, v.x, v.y, TacMap.T.WALL)
				m.wall_mat[0][v.y * m.w + v.x] = 3
				m.labels[0][v.y * m.w + v.x] = -1
				room.cells -= 1
				if gate.x < 0 and v.y == bb.end.y - 1 and v.x > bb.position.x + 1 and v.x < bb.end.x - 2:
					gate = v
		if gate.x < 0:
			for v in cells:
				if m.t(0, v.x, v.y) == TacMap.T.WALL and MapGen.DIRS.any(func(d): return m.t(0, v.x + d.x, v.y + d.y) == TacMap.T.OUTSIDE and m.label(0, v.x + d.x, v.y + d.y) == -1) \
						and MapGen.DIRS.any(func(d): return m.label(0, v.x + d.x, v.y + d.y) == id):
					gate = v
					break
		if gate.x >= 0:
			m.set_t(0, gate.x, gate.y, TacMap.T.DOOR)
			m.doors.append({"floor": 0, "pos": gate, "a": -1, "b": id, "security": false, "structure": sid, "gate": true})
	Furnish.run_structure(m, c.dice, sid)
	if m.devices.any(func(d): return d.structure == sid) and use == "substation":
		m.architectures[sid] = NetGen.generate(m, c.dice, sid)


static func _bbox(cells: Dictionary) -> Rect2i:
	var r := Rect2i()
	var first := true
	for v in cells:
		if first:
			r = Rect2i(v, Vector2i.ONE)
			first = false
		else:
			r = r.expand(v).expand(v + Vector2i.ONE)
	return r


static func _complement(cells: Dictionary) -> Dictionary:
	var bb := _bbox(cells)
	var out := {}
	for y in range(bb.position.y, bb.end.y):
		for x in range(bb.position.x, bb.end.x):
			if not cells.has(Vector2i(x, y)):
				out[Vector2i(x, y)] = true
	return out


# --- Street furniture ------------------------------------------------------------

## Footbridges across straight horizontal grid roads.
static func _footbridges(c: Dictionary, lines: Array) -> void:
	var m: TacMap = c.m
	for ln in lines:
		if not ln.get("horizontal", false):
			continue
		var y := int(ln.pts[0].y)
		var h := int(ln.hw)
		for tries in 20:
			var x: int = c.dice.rng.randi_range(4, m.w - 5)
			if SceneGen.footbridge(c, Vector2i(x, y - h), Vector2i(x, y + h - 1)):
				break


## Sparse parked cars (and wrecks) in curb lanes: asphalt next to sidewalk, parallel to the road.
static func _parked(c: Dictionary, prof: Dictionary, roads: Dictionary) -> void:
	var m: TacMap = c.m
	var rate := float(prof.cars) * 0.06
	for v in roads:
		if not roads[v] or c.dice.rng.randf() >= rate:
			continue
		for d in MapGen.DIRS:
			if roads.get(v + d, true) == false:
				var horiz := d.y != 0
				var piece := "wreck" if c.dice.rng.randf() < float(prof.wreck_ratio) else "car"
				var fp := Vector2i(2, 1) if horiz else Vector2i(1, 2)
				if piece == "wreck":
					fp = Vector2i(2, 2)
				Furnish.try_prop(m, 0, Rect2i(v, fp), piece, -1, {}, c.reserved)
				break


## Reinforcement spawns where roads leave the map, spread around the edge.
static func _edge_spawns(c: Dictionary) -> void:
	var m: TacMap = c.m
	var cands := []
	for v in c.reserved:
		if (v.x == 0 or v.y == 0 or v.x == m.w - 1 or v.y == m.h - 1) and m.walkable(0, v):
			cands.append(v)
	if cands.is_empty():
		SceneGen.spawn(c, Vector2i(0, m.h / 2))
		return
	var ctr := Vector2(m.w / 2.0, m.h / 2.0)
	cands.sort_custom(func(a, b): return (Vector2(a) - ctr).angle() < (Vector2(b) - ctr).angle())
	var n := mini(5, cands.size())
	for i in n:
		SceneGen.spawn(c, cands[i * cands.size() / n])
