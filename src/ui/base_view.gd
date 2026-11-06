class_name BaseView
extends Control
## The safehouse as a place (owner: tactile, physical, upgrades and the crew visible, same pixel
## style). A converted floor of an old block, built from Quaternius' CC0 sci-fi kits (modular walls,
## floor plates, desks, lockers, shelving, crates, computers...) at the tactical view's scale (a
## character stands ~1.15 units; kit metres x KIT), seen through the same low-res palette pipeline.
##
## Layout on a 2.4-unit module grid: three rooms north of a corridor (Med Bay, Armory, Fixer Network),
## three south (Training Room, Workshop, Bunks). Rooms are places with no levels or effects; the
## workshop stays dark storage (tarped crates) until a Tech joins the crew.
## Seen square-on from the south at a fixed angle (owner: 0° yaw, no rotation or zoom). Walls are
## kit walls on the far (north and west) sides and waist-high everywhere else, so every room reads
## from above. The crew stand where their downtime job puts them.
##
## The safehouse is the hub (owner's UI audit): every between-gigs function is a full screen opened
## from its room (src/ui/screens/): Fixer Network → jobs, hire, Night Market; Armory → storage and
## loadouts; Med Bay → ripperdoc, therapy, Critical Injuries; Training Room → Improvement Points;
## Bunks → the crew and resting; Workshop → the Tech's armor upgrades. No sidebars (owner): hovering
## a room highlights it and names what it holds; clicking opens its screen; click a crew member for
## theirs. The crew's state (HP, conditions, last-gig marks) is on the room screens it belongs to
## (Bunks, Med Bay, Training Room). After a gig the debrief screen comes first.
##
## Dev flags (with --shot=x.png for screenshots): --base stays here; --screen=<id> opens a screen
## (jobs, hire, market, city, storage, workshop, ripperdoc, therapy, injuries, training, crew, debrief);
## --crew=n selects crew member n on it; --hover=<room id> shows a room hovered; --demo uses
## DemoState's sample campaign (never saved); with it the Armory also takes --slot=<slot id>,
## --pick=<storage key>, --filter=<chip> (StorageScreen.setup) and --stash=<key,key> (more in storage), and the city map --district=<id> or
## --pin=<board index> (CityTab.setup).

const GB := preload("res://src/tactical/greybox.gd")
const POST_SHADER := preload("res://src/tactical/view/post.gdshader")
const GREYBOX := "res://scenes/greybox.tscn"
const KITS := "res://assets/third_party/quaternius/scifi/models/%s.gltf"
const GUNS := "res://assets/third_party/quaternius/guns/%s.fbx"
const DEV_FLAGS := ["shot", "reel", "scene", "profile", "attack", "jack", "walk"]
const KIT := 0.6         ## kit metres → world units (kit desks waist-high on our characters)
const MOD := 2.4         ## one 4 m kit wall module
const COLS := 6
const ROWS := 5
const W := COLS * MOD
const D := ROWS * MOD
const CORRIDOR_Z := 2    ## module row of the corridor
const LOW := 0.55        ## cutaway wall height
const PITCH_UP := 16.0   ## camera height over the focus...
const PITCH_BACK := 18.0 ## ...and distance back along the view (a ~42° isometric-style pitch)
const VIEW_SIZE := 13.0  ## ortho height framing the whole floor square-on (it was 16 for the 45° diagonal)
const YAW := 0.0         ## owner: fixed, square-on to the walls from the south (no rotation, no zoom)
## Rooms in modules (x, z, w, d), light colour, title.
const ROOMS := {
	"med_bay": [Rect2i(0, 0, 2, 2), "3ce0a0", "MED BAY"],
	"armory": [Rect2i(2, 0, 2, 2), "ffb040", "ARMORY"],
	"intel": [Rect2i(4, 0, 2, 2), "40c8ff", "FIXER NETWORK"],
	"training": [Rect2i(0, 3, 2, 2), "ff4fa0", "TRAINING ROOM"],
	"workshop": [Rect2i(2, 3, 2, 2), "ff8a3c", "WORKSHOP"],
	"bunks": [Rect2i(4, 3, 2, 2), "ffd8a0", "BUNKS"],
}
## Where people stand in each room (room-local world units, 0..4.8).
const SPOTS := {"med_bay": [Vector2(1.3, 2.9), Vector2(3.0, 2.9), Vector2(2.2, 3.9), Vector2(3.8, 3.8)],
	"armory": [Vector2(2.4, 2.6), Vector2(3.4, 3.2), Vector2(1.6, 3.6), Vector2(3.8, 2.0)],
	"intel": [Vector2(1.5, 1.9), Vector2(3.2, 2.9), Vector2(2.2, 3.6), Vector2(3.9, 2.0)],
	"training": [Vector2(2.0, 2.2), Vector2(3.0, 2.8), Vector2(1.6, 3.4), Vector2(3.6, 3.6)],
	"workshop": [Vector2(1.7, 1.8), Vector2(3.0, 2.6), Vector2(2.2, 3.4), Vector2(3.8, 3.4)],
	"bunks": [Vector2(3.0, 2.6), Vector2(3.8, 3.4), Vector2(2.3, 3.6), Vector2(1.4, 2.4)]}

var camp: Campaign
var svp: SubViewport
var screen: TextureRect
var post: ShaderMaterial
var cam: Camera3D
var world: Node3D
var ui: Control
var portraits: Portraits
var outline: Node3D
var labels := {}            ## room id → Label
var crew_nodes := {}        ## Combatant → CharModel
var crew_labels := {}       ## Combatant → Label
var selected := ""          ## room id outlined (hover outlines too)
var hover := ""
var focus := Vector3(W / 2, 0, D / 2)
var _cam_tw: Tween
var _shot_path := ""
var _frames := 0
var _scenes := {}
var _pause: TitleScreen = null   ## the Esc menu while it is up


func _ready() -> void:
	var ad := AudioDirector.get_or_make(get_tree())
	ad.music("explore")
	ad.ambience("amb_safehouse")
	ad.set_space(0.3, 0.1)
	UiScale.watch(get_window())
	GameSettings.apply_at_startup(get_tree())   # (the title screen applies them first in a normal start)
	var dev := false
	var stay := false
	var open := ""
	var crew_i := 0
	for a in OS.get_cmdline_user_args():
		var k := a.trim_prefix("--").get_slice("=", 0)
		if k in DEV_FLAGS:
			dev = true
		if k == "shot":
			_shot_path = a.get_slice("=", 1)
		if k == "base":
			stay = true
		if k == "room":
			selected = a.get_slice("=", 1)
		if k == "hover":
			hover = a.get_slice("=", 1)
		if k == "screen":
			open = a.get_slice("=", 1)
			stay = true
		if k == "crew":
			crew_i = int(a.get_slice("=", 1))
	if dev and not stay:
		get_tree().change_scene_to_file.call_deferred(GREYBOX)
		return
	Hud._fonts()
	if camp == null and "--demo" in OS.get_cmdline_user_args():   # review shots: DEV-ONLY sample campaign, never saved
		camp = DemoState.make()
		for a2 in OS.get_cmdline_user_args():   # --stash=weapon/heavy_pistol@poor,... adds to the demo's storage
			if a2.begins_with("--stash="):
				for k in a2.get_slice("=", 1).split(","):
					camp.stash[k] = int(camp.stash.get(k, 0)) + 1
	elif camp == null:   # (a caller may hand one in before adding the view)
		camp = Campaign.ensure_current()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The view's own input is _unhandled_input (hover, click): this full-screen root must
	# let the mouse through, or as a STOP control it takes every motion and click itself and nothing
	# in the safehouse ever hovers (owner playtest). The top bar and the screens still stop it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portraits = Portraits.new()
	add_child(portraits)
	_build_view()
	_build_world()
	_build_ui()
	_frame_selection(true)
	_place_camera()
	_resize()
	get_viewport().size_changed.connect(_resize)
	_place_labels()   # placed before the first frame draws, not at the top-left corner for one frame
	if camp.has_meta("report"):   # back from a gig: the debrief first
		var rep: Dictionary = camp.get_meta("report")
		camp.remove_meta("report")
		open_screen("debrief", 0, rep)
	elif open == "debrief":
		open_screen("debrief", 0, DemoState.report(camp) if camp.has_meta("demo") else {"members": camp.debrief})
	elif open != "":
		open_screen(open, crew_i)


func _process(_d: float) -> void:
	if _cam_tw and _cam_tw.is_running():
		_place_camera()
	_place_labels()
	if _shot_path != "":
		_frames += 1
		if _frames == 45:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


## Room and crew labels, the hover card and the outline follow the view.
func _place_labels() -> void:
	for c in crew_nodes:
		var n: Node3D = crew_nodes[c]
		var l: Label = crew_labels[c]
		l.position = _to_screen(n.position + Vector3(0, 1.55, 0)) - Vector2(l.size.x / 2, l.size.y)
	var vs := get_viewport_rect().size
	var top := (_top.position.y + _top.size.y + 4) if _top else 0.0
	for id in labels:
		var r := _rect(id)
		var l: Label = labels[id]
		var far := r.get_center() - Vector2(0, 1) * (r.size.x * 0.42)   # label at the room's far edge
		var at := _to_screen(Vector3(far.x, LOW + 0.3, far.y)) - Vector2(l.size.x / 2, l.size.y)
		l.position = at.clamp(Vector2(6, top), vs - l.size - Vector2(6, 30))   # never clipped by the edges or the top bar
		l.modulate = Color(1, 1, 1, 1.0 if id == selected else 0.75)
		l.visible = id != hover   # the hover card takes its place
	_place_hover_card()
	_update_outline()


static func _rect(id: String) -> Rect2:
	var r: Rect2i = ROOMS[id][0]
	return Rect2(Vector2(r.position) * MOD, Vector2(r.size) * MOD)


# --- View ---------------------------------------------------------------------------

func _build_view() -> void:
	svp = SubViewport.new()
	svp.own_world_3d = true
	svp.msaa_3d = Viewport.MSAA_DISABLED
	# Not HDR 2D: under Forward+ (the owner's GPU) an HDR 2D buffer holds LINEAR colour, and the post
	# shader (and the screen) read it as sRGB, so the whole safehouse came out several stops darker
	# than under Compatibility (which ignores the flag). Glow still works: it runs in the 3D buffer.
	svp.use_hdr_2d = false
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)
	screen = TextureRect.new()
	screen.texture = svp.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = POST_SHADER
	screen.material = post
	add_child(screen)
	var pal := PackedVector3Array()
	for h in GB.PALETTE:
		pal.append(GB._oklab(Color(h)))
	post.set_shader_parameter("palette", pal)
	post.set_shader_parameter("palette_n", pal.size())
	post.set_shader_parameter("palette_neutral_n", GB.PALETTE_NEUTRALS)
	post.set_shader_parameter("palette_on", true)
	post.set_shader_parameter("dither", 0.3)
	post.set_shader_parameter("saturation", 1.1)
	post.set_shader_parameter("outline", 0.35)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("05070b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4666")   # a lit interior: every corner reads, the room lights add colour
	env.ambient_light_energy = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR   # no filmic curve to crush the darks, no auto exposure
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, 1.0 if i in [1, 2, 3] else 0.0)
	we.environment = env
	svp.add_child(we)
	var moon := DirectionalLight3D.new()   # cold light through the high windows
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.light_color = Color("8aa4d8")
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	svp.add_child(moon)
	var fill := DirectionalLight3D.new()   # soft shadowless fill from the camera side (south, above)
	fill.rotation_degrees = Vector3(-50, 0, 0)
	fill.light_color = Color("c8d0e8")
	fill.light_energy = 0.3
	svp.add_child(fill)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = VIEW_SIZE
	svp.add_child(cam)


func _resize() -> void:
	var win := Vector2(get_viewport().get_visible_rect().size)
	var px := maxf(1.0, roundf(win.y / 360.0))
	svp.size = Vector2i(maxi(1, int(win.x / px)), maxi(1, int(win.y / px)))
	screen.size = Vector2(svp.size) * px
	post.set_shader_parameter("src_size", Vector2(svp.size))
	if ui:
		_refresh_ui()


func _place_camera() -> void:
	aim_camera(cam, focus)


## The view: from the south (YAW 0, square-on to the walls), looking down on `focus`.
static func aim_camera(c: Camera3D, at: Vector3) -> void:
	c.transform = view_xform(at)


static func view_xform(at: Vector3) -> Transform3D:
	var dir := Vector3(sin(deg_to_rad(YAW)), 0, cos(deg_to_rad(YAW)))
	return Transform3D(Basis(), at + dir * PITCH_BACK + Vector3(0, PITCH_UP, 0)).looking_at(at, Vector3.UP)


func _to_screen(p: Vector3) -> Vector2:
	return cam.unproject_position(p) * (screen.size.x / maxf(1.0, float(svp.size.x)))


func _pick_floor(mouse: Vector2) -> Vector3:
	var sp := mouse / (screen.size.x / maxf(1.0, float(svp.size.x)))
	return floor_at(cam.transform, cam.size, Vector2(svp.size), sp)


## Where a pixel of the 3D view (`px` the SubViewport's size) meets the floor, for an orthographic
## camera at `xf` showing `ortho` units top to bottom (Camera3D's KEEP_HEIGHT). Pure maths, so the
## picking is testable without a live viewport.
static func floor_at(xf: Transform3D, ortho: float, px: Vector2, sp: Vector2) -> Vector3:
	var ndc := Vector2(sp.x / px.x * 2.0 - 1.0, 1.0 - sp.y / px.y * 2.0)
	var half := Vector2(ortho * 0.5 * px.x / px.y, ortho * 0.5)
	var origin := xf.origin + xf.basis.x * ndc.x * half.x + xf.basis.y * ndc.y * half.y
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, -xf.basis.z)
	return hit if hit != null else Vector3(-99, 0, -99)


## The inverse: the view pixel a world point lands on.
static func view_at(xf: Transform3D, ortho: float, px: Vector2, p: Vector3) -> Vector2:
	var local := xf.affine_inverse() * p
	var half := Vector2(ortho * 0.5 * px.x / px.y, ortho * 0.5)
	return Vector2((local.x / half.x + 1.0) * 0.5 * px.x, (1.0 - local.y / half.y) * 0.5 * px.y)


# --- Building blocks ---------------------------------------------------------------------

static func _mat(col: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, emit := 0.0, yaw_r := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, 0.85, emit)
	mi.position = pos + Vector3(0, size.y / 2, 0)
	mi.rotation.y = yaw_r
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, col: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = _mat(col, 0.7, emit)
	mi.position = pos + Vector3(0, h / 2, 0)
	parent.add_child(mi)
	return mi


## A kit model at `pos` (world units, parent-local), turned `deg` degrees, scaled to our world.
func _kit(parent: Node3D, name: String, pos: Vector3, deg := 0.0, scl := 1.0) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load(KITS % name)
	var n: Node3D = (_scenes[name] as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(deg)
	n.scale = Vector3.ONE * KIT * scl
	parent.add_child(n)
	return n


## One of the game's gun models laid out for display, `length` world units long.
func _gun(parent: Node3D, name: String, pos: Vector3, deg: float, length: float, upright := false) -> void:
	if not _scenes.has(name):
		_scenes[name] = load(GUNS % name)
	var g: Node3D = (_scenes[name] as PackedScene).instantiate()
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.add_child(g)
	var a := _aabb(g, Transform3D())
	var s := length / maxf(0.01, maxf(a.size.x, a.size.z))
	g.scale = Vector3.ONE * s
	g.position = -a.get_center() * s
	holder.position = pos
	holder.rotation = Vector3(0, deg_to_rad(deg), deg_to_rad(80.0) if upright else 0.0)


static func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t: Transform3D = xf * (n as Node3D).transform if n is Node3D else xf
	if n is MeshInstance3D and n.mesh:
		out = t * n.mesh.get_aabb()
		first = false
	for c in n.get_children():
		var a := _aabb(c, t)
		if a.size != Vector3.ZERO:
			out = a if first else out.merge(a)
			first = false
	return out


# --- World ----------------------------------------------------------------------------

func _build_world() -> void:
	if world:
		world.queue_free()
	world = Node3D.new()
	svp.add_child(world)
	_box(world, Vector3(W + 14, 0.1, D + 14), Vector3(W / 2, -0.12, D / 2), Color("07090d"))   # the lot outside
	# corridor floor, lights and dressing
	for x in COLS:
		_kit(world, "Platform_Squares", Vector3((x + 0.5) * MOD, 0.0, (CORRIDOR_Z + 0.5) * MOD))
	_kit(world, "Prop_Cable_3", Vector3(W * 0.5, 0.01, (CORRIDOR_Z + 0.3) * MOD), 90.0)
	_kit(world, "Prop_Vent_Big", Vector3(W - 1.4, 0.02, (CORRIDOR_Z + 0.5) * MOD), 90.0)
	var cl := OmniLight3D.new()
	cl.position = Vector3(W / 2, 1.6, (CORRIDOR_Z + 0.5) * MOD)
	cl.light_color = Color("9ab4e0")
	cl.omni_range = 9.0
	cl.omni_attenuation = 0.8
	cl.light_energy = 0.9
	world.add_child(cl)
	_box(world, Vector3(0.1, 0.06, 1.2), Vector3(W + 0.1, 0.9, (CORRIDOR_Z + 0.5) * MOD), Color("ff3b6b"), 2.5)   # the door's neon
	for id in ROOMS:
		_build_room(id)
	_build_walls()
	outline = Node3D.new()
	world.add_child(outline)
	_place_crew()


## Which exterior sides face away from the camera (those get full kit walls).
static func _far_sides() -> Array[String]:
	var dir := Vector2(sin(deg_to_rad(YAW)), cos(deg_to_rad(YAW)))
	var out: Array[String] = []
	var normals := {"north": Vector2(0, -1), "south": Vector2(0, 1), "west": Vector2(-1, 0), "east": Vector2(1, 0)}
	for side in normals:
		if (normals[side] as Vector2).dot(dir) < -0.1:
			out.append(side)
	return out


## Exterior walls (full kit walls on the far sides, waist-high on the near ones) and the waist-high
## partitions between rooms and along the corridor (each room opens onto it through one module).
func _build_walls() -> void:
	var far := _far_sides()
	var walls := Node3D.new()
	walls.name = "walls"
	world.add_child(walls)
	# a kit wall lies on the west edge of the module it's centred in; turn it to the side wanted
	var seg := func(mx: int, mz: int, side: String, full: bool, window := false):
		var ang: float = {"west": 0.0, "south": 90.0, "east": 180.0, "north": 270.0}[side]
		var p := Vector3((mx + 0.5) * MOD, 0, (mz + 0.5) * MOD)
		if full:
			_kit(walls, "WallWindow_Straight" if window else "WallBand_Straight", p, ang)
		else:
			_kit(walls, "ShortWall_MetalPlates_Straight", p, ang, LOW / KIT / 1.0)
	for x in COLS:
		seg.call(x, 0, "north", "north" in far, x % 2 == 1)
		seg.call(x, ROWS - 1, "south", "south" in far, x % 2 == 1)
	for z in ROWS:
		var door: bool = z == CORRIDOR_Z
		seg.call(0, z, "west", "west" in far and not door)
		if not door:
			seg.call(COLS - 1, z, "east", "east" in far)
	for id in ROOMS:
		var r: Rect2i = ROOMS[id][0]
		var north_row := r.position.y < CORRIDOR_Z
		for dx in r.size.x:   # corridor side: one module open as the doorway
			if dx == 0:
				continue
			seg.call(r.position.x + dx, r.end.y - 1 if north_row else r.position.y, "south" if north_row else "north", false)
		if r.end.x < COLS:   # partition to the next room
			for dz in r.size.y:
				seg.call(r.end.x - 1, r.position.y + dz, "east", false)
	if "west" in far or "north" in far:   # a support column in the far corner
		_kit(walls, "Column_Pipes", Vector3(0.25, 0, 0.25))


func _build_room(id: String) -> void:
	var spec: Array = ROOMS[id]
	var r := _rect(id)
	var accent := Color(spec[1])
	var lv := _room_level(id)
	var room := Node3D.new()
	room.name = id
	room.position = Vector3(r.position.x, 0, r.position.y)
	world.add_child(room)
	var plate := "Platform_Metal" if lv > 0 else "Platform_DarkPlates"
	for mx in 2:
		for mz in 2:
			_kit(room, plate, Vector3((mx + 0.5) * MOD, 0.0, (mz + 0.5) * MOD))
	var light := OmniLight3D.new()
	light.position = Vector3(r.size.x / 2, 2.0, r.size.y / 2)
	light.light_color = accent.lerp(Color.WHITE, 0.5)
	light.omni_range = 7.0   # past the room's corners (3.9 from the light), so no dark rim
	light.omni_attenuation = 0.8   # a ceiling light that fills the room, not a bulb's pool
	light.light_energy = [0.25, 1.35, 1.8][lv]
	light.shadow_enabled = lv > 0
	room.add_child(light)
	if lv == 0:
		_unbuilt(room)
		return
	match id:
		"med_bay": _props_med(room, lv, accent)
		"armory": _props_armory(room, lv, accent)
		"intel": _props_intel(room, lv, accent)
		"training": _props_training(room, lv, accent)
		"workshop": _props_workshop(room, accent)
		"bunks": _props_bunks(room, accent)


## How furnished a room looks (rooms have no levels or effects): the workshop is open while a Tech
## is on the crew; every other room is in use.
func _room_level(id: String) -> int:
	if id == "workshop":
		return 2 if camp.best_tech() != null else 0
	return 1


func _unbuilt(room: Node3D) -> void:   # dead storage
	_kit(room, "Prop_Crate_Tarp_Large", Vector3(1.6, 0, 1.0), 10.0)
	_kit(room, "Prop_Crate_Tarp", Vector3(3.6, 0, 1.2), -15.0)
	_kit(room, "Prop_Crate", Vector3(3.5, 0, 3.4), 30.0)
	_kit(room, "Prop_Barrel1", Vector3(1.0, 0, 3.6))
	_kit(room, "Prop_Barrel2_Closed", Vector3(1.6, 0, 3.9))


## A cot: steel frame on legs, mattress, pillow, a blanket in the room colour.
func _bed(room: Node3D, p: Vector3, accent: Color, deg := 0.0) -> void:
	var b := Node3D.new()
	b.position = p
	b.rotation.y = deg_to_rad(deg)
	room.add_child(b)
	_box(b, Vector3(0.62, 0.06, 1.25), Vector3(0, 0.2, 0), Color("4a5262"))
	for c in [Vector2(-0.27, -0.58), Vector2(0.27, -0.58), Vector2(-0.27, 0.58), Vector2(0.27, 0.58)]:
		_box(b, Vector3(0.05, 0.2, 0.05), Vector3(c.x, 0, c.y), Color("2a2f3a"))
	_box(b, Vector3(0.58, 0.08, 1.2), Vector3(0, 0.26, 0), Color("b8c0cc"))
	_box(b, Vector3(0.42, 0.06, 0.2), Vector3(0, 0.34, -0.45), Color("e4e8ee"))
	_box(b, Vector3(0.6, 0.05, 0.7), Vector3(0, 0.34, 0.22), accent.darkened(0.45))
	_box(b, Vector3(0.62, 0.3, 0.05), Vector3(0, 0.2, -0.62), Color("4a5262"))   # headboard


func _props_med(room: Node3D, lv: int, accent: Color) -> void:
	_bed(room, Vector3(1.0, 0, 1.2), accent)
	_bed(room, Vector3(2.6, 0, 1.2), accent)
	_cyl(room, 0.02, 0.85, Vector3(1.55, 0, 0.7), Color("9aa4b4"))   # IV stands
	_box(room, Vector3(0.12, 0.18, 0.06), Vector3(1.55, 0.75, 0.7), accent, 1.0)
	_cyl(room, 0.02, 0.85, Vector3(3.15, 0, 0.7), Color("9aa4b4"))
	_kit(room, "Prop_Shelves_ThinShort", Vector3(4.2, 0, 0.45))
	_kit(room, "Prop_HealthPack", Vector3(4.0, 0.74, 0.45), 0.0, 0.9)
	_kit(room, "Prop_HealthPack_Tube", Vector3(4.4, 0.74, 0.45))
	_kit(room, "Prop_Chest", Vector3(4.1, 0, 3.9), -90.0, 0.8)
	if lv >= 2:
		_bed(room, Vector3(1.0, 0, 3.5), accent, 0.0)
		_box(room, Vector3(0.55, 0.42, 1.1), Vector3(2.9, 0, 3.4), Color("8a96a8"))   # surgical table
		_box(room, Vector3(0.6, 0.04, 1.15), Vector3(2.9, 0.42, 3.4), Color("8a98a8"))
		_cyl(room, 0.28, 0.04, Vector3(2.9, 1.5, 3.4), Color("8a98b0"), 0.4)   # lamp
		_cyl(room, 0.015, 0.5, Vector3(2.9, 1.52, 3.4), Color("5a6476"))
		_kit(room, "Prop_Computer", Vector3(3.7, 0, 2.6), -90.0, 0.85)
		_kit(room, "Prop_Syringe", Vector3(2.6, 0.48, 3.0), 0.0, 0.8)


func _props_armory(room: Node3D, lv: int, accent: Color) -> void:
	_kit(room, "Prop_Shelves_WideTall", Vector3(1.4, 0, 0.35))
	_gun(room, "AssaultRifle_1", Vector3(1.0, 0.95, 0.38), 0.0, 0.6)
	_gun(room, "Shotgun_1", Vector3(1.8, 0.95, 0.38), 0.0, 0.62)
	_gun(room, "SniperRifle_1", Vector3(1.4, 1.42, 0.38), 0.0, 0.75)
	_gun(room, "Pistol_1", Vector3(1.0, 0.5, 0.38), 0.0, 0.18)
	_gun(room, "Revolver_1", Vector3(1.3, 0.5, 0.38), 0.0, 0.2)
	_kit(room, "Prop_Ammo", Vector3(3.5, 0, 0.7), 20.0)
	_kit(room, "Prop_Ammo_Closed", Vector3(4.1, 0, 0.9), -10.0)
	_kit(room, "Prop_Crate", Vector3(4.0, 0, 3.8), 15.0, 0.8)
	if lv >= 2:
		for i in 3:
			_kit(room, "Prop_Locker", Vector3(0.45, 0, 1.9 + i * 0.62), 90.0)
		_kit(room, "Prop_Desk_Medium", Vector3(2.6, 0, 3.9))
		for i in 3:
			_kit(room, "Prop_Grenade", Vector3(2.2 + i * 0.2, 0.62, 3.8), 0.0, 1.2)
		_gun(room, "SubmachineGun_1", Vector3(3.0, 0.62, 3.9), 30.0, 0.42)
		_kit(room, "Prop_Ammo_Small", Vector3(3.4, 0.56, 4.0), 0.0, 0.8)
		_box(room, Vector3(1.6, 0.04, 0.04), Vector3(2.6, 1.35, 4.3), accent, 2.0)   # work light


func _props_intel(room: Node3D, lv: int, accent: Color) -> void:
	_kit(room, "Prop_Desk_L", Vector3(1.0, 0, 0.9))
	_kit(room, "Prop_Computer", Vector3(0.8, 0.56, 0.5), 0.0, 0.7)
	_kit(room, "Prop_Chair", Vector3(1.2, 0, 1.5), 180.0)
	_kit(room, "Prop_Mug", Vector3(1.8, 0.56, 0.7), 0.0, 1.4)
	# the case wall: a corkboard with photos and string
	_box(room, Vector3(1.5, 0.8, 0.04), Vector3(3.4, 0.5, 0.12), Color("7a5a3a"))
	for i in 6:
		_box(room, Vector3(0.18, 0.22, 0.02), Vector3(2.85 + i * 0.22, 0.65 + (i % 2) * 0.28, 0.15), Color("e8dcc0"))
	_box(room, Vector3(1.2, 0.012, 0.012), Vector3(3.4, 0.85, 0.16), Color("e03030"))
	if lv >= 2:
		for i in 2:
			_kit(room, "Prop_AccessPoint", Vector3(0.35, 0, 2.6 + i * 1.0), 90.0)
		_kit(room, "Prop_Desk_Small", Vector3(3.4, 0, 3.6), 180.0)
		_kit(room, "Prop_Computer", Vector3(3.0, 0.56, 3.9), 180.0, 0.7)
		_kit(room, "Prop_Computer", Vector3(3.8, 0.56, 3.9), 180.0, 0.7)
		_kit(room, "Prop_Cable_1", Vector3(2.0, 0.01, 3.2), 40.0)
		for i in 3:   # a wall of screens
			_box(room, Vector3(0.5, 0.3, 0.03), Vector3(2.9 + i * 0.55, 1.15, 0.13), accent.lerp(Color("ff3b6b"), 0.3 * i), 1.6)


func _props_training(room: Node3D, lv: int, accent: Color) -> void:
	_box(room, Vector3(2.6, 0.03, 2.2), Vector3(2.0, 0.0, 2.4), Color("2e3240"))   # mats
	_box(room, Vector3(2.6, 0.005, 0.04), Vector3(2.0, 0.03, 1.3), accent.darkened(0.2), 0.6)
	_cyl(room, 0.17, 0.7, Vector3(4.0, 0.45, 1.2), Color("7a2a2a"))   # heavy bag
	_cyl(room, 0.012, 0.5, Vector3(4.0, 1.15, 1.2), Color("888888"))
	_kit(room, "Prop_Crate3", Vector3(0.6, 0, 4.2), 0.0, 0.6)   # bench
	if lv >= 2:
		_box(room, Vector3(0.06, 0.95, 0.5), Vector3(4.3, 0, 3.8), Color("6a5a40"))   # target stand
		_cyl(room, 0.2, 0.03, Vector3(4.27, 0.7, 3.8), Color("e8e0d0"))
		_box(room, Vector3(0.9, 0.3, 0.3), Vector3(3.2, 0, 4.4), Color("2a2e36"))   # weight rack
		for i in 3:
			_cyl(room, 0.1, 0.05, Vector3(2.9 + i * 0.3, 0.3, 4.4), Color("1a1a1a"))
		_kit(room, "Prop_Light_Floor", Vector3(0.8, 0, 0.5))


func _props_workshop(room: Node3D, accent: Color) -> void:
	_kit(room, "Prop_Desk_Medium", Vector3(2.0, 0, 0.6))
	_kit(room, "Prop_ItemHolder", Vector3(1.4, 0.56, 0.6), 0.0, 0.5)
	_kit(room, "Prop_Computer", Vector3(2.8, 0.56, 0.45), 0.0, 0.7)
	_gun(room, "AssaultRifle_1", Vector3(2.1, 0.6, 0.75), 20.0, 0.6)
	_kit(room, "Prop_Shelves_ThinTall", Vector3(4.3, 0, 1.4), -90.0)
	_kit(room, "Prop_Crate4", Vector3(4.0, 0, 3.9), 25.0, 0.7)
	_kit(room, "Prop_Barrel_Large", Vector3(0.6, 0, 3.9))
	_box(room, Vector3(0.12, 0.08, 0.12), Vector3(2.4, 0.58, 0.7), accent, 3.0)   # soldering glow


func _props_bunks(room: Node3D, accent: Color) -> void:
	for i in 2:   # bunk beds
		var p := Vector3(0.7 + i * 1.0, 0, 0.9)
		_bed(room, p, accent.lerp(Color("5a6a8a"), 0.6))
		_box(room, Vector3(0.62, 0.05, 1.25), p + Vector3(0, 0.75, 0), Color("4a5262"))
		_box(room, Vector3(0.58, 0.08, 1.2), p + Vector3(0, 0.8, 0), Color("a8b0bc"))
		for c in [Vector2(-0.29, -0.6), Vector2(0.29, -0.6), Vector2(-0.29, 0.6), Vector2(0.29, 0.6)]:
			_box(room, Vector3(0.04, 0.85, 0.04), p + Vector3(c.x, 0, c.y), Color("2a2f3a"))
	for i in 2:
		_kit(room, "Prop_Locker", Vector3(3.2 + i * 0.62, 0, 0.3))
	_box(room, Vector3(1.3, 0.25, 0.5), Vector3(3.4, 0, 4.2), Color("5a3a4a"))   # couch
	_box(room, Vector3(1.3, 0.3, 0.12), Vector3(3.4, 0.25, 4.45), Color("5a3a4a"))
	_box(room, Vector3(0.6, 0.22, 0.35), Vector3(3.4, 0, 3.5), Color("3a3020"))   # table
	_kit(room, "Prop_Mug", Vector3(3.3, 0.22, 3.5), 0.0, 1.4)
	_box(room, Vector3(0.7, 0.4, 0.04), Vector3(3.4, 0.6, 4.75), accent.lerp(Color("40c8ff"), 0.6), 1.6)   # TV


# --- Crew -----------------------------------------------------------------------------------

## Where each downtime job puts people: hurt crew go to the med bay when it's built.
func _room_for(c: Combatant) -> String:
	if c.hp < c.max_hp() and c.downtime == "recover":
		return "med_bay"
	if c.role == "tech" and camp.best_tech() != null:
		return "workshop"
	return "bunks"


func _spot(c: Combatant, room: String) -> Vector3:
	var k := 0
	for o in camp.alive_crew():
		if o == c:
			break
		if _room_for(o) == room:
			k += 1
	var r := _rect(room)
	var s: Vector2 = SPOTS[room][k % 4]
	return Vector3(r.position.x + s.x, 0, r.position.y + s.y)


func _place_crew() -> void:
	for c in crew_labels:
		(crew_labels[c] as Label).queue_free()
	crew_nodes.clear()
	crew_labels.clear()
	for c in camp.alive_crew():
		var room := _room_for(c)
		var n := CharModel.build(0, maxi(0, c.look_seed), String(c.role), c.weapons[0].id() if not c.weapons.is_empty() else "heavy_pistol")
		for mt in n.get_meta("mats", []):
			(mt as ShaderMaterial).set_shader_parameter("use_field", false)
		n.position = _spot(c, room)
		n.scale = Vector3.ONE * 1.3
		n.rotation.y = deg_to_rad(200.0 + 37.0 * c.look_seed)
		n.set_meta("calm", true)
		n.set_meta("wound", c.wound_state())
		world.add_child(n)
		_activity(n, room)
		crew_nodes[c] = n
		if ui:
			crew_labels[c] = _crew_label(c)


## Walk someone out of their room, along the corridor, and into the new one.
func _walk(c: Combatant, from: String, to: String) -> void:
	var n: CharModel = crew_nodes[c]
	n.stop_perform()
	var dest := _spot(c, to)
	var cz := (CORRIDOR_Z + 0.5) * MOD
	var pts: Array[Vector3] = []
	if from != to:
		pts.append(Vector3(_rect(from).position.x + MOD * 0.5, 0, cz))   # out through the doorway
		pts.append(Vector3(_rect(to).position.x + MOD * 0.5, 0, cz))
	pts.append(dest)
	n.set_meta("walk", true)
	n.set_meta("stroll", true)
	var tw := create_tween()
	var at := n.position
	for p in pts:
		var d := p - at
		if d.length() < 0.05:
			continue
		var yaw_to := atan2(d.x, d.z)
		tw.tween_callback(func(): n.rotation.y = yaw_to)
		tw.tween_property(n, "position", p, d.length() / 1.1)
		at = p
	tw.tween_callback(_arrive.bind(n, to))


func _arrive(n: CharModel, room: String) -> void:
	n.set_meta("walk", false)
	n.set_meta("stroll", false)
	_activity(n, room)


## What people do in each room.
static func _activity(n: CharModel, room: String) -> void:
	match room:
		"training": n.perform("melee", 1e6)
		"intel": n.perform("idle_phone", 1e6)
		"workshop": n.perform("idle_shift", 1e6)
		"med_bay": n.perform("injured_idle", 1e6)


func _crew_label(c: Combatant) -> Label:
	var l := _text(c.display_name.to_upper(), Hud.F_TERM, Hud.ts(16), Hud.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(l)
	return l


## The hovered / selected room lit up: a rim in its colour on the floor and along the tops of its
## cutaway walls (so it reads past the furniture), and a light in its colour over it.
func _update_outline() -> void:
	if outline == null:
		return
	var id := selected if selected != "" else hover
	if outline.get_meta("for", "~") == id:
		return
	outline.set_meta("for", id)
	for ch in outline.get_children():
		ch.queue_free()
	if id == "":
		return
	var r := _rect(id).grow(-0.08)
	var col := Color(ROOMS[id][1])
	for y in [0.03, LOW + 0.02]:
		for e in [[Vector3(r.get_center().x, y, r.position.y), Vector3(r.size.x, 0.03, 0.06)],
				[Vector3(r.get_center().x, y, r.end.y), Vector3(r.size.x, 0.03, 0.06)],
				[Vector3(r.position.x, y, r.get_center().y), Vector3(0.06, 0.03, r.size.y)],
				[Vector3(r.end.x, y, r.get_center().y), Vector3(0.06, 0.03, r.size.y)]]:
			_box(outline, e[1], e[0], col, 2.0)
	var glow := OmniLight3D.new()
	glow.position = Vector3(r.get_center().x, 1.8, r.get_center().y)
	glow.light_color = col.lerp(Color.WHITE, 0.3)
	glow.omni_range = 4.5
	glow.light_energy = 1.6
	outline.add_child(glow)


# --- UI -------------------------------------------------------------------------------------

## Room → the screen it opens (owner: every between-gigs function is a full screen opened from its
## room) and what it holds (shown on hover).
const ROOM_SCREENS := {
	"intel": ["jobs", "Jobs · Hire · Night Market"],
	"armory": ["storage", "Storage · Loadouts"],
	"med_bay": ["ripperdoc", "Ripperdoc · Therapy · Critical Injuries"],
	"training": ["training", "Improvement Points · Role Rank · Perks"],
	"bunks": ["crew", "Crew · Recover"],
	"workshop": ["workshop", "Armor upgrades"],
}
## Screen id → the screen's tab.
const SCREEN_TABS := {"jobs": "jobs", "hire": "hire", "market": "market", "city": "city", "storage": "loadouts", "workshop": "workshop",
	"ripperdoc": "ripperdoc", "therapy": "therapy", "injuries": "injuries", "training": "", "crew": "", "debrief": ""}


static func _make_screen(id: String) -> SafehouseScreen:
	match id:
		"jobs", "hire", "market", "city": return FixerScreen.new()
		"storage", "workshop": return StorageScreen.new()
		"ripperdoc", "therapy", "injuries": return MedBayScreen.new()
		"training": return TrainingScreen.new()
		"crew": return CrewScreen.new()
		"debrief": return DebriefScreen.new()
	return null

var _screen: SafehouseScreen
var _top: PanelContainer
var _hover_card: PanelContainer
var _hover_for := "~"


func _text(s: String, font: Font, size: int, col := Hud.TEXT) -> Label:
	if (font == Hud.F_DISPLAY or font == Hud.F_PIXEL) and s != s.to_upper():   # the pixel face is for caps only
		font = Hud.F_TERM
		size = Hud.ts(size)
	elif (font == Hud.F_DISPLAY or font == Hud.F_PIXEL) and size < 30:   # r7 review: small pixel text drops columns ("UNDERQTY")
		font = Hud.F_BOLD
		size = Hud.ts(size)
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	for id in ROOMS:
		var l := _text(String(ROOMS[id][2]), Hud.F_PIXEL, 18, Color(ROOMS[id][1]))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		labels[id] = l
		ui.add_child(l)
	for c in crew_nodes:
		crew_labels[c] = _crew_label(c)
	_refresh_ui()


func _refresh_ui() -> void:
	var vs := get_viewport_rect().size
	if _top:
		_top.queue_free()
	_top = SafehouseScreen.top_bar(camp, "Safehouse", "", Callable())
	_top.position = Vector2(12, 10)
	_top.size = Vector2(vs.x - 24, 0)
	ui.add_child(_top)
	_top.reset_size()
	_top.size.x = vs.x - 24
	for c in crew_labels:
		(crew_labels[c] as Label).modulate = Color(1, 1, 1, 0.85)


## The hovered room's name and what it holds, in place of its label: "MED BAY / Ripperdoc · Therapy ·
## Critical Injuries". Rebuilt when the hover changes, placed every frame.
func _place_hover_card() -> void:
	if _hover_for != hover:
		_hover_for = hover
		if _hover_card:
			_hover_card.queue_free()
			_hover_card = null
		if hover != "" and ROOMS.has(hover) and ui:
			_hover_card = _room_card(hover)
			_ignore_mouse(_hover_card)   # never under the cursor as a STOP control (it would end the hover)
			ui.add_child(_hover_card)
			_hover_card.reset_size()
	if _hover_card == null:
		return
	var l: Label = labels[hover]
	var vs := get_viewport_rect().size
	var top := (_top.position.y + _top.size.y + 4) if _top else 0.0
	var at := Vector2(l.position.x + l.size.x / 2 - _hover_card.size.x / 2, l.position.y + l.size.y - _hover_card.size.y)
	_hover_card.position = at.clamp(Vector2(6, top), vs - _hover_card.size - Vector2(6, 30))


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_ignore_mouse(ch)


func _room_card(id: String) -> PanelContainer:
	var col := Color(ROOMS[id][1])
	var p := UiKit.panel(col, 8)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UiKit.vbox(1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(UiKit.label(String(ROOMS[id][2]), 16, col))
	var sub := String(ROOM_SCREENS[id][1])
	if id == "workshop" and camp.best_tech() == null:
		sub = "Needs a Tech on the crew"
	v.add_child(UiKit.body(sub, 14, Hud.TEXT, false))
	v.add_child(UiKit.label("CLICK TO OPEN", 11, Hud.DIM))
	return p


## Open a room's screen.
func open_room(id: String) -> void:
	if ROOM_SCREENS.has(id):
		open_screen(String(ROOM_SCREENS[id][0]))


## Open a between-gigs screen full screen over the safehouse (`crew_index` selects someone).
func open_screen(id: String, crew_index := 0, report := {}) -> void:
	if not SCREEN_TABS.has(id):
		return
	if _screen:
		_screen.queue_free()
	var s := _make_screen(id)
	if s is DebriefScreen:
		(s as DebriefScreen).report = report
	s.setup(camp, portraits, String(SCREEN_TABS[id]), crew_index)
	s.closed.connect(close_screen)
	s.navigate.connect(func(to: String): open_screen(to, s.sel))
	if s is FixerScreen:
		(s as FixerScreen).take_gig.connect(_take_gig)
	_screen = s
	hover = ""
	selected = ""
	ui.visible = false
	svp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(s)


func close_screen() -> void:
	if _screen:
		_screen.queue_free()
		_screen = null
	ui.visible = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_rebuild()
	_frame_selection()


func _take_gig(i: int) -> void:
	if camp.accept(i).is_empty():
		return
	if not camp.has_meta("demo"):
		camp.save()
	get_tree().change_scene_to_file(GREYBOX)


## Glide in on the hovered room (or back out to the whole floor).
func _overview() -> Vector3:   # the whole floor, nudged down (clear of the top bar), centred on screen
	_place_camera()
	return overview_focus()


static func overview_focus() -> Vector3:
	return Vector3(W / 2, 0, D / 2) - Vector3(sin(deg_to_rad(YAW)), 0, cos(deg_to_rad(YAW))) * 1.0


func _frame_selection(now := false) -> void:
	var goal := _overview()
	var size := VIEW_SIZE
	if now:
		focus = goal
		cam.size = size
		_place_camera()
		return
	if _cam_tw and _cam_tw.is_valid():
		_cam_tw.kill()
	_cam_tw = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tw.tween_property(self, "focus", goal, 0.45)
	_cam_tw.tween_property(cam, "size", size, 0.45)
	_cam_tw.chain().tween_callback(_place_camera)


func _rebuild() -> void:
	_build_world()
	_refresh_ui()


func _unhandled_input(ev: InputEvent) -> void:
	if _screen or is_instance_valid(_pause):
		return
	if ev.is_action_pressed("ui_cancel"):   # Esc: the pause menu (Save, Load, Title, Quit)
		get_viewport().set_input_as_handled()
		_pause = TitleScreen.new()
		_pause.pause = true
		_pause.camp = camp
		add_child(_pause)
		return
	if ev is InputEventMouseMotion:
		var h := _room_at(_pick_floor(ev.position))
		if h != hover:
			hover = h
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var c := _crew_at(ev.position)
		if c:
			open_screen("crew", camp.alive_crew().find(c))
			return
		var picked := _room_at(_pick_floor(ev.position))
		if picked != "":
			open_room(picked)


static func _room_at(p: Vector3) -> String:
	for id in ROOMS:
		if _rect(id).has_point(Vector2(p.x, p.z)):
			return id
	return ""


func _crew_at(mouse: Vector2) -> Combatant:
	var best: Combatant = null
	var bd := 34.0
	for c in crew_nodes:
		var d := _to_screen((crew_nodes[c] as Node3D).position + Vector3(0, 0.7, 0)).distance_to(mouse)
		if d < bd:
			bd = d
			best = c
	return best
