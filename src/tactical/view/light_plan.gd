class_name LightPlan
extends RefCounted
## Where the lights go (M4 visual pass: "lots of neon with light spill", spec). Pure data so it's
## testable headless; the greybox turns entries into OmniLights and emissive meshes.
## Entry: {kind: sign|lamp|room|hazard, cell: Vector3i, out: Vector2i (facing, signs), color, energy, range}

const NEON := [Color("ff2a6d"), Color("05d9e8"), Color("f9c80e"), Color("b537f2"), Color("ff6b1a"), Color("39f0a0")]
const ZONE_LIGHT := [Color("ffb070"), Color("ffc890"), Color("d0e2ff"), Color("5fe8d0"), Color("ff4040")]
const LAMP := [Color("ff9a3c"), Color("ffb070"), Color("a8c4ff")]
const LAMP_SPACING := 9


static func plan(m: TacMap, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := []
	var neon: Array = SceneTheme.colors(m, "neon", NEON)
	var zone_light: Array = SceneTheme.colors(m, "zone_light", ZONE_LIGHT)
	var lamps: Array = SceneTheme.colors(m, "lamp", LAMP)
	var bulkhead := String(SceneTheme.of(m).get("lamp_style", "pole")) == "bulkhead"
	var fire_col := Color(String(SceneTheme.of(m).get("fire", "ff8a30")))
	var lamp_keep := float(SceneTheme.of(m).get("lamp_keep", 1.0))
	var blaze := float(SceneTheme.of(m).get("blaze", 0.0))
	# Neon signs over every entrance that opens onto the street, colour per structure. A district
	# with few signs (DistrictLook signs < 1) keeps only some; none where the power's gone.
	var signs := SceneTheme.signs(m)
	for e in m.entrances:
		if e.kind != "door":
			continue
		if signs < 1.0 and posmod(hash(Vector3i(e.pos.x, e.pos.y, seed_value)), 1000) >= int(signs * 1000.0):
			continue
		var f: int = e.get("floor", 0)
		var face := _outward(m, f, e.pos)
		if face == Vector2i.ZERO:
			continue
		var sid: int = e.get("structure", -1)
		var col: Color = neon[posmod(hash(sid * 7919 + seed_value), neon.size())]
		out.append({"kind": "sign", "cell": Vector3i(e.pos.x, e.pos.y, f), "out": face, "color": col,
			"energy": 2.2 if e.get("main", false) else 1.2, "range": 7.0 if e.get("main", false) else 4.5})
	# Street lamps along sidewalks (or road edges), thinned by spacing.
	var taken: Array[Vector2i] = []
	var lamp_col: Color = lamps[rng.randi() % lamps.size()]
	var spacing := 7 if bulkhead else LAMP_SPACING
	for y in m.h:
		for x in m.w:
			if m.t(0, x, y) != TacMap.T.OUTSIDE or m.ground[y * m.w + x] != TacMap.G.SIDEWALK or m.has_cover_at(0, Vector2i(x, y)):
				continue
			var p := Vector2i(x, y)
			var face := Vector2i.ZERO   # bulkhead lamps hang on a wall: the direction out of it
			if bulkhead:
				for d in MapGen.DIRS:
					if m.inb(x - d.x, y - d.y) and m.t(0, x - d.x, y - d.y) == TacMap.T.WALL:
						face = d
						break
				if face == Vector2i.ZERO:
					continue
			if taken.any(func(q): return q.distance_squared_to(p) < spacing * spacing):
				continue
			taken.append(p)
			if rng.randf() > lamp_keep:   # the power's out in a burning district
				continue
			out.append({"kind": "lamp", "cell": Vector3i(x, y, 0), "out": face, "color": lamp_col, "energy": 1.1 if bulkhead else 0.9, "range": 6.0 if bulkhead else 7.0})
	# Outdoor lots get a lamp of their own (owner round 6: empty dark lots): a work light on a
	# construction site, park and plaza lamps, a sodium lamp over parking.
	const LOT_LIGHT := {"construction_site": "ffc860", "park": "c8ffd8", "plaza": "ffd8a8", "parking_lot": "ffb070", "market": "ffc890"}
	for r in m.rooms:
		if not r.get("outdoor", false) or r.floor != 0 or not LOT_LIGHT.has(String(r.kind)) or r.cells < 12:
			continue
		var b: Rect2i = r.bounds
		var spot := Vector2i(-1, -1)
		for k in 30:   # a free square of the lot, toward its middle
			var v := b.get_center() + Vector2i(rng.randi_range(-b.size.x / 4, b.size.x / 4), rng.randi_range(-b.size.y / 4, b.size.y / 4))
			if m.inb(v.x, v.y) and m.label(0, v.x, v.y) == r.id and not m.has_cover_at(0, v):
				spot = v
				break
		if spot.x >= 0 and rng.randf() < lamp_keep:
			out.append({"kind": "lamp", "cell": Vector3i(spot.x, spot.y, 0), "out": Vector2i.ZERO, "color": Color(LOT_LIGHT[String(r.kind)]), "energy": 1.2, "range": 8.0})
	# Outside the city (few lamps): a few burning barrels / fire pits near cover, for warm pools.
	if out.filter(func(x): return x.kind == "lamp").size() < 2:
		var spots: Array[Vector2i] = []
		for c in m.cover:
			if c.floor != 0:
				continue
			for d in MapGen.DIRS:
				var v: Vector2i = Vector2i(c.pos.x, c.pos.y) + d
				if m.inb(v.x, v.y) and m.t(0, v.x, v.y) == TacMap.T.OUTSIDE and not m.has_cover_at(0, v):
					spots.append(v)
					break
		var placed: Array[Vector2i] = []
		for i in 40:
			if spots.is_empty() or placed.size() >= 3:
				break
			var v: Vector2i = spots[rng.randi() % spots.size()]
			if placed.any(func(q): return q.distance_to(v) < 12):
				continue
			placed.append(v)
			out.append({"kind": "fire", "cell": Vector3i(v.x, v.y, 0), "out": Vector2i.ZERO, "color": fire_col, "energy": 2.2, "range": 7.0})
	# Burning scenes: wrecks, cars and rubble heaps on fire (one blaze per prop), spaced out.
	if blaze > 0.0:
		var lit := {}
		var spots2: Array[Vector2i] = []
		for cv in m.cover:
			if cv.floor != 0 or not String(cv.kind) in ["wreck", "car", "rubble"]:
				continue
			var key: int = int(cv.get("prop", -1))
			if key >= 0 and lit.has(key):
				continue
			lit[key] = true
			var v := Vector2i(cv.pos.x, cv.pos.y)
			if posmod(hash(v * 31 + Vector2i(seed_value, 7)), 1000) >= int(blaze * (1000 if cv.kind != "rubble" else 550)):
				continue
			if spots2.any(func(q): return q.distance_to(v) < 6):
				continue
			spots2.append(v)
			out.append({"kind": "blaze", "cell": Vector3i(v.x, v.y, 0), "out": Vector2i.ZERO, "color": fire_col, "energy": 2.8, "range": 9.0})
	# One light per indoor room (big rooms get two), tinted by security level.
	for r in m.rooms:
		if r.cells < 4 or r.get("outdoor", false) or r.floor < 0 or r.kind == "void":
			continue
		var b: Rect2i = r.bounds
		var spots: Array[Vector2i] = [b.get_center()]
		if r.cells >= 60:
			var horiz := b.size.x >= b.size.y
			spots = [b.position + (Vector2i(b.size.x / 4, b.size.y / 2) if horiz else Vector2i(b.size.x / 2, b.size.y / 4)),
				b.position + (Vector2i(b.size.x * 3 / 4, b.size.y / 2) if horiz else Vector2i(b.size.x / 2, b.size.y * 3 / 4))]
		for s in spots:
			if m.label(r.floor, s.x, s.y) != r.id:
				continue
			out.append({"kind": "room", "cell": Vector3i(s.x, s.y, r.floor), "out": Vector2i.ZERO,
				"color": zone_light[clampi(r.zone, 0, 4)], "energy": 2.2 if r.zone < TacMap.Zone.SECURE else 2.6, "range": 7.5})
	# Hazards glow: electrified transformers blue, explosive barrels a faint orange.
	for c in m.cover:
		var hz: String = c.get("hazard", "")
		if hz != "":
			out.append({"kind": "hazard", "cell": Vector3i(c.pos.x, c.pos.y, c.floor), "out": Vector2i.ZERO,
				"color": Color("6fb8ff") if hz == "electrified" else Color("ff7a2a"), "energy": 0.8, "range": 3.0})
	return out


## Direction from an entrance cell to the open street (zero if none).
static func _outward(m: TacMap, f: int, p: Vector2i) -> Vector2i:
	for d in MapGen.DIRS:
		var n: Vector2i = p + d
		if m.inb(n.x, n.y) and m.t(f, n.x, n.y) == TacMap.T.OUTSIDE and m.label(f, n.x, n.y) < 0:
			return d
	for d in MapGen.DIRS:
		var n: Vector2i = p + d
		if m.inb(n.x, n.y) and m.t(f, n.x, n.y) == TacMap.T.OUTSIDE:
			return d
	return Vector2i.ZERO
