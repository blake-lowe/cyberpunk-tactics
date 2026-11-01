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
	"crate": ["wood", true], "safe": ["steel", true],
}

## kind → [[piece, placement, cells per piece (lower = denser)]]. Placement: wall | row | center | scatter.
const ROOM_FURNITURE := {
	"lobby": [["reception", "center", 200], ["planter", "scatter", 30], ["sofa", "wall", 40], ["pillar", "center", 60]],
	"atrium": [["planter", "scatter", 25], ["pillar", "center", 40], ["sofa", "wall", 50]],
	"waiting": [["sofa", "wall", 20], ["table", "center", 30], ["planter", "scatter", 40]],
	"restroom": [],
	"corridor": [["vending", "wall", 60], ["planter", "wall", 70]],
	"office": [["desk", "row", 7], ["cabinet", "wall", 25]],
	"meeting": [["table", "center", 10]],
	"break_room": [["table", "scatter", 14], ["fridge", "wall", 60], ["vending", "wall", 60]],
	"storage": [["crate", "scatter", 6]],
	"security_office": [["desk", "row", 12], ["locker", "wall", 15]],
	"server_room": [["rack", "row", 4]],
	"lab": [["bench", "row", 7], ["cabinet", "wall", 25]],
	"data_vault": [["rack", "row", 6], ["safe", "wall", 40], ["pillar", "center", 50]],
	"exec_office": [["desk", "center", 60], ["sofa", "wall", 30], ["safe", "wall", 60]],
}


static func run(m: TacMap, dice: Dice) -> void:
	var density: float = float(m.params.get("density", 0.5))
	for r in m.rooms:
		if r.cells == 0:
			continue
		for spec in ROOM_FURNITURE.get(r.kind, []):
			var n := roundi(r.cells / float(spec[2]) * (0.4 + 1.2 * density))
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
	for r in m.rooms:
		if r.cells == 0:
			continue
		var z: int = r.zone
		var zn: String = TacMap.ZONE_NAMES[z]
		var tag := "%s_f%d" % [zn, r.floor]
		match r.kind:
			"lobby", "atrium", "corridor":
				for i in maxi(1, r.cells / 60):
					_device(m, dice, r, "camera", "cameras_" + tag, true)
			"office":
				if dice.rng.randf() < 0.6:
					_device(m, dice, r, "terminal", "", false, {"access_point": true})
			"security_office":
				_device(m, dice, r, "terminal", "", false, {"access_point": true, "file_value": 2})
				_device(m, dice, r, "alarm_panel", "alarm", true)
				_device(m, dice, r, "camera", "cameras_" + tag, true)
			"server_room":
				_device(m, dice, r, "terminal", "", false, {"access_point": true, "file_value": 3})
				_device(m, dice, r, "camera", "cameras_" + tag, true)
			"lab":
				_device(m, dice, r, "terminal", "", false, {"access_point": dice.rng.randf() < 0.5, "file_value": 3})
			"data_vault":
				_device(m, dice, r, "data_core", "", false, {"file_value": 5})
				_device(m, dice, r, "camera", "cameras_" + tag, true)
			"exec_office":
				_device(m, dice, r, "terminal", "", false, {"access_point": true, "file_value": 4})
			"break_room", "meeting":
				if z == TacMap.Zone.STAFF and r.floor == 0 and not m.devices.any(func(d): return d.group == "sprinklers"):
					_device(m, dice, r, "sprinkler_valve", "sprinklers", true)
		if sec >= 2 and (r.kind == "data_vault" or (z >= TacMap.Zone.SECURE and dice.rng.randf() < 0.4)):
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
