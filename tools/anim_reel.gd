extends SceneTree
## Review videos of every CharAnims clip: renders each clip on a character in a small studio at
## the game's 3/4 camera angle, frame by frame (run with --fixed-fps 24), as PNG sequences
## under OUT/<clip>/; tools/anim_reel.sh encodes them. Pistol clips use a pistol-armed body.
## Usage: godot --rendering-method gl_compatibility --fixed-fps 24 --path . -s tools/anim_reel.gd -- OUT [clip ...]

const W := 480
const H := 400
const MAX_SECS := 6.0

var out := ""
var clips: Array = []
var vp: SubViewport
var rifle: CharModel
var pistol: CharModel
var cur: CharModel
var ci := -1
var frame := 0
var frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	clips = Array(args.slice(1)) if args.size() > 1 else CharAnims.CLIPS.keys()
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a1e26")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a7890")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_energy = 1.1
	key.shadow_enabled = true
	key.light_cull_mask = 0xFFFFF
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_color = Color("05d9e8")
	rim.light_energy = 0.6
	rim.light_cull_mask = 0xFFFFF
	vp.add_child(rim)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("3a404a")
	fl.material_override = fm
	vp.add_child(fl)
	for k in 9:   # grid lines: one square = 1 unit, so speed and travel read
		for axis in 2:
			var ln := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(8, 0.004, 0.012) if axis == 0 else Vector3(0.012, 0.004, 8)
			ln.mesh = bm
			ln.position = Vector3(0, 0.002, k - 4.0) if axis == 0 else Vector3(k - 4.0, 0.002, 0)
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color("4c5462")
			ln.material_override = lm
			vp.add_child(ln)
	rifle = CharModel.build(0, 0, "solo", "assault_rifle")
	pistol = CharModel.build(0, 2, "techie", "heavy_pistol")
	for c: CharModel in [rifle, pistol]:
		c.scale = Vector3.ONE * 1.3
		c.rotation.y = deg_to_rad(-30)
		vp.add_child(c)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(1.75, 1.9, 2.55), Vector3(0, 0.5, 0.15))


func _start() -> void:   # first frame: the models are ready now, so their own clip picker can be switched off
	for c: CharModel in [rifle, pistol]:
		c.hold_state = true
	_next()


func _next() -> void:
	ci += 1
	if ci >= clips.size():
		quit()
		return
	var clip: String = clips[ci]
	cur = pistol if clip.begins_with("pistol") else rifle
	rifle.visible = cur == rifle
	pistol.visible = cur == pistol
	cur.reset_gun()
	cur.state = clip
	cur.anim.play(clip)
	cur.anim.seek(0.0, true)
	var a := cur.anim.get_animation(clip)
	var secs := clampf(a.length * (2.0 if a.length < 1.2 and a.loop_mode != Animation.LOOP_NONE else 1.0), 1.5, MAX_SECS)
	if a.loop_mode == Animation.LOOP_NONE:
		secs = minf(a.length + 0.6, MAX_SECS)
	frames = int(secs * 24.0)
	frame = -2   # two warm-up frames so the first saved frame shows this clip
	DirAccess.make_dir_recursive_absolute(out.path_join(clip))


func _process(_d: float) -> bool:
	if ci < 0:
		_start()
		return false
	if ci >= clips.size():
		return true
	frame += 1
	if OS.has_environment("REEL_DEBUG") and frame % 20 == 0:
		print(clips[ci], " ", cur.anim.current_animation, " ", cur.anim.current_animation_position, " playing ", cur.anim.is_playing())
	if frame >= 1:
		vp.get_texture().get_image().save_png(out.path_join(clips[ci]).path_join("%04d.png" % frame))
	if frame >= frames:
		_next()
	return false
