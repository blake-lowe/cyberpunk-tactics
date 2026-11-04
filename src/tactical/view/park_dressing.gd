class_name ParkDressing
extends RefCounted
## What makes a theme park read from above (ParkGen's rides and midways; Playland by the Sea,
## NC2045 p.302-313), drawn the way SetPieceDressing draws set-piece props: WorldBuilder hands the
## park's pieces (cover), its decor (queue rails, string-light poles, the coaster's and pavilion's
## markers) and, once per map, the seafront and ride gates to the functions here.
## Rides are scaled down from the real thing (a 20 m wheel, not a 46 m one) so they frame the
## fight instead of hiding it; their tall parts are `shell` materials, so they are never fogged
## (lit rides are landmarks) and dissolve around the focus when they stand in front of it.
## The owner's rule holds: nothing here glows under a unit.

const FH := WorldBuilder.FH
const PIECES := ["wheel", "carousel", "drop_tower", "spinner", "swings", "fountain", "game_booth", "coaster_post", "pavilion_post", "bumper_car", "pine"]
## The pieces drawn once over their whole footprint (the rest are one square each).
const MULTI := ["wheel", "carousel", "drop_tower", "spinner", "swings", "fountain", "game_booth"]
const WARM := Color("ffd8a0")   # incandescent string lights and bulbs


static func has_piece(kind: String) -> bool:
	return kind in PIECES


## A bright light: emissive, never fogged.
static func _lit(wb: WorldBuilder, col: Color, f: int, glow := 1.6) -> Material:
	return wb.mat("dark", f, false, {"glow": glow, "emit": col, "shell": true})


static func _paint(wb: WorldBuilder, col: Color, f: int, shell := false) -> Material:
	return wb.mat("steel", f, false, {"color": col, "shell": shell})


static func _neon(wb: WorldBuilder, i: int) -> Color:
	return wb.neon[posmod(i, wb.neon.size())] if not wb.neon.is_empty() else LightPlan.NEON[posmod(i, LightPlan.NEON.size())]


## A beam (box) from a to b, `t` thick.
static func _beam(wb: WorldBuilder, mt: Material, a: Vector3, b: Vector3, t: float) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var y := d / len
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	wb.put("box", mt, Transform3D(Basis(x, y, z).scaled_local(Vector3(t, len, t)), (a + b) / 2.0))


static func _glow(wb: WorldBuilder, at: Vector3, col: Color, energy: float, rng: float) -> void:
	wb.emitters.append({"cell": Vector3i(clampi(int(at.x), 0, wb.m.w - 1), clampi(int(at.z), 0, wb.m.h - 1), 0), "color": col, "energy": energy, "range": rng, "out": Vector2i.ZERO})


# --- One-square pieces --------------------------------------------------------------------------

static func piece(wb: WorldBuilder, kind: String, p: Vector3, yaw: float, f: int, h0: int) -> void:
	match kind:
		"coaster_post":   # its footing; the lattice up to the track is drawn with the track (decor `coaster`)
			wb.box(wb.mat("concrete_prop", f, false), Vector3(p.x, p.y + 0.1, p.z), Vector3(0.55, 0.2, 0.55))
		"pavilion_post":   # a steel column up to the canopy (decor `pavilion`)
			wb.box(_paint(wb, Color("d8d4e0"), f), p + Vector3(0, 1.25, 0), Vector3(0.2, 2.5, 0.2))
			wb.box(wb.mat("concrete_prop", f, false), p + Vector3(0, 0.08, 0), Vector3(0.4, 0.16, 0.4))
		"bumper_car":   # a round-nosed car in a black rubber bumper, its pole to the ceiling grid
			var col := _neon(wb, h0)
			var yaw2 := yaw * 8.0 + (h0 % 4) * PI / 2
			wb.box(wb.mat("dark", f, false, {"color": Color("101014")}), p + Vector3(0, 0.12, 0), Vector3(0.82, 0.18, 0.62), yaw2)
			wb.box(wb.mat("steel", f, false, {"color": col.darkened(0.1), "glow": 0.35, "emit": col}), p + Vector3(0, 0.27, 0), Vector3(0.7, 0.18, 0.52), yaw2)
			wb.box(wb.mat("dark", f, false), p + Vector3(0, 0.38, 0) + Vector3(-0.12, 0, 0).rotated(Vector3.UP, yaw2), Vector3(0.24, 0.1, 0.38), yaw2)
			wb.put("cyl", _paint(wb, Color("8a8a90"), f), Transform3D(Basis.from_scale(Vector3(0.03, 2.1, 0.03)), p + Vector3(0, 1.4, 0) + Vector3(-0.28, 0, 0).rotated(Vector3.UP, yaw2)))
		"pine":   # the Haunted Woods' fake pines (they blind the drones, NC2045 p.308): a dark trunk,
			# three tiers of near-black needles, now and then a sensor jammer's tell-tale light
			var tall := 0.85 + (h0 % 5) * 0.08
			var needles := wb.mat("plant", f, false, {"color": Color("24402a"), "color2": Color("1a3424")})
			wb.put("cyl", wb.mat("wood", f, false, {"color": Color("3a2a20")}), Transform3D(Basis.from_scale(Vector3(0.14, 0.9 * tall, 0.14)), p + Vector3(0, 0.45 * tall, 0)))
			for i in 3:
				var r := (1.05 - i * 0.26) * tall
				wb.put("cone", needles, Transform3D(Basis(Vector3.UP, yaw + i).scaled_local(Vector3(r, 0.95 * tall, r)), p + Vector3(0, (0.95 + i * 0.55) * tall, 0)))
			if h0 % 4 == 0:
				wb.box(_lit(wb, Color("b537f2") if h0 % 8 == 0 else Color("39f0a0"), f, 1.6), p + Vector3(0.12, 1.25 * tall, 0.12), Vector3(0.05, 0.05, 0.05))
		_:
			multi(wb, kind, Rect2(p.x - 0.5, p.z - 0.5, 1, 1), f, h0)


# --- Multi-square pieces ------------------------------------------------------------------------

static func multi(wb: WorldBuilder, kind: String, r: Rect2, f: int, h0: int) -> void:
	var y0 := f * FH
	var c := Vector3(r.get_center().x, y0, r.get_center().y)
	var long_x := r.size.x >= r.size.y
	var L := maxf(r.size.x, r.size.y)
	var W := minf(r.size.x, r.size.y)
	var yaw := 0.0 if long_x else PI / 2
	var along := Vector3(1, 0, 0) if long_x else Vector3(0, 0, 1)
	var across := Vector3(0, 0, 1) if long_x else Vector3(1, 0, 0)
	match kind:
		"wheel":
			_wheel(wb, c, along, across, L, W, yaw, f, h0)
		"drop_tower":   # a lattice column with a ring of seats partway up, banded in light
			var H := 8.5
			var steel := _paint(wb, Color("c8ccd8"), f, true)
			wb.put("cyl", _paint(wb, Color("4a4a58"), f), Transform3D(Basis.from_scale(Vector3(W * 0.95, 0.5, W * 0.95)), c + Vector3(0, 0.25, 0)))
			wb.box(steel, c + Vector3(0, H / 2, 0), Vector3(0.55, H, 0.55))
			for i in 4:
				var o := Vector3(0.3 if i % 2 == 0 else -0.3, 0, 0.3 if i < 2 else -0.3)
				wb.box(_lit(wb, _neon(wb, h0 + i), f), c + o + Vector3(0, H / 2 + 0.3, 0), Vector3(0.05, H - 0.6, 0.05))
			var sy := 1.4 + float(h0 % 5) * 1.1
			var seats := _paint(wb, _neon(wb, h0 + 2).darkened(0.25), f, true)
			wb.put("cyl", seats, Transform3D(Basis.from_scale(Vector3(W * 0.95, 0.35, W * 0.95)), c + Vector3(0, sy, 0)))
			wb.put("cyl", _lit(wb, WARM, f, 1.4), Transform3D(Basis.from_scale(Vector3(W * 0.98, 0.05, W * 0.98)), c + Vector3(0, sy - 0.2, 0)))
			wb.box(_paint(wb, Color("2a2a34"), f, true), c + Vector3(0, H + 0.25, 0), Vector3(1.1, 0.5, 1.1))
			wb.box(_lit(wb, _neon(wb, h0 + 1), f), c + Vector3(0, H + 0.25, 0), Vector3(1.14, 0.1, 1.14))
			wb.put("cone", steel, Transform3D(Basis.from_scale(Vector3(0.5, 1.0, 0.5)), c + Vector3(0, H + 1.0, 0)))
			wb.box(_lit(wb, Color("ff2020"), f), c + Vector3(0, H + 1.55, 0), Vector3(0.1, 0.1, 0.1))
			_glow(wb, c, _neon(wb, h0), 1.4, 6.0)
		"carousel":   # a round deck under a striped canopy, horses on gilt poles, a crown of bulbs
			var R := W * 0.47
			var gold := _paint(wb, Color("d8b048"), f)
			var cap := _paint(wb, _neon(wb, h0).darkened(0.2), f, true)
			wb.put("cyl", wb.mat("wood", f, false, {"color": Color("5a2626"), "color2": Color("3a1818")}), Transform3D(Basis.from_scale(Vector3(R * 2, 0.28, R * 2)), c + Vector3(0, 0.14, 0)))
			wb.put("cyl", _lit(wb, WARM, f, 1.2), Transform3D(Basis.from_scale(Vector3(R * 2.02, 0.05, R * 2.02)), c + Vector3(0, 0.26, 0)))
			wb.put("cyl", _paint(wb, Color("e8dcc0"), f), Transform3D(Basis.from_scale(Vector3(0.8, 2.0, 0.8)), c + Vector3(0, 1.25, 0)))
			for i in 8:
				var a := TAU * i / 8.0 + 0.2
				var q := c + Vector3(cos(a), 0, sin(a)) * R * 0.72
				wb.put("cyl", gold, Transform3D(Basis.from_scale(Vector3(0.04, 1.95, 0.04)), q + Vector3(0, 1.25, 0)))
				var hy := 0.75 + 0.18 * sin(a * 3.0 + h0)
				wb.box(_paint(wb, Color("f0ece0") if i % 2 == 0 else Color("3a2a24"), f), q + Vector3(0, hy, 0), Vector3(0.48, 0.2, 0.14), -a)
				wb.box(_paint(wb, Color("f0ece0") if i % 2 == 0 else Color("3a2a24"), f), q + Vector3(0, hy + 0.15, 0) + Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)) * 0.2, Vector3(0.1, 0.22, 0.12), -a)
			wb.put("cyl", _paint(wb, Color("f0e4c8"), f, true), Transform3D(Basis.from_scale(Vector3(R * 2.05, 0.3, R * 2.05)), c + Vector3(0, 2.3, 0)))
			wb.put("cone", cap, Transform3D(Basis.from_scale(Vector3(R * 2.1, 1.0, R * 2.1)), c + Vector3(0, 2.95, 0)))
			for i in 8:   # the canopy's stripes: a lighter rib down each panel
				var a2 := TAU * (i + 0.5) / 8.0
				_beam(wb, _paint(wb, Color("f0e4c8"), f, true), c + Vector3(0, 3.42, 0), c + Vector3(cos(a2), 0, sin(a2)) * R * 1.03 + Vector3(0, 2.46, 0), 0.08)
			for i in 20:
				var a3 := TAU * i / 20.0
				wb.box(_lit(wb, WARM if i % 2 == 0 else _neon(wb, h0 + 1), f), c + Vector3(cos(a3), 0, sin(a3)) * R * 1.04 + Vector3(0, 2.3, 0), Vector3(0.09, 0.09, 0.09))
			wb.put("sphere", gold, Transform3D(Basis.from_scale(Vector3(0.22, 0.22, 0.22)), c + Vector3(0, 3.5, 0)))
			_glow(wb, c, WARM, 1.2, 6.5)
		"spinner":   # teacups: three cups on a turning platform under a lit hub
			var R2 := W * 0.46
			wb.put("cyl", _paint(wb, Color("3a3448"), f), Transform3D(Basis.from_scale(Vector3(R2 * 2, 0.2, R2 * 2)), c + Vector3(0, 0.1, 0)))
			wb.put("cyl", _lit(wb, _neon(wb, h0 + 3), f, 1.3), Transform3D(Basis.from_scale(Vector3(R2 * 2.02, 0.04, R2 * 2.02)), c + Vector3(0, 0.2, 0)))
			for i in 3:
				var a := TAU * i / 3.0 + h0
				var q := c + Vector3(cos(a), 0, sin(a)) * R2 * 0.55
				var col := _neon(wb, h0 + i)
				wb.put("cyl", wb.mat("steel", f, false, {"color": col, "glow": 0.25, "emit": col}), Transform3D(Basis.from_scale(Vector3(0.8, 0.42, 0.8)), q + Vector3(0, 0.42, 0)))
				wb.put("cyl", wb.mat("dark", f, false), Transform3D(Basis.from_scale(Vector3(0.62, 0.05, 0.62)), q + Vector3(0, 0.64, 0)))
			wb.put("cyl", _paint(wb, Color("e8e4dc"), f), Transform3D(Basis.from_scale(Vector3(0.35, 1.5, 0.35)), c + Vector3(0, 0.95, 0)))
			wb.put("cone", _paint(wb, _neon(wb, h0 + 4).darkened(0.3), f, true), Transform3D(Basis.from_scale(Vector3(1.6, 0.5, 1.6)), c + Vector3(0, 1.85, 0)))
			_glow(wb, c, _neon(wb, h0 + 3), 1.2, 5.0)
		"swings":   # a wave swinger: a lit column, a crown, seats flung out on chains
			var steel2 := _paint(wb, Color("d8d4e0"), f, true)
			var Hs := 3.4
			wb.put("cyl", _paint(wb, Color("4a4458"), f), Transform3D(Basis.from_scale(Vector3(W * 0.95, 0.3, W * 0.95)), c + Vector3(0, 0.15, 0)))
			wb.put("cyl", steel2, Transform3D(Basis.from_scale(Vector3(0.4, Hs, 0.4)), c + Vector3(0, Hs / 2, 0)))
			var crown := c + Vector3(0, Hs + 0.1, 0)
			wb.put("cone", _paint(wb, _neon(wb, h0).darkened(0.25), f, true), Transform3D(Basis.from_scale(Vector3(3.0, 0.7, 3.0)), crown + Vector3(0, 0.35, 0)))
			wb.put("cyl", _paint(wb, Color("f0e4c8"), f, true), Transform3D(Basis.from_scale(Vector3(3.0, 0.22, 3.0)), crown))
			for i in 12:
				var a := TAU * i / 12.0 + h0
				var rim := crown + Vector3(cos(a), 0, sin(a)) * 1.45
				wb.box(_lit(wb, WARM if i % 2 == 0 else _neon(wb, h0 + 1), f), rim, Vector3(0.09, 0.09, 0.09))
				var seat := c + Vector3(cos(a), 0, sin(a)) * 2.15 + Vector3(0, 1.45, 0)
				_beam(wb, _paint(wb, Color("9a9aa8"), f, true), rim, seat + Vector3(0, 0.15, 0), 0.025)
				wb.box(_paint(wb, _neon(wb, h0 + i).darkened(0.1), f, true), seat, Vector3(0.24, 0.12, 0.24), -a)
			_glow(wb, c, _neon(wb, h0), 1.3, 6.0)
		"fountain":   # the hub's fountain: a stone basin, glowing water, a tiered bowl, jets
			var R3 := W * 0.46
			var stone := wb.mat("stone", f, false, {"color": Color("b0a898"), "color2": Color("8a8274")})
			wb.put("cyl", stone, Transform3D(Basis.from_scale(Vector3(R3 * 2, 0.45, R3 * 2)), c + Vector3(0, 0.22, 0)))
			wb.put("cyl", wb.mat("dark", f, false, {"color": Color("0a3a4a"), "glow": 1.1, "emit": Color("2ab8e8")}), Transform3D(Basis.from_scale(Vector3(R3 * 1.85, 0.04, R3 * 1.85)), c + Vector3(0, 0.44, 0)))
			wb.put("cyl", stone, Transform3D(Basis.from_scale(Vector3(0.6, 1.2, 0.6)), c + Vector3(0, 1.0, 0)))
			wb.put("cyl", stone, Transform3D(Basis.from_scale(Vector3(1.4, 0.18, 1.4)), c + Vector3(0, 1.6, 0)))
			wb.put("sphere", _paint(wb, Color("c8a050"), f), Transform3D(Basis.from_scale(Vector3(0.35, 0.6, 0.35)), c + Vector3(0, 2.0, 0)))
			for i in 6:
				var a := TAU * i / 6.0
				_beam(wb, _lit(wb, Color("aaf6ff"), f, 1.2), c + Vector3(cos(a), 0, sin(a)) * R3 * 0.85 + Vector3(0, 0.45, 0), c + Vector3(cos(a), 0, sin(a)) * R3 * 0.45 + Vector3(0, 1.3, 0), 0.04)
			_glow(wb, c, Color("3ad8ff"), 1.4, 6.0)
		"game_booth":   # a midway game: counter, striped awning, prizes, a lit sign on top
			_booth(wb, c, along, across, L, W, yaw, f, h0)
		_:
			wb.box(wb.mat("concrete_prop", f, false), c + Vector3(0, 0.3, 0), Vector3(r.size.x * 0.8, 0.6, r.size.y * 0.8))


## The big wheel (Deno's Wonder Wheel, Santa Monica's Pacific Wheel): A-frame legs over its
## boarding platform, two lit rims on spokes, gondolas hanging from the rim.
static func _wheel(wb: WorldBuilder, c: Vector3, along: Vector3, across: Vector3, L: float, W: float, yaw: float, f: int, h0: int) -> void:
	var R := L * 0.62
	var hub := c + Vector3(0, R + 0.75, 0)
	var steel := _paint(wb, Color("e4e6ee"), f, true)
	wb.box(_paint(wb, Color("4a4458"), f), c + Vector3(0, 0.18, 0), Vector3(L * 0.92, 0.36, W * 0.85), yaw)
	for s3: float in [-1.0, 1.0]:   # lit edges along the platform
		wb.box(_lit(wb, WARM, f, 1.2), c + across * s3 * W * 0.43 + Vector3(0, 0.3, 0), Vector3(L * 0.93, 0.05, 0.05), yaw)
	for s: float in [-1.0, 1.0]:
		var side := across * s * W * 0.36
		for e: float in [-1.0, 1.0]:
			_beam(wb, steel, c + along * e * L * 0.42 + side + Vector3(0, 0.3, 0), hub + across * s * 0.32, 0.16)
		_beam(wb, steel, c + along * -L * 0.25 + side + Vector3(0, R * 0.5, 0), c + along * L * 0.25 + side + Vector3(0, R * 0.5, 0), 0.08)
	_beam(wb, _paint(wb, Color("8a8a98"), f, true), hub - across * 0.42, hub + across * 0.42, 0.3)
	var ring := Basis(along, PI / 2)   # the torus's axis (y) turned to point across
	var c1 := _neon(wb, h0)
	var c2 := _neon(wb, h0 + 1)
	for s2: float in [-1.0, 1.0]:
		wb.put("torus", _lit(wb, c1 if s2 < 0 else c2, f, 1.5), Transform3D(ring.scaled_local(Vector3(R, R, R)), hub + across * s2 * 0.24))
		wb.put("torus", _paint(wb, Color("d8dae4"), f, true), Transform3D(ring.scaled_local(Vector3(R * 0.55, R * 0.55, R * 0.55)), hub + across * s2 * 0.24))
	var n := 16
	for i in n:
		var a := TAU * i / n + h0 * 0.1
		var dir := along * cos(a) + Vector3.UP * sin(a)
		_beam(wb, _lit(wb, WARM if i % 2 == 0 else c1, f, 1.2), hub + dir * 0.3, hub + dir * R * 0.98, 0.035)
		if i % 2 == 0:   # a gondola hanging below every other rim point
			var g := hub + dir * R
			var gc := _neon(wb, h0 + i / 2)
			wb.box(_paint(wb, gc.darkened(0.2), f, true), g - Vector3(0, 0.38, 0), Vector3(0.42, 0.36, 0.5), yaw)
			wb.box(_paint(wb, Color("e8e8f0"), f, true), g - Vector3(0, 0.17, 0), Vector3(0.46, 0.05, 0.54), yaw)
			wb.box(_paint(wb, Color("8a8a98"), f, true), g - Vector3(0, 0.08, 0), Vector3(0.04, 0.18, 0.04))
	wb.box(_lit(wb, Color("ff2020"), f), hub + Vector3(0, R + 0.1, 0), Vector3(0.12, 0.12, 0.12))
	_glow(wb, c + along * L * 0.3, c1, 1.6, 7.0)
	_glow(wb, c - along * L * 0.3, c2, 1.6, 7.0)


static func _booth(wb: WorldBuilder, c: Vector3, along: Vector3, across: Vector3, L: float, W: float, yaw: float, f: int, h0: int) -> void:
	var front := _front(wb, c, across)
	var col := _neon(wb, h0)
	var wood := wb.mat("wood", f, false, {"color": Color("6a4430")})
	wb.box(wood, c + front * 0.18 + Vector3(0, 0.4, 0), Vector3(L * 0.9, 0.8, 0.22), yaw)
	wb.box(_paint(wb, Color("f0e8d8"), f), c + front * 0.18 + Vector3(0, 0.82, 0), Vector3(L * 0.92, 0.05, 0.3), yaw)
	wb.box(wood, c - front * 0.38 + Vector3(0, 0.95, 0), Vector3(L * 0.9, 1.9, 0.1), yaw)
	for e: float in [-1.0, 1.0]:
		wb.box(wood, c + along * e * L * 0.44 + Vector3(0, 0.95, 0), Vector3(0.08, 1.9, W * 0.85), yaw)
	for i in 5:   # prizes on the back wall
		var px := (i - 2) * L * 0.17
		wb.put("sphere", _paint(wb, _neon(wb, h0 + i + 1).lightened(0.2), f), Transform3D(Basis.from_scale(Vector3(0.22, 0.24, 0.18)), c - front * 0.28 + along * px + Vector3(0, 1.25 + (i % 2) * 0.3, 0)))
	var stripes := 6
	for i in stripes:   # the awning, striped, sloping out over the counter
		var ax := ((i + 0.5) / stripes - 0.5) * L * 0.96
		var sc := Color("f4ece0") if i % 2 == 0 else col.darkened(0.15)
		wb.put("box", _paint(wb, sc, f, true), _slab(c + along * ax - front * 0.38 + Vector3(0, 1.95, 0), c + along * ax + front * 0.6 + Vector3(0, 1.62, 0), along, L * 0.96 / stripes, 0.04))
	wb.box(wb.mat("dark", f, false), c - front * 0.38 + Vector3(0, 2.3, 0), Vector3(L * 0.7, 0.42, 0.08), yaw)
	wb.box(_lit(wb, col, f, 1.6), c - front * 0.34 + Vector3(0, 2.3, 0), Vector3(L * 0.62, 0.3, 0.04), yaw)
	for i in 4:   # bulbs along the awning's edge
		wb.box(_lit(wb, WARM, f, 1.5), c + along * ((i + 0.5) / 4.0 - 0.5) * L * 0.9 + front * 0.62 + Vector3(0, 1.58, 0), Vector3(0.07, 0.07, 0.07))
	_glow(wb, c + front * 0.8, col, 1.2, 4.5)


## A thin slab from a to b (its length), `w` wide along `side`, `t` thick.
static func _slab(a: Vector3, b: Vector3, side: Vector3, w: float, t: float) -> Transform3D:
	var d := b - a
	var len := d.length()
	var z := d / len
	var x := side.normalized()
	var y := z.cross(x).normalized()
	x = y.cross(z)
	return Transform3D(Basis(x, y, z).scaled_local(Vector3(w, t, len)), (a + b) / 2.0)


## Which way a booth on a walk's edge faces: toward the open side (more open squares that way).
static func _front(wb: WorldBuilder, c: Vector3, across: Vector3) -> Vector3:
	var m := wb.m
	var score := func(dir: Vector3) -> int:
		var n := 0
		for k in range(1, 4):
			var x := int(floor(c.x + dir.x * (k + 0.2)))
			var y := int(floor(c.z + dir.z * (k + 0.2)))
			if m.inb(x, y) and m.t(0, x, y) == TacMap.T.OUTSIDE and m.label(0, x, y) < 0:
				n += 1
		return n
	return across if score.call(across) >= score.call(-across) else -across


# --- Decor --------------------------------------------------------------------------------------

## Park decor: queue rails (piped to their neighbours), string-light poles (the string goes to `to`),
## the coaster's track and supports (`rect`: the loop) and the pavilion's canopy (`rect`).
static func decor(wb: WorldBuilder, d: Dictionary, c: Vector3, f: int, rails: Dictionary) -> void:
	match String(d.kind):
		"rail":
			var steel := _paint(wb, Color("c8ccd4"), f)
			wb.put("cyl", steel, Transform3D(Basis.from_scale(Vector3(0.05, 0.5, 0.05)), c + Vector3(0, 0.25, 0)))
			for n in MapGen.DIRS:
				if rails.get(Vector2i(d.pos) + n, "") == "rail":
					var dir := Vector3(n.x, 0, n.y)
					for hgt: float in [0.28, 0.48]:
						_beam(wb, steel, c + Vector3(0, hgt, 0), c + dir * 0.5 + Vector3(0, hgt, 0), 0.035)
		"string_pole":
			var top := c + Vector3(0, 2.45, 0)
			wb.put("cyl", _paint(wb, Color("2a2830"), f), Transform3D(Basis.from_scale(Vector3(0.06, 2.5, 0.06)), c + Vector3(0, 1.25, 0)))
			wb.box(_lit(wb, WARM, f, 1.4), top + Vector3(0, 0.05, 0), Vector3(0.12, 0.08, 0.12))
			if d.has("to"):
				var to: Vector2i = d.to
				var b := Vector3(to.x + 0.5, c.y + 2.45, to.y + 0.5)
				var span := top.distance_to(b)
				var bulbs := maxi(4, int(span * 2.2))
				for i in range(1, bulbs + 1):   # bulbs only: a wire this thin is lost at pixel scale, its shadow was not
					var t := float(i) / float(bulbs + 1)
					var q := top.lerp(b, t) - Vector3(0, 0.55 * 4.0 * t * (1.0 - t), 0)
					var col := WARM if i % 3 != 0 else _neon(wb, i + int(c.x))
					wb.box(_lit(wb, col, f, 1.6), q - Vector3(0, 0.06, 0), Vector3(0.08, 0.1, 0.08))
				_glow(wb, top.lerp(b, 0.5), WARM, 1.2, 6.0)
		"coaster":
			_coaster(wb, d, f)
		"pavilion":
			_pavilion(wb, d.rect, f, hash(Vector2i(d.pos)))


## A coaster's track round its loop, banked hills and drops, on white lattice supports; a train.
static func _coaster(wb: WorldBuilder, d: Dictionary, f: int) -> void:
	var m := wb.m
	var r: Rect2i = d.rect
	var per := ParkGen.perimeter(r)
	var n := per.size()
	var h0 := hash(Vector2i(d.pos))
	var hgt := func(i: int) -> float:
		var s := float(i) / n
		var h := 1.3
		for hill in [[0.1, 3.8, 0.07], [0.38, 2.4, 0.06], [0.62, 1.6, 0.05], [0.82, 1.0, 0.05]]:
			var ds := absf(s - float(hill[0]))
			ds = minf(ds, 1.0 - ds)
			h += float(hill[1]) * exp(-pow(ds / float(hill[2]), 2.0))
		return h
	var pts: Array[Vector3] = []
	for i in n:
		pts.append(Vector3(per[i].x + 0.5, f * FH + hgt.call(i), per[i].y + 0.5))
	var rail := _paint(wb, Color("e8e4ec"), f, true)
	var tie := _paint(wb, Color("6a6a78"), f, true)
	var lit := _lit(wb, _neon(wb, h0), f, 1.5)
	var white := _paint(wb, Color("dcdce4"), f, true)
	for i in n:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % n]
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.UP).normalized() * 0.24
		for s: float in [-1.0, 1.0]:
			_beam(wb, rail, a + side * s, b + side * s, 0.07)
		_beam(wb, lit, a + side * 1.35 - Vector3(0, 0.08, 0), b + side * 1.35 - Vector3(0, 0.08, 0), 0.03)
		wb.box(tie, a - Vector3(0, 0.06, 0), Vector3(0.62, 0.05, 0.14), atan2(dir.x, dir.z))
		var cv := m.cover_at(f, per[i])
		if not cv.is_empty() and String(cv.kind) == "coaster_post":   # a lattice support up to the track
			var top := a - Vector3(0, 0.1, 0)
			var base := Vector3(a.x, f * FH, a.z)
			var o := side.normalized() * 0.2
			for s2: float in [-1.0, 1.0]:
				_beam(wb, white, base + o * s2, top + o * s2, 0.07)
			var hh := top.y - base.y
			var k := 0
			while k * 0.7 < hh - 0.3:
				_beam(wb, white, base + o + Vector3(0, k * 0.7, 0), base - o + Vector3(0, (k + 1) * 0.7, 0), 0.035)
				k += 1
		if i % 7 == 0:
			_glow(wb, Vector3(a.x, 0, a.z), _neon(wb, h0 + i), 0.7, 4.0)
	# the train: four cars on the low run past the station
	var at := int(n * 0.93)
	for k2 in 4:
		var i2 := (at + k2) % n
		var a2: Vector3 = pts[i2]
		var b2: Vector3 = pts[(i2 + 1) % n]
		var dir2 := (b2 - a2).normalized()
		wb.box(_paint(wb, _neon(wb, h0 + 2).darkened(0.1), f, true), a2.lerp(b2, 0.5) + Vector3(0, 0.22, 0), Vector3(0.5, 0.3, 0.8), atan2(dir2.x, dir2.z))


## A bumper-car pavilion: a dark steel floor with a lit edge, an open canopy grid on its posts
## (the cars' poles run up to it), bulbs round the eaves and a sign.
static func _pavilion(wb: WorldBuilder, r: Rect2i, f: int, h0: int) -> void:
	var y := f * FH
	var ctr := Vector3(r.get_center().x, y, r.get_center().y)
	var H := 2.55
	wb.box(wb.mat("floor_metal", f, false), ctr + Vector3(0, 0.02, 0), Vector3(r.size.x - 0.3, 0.03, r.size.y - 0.3))
	var col := _neon(wb, h0)
	var frame := _paint(wb, Color("d8d4e0"), f, true)
	var x0 := r.position.x + 0.5
	var x1 := r.end.x - 0.5
	var z0 := r.position.y + 0.5
	var z1 := r.end.y - 0.5
	for e in [[Vector3(x0, y + H, z0), Vector3(x1, y + H, z0)], [Vector3(x0, y + H, z1), Vector3(x1, y + H, z1)],
			[Vector3(x0, y + H, z0), Vector3(x0, y + H, z1)], [Vector3(x1, y + H, z0), Vector3(x1, y + H, z1)]]:
		_beam(wb, frame, e[0], e[1], 0.16)
		_beam(wb, _lit(wb, col, f, 1.5), e[0] - Vector3(0, 0.12, 0), e[1] - Vector3(0, 0.12, 0), 0.04)
	var gx := x0 + 1.0
	while gx < x1 - 0.5:   # the ceiling grid the cars draw their power from
		_beam(wb, _paint(wb, Color("6a6a78"), f, true), Vector3(gx, y + H + 0.05, z0), Vector3(gx, y + H + 0.05, z1), 0.03)
		gx += 1.0
	wb.box(wb.mat("dark", f, false, {"shell": true}), Vector3(ctr.x, y + H + 0.5, z0), Vector3(minf(4.0, r.size.x - 1.0), 0.6, 0.1))
	wb.box(_lit(wb, _neon(wb, h0 + 1), f, 1.6), Vector3(ctr.x, y + H + 0.5, z0 - 0.06), Vector3(minf(3.6, r.size.x - 1.4), 0.4, 0.04))
	_glow(wb, ctr, col, 1.5, 6.5)


# --- The seafront and the ride gates --------------------------------------------------------------

static func is_park(m: TacMap) -> bool:
	var prof: Variant = RulesDB.gen("districts.json").get(String(m.params.get("profile", "")), {})
	return prof is Dictionary and bool((prof as Dictionary).get("midway", false))


## Once per storey: on a park map, the boardwalk's railing and pilings and an arch with a lit
## sign over every ride gate.
static func dress(wb: WorldBuilder, f: int) -> void:
	var m := wb.m
	if f != 0 or not is_park(m):
		return
	var rail := _paint(wb, Color("e0d8c8"), f)
	var pile := wb.mat("wood", f, false, {"color": Color("3a2a1e")})
	for y in m.h:
		for x in m.w:
			if m.t(0, x, y) != TacMap.T.OUTSIDE or int(m.ground[y * m.w + x]) != TacMap.G.DOCK:
				continue
			for d in MapGen.DIRS:
				if m.t(0, x + d.x, y + d.y) != TacMap.T.WATER:
					continue
				var e := Vector3(x + 0.5 + d.x * 0.45, 0, y + 0.5 + d.y * 0.45)
				var along := Vector3(absf(d.y), 0, absf(d.x))
				wb.box(rail, e + Vector3(0, 0.55, 0), Vector3(0.06, 0.06, 0.06) + along * 1.0)
				wb.box(rail, e + Vector3(0, 0.3, 0), Vector3(0.04, 0.04, 0.04) + along * 1.0)
				wb.box(rail, e + Vector3(0, 0.28, 0), Vector3(0.06, 0.56, 0.06))
				if (x + y) % 2 == 0:   # pilings down into the sea
					wb.put("cyl", pile, Transform3D(Basis.from_scale(Vector3(0.22, 1.2, 0.22)), e + Vector3(d.x, 0, d.y) * 0.2 + Vector3(0, -0.5, 0)))
				if (x * 7 + y * 3) % 9 == 0:   # a lamp on the rail every few squares
					wb.put("cyl", _paint(wb, Color("2a2830"), f), Transform3D(Basis.from_scale(Vector3(0.05, 1.5, 0.05)), e + Vector3(0, 0.75, 0)))
					wb.put("sphere", _lit(wb, WARM, f, 1.5), Transform3D(Basis.from_scale(Vector3(0.2, 0.2, 0.2)), e + Vector3(0, 1.55, 0)))
					_glow(wb, e, WARM, 0.9, 4.5)
	for dr in m.doors:
		if not dr.get("gate", false) or int(dr.get("b", -1)) < 0 or String(m.rooms[int(dr.b)].kind) != "ride":
			continue
		var g: Vector2i = dr.pos
		var out := Vector2i.ZERO
		for d2 in MapGen.DIRS:
			if m.t(0, g.x + d2.x, g.y + d2.y) == TacMap.T.OUTSIDE and m.label(0, g.x + d2.x, g.y + d2.y) != int(dr.b):
				out = d2
		var side := Vector3(absf(out.y), 0, absf(out.x)) if out != Vector2i.ZERO else Vector3(1, 0, 0)
		var gc := Vector3(g.x + 0.5, 0, g.y + 0.5)
		var col := _neon(wb, int(dr.b) * 3 + 1)
		for s: float in [-1.0, 1.0]:
			wb.box(_paint(wb, Color("e8e0d0"), f), gc + side * s * 0.62 + Vector3(0, 1.1, 0), Vector3(0.12, 2.2, 0.12))
		wb.box(wb.mat("dark", f, false, {"shell": true}), gc + Vector3(0, 2.3, 0), side * 1.5 + Vector3(0.1, 0.5, 0.1) - side * 0.1)
		wb.box(_lit(wb, col, f, 1.6), gc + Vector3(0, 2.3, 0) + Vector3(out.x, 0, out.y) * 0.07, side * 1.3 + Vector3(0.04, 0.32, 0.04) - side * 0.04)
		_glow(wb, gc + Vector3(out.x, 0, out.y), col, 1.0, 4.0)
