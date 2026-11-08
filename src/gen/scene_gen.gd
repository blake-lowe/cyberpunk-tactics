class_name SceneGen
extends RefCounted
## Builds whole scenes: outdoor ground, roads, water, fences and yards, with buildings filled by
## BuildingGen. Each scene type has a planner below; data/gen/scenes.json lists them for tools.
## Outdoor areas that matter (parking lots, compounds, quays) are yard "rooms" with a zone, so
## zoning, furnishing, devices and NETs work the same indoors and out. Open street is zone STREET.

const G := TacMap.G


## Every scene id generate() can build (its match below), for data validation.
const PLANNERS := ["lone_building", "skirmish", "street_block", "city_district", "neighborhood", "megablock",
	"shipyard", "badlands", "rail_yard", "corp_campus", "undercity", "arcology", "warzone"]

static func scene_types() -> Array:
	return RulesDB.gen("scenes.json").keys().filter(func(k): return not k.begins_with("_"))


## overrides.setpiece (data/gen/setpieces.json) builds that set piece instead: its scene, its
## planner (SetPieceGen) and its buildings; the caller's other overrides still win.
static func generate(seed_value: int, scene: String, overrides: Dictionary = {}) -> TacMap:
	var setpiece := String(overrides.get("setpiece", ""))
	if SetPieces.has(setpiece):
		scene = SetPieces.scene_of(setpiece)
		overrides = SetPieces.overrides(setpiece, overrides)
	elif setpiece != "":
		push_error("unknown set piece " + setpiece)
		overrides = overrides.duplicate()
		overrides.erase("setpiece")
		setpiece = ""
	var sdef: Dictionary = RulesDB.gen("scenes.json")[scene]
	var p: Dictionary = MapGen.DEFAULTS.duplicate()
	p.merge(sdef.get("params", {}), true)
	p.merge(overrides, true)
	if int(p.get("verticality", 1)) == 0:
		p.floors = 1
	# A tall district (DistrictLook height) raises the neighbourhood's skyline; the gig's own target
	# keeps the scene's storeys (target_floors), so the job is no bigger.
	var h := int(DistrictLook.of(String(p.get("district", ""))).get("height", 0))
	if h > 0 and setpiece == "" and scene in ["street_block", "city_district", "neighborhood"] and not overrides.has("floors"):
		p["target_floors"] = int(p.floors)
		p.floors = int(p.floors) + h
	var dice := Dice.new(seed_value)
	if setpiece != "":
		SetPieceGen.size(dice, p, overrides)
	elif scene == "lone_building":
		_site_size(dice, p, overrides)
	var m := TacMap.new(int(p.w), int(p.h), int(p.floors) + 1)  # + roof level
	m.seed_value = seed_value
	m.algorithm = scene
	m.params = p
	p["scene"] = scene
	var c := {"m": m, "dice": dice, "hints": [], "p": p, "reserved": {}, "overrides": overrides, "related": []}
	if setpiece != "":
		SetPieceGen.run(c)
		BasementGen.run(c)   # storeys below the street, if the recipe has any: street level becomes m.street
	else:
		_plan(c, scene)
		BasementGen.run(c)   # the target building may dig down (its site's below_grade); most don't
	_link_nets(c)
	_deploy_zone(c)
	_ensure_public_access(m)
	_guard_posts(m)
	if setpiece != "":
		SetPieceGen.posts(c)
		_reseat_devices(m)   # set-piece props come after the devices: move any they boxed in
	for st in m.structures:
		if st.target and m.architectures.has(st.id):
			m.architecture = m.architectures[st.id]
			m.algorithm = st.get("algorithm", scene) if scene == "lone_building" else scene
	return m


## Devices the crew can't reach from the deploy zone (boxed in by props placed after them) move to
## the nearest reachable free square in their room, else in their structure; grounds devices move to
## the nearest reachable open-air square within 8. Door locks sit on doors and stay put. An access
## point never moves into jack-in reach of the deploy zone (AP_CLEAR_M).
static func _reseat_devices(m: TacMap) -> void:
	var dep := Vector3i(-1, -1, -1)
	for e in m.entrances:
		if e.kind == "deploy":
			dep = Vector3i(e.pos.x, e.pos.y, m.street)
			break
	if dep.x < 0:
		return
	var reach := m.reachable(dep)
	var used := {}
	for dv in m.devices:
		used[Vector3i(dv.pos.x, dv.pos.y, dv.floor)] = true
	var ap_ids := {}
	for sid in m.architectures:
		for ap in (m.architectures[sid] as NetArchitecture).access_points:
			ap_ids[int(ap.device)] = true
	var los := Los.new(m)
	var dcells := deploy_cells(m)
	for dv in m.devices:
		var at := Vector3i(dv.pos.x, dv.pos.y, dv.floor)
		if dv.type == "door_lock" or reach.has(at):
			continue
		var sid := int(dv.get("structure", -1))
		var best := Vector3i(-1, -1, -1)
		var best_d := INF
		for cell in reach:
			if cell.z != dv.floor or used.has(cell) or m.has_cover_at(cell.z, Vector2i(cell.x, cell.y)):
				continue
			var l := m.label(cell.z, cell.x, cell.y)
			var cs: int = -1 if l < 0 else int(m.rooms[l].get("structure", -1))
			if cs != sid:
				continue
			var dd := Vector2(cell.x - at.x, cell.y - at.y).length() + (0.0 if l == int(dv.get("room", -2)) else 50.0)
			if sid < 0 and dd > 8.0:
				continue
			if dd < best_d and not (ap_ids.has(int(dv.id)) and any_jack_reach(los, dcells, [cell])):
				best_d = dd
				best = cell
		if best.x >= 0:
			used.erase(at)
			used[best] = true
			dv.pos = Vector2i(best.x, best.y)
			dv.room = m.label(best.z, best.x, best.y)


static func _plan(c: Dictionary, scene: String) -> void:
	var p: Dictionary = c.p
	match scene:
		"lone_building": _lone_building(c)
		"skirmish": _skirmish(c)
		"street_block", "city_district", "neighborhood": DistrictGen.generate(c, String(p.get("profile", "mixed_residential")))
		"megablock": _megablock(c)
		"shipyard": _shipyard(c)
		"badlands": _badlands(c)
		"rail_yard": _rail_yard(c)
		"corp_campus": _corp_campus(c)
		"undercity": ThemedScenes.undercity(c)
		"arcology": ThemedScenes.arcology(c)
		"warzone": ThemedScenes.warzone(c)
		_: push_error("unknown scene " + scene)


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


## `part`: a set piece's building (setpieces.json sites.<part>), built from its recipe.
static func building(c: Dictionary, shell: Rect2i, site: String, floors: int, security: int, target := false, base_zone := TacMap.Zone.PUBLIC, entry_side := "", mask := {}, part := "") -> Dictionary:
	# Only what the caller set explicitly; otherwise each site keeps its own defaults.
	var params: Dictionary = {}
	for k in ["density", "loops", "net_threat", "net_scale"]:
		if c.overrides.has(k):
			params[k] = c.overrides[k]
	for k in ["algorithm", "verticality"]:
		if target and c.overrides.has(k):
			params[k] = c.overrides[k]
	if c.has("decay"):
		params["decay"] = c.decay
	# Footprint shape (M2e review: break up grids everywhere): by the site type's shape weights.
	var courtyard := Rect2i()
	var setpiece := String(c.p.get("setpiece", "")) if part != "" else ""
	if mask.is_empty() and mini(shell.size.x, shell.size.y) >= 12:
		var shapes: Dictionary = SetPieces.site_def(site, setpiece, part).get("shapes", {"rect": 1})
		var names := shapes.keys()
		var wts := PackedFloat32Array()
		for n in names:
			wts.append(float(shapes[n]))
		var shape: String = names[c.dice.rng.rand_weighted(wts)]
		var shaped := _shape_mask(c, shell, shape)
		mask = shaped.mask
		courtyard = shaped.courtyard
	return BuildingGen.build(c.m, c.dice, c.hints, {"shell": shell, "site": site, "floors": floors, "security": security,
		"base_zone": base_zone, "target": target, "entry_side": entry_side, "params": params, "mask": mask, "courtyard": courtyard,
		"setpiece": setpiece, "part": part})


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
		# M2f review: sockets always join two nodes of the same level (no bypassing).
		var levels := {}
		for s1 in aa.subnets:
			if s1.zone < TacMap.Zone.VAULT and ab.subnets.any(func(s2): return s2.zone == s1.zone):
				levels[s1.zone] = true
		if levels.is_empty():
			continue
		var z: int = levels.keys()[c.dice.rng.randi_range(0, levels.size() - 1)]
		var hubs_a := aa.subnets.filter(func(s): return s.zone == z)
		var hubs_b := ab.subnets.filter(func(s): return s.zone == z)
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


## Footprint mask for a shape: L (one corner cut out), U (notch in one side), T (two corners on
## one side cut), chamfer (diagonal corner), courtyard (hollow ring). Returns {mask, courtyard}.
static func _shape_mask(c: Dictionary, shell: Rect2i, shape: String) -> Dictionary:
	var w := shell.size.x
	var h := shell.size.y
	var cut: Array[Rect2i] = []
	var yard := Rect2i()
	var side: int = c.dice.d(4)
	match shape:
		"L":
			var cw := roundi(w * c.dice.rng.randf_range(0.35, 0.5))
			var ch := roundi(h * c.dice.rng.randf_range(0.35, 0.5))
			var cx := shell.position.x if side in [1, 3] else shell.end.x - cw
			var cy := shell.position.y if side in [1, 2] else shell.end.y - ch
			cut.append(Rect2i(cx, cy, cw, ch))
		"U":
			if side <= 2:
				var nw := roundi(w * 0.35)
				var nd := roundi(h * 0.4)
				cut.append(Rect2i(shell.position.x + (w - nw) / 2, shell.position.y if side == 1 else shell.end.y - nd, nw, nd))
			else:
				var nh := roundi(h * 0.35)
				var nd2 := roundi(w * 0.4)
				cut.append(Rect2i(shell.position.x if side == 3 else shell.end.x - nd2, shell.position.y + (h - nh) / 2, nd2, nh))
		"T":
			var tw := roundi(w * 0.3)
			var th := roundi(h * 0.45)
			var ty := shell.position.y if side <= 2 else shell.end.y - th
			cut.append(Rect2i(shell.position.x, ty, tw, th))
			cut.append(Rect2i(shell.end.x - tw, ty, tw, th))
		"chamfer":
			return {"mask": _cut_corner(c, shell), "courtyard": Rect2i()}
		"courtyard":
			if mini(w, h) >= 18:
				var k := maxi(6, mini(w, h) / 3)
				yard = shell.grow(-k)
				cut.append(yard)
	if cut.is_empty():
		return {"mask": {}, "courtyard": Rect2i()}
	var mask := {}
	for y in range(shell.position.y, shell.end.y):
		for x in range(shell.position.x, shell.end.x):
			var v := Vector2i(x, y)
			if not cut.any(func(r): return r.has_point(v)):
				mask[v] = true
	return {"mask": mask, "courtyard": yard}


static func _unlabel(m: TacMap, room: Dictionary, cells: Dictionary) -> void:
	for v in cells:
		if m.label(0, v.x, v.y) == room.id:
			m.labels[0][v.y * m.w + v.x] = -1
			room.cells -= 1


## No NET access point within jack-in reach of a square the crew starts on (owner: a crew deployed
## on or beside one jacked in on turn 1 and skipped the infiltration). Reach is Encounter.jack_points'
## rule (same floor, no wall or closed door between: Los.blocker) out to AP_CLEAR_M, which is the
## longest jack-in reach there is, 6 m (CPR core p.198) or 10 m with the Long Leash perk
## (perks.json), so not even a perked Netrunner jacks in from the deploy zone.
const AP_CLEAR_M := 10.0


## Every NET access point's square, all structures: [Vector3i].
static func access_point_cells(m: TacMap) -> Array:
	var out := []
	for sid in m.architectures:
		for ap in (m.architectures[sid] as NetArchitecture).access_points:
			var d: Dictionary = m.devices[int(ap.device)]
			out.append(Vector3i(d.pos.x, d.pos.y, d.floor))
	return out


## The deploy zone's squares at street level (the crew's start squares are these: Encounter.setup).
static func deploy_cells(m: TacMap) -> Array:
	for e in m.entrances:
		if e.kind == "deploy":
			return (e.get("cells", [e.pos]) as Array).map(func(c): return Vector3i(c.x, c.y, m.street))
	return []


## Could a Netrunner standing on `from` jack in at an access point on `ap` (within AP_CLEAR_M)?
static func jack_reach(los: Los, from: Vector3i, ap: Vector3i) -> bool:
	return from.z == ap.z and Los.distance_m(from, ap) <= AP_CLEAR_M and not Los.ray(from, ap).any(func(r): return los.blocker(r) == "wall")


## True if any of `cells` is within jack-in reach of any of `aps` (both [Vector3i]).
static func any_jack_reach(los: Los, cells: Array, aps: Array) -> bool:
	for a in aps:
		for v in cells:
			if jack_reach(los, v, a):
				return true
	return false


## [[deploy square, access point square]] for every pair in jack-in reach: empty on a good map.
static func deploy_ap_clashes(m: TacMap) -> Array:
	var los := Los.new(m)
	var out := []
	for a in access_point_cells(m):
		for v in deploy_cells(m):
			if jack_reach(los, v, a):
				out.append([v, a])
	return out


## Every target NET must be reachable on foot (procgen survey: single-terminal sites behind locked
## doors left data gigs unplayable). If no access point can be stood near from the deploy zone
## without breaching, a public maintenance junction box goes on a reachable wall inside (or
## against) the target building, wired to its shallowest hub, but never within jack-in reach of
## the deploy zone (AP_CLEAR_M: it used to go on the reachable square nearest the zone, which
## against a near start's facade was a deploy square itself).
static func _ensure_public_access(m: TacMap) -> void:
	var deploy := m.entrances.filter(func(e): return e.kind == "deploy")
	if deploy.is_empty():
		return
	var los := Los.new(m)
	var dcells := deploy_cells(m)
	var nav := Nav.new(m)
	var origin: Vector2i = deploy[0].pos
	var field: Dictionary = nav.distance_field([Vector3i(origin.x, origin.y, m.street)], {}, 3000)
	for st in m.structures:
		if not st.target or not m.architectures.has(st.id):
			continue
		var a: NetArchitecture = m.architectures[st.id]
		var reachable := false
		for ap in a.access_points:
			var d: Dictionary = m.devices[ap.device]
			var dp := Vector3i(d.pos.x, d.pos.y, d.floor)
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var v := Vector3i(d.pos.x + dx, d.pos.y + dy, d.floor)
					# the jack-in rule (Encounter._wall_between): walls and closed doors block the line
					if field.has(v) and Los.distance_m(v, dp) <= 6.0 and not Los.ray(v, dp).any(func(r): return m.t(r.z, r.x, r.y) in [TacMap.T.WALL, TacMap.T.DOOR]):
						reachable = true
		if reachable:
			continue
		# the reachable floor cell beside a wall of the target that's closest to the deploy zone, out of
		# jack-in reach of it
		var best := Vector3i(-1, -1, -1)
		var best_d := INF
		for cell in field:
			var l := m.label(cell.z, cell.x, cell.y)
			var inside: bool = l >= 0 and m.rooms[l].structure == st.id
			var beside := MapGen.DIRS.any(func(dd): return m.inb(cell.x + dd.x, cell.y + dd.y) and m.t(cell.z, cell.x + dd.x, cell.y + dd.y) == TacMap.T.WALL \
				and m.label(cell.z, cell.x + dd.x * 2, cell.y + dd.y * 2) >= 0 and m.rooms[m.label(cell.z, cell.x + dd.x * 2, cell.y + dd.y * 2)].structure == st.id)
			if (inside or beside) and not m.has_cover_at(cell.z, Vector2i(cell.x, cell.y)) and m.devices.all(func(o): return not (o.floor == cell.z and o.pos == Vector2i(cell.x, cell.y))):
				var dd2 := float(field[cell]) + (0.0 if inside else 6.0)
				if dd2 < best_d and not any_jack_reach(los, dcells, [cell]):
					best_d = dd2
					best = cell
		if best.x < 0:   # fenced or walled-off sites: a field relay on the reachable square nearest the target
			var tc := Vector2((st.rect as Rect2i).get_center()) if st.has("rect") else Vector2(m.w / 2.0, m.h / 2.0)
			for cell in field:
				var dd3: float = Vector2(cell.x, cell.y).distance_to(tc) + absi(m.level(cell.z)) * 4.0
				if dd3 < best_d and not m.has_cover_at(cell.z, Vector2i(cell.x, cell.y)) and not any_jack_reach(los, dcells, [cell]):
					best_d = dd3
					best = cell
		if best.x < 0:
			continue
		var dev := {"id": m.devices.size(), "type": "junction", "floor": best.z, "pos": Vector2i(best.x, best.y),
			"room": m.label(best.z, best.x, best.y), "zone": TacMap.Zone.PUBLIC, "group": "", "structure": st.id, "access_point": true}
		m.devices.append(dev)
		var hub := -1
		for n in a.nodes:
			if n.type == "hub" and (hub < 0 or int(n.zone) < int(a.nodes[hub].zone)):
				hub = n.id
		if hub < 0:
			continue
		var port := a.add_node({"type": "port", "zone": a.nodes[hub].zone, "subnet": a.nodes[hub].subnet, "device": dev.id})
		a.link(hub, port)
		a.access_points.append({"device": dev.id, "entry_node": port})


## Crew deployment (params.deploy, data/gen/scenes.json; a set piece's params can override it):
## - "near": a short walk from the target's street door (DEPLOY_NEAR squares over open ground,
##   e.g. across the street), so the crew isn't hunting for the way in (playtest round 4);
## - "far" (the default; open ground and stealth approaches): the street spawn farthest from the
##   door becomes the insertion zone.
## The other spawns stay reinforcement entry points. The zone is the 6 nearest open street-level
## squares. "near" falls back to "far" when no open ground fits (a door into a walled yard). Either
## way no square of the zone is within jack-in reach of an access point (AP_CLEAR_M): a near zone
## by a street-facing terminal's window looks elsewhere, and a far one prefers a clear spawn.
static func _deploy_zone(c: Dictionary) -> void:
	var m: TacMap = c.m
	var los := Los.new(m)
	var aps := access_point_cells(m)
	if String(c.p.get("deploy", "far")) == "near" and _deploy_near(m, los, aps):
		return
	var door := Vector2i(m.w / 2, m.h / 2)
	for e in m.entrances:
		if e.main:
			door = e.pos
	var best := -1
	var best_d := -(1 << 40)
	for i in m.entrances.size():
		var e: Dictionary = m.entrances[i]
		if e.kind == "spawn" and m.walkable(m.street, e.pos):
			var dd := absi(e.pos.x - door.x) + absi(e.pos.y - door.y)
			var cells := (_deploy_cells(m, e.pos) as Array).map(func(v): return Vector3i(v.x, v.y, m.street))
			if any_jack_reach(los, cells, aps):
				dd -= 1 << 30   # a last resort only
			if dd > best_d:
				best_d = dd
				best = i
	if best < 0:
		return
	var origin: Vector2i = m.entrances[best].pos
	m.entrances[best].kind = "deploy"
	m.entrances[best]["cells"] = _deploy_cells(m, origin)


## Walking distance in squares (2 m) from the step outside the target's main door to a "near"
## deploy zone's first square: [min, goal, max]. 7 squares is 14 m: across a street or a forecourt.
const DEPLOY_NEAR := [4, 7, 12]
const DEPLOY_SIZE := 6
## A near start that only finds squares in jack-in reach of an access point within DEPLOY_NEAR's max
## (an open forecourt with a jack-in camera by the door, as at Totentanz) looks out to this walk
## before it gives up and deploys far: a slightly longer approach beats one across the map.
const DEPLOY_NEAR_STRETCH := 20


## The DEPLOY_SIZE nearest open (OUTSIDE, uncovered) street-level squares from `origin`, origin first.
static func _deploy_cells(m: TacMap, origin: Vector2i) -> Array:
	var cells: Array = [origin]
	var seen := {origin: true}
	var q: Array = [origin]
	while not q.is_empty() and cells.size() < DEPLOY_SIZE:
		var v: Vector2i = q.pop_front()
		for d in MapGen.DIRS:
			var n: Vector2i = v + d
			if not seen.has(n) and m.inb(n.x, n.y) and m.t(m.street, n.x, n.y) == TacMap.T.OUTSIDE and not m.has_cover_at(m.street, n):
				seen[n] = true
				q.append(n)
				if cells.size() < DEPLOY_SIZE:
					cells.append(n)
	return cells


## Ground a crew can start on: street level, outdoors, no cover, and public (the street or a
## public yard, not a fenced secure compound).
static func _deploy_open(m: TacMap, v: Vector2i) -> bool:
	var s := m.street
	if not m.inb(v.x, v.y) or m.t(s, v.x, v.y) != TacMap.T.OUTSIDE or m.has_cover_at(s, v):
		return false
	var l := m.label(s, v.x, v.y)
	return l < 0 or int(m.rooms[l].zone) <= TacMap.Zone.PUBLIC


## The "near" deploy zone: walk the open ground (and unlocked-looking public gates) out from the
## step in front of the target's main door and take the square closest to DEPLOY_NEAR's goal
## distance that has room for the whole crew, the open street before yards, and that a street
## spawn can reach too (not a pocket the crew can't leave), and out of jack-in reach of every
## access point `aps` (AP_CLEAR_M), out to DEPLOY_NEAR_STRETCH if it must. False if there's none.
static func _deploy_near(m: TacMap, los: Los, aps: Array) -> bool:
	var door := m.main_entrance()
	if door.is_empty():
		return false
	var s := m.street
	var step := Vector2i(-1, -1)
	for d in MapGen.DIRS:
		var n: Vector2i = Vector2i(door.pos) + d
		if _deploy_open(m, n):
			step = n
			break
	if step.x < 0:
		return false
	var dist := {step: 0}
	var q: Array = [step]
	while not q.is_empty():
		var v: Vector2i = q.pop_front()
		if int(dist[v]) >= DEPLOY_NEAR_STRETCH:
			continue
		for d in MapGen.DIRS:
			var n: Vector2i = v + d
			if dist.has(n) or not m.inb(n.x, n.y):
				continue
			var gate := m.t(s, n.x, n.y) == TacMap.T.DOOR and m.doors.any(func(o): return o.floor == s and o.pos == n and o.get("gate", false) and not o.security)
			if gate or _deploy_open(m, n):
				dist[n] = int(dist[v]) + 1
				q.append(n)
	var spawn_reach := {}
	for e in m.entrances:
		if e.kind == "spawn" and m.walkable(s, e.pos):
			spawn_reach = m.reachable(Vector3i(e.pos.x, e.pos.y, s))
			break
	var best := Vector2i(-1, -1)
	for reach_max in [int(DEPLOY_NEAR[2]), DEPLOY_NEAR_STRETCH]:
		var best_score := INF
		for v in dist:
			var dd := int(dist[v])
			if dd < int(DEPLOY_NEAR[0]) or dd > reach_max or not _deploy_open(m, v):
				continue
			if not spawn_reach.is_empty() and not spawn_reach.has(Vector3i(v.x, v.y, s)):
				continue
			var sc := absf(dd - float(DEPLOY_NEAR[1])) + (0.0 if m.label(s, v.x, v.y) < 0 else 3.0)
			if sc >= best_score:
				continue
			var cells := _deploy_cells(m, v)
			if cells.size() < DEPLOY_SIZE or any_jack_reach(los, cells.map(func(c): return Vector3i(c.x, c.y, s)), aps):
				continue
			best_score = sc
			best = v
		if best.x >= 0:
			break
	if best.x < 0:
		return false
	m.entrances.append({"floor": s, "pos": best, "main": false, "kind": "deploy", "near": true, "cells": _deploy_cells(m, best)})
	return true


## Guard posts for placing defenders in M3: the middle of guard rooms, and the secure side of
## every security door and gate.
const POST_ROOMS := ["security_office", "guard_booth", "armory", "vip_lounge", "bridge", "boss_room", "gangway_hall", "lobby", "compound_yard", "data_vault"]


static func _guard_posts(m: TacMap) -> void:
	var rooms_def := RulesDB.gen("rooms.json")
	for r in m.rooms:
		if r.cells == 0 or not (r.kind in POST_ROOMS or bool(rooms_def.get(r.kind, {}).get("post", false))):
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

## A site with its own size (sites.json `footprint: {w, d}` in squares along / into the entrance
## facade, `floors: [min, max]`) sizes a lone building's map to it: the plot plus the street and
## alley. Whatever the caller sets explicitly wins.
static func _site_size(dice: Dice, p: Dictionary, overrides: Dictionary) -> void:
	var sdef: Dictionary = RulesDB.gen("sites.json").get(String(p.get("site", "corp_office")), {})
	if sdef.has("footprint") and not overrides.has("w") and not overrides.has("h"):
		var fw: Array = sdef.footprint.w
		var fd: Array = sdef.footprint.d
		p.w = dice.rng.randi_range(int(fw[0]), int(fw[1])) + 3
		p.h = dice.rng.randi_range(int(fd[0]), int(fd[1])) + 3
	if sdef.has("floors") and not overrides.has("floors") and int(p.get("verticality", 1)) > 0:
		p.floors = dice.rng.randi_range(int(sdef.floors[0]), int(sdef.floors[1]))


## The original: one building on a street corner (street south, alley east).
static func _lone_building(c: Dictionary) -> void:
	var m: TacMap = c.m
	ground(c, Rect2i(0, m.h - 3, m.w, 3), G.ASPHALT)
	ground(c, Rect2i(m.w - 3, 0, 3, m.h), G.GRAVEL)
	building(c, Rect2i(0, 0, m.w - 3, m.h - 3), String(c.p.get("site", "corp_office")), int(c.p.floors), int(c.p.security), true, TacMap.Zone.PUBLIC, "S")
	spawn(c, Vector2i(0, m.h - 2))
	spawn(c, Vector2i(m.w - 2, 0))


## Skirmish: a small test map (M3 playtest verdict): one building on a street with a back
## alley and a few crates, so guards start within a couple of moves of the crew.
static func _skirmish(c: Dictionary) -> void:
	var m: TacMap = c.m
	road(c, Rect2i(0, m.h - 6, m.w, 6), true)
	ground(c, Rect2i(0, 0, m.w, m.h - 6), G.CONCRETE)
	ground(c, Rect2i(0, 0, 3, m.h - 6), G.GRAVEL)
	building(c, Rect2i(3, 1, m.w - 6, m.h - 8), String(c.p.get("site", "bar")), int(c.p.floors), int(c.p.security), true, TacMap.Zone.PUBLIC, "S")
	props(c, Rect2i(3, m.h - 6, m.w - 6, 6), "dumpster", 2)
	for i in 3:
		var v := Vector2i(c.dice.rng.randi_range(3, m.w - 4), c.dice.rng.randi_range(m.h - 5, m.h - 2))   # clear of the spawns
		if m.t(0, v.x, v.y) == TacMap.T.OUTSIDE and not m.has_cover_at(0, v):
			m.add_cover(Furnish.cover_entry("crate", 0, v, -1))
	spawn(c, Vector2i(0, m.h - 2))
	spawn(c, Vector2i(m.w - 1, m.h - 2))


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
