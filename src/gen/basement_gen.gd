class_name BasementGen
extends RefCounted
## Storeys below the street (TacMap.basements). A set piece's building asks for them with its site
## key `basement` {storeys, flood {"-1": share, ...}, flood_rooms [program kinds], shafts}; their
## rooms come from the building's own layout: a program's "-1" / "-2" bands (or "basement" for
## every storey down), sharing the plan's band depths and mirror, so stair halls placed like the
## ground floor's sit right under them and the stair shafts carry straight down. An arena may ask
## for `tunnels` under its streets (the Combat Zone's guard tunnels between its hatches). On any
## other map the gig's target building may dig down by its site's `below_grade` chance (ordinary):
## its own below-grade brief, planned apart from the storeys above.
##
## Runs once the planner has built everything at street level: lifts the map (TacMap.lift), so
## nothing above changes, then lays out, walls, doors, zones, furnishes and wires (the building's
## NET is rebuilt with the new rooms) each storey down. Maps without basements never come here.

const T := TacMap.T
## Scenes whose target building may dig down (ordinary): the single-site raids every canon place with a
## site plays as, campuses and towers; not the district maps (their parks and ruins), the badlands, the undercity or a skirmish.
const ORDINARY_SCENES := ["lone_building", "megablock", "corp_campus", "arcology"]
## Tests only: build every map as if no ordinary building had a basement (the golden maps).
static var ordinary_off := false


## The storeys the scene wants below the street (0: none).
static func depth(c: Dictionary) -> int:
	var n := 0
	var want := wanted(c)
	for sid in want:
		n = maxi(n, int(want[sid].storeys))
	if not _tunnels_def(c).is_empty():
		n = maxi(n, 1)
	return n


## The basement each building gets, {structure id: def}: a set piece's buildings as their recipe
## asks (`basement`); on any other map, the gig's target building as its site's `below_grade`
## (ordinary) rolls.
static func wanted(c: Dictionary) -> Dictionary:
	var m: TacMap = c.m
	var set_piece := String(c.p.get("setpiece", "")) != ""
	var out := {}
	for st in m.structures:
		if String(st.get("kind", "")) != "building":
			continue
		var b: Dictionary = SetPieces.structure_def(st).get("basement", {}) if set_piece else (ordinary(m, st) if st.target else {})
		if int(b.get("storeys", 0)) > 0:
			out[int(st.id)] = b
	return out


## HOUSE-RULE (owner ruling 2026-11-04: "not every map should have a basement necessarily"): an
## ordinary building digs down where real ones do. Its site's `below_grade` (sites.json: {chance,
## storeys [min, max], program, down_from}) gives the chance and the below-grade brief (a bank's
## vaults, a club's back rooms, a corp office's server floor and parking, a block's storage and
## laundry, a hotel's service level). Rolled on a Dice of its own, seeded from the map's seed and
## the building, so the main stream is untouched: a map whose roll misses is exactly what it was
## before. The scene option `basement_storeys` forces the count (0: none). {} for none.
static func ordinary(m: TacMap, st: Dictionary) -> Dictionary:
	var bg: Dictionary = RulesDB.gen("sites.json").get(String(st.get("site", "")), {}).get("below_grade", {})
	if bg.is_empty() or ordinary_off or not String(m.params.get("scene", "")) in ORDINARY_SCENES:
		return {}
	var span: Array = bg.get("storeys", [1, 1])
	var n := 0
	if m.params.has("basement_storeys"):
		n = clampi(int(m.params.basement_storeys), 0, int(span[1]))
	else:
		var roll := Dice.new(m.seed_value * 1000003 + int(st.id) * 7919 + 211)
		if roll.rng.randf() >= float(bg.get("chance", 0.0)):
			return {}
		n = roll.rng.randi_range(int(span[0]), int(span[1]))
	if n <= 0:
		return {}
	return {"storeys": n, "program": bg.program, "down_from": bg.get("down_from", [])}


static func _tunnels_def(c: Dictionary) -> Dictionary:
	return SetPieces.get_def(String(c.p.get("setpiece", ""))).get("arena", {}).get("tunnels", {})


static func run(c: Dictionary) -> void:
	var m: TacMap = c.m
	var want := wanted(c)
	var n := depth(c)
	if n == 0:
		return
	m.lift(n)
	for h in c.hints:
		if int(h.get("floor", -1)) >= 0:
			h.floor = int(h.floor) + n
	for sid in want:
		building(c, int(sid), want[sid])
	if not _tunnels_def(c).is_empty():
		tunnels(c, _tunnels_def(c))


# --- A building's basements ---------------------------------------------------------------------

## Lay out, wall, stair, door, zone, flood and furnish `b.storeys` storeys under structure `sid`.
static func building(c: Dictionary, sid: int, b: Dictionary) -> void:
	var m: TacMap = c.m
	var dice: Dice = c.dice
	var hints: Array = c.hints
	var st: Dictionary = m.structures[sid]
	var p: Dictionary = st.params
	var sdef := SetPieces.structure_def(st)
	var s := m.street
	var n := mini(int(b.storeys), s)
	var shell: Rect2i = st.rect
	var inner := shell.grow(-1)
	var fp := Footprint.make(shell, _ground_mask(m, sid, shell))
	while m.rooms.size() < hints.size():   # room ids follow the scene-wide hint list
		m.rooms.append({"id": m.rooms.size(), "floor": -1, "zone": -1, "kind": "void", "cells": 0, "bounds": Rect2i(), "structure": -1})
	var first := hints.size()
	# An ordinary building's own below-grade brief (`b.program`: its "ground" bands are B1's, "-2"
	# B2's) is planned afresh: the storeys above may not be a program at all.
	var below: Dictionary = p.duplicate()
	if b.has("program"):
		below["algorithm"] = "program"
		below["program"] = b.program
		below["plan"] = Layouts.program_plan(dice, inner, below)
	for k in range(1, n + 1):
		var f := s - k
		var local := PackedInt32Array()
		local.resize(m.w * m.h)
		local.fill(-1)
		var q: Dictionary = below.duplicate()
		q["floor"] = -k   # a program reads its "-k" (or "basement") bands
		var room_hints := Layouts.run(String(below.get("algorithm", "program")), dice, m.w, inner, local, q)
		for y in range(inner.position.y, inner.end.y):
			for x in range(inner.position.x, inner.end.x):
				if not fp.interior(Vector2i(x, y)):
					local[y * m.w + x] = -1
		BuildingGen._split_components(m, f, local, inner, room_hints, hints)
		BuildingGen._walls(m, f, fp)
		BuildingGen._fix_fragments(m, f, fp, hints)
	BuildingGen._index_rooms(m, shell, s, first, hints.size(), sid)
	for i in range(first, hints.size()):
		m.rooms[i]["layout_kind"] = hints[i].get("kind", "")
		m.rooms[i]["below"] = true   # below grade: no windows, no street, no bystanders
		if hints[i].has("room"):
			m.rooms[i]["program_kind"] = hints[i].room
			m.rooms[i]["program_doors"] = hints[i].doors
			m.rooms[i]["glass"] = hints[i].glass
			m.rooms[i]["front"] = hints[i].front
	var entry := _stairs_down(m, sid, s, n, first, b)
	if entry.x < 0:
		push_warning("BasementGen: no way down under structure %d" % sid)
		return
	var root := m.label(s - 1, entry.x, entry.y)
	var above := m.label(s, entry.x, entry.y)
	# Zones down here read the brief like the storeys above (from the building's base zone, so a
	# staff room stays staff); the foot of the stairs is at least as deep as their head.
	BuildingGen._connect(m, dice, hints, p, first, root, int(st.base_zone))
	if above >= 0:
		m.rooms[root].zone = maxi(int(m.rooms[root].zone), int(m.rooms[above].zone))
	var fps := []
	for f in s:
		fps.append(fp)
	BuildingGen._wall_materials(m, fps, s, int(b.get("exterior", 1)))   # cast concrete against the earth
	BuildingGen._glass_fronts(m, first)
	BuildingGen._room_kinds(m, sdef.get("zones", {}), first, root)
	_flood(m, dice, sid, s, n, first, b)
	Furnish.run_structure(m, dice, sid, first)
	if m.architectures.has(sid):   # the building's NET takes in the devices downstairs
		m.architectures[sid] = NetGen.generate(m, dice, sid)
	st["basements"] = n


## The building's street-level footprint: every square of the shell it stands on.
static func _ground_mask(m: TacMap, sid: int, shell: Rect2i) -> Dictionary:
	var mask := {}
	var s := m.street
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			var t := m.t(s, x, y)
			var l := m.label(s, x, y)
			if t in [T.WALL, T.DOOR, T.FLOOR, T.STAIRS, T.ELEVATOR] and (l < 0 or int(m.rooms[l].get("structure", -1)) == sid) \
					and not (t == T.WALL and int(m.wall_mat[s][y * m.w + x]) == 3):
				mask[Vector2i(x, y)] = true
	return {} if mask.size() == shell.get_area() else mask


## Carry the building's stair shafts down where the storeys below have floor under them (a
## program's stair halls line up); if none reaches the first basement, a new shaft from a
## street-level stair room (else any room of `b.down_from`), else one cut down through the first
## shaft. `b.shafts` caps how many go down. Returns the shaft square of the way down (-1 if none).
static func _stairs_down(m: TacMap, sid: int, s: int, n: int, first: int, b: Dictionary) -> Vector2i:
	var shafts: Array = m.verticals.filter(func(v): return int(v.get("structure", -1)) == sid and String(v.type) == "stairs" and int(v.from_floor) == s)
	var cap := int(b.get("shafts", 99))
	var entry := Vector2i(-1, -1)
	var down := 0
	var shell: Rect2i = m.structures[sid].rect
	if b.has("program"):
		# An ordinary building's basement is planned apart from the storeys above, so their shafts
		# would land in any room: a new stair from the street comes down into its own stair halls
		# (each storey's brief starts with one, so they stack), else as below.
		var own := _new_shaft(m, sid, s, n, shell, b.get("down_from", []), first, "stair_hall")
		if own.x >= 0:
			for f in range(s - n, s + 1):
				m.set_t(f, own.x, own.y, T.STAIRS)
			m.verticals.append({"type": "stairs", "pos": own, "from_floor": s - n, "to_floor": s, "structure": sid})
			return own
	for v in shafts:
		if down >= cap:
			break
		var lo := s
		while lo > s - n and m.t(lo - 1, v.pos.x, v.pos.y) == T.FLOOR and m.label(lo - 1, v.pos.x, v.pos.y) >= first:
			lo -= 1
		if lo == s:
			continue
		for f in range(lo, s):
			m.set_t(f, v.pos.x, v.pos.y, T.STAIRS)
		v.from_floor = lo
		down += 1
		if entry.x < 0:
			entry = v.pos
	if entry.x >= 0:
		return entry
	# No shaft lines up: a new one beside a street-level stair (or in a room `down_from` names;
	# an ordinary building's empty list, or one none of whose rooms has room, means any of its rooms).
	var want: Array = b.get("down_from", ["stair_hall"])
	var best := _new_shaft(m, sid, s, n, shell, want)
	if best.x < 0 and b.has("program") and not want.is_empty():
		best = _new_shaft(m, sid, s, n, shell, [])
	if best.x < 0 and not shafts.is_empty():   # last resort: cut the first shaft straight down
		best = shafts[0].pos
		for f in range(s - n, s):
			if m.t(f, best.x, best.y) == T.WALL:
				for d in MapGen.DIRS:
					var l := m.label(f, best.x + d.x, best.y + d.y)
					if l >= first and m.t(f, best.x + d.x, best.y + d.y) == T.FLOOR:
						m.set_t(f, best.x, best.y, T.FLOOR)
						m.labels[f][best.y * m.w + best.x] = l
						break
		if not range(s - n, s).all(func(f): return m.t(f, best.x, best.y) == T.FLOOR):
			return Vector2i(-1, -1)
		shafts[0].from_floor = s - n
		for f in range(s - n, s):
			m.set_t(f, best.x, best.y, T.STAIRS)
		return best
	if best.x < 0:
		return best
	for f in range(s - n, s + 1):
		m.set_t(f, best.x, best.y, T.STAIRS)
	m.verticals.append({"type": "stairs", "pos": best, "from_floor": s - n, "to_floor": s, "structure": sid})
	return best


## The square nearest the building's centre, in a street-level room of structure `sid` whose kind
## is in `want` (any of its rooms if `want` is empty), that is open floor with open floor all round
## on the street and every storey down to s - n: where a new stair shaft can go. With `below`, the
## square must be in a room of that program kind (rooms from `first` on) on every storey down.
## (-1, -1) if none.
static func _new_shaft(m: TacMap, sid: int, s: int, n: int, shell: Rect2i, want: Array, first := 0, below := "") -> Vector2i:
	var c := shell.get_center()
	var best := Vector2i(-1, -1)
	for y in range(shell.position.y + 1, shell.end.y - 1):
		for x in range(shell.position.x + 1, shell.end.x - 1):
			var v := Vector2i(x, y)
			var l := m.label(s, x, y)
			if l < 0 or int(m.rooms[l].get("structure", -1)) != sid:
				continue
			if not want.is_empty() and not (String(m.rooms[l].get("program_kind", m.rooms[l].kind)) in want):
				continue
			# the street storey is furnished already: the shaft and its approaches stay clear of it
			var ok := not m.has_cover_at(s, v) and not m.has_decor_at(s, v) and MapGen.DIRS.all(func(d): return not m.has_cover_at(s, v + d))
			for f in range(s - n, s + 1):
				if m.t(f, x, y) != T.FLOOR:
					ok = false
				for d in MapGen.DIRS:
					if m.t(f, x + d.x, y + d.y) != T.FLOOR:
						ok = false
				if below != "" and f < s:
					var bl := m.label(f, x, y)
					if bl < first or String(m.rooms[bl].get("program_kind", "")) != below:
						ok = false
			if ok and (best.x < 0 or v.distance_squared_to(c) < best.distance_squared_to(c)):
				best = v
	return best


## Standing water (TacMap.T.WATER: no wading rules yet, so it can't be walked) over part of the
## storeys `b.flood` names ({"-2": share of the storey's squares}), in rooms `b.flood_rooms` lists
## (program kinds; empty = any), in pools grown from random seeds. Doorways, stairs and every
## room's link to the stairs stay dry, and each room keeps at least half its floor.
static func _flood(m: TacMap, dice: Dice, sid: int, s: int, n: int, first: int, b: Dictionary) -> void:
	var flood: Dictionary = b.get("flood", {})
	if flood.is_empty():
		return
	var kinds: Array = b.get("flood_rooms", [])
	var shell: Rect2i = m.structures[sid].rect
	for k in range(1, n + 1):
		var share := float(flood.get(str(-k), 0.0))
		if share <= 0.0:
			continue
		var f := s - k
		var dry := {}   # room id → squares still dry
		var cand: Array[Vector2i] = []
		var total := 0
		var stair := Vector2i(-1, -1)
		for y in range(shell.position.y, shell.end.y):
			for x in range(shell.position.x, shell.end.x):
				var t := m.t(f, x, y)
				if t == T.STAIRS:
					stair = Vector2i(x, y)
				if t != T.FLOOR:
					continue
				var l := m.label(f, x, y)
				if l < first:
					continue
				total += 1
				dry[l] = dry.get(l, 0) + 1
				if kinds.is_empty() or String(m.rooms[l].get("program_kind", m.rooms[l].kind)) in kinds:
					cand.append(Vector2i(x, y))
		if stair.x < 0 or cand.is_empty():
			continue
		var cells := {}
		for v in cand:
			cells[v] = int(m.rooms[m.label(f, v.x, v.y)].cells)
		var goal := roundi(total * share)
		var wet := 0
		var tries := 0
		Layouts._shuffle(dice, cand)
		var queue: Array[Vector2i] = []
		while wet < goal and tries < goal * 6 + 50:
			tries += 1
			if queue.is_empty():
				if cand.is_empty():
					break
				queue.append(cand.pop_back())
			var v: Vector2i = queue.pop_front()
			if m.t(f, v.x, v.y) != T.FLOOR or not cells.has(v) or Furnish._near_entry(m, f, v):
				continue
			var l := m.label(f, v.x, v.y)
			if dry[l] - 1 < int(cells[v]) / 2 + 1:
				continue
			m.set_t(f, v.x, v.y, T.WATER)
			if not _all_dry_linked(m, f, shell, stair, first):
				m.set_t(f, v.x, v.y, T.FLOOR)
				continue
			dry[l] -= 1
			wet += 1
			var nexts: Array = MapGen.DIRS.duplicate()
			Layouts._shuffle(dice, nexts)
			for d in nexts:
				if dice.rng.randf() < 0.7:
					queue.append(v + d)
		m.structures[sid]["flooded"] = true


## Every dry floor square of the storey still links to the stairs (doors open, 4-way).
static func _all_dry_linked(m: TacMap, f: int, shell: Rect2i, stair: Vector2i, first: int) -> bool:
	var seen := {stair: true}
	var q: Array[Vector2i] = [stair]
	while not q.is_empty():
		var v: Vector2i = q.pop_back()
		for d in MapGen.DIRS:
			var nb: Vector2i = v + d
			if not seen.has(nb) and shell.has_point(nb) and m.t(f, nb.x, nb.y) in [T.FLOOR, T.DOOR, T.STAIRS]:
				seen[nb] = true
				q.append(nb)
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			if m.t(f, x, y) == T.FLOOR and m.label(f, x, y) >= first and not seen.has(Vector2i(x, y)):
				return false
	return true


# --- Tunnels under an arena's streets -----------------------------------------------------------

## Guard tunnels one storey down (arena `tunnels` {w, kind}): a passage from each tunnel hatch to
## the next (nearest first, so they join up as a tree), dug in the ground under the set, with a
## ladder up through each hatch. The tunnels are one room of the arena's outdoor structure.
static func tunnels(c: Dictionary, td: Dictionary) -> void:
	var m: TacMap = c.m
	var s := m.street
	var f := s - 1
	var hatches: Array[Vector2i] = []
	var sid := -1
	for e in m.entrances:
		if String(e.kind) == "tunnel":
			hatches.append(e.pos)
			sid = int(e.get("structure", -1))
	if hatches.size() < 1 or sid < 0:
		return
	var half := maxi(0, int(td.get("w", 2)) - 1)
	var dug := {}
	var dig := func(a: Vector2i, b: Vector2i) -> void:
		var x0 := mini(a.x, b.x)
		var x1 := maxi(a.x, b.x)
		var y0 := mini(a.y, b.y)
		var y1 := maxi(a.y, b.y)
		for x in range(x0, x1 + 1):   # along x at a's row, then along y at b's column
			for k in half + 1:
				dug[Vector2i(x, a.y + k)] = true
		for y in range(y0, y1 + 1):
			for k in half + 1:
				dug[Vector2i(b.x + k, y)] = true
	var linked: Array[Vector2i] = [hatches[0]]
	var left: Array[Vector2i] = hatches.slice(1)
	while not left.is_empty():
		var bi := 0
		var bj := 0
		var bd := INF
		for i in left.size():
			for j in linked.size():
				var d := Vector2(left[i]).distance_to(Vector2(linked[j]))
				if d < bd:
					bd = d
					bi = i
					bj = j
		dig.call(linked[bj], left[bi])
		linked.append(left[bi])
		left.remove_at(bi)
	for h in hatches:   # a chamber at the foot of each ladder
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				dug[h + Vector2i(dx, dy)] = true
	var id: int = c.hints.size()
	c.hints.append({"zone_hint": TacMap.Zone.STAFF, "kind": String(td.get("kind", "tunnel")), "floor": f})
	while m.rooms.size() < id:
		m.rooms.append({"id": m.rooms.size(), "floor": -1, "zone": -1, "kind": "void", "cells": 0, "bounds": Rect2i(), "structure": -1})
	var room := {"id": id, "floor": f, "zone": TacMap.Zone.STAFF, "kind": String(td.get("kind", "tunnel")), "cells": 0, "bounds": Rect2i(),
		"structure": sid, "below": true}
	m.rooms.append(room)
	for v in dug:
		if not m.inb(v.x, v.y) or v.x < 1 or v.y < 1 or v.x >= m.w - 1 or v.y >= m.h - 1:
			continue
		m.set_t(f, v.x, v.y, T.FLOOR)
		m.labels[f][v.y * m.w + v.x] = id
		room.bounds = Rect2i(v, Vector2i.ONE) if room.cells == 0 else (room.bounds as Rect2i).expand(v).expand(v + Vector2i.ONE)
		room.cells += 1
	for y in m.h:   # lined walls round the dug squares
		for x in m.w:
			if m.t(f, x, y) != T.VOID:
				continue
			for d in MapGen.DIRS + BuildingGen.DIAG:
				if m.label(f, x + d.x, y + d.y) == id:
					m.set_t(f, x, y, T.WALL)
					m.wall_mat[f][y * m.w + x] = 1
					break
	for h in hatches:
		m.connectors.append({"type": "hatch", "a": Vector3i(h.x, h.y, f), "b": Vector3i(h.x, h.y, s), "structure": sid})
	var posts := int(td.get("posts", 0))
	var spots: Array = Furnish.room_cells(m, room).filter(func(v): return not hatches.has(v) and not m.is_connector_end(f, v))
	Layouts._shuffle(c.dice, spots)
	var placed: Array[Vector2i] = []
	for v in spots:
		if placed.size() >= posts:
			break
		if placed.any(func(q): return Vector2(q).distance_to(Vector2(v)) < 10.0):
			continue
		placed.append(v)
		m.posts.append({"floor": f, "pos": v, "structure": sid, "zone": TacMap.Zone.STAFF, "kind": "tunnel", "priority": true})
