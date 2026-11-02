class_name WorldBuilder
extends RefCounted
## Turns a TacMap into a 3D scene that doesn't look like a grid (M4a review: the grid is for
## movement only). The map's cells still decide *where* things are; the geometry is built from
## features rather than cells:
## - walls are merged into continuous runs with real thickness (exterior thicker), skirting and
##   cornices; windows get sills, lintels and off-grid mullions; doors get frames and leaves
## - floors and ground are merged rectangles (greedy meshing) under off-grid procedural materials;
##   organic ground (grass, earth, sand, water) is outlined by marching squares
## - rock is a heap of jittered low-poly boulders; cover pieces are shaped props with small
##   deterministic offsets and turns; clutter (trash, AC units, posters, cables) is scattered off-grid
## - every floor and the roof is built; an XCOM-style radial cutaway (world.gdshader) opens the
##   view around the focus instead of hiding whole floors
## - a skyline of lit towers surrounds the map
## All geometry is batched into MultiMeshes per 8×8 chunk, so lights stay local.

const FH := 1.6
const CHUNK := 8
const EXT_T := 0.42       # exterior wall thickness
const INT_T := 0.24       # interior wall thickness
const SHADER := preload("res://src/tactical/view/world.gdshader")

## name → [albedo, albedo2, pattern, scale, rough, metal, extra{}]
const LIB := {
	"asphalt": [Color("17191d"), Color("0e0f12"), 3, 0.6, 0.55, 0.0],
	"sidewalk": [Color("3b3e43"), Color("25272b"), 4, 1.6, 0.7, 0.0],
	"concrete": [Color("33363a"), Color("232528"), 1, 0.37, 0.8, 0.0],
	"gravel": [Color("3b3833"), Color("2a2824"), 5, 2.0, 0.95, 0.0],
	"dirt": [Color("3a2f25"), Color("281f18"), 5, 0.8, 0.95, 0.0],
	"grass": [Color("1d2e1f"), Color("2c3a1c"), 5, 1.1, 0.95, 0.0],
	"sand": [Color("7a6a5e"), Color("5a4c48"), 5, 0.53, 0.95, 0.0],
	"rail": [Color("2c2724"), Color("1a1715"), 6, 0.9, 0.7, 0.2],
	"dock": [Color("2f2a25"), Color("1a1714"), 2, 0.8, 0.75, 0.0],
	"water": [Color("0a1822"), Color("0a1822"), 10, 0.5, 0.05, 0.2],
	"slab": [Color("1a1c20"), Color("1a1c20"), 0, 1.0, 0.9, 0.0],
	"floor_tile": [Color("2c2e33"), Color("1b1c1f"), 1, 1.13, 0.4, 0.0],
	"floor_wood": [Color("3a2a1f"), Color("1a120d"), 2, 1.1, 0.55, 0.0],
	"floor_concrete": [Color("2f3135"), Color("222427"), 1, 0.43, 0.75, 0.0],
	"floor_carpet": [Color("2a2233"), Color("2a2233"), 0, 4.0, 0.95, 0.0],
	"floor_metal": [Color("2a3038"), Color("181c21"), 6, 1.4, 0.45, 0.5],
	"floor_vault": [Color("2c2228"), Color("15101a"), 1, 0.9, 0.35, 0.3],
	"roof": [Color("2b2e33"), Color("1d1f22"), 5, 0.71, 0.85, 0.0, {"shell": true}],
	"stairs": [Color("4a5058"), Color("2a2e33"), 6, 3.0, 0.5, 0.3],
	"wall_concrete": [Color("5a5f66"), Color("34373c"), 7, 1.0, 0.85, 0.0],
	"wall_plaster": [Color("6e675d"), Color("47423b"), 7, 1.0, 0.9, 0.0],
	"wall_steel": [Color("46505b"), Color("2a3038"), 8, 1.0, 0.45, 0.5],
	"wall_int": [Color("7a756e"), Color("5d5952"), 0, 1.0, 0.9, 0.0],
	"skirt": [Color("1d1f23"), Color("1d1f23"), 0, 1.0, 0.7, 0.2],
	"cornice": [Color("2c3035"), Color("2c3035"), 0, 1.0, 0.7, 0.2],
	"frame": [Color("1b1d21"), Color("1b1d21"), 0, 1.0, 0.35, 0.7],
	"door": [Color("2e3239"), Color("2e3239"), 8, 1.5, 0.45, 0.5],
	"glass": [Color("7fc8e8"), Color("7fc8e8"), 0, 1.0, 0.05, 0.0, {"alpha": 0.24, "glow": 0.25}],
	"fence": [Color("7a8a7a"), Color("7a8a7a"), 0, 1.0, 0.4, 0.7, {"alpha": 0.3}],
	"post": [Color("3a4048"), Color("3a4048"), 0, 1.0, 0.4, 0.7],
	"rock": [Color("6a5a50"), Color("4a4038"), 5, 1.5, 0.95, 0.0],
	"unknown": [Color("1c212c"), Color("1c212c"), 0, 1.0, 0.95, 0.0, {"mode": 1, "glow": 0.5, "emit": Color("141a26")}],
	"wood": [Color("6a4e35"), Color("3e2c1e"), 2, 2.0, 0.8, 0.0],
	"steel": [Color("56606a"), Color("3a424a"), 0, 1.0, 0.4, 0.55],
	"concrete_prop": [Color("6a6e73"), Color("4a4d51"), 0, 2.0, 0.85, 0.0],
	"stone": [Color("67625b"), Color("4a4640"), 5, 2.0, 0.9, 0.0],
	"fabric": [Color("3b3048"), Color("3b3048"), 0, 6.0, 0.95, 0.0],
	"plant": [Color("3a4a2a"), Color("2f5a20"), 5, 3.0, 0.9, 0.0],
	"dark": [Color("141619"), Color("141619"), 0, 1.0, 0.6, 0.3],
	"container": [Color("6a3428"), Color("4a2418"), 8, 1.0, 0.6, 0.4],
	"tower": [Color("14171c"), Color("0e1014"), 9, 0.55, 0.8, 0.2, {"mode": 2}],
	"tower_top": [Color("101216"), Color("101216"), 0, 1.0, 0.8, 0.2, {"mode": 2}],
	"far_ground": [Color("111316"), Color("0b0c0e"), 0, 0.3, 0.9, 0.0, {"mode": 2}],
}
const PAINT := [Color("8a1c2a"), Color("1c3a5a"), Color("c8c8c0"), Color("2a2a2e"), Color("b07a1a"), Color("3a5a2a")]
const NEON := LightPlan.NEON

var m: TacMap
var vision: Vision
var fog_tex: Texture2D
var rng := RandomNumberGenerator.new()
var _mats := {}
var _shapes := {}
var _b := {}            ## batches for the floor being built
var lightfield: Texture2D   ## set by the greybox after baking (LightField)
var emitters: Array = []  ## extra light-field sources from dressing: {cell, color, energy, range}


func _init(p_map: TacMap, p_vision: Vision, p_fog: Texture2D) -> void:
	m = p_map
	vision = p_vision
	fog_tex = p_fog
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 10
	cyl.rings = 1
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 7
	sph.rings = 4
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_shapes = {"box": box, "cyl": cyl, "sphere": sph, "quad": quad}


# --- Materials ---------------------------------------------------------------------

func mat(name: String, f: int, cut := true, over := {}) -> ShaderMaterial:
	var key := "%s|%d|%s|%s" % [name, f, cut, str(over)]
	if _mats.has(key):
		return _mats[key]
	var d: Array = LIB[name]
	var extra: Dictionary = (d[6] if d.size() > 6 else {}).duplicate()
	extra.merge(over, true)
	var mt := ShaderMaterial.new()
	if extra.get("alpha", 1.0) < 1.0:
		mt.shader = _alpha_shader()
	else:
		mt.shader = SHADER
	var col: Color = extra.get("color", d[0])
	mt.set_shader_parameter("albedo", Color(col, extra.get("alpha", 1.0)))
	mt.set_shader_parameter("albedo2", d[1])
	mt.set_shader_parameter("pattern", d[2])
	mt.set_shader_parameter("pattern_scale", d[3])
	mt.set_shader_parameter("roughness", d[4])
	mt.set_shader_parameter("metallic", d[5])
	mt.set_shader_parameter("emission", extra.get("emit", col))
	mt.set_shader_parameter("emission_energy", minf(float(extra.get("glow", 0.0)), 1.6))   # keep emitters in hue
	mt.set_shader_parameter("mode", extra.get("mode", 0))
	mt.set_shader_parameter("shell", extra.get("shell", false))
	mt.set_shader_parameter("cuttable", cut)
	mt.set_shader_parameter("fog", fog_tex)
	if lightfield:
		mt.set_shader_parameter("lightfield", lightfield)
	mt.set_shader_parameter("map_size", Vector2(m.w, m.h))
	mt.set_shader_parameter("floor_idx", float(f))
	mt.set_shader_parameter("floors", float(m.floors))
	_mats[key] = mt
	return mt


static var _alpha: Shader
static func _alpha_shader() -> Shader:
	if _alpha == null:
		_alpha = Shader.new()
		_alpha.code = SHADER.code.replace("render_mode cull_disabled;", "render_mode cull_disabled, blend_mix, depth_draw_opaque;") \
			.replace("EMISSION = emit * k;", "EMISSION = emit * k;\n\tALPHA = albedo.a;")
	return _alpha


## Every material the builder made (the greybox sets fog/look parameters on them).
func materials() -> Array:
	return _mats.values()


# --- Batching ----------------------------------------------------------------------

func put(shape: String, mt: Material, xf: Transform3D) -> void:
	var key := "%d,%d|%s|%d" % [int(xf.origin.x) / CHUNK, int(xf.origin.z) / CHUNK, shape, mt.get_instance_id()]
	var b: Dictionary = _b.get_or_add(key, {"shape": shape, "mat": mt, "xf": []})
	b.xf.append(xf)


func box(mt: Material, center: Vector3, size: Vector3, yaw := 0.0) -> void:
	put("box", mt, Transform3D(Basis(Vector3.UP, yaw).scaled_local(size) if yaw != 0.0 else Basis.from_scale(size), center))


func flush(parent: Node3D) -> void:
	for key in _b:
		var b: Dictionary = _b[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var mesh: PrimitiveMesh = _shapes[b.shape].duplicate()
		mesh.material = b.mat
		mm.mesh = mesh
		mm.instance_count = b.xf.size()
		for i in b.xf.size():
			mm.set_instance_transform(i, b.xf[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		parent.add_child(mi)
	_b = {}


# --- Build -------------------------------------------------------------------------

## Builds everything under `root`; returns per-floor nodes.
func build(root: Node3D) -> Array[Node3D]:
	rng.seed = m.seed_value * 31 + 7
	var out: Array[Node3D] = []
	for f in m.floors:
		var fn := Node3D.new()
		fn.name = "floor%d" % f
		root.add_child(fn)
		out.append(fn)
		_floors(f)
		_walls(f)
		_unknown(f)
		_cover(f)
		_stairs(f)
		if f == 0:
			_ground_organic()
			_rocks()
			_street_clutter()
		_roof_clutter(f)
		_facade_dressing(f)
		flush(fn)
	var sky := Node3D.new()
	sky.name = "skyline"
	root.add_child(sky)
	if String(m.params.get("scene", "")) != "badlands":
		_skyline()
	else:
		box(mat("sand", 0, false, {"mode": 2}), Vector3(m.w / 2.0, -0.2, m.h / 2.0), Vector3(m.w + 120, 0.1, m.h + 120))
	flush(sky)
	return out


# --- Floors and ground -------------------------------------------------------------

func _floor_key(f: int, x: int, y: int) -> String:
	var t := m.t(f, x, y)
	match t:
		TacMap.T.VOID, TacMap.T.WALL, TacMap.T.DOOR:
			return ""
		TacMap.T.WATER:
			return ""   # marching squares
		TacMap.T.STAIRS, TacMap.T.ELEVATOR:
			return "floor_metal"
		TacMap.T.ROOF:
			return "roof"
		TacMap.T.BRIDGE:
			return "floor_metal"
		TacMap.T.OUTSIDE:
			var l := m.label(f, x, y)
			if l >= 0 and not m.rooms[l].get("outdoor", false):
				return _room_floor(m.rooms[l])
			match int(m.ground[y * m.w + x]):
				TacMap.G.ASPHALT: return "asphalt"
				TacMap.G.SIDEWALK: return "sidewalk"
				TacMap.G.RAIL: return "rail"
				TacMap.G.DOCK: return "dock"
				TacMap.G.GRASS, TacMap.G.DIRT, TacMap.G.SAND, TacMap.G.GRAVEL: return "concrete" if f > 0 else ""
			return "concrete"
	var l2 := m.label(f, x, y)
	return _room_floor(m.rooms[l2]) if l2 >= 0 else "floor_concrete"


func _room_floor(r: Dictionary) -> String:
	var k: String = r.kind
	for w in ["bar", "club", "lounge", "apartment", "living", "bedroom", "boss", "exec", "study", "vip", "dining", "temple", "shrine", "quarters", "foyer"]:
		if k.contains(w):
			return "floor_wood" if k != "dance_floor" else "floor_tile"
	for w in ["warehouse", "factory", "garage", "storage", "loading", "cargo", "workshop", "dock", "squat", "stash", "shack", "engine", "cage", "parking", "yard", "platform", "quay", "rubble"]:
		if k.contains(w):
			return "floor_concrete"
	for w in ["server", "vault", "armory", "security", "control", "cooling", "evidence", "holding", "panic", "armored"]:
		if k.contains(w):
			return "floor_vault" if k.contains("vault") else "floor_metal"
	for w in ["office", "meeting", "waiting", "recovery", "capsule", "booth"]:
		if k.contains(w):
			return "floor_carpet"
	return "floor_tile"


func _wallish(f: int, x: int, y: int) -> bool:
	if not m.inb(x, y):
		return false
	var t := m.t(f, x, y)
	return t == TacMap.T.WALL or t == TacMap.T.DOOR


## Greedy-meshed floor rectangles. Each rectangle grows half a square into walls beside it, so
## floors on both sides of a wall meet under its centre line (walls are thinner than a square).
func _floors(f: int) -> void:
	var used := PackedByteArray()
	used.resize(m.w * m.h)
	var y0 := f * FH
	for y in m.h:
		for x in m.w:
			if used[y * m.w + x]:
				continue
			var k := _floor_key(f, x, y)
			if k == "":
				continue
			var w := 1
			while x + w < m.w and not used[y * m.w + x + w] and _floor_key(f, x + w, y) == k:
				w += 1
			var h := 1
			var grow := true
			while grow and y + h < m.h:
				for i in w:
					if used[(y + h) * m.w + x + i] or _floor_key(f, x + i, y + h) != k:
						grow = false
						break
				if grow:
					h += 1
			for j in h:
				for i in w:
					used[(y + j) * m.w + x + i] = 1
			var r := Rect2(x, y, w, h)
			r = _grow_into_walls(f, r, Rect2i(x, y, w, h))
			var thick := 0.12
			var top := y0
			if k == "sidewalk":
				top += 0.07   # raised kerb
			box(mat(k, f, f > 0), Vector3(r.get_center().x, top - thick / 2, r.get_center().y), Vector3(r.size.x, thick, r.size.y))
	# A dark slab under every built cell (including walls) so no seam ever shows the void.
	if f > 0:
		for y in m.h:
			for x in m.w:
				if _wallish(f, x, y):
					box(mat("slab", f), Vector3(x + 0.5, y0 - 0.1, y + 0.5), Vector3(1, 0.08, 1))


func _grow_into_walls(f: int, r: Rect2, ri: Rect2i) -> Rect2:
	var left := true
	var right := true
	var up := true
	var down := true
	for j in ri.size.y:
		left = left and _wallish(f, ri.position.x - 1, ri.position.y + j)
		right = right and _wallish(f, ri.end.x, ri.position.y + j)
	for i in ri.size.x:
		up = up and _wallish(f, ri.position.x + i, ri.position.y - 1)
		down = down and _wallish(f, ri.position.x + i, ri.end.y)
	return r.grow_individual(0.5 if left else 0.0, 0.5 if up else 0.0, 0.5 if right else 0.0, 0.5 if down else 0.0)


## Marching squares over a cell mask: a polygon soup (triangles) outlining the mask with 45°
## corners instead of square steps. Vertices are in map xz; `jitter` wobbles edge midpoints.
static func marching(mask: Callable, w: int, h: int, jitter := 0.0, seed_value := 0) -> PackedVector2Array:
	var tris := PackedVector2Array()
	var r := RandomNumberGenerator.new()
	for y in range(-1, h):
		for x in range(-1, w):
			# corners at cell centres: a (x,y) b (x+1,y) c (x+1,y+1) d (x,y+1)
			var a: bool = mask.call(x, y)
			var b: bool = mask.call(x + 1, y)
			var c: bool = mask.call(x + 1, y + 1)
			var d: bool = mask.call(x, y + 1)
			var idx := int(a) | int(b) << 1 | int(c) << 2 | int(d) << 3
			if idx == 0:
				continue
			var o := Vector2(x + 0.5, y + 0.5)
			var pa := o
			var pb := o + Vector2(1, 0)
			var pc := o + Vector2(1, 1)
			var pd := o + Vector2(0, 1)
			var j := func(p: Vector2) -> Vector2:
				if jitter <= 0.0:
					return p
				r.seed = hash(Vector2i(roundi(p.x * 2), roundi(p.y * 2))) + seed_value
				return p + Vector2(r.randf_range(-jitter, jitter), r.randf_range(-jitter, jitter))
			var ab: Vector2 = j.call((pa + pb) / 2)
			var bc: Vector2 = j.call((pb + pc) / 2)
			var cd: Vector2 = j.call((pc + pd) / 2)
			var da: Vector2 = j.call((pd + pa) / 2)
			var poly: Array = []
			match idx:
				15: poly = [pa, pb, pc, pd]
				1: poly = [pa, ab, da]
				2: poly = [ab, pb, bc]
				4: poly = [bc, pc, cd]
				8: poly = [da, cd, pd]
				3: poly = [pa, pb, bc, da]
				6: poly = [ab, pb, pc, cd]
				12: poly = [da, bc, pc, pd]
				9: poly = [pa, ab, cd, pd]
				7: poly = [pa, pb, pc, cd, da]
				11: poly = [pa, pb, bc, cd, pd]
				13: poly = [pa, ab, bc, pc, pd]
				14: poly = [ab, pb, pc, pd, da]
				5: poly = [pa, ab, bc, pc, cd, da]
				10: poly = [ab, pb, bc, cd, pd, da]
			for i in range(1, poly.size() - 1):
				tris.append(poly[0])
				tris.append(poly[i])
				tris.append(poly[i + 1])
	return tris


func _surface(tris: PackedVector2Array, y: float, mt: Material, parent_key := "") -> MeshInstance3D:
	if tris.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in range(0, tris.size(), 3):
		for k in [0, 1, 2, 0, 2, 1]:  # both windings; the downward one is culled
			var p: Vector2 = tris[i + k]
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x, y, p.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mt
	return mi


var _surfaces: Array[MeshInstance3D] = []


## Organic ground (grass, earth, sand, gravel) and water as marching-squares surfaces on top of
## a concrete base, so their outlines don't follow the grid.
func _ground_organic() -> void:
	var gtypes := {TacMap.G.GRASS: "grass", TacMap.G.DIRT: "dirt", TacMap.G.SAND: "sand", TacMap.G.GRAVEL: "gravel"}
	var base := func(x: int, y: int) -> bool:
		return m.inb(x, y) and m.t(0, x, y) != TacMap.T.VOID and _floor_key(0, x, y) == "" and m.t(0, x, y) != TacMap.T.WATER \
			and not (m.t(0, x, y) in [TacMap.T.WALL, TacMap.T.DOOR])
	# base under organic patches (and under fences/rock walls)
	for y in m.h:
		for x in m.w:
			if base.call(x, y) or (m.t(0, x, y) == TacMap.T.WALL and int(m.wall_mat[0][y * m.w + x]) in [3, 4]):
				box(mat("dirt", 0, false), Vector3(x + 0.5, -0.07, y + 0.5), Vector3(1, 0.1, 1))
	var lift := 0.0
	for g in gtypes:
		lift += 0.004
		var tris := marching(func(x: int, y: int) -> bool:
			return m.inb(x, y) and m.t(0, x, y) != TacMap.T.VOID and int(m.ground[y * m.w + x]) == g and m.label(0, x, y) < 0 or \
				(m.inb(x, y) and int(m.ground[y * m.w + x]) == g and m.label(0, x, y) >= 0 and m.rooms[m.label(0, x, y)].get("outdoor", false)), m.w, m.h, 0.22, g)
		var s := _surface(tris, -0.02 + lift, mat(gtypes[g], 0, false))
		if s:
			s.set_meta("floor", 0)
			_surfaces.append(s)
	var wt := marching(func(x: int, y: int) -> bool: return m.inb(x, y) and m.t(0, x, y) == TacMap.T.WATER, m.w, m.h, 0.15, 99)
	var ws := _surface(wt, -0.35, mat("water", 0, false))
	if ws:
		ws.set_meta("floor", 0)
		_surfaces.append(ws)
		# a dark bed under the water
		for y in m.h:
			for x in m.w:
				if m.t(0, x, y) == TacMap.T.WATER:
					box(mat("dark", 0, false), Vector3(x + 0.5, -0.6, y + 0.5), Vector3(1, 0.1, 1))


## The marching-squares meshes made during build (added by the caller to floor 0).
func surfaces() -> Array[MeshInstance3D]:
	return _surfaces


# --- Walls ---------------------------------------------------------------------------

func _wall_kind(f: int, x: int, y: int) -> int:
	## -1 not a wall; else the material index (0 plaster, 1 concrete, 2 steel, 3 fence, 4 rock, 5/6 glass)
	if not m.inb(x, y) or m.t(f, x, y) != TacMap.T.WALL:
		return -1
	return int(m.wall_mat[f][y * m.w + x])


func _exterior(f: int, x: int, y: int) -> bool:
	for d in Nav.DIRS8:
		var n: Vector2i = Vector2i(x, y) + d
		if not m.inb(n.x, n.y) or m.t(f, n.x, n.y) == TacMap.T.VOID or vision._outdoor(f, n.x, n.y):
			return true
	return false


func _line_member(f: int, x: int, y: int) -> bool:
	## Something a wall run connects to: a solid wall, glass, a door.
	if not m.inb(x, y):
		return false
	var t := m.t(f, x, y)
	if t == TacMap.T.DOOR:
		return true
	var k := _wall_kind(f, x, y)
	return k >= 0 and k != 3 and k != 4


func _walls(f: int) -> void:
	var y0 := f * FH
	for horiz in [true, false]:
		var a_n := m.h if horiz else m.w
		var b_n := m.w if horiz else m.h
		for a in a_n:
			var b := 0
			while b < b_n:
				var x := b if horiz else a
				var y := a if horiz else b
				var k := _wall_kind(f, x, y)
				if k < 0 or k == 3 or k == 4 or not _connects(f, x, y, horiz):
					b += 1
					continue
				var glass := k in [5, 6]
				var start := b
				while b < b_n:
					var xx := b if horiz else a
					var yy := a if horiz else b
					var kk := _wall_kind(f, xx, yy)
					if kk < 0 or kk == 3 or kk == 4 or (kk in [5, 6]) != glass or not _connects(f, xx, yy, horiz):
						break
					b += 1
				_run(f, horiz, a, start, b - 1, glass, k)
	# isolated wall cells (pillars) and fences/rock
	for y in m.h:
		for x in m.w:
			var k := _wall_kind(f, x, y)
			if k < 0:
				continue
			if k == 3:
				_fence_cell(f, x, y)
			elif k == 4:
				continue  # rock: _rocks()
			elif not _connects(f, x, y, true) and not _connects(f, x, y, false):
				var mt := mat("wall_concrete", f)
				box(mt, Vector3(x + 0.5, y0 + FH / 2, y + 0.5), Vector3(EXT_T + 0.1, FH, EXT_T + 0.1))
	for d in m.doors:
		if d.floor == f and m.t(f, d.pos.x, d.pos.y) == TacMap.T.DOOR:
			_door_frame(f, d.pos)


func _connects(f: int, x: int, y: int, horiz: bool) -> bool:
	if horiz:
		return _line_member(f, x - 1, y) or _line_member(f, x + 1, y)
	return _line_member(f, x, y - 1) or _line_member(f, x, y + 1)


func _run(f: int, horiz: bool, a: int, b0: int, b1: int, glass: bool, k: int) -> void:
	var y0 := f * FH
	var x0 := b0 if horiz else a
	var y0c := a if horiz else b0
	var ext := false
	for b in range(b0, b1 + 1):
		if _exterior(f, b if horiz else a, a if horiz else b):
			ext = true
	var t := EXT_T if ext else INT_T
	# ends: reach the cell edge where the line continues into a door/window, else just past centre
	var before := Vector2i(b0 - 1, a) if horiz else Vector2i(a, b0 - 1)
	var after := Vector2i(b1 + 1, a) if horiz else Vector2i(a, b1 + 1)
	var s := float(b0) + 0.5 - (0.5 if _line_member(f, before.x, before.y) else t / 2)
	var e := float(b1) + 0.5 + (0.5 if _line_member(f, after.x, after.y) else t / 2)
	var length := e - s
	var mid := (s + e) / 2
	var c := Vector3(mid, 0, a + 0.5) if horiz else Vector3(a + 0.5, 0, mid)
	var size := func(h: float, thick: float) -> Vector3:
		return Vector3(length, h, thick) if horiz else Vector3(thick, h, length)
	if glass:
		# sill, pane, lintel, and mullions at a spacing that ignores the grid
		var sill := 0.32
		var lintel := 1.32
		var gsh := {"shell": true} if ext else {}
		box(mat("wall_concrete" if ext else "wall_int", f, true, gsh), c + Vector3(0, y0 + sill / 2, 0), size.call(sill, t))
		box(mat("wall_concrete" if ext else "wall_int", f, true, gsh), c + Vector3(0, y0 + (lintel + FH) / 2, 0), size.call(FH - lintel, t))
		box(mat("glass", f, true, gsh), c + Vector3(0, y0 + (sill + lintel) / 2, 0), size.call(lintel - sill, 0.05))
		box(mat("frame", f, true, gsh), c + Vector3(0, y0 + sill + 0.02, 0), size.call(0.04, t + 0.06))
		var n := maxi(1, roundi(length / 0.62))
		for i in range(1, n):
			var p := s + length * i / n
			var mc := Vector3(p, 0, a + 0.5) if horiz else Vector3(a + 0.5, 0, p)
			box(mat("frame", f), mc + Vector3(0, y0 + (sill + lintel) / 2, 0), Vector3(0.04, lintel - sill, 0.08) if horiz else Vector3(0.08, lintel - sill, 0.04))
		return
	var name := "wall_int"
	var sh := {"shell": true} if ext else {}
	if ext:
		name = ["wall_plaster", "wall_concrete", "wall_steel", "wall_concrete", "wall_concrete", "wall_concrete", "wall_concrete"][k]
	box(mat(name, f, true, sh), c + Vector3(0, y0 + FH / 2, 0), size.call(FH, t))
	box(mat("skirt", f, true, sh), c + Vector3(0, y0 + 0.06, 0), size.call(0.12, t + 0.04))
	if ext:
		box(mat("cornice", f, true, sh), c + Vector3(0, y0 + FH - 0.04, 0), size.call(0.08, t + 0.1))


func _door_frame(f: int, p: Vector2i) -> void:
	var y0 := f * FH
	var horiz := _line_member(f, p.x - 1, p.y) or _line_member(f, p.x + 1, p.y) or not (_line_member(f, p.x, p.y - 1) or _line_member(f, p.x, p.y + 1))
	var ext := _exterior(f, p.x, p.y)
	var t := EXT_T if ext else INT_T
	var c := Vector3(p.x + 0.5, y0, p.y + 0.5)
	var head := 1.15
	var lintel := Vector3(1, FH - head, t) if horiz else Vector3(t, FH - head, 1)
	var dsh := {"shell": true} if ext else {}
	box(mat("wall_concrete" if ext else "wall_int", f, true, dsh), c + Vector3(0, head + (FH - head) / 2, 0), lintel)
	for side in [-1, 1]:
		var off := Vector3(side * 0.47, 0, 0) if horiz else Vector3(0, 0, side * 0.47)
		box(mat("frame", f), c + off + Vector3(0, head / 2, 0), Vector3(0.06, head, t + 0.04) if horiz else Vector3(t + 0.04, head, 0.06))
	box(mat("frame", f), c + Vector3(0, head, 0), Vector3(1, 0.05, t + 0.04) if horiz else Vector3(t + 0.04, 0.05, 1))


func _fence_cell(f: int, x: int, y: int) -> void:
	var y0 := f * FH
	var horiz := _wall_kind(f, x - 1, y) == 3 or _wall_kind(f, x + 1, y) == 3
	var c := Vector3(x + 0.5, y0, y + 0.5)
	box(mat("fence", f, false), c + Vector3(0, 0.55, 0), Vector3(1, 1.1, 0.03) if horiz else Vector3(0.03, 1.1, 1))
	box(mat("post", f, false), c + Vector3(0, 1.1, 0), Vector3(1, 0.04, 0.05) if horiz else Vector3(0.05, 0.04, 1))
	if (x + y) % 2 == 0:
		put("cyl", mat("post", f, false), Transform3D(Basis.from_scale(Vector3(0.06, 1.15, 0.06)), c + Vector3(0, 0.575, 0)))


## Doors' leaves are dynamic (open/locked); the greybox draws them. This returns their placement.
func door_leaf(d: Dictionary) -> Dictionary:
	var p: Vector2i = d.pos
	var f: int = d.floor
	var horiz := _line_member(f, p.x - 1, p.y) or _line_member(f, p.x + 1, p.y) or not (_line_member(f, p.x, p.y - 1) or _line_member(f, p.x, p.y + 1))
	return {"center": Vector3(p.x + 0.5, f * FH + 0.575, p.y + 0.5), "horiz": horiz}


# --- Unknown interiors -----------------------------------------------------------------

func _unknown(f: int) -> void:
	## Unknown interiors: one marching-squares surface just under the cutaway height, drawn as a
	## dark hologram (world.gdshader mode 1); it disappears cell by cell as the squad sees inside.
	var tris := marching(func(x: int, y: int) -> bool:
		if not m.inb(x, y):
			return false
		var t := m.t(f, x, y)
		return t != TacMap.T.VOID and not vision._outdoor(f, x, y) and not (t in [TacMap.T.WALL, TacMap.T.DOOR] and _exterior(f, x, y)), m.w, m.h)
	var s := _surface(tris, f * FH + 0.7, mat("unknown", f))
	if s:
		s.set_meta("floor", f)
		_surfaces.append(s)


# --- Vertical links ----------------------------------------------------------------------

func _stairs(f: int) -> void:
	for v in m.verticals:
		if f < v.from_floor or f >= v.to_floor:
			continue
		var p: Vector2i = v.pos
		var y0 := f * FH
		if v.type == "elevator":
			box(mat("frame", f), Vector3(p.x + 0.5, y0 + FH / 2, p.y + 0.5), Vector3(0.8, FH, 0.06))
			box(mat("steel", f, true, {"glow": 0.8, "emit": Color("39f0a0")}), Vector3(p.x + 0.5, y0 + 0.6, p.y + 0.12), Vector3(0.08, 0.12, 0.02))
			continue
		# 7 steps climbing along whichever axis has floor at both ends
		var along_x := m.walkable(f, p + Vector2i(-1, 0)) or m.walkable(f, p + Vector2i(1, 0))
		for i in 7:
			var h := FH * (i + 1) / 7.0
			var off := -0.5 + (i + 0.5) / 7.0
			var c := Vector3(p.x + 0.5 + (off if along_x else 0.0), y0 + h / 2, p.y + 0.5 + (0.0 if along_x else off))
			box(mat("stairs", f), c, Vector3(1.0 / 7.0, h, 0.9) if along_x else Vector3(0.9, h, 1.0 / 7.0))
	for c in m.connectors:
		var a: Vector3i = c.a
		var b: Vector3i = c.b
		if a.z != f:
			continue
		# ladder: two rails and rungs up the outside
		var top := b.z * FH
		var base := a.z * FH
		var cpos := Vector3(a.x + 0.5, (top + base) / 2, a.y + 0.5)
		for side in [-0.18, 0.18]:
			box(mat("post", f, false), cpos + Vector3(side, 0, 0), Vector3(0.04, top - base + 0.4, 0.04))
		for i in int((top - base) / 0.18):
			box(mat("post", f, false), Vector3(cpos.x, base + 0.15 + i * 0.18, cpos.z), Vector3(0.36, 0.025, 0.03))


# --- Cover and props ------------------------------------------------------------------

func _jit(seed_value: int, amt: float) -> float:
	rng.seed = seed_value
	return rng.randf_range(-amt, amt)


func _cover(f: int) -> void:
	var y0 := f * FH
	var props := {}   # prop id → [cells]
	for c in m.cover:
		if c.floor != f:
			continue
		if int(c.get("prop", -1)) >= 0:
			props.get_or_add(int(c.prop) * 10 + f, []).append(c)
			continue
		var h0 := hash(Vector3i(c.pos.x, c.pos.y, f))
		var p := Vector3(c.pos.x + 0.5 + _jit(h0, 0.08), y0, c.pos.y + 0.5 + _jit(h0 + 1, 0.08))
		_piece(String(c.kind), p, _jit(h0 + 2, 0.12), f, h0)
	for k in props:
		var cells: Array = props[k]
		var r := Rect2(cells[0].pos.x, cells[0].pos.y, 1, 1)
		for c in cells:
			r = r.expand(Vector2(c.pos.x, c.pos.y)).expand(Vector2(c.pos.x + 1, c.pos.y + 1))
		var h0 := hash(k)
		_multi(String(cells[0].kind), r, f, h0)


## One-square pieces. `p` is the jittered base centre; `yaw` a small deterministic turn.
func _piece(kind: String, p: Vector3, yaw: float, f: int, h0: int) -> void:
	var W := mat("wood", f, false)
	var S := mat("steel", f, false)
	var D := mat("dark", f, false)
	match kind:
		"desk", "table", "reception", "stall", "kiosk":
			var top := 0.38 if kind != "reception" else 0.5
			box(W if kind != "desk" else mat("dark", f, false), p + Vector3(0, top, 0), Vector3(0.8, 0.05, 0.55), yaw)
			if kind == "reception" or kind == "kiosk" or kind == "stall":
				box(W, p + Vector3(0, top / 2, 0), Vector3(0.78, top, 0.5), yaw)
				if kind == "stall":
					box(mat("fabric", f, false, {"color": NEON[h0 % NEON.size()].darkened(0.5)}), p + Vector3(0, 0.95, 0), Vector3(0.95, 0.04, 0.8), yaw)
			else:
				for sx in [-0.35, 0.35]:
					for sz in [-0.22, 0.22]:
						box(D, p + Vector3(sx, top / 2, sz).rotated(Vector3.UP, yaw), Vector3(0.04, top, 0.04), yaw)
			if kind == "desk":
				box(mat("dark", f, false, {"glow": 1.2, "emit": Color("4fd8ff")}), p + Vector3(0, top + 0.12, -0.1).rotated(Vector3.UP, yaw), Vector3(0.3, 0.2, 0.02), yaw)
		"sofa", "bed", "bench", "pew", "seat", "chair":
			var mt := mat("fabric", f, false) if kind in ["sofa", "bed"] else (W if kind in ["pew", "seat"] else S)
			var w := 0.85 if kind != "seat" and kind != "chair" else 0.4
			box(mt, p + Vector3(0, 0.12, 0), Vector3(w, 0.24, 0.5), yaw)
			if kind != "bed" and kind != "bench":
				box(mt, p + Vector3(0, 0.32, -0.21).rotated(Vector3.UP, yaw), Vector3(w, 0.4, 0.1), yaw)
		"planter", "tree":
			box(mat("stone", f, false), p + Vector3(0, 0.15, 0), Vector3(0.6, 0.3, 0.6), yaw)
			var r := 0.5 if kind == "planter" else 0.9
			put("sphere", mat("plant", f, false), Transform3D(Basis.from_scale(Vector3(r, r * 0.8, r)), p + Vector3(0, 0.3 + r * 0.4 + (0.6 if kind == "tree" else 0.0), 0)))
			if kind == "tree":
				put("cyl", W, Transform3D(Basis.from_scale(Vector3(0.12, 0.8, 0.12)), p + Vector3(0, 0.5, 0)))
		"pillar":
			put("cyl", mat("concrete_prop", f), Transform3D(Basis.from_scale(Vector3(0.5, FH, 0.5)), p + Vector3(0, FH / 2, 0)))
		"cabinet", "locker", "shelf", "rack", "fridge", "safe", "machine", "lift":
			var h: float = {"cabinet": 0.5, "locker": 0.95, "shelf": 0.9, "rack": 0.95, "fridge": 0.95, "safe": 0.5, "machine": 0.8, "lift": 0.3}[kind]
			box(S, p + Vector3(0, h / 2, 0), Vector3(0.7, h, 0.45), yaw)
			if kind == "rack":
				for i in 4:
					box(mat("dark", f, false, {"glow": 1.5, "emit": [Color("39f0a0"), Color("4fd8ff")][i % 2]}), p + Vector3(0, 0.2 + i * 0.2, 0.23).rotated(Vector3.UP, yaw), Vector3(0.5, 0.02, 0.01), yaw)
		"vending":
			box(S, p + Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.45), yaw)
			box(mat("dark", f, false, {"glow": 2.0, "emit": NEON[h0 % NEON.size()]}), p + Vector3(0, 0.5, 0.23).rotated(Vector3.UP, yaw), Vector3(0.5, 0.6, 0.01), yaw)
		"console":
			box(S, p + Vector3(0, 0.22, 0), Vector3(0.75, 0.44, 0.45), yaw)
			box(mat("dark", f, false, {"glow": 1.8, "emit": Color("4fd8ff")}), p + Vector3(0, 0.46, 0), Vector3(0.6, 0.02, 0.35), yaw)
		"crate", "pallet":
			var s := 0.62 if kind == "crate" else 0.8
			var h2 := 0.6 if kind == "crate" else 0.12
			box(W, p + Vector3(0, h2 / 2, 0), Vector3(s, h2, s), yaw * 3)
			if kind == "pallet":
				box(W, p + Vector3(0.05, 0.12 + 0.2, 0), Vector3(0.55, 0.4, 0.55), yaw * 5)
		"barrel", "fuel_barrel":
			var mt2 := S if kind == "barrel" else mat("steel", f, false, {"color": Color("b8481c"), "glow": 0.35, "emit": Color("ff6a1a")})
			put("cyl", mt2, Transform3D(Basis.from_scale(Vector3(0.42, 0.62, 0.42)), p + Vector3(0, 0.31, 0)))
			if kind == "barrel" and h0 % 2 == 0:
				put("cyl", mt2, Transform3D(Basis.from_scale(Vector3(0.42, 0.62, 0.42)), p + Vector3(0.28, 0.31, 0.22)))
		"barrier", "sandbags", "rubble":
			if kind == "sandbags":
				for i in 3:
					put("sphere", mat("stone", f, false, {"color": Color("6a5d45")}), Transform3D(Basis.from_scale(Vector3(0.45, 0.22, 0.35)), p + Vector3(-0.28 + i * 0.28, 0.12, 0).rotated(Vector3.UP, yaw)))
					put("sphere", mat("stone", f, false, {"color": Color("6a5d45")}), Transform3D(Basis.from_scale(Vector3(0.45, 0.22, 0.35)), p + Vector3(-0.14 + i * 0.28, 0.3, 0).rotated(Vector3.UP, yaw)))
			elif kind == "rubble":
				for i in 4:
					rng.seed = h0 + i
					put("sphere", mat("concrete_prop", f, false), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(rng.randf_range(0.25, 0.5), rng.randf_range(0.15, 0.35), rng.randf_range(0.25, 0.5))), p + Vector3(rng.randf_range(-0.3, 0.3), 0.1, rng.randf_range(-0.3, 0.3))))
			else:
				box(mat("concrete_prop", f, false), p + Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.4), yaw)
				box(mat("concrete_prop", f, false), p + Vector3(0, 0.42, 0), Vector3(0.9, 0.26, 0.2), yaw)
				box(mat("steel", f, false, {"color": Color("c8a020")}), p + Vector3(0, 0.5, 0), Vector3(0.92, 0.05, 0.22), yaw)
		"boulder":
			for i in 3:
				rng.seed = h0 + i
				put("sphere", mat("rock", f, false), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(rng.randf_range(0.5, 0.9), rng.randf_range(0.4, 0.7), rng.randf_range(0.5, 0.9))), p + Vector3(rng.randf_range(-0.2, 0.2), 0.2, rng.randf_range(-0.2, 0.2))))
		"transformer":
			box(S, p + Vector3(0, 0.4, 0), Vector3(0.7, 0.8, 0.6), yaw)
			for i in 4:
				box(D, p + Vector3(-0.27 + i * 0.18, 0.4, 0.32).rotated(Vector3.UP, yaw), Vector3(0.03, 0.7, 0.06), yaw)
			box(mat("dark", f, false, {"glow": 2.5, "emit": Color("6fb8ff")}), p + Vector3(0, 0.82, 0), Vector3(0.5, 0.03, 0.4), yaw)
		"ac_unit", "vent":
			box(S, p + Vector3(0, 0.22, 0), Vector3(0.6, 0.44, 0.5), yaw)
			put("cyl", D, Transform3D(Basis.from_scale(Vector3(0.36, 0.02, 0.36)), p + Vector3(0, 0.45, 0)))
		"dumpster":
			box(mat("steel", f, false, {"color": Color("2a4a3a")}), p + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.6), yaw)
			box(D, p + Vector3(0, 0.63, -0.02), Vector3(0.92, 0.04, 0.64), yaw + 0.1)
		"crane_leg":
			box(mat("steel", f, false, {"color": Color("b08020")}), p + Vector3(0, 2.0, 0), Vector3(0.5, 4.0, 0.5))
		_:
			box(mat("concrete_prop", f, false), p + Vector3(0, 0.25, 0), Vector3(0.7, 0.5, 0.7), yaw)


## Multi-square props (cars, wrecks, containers, freight cars, dumpsters) drawn once over their bounds.
func _multi(kind: String, r: Rect2, f: int, h0: int) -> void:
	var y0 := f * FH
	var c := Vector3(r.get_center().x, y0, r.get_center().y)
	var long_x := r.size.x >= r.size.y
	var L := maxf(r.size.x, r.size.y)
	var Wd := minf(r.size.x, r.size.y)
	var yaw := 0.0 if long_x else PI / 2
	rng.seed = h0
	yaw += rng.randf_range(-0.06, 0.06)
	match kind:
		"car", "wreck":
			var paint: Color = PAINT[h0 % PAINT.size()] if kind == "car" else Color("3a2a22")
			var body := mat("steel", f, false, {"color": paint})
			var len2 := L * 0.86
			box(body, c + Vector3(0, 0.22, 0), Vector3(len2, 0.26, Wd * 0.78), yaw)
			box(mat("glass", f, false, {"color": Color("0e1820"), "alpha": 0.85}), c + Vector3(0, 0.44, 0) + Vector3(-0.05 * L, 0, 0).rotated(Vector3.UP, yaw), Vector3(len2 * 0.5, 0.2, Wd * 0.68), yaw)
			for s in [-1, 1]:
				for e in [-1, 1]:
					put("cyl", mat("dark", f, false), Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(0.28, 0.12, 0.28)), c + Vector3(e * len2 * 0.33, 0.12, s * Wd * 0.38).rotated(Vector3.UP, yaw)))
			if kind == "car":
				for s in [-1, 1]:
					box(mat("dark", f, false, {"glow": 3.0, "emit": Color("ff2030")}), c + Vector3(-len2 / 2, 0.27, s * Wd * 0.28).rotated(Vector3.UP, yaw), Vector3(0.02, 0.05, 0.1), yaw)
					box(mat("dark", f, false, {"glow": 2.0, "emit": Color("fff0d0")}), c + Vector3(len2 / 2, 0.25, s * Wd * 0.28).rotated(Vector3.UP, yaw), Vector3(0.02, 0.05, 0.1), yaw)
		"container", "freight_car":
			var col: Color = [Color("6a3428"), Color("284a6a"), Color("6a6028"), Color("2a5a3a"), Color("5a5a5e")][h0 % 5]
			var h := 1.25 if kind == "container" else 1.3
			box(mat("container", f, false, {"color": col}), c + Vector3(0, h / 2 + (0.2 if kind == "freight_car" else 0.0), 0), Vector3(L * 0.97, h, Wd * 0.92), yaw)
			if kind == "freight_car":
				box(mat("dark", f, false), c + Vector3(0, 0.1, 0), Vector3(L * 0.9, 0.2, Wd * 0.6), yaw)
		_:
			_piece(kind, c, yaw, f, h0)


# --- Off-grid clutter --------------------------------------------------------------------

func _street_clutter() -> void:
	rng.seed = m.seed_value * 977
	var D := mat("dark", 0, false)
	var count := int(m.w * m.h * 0.035)
	for i in count:
		var p := Vector2(rng.randf_range(0, m.w), rng.randf_range(0, m.h))
		var c := Vector2i(int(p.x), int(p.y))
		if not m.inb(c.x, c.y) or m.t(0, c.x, c.y) != TacMap.T.OUTSIDE or m.has_cover_at(0, c):
			continue
		var roll := rng.randf()
		if roll < 0.4:   # trash bags in little heaps
			for j in rng.randi_range(1, 3):
				put("sphere", mat("dark", 0, false, {"color": Color("101418")}), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(0.28, 0.22, 0.24)), Vector3(p.x + rng.randf_range(-0.2, 0.2), 0.09, p.y + rng.randf_range(-0.2, 0.2))))
		elif roll < 0.8:  # paper, flyers
			box(mat("wall_int", 0, false, {"color": Color("3a3632")}), Vector3(p.x, 0.012, p.y), Vector3(0.14, 0.004, 0.2), rng.randf() * TAU)
		else:             # manhole / drain
			put("cyl", D, Transform3D(Basis.from_scale(Vector3(0.4, 0.01, 0.4)), Vector3(p.x, 0.005, p.y)))
	# overhead cables between facing exterior walls across streets
	for i in int(m.w * m.h / 160):
		var x := rng.randi_range(1, m.w - 2)
		var y := rng.randi_range(1, m.h - 2)
		if m.t(0, x, y) != TacMap.T.OUTSIDE:
			continue
		var horiz := rng.randf() < 0.5
		var d := Vector2i(1, 0) if horiz else Vector2i(0, 1)
		var a := Vector2i(x, y)
		var b := Vector2i(x, y)
		while m.inb(a.x, a.y) and m.t(0, a.x, a.y) == TacMap.T.OUTSIDE:
			a -= d
		while m.inb(b.x, b.y) and m.t(0, b.x, b.y) == TacMap.T.OUTSIDE:
			b += d
		if not (m.inb(a.x, a.y) and m.inb(b.x, b.y)) or m.t(0, a.x, a.y) != TacMap.T.WALL or m.t(0, b.x, b.y) != TacMap.T.WALL:
			continue
		var span := Vector2(b - a).length()
		if span < 4 or span > 18:
			continue
		var h := FH * rng.randf_range(0.85, 1.6)
		var mid := Vector2(a + b) / 2.0 + Vector2(0.5, 0.5)
		for k in rng.randi_range(1, 3):
			box(D, Vector3(mid.x, h - 0.15 - k * 0.07, mid.y), Vector3(span, 0.015, 0.015) if horiz else Vector3(0.015, 0.015, span))


## Roof clutter: AC units, vents, water tanks and antennas scattered off-grid on ROOF tiles,
## with a parapet around roof edges.
func _roof_clutter(f: int) -> void:
	var y0 := f * FH
	var S := mat("steel", f)
	for y in m.h:
		for x in m.w:
			if m.t(f, x, y) != TacMap.T.ROOF:
				continue
			for d in MapGen.DIRS:
				var n: Vector2i = Vector2i(x, y) + d
				if not m.inb(n.x, n.y) or m.t(f, n.x, n.y) in [TacMap.T.VOID, TacMap.T.OUTSIDE]:
					var off := Vector3(d.x, 0, d.y) * 0.44
					box(mat("cornice", f, true, {"shell": true}), Vector3(x + 0.5, y0 + 0.14, y + 0.5) + off, Vector3(1.0 if d.x == 0 else 0.12, 0.28, 1.0 if d.y == 0 else 0.12))
			rng.seed = hash(Vector3i(x, y, f)) + 5
			var roll := rng.randf()
			var p := Vector3(x + rng.randf_range(0.2, 0.8), y0, y + rng.randf_range(0.2, 0.8))
			if m.has_cover_at(f, Vector2i(x, y)):
				continue
			if roll < 0.05:
				put("cyl", S, Transform3D(Basis.from_scale(Vector3(0.7, 0.8, 0.7)), p + Vector3(0, 0.5, 0)))
				for lx in [-0.2, 0.2]:
					box(S, p + Vector3(lx, 0.05, 0), Vector3(0.05, 0.1, 0.6))
			elif roll < 0.1:
				box(mat("dark", f), p + Vector3(0, 0.45, 0), Vector3(0.03, 0.9, 0.03))
				box(mat("dark", f, true, {"glow": 1.2, "emit": Color("ff2020")}), p + Vector3(0, 0.92, 0), Vector3(0.06, 0.06, 0.06))
			elif roll < 0.16:
				box(S, p + Vector3(0, 0.12, 0), Vector3(0.3, 0.24, 0.3), rng.randf())


## Facades: AC units and pipes on exterior walls, posters, and tall vertical neon boards.
func _facade_dressing(f: int) -> void:
	var y0 := f * FH
	for y in m.h:
		for x in m.w:
			if not (_wall_kind(f, x, y) in [0, 1, 2]):
				continue
			for d in MapGen.DIRS:
				var n: Vector2i = Vector2i(x, y) + d
				if not m.inb(n.x, n.y):
					continue
				var nt := m.t(f, n.x, n.y)
				if not ((f == 0 and nt == TacMap.T.OUTSIDE and m.label(f, n.x, n.y) < 0) or (f > 0 and nt == TacMap.T.VOID)):
					continue
				rng.seed = hash(Vector3i(x, y, f)) * 3 + d.x * 7 + d.y * 13
				var roll := rng.randf()
				var out := Vector3(d.x, 0, d.y)
				var along := rng.randf_range(-0.3, 0.3)
				var side := Vector3(-d.y, 0, d.x) * along
				var face := Vector3(x + 0.5, y0, y + 0.5) + out * (EXT_T / 2 + 0.01) + side
				if roll < 0.06 and f > 0 or (roll < 0.03):
					box(mat("steel", f, true, {"shell": true}), face + out * 0.14 + Vector3(0, rng.randf_range(0.8, 1.3), 0), Vector3(0.36, 0.26, 0.26))
				elif roll < 0.1:
					var col: Color = NEON[rng.randi() % NEON.size()]
					box(mat("dark", f, true, {"glow": 0.9, "emit": col.darkened(0.3), "color": col.darkened(0.6), "shell": true}), face + out * 0.005 + Vector3(0, rng.randf_range(0.4, 0.8), 0), Vector3(0.36 if d.x == 0 else 0.01, 0.46, 0.01 if d.x == 0 else 0.36))
				elif roll < 0.15:
					# blade sign sticking out of the facade, with light spill
					var col2: Color = NEON[rng.randi() % NEON.size()]
					var bl := Vector3(0.42, FH * 0.75, 0.06) if d.x != 0 else Vector3(0.06, FH * 0.75, 0.42)
					box(mat("dark", f, true, {"glow": 5.0, "emit": col2, "shell": true}), face + out * 0.3 + Vector3(0, FH * 0.55 + 0.2, 0), bl)
					emitters.append({"cell": Vector3i(n.x, n.y, 0), "color": col2, "energy": 1.4, "range": 5.0, "out": Vector2i.ZERO})
				elif roll < 0.2 and f == 0:
					# awning over a lit shop window
					var col3: Color = [Color("ffb070"), Color("ff6b9a"), Color("70e0ff")][rng.randi() % 3]
					var wide := Vector3(0.95, 0.04, 0.5) if d.x == 0 else Vector3(0.5, 0.04, 0.95)
					box(mat("fabric", f, true, {"color": NEON[rng.randi() % NEON.size()].darkened(0.55), "shell": true}), face + out * 0.25 + Vector3(0, 1.22, 0), wide)
					box(mat("dark", f, true, {"glow": 4.0, "emit": col3, "shell": true}), face + out * 0.48 + Vector3(0, 1.2, 0), Vector3(0.95, 0.02, 0.02) if d.x == 0 else Vector3(0.02, 0.02, 0.95))
					box(mat("dark", f, true, {"glow": 1.6, "emit": col3, "shell": true}), face + out * 0.01 + Vector3(0, 0.62, 0), Vector3(0.7, 0.6, 0.01) if d.x == 0 else Vector3(0.01, 0.6, 0.7))
					emitters.append({"cell": Vector3i(n.x, n.y, 0), "color": col3, "energy": 1.1, "range": 4.0, "out": Vector2i.ZERO})
				elif roll < 0.16:
					box(mat("post", f, true, {"shell": true}), face + out * 0.05 + Vector3(0, FH / 2, 0), Vector3(0.05, FH, 0.05))


# --- Skyline -----------------------------------------------------------------------------

## Towers beyond the map edges with lit windows, rooftop beacons, and a far ground plane.
func _skyline() -> void:
	rng.seed = m.seed_value * 13 + 1
	var far := mat("far_ground", 0, false)
	var margin := 60.0
	box(far, Vector3(m.w / 2.0, -0.2, m.h / 2.0), Vector3(m.w + margin * 2, 0.1, m.h + margin * 2))
	var T := mat("tower", 0, false)
	var top := mat("tower_top", 0, false)
	var placed: Array[Rect2] = []
	for i in 140:
		var side := rng.randi() % 4
		var dist := rng.randf_range(3.0, 45.0)
		var w := rng.randf_range(4.0, 12.0)
		var d := rng.randf_range(4.0, 12.0)
		var p := Vector2.ZERO
		match side:
			0: p = Vector2(rng.randf_range(-margin, m.w + margin), -dist - d / 2)
			1: p = Vector2(rng.randf_range(-margin, m.w + margin), m.h + dist + d / 2)
			2: p = Vector2(-dist - w / 2, rng.randf_range(-margin, m.h + margin))
			3: p = Vector2(m.w + dist + w / 2, rng.randf_range(-margin, m.h + margin))
		var r := Rect2(p - Vector2(w, d) / 2, Vector2(w, d))
		if placed.any(func(q: Rect2) -> bool: return q.grow(0.8).intersects(r)):
			continue
		placed.append(r)
		var h := rng.randf_range(6.0, 14.0) + dist * rng.randf_range(0.3, 0.9)
		box(T, Vector3(p.x, h / 2 - 0.2, p.y), Vector3(w, h, d))
		box(top, Vector3(p.x, h - 0.15, p.y), Vector3(w * 0.7, 0.4, d * 0.7))
		if rng.randf() < 0.35:
			box(mat("dark", 0, false, {"glow": 1.2, "emit": Color("ff2020"), "mode": 2}), Vector3(p.x, h + 0.1, p.y), Vector3(0.08, 0.08, 0.08))
		if rng.randf() < 0.3:   # a billboard: a big emissive panel on the face toward the map
			var col: Color = NEON[rng.randi() % NEON.size()]
			var toward := Vector2(m.w / 2.0, m.h / 2.0) - p
			var face := Vector3(signf(toward.x) * (w / 2 + 0.05), 0, 0) if absf(toward.x) > absf(toward.y) else Vector3(0, 0, signf(toward.y) * (d / 2 + 0.05))
			var bw := minf(w, d) * 0.6
			box(mat("dark", 0, false, {"glow": 1.8, "emit": col, "mode": 2}), Vector3(p.x, h * rng.randf_range(0.45, 0.8), p.y) + face,
				Vector3(0.05, bw * 0.5, bw) if face.x != 0 else Vector3(bw, bw * 0.5, 0.05))


# --- Rock ----------------------------------------------------------------------------------

## Rock walls (material 4) become heaps of jittered boulders: 2-3 per square, overlapping.
func _rocks() -> void:
	for y in m.h:
		for x in m.w:
			if _wall_kind(0, x, y) != 4:
				continue
			for i in 3:
				rng.seed = hash(Vector2i(x, y)) + i
				var s := Vector3(rng.randf_range(0.8, 1.5), rng.randf_range(0.7, 1.9), rng.randf_range(0.8, 1.5))
				var p := Vector3(x + rng.randf_range(0.2, 0.8), s.y * 0.35, y + rng.randf_range(0.2, 0.8))
				put("sphere", mat("rock", 0, false), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)).scaled_local(s), p))
