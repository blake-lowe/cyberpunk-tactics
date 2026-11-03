class_name ThemedScenes
extends RefCounted
## Planners for the themed scenes (owner: "new scenes that are visually distinct"): the undercity
## (storm drains and service tunnels), the arcology concourse, and a burning combat zone. They use
## SceneGen's building blocks; their look lives in SceneTheme and the greybox LOOKS.

const G := TacMap.G
const T := TacMap.T



# --- Undercity -------------------------------------------------------------------------------

## Storm drains and maintenance tunnels under the city. A main collector (a runoff channel between
## two ledges, with plank crossings) runs in from the west; a second collector crosses it at a
## cistern. Dry service tunnels link pump rooms on a jittered grid and flank the target's vault, a
## big chamber at the east end with the target building inside it. Everything that isn't carved
## stays VOID and is drawn as solid rock.
static func undercity(c: Dictionary) -> void:
	var m: TacMap = c.m
	var rng: RandomNumberGenerator = c.dice.rng
	var sec := int(c.p.security)
	var open := {}
	var carve := func(r: Rect2i, g: int) -> void:
		for y in range(maxi(r.position.y, 0), mini(r.end.y, m.h)):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, m.w)):
				var v := Vector2i(x, y)
				if open.get(v, "") == "water":
					continue
				m.set_t(0, x, y, T.OUTSIDE)
				m.set_ground(x, y, g)
				open[v] = "dry"
	var flood := func(r: Rect2i) -> void:
		for y in range(maxi(r.position.y, 0), mini(r.end.y, m.h)):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, m.w)):
				m.set_t(0, x, y, T.WATER)
				m.set_ground(x, y, G.NONE)
				open[Vector2i(x, y)] = "water"
	# The vault: the target's chamber at the east end.
	var vault := Rect2i(m.w - 31, m.h / 2 - 11 + rng.randi_range(-2, 2), 28, 22)
	var ym := vault.get_center().y + rng.randi_range(-3, 3)   # main collector's centre row
	var xv := rng.randi_range(14, vault.position.x - 14)       # cross collector's centre column
	# Main collector: ledges (SIDEWALK, lamps hang over them) either side of a 3-wide channel.
	carve.call(Rect2i(0, ym - 3, vault.position.x + 1, 7), G.SIDEWALK)
	flood.call(Rect2i(0, ym - 1, vault.position.x - 2, 3))
	# Cross collector, north to south.
	carve.call(Rect2i(xv - 3, 0, 7, m.h), G.SIDEWALK)
	flood.call(Rect2i(xv - 1, 0, 3, ym - 6))
	flood.call(Rect2i(xv - 1, ym + 7, 3, m.h - ym - 7))
	# The cistern where they meet: a ring walkway round a square pool.
	carve.call(Rect2i(xv - 6, ym - 6, 13, 13), G.CONCRETE)
	for v in open.keys():   # the pool replaces the channels' crossing
		if Rect2i(xv - 6, ym - 6, 13, 13).has_point(v) and open[v] == "water":
			m.set_t(0, v.x, v.y, T.OUTSIDE)
			m.set_ground(v.x, v.y, G.CONCRETE)
			open[v] = "dry"
	flood.call(Rect2i(xv - 2, ym - 2, 5, 5))
	# Plank crossings over the channels every ~9 squares (2 wide), away from the cistern.
	var x := 4 + rng.randi_range(0, 3)
	while x < vault.position.x - 4:
		if absi(x - xv) > 9:
			for xx in [x, x + 1]:
				for yy in range(ym - 1, ym + 2):
					m.set_t(0, xx, yy, T.OUTSIDE)
					m.set_ground(xx, yy, G.DOCK)
					open[Vector2i(xx, yy)] = "dry"
					c.reserved[Vector2i(xx, yy)] = true
		x += rng.randi_range(8, 11)
	for yy0 in [rng.randi_range(4, 8), rng.randi_range(m.h - 10, m.h - 6)]:
		for yy in [yy0, yy0 + 1]:
			for xx in range(xv - 1, xv + 2):
				if open.get(Vector2i(xx, yy), "") == "water":
					m.set_t(0, xx, yy, T.OUTSIDE)
					m.set_ground(xx, yy, G.DOCK)
					open[Vector2i(xx, yy)] = "dry"
					c.reserved[Vector2i(xx, yy)] = true
	# Pump rooms on a jittered grid west of the vault, linked by 3-wide service tunnels.
	var nodes: Array[Vector2i] = []
	var cols := [rng.randi_range(5, 8), xv + rng.randi_range(-2, 2), vault.position.x - rng.randi_range(5, 8)]
	var rows := [rng.randi_range(5, 8), m.h - rng.randi_range(6, 9)]
	for cx in cols:
		for cy in rows:
			nodes.append(Vector2i(cx, cy))
	var tunnel := func(a: Vector2i, b: Vector2i) -> void:   # L-shaped, 3 wide
		var corner := Vector2i(b.x, a.y) if rng.randf() < 0.5 else Vector2i(a.x, b.y)
		carve.call(Rect2i(mini(a.x, corner.x) - 1, mini(a.y, corner.y) - 1, absi(a.x - corner.x) + 3, absi(a.y - corner.y) + 3), G.CONCRETE)
		carve.call(Rect2i(mini(b.x, corner.x) - 1, mini(b.y, corner.y) - 1, absi(b.x - corner.x) + 3, absi(b.y - corner.y) + 3), G.CONCRETE)
	for i in nodes.size():   # along each row, and down to the main collector
		var n: Vector2i = nodes[i]
		if i + 2 < nodes.size():
			tunnel.call(n, nodes[i + 2])
		if rng.randf() < 0.7 or i == 0:
			tunnel.call(n, Vector2i(n.x + rng.randi_range(-2, 2), ym + (-4 if n.y < ym else 4)))
	var pumps: Array[Rect2i] = []
	for n in nodes:
		var r := Rect2i(n.x - rng.randi_range(2, 3), n.y - rng.randi_range(2, 3), rng.randi_range(5, 7), rng.randi_range(5, 7))
		carve.call(r, G.CONCRETE)
		pumps.append(r)
	# Flanking tunnels: from the pump rooms nearest the vault into its north and south sides.
	var vn := Vector2i(vault.position.x + rng.randi_range(6, vault.size.x - 8), vault.position.y)
	var vs := Vector2i(vault.position.x + rng.randi_range(6, vault.size.x - 8), vault.end.y - 1)
	tunnel.call(nodes[4], Vector2i(vn.x, nodes[4].y))
	carve.call(Rect2i(vn.x - 1, nodes[4].y, 3, vault.position.y - nodes[4].y + 1), G.CONCRETE)
	tunnel.call(nodes[5], Vector2i(vs.x, nodes[5].y))
	carve.call(Rect2i(vs.x - 1, vault.end.y - 1, 3, nodes[5].y - vault.end.y + 2), G.CONCRETE)
	# The vault floor, and the walls: every solid square touching an open one.
	carve.call(vault, G.CONCRETE)
	for y in m.h:
		for xx in m.w:
			if open.has(Vector2i(xx, y)):
				continue
			var edge := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if open.has(Vector2i(xx + dx, y + dy)):
						edge = true
			if edge:
				m.set_t(0, xx, y, T.WALL)
				m.wall_mat[0][y * m.w + xx] = 1
	# The target, low and sealed, in the middle of the vault, its door toward the collector.
	var site := String(c.overrides.get("site", ""))
	if site == "":
		site = ["gang_hideout", "data_center", "clinic", "chop_shop"][rng.randi() % 4]
	var shell := Rect2i(vault.position.x + 5, vault.position.y + 4, vault.size.x - 9, vault.size.y - 8)
	SceneGen.reserve(c, Rect2i(vault.position.x, ym - 3, 5, 7))
	var tgt := SceneGen.building(c, shell, site, 1, sec, true, TacMap.Zone.STAFF, "W")
	var sid := SceneGen.outdoor_structure(c, "compound", sec, vault)
	SceneGen.related(c, tgt.id, sid, 0.9)
	var vroom := SceneGen.yard(c, vault, "compound_yard", TacMap.Zone.STAFF, sid)
	vroom.kind = "compound_yard"
	Furnish.run_structure(m, c.dice, sid)
	if m.devices.any(func(d): return d.structure == sid):
		m.architectures[sid] = NetGen.generate(m, c.dice, sid)
	# Junk in the pump rooms and along the tunnels: crates, drums, the odd leaking fuel barrel.
	for r in pumps:
		for k in rng.randi_range(2, 4):
			var v := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
			var piece: String = ["crate", "barrel", "crate", "fuel_barrel", "machine"][rng.randi() % 5]
			Furnish.try_prop(m, 0, Rect2i(v, Vector2i.ONE), piece, -1, {}, c.reserved)
	for k in m.w * m.h / 220:
		var v := Vector2i(rng.randi_range(1, m.w - 2), rng.randi_range(1, m.h - 2))
		if open.get(v, "") != "dry" or m.ground[v.y * m.w + v.x] != G.CONCRETE or m.label(0, v.x, v.y) >= 0:
			continue
		var walls := 0
		var across := 0
		for d in MapGen.DIRS:
			if m.t(0, v.x + d.x, v.y + d.y) == T.WALL:
				walls += 1
				if open.get(v - d * 2, "") == "dry":
					across += 1
		if walls == 1 and across == 1:   # against a wall, tunnel stays passable
			Furnish.try_prop(m, 0, Rect2i(v, Vector2i.ONE), ["crate", "barrel", "pallet"][rng.randi() % 3], -1, {}, c.reserved)
	_keep_connected(c, Vector2i(0, ym - 3))
	# Ways in: the collector's mouth (deploy), and the cross collector's two ends (backup).
	SceneGen.spawn(c, Vector2i(0, ym - 3))
	SceneGen.spawn(c, Vector2i(xv - 3, 0))
	SceneGen.spawn(c, Vector2i(xv + 3, m.h - 1))


## Remove props that cut part of the open ground off from `anchor`.
static func _keep_connected(c: Dictionary, anchor: Vector2i) -> void:
	var m: TacMap = c.m
	for pass_i in 20:
		var reach := m.reachable(Vector3i(anchor.x, anchor.y, 0))
		var lost := Vector2i(-1, -1)
		for y in m.h:
			for x in m.w:
				if m.t(0, x, y) == T.OUTSIDE and m.label(0, x, y) < 0 and not reach.has(Vector3i(x, y, 0)) and not m.has_cover_at(0, Vector2i(x, y)):
					lost = Vector2i(x, y)
					break
			if lost.x >= 0:
				break
		if lost.x < 0:
			return
		# drop the cover pieces next to the lost square
		var drop: Array[Vector2i] = []
		for cv in m.cover:
			if cv.floor == 0 and Vector2i(cv.pos.x, cv.pos.y).distance_to(lost) <= 1.5:
				drop.append(Vector2i(cv.pos.x, cv.pos.y))
		if drop.is_empty():
			return
		for v in drop:
			m.remove_cover_at(0, v)


# --- Arcology ---------------------------------------------------------------------------------

## The floor of a corporate arcology's atrium (the surround draws its tiered white walls). A
## service lane at the west end where the crew comes in; a promenade of pale stone round a long
## reflecting pool, with planters and benches; boutiques, a bar and a clinic along both sides; and
## the corp's offices filling the east end behind a security line of barriers.
static func arcology(c: Dictionary) -> void:
	var m: TacMap = c.m
	var rng: RandomNumberGenerator = c.dice.rng
	var sec := int(c.p.security)
	SceneGen.ground(c, Rect2i(0, 0, m.w, m.h), G.CONCRETE)
	SceneGen.road(c, Rect2i(0, 0, 7, m.h), false)   # service lane
	var site := String(c.overrides.get("site", ""))
	if site == "":
		site = ["corp_office", "corp_hq", "data_center", "clinic"][rng.randi() % 4]
	var hq := Rect2i(m.w - 25, 5, 22, m.h - 10)
	var hq_st := SceneGen.building(c, hq, site, int(c.p.floors), sec, true, TacMap.Zone.PUBLIC, "W")
	var x0 := 10
	var x1 := hq.position.x - 6
	var mid := m.h / 2
	# Boutique rows on both sides of the promenade, doors facing it.
	var shops := ["shop", "bar", "clinic", "club", "capsule_hotel", "shop", "bd_parlor"]
	var row_d := mid - 9
	var built: Array = []
	for north in [true, false]:
		var x := x0
		while x < x1 - 9:
			var w := mini(rng.randi_range(10, 15), x1 - x)
			var r := Rect2i(x, 2, w, row_d - 2) if north else Rect2i(x, mid + 9, w, m.h - mid - 11)
			var st := SceneGen.building(c, r, shops[rng.randi() % shops.size()], rng.randi_range(1, 2), maxi(sec - 1, 0), false, TacMap.Zone.PUBLIC, "S" if north else "N")
			built.append(st)
			x += w + 2
	for st in built:   # a bridge from the nearest boutique block to the offices' upper floor
		if SceneGen.skybridge(c, st, hq_st):
			break
	# The reflecting pool with a raised stone rim (SIDEWALK: lamps stand on it), planters along it.
	var pool := Rect2i(x0 + 6, mid - 2, x1 - x0 - 12, 4)
	SceneGen.ground(c, pool.grow(2), G.SIDEWALK)
	SceneGen.water(c, pool)
	var sid := SceneGen.outdoor_structure(c, "campus", maxi(sec - 1, 0), Rect2i(x0, row_d, x1 - x0 + 5, mid + 9 - row_d))
	SceneGen.related(c, sid, hq_st.id, 0.7)
	SceneGen.yard(c, Rect2i(x0, row_d + 1, x1 - x0 + 5, mid + 8 - row_d - 1), "plaza", TacMap.Zone.PUBLIC, sid)
	Furnish.run_structure(m, c.dice, sid)
	if m.devices.any(func(d): return d.structure == sid):
		m.architectures[sid] = NetGen.generate(m, c.dice, sid)
	var x := pool.position.x
	while x < pool.end.x:   # planters with trees in pairs either side of the pool
		for yy in [pool.position.y - 4, pool.end.y + 3]:
			Furnish.try_prop(m, 0, Rect2i(x, yy, 1, 1), "tree" if (x / 7) % 2 == 0 else "planter", -1, {}, c.reserved)
		x += 7
	# The security line in front of the offices: barriers with gaps, a kiosk for the desk.
	var lx := hq.position.x - 4
	for yy in range(hq.position.y, hq.end.y):
		if (yy - hq.position.y) % 5 in [0, 1, 2] and absi(yy - hq.get_center().y) > 2:
			Furnish.try_prop(m, 0, Rect2i(lx, yy, 1, 1), "barrier", -1, {}, c.reserved)
	Furnish.try_prop(m, 0, Rect2i(lx - 2, hq.get_center().y + 3, 1, 1), "kiosk", -1, {}, c.reserved)
	_keep_connected(c, Vector2i(1, mid))
	SceneGen.spawn(c, Vector2i(1, 1))
	SceneGen.spawn(c, Vector2i(1, m.h - 2))
	SceneGen.spawn(c, Vector2i((x0 + x1) / 2, 0))


# --- Warzone ----------------------------------------------------------------------------------

## A combat zone burning at dusk: the burning-zone district profile (heavily ruined blocks,
## wrecks everywhere), plus craters blown in the streets and rubble heaps. Fires and smoke come
## from the theme (LightPlan sets wrecks alight).
static func warzone(c: Dictionary) -> void:
	var m: TacMap = c.m
	var rng: RandomNumberGenerator = c.dice.rng
	DistrictGen.generate(c, String(c.p.get("profile", "burning_zone")))
	# Craters: scorched earth blown through the asphalt, a rubble heap on the rim.
	for k in m.w * m.h / 700:
		var ctr := Vector2i(rng.randi_range(4, m.w - 5), rng.randi_range(4, m.h - 5))
		if m.t(0, ctr.x, ctr.y) != T.OUTSIDE or m.label(0, ctr.x, ctr.y) >= 0:
			continue
		var rad := rng.randf_range(1.2, 2.4)
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var v := ctr + Vector2i(dx, dy)
				if m.inb(v.x, v.y) and m.t(0, v.x, v.y) == T.OUTSIDE and m.label(0, v.x, v.y) < 0 and Vector2(dx, dy).length() <= rad + rng.randf_range(-0.3, 0.3):
					m.set_ground(v.x, v.y, G.DIRT)
		var rim := ctr + Vector2i(roundi(rad + 1) * (1 if rng.randf() < 0.5 else -1), 0)
		if not c.reserved.has(rim):
			Furnish.try_prop(m, 0, Rect2i(rim, Vector2i.ONE), "rubble", -1, {}, c.reserved)
	var anchor := Vector2i(-1, -1)
	for e in m.entrances:
		if e.kind == "spawn" and m.walkable(0, e.pos):
			anchor = e.pos
			break
	if anchor.x >= 0:
		_keep_connected(c, anchor)
