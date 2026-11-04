class_name Furnish
extends RefCounted
## Places cover, props and hackable devices by room kind (indoor rooms and outdoor yards alike).
## Cover HP comes from the material table (p182); pieces are matched to the book's examples
## (p183): desks/tables ≈ overturned table (wood thin 5), sofa (plaster thick 15), cabinets,
## fridges, racks, cars and containers (steel thin 25), pillars and barriers (concrete thick 25),
## safes and crane legs (steel thick 50), boulders (stone thick 40).
## Every placement keeps its room fully connected: no blocked doors, no sealed pockets.

## piece → [material, thick]
const PIECES := {
	"desk": ["wood", false], "table": ["wood", false], "reception": ["wood", true],
	"sofa": ["plaster", true], "planter": ["stone", false], "pillar": ["concrete", true],
	"cabinet": ["steel", false], "vending": ["steel", false], "fridge": ["steel", false],
	"locker": ["steel", false], "rack": ["steel", false], "bench": ["steel", false],
	"crate": ["wood", true], "safe": ["steel", true], "shelf": ["steel", false],
	"seat": ["wood", false], "bed": ["wood", false], "console": ["steel", false],
	# outdoor
	"car": ["steel", false], "dumpster": ["steel", false], "barrier": ["concrete", true],
	"container": ["steel", false], "boulder": ["stone", true], "wreck": ["steel", false],
	"barrel": ["steel", false], "pallet": ["wood", false], "sandbags": ["stone", false],
	"crane_leg": ["steel", true], "freight_car": ["steel", false], "kiosk": ["wood", true],
	"ac_unit": ["steel", false], "vent": ["steel", false],
	"fuel_barrel": ["steel", false],
	"machine": ["steel", true], "pew": ["wood", false], "stall": ["wood", true], "tree": ["wood", true],
	"rubble": ["concrete", false], "transformer": ["steel", true], "chair": ["steel", false], "lift": ["steel", false],
	# rooftops
	"water_tank": ["steel", true], "roof_hut": ["steel", true], "solar": ["steel", false], "stack": ["steel", true],
	"scaffold": ["steel", false],
	# programmed sites: a service / teller counter (bullet-resistant, like the book's thick
	# wooden reception desk), a restaurant booth (upholstered wooden bench), a kitchen range
	"counter": ["wood", true], "booth": ["wood", true], "stove": ["steel", false],
	# set pieces: a deck-mounted anti-aircraft gun (armoured mount: thick steel), an aerodyne
	# cyberbike parked on its pad (a vehicle body: thin steel, like a car)
	"aa_gun": ["steel", true], "cyberbike": ["steel", false],
	# room sets (rooms.json _sets): a bank's teller counter (armoured front ≈ steel cabinet), a
	# stainless prep counter and a kitchen's pass (steel thin, like a fridge), a classroom desk (a
	# desk: thin wood), a host stand (thin wood), an open vault door (thick steel, like a safe),
	# an armchair (upholstered, the book's sofa: thick plaster), gym bleachers (stepped timber
	# deck: thick wood, like the reception desk), a luggage cart (suitcases on a rack: thin wood)
	"teller_counter": ["steel", false], "prep_counter": ["steel", false], "pass": ["steel", false],
	"school_desk": ["wood", false], "host_stand": ["wood", false], "vault_door": ["steel", true],
	"armchair": ["plaster", true], "bleachers": ["wood", true], "luggage": ["wood", false],
	# theme parks (ParkGen): a big wheel's legs and boarding platform, a drop tower's or swing ride's
	# base and a pavilion's posts (steel girders: thick steel, like crane legs), a coaster's lattice support
	# (open steel: thin, like a rack), a carousel's deck (timber platform and rounding boards: thick
	# wood, like the reception desk), a spinner's cups and a bumper car (thin steel, like a car), a
	# fountain basin (stone: thick, like a boulder), a game booth (a kiosk: thick wood), a fake pine
	# (a tree: thick wood)
	"wheel": ["steel", true], "drop_tower": ["steel", true], "swings": ["steel", true], "pavilion_post": ["steel", true],
	"coaster_post": ["steel", false], "carousel": ["wood", true], "spinner": ["steel", false],
	"bumper_car": ["steel", false], "fountain": ["stone", true], "game_booth": ["wood", true], "pine": ["wood", true],
}

## Walk-through dressing: stamped beside the pieces above by room sets, drawn by the viewer, no
## cover and never blocks movement (a chair or a queue rope stops no bullet and no one; HOUSE-RULE:
## chairs are not obstacles, so tables with chairs never wall off a dining room).
## Theme parks (ParkGen): a queue rail, a pole carrying a string of lights, and markers for a
## coaster's track and a pavilion's canopy (both overhead: `rect` carries their extent).
const DECOR := ["side_chair", "stool", "stanchion", "nightstand", "board", "hoop", "rail", "string_pole", "coaster", "pavilion"]

## Pieces that are also hazards (explosive: blows up when destroyed; resolved in M3).
const HAZARDS := {"fuel_barrel": "explosive", "transformer": "electrified"}

## Multi-cell props: piece → [w, h] footprint in squares (rotated at random).
const PROP_SIZES := {"car": [1, 2], "wreck": [2, 2], "container": [1, 3], "freight_car": [2, 7], "dumpster": [1, 1],
	"water_tank": [2, 2], "roof_hut": [2, 2], "solar": [1, 2], "scaffold": [1, 3]}


## Furniture and devices for a structure's rooms (`first`: only rooms from that id on, e.g. the
## basement storeys BasementGen adds under a building already furnished).
static func run_structure(m: TacMap, dice: Dice, sid: int, first := 0) -> void:
	var st: Dictionary = m.structures[sid]
	var density: float = float(st.params.get("density", 0.35))
	var rooms_def := RulesDB.gen("rooms.json")
	for r in m.rooms:
		if r.cells == 0 or r.get("structure", -1) != sid or int(r.id) < first:
			continue
		var geo := {}
		for spec in rooms_def.get(r.kind, {}).get("furniture", []):
			if spec is Dictionary:   # a room set laid out by convention (rows, lines, groups)
				if geo.is_empty():
					geo = _geometry(m, r)
				_pattern(m, dice, r, spec, geo, rooms_def.get("_sets", {}))
				continue
			# Per-kind density lives in the table (cells per piece); the site density scales it.
			var n := roundi(r.cells / float(spec[2]) * (0.25 + density))
			if spec[1] == "center" and spec[0] in ["reception", "desk", "console"]:
				n = mini(n, 1) if r.cells >= 20 else 0
			if PROP_SIZES.has(spec[0]):
				_place_props(m, dice, r, spec[0], n)
			else:
				_place(m, dice, r, spec[0], spec[1], n)
	_devices(m, dice, sid, first)


static func room_cells(m: TacMap, r: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var b: Rect2i = r.bounds
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			if m.label(r.floor, x, y) == r.id:
				out.append(Vector2i(x, y))
	return out


static func open_tile(v: int) -> bool:
	return v == TacMap.T.FLOOR or v == TacMap.T.OUTSIDE or v == TacMap.T.ROOF


static func cover_entry(piece: String, f: int, pos: Vector2i, room: int, prop: int = -1) -> Dictionary:
	var mat: Array = PIECES[piece]
	var hp := int(RulesDB.load_json("armor.json")["cover_hp"][mat[0]][0 if mat[1] else 1])
	return {"floor": f, "pos": pos, "kind": piece, "material": mat[0], "thick": mat[1], "hp": hp, "room": room, "prop": prop,
		"hazard": HAZARDS.get(piece, "")}


static func _place(m: TacMap, dice: Dice, r: Dictionary, piece: String, placement: String, n: int) -> void:
	if n <= 0:
		return
	var cells := room_cells(m, r)
	var b: Rect2i = r.bounds
	var cands: Array[Vector2i] = []
	for c in cells:
		if not open_tile(m.t(r.floor, c.x, c.y)) or m.has_cover_at(r.floor, c) or m.has_decor_at(r.floor, c) or _near_entry(m, r.floor, c):
			continue
		var walls := 0
		for d in MapGen.DIRS:
			if m.t(r.floor, c.x + d.x, c.y + d.y) == TacMap.T.WALL:
				walls += 1
		var ok := false
		match placement:
			"wall": ok = walls >= 1
			"front":   # along the wall towards the entrance facade (counters, a teacher's desk)
				var fd: Vector2i = r.get("front", Vector2i.ZERO)
				ok = m.t(r.floor, c.x + fd.x, c.y + fd.y) == TacMap.T.WALL if fd != Vector2i.ZERO else walls >= 1
			"row": ok = walls == 0 and (c.y - b.position.y) % 3 == 1 and (c.x - b.position.x) % 4 != 0
			"center": ok = _wall_distance(m, r.floor, c) >= 2
			_: ok = walls == 0
		if ok:
			cands.append(c)
	Layouts._shuffle(dice, cands)
	if placement == "center":
		var mid := b.get_center()
		cands.sort_custom(func(a, c): return a.distance_squared_to(mid) < c.distance_squared_to(mid))
	var placed := 0
	for c in cands:
		if placed >= n:
			break
		m.add_cover(cover_entry(piece, r.floor, c, r.id))
		if _room_connected(m, r, cells):
			placed += 1
		else:
			m.pop_cover()


## Multi-cell props (cars, containers, wrecks) with a one-square gap around each, so they can
## never wall off a lane on their own.
static func _place_props(m: TacMap, dice: Dice, r: Dictionary, piece: String, n: int) -> void:
	var cells := room_cells(m, r)
	var cset := {}
	for c in cells:
		cset[c] = true
	Layouts._shuffle(dice, cells)
	var placed := 0
	for c in cells:
		if placed >= n:
			break
		var sz: Array = PROP_SIZES[piece]
		var fp := Vector2i(sz[0], sz[1]) if dice.d(2) == 1 else Vector2i(sz[1], sz[0])
		if try_prop(m, r.floor, Rect2i(c, fp), piece, r.id, cset):
			if _room_connected(m, r, room_cells(m, r)):
				placed += 1
			else:
				for i in fp.x * fp.y:
					m.pop_cover()


## Place a prop footprint if every cell is open, unreserved and the 1-square ring is free of
## other cover and doorways. `allowed` (optional) restricts the cells it may use.
static func try_prop(m: TacMap, f: int, rect: Rect2i, piece: String, room: int, allowed: Dictionary = {}, reserved: Dictionary = {}) -> bool:
	for y in range(rect.position.y - 1, rect.end.y + 1):
		for x in range(rect.position.x - 1, rect.end.x + 1):
			var c := Vector2i(x, y)
			var inside := rect.has_point(c)
			if inside:
				if not m.inb(x, y) or not open_tile(m.t(f, x, y)) or reserved.has(c) or m.has_decor_at(f, c) or (not allowed.is_empty() and not allowed.has(c)):
					return false
			if m.has_cover_at(f, c) or m.t(f, x, y) in [TacMap.T.DOOR, TacMap.T.STAIRS, TacMap.T.ELEVATOR] or m.is_connector_end(f, c):
				return false
	var prop := m.cover.size()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			m.add_cover(cover_entry(piece, f, Vector2i(x, y), room, prop))
	return true


static func _wall_distance(m: TacMap, f: int, c: Vector2i) -> int:
	for dist in range(1, 4):
		for dy in range(-dist, dist + 1):
			for dx in range(-dist, dist + 1):
				if m.t(f, c.x + dx, c.y + dy) == TacMap.T.WALL:
					return dist - 1
	return 3


## Cells next to doors, shafts or exterior openings stay clear.
static func _near_entry(m: TacMap, f: int, c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if m.t(f, c.x + dx, c.y + dy) in [TacMap.T.DOOR, TacMap.T.STAIRS, TacMap.T.ELEVATOR] or m.is_connector_end(f, c + Vector2i(dx, dy)):
				return true
	return false


## All open cells of the room form one connected region (so every door reaches every cell).
static func _room_connected(m: TacMap, r: Dictionary, cells: Array[Vector2i]) -> bool:
	var open := {}
	for c in cells:
		if m.walkable(r.floor, c):
			open[c] = true
	if open.is_empty():
		return false
	var start: Vector2i = open.keys()[0]
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in MapGen.DIRS:
			var nb := c + d
			if open.has(nb) and not seen.has(nb):
				seen[nb] = true
				q.append(nb)
	return seen.size() == open.size()


# --- Room sets ----------------------------------------------------------------
# A furniture entry that is a dictionary lays out a set (rooms.json `_sets`: squares relative to
# an anchor that faces +y, `~kind` = walk-through decor) the way real rooms are planned: lines
# along a chosen wall, rows facing a head wall, one group at the centre or by a door. Keys:
#   at: wall | grid | head | center | door
#   set: a _sets name | piece: one kind | cycle: [kinds] taken in turn along a line
#   walls / head: wall selectors, all must hold: any, front, back, entry, far, side, long, short,
#     nodoor, exterior, interior, adjoin:<kind>[,<kind>]; a leading "!" negates
#   face: in (into the room) | wall | head | entry | far | door
#   off: squares out from the wall; inset: squares kept clear at each end of a wall line;
#   one: only the wall line with the most room; center + len: one run of
#     `len` sets centred on each line; step: squares from set to set; run + gap: runs of `run`
#     sets with `gap` squares between; max, per (room squares per set): how many
#   grid: step [across, along]; from: the first row's distance from the head wall
#   margin: squares kept clear of walls; clear: squares kept clear of earlier furniture and decor;
#   door_gap: squares kept clear of doorways (a reception desk off the lift lobby's door);
#   else: overrides to try again with when no set fits (other walls, a smaller door gap);
#   sites: only in these sites (sites.json)
#   near_ok: may stand beside a doorway (an open vault door); door: main | exterior | any; lat: squares
#     to the side of the doorway
# A set entry is [across, along, kind, turn]: turn 1 faces the anchor's +across, 2 its back, 3 -across.


## Doors, the main door's side and the room's squares, worked out once per room.
static func _geometry(m: TacMap, r: Dictionary) -> Dictionary:
	var cells := room_cells(m, r)
	var cset := {}
	for c in cells:
		cset[c] = true
	var doors: Array = []   # [pos, side (room → door), rank]
	var lines := {}
	for d in m.doors:
		if int(d.floor) != int(r.floor) or not (int(d.a) == int(r.id) or int(d.b) == int(r.id)):
			continue
		var other := int(d.a) if int(d.b) == int(r.id) else int(d.b)
		for s in MapGen.DIRS:
			if cset.has(d.pos - s):
				var rank := -1 if other < 0 else int(m.rooms[other].zone)
				doors.append([d.pos, s, rank, other])
				lines[Vector3i(s.x, s.y, d.pos.x if s.x != 0 else d.pos.y)] = true
				break
	doors.sort_custom(func(p, q): return p[2] < q[2])
	var entry: Vector2i = doors[0][1] if not doors.is_empty() else Vector2i.ZERO
	var front: Vector2i = r.get("front", Vector2i.ZERO)
	return {"cells": cells, "cset": cset, "doors": doors, "door_lines": lines, "entry": entry,
		"front": front if front != Vector2i.ZERO else entry, "heads": {}}


## Does the wall on side `d` of square `c` match every selector?
static func _walls_ok(m: TacMap, r: Dictionary, geo: Dictionary, c: Vector2i, d: Vector2i, sels: Array) -> bool:
	for s0 in sels:
		var s := String(s0)
		var neg := s.begins_with("!")
		if neg:
			s = s.substr(1)
		var ok := true
		var e: Vector2i = geo.entry
		var b: Rect2i = r.bounds
		match s:
			"any": ok = true
			"front": ok = d == geo.front
			"back": ok = d == -geo.front
			"entry": ok = d == e
			"far": ok = d == -e
			"side": ok = e != Vector2i.ZERO and d.x * e.x + d.y * e.y == 0
			"long": ok = (d.y != 0) if b.size.x >= b.size.y else (d.x != 0)
			"short": ok = (d.x != 0) if b.size.x >= b.size.y else (d.y != 0)
			"nodoor": ok = not geo.door_lines.has(Vector3i(d.x, d.y, c.x + d.x if d.x != 0 else c.y + d.y))
			_:
				# beyond the wall: another room of this building, or the outside (a wall junction
				# beyond counts as inside when it lies within the building's plot)
				var bv: Vector2i = c + 2 * d
				var l := m.label(r.floor, bv.x, bv.y)
				var sid := int(r.get("structure", -1))
				var plot: Rect2i = m.structures[sid].get("rect", Rect2i()) if sid >= 0 else Rect2i()
				var inside := l >= 0 and int(m.rooms[l].get("structure", -1)) == sid
				if l < 0 and m.t(r.floor, bv.x, bv.y) == TacMap.T.WALL:
					inside = plot.has_point(bv)
				if s == "exterior":
					ok = not inside
				elif s == "interior":
					ok = inside
				elif s.begins_with("adjoin:"):
					ok = l >= 0 and String(m.rooms[l].kind) in s.substr(7).split(",")
		if ok == neg:
			return false
	return true


## The side whose wall best matches `sels` (most squares along it): a classroom's board wall.
static func _head(m: TacMap, r: Dictionary, geo: Dictionary, sels: Array) -> Vector2i:
	var key := str(sels)
	if geo.heads.has(key):
		return geo.heads[key]
	var best := Vector2i.ZERO
	for tries in [sels, ["nodoor"], ["any"]]:
		var n := 0
		for d in MapGen.DIRS:
			var k := 0
			for c in geo.cells:
				if m.t(r.floor, c.x + d.x, c.y + d.y) == TacMap.T.WALL and _walls_ok(m, r, geo, c, d, tries):
					k += 1
			if k > n:
				n = k
				best = d
		if n > 0:
			break
	geo.heads[key] = best if best != Vector2i.ZERO else Vector2i(0, -1)
	return geo.heads[key]


static func _set_of(spec: Dictionary, sets: Dictionary, i: int) -> Array:
	if spec.has("set"):
		return sets[spec.set]
	if spec.has("cycle"):
		return [[0, 0, spec.cycle[i % (spec.cycle as Array).size()]]]
	return [[0, 0, spec.piece]]


static func _width(st: Array) -> Vector2i:
	var lo := 0
	var hi := 0
	for e in st:
		lo = mini(lo, int(e[0]))
		hi = maxi(hi, int(e[0]))
	return Vector2i(lo, hi)


static func _face(spec: Dictionary, geo: Dictionary, d: Vector2i, fallback: Vector2i) -> Vector2i:
	match String(spec.get("face", "")):
		"in": return -d if d != Vector2i.ZERO else fallback
		"wall": return d if d != Vector2i.ZERO else fallback
		"entry": return geo.entry if geo.entry != Vector2i.ZERO else fallback
		"far": return -geo.entry if geo.entry != Vector2i.ZERO else fallback
	return fallback


static func _limit(spec: Dictionary, r: Dictionary) -> int:
	var n := int(spec.get("max", 1000))
	if spec.has("per"):
		n = mini(n, maxi(1, roundi(r.cells / float(spec.per))))
	return n


static func _pattern(m: TacMap, dice: Dice, r: Dictionary, spec: Dictionary, geo: Dictionary, sets: Dictionary) -> void:
	if spec.has("sites") and not String(m.structures[int(r.structure)].get("site", "")) in spec.sites:
		return
	match String(spec.get("at", "wall")):
		"wall": _at_wall(m, dice, r, spec, geo, sets)
		"grid": _at_grid(m, r, spec, geo, sets)
		"head":
			var h := _head(m, r, geo, spec.get("walls", ["any"]))
			var off := int(spec.get("off", 0))
			var face := _face(spec, geo, h, -h)
			var cands: Array = []
			var mid := (r.bounds as Rect2i).get_center()
			for c in geo.cells:
				if m.t(r.floor, c.x + h.x * (off + 1), c.y + h.y * (off + 1)) == TacMap.T.WALL and geo.cset.has(c + h * off):
					cands.append(c)
			cands.sort_custom(func(p, q): return p.distance_squared_to(mid) < q.distance_squared_to(mid))
			var placed := 0
			for c in cands:
				if placed >= mini(_limit(spec, r), int(spec.get("max", 1))):
					break
				if _stamp(m, r, geo, c, face, _set_of(spec, sets, placed), spec):
					placed += 1
		"center":
			var mid := Vector2((r.bounds as Rect2i).position) + Vector2((r.bounds as Rect2i).size) / 2.0 - Vector2(0.5, 0.5)
			var cands: Array = geo.cells.duplicate()
			Layouts._shuffle(dice, cands)
			cands.sort_custom(func(p, q): return Vector2(p).distance_squared_to(mid) < Vector2(q).distance_squared_to(mid))
			var face := _face(spec, geo, Vector2i.ZERO, Vector2i(0, 1))
			var placed := 0
			for c in cands:
				if placed >= mini(_limit(spec, r), int(spec.get("max", 1))):
					break
				if _stamp(m, r, geo, c, face, _set_of(spec, sets, placed), spec):
					placed += 1
		"door":
			var placed := 0
			for dr in geo.doors:
				if placed >= int(spec.get("max", 1)):
					break
				var which := String(spec.get("door", "main"))
				if (which == "main" and dr != geo.doors[0]) or (which == "exterior" and int(dr[3]) >= 0):
					continue
				var s: Vector2i = dr[1]
				var n := -s
				var lx := Vector2i(n.y, -n.x)
				var e: Vector2i = dr[0] - s
				var signs := [1, -1]
				Layouts._shuffle(dice, signs)
				for sg in signs:
					var a: Vector2i = e + lx * int(sg) * int(spec.get("lat", 2)) + n * int(spec.get("off", 0))
					var face := n
					match String(spec.get("face", "in")):
						"door": face = -lx * int(sg)
						"wall": face = s
					if _stamp(m, r, geo, a, face, _set_of(spec, sets, placed), spec):
						placed += 1
						break


## Sets along the walls that match `walls` (when none fit, again with the `else` overrides): counters, booths, lockers, beds.
static func _at_wall(m: TacMap, dice: Dice, r: Dictionary, spec: Dictionary, geo: Dictionary, sets: Dictionary) -> void:
	if _along(m, dice, r, spec, geo, sets, spec.get("walls", ["any"])) == 0 and spec.has("else"):
		var alt := spec.duplicate()
		alt.erase("else")
		alt.merge(spec.else, true)   # may carry its own `else`
		_at_wall(m, dice, r, alt, geo, sets)


static func _along(m: TacMap, dice: Dice, r: Dictionary, spec: Dictionary, geo: Dictionary, sets: Dictionary, sels: Array) -> int:
	var off := int(spec.get("off", 0))
	var groups := {}   # wall line → [[anchor, d, lat]]
	for c in geo.cells:
		if not open_tile(m.t(r.floor, c.x, c.y)):
			continue
		for d in MapGen.DIRS:
			if m.t(r.floor, c.x + d.x, c.y + d.y) != TacMap.T.WALL or not _walls_ok(m, r, geo, c, d, sels):
				continue
			var a: Vector2i = c - d * off
			if not geo.cset.has(a):
				continue
			var key := Vector3i(d.x, d.y, c.x + d.x if d.x != 0 else c.y + d.y)
			groups.get_or_add(key, []).append([a, d, a.y if d.x != 0 else a.x])
	if groups.is_empty():
		return 0
	var keys: Array = groups.keys()
	Layouts._shuffle(dice, keys)
	var inset := int(spec.get("inset", 0))
	for k in keys:   # keep clear of the ends of each wall line (corners)
		var g: Array = groups[k]
		g.sort_custom(func(p, q): return p[2] < q[2])
		var lo: int = g[0][2] + inset
		var hi: int = g[-1][2] - inset
		groups[k] = g.filter(func(e): return e[2] >= lo and e[2] <= hi)
	keys = keys.filter(func(k): return not groups[k].is_empty())
	if keys.is_empty():
		return 0
	if spec.get("one", false):   # the wall line with the most room for the set
		var room_for := {}
		for k in keys:
			room_for[k] = groups[k].filter(func(e): return _fits(m, r, geo, e[0], _face(spec, geo, e[1], -e[1]), _set_of(spec, sets, 0), spec)).size()
		keys.sort_custom(func(p, q): return room_for[p] > room_for[q])
		keys = [keys[0]]
	var limit := _limit(spec, r)
	var placed := 0
	var w := _width(_set_of(spec, sets, 0))
	var step := int(spec.get("step", w.y - w.x + 1))
	for key in keys:
		var g: Array = groups[key]
		var d: Vector2i = g[0][1]
		var face := _face(spec, geo, d, -d)
		var by_lat := {}
		for e in g:
			by_lat[int(e[2])] = e[0]
		if spec.get("center", false):
			var n := int(spec.get("len", 1))
			var mid := (float(g[0][2]) + float(g[-1][2])) / 2.0
			var starts: Array = []
			for e in g:
				var ok := true
				for i in n:
					ok = ok and by_lat.has(int(e[2]) + i * step)
				if ok:
					starts.append(int(e[2]))
			starts.sort_custom(func(p, q): return absf(p + (n - 1) * step / 2.0 - mid) < absf(q + (n - 1) * step / 2.0 - mid))
			for s in starts:
				if placed >= limit:
					break
				var nc := m.cover.size()
				var nd := m.decor.size()
				var all := true
				for i in n:
					all = all and _stamp(m, r, geo, by_lat[s + i * step], face, _set_of(spec, sets, i), spec)
					if not all:
						break
				if all:
					placed += 1
					break
				while m.cover.size() > nc:
					m.pop_cover()
				while m.decor.size() > nd:
					m.pop_decor()
			continue
		var next := -100000
		var streak := 0
		var i := 0
		for e in g:
			if placed >= limit:
				break
			var lat := int(e[2])
			if lat < next:
				continue
			if _stamp(m, r, geo, e[0], face, _set_of(spec, sets, i), spec):
				placed += 1
				i += 1
				streak += 1
				next = lat + step
				if spec.has("run") and streak >= int(spec.run):
					next += int(spec.get("gap", 1))
					streak = 0
	return placed


## A lattice of sets facing the head wall: desks in rows, tables in a grid.
static func _at_grid(m: TacMap, r: Dictionary, spec: Dictionary, geo: Dictionary, sets: Dictionary) -> void:
	# The head wall: of the walls that match `head`, the one that seats the most sets, then the
	# most rows (a classroom's board goes on the wall that leaves room for rows). A `head` set after this
	# one with the same selectors reuses it.
	var sels: Array = spec.get("head", ["any"])
	var heads: Array = []
	for d in MapGen.DIRS:
		if geo.cells.any(func(c): return m.t(r.floor, c.x + d.x, c.y + d.y) == TacMap.T.WALL and _walls_ok(m, r, geo, c, d, sels)):
			heads.append(d)
	if heads.is_empty():
		heads = [_head(m, r, geo, sels)]
	var best: Array = []
	var best_rows := 0
	var face := Vector2i.ZERO
	var h := heads[0] as Vector2i
	for hd in heads:
		var f: Vector2i = -hd if String(spec.get("face", "head")) == "in" else hd
		var pts := _lattice(m, r, spec, geo, sets, hd, f)
		var rows := {}
		for c in pts:
			rows[c.x if hd.x != 0 else c.y] = true
		if face == Vector2i.ZERO or pts.size() * 10 + rows.size() > best.size() * 10 + best_rows:
			best_rows = rows.size()
			best = pts
			face = f
			h = hd
	geo.heads[str(sels)] = h
	var limit := _limit(spec, r)
	var placed := 0
	for c in best:
		if placed >= limit:
			break
		if _stamp(m, r, geo, c, face, _set_of(spec, sets, placed), spec):
			placed += 1


## Lattice points (rows `from` + k·step[1] squares out from head wall `h`, every step[0] squares
## across, on the offset that fits most) where the set fits, front rows first.
static func _lattice(m: TacMap, r: Dictionary, spec: Dictionary, geo: Dictionary, sets: Dictionary, h: Vector2i, face: Vector2i) -> Array:
	var b: Rect2i = r.bounds
	var st: Array = spec.get("step", [2, 2])
	var sx := int(st[0])
	var sy := int(st[1])
	var from := int(spec.get("from", 1))
	var dist := func(v: Vector2i) -> int:
		if h.y < 0: return v.y - b.position.y
		if h.y > 0: return b.end.y - 1 - v.y
		if h.x < 0: return v.x - b.position.x
		return b.end.x - 1 - v.x
	var lat_of := func(v: Vector2i) -> int: return v.x if h.x == 0 else v.y
	var lo: int = b.position.x if h.x == 0 else b.position.y
	var best: Array = []
	for base in sx:
		var pts: Array = []
		for c in geo.cells:
			var dd: int = dist.call(c)
			if dd >= from and (dd - from) % sy == 0 and posmod(int(lat_of.call(c)) - lo - base, sx) == 0 and _fits(m, r, geo, c, face, _set_of(spec, sets, 0), spec):
				pts.append(c)
		if pts.size() > best.size():
			best = pts
	best.sort_custom(func(p, q): return dist.call(p) < dist.call(q) or (dist.call(p) == dist.call(q) and lat_of.call(p) < lat_of.call(q)))
	return best


static func _cell_of(a: Vector2i, face: Vector2i, e: Array) -> Vector2i:
	var lx := Vector2i(face.y, -face.x)
	return a + lx * int(e[0]) + face * int(e[1])


static func _turn(face: Vector2i, k: int) -> Vector2i:
	var lx := Vector2i(face.y, -face.x)
	return [face, lx, -face, -lx][posmod(k, 4)]


## Can every solid piece of the set stand here (decor is optional)?
static func _fits(m: TacMap, r: Dictionary, geo: Dictionary, a: Vector2i, face: Vector2i, st: Array, spec: Dictionary) -> bool:
	var margin := int(spec.get("margin", 0))
	var clear := int(spec.get("clear", 0))
	var gap := int(spec.get("door_gap", 0))
	var mine := {}
	for e in st:
		if not String(e[2]).begins_with("~"):
			mine[_cell_of(a, face, e)] = true
	for v in mine:
		if not geo.cset.has(v) or not open_tile(m.t(r.floor, v.x, v.y)) or m.has_cover_at(r.floor, v) or m.has_decor_at(r.floor, v):
			return false
		if (not spec.get("near_ok", false) and _near_entry(m, r.floor, v)) or m.is_connector_end(r.floor, v):
			return false
		if margin > 0 and _wall_distance(m, r.floor, v) < margin:
			return false
		for dy in range(-gap, gap + 1):
			for dx in range(-gap, gap + 1):
				if m.t(r.floor, v.x + dx, v.y + dy) == TacMap.T.DOOR:
					return false
		for dy in range(-clear, clear + 1):
			for dx in range(-clear, clear + 1):
				var n: Vector2i = v + Vector2i(dx, dy)
				if not mine.has(n) and (m.has_cover_at(r.floor, n) or m.has_decor_at(r.floor, n)):
					return false
	return true


## Place a set facing `face` at anchor `a`: all its solid pieces or none (and only if the room
## stays connected), then whatever decor has room.
static func _stamp(m: TacMap, r: Dictionary, geo: Dictionary, a: Vector2i, face: Vector2i, st: Array, spec: Dictionary) -> bool:
	if not _fits(m, r, geo, a, face, st, spec):
		return false
	var n := 0
	for e in st:
		if String(e[2]).begins_with("~"):
			continue
		var entry := cover_entry(String(e[2]), r.floor, _cell_of(a, face, e), r.id)
		entry["face"] = _turn(face, int(e[3]) if e.size() > 3 else 0)
		m.add_cover(entry)
		n += 1
	if n > 0 and not _room_connected(m, r, geo.cells):
		for i in n:
			m.pop_cover()
		return false
	for e in st:
		if not String(e[2]).begins_with("~"):
			continue
		var v := _cell_of(a, face, e)
		if not geo.cset.has(v) or not open_tile(m.t(r.floor, v.x, v.y)) or m.has_cover_at(r.floor, v) or m.has_decor_at(r.floor, v):
			continue
		if MapGen.DIRS.any(func(d): return m.t(r.floor, v.x + d.x, v.y + d.y) in [TacMap.T.DOOR, TacMap.T.STAIRS, TacMap.T.ELEVATOR]):
			continue
		m.add_decor({"floor": r.floor, "pos": v, "kind": String(e[2]).substr(1), "face": _turn(face, int(e[3]) if e.size() > 3 else 0), "room": r.id})
	return true


# --- Devices ------------------------------------------------------------------
# Every hackable device belongs to a `group`; NetGen turns each group into one Control Node,
# data devices into Files, and access points into the nodes a Netrunner jacks in at (p198).

static func _devices(m: TacMap, dice: Dice, sid: int, first := 0) -> void:
	var sec := int(m.structures[sid].security)
	var rooms_def := RulesDB.gen("rooms.json")
	var site_groups := {}
	# the turrets' gun (Turret.ARMAMENTS, CPR core p.214): a room spec's `weapon`, else the site's
	# `turret_weapon` (sites.json), else Turret's default
	var site_gun := String(RulesDB.gen("sites.json").get(String(m.structures[sid].get("site", "")), {}).get("turret_weapon", ""))
	for r in m.rooms:
		if r.cells == 0 or r.get("structure", -1) != sid or int(r.id) < first:
			continue
		var z: int = r.zone
		var zn: String = TacMap.ZONE_NAMES[z]
		for spec in rooms_def.get(r.kind, {}).get("devices", []):
			if dice.rng.randf() >= float(spec.get("p", 1.0)):
				continue
			var group: String = spec.get("group", "")
			if group.begins_with("site:"):
				group = group.substr(5)
				if site_groups.has(group) or first > 0:   # a later batch of rooms: site-wide devices are placed
					continue
				site_groups[group] = true
			elif group != "":
				group = "%s_%s_f%d" % [group, zn, r.floor]
			var extra := {}
			if spec.get("ap", false):
				extra["access_point"] = true
			if spec.has("file"):
				extra["file_value"] = int(spec["file"])
			if spec["t"] == "turret" and String(spec.get("weapon", site_gun)) != "":
				extra["weapon"] = String(spec.get("weapon", site_gun))
			for i in maxi(1, r.cells / int(spec.get("per_cells", 100000))):
				add_device(m, dice, r, spec["t"], group, spec.get("wall", false), extra)
		if sec >= 2 and (r.kind in ["data_vault", "vault", "bank_vault", "armored_car", "cargo_hold"] or (z >= TacMap.Zone.SECURE and dice.rng.randf() < 0.4)):
			add_device(m, dice, r, "turret", "turrets_" + zn, true, {"weapon": site_gun} if site_gun != "" else {})
	for d in m.doors:
		if d.security and d.get("structure", -1) == sid and (first == 0 or int(d.b) >= first):
			var zone := maxi(m.rooms[d.a].zone if d.a >= 0 else 0, m.rooms[d.b].zone)
			m.devices.append({"id": m.devices.size(), "type": "door_lock", "floor": d.floor, "pos": d.pos,
				"room": d.b, "zone": zone, "group": "locks_" + TacMap.ZONE_NAMES[zone], "structure": sid})
	for v in m.verticals:
		if v.type == "elevator" and v.get("structure", -1) == sid and first == 0:
			m.devices.append({"id": m.devices.size(), "type": "elevator", "floor": 0, "pos": v.pos, "room": m.label(0, v.pos.x, v.pos.y),
				"zone": TacMap.Zone.PUBLIC, "group": "elevator", "structure": sid})


## Open, cover-free cells of room `r` reachable from its doors (or any opening to outside), by a
## flood within the room. Empty if the room has no door cell (then callers don't filter).
static func _reachable_in_room(m: TacMap, r: Dictionary) -> Dictionary:
	var cells := {}
	for c in room_cells(m, r):
		cells[c] = true
	var free := func(c: Vector2i) -> bool: return cells.has(c) and open_tile(m.t(r.floor, c.x, c.y)) and not m.has_cover_at(r.floor, c)
	var todo: Array[Vector2i] = []
	for c in cells:
		if not free.call(c):
			continue
		for d in MapGen.DIRS:
			var n: Vector2i = c + d
			if not cells.has(n) and m.inb(n.x, n.y) and m.t(r.floor, n.x, n.y) in [TacMap.T.DOOR, TacMap.T.FLOOR, TacMap.T.OUTSIDE]:
				todo.append(c)
				break
	var seen := {}
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if seen.has(c):
			continue
		seen[c] = true
		for d in MapGen.DIRS:
			var n: Vector2i = c + d
			if not seen.has(n) and free.call(n):
				todo.append(n)
	return seen


static func add_device(m: TacMap, dice: Dice, r: Dictionary, type: String, group: String, wall: bool, extra: Dictionary = {}) -> void:
	if type in ["camera", "turret"] and bool(m.params.get("no_drones", false)):
		return   # a place the drones can't see into (Playland's Haunted Woods, NC2045 p.308)
	var taken := {}
	for d in m.devices:
		if d.floor == r.floor:
			taken[d.pos] = true
	var cands: Array[Vector2i] = []
	var reach := _reachable_in_room(m, r)   # never a pocket boxed in by furniture: the crew must reach it
	for c in room_cells(m, r):
		if not open_tile(m.t(r.floor, c.x, c.y)) or m.has_cover_at(r.floor, c) or m.has_decor_at(r.floor, c) or taken.has(c):
			continue
		if not reach.is_empty() and not reach.has(c):
			continue
		var by_wall := MapGen.DIRS.any(func(d): return m.t(r.floor, c.x + d.x, c.y + d.y) == TacMap.T.WALL)
		if by_wall == wall or not wall:
			cands.append(c)
	if cands.is_empty():
		return
	var d := {"id": m.devices.size(), "type": type, "floor": r.floor, "pos": cands[dice.rng.randi_range(0, cands.size() - 1)],
		"room": r.id, "zone": r.zone, "group": group, "structure": r.get("structure", -1)}
	d.merge(extra)
	m.devices.append(d)
