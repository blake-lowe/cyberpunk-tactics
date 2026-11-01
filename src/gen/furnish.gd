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
}

## Multi-cell props: piece → [w, h] footprint in squares (rotated at random).
const PROP_SIZES := {"car": [1, 2], "wreck": [2, 2], "container": [1, 3], "freight_car": [2, 7], "dumpster": [1, 1]}


static func run_structure(m: TacMap, dice: Dice, sid: int) -> void:
	var st: Dictionary = m.structures[sid]
	var density: float = float(st.params.get("density", 0.35))
	var rooms_def := RulesDB.gen("rooms.json")
	for r in m.rooms:
		if r.cells == 0 or r.get("structure", -1) != sid:
			continue
		for spec in rooms_def.get(r.kind, {}).get("furniture", []):
			# Per-kind density lives in the table (cells per piece); the site density scales it.
			var n := roundi(r.cells / float(spec[2]) * (0.25 + density))
			if spec[1] == "center" and spec[0] in ["reception", "desk", "console"]:
				n = mini(n, 1) if r.cells >= 20 else 0
			if PROP_SIZES.has(spec[0]):
				_place_props(m, dice, r, spec[0], n)
			else:
				_place(m, dice, r, spec[0], spec[1], n)
	_devices(m, dice, sid)


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
	return {"floor": f, "pos": pos, "kind": piece, "material": mat[0], "thick": mat[1], "hp": hp, "room": room, "prop": prop}


static func _place(m: TacMap, dice: Dice, r: Dictionary, piece: String, placement: String, n: int) -> void:
	if n <= 0:
		return
	var cells := room_cells(m, r)
	var b: Rect2i = r.bounds
	var cands: Array[Vector2i] = []
	for c in cells:
		if not open_tile(m.t(r.floor, c.x, c.y)) or m.has_cover_at(r.floor, c) or _near_entry(m, r.floor, c):
			continue
		var walls := 0
		for d in MapGen.DIRS:
			if m.t(r.floor, c.x + d.x, c.y + d.y) == TacMap.T.WALL:
				walls += 1
		var ok := false
		match placement:
			"wall": ok = walls >= 1
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
				if not m.inb(x, y) or not open_tile(m.t(f, x, y)) or reserved.has(c) or (not allowed.is_empty() and not allowed.has(c)):
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


# --- Devices ------------------------------------------------------------------
# Every hackable device belongs to a `group`; NetGen turns each group into one Control Node,
# data devices into Files, and access points into the nodes a Netrunner jacks in at (p198).

static func _devices(m: TacMap, dice: Dice, sid: int) -> void:
	var sec := int(m.structures[sid].security)
	var rooms_def := RulesDB.gen("rooms.json")
	var site_groups := {}
	for r in m.rooms:
		if r.cells == 0 or r.get("structure", -1) != sid:
			continue
		var z: int = r.zone
		var zn: String = TacMap.ZONE_NAMES[z]
		for spec in rooms_def.get(r.kind, {}).get("devices", []):
			if dice.rng.randf() >= float(spec.get("p", 1.0)):
				continue
			var group: String = spec.get("group", "")
			if group.begins_with("site:"):
				group = group.substr(5)
				if site_groups.has(group):
					continue
				site_groups[group] = true
			elif group != "":
				group = "%s_%s_f%d" % [group, zn, r.floor]
			var extra := {}
			if spec.get("ap", false):
				extra["access_point"] = true
			if spec.has("file"):
				extra["file_value"] = int(spec["file"])
			for i in maxi(1, r.cells / int(spec.get("per_cells", 100000))):
				add_device(m, dice, r, spec["t"], group, spec.get("wall", false), extra)
		if sec >= 2 and (r.kind in ["data_vault", "vault", "armored_car", "cargo_hold"] or (z >= TacMap.Zone.SECURE and dice.rng.randf() < 0.4)):
			add_device(m, dice, r, "turret", "turrets_" + zn, true)
	for d in m.doors:
		if d.security and d.get("structure", -1) == sid:
			var zone := maxi(m.rooms[d.a].zone if d.a >= 0 else 0, m.rooms[d.b].zone)
			m.devices.append({"id": m.devices.size(), "type": "door_lock", "floor": d.floor, "pos": d.pos,
				"room": d.b, "zone": zone, "group": "locks_" + TacMap.ZONE_NAMES[zone], "structure": sid})
	for v in m.verticals:
		if v.type == "elevator" and v.get("structure", -1) == sid:
			m.devices.append({"id": m.devices.size(), "type": "elevator", "floor": 0, "pos": v.pos, "room": m.label(0, v.pos.x, v.pos.y),
				"zone": TacMap.Zone.PUBLIC, "group": "elevator", "structure": sid})


static func add_device(m: TacMap, dice: Dice, r: Dictionary, type: String, group: String, wall: bool, extra: Dictionary = {}) -> void:
	var taken := {}
	for d in m.devices:
		if d.floor == r.floor:
			taken[d.pos] = true
	var cands: Array[Vector2i] = []
	for c in room_cells(m, r):
		if not open_tile(m.t(r.floor, c.x, c.y)) or m.has_cover_at(r.floor, c) or taken.has(c):
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
