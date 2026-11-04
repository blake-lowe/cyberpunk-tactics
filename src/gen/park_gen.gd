class_name ParkGen
extends RefCounted
## Theme parks: what DistrictGen adds to a `midway` profile (Playland by the Sea, NC2045 p.302-313),
## after real seaside and theme parks: Santa Monica's Pacific Park out on its pier, Coney Island's
## Luna Park and Deno's Wonder Wheel, Blackpool Pleasure Beach's coasters over the walks,
## Disneyland's hub with the lands off it.
## - ride(): a fenced ride lot gets its ride and a queue lane of rails from the gate: a big wheel, a
##   coaster looping round the lot on lattice supports (often with a small ride inside the loop), a
##   carousel, a bumper-car pavilion, a spinner, a swing ride or a drop tower. A map gets as many
##   different rides as it has lots for. Ride footprints are cover and block movement where the real
##   thing would: the wheel's legs and platform, coaster supports, the carousel deck, the drop tower's
##   and swings' bases, the pavilion's posts and the bumper cars. Everything above head height is
##   view dressing (ParkDressing).
## - forest(): the Haunted Woods' fake pines over the open ground between paths and lots.
## - tidy_roofs(): no city water tanks or solar farms on park roofs.
## - hub(): a fountain in the hub plaza.
## - midway(): strings of lights on poles across the walks, game booths and food kiosks along them.
## - pier(): a pier off the boardwalk with the big wheel on it; boardwalk(): booths along its land
##   side, benches and a string of lights along the rail.

const G := TacMap.G
## Rides with a fixed footprint: [w, h] in squares (2 m each; scaled down from the real thing so a
## lot holds one and the walks stay open).
const RIDE_SIZE := {"wheel": Vector2i(2, 6), "carousel": Vector2i(4, 4), "drop_tower": Vector2i(2, 2), "spinner": Vector2i(3, 3), "swings": Vector2i(2, 2)}
## Every ride type, the big ones first (a fresh map fills its biggest lots with them).
const RIDES := ["coaster", "wheel", "bumpers", "carousel", "spinner", "swings", "drop_tower"]
## Small rides that fit inside a coaster's loop.
const INNER := ["carousel", "spinner", "swings", "drop_tower"]


## A fenced ride lot (DistrictGen._yard_lot, before its benches and planters): its ride and queue.
static func ride(c: Dictionary, room: Dictionary, gate: Vector2i) -> void:
	var m: TacMap = c.m
	var cells := Furnish.room_cells(m, room)
	var area := {}
	for v in cells:
		area[v] = true
	var core := _core(area)
	if not core.is_empty():
		var used: Dictionary = c.get_or_add("park_rides", {})
		for k in _order(c, RIDES):
			if _place(c, room, k, core, cells):
				used[k] = int(used.get(k, 0)) + 1
				break
	if gate.x >= 0:
		_queue(c, room, gate, area)


## Ride types least used on this map first; ties broken by size (big first) with a little chance.
static func _order(c: Dictionary, kinds: Array) -> Array:
	var used: Dictionary = c.get_or_add("park_rides", {})
	var key := {}
	for k in kinds:
		key[k] = int(used.get(k, 0)) * 10.0 + RIDES.find(k) * 0.6 + c.dice.rng.randf() * 2.0
	var out := kinds.duplicate()
	out.sort_custom(func(a, b): return key[a] < key[b])
	return out


## Squares of `area` whose eight neighbours are all in it: a footprint there leaves a walk round it.
static func _core(area: Dictionary) -> Dictionary:
	var core := {}
	for v in area:
		if Nav.DIRS8.all(func(d): return area.has(v + d)):
			core[v] = true
	return core


static func _place(c: Dictionary, room: Dictionary, kind: String, core: Dictionary, cells: Array[Vector2i]) -> bool:
	match kind:
		"coaster": return _coaster(c, room, core, cells)
		"bumpers": return _bumpers(c, room, core, cells)
		_: return _footprint(c, room, kind, RIDE_SIZE[kind], core, cells, DistrictGen._bbox(core))


## A fixed-footprint ride inside `inside` (squares it may use), as near the middle of `bb` as it
## goes, long side along the lot's. The lot must stay connected.
static func _footprint(c: Dictionary, room: Dictionary, piece: String, size: Vector2i, inside: Dictionary, cells: Array[Vector2i], bb: Rect2i) -> bool:
	var m: TacMap = c.m
	var lo := mini(size.x, size.y)
	var hi := maxi(size.x, size.y)
	var sizes: Array = [Vector2i(hi, lo), Vector2i(lo, hi)] if bb.size.x >= bb.size.y else [Vector2i(lo, hi), Vector2i(hi, lo)]
	if lo == hi:
		sizes = [size]
	var mid := Vector2(bb.get_center())
	for s in sizes:
		var cands: Array[Vector2i] = []
		for v in inside:
			var r := Rect2i(v, s)
			if _all_in(r, inside):
				cands.append(v)
		cands.sort_custom(func(a, b): return (Vector2(a) + Vector2(s) / 2.0).distance_squared_to(mid) < (Vector2(b) + Vector2(s) / 2.0).distance_squared_to(mid))
		for v in cands.slice(0, 10):
			var n0 := m.cover.size()
			if Furnish.try_prop(m, 0, Rect2i(v, s), piece, room.id, inside, c.reserved):
				if Furnish._room_connected(m, room, cells):
					return true
				_rollback(m, n0)
	return false


static func _all_in(r: Rect2i, inside: Dictionary) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not inside.has(Vector2i(x, y)):
				return false
	return true


static func _rollback(m: TacMap, n0: int) -> void:
	while m.cover.size() > n0:
		m.pop_cover()


## The largest rectangle of squares all in `area` (row histograms, the classic maximal-rectangle scan).
static func max_rect(area: Dictionary) -> Rect2i:
	if area.is_empty():
		return Rect2i()
	var bb := DistrictGen._bbox(area)
	var hgt := PackedInt32Array()
	hgt.resize(bb.size.x)
	var best := Rect2i()
	for y in range(bb.position.y, bb.end.y):
		for i in bb.size.x:
			hgt[i] = hgt[i] + 1 if area.has(Vector2i(bb.position.x + i, y)) else 0
		var stack: Array[int] = []
		for i in bb.size.x + 1:
			var hh := hgt[i] if i < bb.size.x else 0
			while not stack.is_empty() and hgt[stack.back()] >= hh:
				var top: int = stack.pop_back()
				var left: int = stack.back() + 1 if not stack.is_empty() else 0
				var r := Rect2i(bb.position.x + left, y - hgt[top] + 1, i - left, hgt[top])
				if r.get_area() > best.get_area():
					best = r
			stack.append(i)
	return best


## The squares round a rectangle's edge, in order (clockwise from its top-left corner).
static func perimeter(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(r.position.x, r.end.x):
		out.append(Vector2i(x, r.position.y))
	for y in range(r.position.y + 1, r.end.y):
		out.append(Vector2i(r.end.x - 1, y))
	for x in range(r.end.x - 2, r.position.x - 1, -1):
		out.append(Vector2i(x, r.end.y - 1))
	for y in range(r.end.y - 2, r.position.y, -1):
		out.append(Vector2i(r.position.x, y))
	return out


## A coaster: track looping round the lot a square in from its walk, on a lattice support every
## third square (steel: cover), the loop's inside open to walk under the track; a small ride in
## the middle when there's room. The track itself is view dressing (decor `coaster` with its loop).
static func _coaster(c: Dictionary, room: Dictionary, core: Dictionary, cells: Array[Vector2i]) -> bool:
	var m: TacMap = c.m
	var loop := max_rect(core)
	if mini(loop.size.x, loop.size.y) < 7:
		return false
	loop = Rect2i(loop.get_center() - Vector2i(mini(loop.size.x, 22), mini(loop.size.y, 18)) / 2, Vector2i(mini(loop.size.x, 22), mini(loop.size.y, 18)))
	var per := perimeter(loop)
	if not per.all(func(v): return core.has(v)):
		return false
	var n0 := m.cover.size()
	for i in range(0, per.size(), 3):
		Furnish.try_prop(m, 0, Rect2i(per[i], Vector2i.ONE), "coaster_post", room.id, {}, c.reserved)
	if m.cover.size() - n0 < per.size() / 4 or not Furnish._room_connected(m, room, cells):
		_rollback(m, n0)
		return false
	var at := per[1] if not m.has_cover_at(0, per[1]) else per[2]
	m.add_decor({"floor": 0, "pos": at, "kind": "coaster", "face": Vector2i(0, 1), "room": room.id, "rect": loop})
	# a small ride in the middle of the loop
	var inner := {}
	var ir := loop.grow(-2)
	for v in core:
		if ir.has_point(v):
			inner[v] = true
	if not inner.is_empty():
		var used: Dictionary = c.get_or_add("park_rides", {})
		for k in _order(c, INNER):
			if _footprint(c, room, k, RIDE_SIZE[k], inner, cells, ir):
				used[k] = int(used.get(k, 0)) + 1
				break
	return true


## A bumper-car pavilion: a posted canopy (the posts are cover) over a floor of bumper cars (low
## cover, like parked cars). Decor `pavilion` carries its rect for the canopy.
static func _bumpers(c: Dictionary, room: Dictionary, core: Dictionary, cells: Array[Vector2i]) -> bool:
	var m: TacMap = c.m
	var bb := max_rect(core)
	var w := mini(bb.size.x, 9)
	var h := mini(bb.size.y, 7)
	if w < 5 or h < 5:
		return false
	var r := Rect2i(bb.get_center() - Vector2i(w / 2, h / 2), Vector2i(w, h))
	if not _all_in(r, core):
		return false
	var n0 := m.cover.size()
	for v in [r.position, Vector2i(r.end.x - 1, r.position.y), Vector2i(r.position.x, r.end.y - 1), r.end - Vector2i.ONE]:
		if not Furnish.try_prop(m, 0, Rect2i(v, Vector2i.ONE), "pavilion_post", room.id, {}, c.reserved):
			_rollback(m, n0)
			return false
	var inner := r.grow(-1)
	var cars := 0
	for i in 24:
		if cars >= 2 + (inner.get_area() / 12):
			break
		var v := Vector2i(c.dice.rng.randi_range(inner.position.x, inner.end.x - 1), c.dice.rng.randi_range(inner.position.y, inner.end.y - 1))
		if Furnish.try_prop(m, 0, Rect2i(v, Vector2i.ONE), "bumper_car", room.id, {}, c.reserved):
			cars += 1
	if not Furnish._room_connected(m, room, cells):
		_rollback(m, n0)
		return false
	for v in perimeter(r):
		if not m.has_cover_at(0, v):
			m.add_decor({"floor": 0, "pos": v, "kind": "pavilion", "face": Vector2i(0, 1), "room": room.id, "rect": r})
			break
	return true


## A queue lane from the gate: rails both sides of a one-square lane running into the lot
## (walk-through decor: a queue rail stops no one).
static func _queue(c: Dictionary, room: Dictionary, gate: Vector2i, area: Dictionary) -> void:
	var m: TacMap = c.m
	var inward := Vector2i.ZERO
	for d in MapGen.DIRS:
		if area.has(gate + d):
			inward = d
	if inward == Vector2i.ZERO:
		return
	var side := Vector2i(inward.y, inward.x)
	for k in range(1, 5):
		var lane := gate + inward * k
		if not area.has(lane) or m.has_cover_at(0, lane):
			break
		for s in [-1, 1]:
			var v: Vector2i = lane + side * s
			if area.has(v) and not m.has_cover_at(0, v) and not m.has_decor_at(0, v) and m.walkable(0, v):
				m.add_decor({"floor": 0, "pos": v, "kind": "rail", "face": inward, "room": room.id})


## The hub plaza's centrepiece: a fountain (stone basin: cover).
static func hub(c: Dictionary, room: Dictionary) -> void:
	var m: TacMap = c.m
	var cells := Furnish.room_cells(m, room)
	var area := {}
	for v in cells:
		area[v] = true
	var core := _core(area)
	if not core.is_empty():
		_footprint(c, room, "fountain", Vector2i(4, 4), core, cells, DistrictGen._bbox(core))


## The midways: strings of lights on poles across the walk, then game booths, food kiosks and
## vending machines along its edges (profile `midway_props` {rate, pieces}), clear of doors and
## gates. `roads`: square → true for the walk's middle, false for its edge.
static func midway(c: Dictionary, prof: Dictionary, roads: Dictionary) -> void:
	var m: TacMap = c.m
	var spec: Dictionary = prof.get("midway_props", {})
	var edges: Array[Vector2i] = []
	for v in roads:
		if roads[v] == false and m.t(0, v.x, v.y) == TacMap.T.OUTSIDE and m.label(0, v.x, v.y) < 0 and not m.has_cover_at(0, v):
			edges.append(v)
	# strings of lights: a pole on each side, the string across the middle
	var poles: Array[Vector2i] = []
	var spacing := int(spec.get("string_spacing", 7))
	if spacing > 0:
		for v in edges:
			if poles.any(func(q): return q.distance_squared_to(v) < spacing * spacing) or not _free(m, v):
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var u: Vector2i = v + d
				var n := 0
				while roads.get(u, false) == true and n < 14:
					u += d
					n += 1
				if n >= 3 and roads.has(u) and roads[u] == false and _free(m, u) and not poles.any(func(q): return q.distance_squared_to(u) < 9):
					m.add_decor({"floor": 0, "pos": v, "kind": "string_pole", "face": d, "room": -1, "to": u})
					m.add_decor({"floor": 0, "pos": u, "kind": "string_pole", "face": -d, "room": -1})
					poles.append(v)
					poles.append(u)
					break
	# booths and kiosks along the edges
	var rate := float(spec.get("rate", 0.0))
	var pieces: Array = spec.get("pieces", ["kiosk"])
	var placed: Array[Vector2i] = []
	for v in edges:
		if c.dice.rng.randf() > rate or placed.any(func(q): return q.distance_squared_to(v) < 10) or _near_door(m, v, 2):
			continue
		var piece: String = pieces[c.dice.rng.randi() % pieces.size()]
		var rect := Rect2i(v, Vector2i.ONE)
		if piece == "game_booth":   # two squares long, along the edge
			rect = Rect2i()
			for d in MapGen.DIRS:
				var u: Vector2i = v + d
				if roads.get(u, true) == false and d.x >= 0 and d.y >= 0:
					rect = Rect2i(v, Vector2i.ONE).expand(u).expand(u + Vector2i.ONE)
					break
			if rect.size == Vector2i.ZERO or _near_door(m, rect.end - Vector2i.ONE, 2):
				continue
		if Furnish.try_prop(m, 0, rect, piece, -1, {}, c.reserved):
			placed.append(v)


## A fake forest between the paths (profile `forest`: the share of open ground that gets a pine):
## open grass outside the lots, clear of doors and the paths' middle. Pines never stand side by side
## (try_prop keeps a square round each), so the wood stays walkable.
static func forest(c: Dictionary, prof: Dictionary) -> void:
	var share := float(prof.get("forest", 0.0))
	if share <= 0.0:
		return
	var m: TacMap = c.m
	var tree := String(DistrictLook.of_params(c.p).get("tree", "tree"))
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			var v := Vector2i(x, y)
			if int(m.ground[y * m.w + x]) != G.GRASS or not _free(m, v) or c.reserved.has(v) or c.dice.rng.randf() > share or _near_door(m, v, 2):
				continue
			Furnish.try_prop(m, 0, Rect2i(v, Vector2i.ONE), tree, -1, {}, c.reserved)


## A park's roofs carry plant (AC units, vents, huts) but not the city's water tanks and solar
## farms, which made its low pavilions read as tenement blocks.
static func tidy_roofs(c: Dictionary) -> void:
	var m: TacMap = c.m
	var drop: Array[Vector3i] = []
	for cv in m.cover:
		if String(cv.kind) in ["water_tank", "solar"]:
			drop.append(Vector3i(cv.pos.x, cv.pos.y, cv.floor))
	for v in drop:
		m.remove_cover_at(v.z, Vector2i(v.x, v.y))


static func _free(m: TacMap, v: Vector2i) -> bool:
	return m.inb(v.x, v.y) and m.t(0, v.x, v.y) == TacMap.T.OUTSIDE and m.label(0, v.x, v.y) < 0 and not m.has_cover_at(0, v) and not m.has_decor_at(0, v)


static func _near_door(m: TacMap, v: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if m.t(0, v.x + dx, v.y + dy) == TacMap.T.DOOR:
				return true
	return false


## A pier off the boardwalk into the sea (Santa Monica): `rows` deep, 8 squares wide, planked.
## Its squares join the walks (`roads`), so no lot takes them. Returns its rect.
static func pier(c: Dictionary, roads: Dictionary, top: int, rows: int) -> Rect2i:
	var m: TacMap = c.m
	var w := 8
	var x0: int = c.dice.rng.randi_range(m.w / 5, m.w * 4 / 5 - w)
	var r := Rect2i(x0, top, w, rows)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var v := Vector2i(x, y)
			m.set_t(0, x, y, TacMap.T.OUTSIDE)
			m.set_ground(x, y, G.DOCK)
			c.reserved.erase(v)
			roads[v] = true
	return r


## The pier's big wheel, across its middle; along the boardwalk a string of lights on the rail,
## benches facing the sea and booths on the land side.
static func boardwalk(c: Dictionary, sea_top: int) -> void:
	var m: TacMap = c.m
	var pr: Rect2i = c.get("pier", Rect2i())
	if pr.size != Vector2i.ZERO and pr.size.y >= 8:
		var r := Rect2i(pr.position.x + pr.size.x / 2 - 1, pr.position.y + (pr.size.y - 6) / 2, 2, 6)
		if Furnish.try_prop(m, 0, r, "wheel", -1, {}, c.reserved):
			var used: Dictionary = c.get_or_add("park_rides", {})
			used["wheel"] = int(used.get("wheel", 0)) + 1
	var y := sea_top - 1
	# a string of lights along the rail, pole to pole (Santa Monica's pier, Brighton's promenade)
	var poles: Array[Vector2i] = []
	for x in range(2, m.w - 2, 8):
		if _free(m, Vector2i(x, y)) and m.t(0, x, y + 1) == TacMap.T.WATER:
			poles.append(Vector2i(x, y))
	for i in poles.size():
		var d := {"floor": 0, "pos": poles[i], "kind": "string_pole", "face": Vector2i(1, 0), "room": -1}
		if i + 1 < poles.size() and poles[i + 1].x - poles[i].x <= 8:
			d["to"] = poles[i + 1]
		m.add_decor(d)
	# benches facing the sea between them
	var last := -99
	for x in range(1, m.w - 1):
		var v := Vector2i(x, y)
		if x - last < 6 or m.t(0, x, y + 1) != TacMap.T.WATER or not _free(m, v):
			continue
		if Furnish.try_prop(m, 0, Rect2i(v, Vector2i.ONE), "bench", -1, {}, c.reserved):
			last = x
	# game booths and food kiosks along the land side (Coney Island's boardwalk)
	var yl := sea_top - 3
	var lastb := -99
	for x in range(2, m.w - 3):
		if x - lastb < 7 or c.dice.rng.randf() > 0.45:
			continue
		var piece := "game_booth" if c.dice.rng.randf() < 0.6 else "kiosk"
		var r := Rect2i(x, yl, 2 if piece == "game_booth" else 1, 1)
		if not (_free(m, r.position) and _free(m, r.end - Vector2i.ONE)) or c.reserved.has(r.position) or c.reserved.has(r.end - Vector2i.ONE):
			continue
		if Furnish.try_prop(m, 0, r, piece, -1, {}, c.reserved):
			lastb = x
