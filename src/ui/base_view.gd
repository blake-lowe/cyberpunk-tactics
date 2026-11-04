class_name BaseView
extends Control
## The safehouse as a place (owner: tactile, physical, upgrades and the crew visible, same pixel
## style). A converted floor of an old block, built from Quaternius' CC0 sci-fi kits (modular walls,
## floor plates, desks, lockers, shelving, crates, computers...) at the tactical view's scale (a
## character stands ~1.15 units; kit metres x KIT), seen through the same low-res palette pipeline.
##
## Layout on a 2.4-unit module grid: three rooms north of a corridor (Med Bay, Armory, Fixer Network),
## three south (Training Room, Workshop, Bunks). A facility's level decides its room: unbuilt rooms are
## dark storage (tarped crates); level 1 brings the basics; level 2 fills it out and lights it up.
## Walls are kit walls on the two far sides (rebuilt as the view rotates) and waist-high everywhere
## else, so every room reads from above. The crew stand where their downtime job puts them.
##
## UI (same chrome as the tactical HUD): crew roster left (click: go to them, set their downtime job),
## rest and the fixer board top right, room / crew detail on the right. Click a room to upgrade it.

const GB := preload("res://src/tactical/greybox.gd")
const POST_SHADER := preload("res://src/tactical/view/post.gdshader")
const BOARD := "res://scenes/board.tscn"
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
var panel: PanelContainer
var roster: VBoxContainer
var portraits: Portraits
var outline: Node3D
var labels := {}            ## room id → Label
var crew_nodes := {}        ## Combatant → CharModel
var crew_labels := {}       ## Combatant → Label
var selected := ""          ## room id shown in the side panel
var sel_crew: Combatant     ## or a crew member
var hover := ""
var yaw := 45.0
var focus := Vector3(W / 2, 0, D / 2)
var _cam_tw: Tween
var _shot_path := ""
var _frames := 0
var _money: Label
var _scenes := {}


func _ready() -> void:
	var ad := AudioDirector.get_or_make(get_tree())
	ad.music("explore")
	ad.ambience("amb_safehouse")
	ad.set_space(0.3, 0.1)
	UiScale.watch(get_window())
	var dev := false
	var stay := false
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
		if k == "yaw":
			yaw = float(a.get_slice("=", 1))
		if k == "board" or k == "train":   # board review shots
			get_tree().change_scene_to_file.call_deferred(BOARD)
			return
	if dev and not stay:
		get_tree().change_scene_to_file.call_deferred(GREYBOX)
		return
	Hud._fonts()
	camp = Campaign.ensure_current()
	if "--demo" in OS.get_cmdline_user_args():   # review shots: a furnished base (not saved)
		camp.facilities = {"med_bay": 2, "intel": 2, "training": 1}
		if not camp.crew.is_empty():
			camp.crew[0].hp = maxi(1, camp.crew[0].max_hp() / 2)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portraits = Portraits.new()
	add_child(portraits)
	_build_view()
	_build_world()
	for a in OS.get_cmdline_user_args():   # review shots: --crew=n selects crew member n
		if a.begins_with("--crew=") and int(a.get_slice("=", 1)) < camp.alive_crew().size():
			sel_crew = camp.alive_crew()[int(a.get_slice("=", 1))]
	_build_ui()
	_frame_selection(true)
	_place_camera()
	_resize()
	get_viewport().size_changed.connect(_resize)


func _process(_d: float) -> void:
	if _cam_tw and _cam_tw.is_running():
		_place_camera()
	for c in crew_nodes:
		var n: Node3D = crew_nodes[c]
		var l: Label = crew_labels[c]
		l.position = _to_screen(n.position + Vector3(0, 1.55, 0)) - Vector2(l.size.x / 2, l.size.y)
	for id in labels:
		var r := _rect(id)
		var l: Label = labels[id]
		var dir := Vector2(sin(deg_to_rad(yaw)), cos(deg_to_rad(yaw)))
		var far := r.get_center() - dir * (r.size.x * 0.42)   # label at the room's far edge
		l.position = _to_screen(Vector3(far.x, LOW + 0.3, far.y)) - Vector2(l.size.x / 2, l.size.y)
		l.modulate = Color(1, 1, 1, 1.0 if id == hover or id == selected else 0.75)
	_update_outline()
	if _shot_path != "":
		_frames += 1
		if _frames == 45:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


func _rect(id: String) -> Rect2:
	var r: Rect2i = ROOMS[id][0]
	return Rect2(Vector2(r.position) * MOD, Vector2(r.size) * MOD)


# --- View ---------------------------------------------------------------------------

func _build_view() -> void:
	svp = SubViewport.new()
	svp.own_world_3d = true
	svp.msaa_3d = Viewport.MSAA_DISABLED
	svp.use_hdr_2d = true
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
	env.ambient_light_color = Color("2a3450")
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
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
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 14.5
	svp.add_child(cam)


func _resize() -> void:
	var win := Vector2(get_viewport().get_visible_rect().size)
	var px := maxf(1.0, roundf(win.y / 360.0))
	svp.size = Vector2i(maxi(1, int(win.x / px)), maxi(1, int(win.y / px)))
	screen.size = Vector2(svp.size) * px
	post.set_shader_parameter("src_size", Vector2(svp.size))
	if panel:
		_refresh_ui()


func _place_camera() -> void:
	var dir := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	cam.look_at_from_position(focus + dir * 18.0 + Vector3(0, 16.0, 0), focus, Vector3.UP)


func _to_screen(p: Vector3) -> Vector2:
	return cam.unproject_position(p) * (screen.size.x / maxf(1.0, float(svp.size.x)))


func _pick_floor(mouse: Vector2) -> Vector3:
	var sp := mouse / (screen.size.x / maxf(1.0, float(svp.size.x)))
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(sp), cam.project_ray_normal(sp))
	return hit if hit != null else Vector3(-99, 0, -99)


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
	cl.omni_range = 8.0
	cl.light_energy = 0.6
	world.add_child(cl)
	_box(world, Vector3(0.1, 0.06, 1.2), Vector3(W + 0.1, 0.9, (CORRIDOR_Z + 0.5) * MOD), Color("ff3b6b"), 2.5)   # the door's neon
	for id in ROOMS:
		_build_room(id)
	_build_walls()
	outline = Node3D.new()
	world.add_child(outline)
	_place_crew()


## Which exterior sides face away from the camera (those get full kit walls).
func _far_sides() -> Array[String]:
	var dir := Vector2(sin(deg_to_rad(yaw)), cos(deg_to_rad(yaw)))
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
	light.omni_range = 5.5
	light.light_energy = [0.15, 0.9, 1.4][lv]
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


## Facilities by their level; the workshop is open while a Tech is on the crew; bunks are always in.
func _room_level(id: String) -> int:
	if Campaign.FACILITIES.has(id):
		return camp.level(id)
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
	if c.hp < c.max_hp() and camp.level("med_bay") > 0 and c.downtime == "recover":
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


## Gold rim around the hovered / selected room.
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
	for e in [[Vector3(r.get_center().x, 0.03, r.position.y), Vector3(r.size.x, 0.02, 0.05)],
			[Vector3(r.get_center().x, 0.03, r.end.y), Vector3(r.size.x, 0.02, 0.05)],
			[Vector3(r.position.x, 0.03, r.get_center().y), Vector3(0.05, 0.02, r.size.y)],
			[Vector3(r.end.x, 0.03, r.get_center().y), Vector3(0.05, 0.02, r.size.y)]]:
		_box(outline, e[1], e[0], col, 2.0 if id == selected else 1.0)


# --- UI -------------------------------------------------------------------------------------

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


func _wrap(s: String, size: int, col: Color, width := 340.0) -> Label:
	var l := _text(s, Hud.F_TERM, Hud.ts(size), col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


func _button(label: String, col: Color, cb: Callable, enabled := true, size := 20) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.add_theme_font_override("font", Hud.F_DISPLAY)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", col)
	b.add_theme_stylebox_override("normal", CutBox.make(Color(0.03, 0.045, 0.06, 0.95), Color(col, 0.5), 7, 0b0101))
	b.add_theme_stylebox_override("hover", CutBox.make(Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.97), col, 7, 0b0101))
	b.add_theme_stylebox_override("pressed", CutBox.make(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, 7, 0b0101))
	b.add_theme_stylebox_override("disabled", CutBox.make(Color(0.02, 0.025, 0.03, 0.8), Color(Hud.DIM, 0.2), 7, 0b0101))
	b.pressed.connect(cb)
	return b


func _panel(accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", CutBox.make(Hud.INK, Color(accent, 0.5), 12, 0b0101, accent, 12))
	return p


func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	for id in ROOMS:
		var l := _text("", Hud.F_PIXEL, 18, Color(ROOMS[id][1]))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		labels[id] = l
		ui.add_child(l)
	for c in crew_nodes:
		crew_labels[c] = _crew_label(c)
	# header: title and the money / standing line, in the HUD's banner chrome
	var head := _panel(Hud.GOLD)
	head.position = Vector2(14, 12)
	ui.add_child(head)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	head.add_child(hb)
	hb.add_child(_text("SAFEHOUSE", Hud.F_DISPLAY, 34, Hud.GOLD))
	_money = _text("", Hud.F_TERM, Hud.ts(24), Hud.TEXT)
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_money)
	# crew roster, left
	roster = VBoxContainer.new()
	roster.position = Vector2(14, 84)
	roster.add_theme_constant_override("separation", 6)
	ui.add_child(roster)
	# actions, top right
	var acts := VBoxContainer.new()
	acts.name = "acts"
	acts.add_theme_constant_override("separation", 6)
	ui.add_child(acts)
	var board := _button("FIXER BOARD  ›", Hud.GOLD, func(): camp.save(); get_tree().change_scene_to_file(BOARD), true, 24)
	board.custom_minimum_size = Vector2(230, 46)
	acts.add_child(board)
	var rest := HBoxContainer.new()
	rest.add_theme_constant_override("separation", 6)
	acts.add_child(rest)
	rest.add_child(_button("REST 1 DAY", Hud.CYAN, func(): camp.rest(1); camp.save(); _rebuild(), true, 16))
	rest.add_child(_button("UNTIL HEALED", Hud.CYAN, func(): _rest_full(); camp.save(); _rebuild(), true, 16))
	var hint := _text("CLICK A ROOM TO UPGRADE IT · CLICK SOMEONE TO SET THEIR DOWNTIME · Q/E ROTATE · WHEEL ZOOM", Hud.F_TERM, Hud.ts(16), Hud.DIM)
	hint.name = "hint"
	ui.add_child(hint)
	panel = _panel(Hud.CYAN)
	panel.custom_minimum_size = Vector2(370, 0)
	ui.add_child(panel)
	_refresh_ui()


func _rest_full() -> void:
	var days := 0
	while days < 14 and camp.crew.any(func(c): return c.hp < c.max_hp()):
		camp.rest(1)
		days += 1


func _refresh_ui() -> void:
	var vs := get_viewport_rect().size
	_money.text = "DAY %d  ·  %s eb" % [camp.day, Board._money(camp.eb)]
	var acts: Control = ui.get_node("acts")
	acts.reset_size()
	acts.position = Vector2(vs.x - acts.size.x - 14, 12)
	var hint: Label = ui.get_node("hint")
	hint.reset_size()
	hint.position = Vector2(vs.x / 2 - hint.size.x / 2, vs.y - 30)
	for id in ROOMS:
		var lv := _room_level(id)
		var pips := ""
		if Campaign.FACILITIES.has(id):
			pips = "  " + "◆".repeat(lv) + "◇".repeat(2 - lv)
		(labels[id] as Label).text = String(ROOMS[id][2]) + pips + ("" if lv > 0 else "  · STORAGE")
	for c in crew_labels:
		(crew_labels[c] as Label).modulate = Color(1, 1, 1, 1.0 if c == sel_crew else 0.8)
	_build_roster()
	for ch in panel.get_children():
		ch.queue_free()
	panel.visible = selected != "" or sel_crew != null
	if panel.visible:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		panel.add_child(col)
		if sel_crew != null:
			_crew_panel(col, sel_crew)
		else:
			_room_panel(col, selected)
		col.add_child(_button("CLOSE", Hud.DIM, func(): selected = ""; sel_crew = null; _refresh_ui(); _frame_selection(), true, 16))
		panel.reset_size()
		panel.position = Vector2(vs.x - panel.size.x - 14, 120)


## The crew down the left: HUD-style cards (portrait, name, role, HP, downtime job).
func _build_roster() -> void:
	for ch in roster.get_children():
		ch.queue_free()
	roster.add_child(_text("// CREW", Hud.F_PIXEL, 18, Hud.CYAN))
	for c in camp.alive_crew():
		var card := _panel(Hud.GOLD if c == sel_crew else UnitLook.CREW_ACCENTS[maxi(0, c.look_seed) % 4])
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select_crew(c))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var pic := TextureRect.new()
		pic.texture = portraits.tex({"id": 1000 + maxi(0, c.look_seed), "team": 0, "c": c})
		pic.custom_minimum_size = Vector2(52, 52)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pic)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
		v.add_child(_text(c.display_name.to_upper(), Hud.F_DISPLAY, 22, Hud.TEXT))
		var hpc := Hud.GREEN if c.hp >= c.max_hp() else (Hud.GOLD if c.wound_state() < Combatant.Wound.SERIOUS else Hud.RED)
		v.add_child(_text("%s · HP %d/%d · REP %d" % [c.role.to_upper(), c.hp, c.max_hp(), c.reputation], Hud.F_TERM, Hud.ts(16), hpc))
		v.add_child(_text("DOWNTIME: " + String(Campaign.DOWNTIME[c.downtime].name).to_upper(), Hud.F_TERM, Hud.ts(16), Hud.CYAN))
		card.custom_minimum_size = Vector2(250, 0)
		roster.add_child(card)


func _crew_panel(col: VBoxContainer, c: Combatant) -> void:
	col.add_child(_text(c.display_name.to_upper(), Hud.F_DISPLAY, 32, Hud.GOLD))
	col.add_child(_text("%s · RANK %d · %d IP · REPUTATION %d" % [c.role.to_upper(), c.role_rank, c.ip, c.reputation], Hud.F_TERM, Hud.ts(18), Hud.CYAN))
	col.add_child(_text("HP %d/%d · SP %d/%d%s" % [c.hp, c.max_hp(), c.sp("head"), c.sp("body"),
		(" · HUM %d/%d" % [c.humanity, c.max_humanity]) if c.tracks_humanity else ""], Hud.F_TERM, Hud.ts(18), Hud.TEXT))
	for inj in c.injuries:
		col.add_child(_text("! " + String(inj.get("name", "injury")).to_upper(), Hud.F_TERM, Hud.ts(18), Hud.RED))
	col.add_child(_text("DOWNTIME JOB", Hud.F_PIXEL, 18, Hud.DIM))
	for k in Campaign.DOWNTIME:
		var key: String = k
		var on: bool = c.downtime == key
		var b := _button(("● " if on else "○ ") + String(Campaign.DOWNTIME[key].name).to_upper(), Hud.GOLD if on else Hud.CYAN,
			func(): if c.downtime != key: _set_downtime(c, key), true, 18)
		if on:   # the current job is highlighted, not greyed out
			b.add_theme_stylebox_override("normal", CutBox.make(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, 7, 0b0101))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(b)
		col.add_child(_wrap(String(Campaign.DOWNTIME[key].desc), 16, Color(Hud.TEXT, 0.7)))
	col.add_child(_wrap("Training, gear and chrome are on the fixer board.", 16, Hud.DIM))


func _room_panel(col: VBoxContainer, id: String) -> void:
	var accent := Color(ROOMS[id][1])
	col.add_child(_text(String(ROOMS[id][2]), Hud.F_DISPLAY, 32, accent))
	if Campaign.FACILITIES.has(id):
		var d: Dictionary = Campaign.FACILITIES[id]
		var lv := camp.level(id)
		col.add_child(_text("LEVEL %d OF %d" % [lv, d.costs.size()], Hud.F_TERM, Hud.ts(18), Hud.CYAN))
		for i in d.desc.size():
			if String(d.desc[i]) != "":
				col.add_child(_wrap(("✓ " if lv > i else "· ") + String(d.desc[i]), 18, Color(Hud.TEXT, 0.9 if lv > i else 0.55)))
		var cost := camp.upgrade_cost(id)
		if cost >= 0:
			col.add_child(_button(("BUILD" if lv == 0 else "UPGRADE") + "  %s eb" % Board._money(cost), Hud.GREEN,
				func(): camp.upgrade(id); camp.save(); _rebuild(), camp.eb >= cost))
		else:
			col.add_child(_text("FULLY UPGRADED", Hud.F_TERM, Hud.ts(18), Hud.GREEN))
	else:
		var why := {"workshop": "Opens when a Tech joins the crew: armour upgrades between gigs (on the fixer board's crew cards).",
			"bunks": "Where the crew sleeps, and where anyone recovering rests up when there's no med bay.",
			"armory": "Where the crew's gear is kept."}
		col.add_child(_wrap(String(why.get(id, "")), 18, Hud.TEXT))
	var here := camp.alive_crew().filter(func(c): return _room_for(c) == id)
	if not here.is_empty():
		col.add_child(_text("HERE: " + ", ".join(here.map(func(c): return c.display_name.to_upper())), Hud.F_TERM, Hud.ts(18), Hud.CYAN))


func _set_downtime(c: Combatant, job: String) -> void:
	var from := _room_for(c)
	c.downtime = job
	camp.save()
	_walk(c, from, _room_for(c))
	_refresh_ui()


func _select_crew(c: Combatant) -> void:
	sel_crew = c
	selected = ""
	_refresh_ui()
	_frame_selection()


## Glide in on the selected room or crew member (or back out to the whole floor).
func _overview() -> Vector3:   # the whole floor, nudged down (clear of the header) and right (of the roster)
	_place_camera()
	var right := Vector3(cam.global_basis.x.x, 0, cam.global_basis.x.z).normalized()
	var dir := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	return Vector3(W / 2, 0, D / 2) - dir * 1.0 - right * 1.6


func _frame_selection(now := false) -> void:
	var goal := _overview()
	var size := 14.5
	if sel_crew != null and crew_nodes.has(sel_crew):
		goal = (crew_nodes[sel_crew] as Node3D).position
		size = 6.0
	elif selected != "":
		var r := _rect(selected)
		goal = Vector3(r.get_center().x, 0, r.get_center().y)
		size = 6.5
	if sel_crew != null or selected != "":   # sit left of the side panel
		_place_camera()
		var right := Vector3(cam.global_basis.x.x, 0, cam.global_basis.x.z).normalized()
		goal += right * size * 0.2
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
	if ev is InputEventMouseMotion:
		hover = _room_at(_pick_floor(ev.position))
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var c := _crew_at(ev.position)
		if c:
			_select_crew(c)
			return
		var picked := _room_at(_pick_floor(ev.position))
		if picked != selected or sel_crew != null:
			selected = picked
			sel_crew = null
			_refresh_ui()
			_frame_selection()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		cam.size = clampf(cam.size + (-1.0 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0), 4.0, 18.0)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode in [KEY_Q, KEY_E]:
			yaw += -90.0 if ev.keycode == KEY_Q else 90.0
			_build_world()   # far walls follow the view
			_place_camera()
			_refresh_ui()


func _room_at(p: Vector3) -> String:
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
