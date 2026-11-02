class_name BaseView
extends Control
## The safehouse as a place (owner: "more tactile... physically represent the space of the base,
## upgrades and characters, in the same pixel style"). A converted warehouse floor seen from above
## in the tactical view's pixel pipeline (low-res 3D, palette/dither post): one room per facility
## plus a workshop and bunks. A facility's level decides what's in its room: unbuilt rooms are dark
## with tarped crates; level 1 brings the basics; level 2 fills it out and lights it up. The crew
## stand where their downtime assignment puts them. Click a room to see and upgrade it; click a crew
## member to change their downtime job. The hub between gigs: the fixer board is a button away.

const GB := preload("res://src/tactical/greybox.gd")
const POST_SHADER := preload("res://src/tactical/view/post.gdshader")
const BOARD := "res://scenes/board.tscn"
const GREYBOX := "res://scenes/greybox.tscn"
const DEV_FLAGS := ["shot", "reel", "scene", "profile", "attack", "jack", "walk"]
const W := 24.0     ## warehouse floor, metres
const D := 15.0
const WALL_H := 0.7  ## cutaway wall height
## Room layout: id → [rect (x, z, w, d), light colour, title]. Facilities first, then fixed rooms.
const ROOMS := {
	"med_bay": [Rect2(0, 0, 8, 7), "3ce0a0", "MED BAY"],
	"armory": [Rect2(8, 0, 8, 7), "ffb040", "ARMORY"],
	"intel": [Rect2(16, 0, 8, 7), "40c8ff", "FIXER NETWORK"],
	"training": [Rect2(0, 8, 8, 7), "ff4fa0", "TRAINING ROOM"],
	"workshop": [Rect2(8, 8, 8, 7), "ff8a3c", "WORKSHOP"],
	"bunks": [Rect2(16, 8, 8, 7), "ffd8a0", "BUNKS"],
}

var camp: Campaign
var svp: SubViewport
var screen: TextureRect
var post: ShaderMaterial
var cam: Camera3D
var world: Node3D
var ui: Control
var panel: PanelContainer
var labels := {}            ## room id → Label
var crew_nodes := {}        ## Combatant → CharModel
var crew_labels := {}       ## Combatant → Label
var selected := ""          ## room id shown in the side panel
var hover := ""
var yaw := 45.0
var focus := Vector3(W / 2, 0, D / 2)   ## camera target (a room when one is selected)
var _cam_tw: Tween
var _shot_path := ""
var _frames := 0
var _money: Label


func _ready() -> void:
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
		camp.facilities = {"med_bay": 2, "armory": 1, "intel": 2, "training": 2}
		var dts := ["recover", "train", "hustle", "recover"]
		for i in camp.crew.size():
			camp.crew[i].downtime = dts[i % 4]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_view()
	_build_world()
	_build_ui()
	if selected != "":
		var r: Rect2 = ROOMS[selected][0]
		focus = Vector3(r.get_center().x, 0, r.get_center().y)
		cam.size = 7.5
		_place_camera()
		var right := Vector3(cam.global_basis.x.x, 0, cam.global_basis.x.z).normalized()
		focus += right * 2.2
	_place_camera()
	_resize()
	get_viewport().size_changed.connect(_resize)


func _process(_d: float) -> void:
	if _cam_tw and _cam_tw.is_running():
		_place_camera()
	for c in crew_nodes:
		var n: Node3D = crew_nodes[c]
		var l: Label = crew_labels[c]
		var p := _to_screen(n.position + Vector3(0, 2.3, 0))
		l.position = p - Vector2(l.size.x / 2, l.size.y)
	for id in labels:
		var r: Rect2 = ROOMS[id][0]
		var l: Label = labels[id]
		var p := _to_screen(Vector3(r.position.x + r.size.x / 2, WALL_H + 0.2, r.position.y + 0.6))
		l.position = p - Vector2(l.size.x / 2, l.size.y)
		l.modulate = Color(1, 1, 1, 1.0 if id == hover or id == selected else 0.8)
	if _shot_path != "":
		_frames += 1
		if _frames == 40:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


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
	env.background_color = Color("06080c")
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
	var moon := DirectionalLight3D.new()   # cold light through the skylights
	moon.rotation_degrees = Vector3(-60, 30, 0)
	moon.light_color = Color("7f9cd0")
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	svp.add_child(moon)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 18.0
	svp.add_child(cam)


func _resize() -> void:
	var win := Vector2(get_viewport().get_visible_rect().size)
	var px := maxf(1.0, roundf(win.y / 360.0))
	svp.size = Vector2i(maxi(1, int(win.x / px)), maxi(1, int(win.y / px)))
	screen.size = Vector2(svp.size) * px
	post.set_shader_parameter("src_size", Vector2(svp.size))


func _place_camera() -> void:
	var dir := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	var c := focus - dir * (1.6 if selected == "" else 0.0)   # overview: nudge the far rooms clear of the header
	cam.look_at_from_position(c + dir * 22.0 + Vector3(0, 20.0, 0), c, Vector3.UP)


func _to_screen(p: Vector3) -> Vector2:
	return cam.unproject_position(p) * (screen.size.x / maxf(1.0, float(svp.size.x)))


func _pick_floor(mouse: Vector2) -> Vector3:
	var sp := mouse / (screen.size.x / maxf(1.0, float(svp.size.x)))
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(sp), cam.project_ray_normal(sp))
	return hit if hit != null else Vector3(-99, 0, -99)


# --- World ----------------------------------------------------------------------------

static func _mat(col: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, emit := 0.0, rough := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, rough, emit)
	mi.position = pos + Vector3(0, size.y / 2, 0)
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, col: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _mat(col, 0.7, emit)
	mi.position = pos + Vector3(0, h / 2, 0)
	parent.add_child(mi)
	return mi


func _build_world() -> void:
	if world:
		world.queue_free()
	world = Node3D.new()
	svp.add_child(world)
	_box(world, Vector3(W + 1, 0.2, D + 1), Vector3(W / 2, -0.2, D / 2), Color("1a1e26"))   # slab
	_box(world, Vector3(W + 8, 0.1, D + 8), Vector3(W / 2, -0.35, D / 2), Color("0b0d12"))  # the lot outside
	for id in ROOMS:
		_build_room(id)
	# outer walls and the corridor between the two rows
	var wall := Color("2c3240")
	for z in [-0.15, D + 0.15]:
		_box(world, Vector3(W + 0.3, WALL_H, 0.3), Vector3(W / 2, 0, z), wall)
	for x in [-0.15, W + 0.15]:
		_box(world, Vector3(0.3, WALL_H, D + 0.3), Vector3(x, 0, D / 2), wall)
	_box(world, Vector3(W, 0.02, 1.0), Vector3(W / 2, 0, 7.5), Color("232836"))   # corridor floor
	_box(world, Vector3(1.2, 0.05, 0.5), Vector3(W + 0.4, 0, 7.5), Color("ff3b6b"), 2.0)   # the door, neon strip
	_place_crew()


func _build_room(id: String) -> void:
	var spec: Array = ROOMS[id]
	var r: Rect2 = spec[0]
	var accent := Color(spec[1])
	var lv := _room_level(id)
	var room := Node3D.new()
	room.name = id
	room.position = Vector3(r.position.x, 0, r.position.y)
	world.add_child(room)
	var floor_col := Color("20242e") if lv > 0 else Color("15171c")
	_box(room, Vector3(r.size.x - 0.2, 0.04, r.size.y - 0.2), Vector3(r.size.x / 2, 0, r.size.y / 2), floor_col)
	var wall := Color("323a4a")
	# interior partitions (corridor side has a doorway gap)
	_box(room, Vector3(0.2, WALL_H, r.size.y), Vector3(r.size.x, 0, r.size.y / 2), wall)
	var door_z := r.size.y if r.position.y == 0 else 0.0
	_box(room, Vector3(r.size.x * 0.4, WALL_H, 0.2), Vector3(r.size.x * 0.2, 0, door_z), wall)
	_box(room, Vector3(r.size.x * 0.4, WALL_H, 0.2), Vector3(r.size.x * 0.8, 0, door_z), wall)
	# neon trim on the corridor wall, brighter with level
	_box(room, Vector3(r.size.x * 0.36, 0.06, 0.06), Vector3(r.size.x * 0.2, WALL_H, door_z), accent, 0.6 + lv * 1.2)
	var light := OmniLight3D.new()
	light.position = Vector3(r.size.x / 2, 2.6, r.size.y / 2)
	light.light_color = accent.lerp(Color.WHITE, 0.55)
	light.omni_range = 7.5
	light.light_energy = [0.2, 0.9, 1.3][lv]
	light.shadow_enabled = lv > 0
	room.add_child(light)
	if lv == 0:
		_unbuilt(room, r)
		return
	match id:
		"med_bay": _props_med(room, lv, accent)
		"armory": _props_armory(room, lv, accent)
		"intel": _props_intel(room, lv, accent)
		"training": _props_training(room, lv, accent)
		"workshop": _props_workshop(room, lv, accent)
		"bunks": _props_bunks(room, lv, accent)


## Facilities by their level; the workshop is open while a Tech is on the crew; bunks are always in.
func _room_level(id: String) -> int:
	if Campaign.FACILITIES.has(id):
		return camp.level(id)
	if id == "workshop":
		return 2 if camp.best_tech() != null else 0
	return 1


func _unbuilt(room: Node3D, r: Rect2) -> void:
	var tarp := Color("2a2e36")
	for p in [Vector3(1.6, 0, 1.6), Vector3(2.8, 0, 1.4), Vector3(2.2, 0, 2.7), Vector3(r.size.x - 2, 0, r.size.y - 2.2)]:
		_box(room, Vector3(1.1, 0.8, 1.0), p, tarp)
	_box(room, Vector3(1.8, 0.05, 1.4), Vector3(r.size.x - 2.4, 0, 2.0), Color("3a3020"))   # a pallet


func _props_med(room: Node3D, lv: int, accent: Color) -> void:
	for i in (2 if lv == 1 else 3):
		var x := 1.4 + i * 2.2
		_box(room, Vector3(0.9, 0.45, 2.0), Vector3(x, 0, 1.6), Color("8a96a4"))      # bed
		_box(room, Vector3(0.8, 0.12, 0.4), Vector3(x, 0.45, 0.8), Color("b4bcc8"))   # pillow
		_cyl(room, 0.04, 1.5, Vector3(x + 0.6, 0, 0.8), Color("8a96a8"))              # IV stand
		_box(room, Vector3(0.2, 0.3, 0.1), Vector3(x + 0.6, 1.3, 0.8), accent, 1.2)   # bag
	_box(room, Vector3(1.6, 1.1, 0.5), Vector3(6.6, 0, 0.5), Color("5a6476"))         # cabinet
	if lv >= 2:
		_box(room, Vector3(1.0, 0.85, 2.0), Vector3(3.8, 0, 4.8), Color("7c8a9c"))    # surgical table
		_box(room, Vector3(0.7, 0.5, 0.1), Vector3(5.0, 1.0, 4.4), accent, 2.5)       # monitor
		_cyl(room, 0.5, 0.08, Vector3(3.8, 2.0, 4.8), Color("d8e8ff"), 1.2)           # surgical lamp


func _props_armory(room: Node3D, lv: int, accent: Color) -> void:
	_box(room, Vector3(3.2, 1.6, 0.4), Vector3(2.2, 0, 0.4), Color("3a4250"))         # gun rack
	for i in 6:
		_box(room, Vector3(0.08, 1.0, 0.12), Vector3(0.9 + i * 0.5, 0.4, 0.66), Color("15181e"))
	for p in [Vector3(5.5, 0, 1.2), Vector3(6.4, 0, 1.4), Vector3(5.9, 0.5, 1.3)]:
		_box(room, Vector3(0.8, 0.5, 0.6), p, Color("4a5a3a"))                       # ammo crates
	if lv >= 2:
		for i in 4:
			_box(room, Vector3(0.6, 1.8, 0.5), Vector3(1.0 + i * 0.65, 0, 6.2), Color("4c5668"))   # lockers
		_box(room, Vector3(2.4, 0.9, 1.0), Vector3(5.6, 0, 4.4), Color("5c4a36"))     # bench
		for i in 4:
			var g := _cyl(room, 0.09, 0.16, Vector3(4.9 + i * 0.4, 0.9, 4.4), Color("3e4a2e"))
			g.name = "grenade%d" % i
		_box(room, Vector3(2.2, 0.05, 0.05), Vector3(5.6, 1.7, 4.0), accent, 2.0)     # work light


func _props_intel(room: Node3D, lv: int, accent: Color) -> void:
	_box(room, Vector3(2.6, 0.75, 1.0), Vector3(2.4, 0, 1.6), Color("3a3448"))        # desk
	for i in 2:
		_box(room, Vector3(0.7, 0.45, 0.06), Vector3(1.8 + i * 1.1, 0.95, 1.2), accent, 2.2)   # screens
	_box(room, Vector3(0.5, 0.5, 0.5), Vector3(2.4, 0, 2.6), Color("2a2a30"))         # chair
	_box(room, Vector3(2.0, 1.2, 0.05), Vector3(5.6, 0.8, 0.12), Color("8a6a48"))     # corkboard
	for i in 5:
		_box(room, Vector3(0.25, 0.3, 0.03), Vector3(4.9 + i * 0.35, 1.2 + (i % 2) * 0.35, 0.16), Color("e8dcc0"))   # photos and notes
	if lv >= 2:
		for i in 3:
			_box(room, Vector3(0.8, 2.0, 0.9), Vector3(1.0 + i * 1.0, 0, 6.0), Color("1c2028"))   # server racks
			for k in 5:
				_box(room, Vector3(0.6, 0.04, 0.02), Vector3(1.0 + i * 1.0, 0.3 + k * 0.32, 5.54), accent, 3.0)
		for i in 3:
			_box(room, Vector3(0.9, 0.55, 0.06), Vector3(4.8 + i * 1.0, 1.6, 0.18), accent.lerp(Color("ff3b6b"), 0.3 * i), 2.0)   # wall of screens


func _props_training(room: Node3D, lv: int, accent: Color) -> void:
	_box(room, Vector3(4.0, 0.04, 3.0), Vector3(3.0, 0.02, 3.6), Color("2e3240"))     # mats
	_cyl(room, 0.3, 1.1, Vector3(6.4, 0.6, 1.4), Color("7a2a2a"))                    # heavy bag
	_cyl(room, 0.02, 1.0, Vector3(6.4, 1.7, 1.4), Color("888888"))                   # chain
	if lv >= 2:
		_box(room, Vector3(0.1, 1.6, 0.8), Vector3(1.0, 0, 6.2), Color("6a5a40"))     # target stand
		_cyl(room, 0.32, 0.04, Vector3(1.06, 1.2, 6.2), Color("e8e0d0"))
		_box(room, Vector3(1.6, 0.6, 0.5), Vector3(6.0, 0, 6.2), Color("2a2e36"))     # weight rack
		for i in 3:
			_cyl(room, 0.18, 0.08, Vector3(5.5 + i * 0.5, 0.6, 6.2), Color("1a1a1a"))
		_box(room, Vector3(3.0, 0.05, 0.05), Vector3(3.0, 2.2, 3.6), accent, 2.0)


func _props_workshop(room: Node3D, _lv: int, accent: Color) -> void:
	_box(room, Vector3(3.0, 0.9, 1.0), Vector3(2.4, 0, 0.8), Color("5c4a36"))         # bench
	_box(room, Vector3(3.0, 1.4, 0.06), Vector3(2.4, 1.0, 0.1), Color("3a4250"))      # tool board
	for i in 6:
		_box(room, Vector3(0.08, 0.4, 0.04), Vector3(1.2 + i * 0.45, 1.5, 0.16), Color("9aa4b4"))
	_box(room, Vector3(1.2, 1.4, 0.8), Vector3(6.2, 0, 1.0), Color("2e3440"))         # armour on a stand
	_cyl(room, 0.25, 0.6, Vector3(6.2, 1.4, 1.0), Color("4a5468"))
	_box(room, Vector3(0.3, 0.2, 0.3), Vector3(3.4, 0.9, 0.8), accent, 3.0)           # soldering glow


func _props_bunks(room: Node3D, _lv: int, accent: Color) -> void:
	for i in 2:
		var x := 1.2 + i * 1.6
		_box(room, Vector3(1.0, 0.4, 2.0), Vector3(x, 0, 1.4), Color("4a4e5a"))
		_box(room, Vector3(1.0, 0.1, 2.0), Vector3(x, 1.2, 1.4), Color("4a4e5a"))     # upper bunk
		for c in [Vector2(-0.45, 0.45), Vector2(0.45, 0.45), Vector2(-0.45, 2.35), Vector2(0.45, 2.35)]:
			_cyl(room, 0.04, 1.3, Vector3(x + c.x, 0, c.y), Color("2a2e36"))
	_box(room, Vector3(2.4, 0.5, 0.9), Vector3(5.6, 0, 5.8), Color("5a3a4a"))         # couch
	_box(room, Vector3(1.0, 0.4, 0.6), Vector3(5.6, 0, 4.6), Color("3a3020"))         # table
	_box(room, Vector3(0.7, 1.7, 0.7), Vector3(7.0, 0, 1.0), Color("c8ccd4"))         # fridge
	_box(room, Vector3(0.9, 0.5, 0.05), Vector3(5.6, 1.3, 6.85), accent.lerp(Color("40c8ff"), 0.6), 1.8)   # TV


# --- Crew -----------------------------------------------------------------------------------

## Where each downtime job puts people: hurt crew go to the med bay when it's built.
func _room_for(c: Combatant) -> String:
	if c.hp < c.max_hp() and camp.level("med_bay") > 0 and c.downtime == "recover":
		return "med_bay"
	match c.downtime:
		"train": return "training" if camp.level("training") > 0 else "bunks"
		"hustle": return "intel" if camp.level("intel") > 0 else "bunks"
	if c.role == "tech":
		return "workshop"
	return "bunks"


const SPOTS := {"med_bay": [Vector2(1.4, 3.2), Vector2(3.6, 3.2), Vector2(5.8, 3.2), Vector2(2.4, 5.4)],
	"training": [Vector2(2.2, 3.4), Vector2(3.8, 3.8), Vector2(5.4, 2.0), Vector2(2.8, 5.0)],
	"intel": [Vector2(2.4, 2.8), Vector2(4.6, 2.2), Vector2(5.8, 3.4), Vector2(3.4, 4.6)],
	"workshop": [Vector2(2.4, 2.0), Vector2(4.0, 2.4), Vector2(5.4, 3.0), Vector2(3.0, 4.6)],
	"bunks": [Vector2(4.6, 4.8), Vector2(6.4, 4.8), Vector2(3.0, 4.2), Vector2(5.4, 3.4)]}


func _place_crew() -> void:
	for c in crew_labels:
		(crew_labels[c] as Label).queue_free()
	crew_nodes.clear()
	crew_labels.clear()
	var used := {}
	for c in camp.alive_crew():
		var room := _room_for(c)
		var k: int = used.get(room, 0)
		used[room] = k + 1
		var r: Rect2 = ROOMS[room][0]
		var spot: Vector2 = SPOTS[room][k % 4]
		var n := CharModel.build(0, maxi(0, c.look_seed), String(c.role), c.weapons[0].id() if not c.weapons.is_empty() else "heavy_pistol")
		for mt in n.get_meta("mats", []):
			(mt as ShaderMaterial).set_shader_parameter("use_field", false)
		n.position = Vector3(r.position.x + spot.x, 0, r.position.y + spot.y)
		n.scale = Vector3.ONE * 1.3
		n.rotation.y = randf_range(-PI, PI) if room == "bunks" else PI * 0.8
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
	var rt: Rect2 = ROOMS[to][0]
	var taken := crew_nodes.keys().filter(func(o): return o != c and _room_for(o) == to).size()
	var spot: Vector2 = SPOTS[to][taken % 4]
	var dest := Vector3(rt.position.x + spot.x, 0, rt.position.y + spot.y)
	var pts: Array[Vector3] = []
	if from != to:
		var rf: Rect2 = ROOMS[from][0]
		pts.append(Vector3(rf.get_center().x, 0, 7.5))   # out through the door to the corridor
		pts.append(Vector3(rt.get_center().x, 0, 7.5))
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
		tw.tween_property(n, "position", p, d.length() / 1.6)
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


func _crew_label(c: Combatant) -> Label:
	var l := _text("%s\n%s" % [c.display_name.to_upper(), String(Campaign.DOWNTIME[c.downtime].name).to_upper()], Hud.F_TERM, 16, Hud.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(l)
	return l


# --- UI -------------------------------------------------------------------------------------

func _text(s: String, font: Font, size: int, col := Hud.TEXT) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(label: String, col: Color, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.add_theme_font_override("font", Hud.F_DISPLAY)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", col)
	b.add_theme_stylebox_override("normal", CutBox.make(Color(0.03, 0.045, 0.06, 0.95), Color(col, 0.5), 7, 0b0101))
	b.add_theme_stylebox_override("hover", CutBox.make(Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.97), col, 7, 0b0101))
	b.add_theme_stylebox_override("disabled", CutBox.make(Color(0.02, 0.025, 0.03, 0.8), Color(Hud.DIM, 0.2), 7, 0b0101))
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var head := HBoxContainer.new()
	head.position = Vector2(24, 16)
	head.add_theme_constant_override("separation", 22)
	ui.add_child(head)
	head.add_child(_text("SAFEHOUSE", Hud.F_DISPLAY, 48, Hud.GOLD))
	_money = _text("", Hud.F_TERM, 30, Hud.GREEN)
	_money.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_money)
	var board := _button("FIXER BOARD  ›", Hud.GOLD, func(): camp.save(); get_tree().change_scene_to_file(BOARD))
	board.custom_minimum_size = Vector2(220, 48)
	board.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	board.position = Vector2(get_viewport_rect().size.x - 244, 18)
	ui.add_child(board)
	var hint := _text("CLICK A ROOM TO UPGRADE IT · CLICK SOMEONE TO CHANGE THEIR DOWNTIME JOB · Q / E ROTATE · WHEEL ZOOM", Hud.F_TERM, 18, Hud.DIM)
	hint.position = Vector2(24, get_viewport_rect().size.y - 34)
	ui.add_child(hint)
	for id in ROOMS:
		var l := _text("", Hud.F_PIXEL, 18, Color(ROOMS[id][1]))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		labels[id] = l
		ui.add_child(l)
	for c in crew_nodes:
		crew_labels[c] = _crew_label(c)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CutBox.make(Hud.INK, Color(Hud.CYAN, 0.5), 12, 0b0101, Hud.CYAN, 12))
	panel.custom_minimum_size = Vector2(380, 0)
	ui.add_child(panel)
	_refresh_ui()


func _refresh_ui() -> void:
	_money.text = "DAY %d   %s eb   REP %d   HEAT %d" % [camp.day, Board._money(camp.eb), camp.rep, camp.heat]
	for id in ROOMS:
		var lv := _room_level(id)
		var pips := ""
		if Campaign.FACILITIES.has(id):
			pips = "  " + "◆".repeat(lv) + "◇".repeat(2 - lv)
		(labels[id] as Label).text = String(ROOMS[id][2]) + pips + ("" if lv > 0 else "  · EMPTY")
	for ch in panel.get_children():
		ch.queue_free()
	panel.visible = selected != ""
	if selected == "":
		return
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var accent := Color(ROOMS[selected][1])
	col.add_child(_text(String(ROOMS[selected][2]), Hud.F_DISPLAY, 32, accent))
	if Campaign.FACILITIES.has(selected):
		var d: Dictionary = Campaign.FACILITIES[selected]
		var lv := camp.level(selected)
		for i in d.desc.size():
			if String(d.desc[i]) != "":
				var l := _text(("✓ " if lv > i else "· ") + String(d.desc[i]), Hud.F_TERM, 18, Color(Hud.TEXT, 0.9 if lv > i else 0.55))
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size.x = 350
				col.add_child(l)
		var cost := camp.upgrade_cost(selected)
		if cost >= 0:
			col.add_child(_button(("BUILD" if lv == 0 else "UPGRADE") + "  %s eb" % Board._money(cost), Hud.GREEN,
				func(): camp.upgrade(selected); camp.save(); _rebuild(), camp.eb >= cost))
		else:
			col.add_child(_text("FULLY UPGRADED", Hud.F_TERM, 18, Hud.GREEN))
	else:
		var why := {"workshop": "A Tech on the crew works here: armour upgrades between gigs (on the fixer board's crew cards).",
			"bunks": "Where the crew sleeps, and where anyone recovering without a med bay rests up."}
		var l2 := _text(String(why.get(selected, "")), Hud.F_TERM, 18, Hud.TEXT)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.custom_minimum_size.x = 350
		col.add_child(l2)
	var here := camp.alive_crew().filter(func(c): return _room_for(c) == selected)
	if not here.is_empty():
		col.add_child(_text("HERE: " + ", ".join(here.map(func(c): return c.display_name.to_upper())), Hud.F_TERM, 18, Hud.CYAN))
	col.add_child(_button("CLOSE", Hud.DIM, func(): selected = ""; _refresh_ui(); _frame_selection()))
	panel.reset_size()
	var vs := get_viewport_rect().size
	panel.position = Vector2(vs.x - panel.size.x - 24, 90)


## Glide in on the selected room (or back out to the whole floor).
func _frame_selection() -> void:
	var goal := Vector3(W / 2, 0, D / 2)
	var size := 18.0
	if selected != "":
		var r: Rect2 = ROOMS[selected][0]
		goal = Vector3(r.get_center().x, 0, r.get_center().y)
		size = 7.5
		var right := Vector3(cam.global_basis.x.x, 0, cam.global_basis.x.z).normalized()
		goal += right * 2.2   # the room sits left of the info panel
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
		if c:   # cycle their downtime job; they walk to the matching room
			var keys: Array = Campaign.DOWNTIME.keys()
			var from := _room_for(c)
			c.downtime = keys[(keys.find(c.downtime) + 1) % keys.size()]
			camp.save()
			(crew_labels[c] as Label).text = "%s\n%s" % [c.display_name.to_upper(), String(Campaign.DOWNTIME[c.downtime].name).to_upper()]
			_walk(c, from, _room_for(c))
			_refresh_ui()
			return
		var picked := _room_at(_pick_floor(ev.position))
		if picked != selected:
			selected = picked
			_refresh_ui()
			_frame_selection()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		cam.size = clampf(cam.size + (-1.5 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.5), 9.0, 24.0)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_Q:
			yaw -= 90.0
			_place_camera()
		elif ev.keycode == KEY_E:
			yaw += 90.0
			_place_camera()


func _room_at(p: Vector3) -> String:
	for id in ROOMS:
		if (ROOMS[id][0] as Rect2).has_point(Vector2(p.x, p.z)):
			return id
	return ""


func _crew_at(mouse: Vector2) -> Combatant:
	var best: Combatant = null
	var bd := 40.0
	for c in crew_nodes:
		var d := _to_screen((crew_nodes[c] as Node3D).position + Vector3(0, 1.0, 0)).distance_to(mouse)
		if d < bd:
			bd = d
			best = c
	return best
