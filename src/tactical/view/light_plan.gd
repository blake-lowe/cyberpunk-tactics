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
	# Neon signs over every entrance that opens onto the street, colour per structure.
	for e in m.entrances:
		if e.kind != "door":
			continue
		var f: int = e.get("floor", 0)
		var face := _outward(m, f, e.pos)
		if face == Vector2i.ZERO:
			continue
		var sid: int = e.get("structure", -1)
		var col: Color = NEON[posmod(hash(sid * 7919 + seed_value), NEON.size())]
		out.append({"kind": "sign", "cell": Vector3i(e.pos.x, e.pos.y, f), "out": face, "color": col,
			"energy": 2.2 if e.get("main", false) else 1.2, "range": 7.0 if e.get("main", false) else 4.5})
	# Street lamps along sidewalks (or road edges), thinned by spacing.
	var taken: Array[Vector2i] = []
	var lamp_col: Color = LAMP[rng.randi() % LAMP.size()]
	for y in m.h:
		for x in m.w:
			if m.t(0, x, y) != TacMap.T.OUTSIDE or m.ground[y * m.w + x] != TacMap.G.SIDEWALK or m.has_cover_at(0, Vector2i(x, y)):
				continue
			var p := Vector2i(x, y)
			if taken.any(func(q): return q.distance_squared_to(p) < LAMP_SPACING * LAMP_SPACING):
				continue
			taken.append(p)
			out.append({"kind": "lamp", "cell": Vector3i(x, y, 0), "out": Vector2i.ZERO, "color": lamp_col, "energy": 0.9, "range": 7.0})
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
			out.append({"kind": "fire", "cell": Vector3i(v.x, v.y, 0), "out": Vector2i.ZERO, "color": Color("ff8a30"), "energy": 2.2, "range": 7.0})
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
				"color": ZONE_LIGHT[clampi(r.zone, 0, 4)], "energy": 2.2 if r.zone < TacMap.Zone.SECURE else 2.6, "range": 7.5})
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
