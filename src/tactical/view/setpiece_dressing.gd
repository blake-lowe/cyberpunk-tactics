class_name SetPieceDressing
extends RefCounted
## What makes a famous place recognisable from above (data/gen/setpieces.json `look` on a set
## piece's part, and on the set piece itself for its grounds). WorldBuilder asks look() for a
## part's wall, trim and roof colours, draws the set pieces' own props here (SetPieceGen.PIECES:
## a school cupola, a flagpole, a crowning spire, a warship's turret, mast and funnel, a
## columbarium, a parked AV) and calls dress() once per storey for dressing that is view only:
## graffiti, lit terrace edges, a crown of fins round the top roof, crenellations, landing-pad
## marks, a ship's waterline, a lit name sign over the door, standing water in drowned rooms.
##
## Part look keys: wall / roof {color, color2, pattern, scale} (pattern 11 is brick), trim (hex:
## cornice and skirting), roof_mark "none" (no painted helipad), graffiti (share of ground-floor
## facade squares tagged, in the faction's colours), crown (hex), terrace_lights (hex), crenels,
## pads, waterline (hex), sign (hex), flooded [room kinds]. Set-piece look: wall_crenels (the
## perimeter wall's top), graffiti_walls (share of perimeter wall squares tagged), court_lines (hex:
## a basketball court painted on the grounds' asphalt), burn_barrels (fires in the outdoor drums).

const FH := WorldBuilder.FH
const EXT_T := WorldBuilder.EXT_T


static func has_piece(kind: String) -> bool:
	return SetPieceGen.PIECES.has(kind)


## A part's look ({} for anything that isn't a set piece's building).
static func look(m: TacMap, sid: int) -> Dictionary:
	if sid < 0 or sid >= m.structures.size() or String(m.structures[sid].get("setpiece", "")) == "":
		return {}
	return SetPieces.structure_def(m.structures[sid]).get("look", {})


## A look entry ({color, color2, pattern, scale, glow, emit}) as WorldBuilder.mat overrides.
static func mat_over(d: Variant) -> Dictionary:
	var o := {}
	if d is String:
		return {"color": Color(d), "color2": Color(d).darkened(0.4)}
	if not d is Dictionary:
		return o
	for k in d:
		match String(k):
			"color", "color2", "emit": o[k] = Color(String(d[k]))
			"pattern": o[k] = int(d[k])
			"scale", "glow": o[k] = float(d[k])
	if o.has("color") and not o.has("color2"):
		o["color2"] = (o.color as Color).darkened(0.42)
	return o


## The faction colours of the map's set piece: [jacket, accent] (graffiti, flags, AV livery).
static func faction_colors(m: TacMap) -> Array:
	var sp := SetPieces.get_def(String(m.params.get("setpiece", "")))
	var lk: Dictionary = World.faction(String(sp.get("faction", ""))).get("look", {})
	return [Color(String(lk.get("jacket", "3a3a3a"))), Color(String(lk.get("accent", "ff3030")))]


# --- Props -----------------------------------------------------------------------------------

## One-square pieces (flagpole, mast).
static func piece(wb: WorldBuilder, kind: String, p: Vector3, yaw: float, f: int, h0: int) -> void:
	var m := wb.m
	match kind:
		"flagpole":   # white pole, gilt ball, the gang's colours flying
			var fc: Array = faction_colors(m)
			wb.put("cyl", wb.mat("steel", f, false, {"color": Color("d8d8d0")}), Transform3D(Basis.from_scale(Vector3(0.07, 3.6, 0.07)), p + Vector3(0, 1.8, 0)))
			wb.put("sphere", wb.mat("steel", f, false, {"color": Color("c8a040")}), Transform3D(Basis.from_scale(Vector3(0.14, 0.14, 0.14)), p + Vector3(0, 3.65, 0)))
			wb.box(wb.mat("fabric", f, false, {"color": fc[1], "glow": 0.35, "emit": fc[1]}), p + Vector3(0.5, 3.25, 0), Vector3(0.9, 0.5, 0.03), 0.15)
			wb.box(wb.mat("fabric", f, false, {"color": fc[0].lightened(0.2)}), p + Vector3(0.5, 3.25, 0.02), Vector3(0.3, 0.5, 0.01), 0.15)
			wb.box(wb.mat("concrete_prop", f, false), p + Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.5))
		"mast":   # a warship's lattice mast: yardarm, radar bar, a red light at the truck
			var g := wb.mat("steel", f, false, {"color": Color("6a7078")})
			wb.put("cyl", g, Transform3D(Basis.from_scale(Vector3(0.12, 3.4, 0.12)), p + Vector3(0, 1.7, 0)))
			for s in [-1, 1]:
				wb.put("cyl", g, Transform3D(Basis(Vector3.FORWARD, s * 0.18).scaled_local(Vector3(0.06, 2.6, 0.06)), p + Vector3(s * 0.22, 1.25, 0)))
			wb.box(g, p + Vector3(0, 2.6, 0), Vector3(1.6, 0.06, 0.06), yaw)
			wb.box(wb.mat("steel", f, false, {"color": Color("2a2e34")}), p + Vector3(0, 3.1, 0), Vector3(1.0, 0.22, 0.08), yaw + 0.6)
			wb.put("sphere", wb.mat("steel", f, false, {"color": Color("d0d4d8")}), Transform3D(Basis.from_scale(Vector3(0.36, 0.36, 0.36)), p + Vector3(0, 3.5, 0)))
			wb.box(wb.mat("dark", f, false, {"glow": 2.5, "emit": Color("ff2020")}), p + Vector3(0, 3.75, 0), Vector3(0.09, 0.09, 0.09))
		"camera_mast":   # a broadcast camera on a lattice mast: the lens trained down the street, a red tally light, a lamp
			var g := wb.mat("steel", f, false, {"color": Color("3a3e44")})
			wb.box(wb.mat("concrete_prop", f, false), p + Vector3(0, 0.1, 0), Vector3(0.55, 0.2, 0.55))
			wb.put("cyl", g, Transform3D(Basis.from_scale(Vector3(0.1, 4.2, 0.1)), p + Vector3(0, 2.1, 0)))
			for s in [-1, 1]:
				wb.put("cyl", g, Transform3D(Basis(Vector3.FORWARD, s * 0.12).scaled_local(Vector3(0.04, 3.4, 0.04)), p + Vector3(s * 0.16, 1.7, 0)))
			var dir := Vector3(0, 0, 1).rotated(Vector3.UP, yaw)
			wb.box(wb.mat("steel", f, false, {"color": Color("16181c")}), p + Vector3(0, 4.25, 0) + dir * 0.2, Vector3(0.28, 0.26, 0.6), yaw)
			wb.box(wb.mat("glass", f, false, {"color": Color("0a1420"), "alpha": 0.95, "glow": 0.6, "emit": Color("4aa0ff")}), p + Vector3(0, 4.25, 0) + dir * 0.52, Vector3(0.18, 0.18, 0.04), yaw)
			wb.box(wb.mat("dark", f, false, {"glow": 3.0, "emit": Color("ff1a1a")}), p + Vector3(0, 4.45, 0), Vector3(0.08, 0.08, 0.08))
			wb.box(wb.mat("dark", f, false, {"glow": 2.2, "emit": Color("fff0d0")}), p + Vector3(0, 3.85, 0) - dir * 0.15, Vector3(0.3, 0.16, 0.12), yaw)
			wb.emitters.append({"cell": Vector3i(int(p.x), int(p.z), f), "color": Color("fff0d0"), "energy": 1.1, "range": 5.0, "out": Vector2i.ZERO})
		_:
			multi(wb, kind, Rect2(p.x - 0.5, p.z - 0.5, 1, 1), f, h0)


## Multi-square pieces, drawn once over their bounds `r`.
static func multi(wb: WorldBuilder, kind: String, r: Rect2, f: int, h0: int) -> void:
	var m := wb.m
	var y0 := f * FH
	var c := Vector3(r.get_center().x, y0, r.get_center().y)
	var sz := minf(r.size.x, r.size.y)
	match kind:
		"cupola":   # an old school's bell cupola: brick base, white lantern, green dome, a clock
			var brick := wb.mat("wall_plaster", f, false, {"color": Color("7a3424"), "color2": Color("4a2018"), "pattern": 11})
			var white := wb.mat("steel", f, false, {"color": Color("d8d4c8")})
			wb.box(brick, c + Vector3(0, 0.45, 0), Vector3(sz * 0.8, 0.9, sz * 0.8))
			wb.box(white, c + Vector3(0, 0.93, 0), Vector3(sz * 0.88, 0.08, sz * 0.88))
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				wb.box(white, c + Vector3(q.x * sz * 0.3, 1.27, q.y * sz * 0.3), Vector3(0.09, 0.6, 0.09))
			wb.box(wb.mat("dark", f, false, {"glow": 0.9, "emit": Color("ffc070")}), c + Vector3(0, 1.25, 0), Vector3(sz * 0.4, 0.5, sz * 0.4))
			wb.box(white, c + Vector3(0, 1.6, 0), Vector3(sz * 0.72, 0.07, sz * 0.72))
			wb.put("sphere", wb.mat("steel", f, false, {"color": Color("4a7a66")}), Transform3D(Basis.from_scale(Vector3(sz * 0.62, 0.7, sz * 0.62)), c + Vector3(0, 1.66, 0)))
			wb.put("cyl", wb.mat("steel", f, false, {"color": Color("c8a040")}), Transform3D(Basis.from_scale(Vector3(0.05, 0.6, 0.05)), c + Vector3(0, 2.25, 0)))
			for dz in [-1, 1]:   # clock faces front and back
				wb.put("cyl", wb.mat("dark", f, false, {"color": Color("f0e8d0"), "glow": 0.6, "emit": Color("f0e0b0")}), Transform3D(Basis(Vector3.RIGHT, PI / 2).scaled_local(Vector3(0.5, 0.02, 0.5)), c + Vector3(0, 0.52, dz * sz * 0.41)))
		"spire":   # a tower's crown: stepped tiers banded in light, a mast with a beacon
			var dark := wb.mat("steel", f, false, {"color": Color("1c2228")})
			var gold := Color(String(look(m, _sid_at(wb, c)).get("crown", "ffc040")))
			var band := wb.mat("dark", f, false, {"glow": 2.2, "emit": gold})
			var h := 0.0
			for t in 3:
				var w := sz * (0.9 - t * 0.22)
				var th := 0.55 + t * 0.15
				wb.box(dark, c + Vector3(0, h + th / 2, 0), Vector3(w, th, w))
				wb.box(band, c + Vector3(0, h + th - 0.04, 0), Vector3(w + 0.04, 0.06, w + 0.04))
				h += th
			wb.put("cyl", dark, Transform3D(Basis.from_scale(Vector3(0.1, 2.8, 0.1)), c + Vector3(0, h + 1.4, 0)))
			wb.box(wb.mat("dark", f, false, {"glow": 3.0, "emit": Color("ff2020")}), c + Vector3(0, h + 2.85, 0), Vector3(0.12, 0.12, 0.12))
			wb.emitters.append({"cell": Vector3i(int(c.x), int(c.z), f), "color": gold, "energy": 1.2, "range": 5.0, "out": Vector2i.ZERO})
		"turret":   # a warship's gun turret: armoured ring, angled house, the barrel trained fore or aft
			var grey := wb.mat("steel", f, false, {"color": Color("5c636b")})
			var sid := _sid_at(wb, c)
			var dir := 1.0
			if sid >= 0:
				var hr: Rect2i = m.structures[sid].rect
				dir = 1.0 if c.x > hr.get_center().x else -1.0
			wb.put("cyl", wb.mat("steel", f, false, {"color": Color("3a4048")}), Transform3D(Basis.from_scale(Vector3(sz * 0.85, 0.25, sz * 0.85)), c + Vector3(0, 0.12, 0)))
			wb.box(grey, c + Vector3(-dir * 0.1, 0.5, 0), Vector3(sz * 0.7, 0.5, sz * 0.55))
			wb.box(grey, c + Vector3(dir * sz * 0.3, 0.45, 0), Vector3(0.3, 0.38, sz * 0.5))
			wb.put("cyl", wb.mat("steel", f, false, {"color": Color("2a2e34")}), Transform3D(Basis(Vector3.FORWARD, PI / 2 - dir * 0.06).scaled_local(Vector3(0.16, 2.4, 0.16)), c + Vector3(dir * (sz * 0.35 + 1.1), 0.55, 0)))
		"funnel":   # an oval, raked stack with a black cap
			var grey2 := wb.mat("steel", f, false, {"color": Color("5c636b")})
			wb.put("cyl", grey2, Transform3D(Basis(Vector3.FORWARD, -0.12).scaled_local(Vector3(sz * 0.7, 1.7, sz * 0.45)), c + Vector3(-0.1, 0.85, 0)))
			wb.put("cyl", wb.mat("dark", f, false), Transform3D(Basis(Vector3.FORWARD, -0.12).scaled_local(Vector3(sz * 0.72, 0.22, sz * 0.47)), c + Vector3(-0.2, 1.68, 0)))
			wb.put("cyl", wb.mat("dark", f, false, {"glow": 0.5, "emit": Color("ff8040")}), Transform3D(Basis.from_scale(Vector3(sz * 0.5, 0.02, sz * 0.3)), c + Vector3(-0.22, 1.8, 0)))
		"columbarium":   # the base memorial: a pale stone plinth, a monolith of niches, a flame
			var stone := wb.mat("stone", f, false, {"color": Color("a8a498"), "color2": Color("7a766c")})
			wb.box(stone, c + Vector3(0, 0.1, 0), Vector3(sz * 0.95, 0.2, sz * 0.95))
			wb.box(stone, c + Vector3(0, 0.3, 0), Vector3(sz * 0.7, 0.2, sz * 0.7))
			wb.box(stone, c + Vector3(0, 0.95, 0), Vector3(0.9, 1.3, 0.9))
			for i in 4:
				var a := i * PI / 2
				var face := Vector3(sin(a), 0, cos(a)) * 0.46
				for row in 3:
					wb.box(wb.mat("dark", f, false, {"color": Color("2a2824")}), c + face + Vector3(0, 0.6 + row * 0.3, 0), Vector3(0.6, 0.16, 0.6) * Vector3(absf(cos(a)) * 0.9 + 0.05, 1, absf(sin(a)) * 0.9 + 0.05))
			wb.put("cyl", wb.mat("dark", f, false, {"glow": 3.0, "emit": Color("ff9a30")}), Transform3D(Basis.from_scale(Vector3(0.18, 0.25, 0.18)), c + Vector3(0, 1.75, 0)))
			wb.emitters.append({"cell": Vector3i(int(c.x), int(c.z), f), "color": Color("ff9a30"), "energy": 1.0, "range": 4.0, "out": Vector2i.ZERO})
		"av":   # an aerodyne on its pad, in the owner's livery: hull, canopy, four ducted fans
			var fc: Array = faction_colors(m)
			var body := wb.mat("steel", f, false, {"color": fc[0].lightened(0.1)})
			var long_x := r.size.x >= r.size.y
			var yaw := 0.0 if long_x else PI / 2
			wb.box(body, c + Vector3(0, 0.55, 0), Vector3(sz * 0.75, 0.45, sz * 0.36), yaw)
			wb.box(body, c + Vector3(0, 0.85, 0) + Vector3(-0.2, 0, 0).rotated(Vector3.UP, yaw), Vector3(sz * 0.45, 0.25, sz * 0.3), yaw)
			wb.box(wb.mat("glass", f, false, {"color": Color("0e1820"), "alpha": 0.9}), c + Vector3(0, 0.75, 0) + Vector3(sz * 0.3, 0, 0).rotated(Vector3.UP, yaw), Vector3(0.5, 0.25, sz * 0.3), yaw)
			wb.box(wb.mat("dark", f, false, {"glow": 2.0, "emit": fc[1]}), c + Vector3(0, 0.79, 0), Vector3(sz * 0.76, 0.05, sz * 0.37), yaw)
			for s in [-1, 1]:
				for e in [-1, 1]:
					var o := Vector3(e * sz * 0.32, 0, s * sz * 0.33).rotated(Vector3.UP, yaw)
					wb.put("cyl", wb.mat("steel", f, false, {"color": Color("2a2e34")}), Transform3D(Basis.from_scale(Vector3(0.62, 0.22, 0.62)), c + o + Vector3(0, 0.45, 0)))
					wb.put("cyl", wb.mat("dark", f, false, {"glow": 1.4, "emit": Color("70d8ff")}), Transform3D(Basis.from_scale(Vector3(0.5, 0.02, 0.5)), c + o + Vector3(0, 0.33, 0)))
		"bus":   # a burnt-out yellow school bus dragged across as a barricade
			var long_x := r.size.x >= r.size.y
			var yaw := 0.0 if long_x else PI / 2
			var L := maxf(r.size.x, r.size.y) * 0.95
			var Wd := minf(r.size.x, r.size.y) * 0.85
			var yellow := wb.mat("steel", f, false, {"color": Color("c89a1a").darkened(0.15 + (h0 % 3) * 0.1)})
			wb.box(yellow, c + Vector3(0, 0.55, 0), Vector3(L, 0.7, Wd), yaw)
			wb.box(wb.mat("dark", f, false), c + Vector3(0, 0.62, 0), Vector3(L * 0.82, 0.18, Wd + 0.02), yaw)   # the window band, glass long gone
			wb.box(wb.mat("steel", f, false, {"color": Color("1a1a1a")}), c + Vector3(0, 0.4, 0), Vector3(L + 0.02, 0.05, Wd + 0.02), yaw)   # the black rub rail
			wb.box(wb.mat("steel", f, false, {"color": Color("e8e4d8")}), c + Vector3(0, 0.91, 0), Vector3(L * 0.98, 0.03, Wd * 0.9), yaw)
			wb.box(yellow, c + Vector3(0, 0.35, 0) + Vector3(L * 0.5 + 0.3, 0, 0).rotated(Vector3.UP, yaw), Vector3(0.6, 0.4, Wd * 0.9), yaw)   # the hood
			for e in [-0.33, 0.3]:
				for sd in [-1, 1]:
					wb.put("cyl", wb.mat("dark", f, false), Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(0.36, 0.12, 0.36)), c + Vector3(e * L, 0.17, sd * Wd * 0.45).rotated(Vector3.UP, yaw)))
		"dish":   # a broadcast uplink dish on its mount, tilted at the sky, a red beacon on the feed arm
			var w := wb.mat("steel", f, false, {"color": Color("d8d8d2")})
			wb.box(wb.mat("steel", f, false, {"color": Color("3a3e44")}), c + Vector3(0, 0.25, 0), Vector3(sz * 0.5, 0.5, sz * 0.5))
			var tilt := Basis(Vector3.UP, float(h0 % 4) * PI / 2 + 0.6) * Basis(Vector3.RIGHT, -0.75)
			wb.put("cyl", w, Transform3D(tilt.scaled_local(Vector3(sz * 0.9, 0.08, sz * 0.9)), c + Vector3(0, 1.05, 0)))
			wb.put("cyl", wb.mat("steel", f, false, {"color": Color("8a8e94")}), Transform3D(tilt.scaled_local(Vector3(0.05, 0.9, 0.05)), c + Vector3(0, 1.05, 0) + tilt.y * 0.45))
			wb.box(wb.mat("dark", f, false, {"glow": 3.0, "emit": Color("ff2020")}), c + Vector3(0, 1.05, 0) + tilt.y * 0.92, Vector3(0.1, 0.1, 0.1))
		"fountain":   # a round stone basin on the lawn, lit water, a jet in the middle
			var stone := wb.mat("stone", f, false, {"color": Color("d8d2c4"), "color2": Color("a8a294")})
			wb.put("cyl", stone, Transform3D(Basis.from_scale(Vector3(sz * 0.92, 0.45, sz * 0.92)), c + Vector3(0, 0.22, 0)))
			wb.put("cyl", wb.mat("water", f, false, {"color": Color("2a8ab8"), "glow": 0.9, "emit": Color("3ab8e8")}), Transform3D(Basis.from_scale(Vector3(sz * 0.8, 0.04, sz * 0.8)), c + Vector3(0, 0.46, 0)))
			wb.put("cyl", stone, Transform3D(Basis.from_scale(Vector3(0.4, 0.9, 0.4)), c + Vector3(0, 0.75, 0)))
			wb.put("cyl", stone, Transform3D(Basis.from_scale(Vector3(1.0, 0.1, 1.0)), c + Vector3(0, 1.2, 0)))
			wb.put("cyl", wb.mat("glass", f, false, {"color": Color("c8f0ff"), "alpha": 0.5, "glow": 0.8, "emit": Color("a0e8ff")}), Transform3D(Basis.from_scale(Vector3(0.12, 0.8, 0.12)), c + Vector3(0, 1.6, 0)))
			wb.emitters.append({"cell": Vector3i(int(c.x), int(c.z), f), "color": Color("70d0ff"), "energy": 1.0, "range": 4.0, "out": Vector2i.ZERO})
		_:
			wb.box(wb.mat("concrete_prop", f, false), c + Vector3(0, 0.3, 0), Vector3(r.size.x * 0.8, 0.6, r.size.y * 0.8))


static func _sid_at(wb: WorldBuilder, c: Vector3) -> int:
	var x := clampi(int(c.x), 0, wb.m.w - 1)
	var y := clampi(int(c.z), 0, wb.m.h - 1)
	return wb._sid_grid[y * wb.m.w + x]


# --- Dressing ----------------------------------------------------------------------------------

## Everything view-only a storey's set-piece buildings carry.
static func dress(wb: WorldBuilder, f: int) -> void:
	var m := wb.m
	if not SetPieces.has(String(m.params.get("setpiece", ""))):
		return
	var s := m.street   # street level; storeys below it are dug into the ground (no facade)
	for st in m.structures:
		var lk := look(m, int(st.id))
		if lk.is_empty():
			continue
		if lk.has("graffiti") and f >= s and f <= s + 1:
			_graffiti(wb, f, int(st.id), float(lk.graffiti) * (1.0 if f == s else 0.4))
		if lk.has("terrace_lights"):
			_terrace_lights(wb, f, int(st.id), Color(String(lk.terrace_lights)))
		if lk.has("crown"):
			_crown(wb, f, int(st.id), Color(String(lk.crown)))
		if lk.get("crenels", false):
			_crenels(wb, f, int(st.id))
		if lk.get("pads", false):
			_pads(wb, f, int(st.id))
		wb.y_off = wb.gy   # the street-level pieces below are placed from y 0: lift them to the street
		if lk.has("waterline") and f == s:
			_waterline(wb, int(st.id), Color(String(lk.waterline)))
		if lk.has("sign") and f == s:
			_sign(wb, int(st.id), Color(String(lk.sign)))
		wb.y_off = 0.0
		# the drowned storeys: those below the street (their deep water is real WATER), else the lowest
		if lk.has("flooded") and (f < s if s > 0 else f == 0):
			_flooded(wb, f, int(st.id), lk.flooded)
	var sl: Dictionary = (SetPieces.get_def(String(m.params.setpiece)).get("look", {}) as Dictionary).duplicate()
	sl.merge(SetPieces.variant(m).get("look", {}), true)   # an estate's own (M'bolu's tagged walls)
	if f == s and (sl.get("wall_crenels", false) or sl.has("graffiti_walls")):
		_perimeter(wb, sl)
	wb.y_off = wb.gy
	if f == s:
		_hatches(wb)
	if f == s and sl.get("pool_lights", false):
		_pools(wb)
	if f == s and sl.get("decon_gate", false):
		_decon_gate(wb)
	if f == s and sl.has("court_lines"):
		_court_lines(wb, Color(String(sl.court_lines)))
	wb.y_off = 0.0
	if sl.get("burn_barrels", false):
		_burn_barrels(wb, f)


## Tunnel hatches (entrances of kind tunnel: the Combat Zone's guard tunnels): a steel lid swung
## open on a hazard-striped collar over a dark shaft, a work light.
static func _hatches(wb: WorldBuilder) -> void:
	var m := wb.m
	for e in m.entrances:
		if String(e.kind) != "tunnel":
			continue
		var p := Vector3(e.pos.x + 0.5, 0, e.pos.y + 0.5)
		wb.put("cyl", wb.mat("dark", wb.street, false, {"color": Color("050505")}), Transform3D(Basis.from_scale(Vector3(0.78, 0.02, 0.78)), p + Vector3(0, 0.02, 0)))
		for i in 12:
			var a := TAU * i / 12.0
			wb.box(wb.mat("steel", wb.street, false, {"color": Color("f2c200") if i % 2 == 0 else Color("1a1a1a")}), p + Vector3(cos(a), 0, sin(a)) * 0.46 + Vector3(0, 0.06, 0), Vector3(0.26, 0.1, 0.14), -a + PI / 2)
		wb.put("cyl", wb.mat("steel", wb.street, false, {"color": Color("4a4e54")}), Transform3D(Basis(Vector3.RIGHT, 1.2).scaled_local(Vector3(0.8, 0.05, 0.8)), p + Vector3(0, 0.35, -0.55)))
		wb.box(wb.mat("dark", wb.street, false, {"glow": 2.0, "emit": Color("ffd070")}), p + Vector3(0.45, 0.25, 0.45), Vector3(0.12, 0.12, 0.12))
		wb.emitters.append({"cell": Vector3i(e.pos.x, e.pos.y, wb.street), "color": Color("ffd070"), "energy": 0.8, "range": 3.0, "out": Vector2i.ZERO})


## A garden pool: lit turquoise water over the pool squares (water tiles inside a pool deck), a
## white stone coping round it.
static func _pools(wb: WorldBuilder) -> void:
	var m := wb.m
	var water := wb.mat("water", wb.street, false, {"color": Color("1aa0c8"), "glow": 1.0, "emit": Color("2ac8f0")})
	var coping := wb.mat("stone", wb.street, false, {"color": Color("ece8e0")})
	for r in m.rooms:
		if r.cells == 0 or String(r.kind) != "pool_deck":
			continue
		var b: Rect2i = r.bounds
		var lit := false
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				if m.t(wb.street, x, y) != TacMap.T.WATER:
					continue
				wb.box(water, Vector3(x + 0.5, -0.12, y + 0.5), Vector3(1, 0.04, 1))
				for d in MapGen.DIRS:
					if m.t(wb.street, x + d.x, y + d.y) != TacMap.T.WATER:
						wb.box(coping, Vector3(x + 0.5 + d.x * 0.45, 0.04, y + 0.5 + d.y * 0.45), Vector3(1.0 if d.x == 0 else 0.12, 0.08, 1.0 if d.y == 0 else 0.12))
				if not lit:
					lit = true
					wb.emitters.append({"cell": Vector3i(x, y, wb.street), "color": Color("40d0ff"), "energy": 1.2, "range": 5.0, "out": Vector2i.ZERO})


## A decontamination arch over the way in at each gate of the grounds: steel posts either side, a
## bar of nozzles across, a green ready light (the Estates' decon sprayers; dressing only).
static func _decon_gate(wb: WorldBuilder) -> void:
	var m := wb.m
	var steel := wb.mat("steel", wb.street, false, {"color": Color("c8ccd0")})
	for e in m.entrances:
		if String(e.kind) != "gate":
			continue
		for d in MapGen.DIRS:
			var n: Vector2i = e.pos + d
			var l := m.label(wb.street, n.x, n.y)
			if not m.inb(n.x, n.y) or l < 0 or not m.rooms[l].get("outdoor", false):
				continue
			var across := Vector3(absf(d.y), 0, absf(d.x))
			var c := Vector3(n.x + 0.5, 0, n.y + 0.5) + Vector3(d.x, 0, d.y) * 0.6
			for s in [-1, 1]:
				wb.box(steel, c + across * s * 1.6 + Vector3(0, 1.3, 0), Vector3(0.14, 2.6, 0.14))
			wb.box(steel, c + Vector3(0, 2.6, 0), across * 3.4 + Vector3(0.18, 0.18, 0.18) - across * 0.18)
			for i in 5:
				wb.box(wb.mat("dark", wb.street, false, {"glow": 1.6, "emit": Color("60ffa0")}), c + across * (i - 2) * 0.6 + Vector3(0, 2.48, 0), Vector3(0.08, 0.06, 0.08))
			wb.emitters.append({"cell": Vector3i(n.x, n.y, wb.street), "color": Color("60ffa0"), "energy": 0.9, "range": 3.5, "out": Vector2i.ZERO})
			break


## Fires in the oil drums standing out in the open (a gang's yard, the Hot Zone's ruins): the
## only light out there.
static func _burn_barrels(wb: WorldBuilder, f: int) -> void:
	var m := wb.m
	var fire := wb.mat("dark", f, false, {"glow": 3.0, "emit": Color("ff7a20")})
	var ember := wb.mat("dark", f, false, {"glow": 2.0, "emit": Color("ffb040")})
	for c in m.cover:
		if int(c.floor) != f or String(c.kind) != "barrel" or int(c.get("hp", 1)) <= 0:
			continue
		var l := m.label(f, c.pos.x, c.pos.y)
		if l < 0 or not m.rooms[l].get("outdoor", false):
			continue
		var p := Vector3(c.pos.x + 0.5, f * FH, c.pos.y + 0.5)
		wb.put("cyl", fire, Transform3D(Basis.from_scale(Vector3(0.34, 0.12, 0.34)), p + Vector3(0, 0.66, 0)))
		wb.put("sphere", ember, Transform3D(Basis.from_scale(Vector3(0.22, 0.3, 0.22)), p + Vector3(0, 0.82, 0)))
		wb.emitters.append({"cell": Vector3i(c.pos.x, c.pos.y, f), "color": Color("ff8a30"), "energy": 2.0, "range": 6.0, "out": Vector2i.ZERO})


## A basketball court painted on the open asphalt of the grounds (a schoolyard): the outline, the
## half-way line and circle, the keys, and two hoops on posts at the ends. It goes where the
## asphalt has least on it (the gang's barricades and drums stand on the old court).
static func _court_lines(wb: WorldBuilder, col: Color) -> void:
	var m := wb.m
	var open := func(x: int, y: int) -> bool:
		var l := m.label(wb.street, x, y)
		return m.inb(x, y) and m.t(wb.street, x, y) == TacMap.T.OUTSIDE and int(m.ground[y * m.w + x]) == TacMap.G.ASPHALT \
			and l >= 0 and m.rooms[l].get("outdoor", false)
	var best := Rect2i()
	var best_n := 1 << 30
	for sz in [Vector2i(15, 8), Vector2i(8, 15)]:
		for y in range(1, m.h - sz.y):
			for x in range(1, m.w - sz.x):
				var n := 0
				for yy in range(y, y + sz.y):
					for xx in range(x, x + sz.x):
						if not open.call(xx, yy):
							n = 1 << 30
							break
						if m.has_cover_at(wb.street, Vector2i(xx, yy)):
							n += 1
					if n >= best_n:
						break
				if n < best_n:
					best_n = n
					best = Rect2i(x, y, sz.x, sz.y)
	if not best.has_area():
		return
	var paint := wb.mat("dark", wb.street, true, {"color": col, "glow": 0.25, "emit": col})
	var r := Rect2(best).grow(-0.3)
	var long_x := r.size.x >= r.size.y
	var y := 0.025
	var line := func(a: Vector2, b: Vector2) -> void:
		var mid := (a + b) / 2.0
		var d := b - a
		wb.box(paint, Vector3(mid.x, y, mid.y), Vector3(maxf(absf(d.x), 0.08), 0.02, maxf(absf(d.y), 0.08)))
	line.call(r.position, Vector2(r.end.x, r.position.y))
	line.call(Vector2(r.position.x, r.end.y), r.end)
	line.call(r.position, Vector2(r.position.x, r.end.y))
	line.call(Vector2(r.end.x, r.position.y), r.end)
	var c := r.get_center()
	if long_x:
		line.call(Vector2(c.x, r.position.y), Vector2(c.x, r.end.y))
	else:
		line.call(Vector2(r.position.x, c.y), Vector2(r.end.x, c.y))
	for i in 12:
		var a := TAU * i / 12.0
		wb.box(paint, Vector3(c.x + cos(a) * 1.3, y, c.y + sin(a) * 1.3), Vector3(0.1, 0.02, 0.7), -a)
	for e in [-1, 1]:   # keys and hoops
		var end := Vector2(r.position.x if e < 0 else r.end.x, c.y) if long_x else Vector2(c.x, r.position.y if e < 0 else r.end.y)
		var inward := Vector2(-e, 0) if long_x else Vector2(0, -e)
		var across := Vector2(0, 1) if long_x else Vector2(1, 0)
		var k0 := end + across * 1.3
		var k1 := end - across * 1.3
		line.call(k0, k0 + inward * 2.6)
		line.call(k1, k1 + inward * 2.6)
		line.call(k0 + inward * 2.6, k1 + inward * 2.6)
		var post := end - inward * 0.2
		wb.box(wb.mat("post", wb.street), Vector3(post.x, 1.0, post.y), Vector3(0.08, 2.0, 0.08))
		var board := end + inward * 0.25
		wb.box(wb.mat("steel", wb.street, false, {"color": Color("e8e8e0")}), Vector3(board.x, 1.9, board.y), Vector3(0.05, 0.5, 0.8) if long_x else Vector3(0.8, 0.5, 0.05))
		var rim := end + inward * 0.55
		wb.put("cyl", wb.mat("steel", wb.street, false, {"color": Color("d05020")}), Transform3D(Basis.from_scale(Vector3(0.45, 0.03, 0.45)), Vector3(rim.x, 1.75, rim.y)))


## Squares of a structure's footprint on storey f that are outer wall, with the outward direction.
static func _outer_walls(wb: WorldBuilder, f: int, sid: int) -> Array:
	var m := wb.m
	var out := []
	var r: Rect2i = m.structures[sid].rect
	for y in range(maxi(r.position.y, 0), mini(r.end.y, m.h)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, m.w)):
			if m.t(f, x, y) != TacMap.T.WALL or int(m.wall_mat[f][y * m.w + x]) in [3, 4, 5, 6]:
				continue
			for d in MapGen.DIRS:
				var n: Vector2i = Vector2i(x, y) + d
				if not m.inb(n.x, n.y):
					continue
				var t := m.t(f, n.x, n.y)
				var l := m.label(f, n.x, n.y)
				if t in [TacMap.T.VOID, TacMap.T.WATER] or (t in [TacMap.T.OUTSIDE, TacMap.T.ROOF] and (l < 0 or m.rooms[l].get("outdoor", false))):
					out.append([Vector2i(x, y), d])
					break
	return out


## Tags sprayed on the facade in the gang's colours: a few strokes and a fat throw-up per tag.
static func _graffiti(wb: WorldBuilder, f: int, sid: int, rate: float) -> void:
	var fc: Array = faction_colors(wb.m)
	var cols: Array = [fc[1], fc[0].lightened(0.45), Color("f0f0e8"), wb.neon[0], fc[1].lightened(0.3)]
	for e in _outer_walls(wb, f, sid):
		var v: Vector2i = e[0]
		var d: Vector2i = e[1]
		wb.rng.seed = hash(Vector3i(v.x, v.y, f)) + 4242
		if wb.rng.randf() > rate:
			continue
		_tag(wb, f, v, d, cols)


static func _tag(wb: WorldBuilder, f: int, v: Vector2i, d: Vector2i, cols: Array) -> void:
	var out := Vector3(d.x, 0, d.y)
	var along := Vector3(-d.y, 0, d.x)
	var face := Vector3(v.x + 0.5, f * FH, v.y + 0.5) + out * (EXT_T / 2 + 0.012)
	var col: Color = cols[wb.rng.randi() % cols.size()]
	var col2: Color = cols[wb.rng.randi() % cols.size()]
	var h := wb.rng.randf_range(0.35, 0.8)
	var thin := func(w: float, ht: float) -> Vector3: return Vector3(w, ht, 0.012) if d.x == 0 else Vector3(0.012, ht, w)
	# the throw-up: an outlined blob of letters
	var bw := wb.rng.randf_range(0.5, 0.95)
	wb.box(wb.mat("dark", f, true, {"color": col2.darkened(0.5), "shell": true}), face + Vector3(0, h, 0), thin.call(bw + 0.08, 0.34))
	wb.box(wb.mat("dark", f, true, {"color": col, "glow": 0.45, "emit": col, "shell": true}), face + out * 0.004 + Vector3(0, h, 0), thin.call(bw, 0.26))
	# strokes: a drip, an underline, a slash
	for i in wb.rng.randi_range(1, 3):
		var sl := wb.rng.randf_range(0.2, 0.55)
		var off := along * wb.rng.randf_range(-0.35, 0.35) + Vector3(0, h + wb.rng.randf_range(-0.3, 0.25), 0)
		var yaw := wb.rng.randf_range(-0.5, 0.5)
		var b := Basis(out, yaw).scaled_local(thin.call(sl, 0.04))
		wb.put("box", wb.mat("dark", f, true, {"color": col2, "glow": 0.3, "emit": col2, "shell": true}), Transform3D(b, face + out * 0.008 + off))


## Lit strips and glass balustrades along a stepped tower's terrace edges.
static func _terrace_lights(wb: WorldBuilder, f: int, sid: int, col: Color) -> void:
	var m := wb.m
	var y0 := f * FH
	for r in m.rooms:
		if r.cells == 0 or int(r.floor) != f or int(r.get("structure", -1)) != sid or String(r.kind) != "terrace":
			continue
		for v in Furnish.room_cells(m, r):
			for d in MapGen.DIRS:
				var n: Vector2i = v + d
				if m.inb(n.x, n.y) and m.t(f, n.x, n.y) != TacMap.T.VOID:
					continue
				var off := Vector3(d.x, 0, d.y) * 0.46
				var cv := Vector3(v.x + 0.5, y0, v.y + 0.5) + off
				var strip := Vector3(1.0, 0.04, 0.06) if d.x == 0 else Vector3(0.06, 0.04, 1.0)
				var pane := Vector3(1.0, 0.55, 0.03) if d.x == 0 else Vector3(0.03, 0.55, 1.0)
				wb.box(wb.mat("dark", f, true, {"glow": 2.2, "emit": col}), cv + Vector3(0, 0.03, 0), strip)
				wb.box(wb.mat("glass", f, true, {"alpha": 0.3}), cv + Vector3(0, 0.32, 0), pane)
				if (v.x + v.y) % 3 == 0:
					wb.emitters.append({"cell": Vector3i(v.x, v.y, f), "color": col, "energy": 0.5, "range": 2.5, "out": Vector2i.ZERO})


## A crown of tall fins round the top roof's edge, their tips glowing.
static func _crown(wb: WorldBuilder, f: int, sid: int, col: Color) -> void:
	var m := wb.m
	if f != m.street + int(m.structures[sid].floors):   # the top roof: `floors` counts storeys from the street
		return
	var y0 := f * FH
	var r: Rect2i = m.structures[sid].rect
	var fin := wb.mat("steel", f, true, {"color": Color("1c2228"), "shell": true})
	var tip := wb.mat("dark", f, true, {"glow": 2.4, "emit": col, "shell": true})
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if m.t(f, x, y) != TacMap.T.ROOF or m.t(f - 1, x, y) == TacMap.T.ROOF:
				continue
			for d in MapGen.DIRS:
				var n: Vector2i = Vector2i(x, y) + d
				if m.inb(n.x, n.y) and m.t(f, n.x, n.y) != TacMap.T.VOID:
					continue
				var p := Vector3(x + 0.5, y0, y + 0.5) + Vector3(d.x, 0, d.y) * 0.47
				var sz := Vector3(0.1, 1.5, 0.35) if d.x != 0 else Vector3(0.35, 1.5, 0.1)
				wb.box(fin, p + Vector3(0, 0.75, 0), sz)
				wb.box(tip, p + Vector3(0, 1.52, 0), sz * Vector3(1.2, 0.04, 1.2) + Vector3(0, 0.02, 0))
	wb.emitters.append({"cell": Vector3i(r.get_center().x, r.get_center().y, f), "color": col, "energy": 1.4, "range": 8.0, "out": Vector2i.ZERO})


## Merlons on alternate squares along every roof edge of a castle's buildings.
static func _crenels(wb: WorldBuilder, f: int, sid: int) -> void:
	var m := wb.m
	if f <= m.street:
		return
	var y0 := f * FH
	var r: Rect2i = m.structures[sid].rect
	var mt := wb.mat("wall_concrete", f, true, {"shell": true}.merged(mat_over(look(m, sid).get("wall", {}))))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if m.t(f, x, y) != TacMap.T.ROOF or (x + y) % 2 != 0:
				continue
			for d in MapGen.DIRS:
				var n: Vector2i = Vector2i(x, y) + d
				if m.inb(n.x, n.y) and not (m.t(f, n.x, n.y) in [TacMap.T.VOID, TacMap.T.OUTSIDE]):
					continue
				var p := Vector3(x + 0.5, y0, y + 0.5) + Vector3(d.x, 0, d.y) * 0.4
				wb.box(mt, p + Vector3(0, 0.36, 0), Vector3(0.55, 0.72, 0.22) if d.x == 0 else Vector3(0.22, 0.72, 0.55))


## Landing pads painted on a tower's roomy terraces and its top roof: a ring, an H, edge lights.
static func _pads(wb: WorldBuilder, f: int, sid: int) -> void:
	var m := wb.m
	var y0 := f * FH
	var fc: Array = faction_colors(m)
	for r in m.rooms:
		if r.cells < 24 or int(r.floor) != f or int(r.get("structure", -1)) != sid or not (String(r.kind) in ["terrace", "roof"]):
			continue
		var cells := Furnish.room_cells(m, r)
		var mid := Vector2((r.bounds as Rect2i).get_center())
		cells.sort_custom(func(a, b): return Vector2(a).distance_squared_to(mid) < Vector2(b).distance_squared_to(mid))
		var at: Vector2i = cells[0]
		var c := Vector3(at.x + 0.5, y0 + 0.02, at.y + 0.5)
		var rad := clampf(minf((r.bounds as Rect2i).size.x, (r.bounds as Rect2i).size.y) / 2.0 - 0.6, 1.0, 2.2)
		var paint := wb.mat("dark", f, true, {"color": Color("d8d4c8"), "glow": 0.3, "emit": Color("d8d4c8")})
		for i in 16:
			var a := TAU * i / 16.0
			wb.box(paint, c + Vector3(cos(a), 0, sin(a)) * rad, Vector3(0.14, 0.02, rad * 0.4), -a)
		wb.box(paint, c + Vector3(-0.4, 0, 0), Vector3(0.14, 0.02, 1.1))
		wb.box(paint, c + Vector3(0.4, 0, 0), Vector3(0.14, 0.02, 1.1))
		wb.box(paint, c, Vector3(0.8, 0.02, 0.14))
		for i in 8:
			var a2 := TAU * i / 8.0
			wb.box(wb.mat("dark", f, true, {"glow": 2.5, "emit": fc[1]}), c + Vector3(cos(a2), 0.04, sin(a2)) * (rad + 0.4), Vector3(0.1, 0.06, 0.1))
		wb.emitters.append({"cell": Vector3i(at.x, at.y, f), "color": fc[1], "energy": 0.7, "range": 3.5, "out": Vector2i.ZERO})


## A ship's boot-topping: a red band at the waterline under a white line, round the hull.
static func _waterline(wb: WorldBuilder, sid: int, col: Color) -> void:
	for e in _outer_walls(wb, wb.street, sid):
		var v: Vector2i = e[0]
		var d: Vector2i = e[1]
		var out := Vector3(d.x, 0, d.y)
		var face := Vector3(v.x + 0.5, 0, v.y + 0.5) + out * (EXT_T / 2 + 0.01)
		var w := Vector3(1.02, 0, 0.02) if d.x == 0 else Vector3(0.02, 0, 1.02)
		wb.box(wb.mat("steel", wb.street, true, {"color": col, "shell": true}), face + Vector3(0, 0.16, 0), w + Vector3(0, 0.32, 0))
		wb.box(wb.mat("steel", wb.street, true, {"color": Color("e0e0d8"), "shell": true}), face + Vector3(0, 0.35, 0), w + Vector3(0, 0.05, 0))


## A lit name band over the main door.
static func _sign(wb: WorldBuilder, sid: int, col: Color) -> void:
	var m := wb.m
	for e in m.entrances:
		if not e.main or int(e.get("structure", -1)) != sid:
			continue
		var p: Vector2i = e.pos
		for d in MapGen.DIRS:
			var n: Vector2i = p + d
			var t := m.t(wb.street, n.x, n.y)
			var l := m.label(wb.street, n.x, n.y)
			if not (t == TacMap.T.OUTSIDE and (l < 0 or m.rooms[l].get("outdoor", false))):
				continue
			var out := Vector3(d.x, 0, d.y)
			var face := Vector3(p.x + 0.5, 0, p.y + 0.5) + out * (EXT_T / 2 + 0.03)
			var w := Vector3(2.6, 0.3, 0.05) if d.x == 0 else Vector3(0.05, 0.3, 2.6)
			wb.box(wb.mat("dark", wb.street, true, {"color": Color("1a1c20"), "shell": true}), face + Vector3(0, 1.38, 0), w + Vector3(0.1, 0.08, 0) * (Vector3(1, 1, 0) if d.x == 0 else Vector3(0, 1, 1)))
			wb.box(wb.mat("dark", wb.street, true, {"glow": 2.2, "emit": col, "shell": true}), face + out * 0.03 + Vector3(0, 1.38, 0), w * Vector3(0.9, 0.6, 1))
			wb.emitters.append({"cell": Vector3i(n.x, n.y, wb.street), "color": col, "energy": 1.2, "range": 4.0, "out": Vector2i.ZERO})
			return


## Standing water over drowned rooms' floors (Eurasiabank's sunken vaults).
static func _flooded(wb: WorldBuilder, f: int, sid: int, kinds: Array) -> void:
	var m := wb.m
	var y0 := f * FH
	var water := wb.mat("water", f, true, {"glow": 0.4})
	for r in m.rooms:
		if r.cells == 0 or int(r.floor) != f or int(r.get("structure", -1)) != sid or not (String(r.kind) in kinds):
			continue
		var b: Rect2i = r.bounds
		if f >= m.street:
			wb.box(water, Vector3(b.get_center().x, y0 + 0.05, b.get_center().y), Vector3(b.size.x, 0.04, b.size.y))
			continue
		# below grade the deep pools are real WATER squares (WorldBuilder._earth): the sheen
		# lies only over the dry floor round them, thin, so the pools read darker and deeper
		var sheen := wb.mat("water", f, true, {"glow": 0.25, "alpha": 0.55})
		for c in Furnish.room_cells(m, r):
			if m.t(f, c.x, c.y) == TacMap.T.FLOOR:
				wb.box(sheen, Vector3(c.x + 0.5, y0 + 0.03, c.y + 0.5), Vector3(1.0, 0.02, 1.0))


## The compound's perimeter wall: merlons along its top, tags on its street face.
static func _perimeter(wb: WorldBuilder, sl: Dictionary) -> void:
	var m := wb.m
	var mt := wb.mat("wall_concrete", wb.street, true, {"shell": true})
	var fc: Array = faction_colors(m)
	var cols: Array = [fc[1], Color("f0f0e8"), wb.neon[0]]
	for y in m.h:
		for x in m.w:
			if m.t(wb.street, x, y) != TacMap.T.WALL or wb._sid_grid[y * m.w + x] >= 0 or int(m.wall_mat[wb.street][y * m.w + x]) in [3, 4]:
				continue
			if sl.get("wall_crenels", false) and (x + y) % 2 == 0:
				wb.box(mt, Vector3(x + 0.5, wb.gy + FH + 0.3, y + 0.5), Vector3(0.5, 0.6, 0.5))
			if sl.has("graffiti_walls"):
				for d in MapGen.DIRS:
					var n: Vector2i = Vector2i(x, y) + d
					if m.inb(n.x, n.y) and m.t(wb.street, n.x, n.y) == TacMap.T.OUTSIDE and m.label(wb.street, n.x, n.y) < 0:
						wb.rng.seed = hash(Vector3i(x, y, 77))
						if wb.rng.randf() < float(sl.graffiti_walls):
							_tag(wb, wb.street, Vector2i(x, y), d, cols)
						break
