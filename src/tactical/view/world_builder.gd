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
const WALL_GAP := 0.012   # walls stop just under the next floor: tops at the floor's own height z-fought (r8 review: white roof dashes)
const SHADER := preload("res://src/tactical/view/world.gdshader")

## name → [albedo, albedo2, pattern, scale, rough, metal, extra{}]
const LIB := {
	"asphalt": [Color("1c2028"), Color("0e0f12"), 3, 0.6, 0.55, 0.0],
	"sidewalk": [Color("3b3e43"), Color("25272b"), 4, 1.6, 0.7, 0.0],
	"concrete": [Color("33363a"), Color("232528"), 1, 0.37, 0.8, 0.0],
	"gravel": [Color("3b3833"), Color("2a2824"), 5, 2.0, 0.95, 0.0],
	"dirt": [Color("5a4836"), Color("3e3226"), 5, 0.8, 0.95, 0.0],   # r7 review: lots read as voids when darker
	"grass": [Color("3e6a30"), Color("54722c"), 5, 1.1, 0.95, 0.0, {"fog_hue": 0.6}],   # yellow-green so moonlight leaves it green, not teal; keeps its hue out of sight
	"sand": [Color("9a8670"), Color("6a5644"), 5, 0.7, 0.95, 0.0],   # r8 review: wider tone gap so the badlands floor isn't one flat colour
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
	"roof": [Color("3a4252"), Color("232833"), 4, 0.5, 0.85, 0.0, {"shell": true, "dry": true}],
	"stairs": [Color("4a5058"), Color("2a2e33"), 6, 3.0, 0.5, 0.3],
	"wall_concrete": [Color("5a5f66"), Color("34373c"), 7, 1.0, 0.85, 0.0],
	"wall_plaster": [Color("6e675d"), Color("47423b"), 7, 1.0, 0.9, 0.0],
	"wall_steel": [Color("46505b"), Color("2a3038"), 8, 1.0, 0.45, 0.5],
	"wall_int": [Color("7a756e"), Color("5d5952"), 0, 1.0, 0.9, 0.0],
	"skirt": [Color("1d1f23"), Color("1d1f23"), 0, 1.0, 0.7, 0.2],
	"cornice": [Color("4e5c78"), Color("4e5c78"), 0, 1.0, 0.7, 0.2],
	"frame": [Color("1b1d21"), Color("1b1d21"), 0, 1.0, 0.35, 0.7],
	"door": [Color("2e3239"), Color("2e3239"), 8, 1.5, 0.45, 0.5],
	"glass": [Color("7fc8e8"), Color("7fc8e8"), 0, 1.0, 0.05, 0.0, {"alpha": 0.24, "glow": 0.25}],
	"fence": [Color("7a8a7a"), Color("7a8a7a"), 0, 1.0, 0.4, 0.7, {"alpha": 0.3}],
	"post": [Color("3a4048"), Color("3a4048"), 0, 1.0, 0.4, 0.7],
	"rock": [Color("5a4a40"), Color("463a32"), 5, 1.5, 0.95, 0.0, {"flat": true}],
	"nature": [Color.WHITE, Color.WHITE, 0, 1.0, 0.92, 0.0],
	"mesa": [Color("b06a40"), Color("8a4a2c"), 5, 0.18, 0.95, 0.0, {"flat": true, "mode": 2, "offmap": true}],   # imported models: their own texture, tinted
	"unknown": [Color("1c212c"), Color("1c212c"), 0, 1.0, 0.95, 0.0, {"mode": 1, "glow": 0.5, "emit": Color("141a26")}],
	"wood": [Color("4e3a28"), Color("2e2216"), 2, 2.0, 0.8, 0.0],
	"steel": [Color("56606a"), Color("3a424a"), 0, 1.0, 0.4, 0.55],
	"concrete_prop": [Color("6a6e73"), Color("4a4d51"), 0, 2.0, 0.85, 0.0],
	"stone": [Color("67625b"), Color("4a4640"), 5, 2.0, 0.9, 0.0],
	"fabric": [Color("3b3048"), Color("3b3048"), 0, 6.0, 0.95, 0.0],
	"plant": [Color("4a6a2c"), Color("3a6a24"), 5, 3.0, 0.9, 0.0, {"fog_hue": 0.7}],
	"dark": [Color("141619"), Color("141619"), 0, 1.0, 0.6, 0.3],
	"container": [Color("6a3428"), Color("4a2418"), 8, 1.0, 0.6, 0.4],
	"tower": [Color("14171c"), Color("0e1014"), 9, 0.55, 0.8, 0.2, {"mode": 2}],
	"tower_top": [Color("101216"), Color("101216"), 0, 1.0, 0.8, 0.2, {"mode": 2}],
	"far_ground": [Color("111316"), Color("0b0c0e"), 0, 0.3, 0.9, 0.0, {"mode": 2}],
	"bedrock": [Color("16181a"), Color("0d0e10"), 5, 0.6, 0.95, 0.0, {"shell": true}],   # undercity: the solid ground between tunnels
	"atrium": [Color("e8e8e4"), Color("d0d0cc"), 0, 1.0, 0.3, 0.0, {"mode": 2}],          # arcology: the walls around the concourse
}
const PAINT := [Color("8a1c2a"), Color("1c3a5a"), Color("9a9a92"), Color("2a2a2e"), Color("b07a1a"), Color("3a5a2a")]
const NEON := LightPlan.NEON

var m: TacMap
var vision: Vision
var fog_tex: Texture2D
var rng := RandomNumberGenerator.new()
var _mats := {}
var _shapes := {}
var _b := {}            ## batches for the floor being built
var natural := false     ## open-country scene: modelled rocks, plants, mesas instead of a skyline
var tag: Variant = null ## while set, instances added by put() are recorded under it (cover cells)
var _tagged := {}       ## Vector3i cell → [[batch, index]] so a destroyed piece can be hidden
var lightfield: Texture2D   ## set by the greybox after baking (LightField)
var _sid_grid := PackedInt32Array()   ## building structure id per square (-1 none): per-building looks
var neon: Array = []    ## this scene's sign colours (SceneTheme), for facade dressing and the skyline
var emitters: Array = []  ## extra light-field sources from dressing: {cell, color, energy, range}
var _sp_looks := {}      ## structure id → its set-piece look (SetPieceDressing.look), cached
var signs := 1.0        ## neon sign density (SceneTheme.signs: the district's look)
var grime := 1.0        ## street litter and cables (SceneTheme.grime)
var street := 0            ## the street-level floor (TacMap.street: 0 unless the map has basements)
var gy := 0.0           ## its height (street * FH): street dressing stands on it, the skyline too
var y_off := 0.0        ## added to every put() while set: street dressing written from y 0 lifted to gy


func _init(p_map: TacMap, p_vision: Vision, p_fog: Texture2D) -> void:
	m = p_map
	neon = SceneTheme.colors(m, "neon", NEON)
	signs = SceneTheme.signs(m)
	grime = SceneTheme.grime(m)
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
	var rock := SphereMesh.new()   # low-poly and flat-shaded: faceted rocks read well as pixel art
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 5
	rock.rings = 3
	var mesa := CylinderMesh.new()   # a flat-topped butte: tapered, few facets
	mesa.top_radius = 0.4
	mesa.bottom_radius = 0.5
	mesa.height = 1.0
	mesa.radial_segments = 7
	mesa.rings = 2
	var cone := CylinderMesh.new()   # pines, canopies, spires
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 10
	cone.rings = 1
	var torus := TorusMesh.new()   # a big wheel's rim: radius 1, round its y axis
	torus.inner_radius = 0.955
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 4
	_shapes = {"box": box, "cyl": cyl, "sphere": sph, "quad": quad, "rock": rock, "mesa": mesa, "cone": cone, "torus": torus}


# --- Materials ---------------------------------------------------------------------

func mat(name: String, f: int, cut := true, over := {}) -> ShaderMaterial:
	var key := "%s|%d|%s|%s" % [name, f, cut, str(over)]
	if _mats.has(key):
		return _mats[key]
	var d: Array = SceneTheme.lib_entry(m, name, LIB[name])
	var extra: Dictionary = (d[6] if d.size() > 6 else {}).duplicate()
	extra.merge(over, true)
	var mt := ShaderMaterial.new()
	if extra.get("alpha", 1.0) < 1.0:
		mt.shader = _alpha_shader()
	elif extra.get("cutout", false):
		mt.shader = _cutout_shader()
	else:
		mt.shader = SHADER
	var col: Color = extra.get("color", d[0])
	mt.set_shader_parameter("albedo", Color(col, extra.get("alpha", 1.0)))
	mt.set_shader_parameter("albedo2", extra.get("color2", d[1]))
	mt.set_shader_parameter("pattern", extra.get("pattern", d[2]))
	mt.set_shader_parameter("pattern_scale", extra.get("scale", d[3]))
	mt.set_shader_parameter("roughness", d[4])
	mt.set_shader_parameter("metallic", d[5])
	mt.set_shader_parameter("emission", extra.get("emit", col))
	mt.set_shader_parameter("emission_energy", minf(float(extra.get("glow", 0.0)), 1.6))   # keep emitters in hue
	mt.set_shader_parameter("mode", extra.get("mode", 0))
	mt.set_shader_parameter("shell", extra.get("shell", false))
	mt.set_shader_parameter("flat_shade", extra.get("flat", false))
	mt.set_shader_parameter("offmap", extra.get("offmap", false))
	mt.set_shader_parameter("near_fade", extra.get("near_fade", false))
	mt.set_shader_parameter("dry", extra.get("dry", false))
	mt.set_shader_parameter("fog_hue", float(extra.get("fog_hue", 0.0)))
	mt.set_shader_parameter("cuttable", cut)
	if extra.has("tex"):
		mt.set_shader_parameter("tex", extra.tex)
		mt.set_shader_parameter("tex_mix", 1.0)
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
			.replace("	EMISSION = emit;", "	EMISSION = emit;\n\tALPHA = albedo.a;")
	return _alpha


static var _cutout: Shader
## Leaves and grass blades: the texture's alpha cuts the shape (opaque pipeline, alpha scissor).
static func _cutout_shader() -> Shader:
	if _cutout == null:
		_cutout = Shader.new()
		_cutout.code = SHADER.code.replace("	EMISSION = emit;", "	EMISSION = emit;\n\tALPHA = texture(tex, UV).a;\n\tALPHA_SCISSOR_THRESHOLD = 0.5;")
	return _cutout


const NATURE := "res://assets/third_party/quaternius/nature/%s.gltf"
static var _models := {}   ## model name → {mesh, xf (node transform in the scene), surf: [[texture, cutout]]}


## An imported model's mesh, its transform inside the file, and each surface's texture.
static func model(name: String) -> Dictionary:
	if _models.has(name):
		return _models[name]
	var sc: Node = (load(NATURE % name) as PackedScene).instantiate()
	var mi: MeshInstance3D = sc.find_children("*", "MeshInstance3D", true, false)[0]
	var xf := Transform3D.IDENTITY
	var n: Node = mi
	while n and n != sc:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var surf: Array = []
	for s in mi.mesh.get_surface_count():
		var sm := mi.get_active_material(s) as BaseMaterial3D
		var cut: bool = sm != null and (sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
		surf.append([sm.albedo_texture if sm else null, cut])
	_models[name] = {"mesh": mi.mesh, "xf": xf, "surf": surf}
	sc.free()
	return _models[name]


## Place an imported model (batched like the primitives). `over` overrides the material, e.g. a
## different texture ({"tex": ...}) or a tint ({"color": ...}).
func nature(name: String, xf: Transform3D, f := 0, over := {}) -> void:
	var md := model(name)
	var mats: Array = []
	for sv in md.surf:
		var o := {"tex": sv[0], "cutout": sv[1]}
		o.merge(over, true)
		if o.tex == null:
			o.erase("tex")
		mats.append(mat("nature", f, false, o))
	var key := "%d,%d|%s|%d" % [int(xf.origin.x) / CHUNK, int(xf.origin.z) / CHUNK, name, mats[0].get_instance_id()]
	var b: Dictionary = _b.get_or_add(key, {"shape": name, "mat": mats[0], "surf": mats, "xf": []})
	b.xf.append(xf * (md.xf as Transform3D))
	if tag != null:
		for cell in (tag if tag is Array else [tag]):
			_tagged.get_or_add(cell, []).append([b, b.xf.size() - 1])


## Every material the builder made (the greybox sets fog/look parameters on them).
func materials() -> Array:
	return _mats.values()


# --- Batching ----------------------------------------------------------------------

func put(shape: String, mt: Material, xf: Transform3D) -> void:
	xf.origin.y += y_off
	var key := "%d,%d|%s|%d" % [int(xf.origin.x) / CHUNK, int(xf.origin.z) / CHUNK, shape, mt.get_instance_id()]
	var b: Dictionary = _b.get_or_add(key, {"shape": shape, "mat": mt, "xf": []})
	b.xf.append(xf)
	if tag != null:
		for cell in (tag if tag is Array else [tag]):
			_tagged.get_or_add(cell, []).append([b, b.xf.size() - 1])


## Hide a destroyed cover piece at once (its MultiMesh instances shrink to nothing), without a
## rebuild. Multi-square props vanish whole when any of their squares is destroyed.
func hide_cover(cell: Vector3i) -> void:
	for e in _tagged.get(cell, []):
		var b: Dictionary = e[0]
		if b.has("mm"):
			(b.mm as MultiMesh).set_instance_transform(int(e[1]), Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


func box(mt: Material, center: Vector3, size: Vector3, yaw := 0.0) -> void:
	put("box", mt, Transform3D(Basis(Vector3.UP, yaw).scaled_local(size) if yaw != 0.0 else Basis.from_scale(size), center))


func flush(parent: Node3D) -> void:
	for key in _b:
		var b: Dictionary = _b[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		if b.has("surf"):   # imported model: one material per surface
			var am: Mesh = (model(b.shape).mesh as Mesh).duplicate()
			for s in am.get_surface_count():
				am.surface_set_material(s, b.surf[s])
			mm.mesh = am
		else:
			var mesh: PrimitiveMesh = _shapes[b.shape].duplicate()
			mesh.material = b.mat
			mm.mesh = mesh
		mm.instance_count = b.xf.size()
		b["mm"] = mm
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
	_sid_grid.resize(m.w * m.h)
	_sid_grid.fill(-1)
	for st in m.structures:
		if st.get("kind", "") != "building" or not st.has("rect"):
			continue
		var r: Rect2i = st.rect
		for y in range(maxi(r.position.y, 0), mini(r.end.y, m.h)):
			for x in range(maxi(r.position.x, 0), mini(r.end.x, m.w)):
				_sid_grid[y * m.w + x] = int(st.id)
	natural = String(m.params.get("scene", "")) == "badlands"
	street = m.street
	gy = street * FH
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
		if f < street:
			_earth(f)
		if f == street:
			if _surround() == "bedrock":
				_bedrock()
			_ground_organic()
			_rocks()
			_street_clutter()
			if natural:
				_nature_scatter()
		_roof_clutter(f)
		_facade_dressing(f)
		SetPieceDressing.dress(self, f)
		ParkDressing.dress(self, f)
		flush(fn)
	var sky := Node3D.new()
	sky.name = "skyline"
	sky.position.y = gy   # the city round the map stands on the street, whatever lies below it
	root.add_child(sky)
	match _surround():
		"desert":
			_frame(mat("sand", 0, false, {"mode": 2, "offmap": true}), 130.0)
			_mesas()
		"bedrock":
			_bedrock_ring()
		"atrium":
			_atrium()
		"ruins":
			_skyline(true)
		_:
			_skyline()
	flush(sky)
	return out


# --- Floors and ground -------------------------------------------------------------

## Neighbouring buildings get their own roof (owner round 6: every roof was the same grey):
## membrane, tar, gravel, pavers, a green coat or rusted sheet; corrugated on industrial sites,
## pavers on corp ones. Themed scenes keep their own roof material.
const ROOF_LOOKS := [
	{"color": Color("3a4252"), "color2": Color("232833"), "pattern": 4},
	{"color": Color("1c1e22"), "color2": Color("101113"), "pattern": 0},
	{"color": Color("625c50"), "color2": Color("44403a"), "pattern": 5, "scale": 1.6},
	{"color": Color("585c64"), "color2": Color("383b40"), "pattern": 1, "scale": 0.6},
	{"color": Color("2e4a3e"), "color2": Color("1c2e26"), "pattern": 4},
	{"color": Color("62402c"), "color2": Color("3a261a"), "pattern": 8, "scale": 1.2},
]
const WALL_LOOKS := {
	"wall_plaster": [Color("6e675d"), Color("5e6870"), Color("7a6252"), Color("5c6656"), Color("6c5e6e"), Color("7a7462")],
	"wall_concrete": [Color("5a5f66"), Color("4c535a"), Color("64645e"), Color("545a52"), Color("5e5660")],
}


func _site_of(sid: int) -> String:
	return String(m.structures[sid].get("site", "")) if sid >= 0 and sid < m.structures.size() else ""


## A set piece's building wears its recipe's look (setpieces.json sites.<part>.look).
func _sp_look(sid: int) -> Dictionary:
	if not _sp_looks.has(sid):
		_sp_looks[sid] = SetPieceDressing.look(m, sid)
	return _sp_looks[sid]


func _roof_look(sid: int) -> Dictionary:
	if sid >= 0 and _sp_look(sid).has("roof"):
		return SetPieceDressing.mat_over(_sp_look(sid).roof)
	if sid < 0 or SceneTheme.of(m).get("mats", {}).has("roof"):
		return {}
	var site := _site_of(sid)
	if site in ["warehouse", "factory", "chop_shop"]:
		return {"color": Color("4c5056"), "color2": Color("2e3236"), "pattern": 8, "scale": 1.3}
	if site in ["corp_office", "corp_hq", "data_center", "bank"]:
		return ROOF_LOOKS[3]
	return ROOF_LOOKS[posmod(hash(sid * 2654435761 + m.seed_value), ROOF_LOOKS.size())]


func _wall_look(name: String, sid: int) -> Dictionary:
	if sid >= 0 and _sp_look(sid).has("wall"):
		return SetPieceDressing.mat_over(_sp_look(sid).wall)
	if sid < 0:
		return {}
	var dl := SceneTheme.wall_look(m, name, hash(sid * 40503 + m.seed_value * 7))   # the district's facades
	if not dl.is_empty():
		return dl
	if not WALL_LOOKS.has(name) or SceneTheme.of(m).get("mats", {}).has(name):
		return {}
	var list: Array = WALL_LOOKS[name]
	var col: Color = list[posmod(hash(sid * 40503 + m.seed_value * 7), list.size())]
	return {"color": col, "color2": col.darkened(0.42)}


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
				TacMap.G.GRASS, TacMap.G.DIRT, TacMap.G.SAND, TacMap.G.GRAVEL: return "concrete" if f != street else ""
			return "concrete"
	var l2 := m.label(f, x, y)
	return _room_floor(m.rooms[l2]) if l2 >= 0 else "floor_concrete"


func _room_floor(r: Dictionary) -> String:
	var k: String = r.kind
	for w in ["bar", "club", "lounge", "apartment", "living", "bedroom", "boss", "exec", "study", "vip", "dining", "temple", "shrine", "quarters", "foyer", "gym", "auditorium"]:
		if k.contains(w):
			return "floor_wood" if k != "dance_floor" else "floor_tile"
	for w in ["warehouse", "factory", "garage", "storage", "loading", "cargo", "workshop", "dock", "squat", "stash", "shack", "engine", "cage", "parking", "yard", "platform", "quay", "rubble", "tunnel"]:
		if k.contains(w):
			return "floor_concrete"
	for w in ["server", "vault", "armory", "security", "control", "cooling", "evidence", "holding", "panic", "armored", "mantrap"]:
		if k.contains(w):
			return "floor_vault" if k.contains("vault") else "floor_metal"
	for w in ["office", "meeting", "waiting", "recovery", "capsule", "booth", "guest", "suite", "library"]:
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
			var look := _roof_look(_sid_grid[y * m.w + x]) if k == "roof" else {}
			box(mat(k, f, f != street, look), Vector3(r.get_center().x, top - thick / 2, r.get_center().y), Vector3(r.size.x, thick, r.size.y))
	# A dark slab under every built cell (including walls) so no seam ever shows the void.
	if f != street:
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
		for k in [0, 1, 2]:  # upward winding only: the world shader draws both faces (cull_disabled), and a
			# downward copy won the depth tie, so lawns and water drew as section caps (unlit slate, no spill)
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
		return m.inb(x, y) and m.t(street, x, y) != TacMap.T.VOID and _floor_key(street, x, y) == "" and m.t(street, x, y) != TacMap.T.WATER \
			and not (m.t(street, x, y) in [TacMap.T.WALL, TacMap.T.DOOR])
	# base under organic patches (and under fences/rock walls)
	for y in m.h:
		for x in m.w:
			if base.call(x, y) or (m.t(street, x, y) == TacMap.T.WALL and int(m.wall_mat[street][y * m.w + x]) in [3, 4]):
				box(mat("dirt", street, false), Vector3(x + 0.5, gy - 0.07, y + 0.5), Vector3(1, 0.1, 1))
	var lift := 0.0
	for g in gtypes:
		lift += 0.004
		var tris := marching(func(x: int, y: int) -> bool:
			return m.inb(x, y) and m.t(street, x, y) != TacMap.T.VOID and int(m.ground[y * m.w + x]) == g and m.label(street, x, y) < 0 or \
				(m.inb(x, y) and int(m.ground[y * m.w + x]) == g and m.label(street, x, y) >= 0 and m.rooms[m.label(street, x, y)].get("outdoor", false)), m.w, m.h, 0.1, g)   # less jitter: no floating shards
		var sf := _surface(tris, gy - 0.02 + lift, mat(gtypes[g], street, false))
		if sf:
			sf.set_meta("floor", street)
			_surfaces.append(sf)
	var water := mat("water", street, false)
	if float(SceneTheme.of(m).get("mats", {}).get("water", {}).get("glow", 0.0)) > 0.0:
		# glowing water (the undercity's runoff) is drawn as boxes: marching-squares surfaces
		# lose their emission in the world shader
		for y in m.h:
			for x in m.w:
				if m.t(street, x, y) == TacMap.T.WATER:
					box(water, Vector3(x + 0.5, gy - 0.3, y + 0.5), Vector3(1, 0.1, 1))
					box(mat("dark", street, false), Vector3(x + 0.5, gy - 0.6, y + 0.5), Vector3(1, 0.1, 1))
		return
	var wt := marching(func(x: int, y: int) -> bool: return m.inb(x, y) and m.t(street, x, y) == TacMap.T.WATER, m.w, m.h, 0.15, 99)
	var ws := _surface(wt, gy - 0.35, water)
	if ws:
		ws.set_meta("floor", street)
		_surfaces.append(ws)
		# a dark bed under the water
		for y in m.h:
			for x in m.w:
				if m.t(street, x, y) == TacMap.T.WATER:
					box(mat("dark", street, false), Vector3(x + 0.5, gy - 0.6, y + 0.5), Vector3(1, 0.1, 1))


## A storey below the street (TacMap.basements): the earth it is dug into, packed round the
## excavation up to just under street level (greedy-meshed blocks over the storey's empty squares
## and a margin past the map edge), its top a dark soil section with a lighter lip where it meets
## the dug-out rooms; standing water (T.WATER: flooded sunken floors) as a dark sheet a hand below
## the floor. Seen only when the view is down here: the street and everything above is lifted off.
const EARTH_MARGIN := 6

func _earth(f: int) -> void:
	var y0 := f * FH
	var top := (f + 1) * FH - 0.13   # just under the street's ground slabs: no z-fight from above
	var soil := mat("dirt", f, false, {"color": Color("6e5640"), "color2": Color("4a3a2a"), "pattern": 5, "scale": 1.6, "shell": true, "glow": 0.12, "emit": Color("3a2c20")})
	var lip := mat("concrete", f, false, {"color": Color("9a8a74"), "color2": Color("7a6a56"), "shell": true, "glow": 0.2, "emit": Color("6a5a48")})
	var dug := func(x: int, y: int) -> bool: return m.inb(x, y) and m.t(f, x, y) != TacMap.T.VOID
	var used := {}
	var x0 := -EARTH_MARGIN
	var x1 := m.w + EARTH_MARGIN
	var y1 := m.h + EARTH_MARGIN
	for y in range(-EARTH_MARGIN, y1):
		for x in range(x0, x1):
			if used.has(Vector2i(x, y)) or dug.call(x, y):
				continue
			var w := 1
			while x + w < x1 and not used.has(Vector2i(x + w, y)) and not dug.call(x + w, y):
				w += 1
			var h := 1
			var grow := true
			while grow and y + h < y1:
				for i in w:
					if used.has(Vector2i(x + i, y + h)) or dug.call(x + i, y + h):
						grow = false
						break
				if grow:
					h += 1
			for j in h:
				for i in w:
					used[Vector2i(x + i, y + j)] = true
			box(soil, Vector3(x + w / 2.0, (y0 - 0.12 + top) / 2.0, y + h / 2.0), Vector3(w, top - y0 + 0.12, h))
	# the lip: a lighter band on the soil squares that border the dig, so its outline reads
	for y in m.h:
		for x in m.w:
			if dug.call(x, y):
				continue
			for d in MapGen.DIRS:
				if dug.call(x + d.x, y + d.y):
					box(lip, Vector3(x + 0.5, top + 0.005, y + 0.5), Vector3(1.0, 0.012, 1.0))
					break
	var water := mat("water", f, false, {"color": Color("0c2a36"), "glow": 0.2, "emit": Color("0a3a48")})
	for y in m.h:
		for x in m.w:
			if m.t(f, x, y) == TacMap.T.WATER:
				box(water, Vector3(x + 0.5, y0 - 0.1, y + 0.5), Vector3(1.0, 0.04, 1.0))
				box(mat("dark", f, false), Vector3(x + 0.5, y0 - 0.45, y + 0.5), Vector3(1.0, 0.1, 1.0))


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
				box(mt, Vector3(x + 0.5, y0 + (FH - WALL_GAP) / 2, y + 0.5), Vector3(EXT_T + 0.1, FH - WALL_GAP, EXT_T + 0.1))
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
	if glass and ext and b0 == b1 and _punched(x0, y0c):
		_punched_window(f, horiz, a, b0, t, c)
		return
	if glass:
		# sill, pane, lintel, and mullions at a spacing that ignores the grid
		var sill := 0.32
		var lintel := 1.32
		var gsh := {"shell": true} if ext else {}
		var wsh := gsh
		if ext:   # a set piece's sill and lintel wear its wall look
			wsh = gsh.merged(_sp_wall(_sid_grid[clampi(a if horiz else b0, 0, m.h - 1) * m.w + clampi(b0 if horiz else a, 0, m.w - 1)]))
		box(mat("wall_concrete" if ext else "wall_int", f, true, wsh), c + Vector3(0, y0 + sill / 2, 0), size.call(sill, t))
		box(mat("wall_concrete" if ext else "wall_int", f, true, wsh), c + Vector3(0, y0 + (lintel + FH - WALL_GAP) / 2, 0), size.call(FH - lintel - WALL_GAP, t))
		box(mat("glass", f, true, gsh), c + Vector3(0, y0 + (sill + lintel) / 2, 0), size.call(lintel - sill, 0.05))
		box(mat("frame", f, true, gsh), c + Vector3(0, y0 + sill + 0.02, 0), size.call(0.04, t + 0.06))
		var n := maxi(1, roundi(length / 0.62))
		if ext:   # ~35% of panes lit from inside: rhythm on the facade and coloured spill outside
			var inward := Vector3.ZERO
			var probe := Vector2i(b0, a + 1) if horiz else Vector2i(a + 1, b0)
			var norm := Vector3(0, 0, 1) if horiz else Vector3(1, 0, 0)
			inward = norm if (m.inb(probe.x, probe.y) and not vision._outdoor(f, probe.x, probe.y)) else -norm
			for i in n:
				rng.seed = hash(Vector3i(b0 + i, a, f)) + 41
				if rng.randf() > 0.35:
					continue
				var wcol: Color = [Color("ffc890"), Color("ffb070"), Color("aaf6ff"), Color("ffa0c0")][rng.randi() % 4]
				var pc := s + length * (i + 0.5) / n
				var pcv := (Vector3(pc, 0, a + 0.5) if horiz else Vector3(a + 0.5, 0, pc)) + inward * 0.05
				var pw := length / n * 0.9
				box(mat("dark", f, true, {"glow": 1.2, "emit": wcol, "shell": true}), pcv + Vector3(0, y0 + (sill + lintel) / 2, 0), Vector3(pw, lintel - sill - 0.04, 0.02) if horiz else Vector3(0.02, lintel - sill - 0.04, pw))
				if f == street:
					var oc := Vector3(pc, 0, a + 0.5) - inward * 1.0
					emitters.append({"cell": Vector3i(int(oc.x), int(oc.z), street), "color": wcol, "energy": 0.6, "range": 3.0, "out": Vector2i.ZERO})
		for i in range(1, n):
			var p := s + length * i / n
			var mc := Vector3(p, 0, a + 0.5) if horiz else Vector3(a + 0.5, 0, p)
			box(mat("frame", f), mc + Vector3(0, y0 + (sill + lintel) / 2, 0), Vector3(0.04, lintel - sill, 0.08) if horiz else Vector3(0.08, lintel - sill, 0.04))
		return
	var name := "wall_int"
	var sh := {"shell": true} if ext else {}
	var trim := sh
	if ext and f < street:   # below grade: bare cast concrete against the earth, no facade look
		name = "wall_concrete"
	elif ext:
		name = ["wall_plaster", "wall_concrete", "wall_steel", "wall_concrete", "wall_concrete", "wall_concrete", "wall_concrete"][k]
		var cx: int = x0 if horiz else a
		var cy: int = a if horiz else b0
		var wsid := _sid_grid[clampi(cy, 0, m.h - 1) * m.w + clampi(cx, 0, m.w - 1)]
		sh.merge(_wall_look(name, wsid))
		trim = _trim_look(wsid, sh)
	box(mat(name, f, true, sh), c + Vector3(0, y0 + (FH - WALL_GAP) / 2, 0), size.call(FH - WALL_GAP, t))
	box(mat("skirt", f, true, trim), c + Vector3(0, y0 + 0.06, 0), size.call(0.12, t + 0.04))
	if ext and f >= street:
		box(mat("cornice", f, true, trim), c + Vector3(0, y0 + FH - 0.04 - WALL_GAP, 0), size.call(0.08, t + 0.1))


## A set piece's trim (cornices, skirting, parapets: a colour, or a look that may glow), else `fallback`.
func _trim_look(sid: int, fallback: Dictionary) -> Dictionary:
	if sid >= 0 and _sp_look(sid).has("trim"):
		var o := SetPieceDressing.mat_over(_sp_look(sid).trim)
		o["shell"] = true
		return o
	return fallback


## A set piece's wall look ({} for any other building).
func _sp_wall(sid: int) -> Dictionary:
	return SetPieceDressing.mat_over(_sp_look(sid).wall) if sid >= 0 and _sp_look(sid).has("wall") else {}


func _punched(x: int, y: int) -> bool:
	var sid := _sid_grid[clampi(y, 0, m.h - 1) * m.w + clampi(x, 0, m.w - 1)]
	return sid >= 0 and bool(m.structures[sid].get("punched_windows", false))


## A single-square window in a site that repeats its rooms (a hotel's guest rooms): a narrow
## opening punched in the wall, its jambs, sill and head in the wall's own finish.
func _punched_window(f: int, horiz: bool, a: int, b: int, t: float, c: Vector3) -> void:
	var y0 := f * FH
	var x := b if horiz else a
	var y := a if horiz else b
	var k := 1
	for n in ([Vector2i(x - 1, y), Vector2i(x + 1, y)] if horiz else [Vector2i(x, y - 1), Vector2i(x, y + 1)]):
		var kn := _wall_kind(f, n.x, n.y)
		if kn in [0, 1, 2]:
			k = kn
	var name: String = ["wall_plaster", "wall_concrete", "wall_steel"][k]
	var sh := {"shell": true}
	sh.merge(_wall_look(name, _sid_grid[clampi(y, 0, m.h - 1) * m.w + clampi(x, 0, m.w - 1)]))
	var wm := mat(name, f, true, sh)
	var sz := func(along: float, h: float, thick: float) -> Vector3:
		return Vector3(along, h, thick) if horiz else Vector3(thick, h, along)
	var ax := Vector3(1, 0, 0) if horiz else Vector3(0, 0, 1)
	var sill := 0.42
	var lintel := 1.2
	var top := FH - WALL_GAP
	var pane := 0.46
	var jamb := (1.0 - pane) / 2.0
	for sd in [-1, 1]:
		box(wm, c + ax * sd * (0.5 - jamb / 2.0) + Vector3(0, y0 + top / 2, 0), sz.call(jamb, top, t))
	box(wm, c + Vector3(0, y0 + sill / 2, 0), sz.call(pane, sill, t))
	box(wm, c + Vector3(0, y0 + (lintel + top) / 2, 0), sz.call(pane, top - lintel, t))
	box(mat("skirt", f, true, sh), c + Vector3(0, y0 + 0.06, 0), sz.call(1.0, 0.12, t + 0.04))
	box(mat("cornice", f, true, sh), c + Vector3(0, y0 + top - 0.04, 0), sz.call(1.0, 0.08, t + 0.1))
	box(mat("glass", f, true, {"shell": true}), c + Vector3(0, y0 + (sill + lintel) / 2, 0), sz.call(pane, lintel - sill, 0.05))
	box(mat("frame", f, true, {"shell": true}), c + Vector3(0, y0 + sill + 0.02, 0), sz.call(pane + 0.08, 0.05, t + 0.08))
	rng.seed = hash(Vector3i(x, y, f)) + 41
	if rng.randf() < 0.45:   # some rooms lit from inside: the same window, on and off, up the facade
		var probe := Vector2i(x, y + 1) if horiz else Vector2i(x + 1, y)
		var norm := Vector3(0, 0, 1) if horiz else Vector3(1, 0, 0)
		var inward := norm if (m.inb(probe.x, probe.y) and not vision._outdoor(f, probe.x, probe.y)) else -norm
		var wcol: Color = [Color("ffc890"), Color("ffb070"), Color("ffd8a8")][rng.randi() % 3]
		box(mat("dark", f, true, {"glow": 1.2, "emit": wcol, "shell": true}), c + inward * 0.05 + Vector3(0, y0 + (sill + lintel) / 2, 0), sz.call(pane - 0.04, lintel - sill - 0.04, 0.02))


func _door_frame(f: int, p: Vector2i) -> void:
	var y0 := f * FH
	var horiz := _line_member(f, p.x - 1, p.y) or _line_member(f, p.x + 1, p.y) or not (_line_member(f, p.x, p.y - 1) or _line_member(f, p.x, p.y + 1))
	var ext := _exterior(f, p.x, p.y)
	var t := EXT_T if ext else INT_T
	var c := Vector3(p.x + 0.5, y0, p.y + 0.5)
	var head := 1.15
	var lintel := Vector3(1, FH - head, t) if horiz else Vector3(t, FH - head, 1)
	var dsh := {"shell": true} if ext else {}
	if ext:
		dsh.merge(_sp_wall(_sid_grid[p.y * m.w + p.x]))
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
		if c.floor != f or int(c.get("hp", 1)) <= 0:   # destroyed pieces stay gone after a rebuild
			continue
		if int(c.get("prop", -1)) >= 0:
			props.get_or_add(int(c.prop) * 10 + f, []).append(c)
			continue
		var h0 := hash(Vector3i(c.pos.x, c.pos.y, f))
		tag = Vector3i(c.pos.x, c.pos.y, f)
		if c.has("face"):   # laid out by a room set: square on its square, turned to face its way
			_piece(String(c.kind), Vector3(c.pos.x + 0.5, y0, c.pos.y + 0.5), _yaw(c.face), f, h0, true)
		else:
			var p := Vector3(c.pos.x + 0.5 + _jit(h0, 0.08), y0, c.pos.y + 0.5 + _jit(h0 + 1, 0.08))
			_piece(String(c.kind), p, _jit(h0 + 2, 0.12), f, h0)
		tag = null
	for k in props:
		var cells: Array = props[k]
		tag = cells.map(func(c): return Vector3i(c.pos.x, c.pos.y, f))
		var r := Rect2(cells[0].pos.x, cells[0].pos.y, 1, 1)
		for c in cells:
			r = r.expand(Vector2(c.pos.x, c.pos.y)).expand(Vector2(c.pos.x + 1, c.pos.y + 1))
		var h0 := hash(k)
		_multi(String(cells[0].kind), r, f, h0)
		tag = null
	var stanchions := {}
	for d in m.decor:
		if d.floor == f and d.kind in ["stanchion", "rail"]:
			stanchions[d.pos] = d.kind
	for d in m.decor:
		if d.floor == f:
			_decor(d, Vector3(d.pos.x + 0.5, y0, d.pos.y + 0.5), f, stanchions)


## A room set's facing as a turn: the piece's front (+z) points along `face`.
static func _yaw(face: Vector2i) -> float:
	return atan2(float(face.x), float(face.y))


## Walk-through dressing (Furnish.DECOR): chairs and stools pulled up to the piece they face,
## queue posts with belts to their neighbours, bedside tables, boards and hoops on the wall behind.
func _decor(d: Dictionary, c: Vector3, f: int, stanchions: Dictionary) -> void:
	var face: Vector2i = d.get("face", Vector2i(0, 1))
	var yaw := _yaw(face)
	var fz := Vector3(face.x, 0, face.y)
	var D := mat("dark", f, false)
	match String(d.kind):
		"side_chair":
			var p := c + fz * 0.32
			box(mat("fabric", f, false, {"color": Color("4a3a5a")}), p + Vector3(0, 0.23, 0), Vector3(0.36, 0.05, 0.34), yaw)
			box(D, p + Vector3(0, 0.38, -0.17).rotated(Vector3.UP, yaw), Vector3(0.36, 0.3, 0.04), yaw)
			for sx in [-0.15, 0.15]:
				for sz in [-0.14, 0.14]:
					box(D, p + Vector3(sx, 0.11, sz).rotated(Vector3.UP, yaw), Vector3(0.03, 0.22, 0.03), yaw)
		"stool":
			var p := c + fz * 0.3
			put("cyl", mat("fabric", f, false, {"color": Color("8a2a3a")}), Transform3D(Basis.from_scale(Vector3(0.3, 0.05, 0.3)), p + Vector3(0, 0.3, 0)))
			put("cyl", D, Transform3D(Basis.from_scale(Vector3(0.05, 0.3, 0.05)), p + Vector3(0, 0.15, 0)))
			put("cyl", D, Transform3D(Basis.from_scale(Vector3(0.22, 0.02, 0.22)), p + Vector3(0, 0.01, 0)))
		"stanchion":   # a queue post; a belt to each neighbouring post
			var steel := mat("steel", f, false, {"color": Color("b8bcc2")})
			put("cyl", steel, Transform3D(Basis.from_scale(Vector3(0.05, 0.46, 0.05)), c + Vector3(0, 0.23, 0)))
			put("cyl", steel, Transform3D(Basis.from_scale(Vector3(0.2, 0.02, 0.2)), c + Vector3(0, 0.01, 0)))
			for n in MapGen.DIRS:
				if stanchions.get(d.pos + n, "") == "stanchion":
					var dir := Vector3(n.x, 0, n.y)
					box(mat("fabric", f, false, {"color": Color("a01830"), "glow": 0.3, "emit": Color("ff2040")}), c + dir * 0.25 + Vector3(0, 0.42, 0), Vector3(0.5, 0.05, 0.015), _yaw(Vector2i(n.y, -n.x)))
		"nightstand":
			var p := c - fz * 0.25
			box(mat("wood", f, false), p + Vector3(0, 0.15, 0), Vector3(0.36, 0.3, 0.32), yaw)
			put("cyl", mat("dark", f, false, {"glow": 1.4, "emit": Color("ffc890")}), Transform3D(Basis.from_scale(Vector3(0.12, 0.14, 0.12)), p + Vector3(0, 0.37, 0)))
		"board":   # a board (classroom) or a key/logo wall (front desk) on the wall behind
			var p := c - fz * 0.76
			box(mat("frame", f), p + Vector3(0, 0.8, 0), Vector3(0.96, 0.5, 0.04), yaw)
			box(mat("dark", f, true, {"color": Color("16302a"), "glow": 0.5, "emit": Color("3fd0a0")}), p + Vector3(0, 0.8, 0) + fz * 0.02, Vector3(0.88, 0.42, 0.02), yaw)
			box(mat("frame", f), p + Vector3(0, 0.55, 0) + fz * 0.05, Vector3(0.9, 0.03, 0.08), yaw)
		"hoop":   # a basketball backboard and rim on the end wall
			var p := c - fz * 0.76
			box(mat("steel", f, true, {"color": Color("e8e8e4")}), p + Vector3(0, 1.15, 0), Vector3(0.55, 0.36, 0.03), yaw)
			box(mat("steel", f, true, {"color": Color("d05a1a")}), p + Vector3(0, 1.02, 0) + fz * 0.14, Vector3(0.22, 0.02, 0.22), yaw)
			box(mat("steel", f, true, {"color": Color("d05a1a")}), p + Vector3(0, 1.1, 0) + fz * 0.03, Vector3(0.16, 0.12, 0.02), yaw)
		_:   # a theme park's: queue rails, string-light poles, the coaster's track, a pavilion's canopy
			ParkDressing.decor(self, d, c, f, stanchions)


## One-square pieces. `p` is the jittered base centre; `yaw` a small deterministic turn.
## `aligned`: placed by a room set, so runs of counters and tables meet edge to edge.
func _piece(kind: String, p: Vector3, yaw: float, f: int, h0: int, aligned := false) -> void:
	var W := mat("wood", f, false)
	var S := mat("steel", f, false)
	var D := mat("dark", f, false)
	var wide := 1.0 if aligned else 0.8
	if kind == "bed" and aligned:
		kind = "bed_set"
	match kind:
		"desk", "table", "reception", "counter", "stall", "kiosk":
			var top := 0.38 if not (kind in ["reception", "counter"]) else 0.5
			box(W if kind != "desk" else mat("dark", f, false), p + Vector3(0, top, 0), Vector3(wide if kind != "desk" else 0.8, 0.05, 0.55), yaw)
			if kind in ["reception", "counter", "kiosk", "stall"]:
				box(W, p + Vector3(0, top / 2, 0), Vector3(wide - 0.02, top, 0.5), yaw)
				if kind == "stall":
					box(mat("fabric", f, false, {"color": neon[h0 % neon.size()].darkened(0.5)}), p + Vector3(0, 0.95, 0), Vector3(0.95, 0.04, 0.8), yaw)
			else:
				for sx in [-0.35, 0.35]:
					for sz in [-0.22, 0.22]:
						box(D, p + Vector3(sx, top / 2, sz).rotated(Vector3.UP, yaw), Vector3(0.04, top, 0.04), yaw)
			if kind == "desk":   # the screen on the far side from the user (a set's desk faces +z)
				box(mat("dark", f, false, {"glow": 1.2, "emit": Color("4fd8ff")}), p + Vector3(0, top + 0.12, 0.15 if aligned else -0.1).rotated(Vector3.UP, yaw), Vector3(0.3, 0.2, 0.02), yaw)
			if kind == "reception" and aligned:   # a lit strip along the visitors' side
				box(mat("dark", f, false, {"glow": 1.0, "emit": neon[h0 % neon.size()] if not neon.is_empty() else Color("4fd8ff")}), p + Vector3(0, 0.3, 0.26).rotated(Vector3.UP, yaw), Vector3(wide - 0.04, 0.04, 0.01), yaw)
		"teller_counter":   # an armoured counter, a bullet-resistant screen on the customers' side
			box(mat("steel", f, false, {"color": Color("5a6470")}), p + Vector3(0, 0.26, 0), Vector3(1.0, 0.52, 0.5), yaw)
			box(mat("stone", f, false, {"color": Color("a8a296")}), p + Vector3(0, 0.53, 0), Vector3(1.0, 0.04, 0.58), yaw)
			box(mat("glass", f, false, {"alpha": 0.4}), p + Vector3(0, 0.88, 0.24).rotated(Vector3.UP, yaw), Vector3(0.98, 0.66, 0.03), yaw)
			box(mat("frame", f, false), p + Vector3(0, 1.22, 0.24).rotated(Vector3.UP, yaw), Vector3(1.0, 0.03, 0.05), yaw)
			box(mat("frame", f, false), p + Vector3(-0.48, 0.88, 0.24).rotated(Vector3.UP, yaw), Vector3(0.04, 0.66, 0.05), yaw)
			box(mat("dark", f, false, {"glow": 1.2, "emit": Color("4fd8ff")}), p + Vector3(0.18, 0.66, 0.05).rotated(Vector3.UP, yaw), Vector3(0.26, 0.18, 0.02), yaw)
		"prep_counter", "pass":   # stainless kitchen counters; the pass carries heat lamps on a gantry
			box(mat("steel", f, false, {"color": Color("8a9096")}), p + Vector3(0, 0.23, 0), Vector3(wide, 0.46, 0.55), yaw)
			box(mat("steel", f, false, {"color": Color("c0c6cc")}), p + Vector3(0, 0.47, 0), Vector3(wide, 0.03, 0.58), yaw)
			if kind == "pass":
				for sx in [-0.45, 0.45]:
					box(S, p + Vector3(sx, 0.75, 0).rotated(Vector3.UP, yaw), Vector3(0.04, 0.55, 0.04), yaw)
				box(S, p + Vector3(0, 1.02, 0), Vector3(wide, 0.05, 0.3), yaw)
				box(mat("dark", f, false, {"glow": 2.0, "emit": Color("ff7a2a")}), p + Vector3(0, 0.99, 0), Vector3(wide * 0.9, 0.02, 0.2), yaw)
			else:
				box(D, p + Vector3(0, 0.12, 0), Vector3(wide * 0.92, 0.02, 0.5), yaw)
		"school_desk":   # a pupil's desk and its chair behind it, both facing the board
			box(W, p + Vector3(0, 0.36, 0.12).rotated(Vector3.UP, yaw), Vector3(0.6, 0.04, 0.38), yaw)
			box(S, p + Vector3(0, 0.18, 0.28).rotated(Vector3.UP, yaw), Vector3(0.56, 0.34, 0.03), yaw)
			box(mat("steel", f, false, {"color": Color("2a5a7a")}), p + Vector3(0, 0.22, -0.22).rotated(Vector3.UP, yaw), Vector3(0.36, 0.04, 0.32), yaw)
			box(mat("steel", f, false, {"color": Color("2a5a7a")}), p + Vector3(0, 0.36, -0.38).rotated(Vector3.UP, yaw), Vector3(0.36, 0.28, 0.03), yaw)
			box(D, p + Vector3(0, 0.11, -0.22).rotated(Vector3.UP, yaw), Vector3(0.04, 0.22, 0.04), yaw)
		"host_stand":   # a lectern by the door with a reading lamp
			box(mat("wood", f, false, {"color": Color("2a1a14")}), p + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.36), yaw)
			box(W, p + Vector3(0, 0.62, -0.02).rotated(Vector3.UP, yaw), Vector3(0.56, 0.04, 0.42), yaw)
			box(mat("dark", f, false, {"glow": 1.6, "emit": Color("ffc890")}), p + Vector3(0.18, 0.7, -0.1).rotated(Vector3.UP, yaw), Vector3(0.08, 0.1, 0.08), yaw)
		"vault_door":   # the open vault door, swung back against the wall beside its doorway
			var bv := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), PI / 2)
			put("cyl", mat("steel", f, false, {"color": Color("9aa2aa")}), Transform3D(bv.scaled_local(Vector3(1.0, 0.3, 1.0)), p + Vector3(0, 0.56, 0)))
			put("cyl", mat("steel", f, false, {"color": Color("5a626a")}), Transform3D(bv.scaled_local(Vector3(0.7, 0.34, 0.7)), p + Vector3(0, 0.56, 0)))
			for i in 3:   # the locking wheel's spokes on the room side
				var sb := Basis(Vector3.UP, yaw) * Basis(Vector3(1, 0, 0), i * PI / 3.0)
				put("box", D, Transform3D(sb.scaled_local(Vector3(0.04, 0.5, 0.04)), p + Vector3(0, 0.56, 0) + Vector3(0.19, 0, 0).rotated(Vector3.UP, yaw)))
			box(D, p + Vector3(0, 0.56, -0.48).rotated(Vector3.UP, yaw), Vector3(0.2, 0.7, 0.1), yaw)
		"armchair":
			var fab := mat("fabric", f, false, {"color": Color("5a3a4a")})
			box(fab, p + Vector3(0, 0.13, 0), Vector3(0.6, 0.26, 0.55), yaw)
			box(fab, p + Vector3(0, 0.36, -0.24).rotated(Vector3.UP, yaw), Vector3(0.6, 0.36, 0.1), yaw)
			for sx in [-0.27, 0.27]:
				box(fab, p + Vector3(sx, 0.3, 0).rotated(Vector3.UP, yaw), Vector3(0.08, 0.16, 0.55), yaw)
		"bleachers":   # stepped timber tiers rising to the wall, a rail along the top
			for i in 3:
				box(mat("wood", f, false, {"color": Color("a07c50")}), p + Vector3(0, 0.12 + i * 0.2, 0.3 - i * 0.28).rotated(Vector3.UP, yaw), Vector3(1.0, 0.24 + i * 0.4, 0.3), yaw)
			box(S, p + Vector3(0, 0.95, -0.45).rotated(Vector3.UP, yaw), Vector3(1.0, 0.04, 0.04), yaw)
		"luggage":   # a brass luggage cart loaded with cases
			var brass := mat("steel", f, false, {"color": Color("b8902a")})
			box(brass, p + Vector3(0, 0.1, 0), Vector3(0.75, 0.04, 0.45), yaw)
			for sx in [-0.35, 0.35]:
				box(brass, p + Vector3(sx, 0.5, 0).rotated(Vector3.UP, yaw), Vector3(0.04, 0.8, 0.04), yaw)
			box(brass, p + Vector3(0, 0.9, 0), Vector3(0.74, 0.04, 0.04), yaw)
			var cases := [Color("6a2a2a"), Color("2a3a5a"), Color("3a3a3a"), Color("6a5a3a")]
			box(mat("fabric", f, false, {"color": cases[h0 % 4]}), p + Vector3(-0.12, 0.27, 0).rotated(Vector3.UP, yaw), Vector3(0.4, 0.3, 0.3), yaw)
			box(mat("fabric", f, false, {"color": cases[(h0 + 1) % 4]}), p + Vector3(0.17, 0.22, 0.02).rotated(Vector3.UP, yaw), Vector3(0.22, 0.22, 0.34), yaw)
			box(mat("fabric", f, false, {"color": cases[(h0 + 2) % 4]}), p + Vector3(-0.05, 0.5, 0).rotated(Vector3.UP, yaw), Vector3(0.3, 0.16, 0.24), yaw + 0.2)
		"bed_set":   # a bed laid out by a room set: head to the wall (-z), headboard, pillow, a throw
			box(W, p + Vector3(0, 0.12, 0.02), Vector3(0.78, 0.24, 0.92), yaw)
			box(mat("fabric", f, false, {"color": Color("c8c4bc")}), p + Vector3(0, 0.28, 0.02), Vector3(0.74, 0.08, 0.88), yaw)
			box(mat("fabric", f, false, {"color": Color("e8e4dc")}), p + Vector3(0, 0.34, -0.3).rotated(Vector3.UP, yaw), Vector3(0.6, 0.07, 0.2), yaw)
			box(mat("fabric", f, false), p + Vector3(0, 0.33, 0.28).rotated(Vector3.UP, yaw), Vector3(0.76, 0.04, 0.3), yaw)
			box(W, p + Vector3(0, 0.4, -0.46).rotated(Vector3.UP, yaw), Vector3(0.84, 0.8, 0.06), yaw)
		"sofa", "booth", "bed", "bench", "pew", "seat", "chair":
			var mt := mat("fabric", f, false) if kind in ["sofa", "booth", "bed"] else (W if kind in ["pew", "seat"] else S)
			var w := 0.85 if kind != "seat" and kind != "chair" else 0.4
			box(mt, p + Vector3(0, 0.12, 0), Vector3(w, 0.24, 0.5), yaw)
			if kind == "booth":   # a high wooden back, the seat upholstered
				box(W, p + Vector3(0, 0.45, -0.21).rotated(Vector3.UP, yaw), Vector3(w, 0.9, 0.1), yaw)
			elif kind != "bed" and kind != "bench":
				box(mt, p + Vector3(0, 0.32, -0.21).rotated(Vector3.UP, yaw), Vector3(w, 0.4, 0.1), yaw)
		"stove":   # a kitchen range: steel body, dark hob, burners glowing
			box(S, p + Vector3(0, 0.22, 0), Vector3(0.75, 0.44, 0.55), yaw)
			box(D, p + Vector3(0, 0.45, 0), Vector3(0.72, 0.02, 0.52), yaw)
			for bx in [-0.18, 0.18]:
				box(mat("dark", f, false, {"glow": 1.6, "emit": Color("ff6a1a")}), p + Vector3(bx, 0.47, 0).rotated(Vector3.UP, yaw), Vector3(0.16, 0.01, 0.16), yaw)
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
			box(mat("dark", f, false, {"glow": 2.0, "emit": neon[h0 % neon.size()]}), p + Vector3(0, 0.5, 0.23).rotated(Vector3.UP, yaw), Vector3(0.5, 0.6, 0.01), yaw)
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
			if natural:
				_rock_model(p + Vector3(0, -0.05, 0), Vector3(0.32, 0.3, 0.32), h0, f)
				return
			for i in 3:
				rng.seed = h0 + i
				put("rock", mat("rock", f, false), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(rng.randf_range(0.5, 0.9), rng.randf_range(0.4, 0.7), rng.randf_range(0.5, 0.9))), p + Vector3(rng.randf_range(-0.2, 0.2), 0.2, rng.randf_range(-0.2, 0.2))))
		"server_core":   # a tall rack tower, status lights racing up the front
			box(mat("steel", f, false, {"color": Color("1e2228")}), p + Vector3(0, 0.75, 0), Vector3(0.85, 1.5, 0.85), yaw)
			for i in 7:
				var lc: Color = [Color("39f0a0"), Color("05d9e8"), Color("ff3b4f")][(i + h0) % 3]
				box(mat("dark", f, false, {"glow": 1.8, "emit": lc}), p + Vector3(-0.2 + (i % 2) * 0.4, 0.25 + i * 0.18, 0.43).rotated(Vector3.UP, yaw), Vector3(0.28, 0.03, 0.01), yaw)
			box(mat("dark", f, false, {"glow": 1.2, "emit": Color("05d9e8")}), p + Vector3(0, 1.52, 0), Vector3(0.7, 0.03, 0.7), yaw)
		"generator":   # a diesel genset: housing, exhaust, warning stripes
			box(mat("steel", f, false, {"color": Color("8a6a1a")}), p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.7), yaw)
			box(mat("steel", f, false, {"color": Color("2a2a2a")}), p + Vector3(0, 0.1, 0), Vector3(0.95, 0.2, 0.75), yaw)
			put("cyl", mat("steel", f, false, {"color": Color("4a4a4a")}), Transform3D(Basis.from_scale(Vector3(0.14, 0.7, 0.14)), p + Vector3(0.3, 1.1, 0.2)))
			box(mat("dark", f, false, {"glow": 2.0, "emit": Color("ffb02e")}), p + Vector3(0, 0.75, 0.36).rotated(Vector3.UP, yaw), Vector3(0.2, 0.08, 0.01), yaw)
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
		"aa_gun":   # a deck mount: armoured ring, turret, twin barrels raised to the sky
			var gray := mat("steel", f, false, {"color": Color("4a5056")})
			put("cyl", gray, Transform3D(Basis.from_scale(Vector3(0.95, 0.3, 0.95)), p + Vector3(0, 0.15, 0)))
			box(gray, p + Vector3(0, 0.5, 0), Vector3(0.6, 0.4, 0.55), yaw)
			for sx in [-0.14, 0.14]:
				var tip := Vector3(sx, 0, 0).rotated(Vector3.UP, yaw)
				put("cyl", D, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.75) * Basis.from_scale(Vector3(0.09, 1.3, 0.09)), p + tip + Vector3(0, 0.95, 0) + Vector3(0, 0, -0.3).rotated(Vector3.UP, yaw)))
			box(mat("dark", f, false, {"glow": 2.0, "emit": Color("ff3030")}), p + Vector3(0, 0.72, 0.28).rotated(Vector3.UP, yaw), Vector3(0.12, 0.05, 0.02), yaw)
		"cyberbike":   # an aerodyne cyberbike on its pad: a low fairing over two lift fans
			box(mat("steel", f, false, {"color": Color("8a1a1a")}), p + Vector3(0, 0.35, 0), Vector3(0.95, 0.22, 0.32), yaw)
			for e in [-0.38, 0.38]:
				put("cyl", D, Transform3D(Basis.from_scale(Vector3(0.34, 0.1, 0.34)), p + Vector3(e, 0.25, 0).rotated(Vector3.UP, yaw)))
				put("cyl", mat("dark", f, false, {"glow": 1.6, "emit": Color("4fd8ff")}), Transform3D(Basis.from_scale(Vector3(0.26, 0.02, 0.26)), p + Vector3(e, 0.19, 0).rotated(Vector3.UP, yaw)))
			box(mat("glass", f, false, {"color": Color("0e1820"), "alpha": 0.85}), p + Vector3(-0.1, 0.52, 0).rotated(Vector3.UP, yaw), Vector3(0.3, 0.12, 0.24), yaw)
		"stack":   # industrial exhaust: a tall banded flue with a warning light
			put("cyl", mat("steel", f, false, {"color": Color("5a5650")}), Transform3D(Basis.from_scale(Vector3(0.5, 2.2, 0.5)), p + Vector3(0, 1.1, 0)))
			for hb in [0.6, 1.5]:
				put("cyl", mat("steel", f, false, {"color": Color("8a3a22")}), Transform3D(Basis.from_scale(Vector3(0.54, 0.14, 0.54)), p + Vector3(0, hb, 0)))
			box(mat("dark", f, false, {"glow": 2.5, "emit": Color("ff2020")}), p + Vector3(0, 2.25, 0), Vector3(0.08, 0.08, 0.08))
		_:
			if SetPieceDressing.has_piece(kind):   # a set piece's own prop (cupola, mast, ...)
				SetPieceDressing.piece(self, kind, p, yaw, f, h0)
				return
			if ParkDressing.has_piece(kind):   # a theme park's (rides, booths, fake pines)
				ParkDressing.piece(self, kind, p, yaw, f, h0)
				return
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
		"scaffold":   # construction scaffolding: tubes, two plank decks, braces and green netting
			var tube := mat("steel", f, false, {"color": Color("8a7a5a")})
			var along := Vector3(cos(yaw), 0, -sin(yaw))
			var across := Vector3(sin(yaw), 0, cos(yaw))
			for i in 3:
				for s in [-1, 1]:
					var pp: Vector3 = c + along * (L * (i / 2.0 - 0.5) * 0.9) + across * (s * Wd * 0.35)
					box(tube, pp + Vector3(0, 1.3, 0), Vector3(0.05, 2.6, 0.05))
			for lv in [0.9, 1.8]:
				box(mat("wood", f, false), c + Vector3(0, lv, 0), Vector3(L * 0.92, 0.05, Wd * 0.7), yaw)
				box(tube, c + across * (Wd * 0.35) + Vector3(0, lv + 0.45, 0), Vector3(L * 0.92, 0.04, 0.04), yaw)
			box(tube, c + across * (-Wd * 0.35) + Vector3(0, 1.3, 0), Vector3(L * 0.95, 0.04, 0.04), yaw + 0.0)
			box(mat("fabric", f, false, {"color": Color("2a5a3a"), "alpha": 0.75}), c + across * (Wd * 0.38) + Vector3(0, 1.4, 0), Vector3(L * 0.9, 2.2, 0.02), yaw)
		"water_tank":   # a timber-hooped tank on a steel frame, conical cap
			var tc := mat("wood", f, false, {"color": Color("5a4430")}) if h0 % 2 == 0 else mat("steel", f, false, {"color": Color("6a6e70")})
			for s in [-1, 1]:
				for e in [-1, 1]:
					box(mat("steel", f, false, {"color": Color("2a2c30")}), c + Vector3(e * Wd * 0.3, 0.3, s * Wd * 0.3), Vector3(0.08, 0.6, 0.08))
			box(mat("steel", f, false, {"color": Color("2a2c30")}), c + Vector3(0, 0.6, 0), Vector3(Wd * 0.75, 0.08, Wd * 0.75))
			put("cyl", tc, Transform3D(Basis.from_scale(Vector3(Wd * 0.78, 1.0, Wd * 0.78)), c + Vector3(0, 1.15, 0)))
			for hb in [0.85, 1.15, 1.45]:
				put("cyl", mat("dark", f, false), Transform3D(Basis.from_scale(Vector3(Wd * 0.8, 0.04, Wd * 0.8)), c + Vector3(0, hb, 0)))
			put("cyl", mat("steel", f, false, {"color": Color("3a3c40")}), Transform3D(Basis.from_scale(Vector3(Wd * 0.82, 0.12, Wd * 0.82)), c + Vector3(0, 1.71, 0)))
		"roof_hut":   # a corrugated shed with a lit door
			var hc: Color = [Color("4a5058"), Color("5a4a3a"), Color("3a4a44"), Color("5a3a3a")][h0 % 4]
			box(mat("steel", f, false, {"color": hc, "pattern": 8, "color2": hc.darkened(0.4)}), c + Vector3(0, 0.6, 0), Vector3(L * 0.9, 1.2, Wd * 0.88), yaw)
			box(mat("steel", f, false, {"color": hc.darkened(0.35)}), c + Vector3(0, 1.24, 0), Vector3(L * 0.98, 0.08, Wd * 0.96), yaw)
			box(mat("dark", f, false, {"glow": 1.6, "emit": Color("ffc890")}), c + Vector3(0, 0.5, Wd * 0.45).rotated(Vector3.UP, yaw), Vector3(0.45, 0.85, 0.02), yaw)
			emitters.append({"cell": Vector3i(int(c.x), int(c.z), f), "color": Color("ffc890"), "energy": 0.6, "range": 2.5, "out": Vector2i.ZERO})
		"solar":
			box(mat("steel", f, false, {"color": Color("2a2c30")}), c + Vector3(0, 0.2, 0), Vector3(L * 0.85, 0.06, Wd * 0.2), yaw)
			var pb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT if long_x else Vector3.FORWARD, 0.45)
			put("box", mat("glass", f, false, {"color": Color("1a2a4a"), "alpha": 0.95, "glow": 0.25, "emit": Color("2a4a7a")}), Transform3D(pb.scaled_local(Vector3(L * 0.9 if long_x else Wd * 0.85, 0.05, Wd * 0.85 if long_x else L * 0.9)), c + Vector3(0, 0.38, 0)))
		"container", "freight_car":
			var col: Color = [Color("6a3428"), Color("284a6a"), Color("6a6028"), Color("2a5a3a"), Color("5a5a5e")][h0 % 5]
			var h := 1.25 if kind == "container" else 1.3
			box(mat("container", f, false, {"color": col}), c + Vector3(0, h / 2 + (0.2 if kind == "freight_car" else 0.0), 0), Vector3(L * 0.97, h, Wd * 0.92), yaw)
			if kind == "freight_car":
				box(mat("dark", f, false), c + Vector3(0, 0.1, 0), Vector3(L * 0.9, 0.2, Wd * 0.6), yaw)
		_:
			if SetPieceDressing.has_piece(kind):
				SetPieceDressing.multi(self, kind, r, f, h0)
			elif kind in ParkDressing.MULTI:
				ParkDressing.multi(self, kind, r, f, h0)
			else:
				_piece(kind, c, yaw, f, h0)


# --- Off-grid clutter --------------------------------------------------------------------

func _street_clutter() -> void:
	rng.seed = m.seed_value * 977
	var D := mat("dark", street, false)
	var count := int(m.w * m.h * 0.035 * grime)
	for i in count:
		var p := Vector2(rng.randf_range(0, m.w), rng.randf_range(0, m.h))
		var c := Vector2i(int(p.x), int(p.y))
		if not m.inb(c.x, c.y) or m.t(street, c.x, c.y) != TacMap.T.OUTSIDE or m.has_cover_at(street, c):
			continue
		var roll := rng.randf()
		if roll < 0.4:   # trash bags in little heaps
			for j in rng.randi_range(1, 3):
				put("sphere", mat("dark", street, false, {"color": Color("101418")}), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(0.28, 0.22, 0.24)), Vector3(p.x + rng.randf_range(-0.2, 0.2), gy + 0.09, p.y + rng.randf_range(-0.2, 0.2))))
		elif roll < 0.8:  # paper, flyers
			box(mat("wall_int", street, false, {"color": Color("3a3632")}), Vector3(p.x, gy + 0.012, p.y), Vector3(0.14, 0.004, 0.2), rng.randf() * TAU)
		else:             # manhole / drain
			put("cyl", D, Transform3D(Basis.from_scale(Vector3(0.4, 0.01, 0.4)), Vector3(p.x, gy + 0.005, p.y)))
	# overhead cables between facing exterior walls across streets
	for i in int(m.w * m.h / 160 * minf(grime, 1.5)):
		var x := rng.randi_range(1, m.w - 2)
		var y := rng.randi_range(1, m.h - 2)
		if m.t(street, x, y) != TacMap.T.OUTSIDE:
			continue
		var horiz := rng.randf() < 0.5
		var d := Vector2i(1, 0) if horiz else Vector2i(0, 1)
		var a := Vector2i(x, y)
		var b := Vector2i(x, y)
		while m.inb(a.x, a.y) and m.t(street, a.x, a.y) == TacMap.T.OUTSIDE:
			a -= d
		while m.inb(b.x, b.y) and m.t(street, b.x, b.y) == TacMap.T.OUTSIDE:
			b += d
		if not (m.inb(a.x, a.y) and m.inb(b.x, b.y)) or m.t(street, a.x, a.y) != TacMap.T.WALL or m.t(street, b.x, b.y) != TacMap.T.WALL:
			continue
		var span := Vector2(b - a).length()
		if span < 4 or span > 18:
			continue
		var h := gy + FH * rng.randf_range(0.85, 1.6)
		var mid := Vector2(a + b) / 2.0 + Vector2(0.5, 0.5)
		for k in rng.randi_range(1, 3):
			box(D, Vector3(mid.x, h - 0.15 - k * 0.07, mid.y), Vector3(span, 0.015, 0.015) if horiz else Vector3(0.015, 0.015, span))


## Roof clutter: AC units, vents, water tanks and antennas scattered off-grid on ROOF tiles,
## with a parapet around roof edges.
func _roof_clutter(f: int) -> void:
	var y0 := f * FH
	var S := mat("steel", f)
	_billboards(f)
	_roof_marks(f)
	for y in m.h:
		for x in m.w:
			if m.t(f, x, y) != TacMap.T.ROOF:
				continue
			for d in MapGen.DIRS:
				var n: Vector2i = Vector2i(x, y) + d
				if not m.inb(n.x, n.y) or m.t(f, n.x, n.y) in [TacMap.T.VOID, TacMap.T.OUTSIDE]:
					var off := Vector3(d.x, 0, d.y) * 0.44
					box(mat("cornice", f, true, _trim_look(_sid_grid[y * m.w + x], {"shell": true})), Vector3(x + 0.5, y0 + 0.14, y + 0.5) + off, Vector3(1.0 if d.x == 0 else 0.12, 0.28, 1.0 if d.y == 0 else 0.12))
			rng.seed = hash(Vector3i(x, y, f)) + 5
			var roll := rng.randf()
			var p := Vector3(x + rng.randf_range(0.2, 0.8), y0, y + rng.randf_range(0.2, 0.8))
			if m.has_cover_at(f, Vector2i(x, y)):
				continue
			if roll < 0.05:
				pass   # (rooftop tanks are real cover pieces now)
			elif roll < 0.056:   # aerial masts: a rare red-tipped few, not dozens
				box(mat("dark", f), p + Vector3(0, 0.45, 0), Vector3(0.03, 0.9, 0.03))
				box(mat("dark", f, true, {"glow": 1.2, "emit": Color("ff2020")}), p + Vector3(0, 0.92, 0), Vector3(0.06, 0.06, 0.06))
			elif roll < 0.16:
				box(S, p + Vector3(0, 0.12, 0), Vector3(0.3, 0.24, 0.3), rng.randf())
			elif roll < 0.172:   # skylight glowing from the room below (sparse: they read as noise in numbers)
				var sk: Color = [Color("ffc890"), Color("ffb070")][rng.randi() % 2]
				box(mat("frame", f), Vector3(x + 0.5, y0 + 0.03, y + 0.5), Vector3(0.66, 0.06, 0.66))
				for q in [Vector2(-0.14, -0.14), Vector2(0.14, -0.14), Vector2(-0.14, 0.14), Vector2(0.14, 0.14)]:   # four panes in a frame
					box(mat("dark", f, true, {"glow": 0.45, "emit": sk}), Vector3(x + 0.5 + q.x, y0 + 0.065, y + 0.5 + q.y), Vector3(0.22, 0.02, 0.22))
				emitters.append({"cell": Vector3i(x, y, f), "color": sk, "energy": 0.8, "range": 2.5, "out": Vector2i.ZERO})


## Painted roof markings by site: a lit helipad on corp towers, skylight strips glowing from the
## hall below on industrial roofs. Flat, so nothing on the roof is blocked.
func _roof_marks(f: int) -> void:
	var y0 := f * FH
	var boxes := {}   # structure → its roof squares' bounds on this level
	for y in m.h:
		for x in m.w:
			if m.t(f, x, y) == TacMap.T.ROOF and _sid_grid[y * m.w + x] >= 0 and f > 0 and m.t(f - 1, x, y) != TacMap.T.ROOF:
				var sid := _sid_grid[y * m.w + x]
				boxes[sid] = Rect2i(x, y, 1, 1) if not boxes.has(sid) else (boxes[sid] as Rect2i).expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	for sid in boxes:
		var r: Rect2i = boxes[sid]
		var site := _site_of(sid)
		if site in ["corp_hq", "corp_office"] and mini(r.size.x, r.size.y) >= 8 and f + 1 >= m.floors and String(_sp_look(sid).get("roof_mark", "")) != "none":
			var c := Vector3(r.get_center().x, y0 + 0.02, r.get_center().y)
			var paint := mat("dark", f, true, {"color": Color("d8d4c8"), "glow": 0.3, "emit": Color("d8d4c8")})
			for i in 16:   # the ring
				var a := TAU * i / 16.0
				box(paint, c + Vector3(cos(a), 0, sin(a)) * 2.2, Vector3(0.18, 0.02, 0.9), -a)
			box(paint, c + Vector3(-0.55, 0, 0), Vector3(0.18, 0.02, 1.6))
			box(paint, c + Vector3(0.55, 0, 0), Vector3(0.18, 0.02, 1.6))
			box(paint, c, Vector3(1.1, 0.02, 0.18))
			for i in 8:   # edge lights
				var a2 := TAU * i / 8.0
				box(mat("dark", f, true, {"glow": 2.5, "emit": Color("ffc040")}), c + Vector3(cos(a2), 0.04, sin(a2)) * 3.0, Vector3(0.1, 0.06, 0.1))
			emitters.append({"cell": Vector3i(int(c.x), int(c.z), f), "color": Color("ffc040"), "energy": 0.8, "range": 4.0, "out": Vector2i.ZERO})
		elif site in ["warehouse", "factory"]:
			var along_x := r.size.x >= r.size.y
			var n := maxi(1, (r.size.y if along_x else r.size.x) / 4)
			for i in n:
				var off := (i + 0.5) * (r.size.y if along_x else r.size.x) / float(n)
				var sk := Vector3(r.get_center().x, y0 + 0.03, r.position.y + off) if along_x else Vector3(r.position.x + off, y0 + 0.03, r.get_center().y)
				var ln := (r.size.x if along_x else r.size.y) - 3.0
				box(mat("dark", f, true, {"glow": 0.9, "emit": Color("ffd8a0")}), sk, Vector3(ln, 0.04, 0.5) if along_x else Vector3(0.5, 0.04, ln))
				box(mat("frame", f), sk + Vector3(0, 0.03, 0), Vector3(ln, 0.03, 0.06) if along_x else Vector3(0.06, 0.03, ln))


## One rooftop billboard per structure: two posts and a big neon panel, with light spill.
func _billboards(f: int) -> void:
	var done := {}
	for y in m.h:
		for x in m.w:
			if m.t(f, x, y) != TacMap.T.ROOF:
				continue
			var sid := _structure_at(f, x, y)
			if done.has(sid):
				continue
			# a roof edge square facing open air
			var face := Vector2i.ZERO
			for d in MapGen.DIRS:
				var n: Vector2i = Vector2i(x, y) + d
				if not m.inb(n.x, n.y) or m.t(f, n.x, n.y) == TacMap.T.VOID:
					face = d
			if face == Vector2i.ZERO:
				continue
			rng.seed = hash(Vector3i(x, y, f)) + 99
			if rng.randf() >= 0.4 * signs:
				done[sid] = true
				continue
			done[sid] = true
			var col: Color = neon[rng.randi() % neon.size()]
			var c := Vector3(x + 0.5, f * FH, y + 0.5) - Vector3(face.x, 0, face.y) * 0.1
			var along := Vector3(0.9, 0, 0) if face.x == 0 else Vector3(0, 0, 0.9)
			for sgn in [-1, 1]:
				box(mat("post", f), c + along * 0.45 * sgn + Vector3(0, 0.45, 0), Vector3(0.05, 0.9, 0.05))
			box(mat("dark", f, true, {"glow": 1.5, "emit": col}), c + Vector3(0, 0.95, 0), Vector3(1.6, 0.6, 0.06) if face.x == 0 else Vector3(0.06, 0.6, 1.6))
			emitters.append({"cell": Vector3i(x, y, f), "color": col, "energy": 1.4, "range": 4.0, "out": Vector2i.ZERO})


func _structure_at(f: int, x: int, y: int) -> int:
	for d in [Vector2i.ZERO] + Nav.DIRS8:
		var l := m.label(f, x + d.x, y + d.y)
		if l >= 0:
			return int(m.rooms[l].structure)
	return -1


const HOMES := ["apartments", "capsule_hotel", "squat", "villa", "gang_hideout", "bar", "shop", "bd_parlor", "hotel"]


## Residential upper floors: a slab balcony with a railing outside some of the windows.
func _balconies(f: int) -> void:
	if f <= street:
		return
	var y0 := f * FH
	var slab := mat("concrete_prop", f, true, {"shell": true})
	var rail := mat("steel", f, true, {"color": Color("2a2e34"), "shell": true})
	for y in m.h:
		for x in m.w:
			var k := _wall_kind(f, x, y)
			if not (k in [5, 6]) or not (_site_of(_sid_grid[y * m.w + x]) in HOMES):
				continue
			if posmod(hash(Vector3i(x, y, f * 7 + 3)), 5) > 1:
				continue
			for d in MapGen.DIRS:
				var n: Vector2i = Vector2i(x, y) + d
				if not m.inb(n.x, n.y) or m.t(f, n.x, n.y) != TacMap.T.VOID:
					continue
				var out := Vector3(d.x, 0, d.y)
				var horiz := d.y != 0
				var c := Vector3(x + 0.5, y0, y + 0.5) + out * (EXT_T / 2 + 0.24)
				box(slab, c + Vector3(0, 0.03, 0), Vector3(1.1, 0.07, 0.5) if horiz else Vector3(0.5, 0.07, 1.1))
				box(rail, c + out * 0.23 + Vector3(0, 0.42, 0), Vector3(1.1, 0.03, 0.03) if horiz else Vector3(0.03, 0.03, 1.1))
				for sgn in [-1, 1]:
					var side: Vector3 = Vector3(-d.y, 0, d.x) * 0.53 * sgn
					box(rail, c + side + Vector3(0, 0.22, 0), Vector3(0.03, 0.4, 0.5) if horiz else Vector3(0.5, 0.4, 0.03))
				for i in 4:
					var off := Vector3(-d.y, 0, d.x) * (-0.45 + i * 0.3)
					box(rail, c + out * 0.23 + off + Vector3(0, 0.22, 0), Vector3(0.02, 0.4, 0.02))


var _escapes := {}   ## structure id → [cell, along, out, floors]: one fire escape per tall home


## A steel fire escape zig-zagging up one blank street-facing wall of residential buildings:
## a grated landing at each upper floor, a flight up to the next, a drop ladder at the bottom.
## Decoration (the climbable ladders are the rules' connectors).
func _fire_escape(f: int) -> void:
	if f <= street:
		if f == street:
			_plan_escapes()
		return
	var y0 := f * FH
	var steel := mat("steel", f, true, {"color": Color("30343a"), "shell": true})
	var grate := mat("floor_metal", f, true, {"color": Color("3a3e44"), "shell": true})
	for sid in _escapes:
		var e: Array = _escapes[sid]
		var floors: int = e[3]
		if f >= floors:
			continue
		var cell: Vector2i = e[0]
		var along: Vector3 = e[1]
		var out: Vector3 = e[2]
		var base := Vector3(cell.x + 0.5, y0, cell.y + 0.5) + out * (EXT_T / 2 + 0.38)
		var horiz := absf(along.x) > 0.5
		box(grate, base + Vector3(0, 0.02, 0), Vector3(2.8, 0.05, 0.7) if horiz else Vector3(0.7, 0.05, 2.8))
		box(steel, base + out * 0.34 + Vector3(0, 0.45, 0), Vector3(2.8, 0.03, 0.03) if horiz else Vector3(0.03, 0.03, 2.8))
		for i in 5:
			box(steel, base + out * 0.34 + along * (-1.35 + i * 0.675) + Vector3(0, 0.23, 0), Vector3(0.025, 0.44, 0.025))
		for sgn in [-1, 1]:   # brackets into the wall
			box(steel, base + along * (1.2 * sgn) - out * 0.2 + Vector3(0, -0.12, 0), Vector3(0.04, 0.24, 0.04) if horiz else Vector3(0.04, 0.24, 0.04))
		var dir := 1.0 if f % 2 == 0 else -1.0
		if f + 1 < floors:   # flight up to the next landing
			var x_dir := (along * dir * 2.0 + Vector3(0, FH, 0)).normalized()
			var ln := Vector2(2.0, FH).length()
			var z := out
			var yv := z.cross(x_dir).normalized()
			put("box", grate, Transform3D(Basis(x_dir * ln, yv * 0.05, z * 0.5), base + Vector3(0, FH / 2, 0) + out * 0.02))
		if f == 1:   # drop ladder, hanging short of the street
			for sgn in [-1, 1]:
				box(steel, base + along * (-1.1 * dir) + along * (0.18 * sgn) + Vector3(0, -0.75, 0), Vector3(0.025, 1.0, 0.025))
			for i in 5:
				box(steel, base + along * (-1.1 * dir) + Vector3(0, -0.3 - i * 0.2, 0), Vector3(0.36, 0.02, 0.02) if horiz else Vector3(0.02, 0.02, 0.36))


func _plan_escapes() -> void:
	_escapes.clear()
	var best := {}   # sid → [score, cell, d]
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			var sid := _sid_grid[y * m.w + x]
			if sid < 0 or not (_site_of(sid) in ["apartments", "squat", "capsule_hotel", "gang_hideout"]) or int(m.structures[sid].floors) < 2:
				continue
			for d in MapGen.DIRS:
				var along := Vector2i(-d.y, d.x)
				var ok := true
				for k in range(-1, 2):   # three blank wall squares on floor 1, the street below
					var w: Vector2i = Vector2i(x, y) + along * k
					if _wall_kind(1, w.x, w.y) in [-1, 3, 4, 5, 6] or m.t(1, w.x + d.x, w.y + d.y) != TacMap.T.VOID \
							or m.t(0, w.x + d.x, w.y + d.y) != TacMap.T.OUTSIDE or m.t(0, w.x, w.y) == TacMap.T.DOOR:
						ok = false
				if not ok:
					continue
				var score := posmod(hash(Vector3i(x, y, sid)), 1000)
				if not best.has(sid) or score > int(best[sid][0]):
					best[sid] = [score, Vector2i(x, y), d]
	for sid in best:
		var d: Vector2i = best[sid][2]
		_escapes[sid] = [best[sid][1], Vector3(-d.y, 0, d.x), Vector3(d.x, 0, d.y), int(m.structures[sid].floors)]


## Facades: AC units and pipes on exterior walls, posters, and tall vertical neon boards.
func _facade_dressing(f: int) -> void:
	_balconies(f)
	_fire_escape(f)
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
				if not ((f == street and nt == TacMap.T.OUTSIDE and m.label(f, n.x, n.y) < 0) or (f > street and nt == TacMap.T.VOID)):
					continue
				rng.seed = hash(Vector3i(x, y, f)) * 3 + d.x * 7 + d.y * 13
				var roll := rng.randf()
				if roll >= 0.06:   # the sign bands, stretched or squeezed by the district's sign density
					roll = 0.06 + (roll - 0.06) / signs if signs > 0.0 else 1.0
				var out := Vector3(d.x, 0, d.y)
				var along := rng.randf_range(-0.3, 0.3)
				var side := Vector3(-d.y, 0, d.x) * along
				var face := Vector3(x + 0.5, y0, y + 0.5) + out * (EXT_T / 2 + 0.01) + side
				if roll < 0.06 and f > street or (roll < 0.03):
					box(mat("steel", f, true, {"shell": true}), face + out * 0.14 + Vector3(0, rng.randf_range(0.8, 1.3), 0), Vector3(0.36, 0.26, 0.26))
				elif roll < 0.1:
					var col: Color = neon[rng.randi() % neon.size()]
					box(mat("dark", f, true, {"glow": 0.9, "emit": col.darkened(0.3), "color": col.darkened(0.6), "shell": true}), face + out * 0.005 + Vector3(0, rng.randf_range(0.4, 0.8), 0), Vector3(0.36 if d.x == 0 else 0.01, 0.46, 0.01 if d.x == 0 else 0.36))
				elif roll < 0.15:
					# blade sign sticking out of the facade, with light spill
					var col2: Color = neon[rng.randi() % neon.size()]
					var bl := Vector3(0.42, FH * 0.75, 0.06) if d.x != 0 else Vector3(0.06, FH * 0.75, 0.42)
					box(mat("dark", f, true, {"glow": 5.0, "emit": col2, "shell": true}), face + out * 0.3 + Vector3(0, FH * 0.55 + 0.2, 0), bl)
					emitters.append({"cell": Vector3i(n.x, n.y, street), "color": col2, "energy": 1.4, "range": 5.0, "out": Vector2i.ZERO})
				elif roll < 0.2 and f == street:
					# awning over a lit shop window
					var col3: Color = [Color("ffb070"), Color("ff6b9a"), Color("70e0ff")][rng.randi() % 3]
					var wide := Vector3(0.95, 0.04, 0.5) if d.x == 0 else Vector3(0.5, 0.04, 0.95)
					box(mat("fabric", f, true, {"color": neon[rng.randi() % neon.size()].darkened(0.55), "shell": true}), face + out * 0.25 + Vector3(0, 1.22, 0), wide)
					box(mat("dark", f, true, {"glow": 4.0, "emit": col3, "shell": true}), face + out * 0.48 + Vector3(0, 1.2, 0), Vector3(0.95, 0.02, 0.02) if d.x == 0 else Vector3(0.02, 0.02, 0.95))
					box(mat("dark", f, true, {"glow": 1.6, "emit": col3, "shell": true}), face + out * 0.01 + Vector3(0, 0.62, 0), Vector3(0.7, 0.6, 0.01) if d.x == 0 else Vector3(0.01, 0.6, 0.7))
					emitters.append({"cell": Vector3i(n.x, n.y, street), "color": col3, "energy": 1.1, "range": 4.0, "out": Vector2i.ZERO})
				elif roll < 0.16:
					box(mat("post", f, true, {"shell": true}), face + out * 0.05 + Vector3(0, FH / 2, 0), Vector3(0.05, FH, 0.05))


# --- Skyline -----------------------------------------------------------------------------

## Towers beyond the map edges with lit windows, rooftop beacons, and a far ground plane.
## Ground beyond the map edge, as a frame (a single slab under the map would hide its water,
## which sits below street level).
func _frame(mt: Material, margin: float) -> void:
	var y := -0.2
	box(mt, Vector3(m.w / 2.0, y, -margin / 2), Vector3(m.w + margin * 2, 0.1, margin))
	box(mt, Vector3(m.w / 2.0, y, m.h + margin / 2), Vector3(m.w + margin * 2, 0.1, margin))
	box(mt, Vector3(-margin / 2, y, m.h / 2.0), Vector3(margin, 0.1, m.h))
	box(mt, Vector3(m.w + margin / 2, y, m.h / 2.0), Vector3(margin, 0.1, m.h))


## What surrounds the map (SceneTheme): lit towers by default, desert for open country.
func _surround() -> String:
	return String(SceneTheme.of(m).get("surround", "desert" if natural else "skyline"))


## Undercity: the solid ground between the tunnels, a block up to wall height over every VOID
## square on the ground floor (greedy rectangles), so the tunnel network reads as cut into rock.
func _bedrock() -> void:
	var mt := mat("bedrock", 0)
	var done := {}
	for y in m.h:
		for x in m.w:
			if done.has(Vector2i(x, y)) or m.t(0, x, y) != TacMap.T.VOID:
				continue
			var w := 1
			while x + w < m.w and m.t(0, x + w, y) == TacMap.T.VOID and not done.has(Vector2i(x + w, y)):
				w += 1
			var h := 1
			var grow := true
			while grow and y + h < m.h:
				for xx in range(x, x + w):
					if m.t(0, xx, y + h) != TacMap.T.VOID or done.has(Vector2i(xx, y + h)):
						grow = false
						break
				if grow:
					h += 1
			for yy in range(y, y + h):
				for xx in range(x, x + w):
					done[Vector2i(xx, yy)] = true
			box(mt, Vector3(x + w / 2.0, FH / 2, y + h / 2.0), Vector3(w, FH, h))
	# pipes and conduit along the tunnel walls, in runs: the city's plumbing overhead
	var pipe := mat("steel", 0, true, {"color": Color("3a4a40")})
	var rust := mat("steel", 0, true, {"color": Color("6a3e24")})
	var conduit := mat("dark", 0, true, {"color": Color("1a1e1a")})
	for y in m.h:
		for x in m.w:
			if m.t(0, x, y) != TacMap.T.WALL:
				continue
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var o: Vector2i = Vector2i(x, y) + d
				if not m.inb(o.x, o.y) or m.t(0, o.x, o.y) != TacMap.T.OUTSIDE:
					continue
				var horiz: bool = d.y != 0   # the wall runs along x
				var line := y if horiz else x
				var seg := (x if horiz else y) / 7
				var hv := hash(Vector3i(line * 4 + d.x + 2 * d.y + 3, seg, m.seed_value)) % 5
				if hv >= 3:
					continue
				var off := Vector3(d.x, 0, d.y) * 0.3
				var b := Basis(Vector3.FORWARD, PI / 2) if horiz else Basis(Vector3.RIGHT, PI / 2)
				var c := Vector3(x + 0.5, 0, y + 0.5) + off
				put("cyl", rust if hv == 0 else pipe, Transform3D(b.scaled_local(Vector3(0.13, 1.0, 0.13)), c + Vector3(0, FH * 0.78, 0)))
				if hv == 1:
					put("cyl", conduit, Transform3D(b.scaled_local(Vector3(0.06, 1.0, 0.06)), c + Vector3(0, FH * 0.64, 0) + off * 0.2))


## Beyond the undercity map: more rock at wall height, and a dark floor under it.
func _bedrock_ring() -> void:
	var r := mat("bedrock", 0, false, {"mode": 2})
	_frame(mat("far_ground", 0, false, {"color": Color("0a0c0a")}), 60.0)
	var ring := 40.0
	box(r, Vector3(m.w / 2.0, FH / 2, -ring / 2), Vector3(m.w + ring * 2, FH, ring))
	box(r, Vector3(m.w / 2.0, FH / 2, m.h + ring / 2), Vector3(m.w + ring * 2, FH, ring))
	box(r, Vector3(-ring / 2, FH / 2, m.h / 2.0), Vector3(ring, FH, m.h))
	box(r, Vector3(m.w + ring / 2, FH / 2, m.h / 2.0), Vector3(ring, FH, m.h))


## Arcology: the concourse sits at the bottom of a huge white atrium. The walls around the map
## rise in tiers (balcony bands of dark glass), cut by red light strips; light pours from above.
func _atrium() -> void:
	rng.seed = m.seed_value * 13 + 1
	var floor_m := mat("atrium", 0, false, {"color": Color("c8c8c4")})
	_frame(floor_m, 60.0)
	var wall := mat("atrium", 0, false, {"near_fade": true})
	var band := mat("dark", 0, false, {"mode": 2, "near_fade": true, "color": Color("1a2028"), "glow": 0.5, "emit": Color("4a6a88")})
	var red := mat("dark", 0, false, {"mode": 2, "near_fade": true, "glow": 1.6, "emit": Color("ff2030")})
	var white := mat("dark", 0, false, {"mode": 2, "near_fade": true, "glow": 1.4, "emit": Color("f0f6ff")})
	var gap := 12.0
	var H := 14.0
	var sides := [[Vector3(m.w / 2.0, 0, -gap - 2), Vector3(m.w + gap * 2 + 8, 0, 4), true],
		[Vector3(m.w / 2.0, 0, m.h + gap + 2), Vector3(m.w + gap * 2 + 8, 0, 4), true],
		[Vector3(-gap - 2, 0, m.h / 2.0), Vector3(4, 0, m.h + gap * 2), false],
		[Vector3(m.w + gap + 2, 0, m.h / 2.0), Vector3(4, 0, m.h + gap * 2), false]]
	for sd in sides:
		var c: Vector3 = sd[0]
		var sz: Vector3 = sd[1]
		var horiz: bool = sd[2]
		box(wall, c + Vector3(0, H / 2, 0), Vector3(sz.x, H, sz.z))
		var inward := Vector3(0, 0, 1 if c.z < 0 else -1) if horiz else Vector3(1 if c.x < 0 else -1, 0, 0)
		var face := c + inward * 2.05
		for lv in [2.6, 5.4, 8.2, 11.0]:   # balcony tiers: dark glass with a lit soffit
			box(band, face + Vector3(0, lv, 0), Vector3(sz.x, 1.1, 0.1) if horiz else Vector3(0.1, 1.1, sz.z))
			box(white, face + inward * 0.06 + Vector3(0, lv - 0.62, 0), Vector3(sz.x, 0.06, 0.06) if horiz else Vector3(0.06, 0.06, sz.z))
		var span := sz.x if horiz else sz.z
		var n := int(span / 11.0)
		for i in n + 1:   # red light strips and columns
			var t := -span / 2 + span * i / maxf(1, n)
			var p := face + (Vector3(t, 0, 0) if horiz else Vector3(0, 0, t))
			box(wall, p + inward * 0.4 + Vector3(0, H / 2, 0), Vector3(1.2, H, 0.8) if horiz else Vector3(0.8, H, 1.2))
			box(red, p + inward * 0.82 + Vector3(0, H / 2, 0), Vector3(0.14, H, 0.04) if horiz else Vector3(0.04, H, 0.14))
		# a corporate banner or two hanging in the void
		for k in 2:
			var t2 := rng.randf_range(-span / 3, span / 3)
			var bp := face + inward * 0.2 + (Vector3(t2, 0, 0) if horiz else Vector3(0, 0, t2))
			box(mat("dark", 0, false, {"mode": 2, "near_fade": true, "color": Color("8a0a1c"), "glow": 0.5, "emit": Color("c8102e")}), bp + Vector3(0, 8.0, 0), Vector3(2.4, 5.0, 0.05) if horiz else Vector3(0.05, 5.0, 2.4))
			box(white, bp + inward * 0.04 + Vector3(0, 9.4, 0), Vector3(1.2, 1.2, 0.03) if horiz else Vector3(0.03, 1.2, 1.2))


func _skyline(ruins := false) -> void:
	rng.seed = m.seed_value * 13 + 1
	var far := mat("far_ground", 0, false)
	var margin := 60.0
	_frame(far, margin)
	var T := mat("tower", 0, false, {"near_fade": true} if ruins else {})
	var top := mat("tower_top", 0, false, {"near_fade": true} if ruins else {})
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
		h = minf(h, dist * 0.7 + 1.0)   # the near ring never hides the map at the lowest camera pitch
		box(T, Vector3(p.x, h / 2 - 0.2, p.y), Vector3(w, h, d))
		box(top, Vector3(p.x, h - 0.15, p.y), Vector3(w * 0.7, 0.4, d * 0.7))
		box(mat("cornice", 0, false, {"mode": 2, "color": Color("2a3040")}), Vector3(p.x, h - 0.2, p.y), Vector3(w + 0.15, 0.12, d + 0.15))
		if ruins:   # gutted towers: broken tops, burning floors, no neon
			for k in rng.randi_range(1, 3):   # broken stumps on the roof, inside the height limit
				var bw := minf(w * rng.randf_range(0.2, 0.5), h * 0.4)
				box(T, Vector3(p.x + rng.randf_range(-w, w) * 0.3, h - bw * 0.2, p.y + rng.randf_range(-d, d) * 0.3), Vector3(bw, bw * 0.8, bw))
			if rng.randf() < 0.45 and dist > 14.0:   # burning floors, on the farther towers only
				var fl := rng.randf_range(0.3, 0.85) * h
				var toward2 := Vector2(m.w / 2.0, m.h / 2.0) - p
				var face2 := Vector3(signf(toward2.x) * (w / 2 + 0.05), 0, 0) if absf(toward2.x) > absf(toward2.y) else Vector3(0, 0, signf(toward2.y) * (d / 2 + 0.05))
				var fc: Color = [Color("ff6b1a"), Color("ff8a30"), Color("ffb040")][rng.randi() % 3]
				var span2 := (d if face2.x != 0 else w) * rng.randf_range(0.3, 0.8)
				box(mat("dark", 0, false, {"glow": 1.6, "emit": fc, "mode": 2, "near_fade": true}), Vector3(p.x, fl, p.y) + face2,
					Vector3(0.05, rng.randf_range(0.8, 2.4), span2) if face2.x != 0 else Vector3(span2, rng.randf_range(0.8, 2.4), 0.05))
			if rng.randf() < 0.2 and dist > 14.0:
				box(mat("dark", 0, false, {"glow": 1.6, "emit": Color("ff7a24"), "mode": 2, "near_fade": true}), Vector3(p.x, h + 0.1, p.y), Vector3(w * 0.5, 0.3, d * 0.5))
			continue
		if rng.randf() < 0.25 * signs:   # a vertical neon edge so the mass has an outline
			var sc: Color = neon[rng.randi() % neon.size()]
			box(mat("dark", 0, false, {"glow": 1.4, "emit": sc, "mode": 2}), Vector3(p.x + w / 2, h / 2, p.y + d / 2), Vector3(0.12, h, 0.12))
		if rng.randf() < 0.35:
			box(mat("dark", 0, false, {"glow": 1.2, "emit": Color("ff2020"), "mode": 2}), Vector3(p.x, h + 0.1, p.y), Vector3(0.08, 0.08, 0.08))
		if rng.randf() < 0.3 * signs:   # a billboard: a big emissive panel on the face toward the map
			var col: Color = neon[rng.randi() % neon.size()]
			var toward := Vector2(m.w / 2.0, m.h / 2.0) - p
			var face := Vector3(signf(toward.x) * (w / 2 + 0.05), 0, 0) if absf(toward.x) > absf(toward.y) else Vector3(0, 0, signf(toward.y) * (d / 2 + 0.05))
			var bw := minf(w, d) * 0.6
			box(mat("dark", 0, false, {"glow": 1.8, "emit": col, "mode": 2}), Vector3(p.x, h * rng.randf_range(0.45, 0.8), p.y) + face,
				Vector3(0.05, bw * 0.5, bw) if face.x != 0 else Vector3(bw, bw * 0.5, 0.05))


# --- Open country (badlands) ----------------------------------------------------------------

const ROCKS := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
var _desert_tex: Texture2D


## A modelled rock (Stylized Nature kit, CC0) with the kit's desert texture.
func _rock_model(at: Vector3, scl: Vector3, h0: int, f: int, over := {}) -> void:
	if _desert_tex == null:
		_desert_tex = load("res://assets/third_party/quaternius/nature/Rocks_Desert_Diffuse.png")
	rng.seed = h0
	var o := {"tex": _desert_tex, "flat": true}
	o.merge(over, true)
	var b := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)).scaled_local(scl)
	nature(ROCKS[rng.randi() % ROCKS.size()], Transform3D(b, at), f, o)


## Dead and twisted trees, dry scrub, straw grass and pebbles on open ground; decoration only (no
## cover, no blocking), so they never disagree with the rules.
func _nature_scatter() -> void:
	var straw := Color(1.05, 0.82, 0.55)
	var dry := Color(0.8, 0.7, 0.5)
	for y in m.h:
		for x in m.w:
			if m.t(0, x, y) != TacMap.T.OUTSIDE or m.label(0, x, y) >= 0 or m.has_cover_at(0, Vector2i(x, y)):
				continue
			var g := int(m.ground[y * m.w + x])
			if g not in [TacMap.G.SAND, TacMap.G.DIRT, TacMap.G.GRAVEL]:
				continue
			rng.seed = hash(Vector3i(x, y, 77))
			var roll := rng.randf()
			var p := Vector3(x + rng.randf_range(0.2, 0.8), -0.02, y + rng.randf_range(0.2, 0.8))
			var yaw := Basis(Vector3.UP, rng.randf() * TAU)
			if roll < 0.018 and g != TacMap.G.DIRT:
				var s := rng.randf_range(0.11, 0.17)
				nature("DeadTree_%d" % (1 + rng.randi() % 5), Transform3D(yaw.scaled_local(Vector3.ONE * s), p), 0, {"color": Color(0.85, 0.75, 0.65)})
			elif roll < 0.026 and g != TacMap.G.DIRT:
				var s := rng.randf_range(0.1, 0.14)
				nature("TwistedTree_%d" % (1 + rng.randi() % 3), Transform3D(yaw.scaled_local(Vector3.ONE * s), p), 0, {"color": dry})
			elif roll < 0.07:
				nature("Plant_7", Transform3D(yaw.scaled_local(Vector3.ONE * rng.randf_range(0.18, 0.3)), p), 0, {"color": dry})
			elif roll < 0.2:
				nature("Grass_Wispy_Tall" if rng.randf() < 0.5 else "Grass_Wispy_Short", Transform3D(yaw.scaled_local(Vector3.ONE * rng.randf_range(0.22, 0.38)), p), 0, {"color": straw})
			elif roll < 0.3:
				var pb := ["Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3", "Pebble_Square_1", "Pebble_Square_2"]
				nature(pb[rng.randi() % pb.size()], Transform3D(yaw.scaled_local(Vector3.ONE * rng.randf_range(0.12, 0.25)), p), 0, {"tex": _desert_tex if _desert_tex else null})


## Buttes on the horizon: tapered, faceted, banded; a ring of talus rocks round each base.
func _mesas() -> void:
	rng.seed = m.seed_value * 17 + 3
	var placed: Array[Rect2] = []
	for i in 60:
		var side := rng.randi() % 4
		var dist := rng.randf_range(12.0, 110.0)
		var r := rng.randf_range(5.0, 16.0)
		var p := Vector2.ZERO
		match side:
			0: p = Vector2(rng.randf_range(-60, m.w + 60), -dist - r)
			1: p = Vector2(rng.randf_range(-60, m.w + 60), m.h + dist + r)
			2: p = Vector2(-dist - r, rng.randf_range(-60, m.h + 60))
			3: p = Vector2(m.w + dist + r, rng.randf_range(-60, m.h + 60))
		var rect := Rect2(p - Vector2(r, r), Vector2(r, r) * 2)
		if placed.any(func(q: Rect2) -> bool: return q.grow(2.0).intersects(rect)):
			continue
		placed.append(rect)
		var h := rng.randf_range(4.0, 9.0) + dist * rng.randf_range(0.08, 0.2)
		h = minf(h, dist * 0.55 + 2.0)   # the near ones stay low so they never hide the map
		put("mesa", mat("mesa", 0, false), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(r * 2, h, r * 2)), Vector3(p.x, h / 2 - 0.2, p.y)))
		for k in 4:
			var a := rng.randf() * TAU
			var tp := Vector3(p.x + cos(a) * r * 1.05, -0.2, p.y + sin(a) * r * 1.05)
			_rock_model(tp, Vector3.ONE * rng.randf_range(0.8, 1.8), hash(Vector3i(i, k, 5)), 0, {"mode": 2, "offmap": true})


# --- Rock ----------------------------------------------------------------------------------

## Rock walls (material 4) become heaps of jittered boulders: 2-3 per square, overlapping.
func _rocks() -> void:
	for y in m.h:
		for x in m.w:
			if _wall_kind(0, x, y) != 4:
				continue
			if natural:   # modelled rock, rising toward the middle of each outcrop like a low cliff
				var n := 0
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						if _wall_kind(0, x + dx, y + dy) == 4:
							n += 1
				var depth := clampf((n - 6) / 18.0, 0.0, 1.0)
				rng.seed = hash(Vector2i(x, y))
				var sxz := rng.randf_range(0.42, 0.56)
				var sy := rng.randf_range(0.35, 0.55) + depth * rng.randf_range(0.5, 1.1)
				_rock_model(Vector3(x + 0.5 + rng.randf_range(-0.15, 0.15), -0.05, y + 0.5 + rng.randf_range(-0.15, 0.15)), Vector3(sxz, sy, sxz), hash(Vector2i(x, y)), 0)
				continue
			for i in 3:
				rng.seed = hash(Vector2i(x, y)) + i
				var s := Vector3(rng.randf_range(0.8, 1.5), rng.randf_range(0.7, 1.9), rng.randf_range(0.8, 1.5))
				var p := Vector3(x + rng.randf_range(0.2, 0.8), s.y * 0.35, y + rng.randf_range(0.2, 0.8))
				put("rock", mat("rock", 0, false), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)).scaled_local(s), p))
