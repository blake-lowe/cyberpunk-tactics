class_name CarProp
extends RefCounted
## Street cars and burnt-out wrecks over their cover footprints (Furnish "car" 2x1, "wreck" 2x1 or
## 2x2), at real-world scale, from the makes in data/gen/cars.json. Owner verdicts 2026-11-09:
## "the car proportions are laughably wrong" (a 3.4 x 1.6 m slab 1.1 m high; a 2x2 wreck drew a
## square car), then "a smooth car model and different makes and colors for variation".
##
## World units are squares (1 square = 2 m, CPR core p.127). A groundcar is about 4.5 x 1.8 x
## 1.45 m: 2.2 x 0.9 x 0.72 squares, well under a storey (WorldBuilder.FH 1.6). Each make's body
## is lofted from its side profile (`top` knots) into one smooth mesh, rounded in plan and in
## section (tumblehome over the beltline), wheel arches cut out of the sills, glass as its own
## surface; tyres sit inset under the arches. A make's bodies are generated once and batched by
## WorldBuilder like any prop. Paint by the street's band (SceneEvent bands): muted, dirty and
## primer-patched in the Combat Zone, glossy dark with chrome in corporate streets.
##
## Visual only: the make, paint and stance come from the map seed and the prop's hash (frame()), so
## the same map always parks the same cars. parts() is plain data, so sizes are tested headless.

const DATA := "cars.json"
const BURNT := Color("2c2420")
const STEP := 0.06          ## loft station spacing along the car (squares)
const ARCH_GAP := 0.035     ## wheel arch clearance over the tyre

static var _db: Dictionary = {}
static var _meshes: Dictionary = {}   ## "make:paint" / "make:glass" → ArrayMesh


static func db() -> Dictionary:
	if _db.is_empty():
		_db = RulesDB.gen(DATA)
	return _db


static func makes() -> Dictionary:
	return db().makes


static func make(id: String) -> Dictionary:
	return makes().get(id, makes().compact)


## The street band a map's cars are drawn for (SceneEvent bands: corporate, moderate, combat_zone,
## outskirts), from its district's Security Code and profile; "moderate" when there's none.
static func band(m: TacMap) -> String:
	var did := String(m.params.get("district", ""))
	var d := World.district(did) if did != "" else {}
	var dcode := SecurityCode.normalise(d.get("security_code")) if not d.is_empty() else {}
	var b := SceneEvent.band_of(-1, int(dcode.get("n", -1)) if not dcode.is_empty() else -1, String(d.get("profile", m.params.get("profile", ""))),
		String(m.params.get("scene", "")), did)
	return b if b in ["corporate", "moderate", "combat_zone", "outskirts"] else "moderate"


## A make for the band, by its weight.
static func pick_make(rng: RandomNumberGenerator, bnd: String) -> String:
	var total := 0.0
	for id in makes():
		total += float(makes()[id].weight.get(bnd, 1.0))
	var r := rng.randf() * total
	for id in makes():
		r -= float(makes()[id].weight.get(bnd, 1.0))
		if r <= 0.0:
			return String(id)
	return "compact"


## Where and what the car is: {make, centre (map xz), yaw, roll, paint, chrome, primer [x, z side]
## or [], glow (underglow colour or transparent), cab, wreck, lost (the wreck's missing wheel)}.
## Lengthwise along the footprint's long side; a wreck on a 2x2 footprint stands skewed across it.
static func frame(kind: String, r: Rect2, h0: int, seed_value := 0, bnd := "moderate", force_make := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([h0, seed_value, 41])
	var long_x := r.size.x >= r.size.y
	var yaw := (0.0 if long_x else -PI / 2) + rng.randf_range(-0.04, 0.04)
	if rng.randf() < 0.5:
		yaw += PI   # parked either way round
	var wreck := kind == "wreck"
	if wreck and absf(r.size.x - r.size.y) < 0.5:
		yaw += rng.randf_range(0.22, 0.4) * (1.0 if rng.randf() < 0.5 else -1.0)
	var id := force_make if force_make != "" else pick_make(rng, bnd)
	var mk := make(id)
	var pal: Dictionary = db().paint.get(bnd, db().paint.moderate)
	var cols: Array = pal.colors
	var paint := Color(String(cols[rng.randi() % cols.size()]))
	var cab := not wreck and rng.randf() < float(mk.get("cab", 0.0))
	if cab:
		paint = Color(String(db().paint.cab))
	var primer: Array = []
	if not wreck and rng.randf() < float(pal.primer):   # a replaced panel, never painted
		var pc: Array = db().paint.primer_colors
		primer = [rng.randf_range(-0.35, 0.35) * float(mk.length), 1.0 if rng.randf() < 0.5 else -1.0, Color(String(pc[rng.randi() % pc.size()]))]
	var glow := Color(0, 0, 0, 0)
	if not wreck and rng.randf() < float(pal.glow):
		var gc: Array = db().paint.glow_colors
		glow = Color(String(gc[rng.randi() % gc.size()]))
	return {"make": id, "centre": r.get_center(), "yaw": yaw, "wreck": wreck, "paint": paint if not wreck else BURNT,
		"chrome": not wreck and rng.randf() < float(pal.chrome), "primer": primer, "glow": glow, "cab": cab,
		"roll": rng.randf_range(0.03, 0.06) * (1.0 if rng.randf() < 0.5 else -1.0) if wreck else 0.0,
		"lost": rng.randi() % 4 if wreck else -1}


# --- The body: a loft of the make's profile ---------------------------------------------------

static func _top(mk: Dictionary, x: float) -> float:
	var k: Array = mk.top
	if x <= float(k[0][0]):
		return float(k[0][1])
	for i in range(1, k.size()):
		var a: Array = k[i - 1]
		var b: Array = k[i]
		if x <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001))
	return float(k[k.size() - 1][1])


static func _sill(mk: Dictionary, x: float) -> float:
	var r := float(mk.wheel[0])
	var ax := float(mk.wheel[1]) / 2
	var R := r + ARCH_GAP
	var s := float(mk.sill)
	for c in [-ax, ax]:
		var dx := absf(x - c)
		if dx < R:
			s = maxf(s, r + sqrt(R * R - dx * dx) * 0.92)
	var e := clampf((absf(x) - (float(mk.length) / 2 - 0.12)) / 0.12, 0.0, 1.0)
	return s + 0.05 * e * e   # the bumpers tuck under


static func _half_w(mk: Dictionary, x: float) -> float:
	var hw := float(mk.width) / 2
	var e := clampf((absf(x) - (float(mk.length) / 2 - 0.24)) / 0.24, 0.0, 1.0)
	return hw * (1.0 - 0.16 * e * e)


## One station's section, left sill round over the top to the right sill: Vector2(z, y).
static func _section(mk: Dictionary, x: float) -> PackedVector2Array:
	var w := _half_w(mk, x)
	var top := _top(mk, x)
	var sill := minf(_sill(mk, x), top - 0.06)
	var belt := minf(float(mk.belt), top - 0.02)
	var hgt := top - belt
	var t := smoothstep(0.04, 0.16, hgt)   # 0: a hood or boot, 1: under the glasshouse
	var z3 := w - lerpf(0.03, 0.085, t)
	var y3 := belt + hgt * lerpf(0.5, 0.86, t)
	var z4 := w - lerpf(0.1, 0.15, t)
	var pts := [Vector2(-w + 0.035, sill), Vector2(-w, sill + 0.04), Vector2(-w, belt), Vector2(-z3, y3), Vector2(-z4, top),
		Vector2(z4, top), Vector2(z3, y3), Vector2(w, belt), Vector2(w, sill + 0.04), Vector2(w - 0.035, sill)]
	return PackedVector2Array(pts)


static func _stations(mk: Dictionary) -> PackedFloat32Array:
	var L := float(mk.length)
	var xs := {}
	var n := int(ceil(L / STEP))
	for i in n + 1:
		xs[snappedf(-L / 2 + L * i / n, 0.0001)] = true
	for k in mk.top:
		xs[snappedf(clampf(float(k[0]), -L / 2, L / 2), 0.0001)] = true
	var ax := float(mk.wheel[1]) / 2
	var R := float(mk.wheel[0]) + ARCH_GAP
	for c in [-ax, ax]:   # finer round the arches
		for i in 13:
			xs[snappedf(c - R + 2.0 * R * i / 12.0, 0.0001)] = true
	var out := PackedFloat32Array(xs.keys())
	out.sort()
	return out


## Whether the face between stations at x (mid) on section edge j (0..9, edge j → j+1) is glass.
static func _glass(mk: Dictionary, x: float, j: int, slope: float) -> bool:
	var hgt := _top(mk, x) - float(mk.belt)
	if hgt < 0.12:
		return false
	var sg: Array = mk.side_glass
	if j == 2 or j == 6:   # the side windows, a pillar between them
		var c := (float(sg[0]) + float(sg[1])) / 2
		return x > float(sg[0]) and x < float(sg[1]) and absf(x - c) > 0.03 and absf(slope) < 0.5
	if j in [3, 4, 5]:   # the windscreen and the rear glass slope
		return absf(slope) > 0.35
	return false


## The make's body meshes {paint: ArrayMesh, glass: ArrayMesh}, smooth normals, made once.
static func body(id: String) -> Dictionary:
	if _meshes.has(id + ":paint"):
		return {"paint": _meshes[id + ":paint"], "glass": _meshes[id + ":glass"]}
	var mk := make(id)
	var xs := _stations(mk)
	var grid: Array = []   # [station][ring point] → Vector3
	for x in xs:
		var row: Array = []
		for p in _section(mk, x):
			row.append(Vector3(x, p.y, p.x))
		grid.append(row)
	var ns := grid.size()
	var nr: int = (grid[0] as Array).size()
	var norm: Array = []
	for i in ns:
		var row: Array = []
		for j in nr:
			var dx: Vector3 = grid[mini(i + 1, ns - 1)][j] - grid[maxi(i - 1, 0)][j]
			var ds: Vector3 = grid[i][(j + 1) % nr] - grid[i][(j - 1 + nr) % nr]
			var n := ds.cross(dx).normalized()
			var p: Vector3 = grid[i][j]
			if n.dot(Vector3(0, p.y - 0.3, p.z)) < 0.0:
				n = -n
			if i == 0 or i == ns - 1:   # the ends lean out lengthwise
				n = (n + Vector3(signf(p.x), 0, 0) * 0.8).normalized()
			row.append(n)
		norm.append(row)
	var st := {"paint": SurfaceTool.new(), "glass": SurfaceTool.new()}
	for k in st:
		(st[k] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ns - 1:
		var xm := (xs[i] + xs[i + 1]) / 2
		var slope := (_top(mk, xs[i + 1]) - _top(mk, xs[i])) / maxf(xs[i + 1] - xs[i], 0.0001)
		for j in nr:
			var j2 := (j + 1) % nr
			var s: SurfaceTool = st["glass" if _glass(mk, xm, j, slope) else "paint"]
			_quad(s, [grid[i][j], grid[i + 1][j], grid[i + 1][j2], grid[i][j2]], [norm[i][j], norm[i + 1][j], norm[i + 1][j2], norm[i][j2]])
	for e in [0, ns - 1]:   # end caps: a fan from the middle of the end section
		var c := Vector3.ZERO
		for p in grid[e]:
			c += p
		c /= nr
		var out := Vector3(-1 if e == 0 else 1, 0, 0)
		var s: SurfaceTool = st.paint
		for j in nr:
			var a: Vector3 = grid[e][j]
			var b: Vector3 = grid[e][(j + 1) % nr]
			var tri := [c, a, b] if e != 0 else [c, b, a]
			for v in tri:
				s.set_normal(((v - c) * Vector3(0, 1, 1) * 1.5 + out).normalized())
				s.set_uv(Vector2(v.z, v.y))
				s.add_vertex(v)
	for k in st:
		_meshes[id + ":" + k] = (st[k] as SurfaceTool).commit()
	return {"paint": _meshes[id + ":paint"], "glass": _meshes[id + ":glass"]}


## A quad as two triangles, wound so its face points the way of its normals.
static func _quad(s: SurfaceTool, v: Array, n: Array) -> void:
	var face: Vector3 = (v[1] - v[0]).cross(v[3] - v[0])
	var order := [0, 1, 2, 0, 2, 3] if face.dot(n[0] + n[2]) < 0.0 else [0, 2, 1, 0, 3, 2]
	for k in order:
		s.set_normal(n[k])
		s.set_uv(Vector2((v[k] as Vector3).x, (v[k] as Vector3).y))
		s.add_vertex(v[k])


# --- The rest of the car as parts ---------------------------------------------------------------

## Everything but the body in the car's own frame (+x forward, +z its left, y up, the ground under
## its middle): [{shape, mat (role), at, size, basis}]. Roles: tyre, hub, head, tail, dark, chrome,
## primer, glow, cab, rust. The body itself is {shape: "body"} with the make's length, width, height.
static func parts(fr: Dictionary) -> Array:
	var mk := make(String(fr.make))
	var out: Array = []
	var L := float(mk.length)
	var r := float(mk.wheel[0])
	var ax := float(mk.wheel[1]) / 2
	var track := float(mk.width) / 2 - 0.075
	var wreck: bool = fr.wreck
	out.append(_p("body", "paint", Vector3(0, float(mk.height) / 2, 0), Vector3(L, float(mk.height), float(mk.width))))
	var k := 0
	for e in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			if wreck and k == int(fr.lost):
				k += 1
				continue   # a wreck stands on three
			var tb := Basis(Vector3.RIGHT, PI / 2)
			out.append(_p("cyl", "tyre", Vector3(e * ax, r, side * track), Vector3(r * 2, 0.12, r * 2), tb))
			out.append(_p("cyl", "hub" if not wreck else "rust", Vector3(e * ax, r, side * (track + 0.061)), Vector3(r * 1.15, 0.01, r * 1.15), tb))
			k += 1
	# the dark underside, so the arches read as openings
	out.append(_p("box", "dark", Vector3(0, 0.1 + float(mk.sill) / 2, 0), Vector3(L - 0.3, 0.16, float(mk.width) - 0.2)))
	var nose := _top(mk, L / 2 - 0.06)
	var tail := _top(mk, -L / 2 + 0.06)
	if not wreck:
		for side in [-1.0, 1.0]:
			out.append(_p("box", "head", Vector3(L / 2 - 0.035, nose - 0.05, side * (_half_w(mk, L / 2) - 0.1)), Vector3(0.06, 0.035, 0.14), Basis(Vector3.FORWARD, -0.3)))
		out.append(_p("box", "tail", Vector3(-L / 2 + 0.03, tail - 0.045, 0), Vector3(0.05, 0.03, _half_w(mk, -L / 2) * 2 - 0.12)))
		if fr.chrome:   # a chrome line along the beltline and round the grille
			for side in [-1.0, 1.0]:
				out.append(_p("box", "chrome", Vector3(0, float(mk.belt) - 0.035, side * (float(mk.width) / 2 + 0.003)), Vector3(L * 0.62, 0.016, 0.008)))
			out.append(_p("box", "chrome", Vector3(L / 2 + 0.002, nose - 0.13, 0), Vector3(0.01, 0.05, float(mk.width) * 0.45)))
		var pr: Array = fr.primer
		if not pr.is_empty():   # a primer panel: a door or a wing never painted to match
			var px := clampf(float(pr[0]), -ax + r + 0.12, ax - r - 0.12)
			var zz := float(pr[1]) * (_half_w(mk, px) + 0.004)
			out.append(_p("box", "primer", Vector3(px, (float(mk.belt) + _sill(mk, px)) / 2 + 0.02, zz), Vector3(0.42, float(mk.belt) - _sill(mk, px) - 0.06, 0.006)))
		if fr.glow.a > 0.0:   # a neon trim along the sills (a parked car's, never under a unit)
			for side in [-1.0, 1.0]:
				out.append(_p("box", "glow", Vector3(0, float(mk.sill) + 0.01, side * (float(mk.width) / 2 - 0.02)), Vector3(ax * 2 - r * 2 - 0.1, 0.012, 0.012)))
		if fr.cab:   # a cab's roof light
			var roof := _top(mk, 0.0)
			out.append(_p("box", "cab", Vector3(-0.05, roof + 0.03, 0), Vector3(0.12, 0.06, 0.3)))
		if mk.has("bed"):   # a pickup's open bed
			var bd: Array = mk.bed
			out.append(_p("box", "dark", Vector3((float(bd[0]) + float(bd[1])) / 2, float(mk.belt) - 0.015, 0), Vector3(float(bd[1]) - float(bd[0]), 0.04, float(mk.width) - 0.12)))
	else:   # rust blooms on the burnt shell
		out.append(_p("box", "rust", Vector3(L * 0.28, nose + 0.004, 0.08), Vector3(0.42, 0.008, 0.36)))
		out.append(_p("box", "rust", Vector3(-L * 0.32, tail + 0.004, -0.1), Vector3(0.28, 0.008, 0.3)))
	return out


static func _p(shape: String, mt: String, at: Vector3, size: Vector3, basis := Basis.IDENTITY) -> Dictionary:
	return {"shape": shape, "mat": mt, "at": at, "size": size, "basis": basis}


## The car's frame on the map: car-local → world (y = the floor's height).
static func xform(fr: Dictionary, y0: float) -> Transform3D:
	var c: Vector2 = fr.centre
	var bs := Basis(Vector3.UP, float(fr.yaw)) * Basis(Vector3.RIGHT, float(fr.roll))
	return Transform3D(bs, Vector3(c.x, y0 - (0.05 if fr.wreck else 0.0), c.y))   # a wreck sits low on its rims


## The car's bounds in its own frame: the body mesh and every part.
static func bounds(fr: Dictionary) -> AABB:
	var ab: AABB = (body(String(fr.make)).paint as Mesh).get_aabb()
	for p in parts(fr):
		if p.shape == "body":
			continue
		var bs: Basis = (p.basis as Basis) * Basis.from_scale(p.size)
		for i in 8:
			ab = ab.expand(p.at + bs * Vector3((i & 1) - 0.5, ((i >> 1) & 1) - 0.5, ((i >> 2) & 1) - 0.5))
	return ab


## The four corner lamps in world space (AmbientFx hazard blinkers).
static func corners(fr: Dictionary, y0: float) -> Array:
	var mk := make(String(fr.make))
	var xf := xform(fr, y0)
	var L := float(mk.length)
	var out: Array = []
	for e in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var x: float = e * (L / 2 - 0.02)
			out.append(xf * Vector3(x, _top(mk, x) - 0.05, side * (_half_w(mk, x) - 0.06)))
	return out


## The frame for a prop on a map: its band and the map's seed (WorldBuilder, AmbientFx agree).
## A prop may name its make (`make` on its cover squares: the lineup, a set piece's own car).
static func frame_on(m: TacMap, kind: String, r: Rect2, h0: int, force_make := "", force_band := "") -> Dictionary:
	return frame(kind, r, h0, m.seed_value, force_band if force_band != "" else band(m), force_make)


## Draws the car into WorldBuilder's batches (bodies and parts share the builder's materials).
static func draw(wb: WorldBuilder, kind: String, r: Rect2, f: int, h0: int, force_make := "", force_band := "") -> void:
	draw_frame(wb, frame_on(wb.m, kind, r, h0, force_make, force_band), f)


## Review renders (greybox --cars=lineup): every make parked in a row on the open street nearest
## `near`, then a wreck of the first; each square of a car carries its make. Returns the row's middle.
static func lineup(m: TacMap, near: Vector2i) -> Vector2:
	var ids := makes().keys()
	var need := ids.size() * 4 + 4
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(1, m.h - 2):
		for x in range(8, m.w - need - 8):   # clear of the map's edge (a framed render stays on the map)
			var ok := true
			for dx in need:
				for dy in 2:
					var v := Vector2i(x + dx, y + dy)
					if m.t(m.street, v.x, v.y) != TacMap.T.OUTSIDE or m.has_cover_at(m.street, v) or m.label(m.street, v.x, v.y) >= 0:
						ok = false
						break
				if not ok:
					break
			var d := Vector2(x + need / 2.0 - near.x, y - near.y).length()
			if ok and d < bd:
				bd = d
				best = Vector2i(x, y)
	if best.x < 0:
		return Vector2(-1, -1)
	for i in ids.size() + 1:
		var kind := "car" if i < ids.size() else "wreck"
		var rect := Rect2i(best.x + 1 + i * 4, best.y, 3 if String(ids[mini(i, ids.size() - 1)]) in ["pickup", "van", "exec"] else 2, 1)
		var at := m.cover.size()
		if Furnish.try_prop(m, m.street, rect, kind, -1):
			for k in range(at, m.cover.size()):
				m.cover[k]["make"] = String(ids[i % ids.size()])
	return Vector2(best.x + need / 2.0, best.y + 1)


static func draw_frame(wb: WorldBuilder, fr: Dictionary, f: int) -> void:
	var xf := xform(fr, f * WorldBuilder.FH)
	var wreck: bool = fr.wreck
	var paint: Color = fr.paint
	var corp: bool = fr.chrome
	var mats := {
		"paint": wb.mat("steel", f, false, {"color": paint, "color2": paint.darkened(0.25)}) if not wreck
			else wb.mat("steel", f, false, {"color": BURNT, "color2": Color("120e0c"), "pattern": 5, "scale": 3.0}),
		"glass": wb.mat("glass", f, false, {"color": Color("0e1820") if not corp else Color("06080c"), "alpha": 0.88}) if not wreck else wb.mat("dark", f, false, {"color": Color("0a0908")}),
		"rust": wb.mat("steel", f, false, {"color": Color("6a3418")}),
		"dark": wb.mat("dark", f, false),
		"tyre": wb.mat("dark", f, false, {"color": Color("0c0d0f")}),
		"hub": wb.mat("steel", f, false, {"color": Color("8a9098") if not corp else Color("c8d0d8")}),
		"chrome": wb.mat("steel", f, false, {"color": Color("d8e0e8")}),
		"head": wb.mat("dark", f, false, {"glow": 1.6, "emit": Color("fff0d0")}),
		"tail": wb.mat("dark", f, false, {"glow": 1.6, "emit": Color("ff2030")}),
		"cab": wb.mat("dark", f, false, {"glow": 1.4, "emit": Color("fff4e0")}),
	}
	if not (fr.primer as Array).is_empty():
		mats["primer"] = wb.mat("steel", f, false, {"color": fr.primer[2]})
	if fr.glow.a > 0.0:
		mats["glow"] = wb.mat("dark", f, false, {"glow": 1.6, "emit": fr.glow})
	var id := String(fr.make)
	var bm := body(id)
	wb.add_shape("car_" + id, bm.paint)
	wb.add_shape("car_glass_" + id, bm.glass)
	for p in parts(fr):
		if p.shape == "body":
			wb.put("car_" + id, mats.paint, xf)
			wb.put("car_glass_" + id, mats.glass, xf)
			continue
		var bs: Basis = (p.basis as Basis) * Basis.from_scale(p.size)
		wb.put(String(p.shape), mats[String(p.mat)], Transform3D(xf.basis * bs, xf * (p.at as Vector3)))
