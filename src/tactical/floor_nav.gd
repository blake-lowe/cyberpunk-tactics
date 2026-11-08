class_name FloorNav
extends RefCounted
## Floor navigation in the tactical view, as pure rules (playtest round 4: a tester never found the
## upper floor). Stairs and elevators are shafts at one x,y (TacMap.verticals: the same square is
## STAIRS on every storey from from_floor to to_floor, each one linked to the next); ladders and fire
## escapes are TacMap.connectors (end a to end b). Nav prices the links (stairs 1 per floor, a
## climb 2 per floor, p169), so GO UP / GO DOWN is an ordinary move along that one link.

const NONE := Vector3i(-1, -1, -1)


## The squares on other floors that square `v` connects to directly: the shaft's next storey up and
## down, and the far end of a ladder that starts here.
static func links(m: TacMap, v: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for s in m.verticals:
		if s.pos == Vector2i(v.x, v.y) and v.z >= int(s.from_floor) and v.z <= int(s.to_floor):
			for f in [v.z + 1, v.z - 1]:
				if f >= int(s.from_floor) and f <= int(s.to_floor):
					out.append(Vector3i(v.x, v.y, f))
	for c in m.connectors:
		if c.a == v:
			out.append(c.b)
		elif c.b == v:
			out.append(c.a)
	return out


## Where taking the stairs (dir +1 up, -1 down) from `v` leads: the linked square on the nearest
## floor that way, or NONE.
static func step(m: TacMap, v: Vector3i, dir: int) -> Vector3i:
	var best := NONE
	for l in links(m, v):
		if signi(l.z - v.z) == signi(dir) and (best == NONE or absi(l.z - v.z) < absi(best.z - v.z)):
			best = l
	return best


## Whether square `v` is a stair (or elevator / ladder end) that leads somewhere.
static func is_stair(m: TacMap, v: Vector3i) -> bool:
	return not links(m, v).is_empty()


## GO UP / GO DOWN for the active unit: {ok, dest, run, reason}. `ok` only when the move along the
## link fits this turn: in the move range (`moves`, Encounter.move_options) or the Run range
## (`runs`, Encounter.run_options, which spends the Action).
static func go(m: TacMap, pos: Vector3i, dir: int, moves: Dictionary, runs: Dictionary) -> Dictionary:
	var dest := step(m, pos, dir)
	if dest == NONE:
		return {"ok": false, "dest": NONE, "run": false, "reason": "no stairs that way"}
	if moves.has(dest):
		return {"ok": true, "dest": dest, "run": false, "reason": ""}
	if runs.has(dest):
		return {"ok": true, "dest": dest, "run": true, "reason": ""}
	return {"ok": false, "dest": dest, "run": false, "reason": "not enough movement (or the way is blocked)"}


## The floor to view after a unit's move ends at `end_z`: crew moves are followed, foes only when
## the crew sees where they ended (`seen`); otherwise the view stays.
static func follow_floor(view_floor: int, end_z: int, crew: bool, seen: bool) -> int:
	if end_z == view_floor or not (crew or seen):
		return view_floor
	return end_z


## The next floor to view that way (dir +1 / -1), or -1 at the top / bottom.
static func next_floor(m: TacMap, view_floor: int, dir: int) -> int:
	var f := view_floor + signi(dir)
	return f if f >= 0 and f < m.floors else -1


## Which way the objective lies from the viewed floor: 1 up, -1 down, 0 this floor.
static func objective_dir(view_floor: int, target_z: int) -> int:
	return signi(target_z - view_floor)


## The stair squares on `view_floor` that lead toward floor `target_z`: shafts reaching that way
## (and ladder ends climbing that way), the target's own building first when it is in one.
static func hint_stairs(m: TacMap, view_floor: int, target: Vector3i) -> Array[Vector3i]:
	var dir := objective_dir(view_floor, target.z)
	var out: Array[Vector3i] = []
	if dir == 0:
		return out
	var own: Array[Vector3i] = []
	var sid := _structure_at(m, target)
	for s in m.verticals:
		if view_floor < int(s.from_floor) or view_floor > int(s.to_floor):
			continue
		var reach := int(s.to_floor) if dir > 0 else int(s.from_floor)
		if reach == view_floor:
			continue
		var v := Vector3i(s.pos.x, s.pos.y, view_floor)
		out.append(v)
		if sid >= 0 and int(s.get("structure", -1)) == sid:
			own.append(v)
	for c in m.connectors:
		for e in [[c.a, c.b], [c.b, c.a]]:
			if (e[0] as Vector3i).z == view_floor and signi((e[1] as Vector3i).z - view_floor) == dir:
				out.append(e[0])
	return own if not own.is_empty() else out


## Alt's floor signs (owner-approved signposts): every stair square on `view_floor` (shafts and ladder
## ends) with the ways it leads (`dirs`: 1 up, -1 down), and every way out of a building there
## (`is_exit`). Only squares `known` accepts (Callable(Vector3i) -> bool: seen by the crew, or on a
## blueprint storey). [{kind: "stairs" | "exit", cell: Vector3i, dirs: Array[int]}]
static func signs(m: TacMap, view_floor: int, known: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cells: Array[Vector3i] = []
	for s in m.verticals:
		if view_floor >= int(s.from_floor) and view_floor <= int(s.to_floor):
			cells.append(Vector3i(s.pos.x, s.pos.y, view_floor))
	for c in m.connectors:
		for e in [c.a, c.b]:
			if (e as Vector3i).z == view_floor:
				cells.append(e)
	var done := {}
	for v in cells:
		if done.has(v) or not known.call(v):
			continue
		done[v] = true
		var dirs: Array[int] = []
		for d in [1, -1]:
			if step(m, v, d) != NONE:
				dirs.append(d)
		if not dirs.is_empty():
			out.append({"kind": "stairs", "cell": v, "dirs": dirs})
	for d in m.doors:
		var v := Vector3i(d.pos.x, d.pos.y, int(d.floor))
		if v.z == view_floor and not done.has(v) and is_exit(m, d) and known.call(v):
			done[v] = true
			out.append({"kind": "exit", "cell": v, "dirs": [] as Array[int]})
	return out


## A door out of a building: outdoors (the street, or an outdoor room such as a terrace) on exactly
## one side. Fence gates between yards and the street are not doors out.
static func is_exit(m: TacMap, d: Dictionary) -> bool:
	if d.get("gate", false) or m.t(int(d.floor), d.pos.x, d.pos.y) != TacMap.T.DOOR:
		return false
	return _outdoors(m, int(d.a)) != _outdoors(m, int(d.b))


static func _outdoors(m: TacMap, room: int) -> bool:
	return room < 0 or room >= m.rooms.size() or bool(m.rooms[room].get("outdoor", false))


const SIGN_FAR_ALPHA := 0.35   ## the faintest a far sign draws


## Keeps Alt's signs uncluttered: the `cap` nearest the camera focus (in squares), each given an
## `alpha` that fades from 1 within `near` squares to SIGN_FAR_ALPHA at `far` and beyond.
static func nearest_signs(list: Array, focus: Vector2, cap: int, near := 8.0, far := 20.0) -> Array:
	var keyed: Array = []
	for s in list:
		var v: Vector3i = s.cell
		keyed.append([Vector2(v.x + 0.5, v.y + 0.5).distance_to(focus), v.y * 100000 + v.x, s])
	keyed.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array = []
	for k in keyed.slice(0, maxi(cap, 0)):
		var s: Dictionary = (k[2] as Dictionary).duplicate()
		s["alpha"] = lerpf(1.0, SIGN_FAR_ALPHA, clampf(inverse_lerp(near, far, float(k[0])), 0.0, 1.0))
		out.append(s)
	return out


static func _structure_at(m: TacMap, v: Vector3i) -> int:
	if v.z < 0 or v.z >= m.floors or not m.inb(v.x, v.y):
		return -1
	var l := m.label(v.z, v.x, v.y)
	return int(m.rooms[l].get("structure", -1)) if l >= 0 else -1


## Floors drawn as the fixer's blueprints while unexplored: every floor no crew member starts on.
## Their static layout (floors, walls, doors, stairs) shows dimmed; units, devices and furniture stay
## fogged until seen. The floor the crew goes in on is scouted the old way.
static func blueprint_floors(floors: int, crew_start: Array) -> Dictionary:
	var out := {}
	for f in floors:
		out[f] = true
	for p in crew_start:
		out.erase((p as Vector3i).z)
	return out
