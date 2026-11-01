class_name Furnish
extends RefCounted
## Places cover and hackable devices by room kind.
## Cover HP comes from the material table (p182); pieces are matched to the book's examples
## (p183): desks/tables ≈ overturned table (wood thin 5), sofa (plaster thick 15), cabinets,
## fridges and racks (steel thin 25), pillars (concrete thick 25), safes (steel thick 50).
## Every placement keeps the room fully connected: no blocked doors, no sealed pockets.

## piece → [material, thick]
const PIECES := {
	"desk": ["wood", false], "table": ["wood", false], "reception": ["wood", true],
	"sofa": ["plaster", true], "planter": ["stone", false], "pillar": ["concrete", true],
	"cabinet": ["steel", false], "vending": ["steel", false], "fridge": ["steel", false],
	"locker": ["steel", false], "rack": ["steel", false], "bench": ["steel", false],
	"crate": ["wood", true], "safe": ["steel", true], "shelf": ["steel", false],
}

static func run(m: TacMap, dice: Dice) -> void:
	var density: float = float(m.params.get("density", 0.35))
	var rooms_def := RulesDB.gen("rooms.json")
	for r in m.rooms:
		if r.cells == 0:
			continue
		for spec in rooms_def.get(r.kind, {}).get("furniture", []):
			# Per-kind density lives in the table (cells per piece); the site density scales it.
			var n := roundi(r.cells / float(spec[2]) * (0.25 + density))
			if spec[1] == "center" and spec[0] in ["reception", "desk"]:
				n = mini(n, 1) if r.cells >= 20 else 0
			_place(m, dice, r, spec[0], spec[1], n)
	_devices(m, dice)


static func room_cells(m: TacMap, r: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var b: Rect2i = r.bounds
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			if m.label(r.floor, x, y) == r.id:
				out.append(Vector2i(x, y))
	return out


static func _place(m: TacMap, dice: Dice, r: Dictionary, piece: String, placement: String, n: int) -> void:
	if n <= 0:
		return
	var cells := room_cells(m, r)
	var b: Rect2i = r.bounds
	var cands: Array[Vector2i] = []
	for c in cells:
		if m.t(r.floor, c.x, c.y) != TacMap.T.FLOOR or m.has_cover_at(r.floor, c) or _near_entry(m, r.floor, c):
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
		var mat: Array = PIECES[piece]
		var hp := int(RulesDB.load_json("armor.json")["cover_hp"][mat[0]][0 if mat[1] else 1])
		m.cover.append({"floor": r.floor, "pos": c, "kind": piece, "material": mat[0], "thick": mat[1], "hp": hp, "room": r.id})
		if _room_connected(m, r, cells):
			placed += 1
		else:
			m.cover.pop_back()


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
			if m.t(f, c.x + dx, c.y + dy) in [TacMap.T.DOOR, TacMap.T.STAIRS, TacMap.T.ELEVATOR]:
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
# and data devices into Files. Access points are where a Netrunner can jack in (p198).

static func _devices(m: TacMap, dice: Dice) -> void:
	var sec := int(m.params.get("security", 1))
	var rooms_def := RulesDB.gen("rooms.json")
	var site_groups := {}
	for r in m.rooms:
		if r.cells == 0:
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
				_device(m, dice, r, spec["t"], group, spec.get("wall", false), extra)
		if sec >= 2 and (r.kind in ["data_vault", "vault"] or (z >= TacMap.Zone.SECURE and dice.rng.randf() < 0.4)):
			_device(m, dice, r, "turret", "turrets_" + zn, true)
	for d in m.doors:
		if d.security:
			var zone := maxi(m.rooms[d.a].zone if d.a >= 0 else 0, m.rooms[d.b].zone)
			m.devices.append({"id": m.devices.size(), "type": "door_lock", "floor": d.floor, "pos": d.pos,
				"room": d.b, "zone": zone, "group": "locks_" + TacMap.ZONE_NAMES[zone]})
	for v in m.verticals:
		if v.type == "elevator":
			m.devices.append({"id": m.devices.size(), "type": "elevator", "floor": 0, "pos": v.pos, "room": m.label(0, v.pos.x, v.pos.y),
				"zone": TacMap.Zone.PUBLIC, "group": "elevator"})


static func _device(m: TacMap, dice: Dice, r: Dictionary, type: String, group: String, wall: bool, extra: Dictionary = {}) -> void:
	var cands: Array[Vector2i] = []
	for c in room_cells(m, r):
		if m.t(r.floor, c.x, c.y) != TacMap.T.FLOOR or m.has_cover_at(r.floor, c):
			continue
		if m.devices.any(func(d): return d.floor == r.floor and d.pos == c):
			continue
		var by_wall := MapGen.DIRS.any(func(d): return m.t(r.floor, c.x + d.x, c.y + d.y) == TacMap.T.WALL)
		if by_wall == wall or not wall:
			cands.append(c)
	if cands.is_empty():
		return
	var d := {"id": m.devices.size(), "type": type, "floor": r.floor, "pos": cands[dice.rng.randi_range(0, cands.size() - 1)],
		"room": r.id, "zone": r.zone, "group": group}
	d.merge(extra)
	m.devices.append(d)
