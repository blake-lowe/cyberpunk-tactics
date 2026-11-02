extends Node
## Playable tactical view: a generated scene in 3D, driven by Encounter.
## M4 first pass (M3 playtest verdicts): pixel-art render (low-res SubViewport + palette/dither
## post), night lighting with neon signs, street lamps and room lights, bloom; fog of war (building
## interiors appear only once the squad sees them; guards are drawn only while in sight); a
## Baldur's Gate 3 style HUD (view/hud.gd).
##
## Controls
##   WASD / arrows   pan          Mouse wheel   zoom          Q / E   rotate 90°
##   PageUp/PageDown change the floor you're viewing (floors above open up around the focus)
##   Left click      move (path preview while hovering the move grid)
##   Right click     attack the enemy under the cursor (X or Shift: shoot the cover in the way)
##   1 / 2 / 3       single shot / autofire / aimed head shot
##   R reload    J jack in (Netrunner, within 6 m of a terminal)    Space  end turn
##   C cutaway on/off    F1 new gig    F2 look settings    F3 toggle fog of war
## Screenshot mode:  -- --shot=path.png [--scene=x] [--profile=y] [--seed=n] [--pixel=3]
##   [--levels=0] [--dither=0.5] [--outline=0.4] [--bloom=0.8] [--contrast=1.1] [--ortho=1]
##   [--fog=0] [--zoom=24] [--yaw=45] [--lights=1] [--hover=x,y]

const FH := 1.6           # floor height in squares (3.2 m)
const POST_SHADER := preload("res://src/tactical/view/post.gdshader")
const SKY_SHADER := preload("res://src/tactical/view/sky.gdshader")

var m: TacMap
var enc: Encounter
var dice: Dice
var view_floor := 0
var cutaway := true
var fog_on := true
var mode := Attack.Mode.SINGLE
var cover_mode := false
var move_opts := {}
var hover := Vector3i(-1, -1, -1)
var mouse := Vector2.ZERO
var gig := {"scene": "skirmish", "profile": "", "seed": 11, "security": 1}
var look := {"pixel": 3.0, "levels": 0.0, "dither": 0.5, "contrast": 1.1, "saturation": 1.15, "outline": 0.4,
	"bloom": 0.8, "ortho": 0.0, "lights": 1.6, "dim": 0.65}

var svp: SubViewport
var screen: TextureRect
var post: ShaderMaterial
var env: Environment
var sun: DirectionalLight3D
var cam: Camera3D
var cam_target := Vector3.ZERO
var cam_yaw := 45.0
var cam_dist := 34.0
var hud: Hud
var world: Node3D
var floor_nodes: Array[Node3D] = []
var unit_nodes := {}
var door_nodes: Node3D
var grid_node: MeshInstance3D
var path_node: MultiMeshInstance3D
var ring: MeshInstance3D
var target_ring: MeshInstance3D
var lights: Array = []        ## [OmniLight3D, Vector3i cell, kind]
var fog_img: Image
var fog_tex: ImageTexture
var builder: WorldBuilder
var _log_seen := 0
var _shot_path := ""
var _shot_hover := Vector2i(-1, -1)
var _frames := 0
var _reveal := false
var _walk := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"shot": _shot_path = kv[1]
			"scene": gig.scene = kv[1]
			"profile": gig.profile = kv[1]
			"seed": gig.seed = int(kv[1])
			"security": gig.security = int(kv[1])
			"fog": fog_on = kv[1] != "0"
			"zoom": cam_dist = float(kv[1])
			"yaw": cam_yaw = float(kv[1])
			"reveal":  # review renders: everything explored
				_reveal = true
			"walk":  # review renders: the crew walks n squares toward the target first
				_walk = int(kv[1])
			"hover":
				if kv[1] == "guard":
					_shot_hover = Vector2i(-2, -2)
					continue
				var xy := kv[1].split(",")
				_shot_hover = Vector2i(int(xy[0]), int(xy[1]))
			_:
				if look.has(kv[0]):
					look[kv[0]] = float(kv[1])
	_build_view()
	new_gig()


func _process(delta: float) -> void:
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	if pan != Vector3.ZERO:
		cam_target += pan.rotated(Vector3.UP, deg_to_rad(-cam_yaw + 45)).normalized() * delta * cam_dist * 0.9
		_place_camera()
	if ring and ring.visible:
		ring.rotation.y += delta * 0.8
	if _shot_path != "":
		_frames += 1
		if _frames == 2 and _shot_hover == Vector2i(-2, -2):  # --hover=guard: the nearest guard in sight
			for u in enc.units:
				if u.team == 1 and enc.vision.visible.has(u.pos) and not u.c.dead:
					_shot_hover = Vector2i(u.pos.x, u.pos.y)
		if _frames == 3 and _shot_hover.x >= 0:
			hover = Vector3i(_shot_hover.x, _shot_hover.y, view_floor)
			mouse = cam.unproject_position(Vector3(hover.x + 0.5, view_floor * FH, hover.y + 0.5)) * look.pixel
			_update_hover()
		if _frames == 12:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


# --- View: low-res 3D viewport + post + HUD ---------------------------------------

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
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = POST_SHADER
	screen.material = post
	var bg := CanvasLayer.new()
	bg.layer = -1
	add_child(bg)
	bg.add_child(screen)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skm := ShaderMaterial.new()
	skm.shader = SKY_SHADER
	sky.sky_material = skm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a5470")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = true        # Forward+ only; ignored by the compatibility renderer
	env.ssr_enabled = true         # wet-street reflections on the user's GPU
	env.fog_enabled = true
	env.fog_light_color = Color("1a1430")
	env.fog_density = 0.004
	we.environment = env
	svp.add_child(we)
	sun = DirectionalLight3D.new()   # cold moonlight, just enough to read the blockout
	sun.rotation_degrees = Vector3(-58, 30, 0)
	sun.light_color = Color("98a6c8")
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	svp.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 34
	svp.add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.action.connect(_on_hud)
	hud.build_settings(look, [["pixel", "Pixel scale", 1, 6, 1], ["levels", "Palette steps", 0, 32, 1], ["dither", "Dither", 0, 1, 0.05],
		["contrast", "Contrast", 0.6, 1.6, 0.05], ["saturation", "Saturation", 0, 2, 0.05], ["outline", "Outline", 0, 1, 0.05],
		["bloom", "Bloom", 0, 2, 0.05], ["lights", "Light level", 0.2, 2, 0.05], ["ortho", "Orthographic", 0, 1, 1]], _apply_look)
	get_viewport().size_changed.connect(_apply_look)
	_apply_look()


func _apply_look() -> void:
	var px := maxf(1.0, look.pixel)
	var win := Vector2(get_viewport().get_visible_rect().size)
	svp.size = Vector2i(maxi(1, int(win.x / px)), maxi(1, int(win.y / px)))
	post.set_shader_parameter("src_size", Vector2(svp.size))
	post.set_shader_parameter("levels", look.levels)
	post.set_shader_parameter("dither", look.dither)
	post.set_shader_parameter("contrast", look.contrast)
	post.set_shader_parameter("saturation", look.saturation)
	post.set_shader_parameter("outline", look.outline)
	env.glow_intensity = look.bloom
	env.glow_strength = 1.0
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL if look.ortho > 0.5 else Camera3D.PROJECTION_PERSPECTIVE
	for l in lights:
		l[0].light_energy = l[0].get_meta("base", 1.0) * look.lights
	_apply_world_look()
	if cam_target != Vector3.ZERO:
		_place_camera()


# --- Gig setup -------------------------------------------------------------------

func new_gig() -> void:
	var o := {"security": gig.security}
	if gig.profile != "":
		o["profile"] = gig.profile
	m = SceneGen.generate(gig.seed, "neighborhood" if gig.profile != "" else gig.scene, o)
	dice = Dice.new(gig.seed + 1)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	enc = Encounter.setup(m, dice, crew)
	_log_seen = 0
	_build_world()
	var d: Dictionary = enc.units[0]
	cam_target = Vector3(d.pos.x + 0.5, 0, d.pos.y + 0.5).lerp(Vector3(m.w / 2.0, 0, m.h / 2.0), 0.75 if m.w <= 40 else 0.3)
	_place_camera()
	enc.next_turn()
	if _reveal:
		for f in m.floors:
			for y in m.h:
				for x in m.w:
					enc.vision.explored[Vector3i(x, y, f)] = true
	for i in _walk:  # scripted approach for review renders: each crew member walks toward the main door
		for u in enc.alive(0):
			var door := Vector3i(m.w / 2, m.h / 2, 0)
			for e in m.entrances:
				if e.main:
					door = Vector3i(e.pos.x, e.pos.y, 0)
			var p := enc.nav.path(u.pos, door, enc.occupied(u))
			if p.size() > 1:
				u.pos = p[0]
				enc.los.open_doors[p[0]] = true if m.t(0, p[0].x, p[0].y) == TacMap.T.DOOR else false
				if not enc.los.open_doors[p[0]]:
					enc.los.open_doors.erase(p[0])
		enc.refresh_vision()
		enc.update_alerts()
	if _walk > 0:
		cam_target = Vector3(enc.cur.pos.x + 0.5, 0, enc.cur.pos.y + 0.5).lerp(Vector3(m.w / 2.0, 0, m.h / 2.0), 0.5)
		_place_camera()
	_after_action()


# --- World -------------------------------------------------------------------------

func _unlit(col: Color, alpha := 1.0, glow := 1.0) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(col * glow, alpha)
	if alpha < 1.0:
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mt


func _build_world() -> void:
	if world:
		world.queue_free()
	world = Node3D.new()
	svp.add_child(world)
	fog_img = Image.create(m.w, m.h * m.floors, false, Image.FORMAT_L8)
	fog_tex = ImageTexture.create_from_image(fog_img)
	_update_fog()
	builder = WorldBuilder.new(m, enc.vision, fog_tex)
	floor_nodes = builder.build(world)
	for s in builder.surfaces():
		floor_nodes[0].add_child(s)
	unit_nodes.clear()
	lights.clear()
	_build_lights()
	door_nodes = Node3D.new()
	world.add_child(door_nodes)
	grid_node = MeshInstance3D.new()
	world.add_child(grid_node)
	path_node = MultiMeshInstance3D.new()
	world.add_child(path_node)
	ring = _ring(Color("f9c80e"), 0.36)
	target_ring = _ring(Color("ff3b4f"), 0.4)
	for u in enc.units:
		var n := UnitModel.build(u.team, u.id if u.team == 0 else 0)
		if u.team == 0:  # crew carry a small light (XCOM-style) so they read at night through the pixel filter
			var pl := OmniLight3D.new()
			pl.light_color = Color("cfe6ff")
			pl.light_energy = 0.4
			pl.omni_range = 2.6
			pl.position = Vector3(0, 1.1, 0.2)
			n.add_child(pl)
		world.add_child(n)
		unit_nodes[u.id] = n
	_apply_world_look()
	_refresh()


func _apply_world_look() -> void:
	if builder:
		for mt in builder.materials():
			mt.set_shader_parameter("explored_dim", look.dim)


func _ring(col: Color, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r - 0.04
	t.outer_radius = r
	t.rings = 24
	t.material = _unlit(col, 1.0, 2.2)
	mi.mesh = t
	mi.scale = Vector3(1, 0.3, 1)
	world.add_child(mi)
	return mi


func _build_lights() -> void:
	for e in LightPlan.plan(m, m.seed_value):
		var cell: Vector3i = e.cell
		var fn: Node3D = floor_nodes[cell.z]
		var base := Vector3(cell.x + 0.5, cell.z * FH, cell.y + 0.5)
		var l := OmniLight3D.new()
		l.light_color = e.color
		l.omni_range = e.range
		l.omni_attenuation = 1.4
		l.set_meta("base", e.energy)
		match e.kind:
			"sign":
				var out := Vector3(e.out.x, 0, e.out.y)
				l.position = base + out * 0.9 + Vector3(0, 1.15, 0)
				var sign := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.75, 0.16, 0.06) if e.out.y != 0 else Vector3(0.06, 0.16, 0.75)
				bm.material = _unlit(e.color, 1.0, 1.6)
				sign.mesh = bm
				sign.position = base + out * 0.55 + Vector3(0, 1.3, 0)
				fn.add_child(sign)
			"lamp":
				l.position = base + Vector3(0, 1.45, 0)
				var pole := MeshInstance3D.new()
				var pm := CylinderMesh.new()
				pm.top_radius = 0.025
				pm.bottom_radius = 0.035
				pm.height = 1.5
				pm.material = builder.mat("post", 0, false)
				pole.mesh = pm
				pole.position = base + Vector3(0.3, 0.75, 0.3)
				fn.add_child(pole)
				var arm := MeshInstance3D.new()
				var am := BoxMesh.new()
				am.size = Vector3(0.4, 0.03, 0.03)
				am.material = pm.material
				arm.mesh = am
				arm.position = base + Vector3(0.12, 1.5, 0.3)
				fn.add_child(arm)
				var head := MeshInstance3D.new()
				var hm := BoxMesh.new()
				hm.size = Vector3(0.2, 0.04, 0.12)
				hm.material = _unlit(e.color, 1.0, 2.5)
				head.mesh = hm
				head.position = base + Vector3(-0.05, 1.48, 0.3)
				fn.add_child(head)
				l.position = head.position - Vector3(0, 0.05, 0)
			"room":
				l.position = base + Vector3(0, FH * 0.85, 0)
			"hazard":
				l.position = base + Vector3(0, 0.6, 0)
		fn.add_child(l)
		lights.append([l, cell, e.kind])
	_apply_look()


# --- Refresh: fog, cutaway, units, grid, HUD -------------------------------------

func _refresh() -> void:
	_update_fog()
	_update_cut()
	for l in lights:  # rooms stay dark until explored, so a reveal reads as lights coming on
		var cell: Vector3i = l[1]
		l[0].visible = l[2] != "room" or not fog_on or enc.vision.explored.has(cell)
	_build_doors()
	for u in enc.units:
		var n: Node3D = unit_nodes[u.id]
		var seen: bool = u.team == 0 or not fog_on or enc.vision.visible.has(u.pos)
		n.visible = seen and not _cut_hides(u.pos)
		n.position = Vector3(u.pos.x + 0.5, u.pos.z * FH, u.pos.y + 0.5)
		n.scale = Vector3.ONE * 1.2
		if u.c.dead or u.c.wound_state() == Combatant.Wound.MORTAL:
			n.rotation = Vector3(deg_to_rad(-88), n.rotation.y, 0)
			n.position.y += 0.08
		else:
			n.rotation.x = 0
			var foes := enc.alive(1 - u.team).filter(func(o): return o.alerted or u.team == 1)
			if u.team == 1 and not u.alerted:
				foes = []
			if not foes.is_empty():
				foes.sort_custom(func(a, b): return Vector3(a.pos - u.pos).length() < Vector3(b.pos - u.pos).length())
				var d: Vector3i = foes[0].pos - u.pos
				n.rotation.y = atan2(float(d.x), float(d.y))
	if not enc.cur.is_empty():
		ring.visible = enc.cur.team == 0 or enc.vision.visible.has(enc.cur.pos)
		ring.position = Vector3(enc.cur.pos.x + 0.5, enc.cur.pos.z * FH + 0.04, enc.cur.pos.y + 0.5)
	_draw_grid()
	hud.refresh(enc, mode, cover_mode, "FLOOR %d / %d   ·   %s   ·   %s" % [view_floor + 1, m.floors, gig.scene.replace("_", " ").to_upper(),
		"ENGAGED" if enc.engaged() else "UNDETECTED"])
	_toast_new_log()


func _cut_radius() -> float:
	return clampf(cam_dist * 0.3, 5.0, 13.0) if cutaway else 0.0


func _update_cut() -> void:
	RenderingServer.global_shader_parameter_set("cut_center", Vector3(cam_target.x, view_floor, cam_target.z))
	RenderingServer.global_shader_parameter_set("cut_radius", _cut_radius())


func _cut_hides(v: Vector3i) -> bool:
	return v.z > view_floor and Vector2(v.x + 0.5 - cam_target.x, v.y + 0.5 - cam_target.z).length() < _cut_radius()


func _update_fog() -> void:
	var data := PackedByteArray()
	data.resize(m.w * m.h * m.floors)
	if not fog_on:
		data.fill(255)
	else:
		for f in m.floors:
			for y in m.h:
				for x in m.w:
					data[(f * m.h + y) * m.w + x] = [0, 128, 255][enc.vision.state(Vector3i(x, y, f))]
	fog_img.set_data(m.w, m.h * m.floors, false, Image.FORMAT_L8, data)
	fog_tex.update(fog_img)


## Door leaves: closed in the wall line, or swung open 90° on the hinge; a lock light on the frame.
func _build_doors() -> void:
	for ch in door_nodes.get_children():
		ch.queue_free()
	for d in m.doors:
		var v := Vector3i(d.pos.x, d.pos.y, d.floor)
		if m.t(d.floor, d.pos.x, d.pos.y) != TacMap.T.DOOR or (fog_on and not enc.vision.explored.has(v)):
			continue
		var leaf := builder.door_leaf(d)
		var horiz: bool = leaf.horiz
		var c: Vector3 = leaf.center
		var open: bool = enc.los.open_doors.has(v)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.material = builder.mat("door", d.floor)
		var along := horiz != open
		bm.size = Vector3(0.88, 1.1, 0.05) if along else Vector3(0.05, 1.1, 0.88)
		mi.mesh = bm
		mi.position = c
		if open:
			mi.position += Vector3(-0.44, 0, 0.44) if horiz else Vector3(0.44, 0, -0.44)
		door_nodes.add_child(mi)
		var lamp := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.05, 0.08, 0.05)
		var locked: bool = enc.nav.locked.has(v)
		lm.material = _unlit(Color("ff3030") if locked else Color("30ff90"), 1.0, 3.0)
		lamp.mesh = lm
		lamp.position = c + (Vector3(0.47, 0.05, 0.26) if horiz else Vector3(0.26, 0.05, 0.47))
		door_nodes.add_child(lamp)


## Move range as one marching-squares area (no tiles), with the hovered path as small markers.
func _draw_grid() -> void:
	move_opts = {}
	if _crew_turn() and enc.turn.can_move():
		move_opts = enc.move_options()
	var mask := {}
	for v in move_opts:
		if v.z == view_floor:
			mask[Vector2i(v.x, v.y)] = true
	var tris := WorldBuilder.marching(func(x: int, y: int) -> bool: return mask.has(Vector2i(x, y)), m.w, m.h)
	if tris.is_empty():
		grid_node.mesh = null
	else:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var y := view_floor * FH + 0.09
		for i in range(0, tris.size(), 3):
			for k in [0, 1, 2, 0, 2, 1]:
				var p: Vector2 = tris[i + k]
				st.add_vertex(Vector3(p.x, y, p.y))
		grid_node.mesh = st.commit()
		var mt := _unlit(Color("05d9e8"), 0.09, 1.0)
		mt.cull_mode = BaseMaterial3D.CULL_DISABLED
		grid_node.material_override = mt
	_draw_path()


func _tiles(cells: Array, col: Color, alpha: float, s: float) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = _unlit(col, alpha, 1.4)
	mm.mesh = box
	mm.instance_count = cells.size()
	for i in cells.size():
		var v: Vector3i = cells[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, 0.02, s)), Vector3(v.x + 0.5, v.z * FH + 0.03, v.y + 0.5)))
	return mm


func _draw_path() -> void:
	var cells := []
	if move_opts.has(hover) and _crew_turn():
		cells = Array(enc._with_locks(func(): return enc.nav.path(enc.cur.pos, hover, enc.occupied(enc.cur))))
	path_node.multimesh = _tiles(cells, Color("f9c80e"), 0.9, 0.16)


func _place_camera() -> void:
	var fy := view_floor * FH
	var off := Vector3(0, cam_dist * 0.78, cam_dist * 0.62).rotated(Vector3.UP, deg_to_rad(cam_yaw))
	cam.position = cam_target + Vector3(0, fy, 0) + off
	cam.look_at(cam_target + Vector3(0, fy, 0))
	cam.size = cam_dist * 0.62
	_update_cut()


# --- Input ------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse = ev.position
		var h := _pick(ev.position)
		if h != hover:
			hover = h
			_draw_path()
		_update_hover()
	elif ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP: cam_dist = maxf(8, cam_dist * 0.9); _place_camera()
			MOUSE_BUTTON_WHEEL_DOWN: cam_dist = minf(160, cam_dist * 1.1); _place_camera()
			MOUSE_BUTTON_LEFT: _click_move()
			MOUSE_BUTTON_RIGHT: _click_attack(ev.shift_pressed or cover_mode)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_Q: cam_yaw -= 90; _place_camera()
			KEY_E: cam_yaw += 90; _place_camera()
			KEY_PAGEUP: view_floor = mini(view_floor + 1, m.floors - 1); _place_camera(); _refresh()
			KEY_PAGEDOWN: view_floor = maxi(view_floor - 1, 0); _place_camera(); _refresh()
			KEY_C: cutaway = not cutaway; _refresh()
			KEY_1: _on_hud("mode", 0)
			KEY_2: _on_hud("mode", 1)
			KEY_3: _on_hud("mode", 2)
			KEY_X: _on_hud("cover_mode", null)
			KEY_R: _on_hud("reload", null)
			KEY_J: _on_hud("jack_in", null)
			KEY_SPACE: _on_hud("end_turn", null)
			KEY_F1: gig.seed += 1; new_gig()
			KEY_F2: hud.settings.visible = not hud.settings.visible
			KEY_F3: fog_on = not fog_on; _refresh()


func _on_hud(name: String, arg: Variant) -> void:
	match name:
		"mode":
			mode = [Attack.Mode.SINGLE, Attack.Mode.AUTOFIRE, Attack.Mode.AIMED_HEAD][int(arg)]
			cover_mode = false
			_refresh(); _update_hover()
		"cover_mode": cover_mode = not cover_mode; _refresh(); _update_hover()
		"reload": _reload()
		"jack_in": _jack_in()
		"end_turn": _end_turn()
		"net":
			if _crew_turn():
				var r := enc.net_action(String(arg))
				if not r.get("ok", false):
					hud.toast(String(r.get("reason", "can't")))
				elif r.has("success"):
					_float(enc.cur, "%s %s" % [String(arg).replace("_", "-").to_upper(), "OK" if r.success else "FAILED"], Color("d68cff"))
				_after_action()
		"net_move":
			var run: NetRun = enc.runs.get(enc.cur.id)
			if run and not run.move_to(int(arg)):
				hud.toast("Blocked by a firewall or ICE.")
			_after_action()


func _pick(screen_pos: Vector2) -> Vector3i:
	var sp := screen_pos / maxf(1.0, look.pixel)
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	var hit: Variant = Plane(Vector3.UP, view_floor * FH).intersects_ray(o, d)
	if hit == null:
		return Vector3i(-1, -1, -1)
	return Vector3i(floori(hit.x), floori(hit.z), view_floor)


func _crew_turn() -> bool:
	return enc.state == "playing" and not enc.cur.is_empty() and enc.cur.team == 0


func _click_move() -> void:
	if _crew_turn() and move_opts.has(hover) and enc.move_to(hover):
		_after_action()


func _unit_at(v: Vector3i) -> Dictionary:
	for u in enc.units:
		if u.pos == v and not u.c.dead and (u.team == 0 or not fog_on or enc.vision.visible.has(v)):
			return u
	return {}


func _click_attack(at_cover: bool) -> void:
	if not _crew_turn() or enc.cur.c.weapons.is_empty():
		return
	var w: Weapon = enc.cur.c.weapons[0]
	var t := _unit_at(hover)
	if at_cover or t.is_empty():
		var r := {}
		if not t.is_empty():
			var p := enc.preview(t, w, mode)
			if p.blocker.x >= 0:
				r = enc.shoot_cover(p.blocker, w)
		elif enc.los.blocker(hover) != "":
			r = enc.shoot_cover(hover, w)
		if r.get("ok", false):
			hud.toast("%d damage to cover%s" % [r.damage, " — destroyed" if r.left == 0 else " (%d HP left)" % r.left])
			if r.left == 0:
				_build_world()
		_after_action()
		return
	if t.team == 0:
		return
	var before_hp: int = t.c.hp
	var r := enc.attack(t, w, mode)
	if r.get("ok", true) == false:
		hud.toast(r.reason)
	elif r.get("dodged", false):
		_float(t, "DODGE", Color("63c7d6"))
	elif r.get("hit", false):
		_float(t, "-%d" % (before_hp - t.c.hp), Color("ff3b4f"))
	else:
		_float(t, "MISS", Color("8d98a1"))
	_after_action()


func _reload() -> void:
	if _crew_turn() and not enc.cur.c.weapons.is_empty() and enc.turn.use_action():
		enc.cur.c.weapons[0].reload()
		enc.say("%s reloads." % enc.cur.c.display_name)
		_after_action()


func _jack_in() -> void:
	if not _crew_turn():
		return
	var pts := enc.jack_points(enc.cur)
	if pts.is_empty():
		hud.toast("No terminal within 6 m.")
	elif enc.jack_in(pts[0]):
		enc.net_left = NetRun.net_actions(NetRun.interface_rank(enc.cur.c)) - 1
	_after_action()


func _end_turn() -> void:
	if not _crew_turn():
		return
	var hp_before := {}
	for u in enc.units:
		hp_before[u.id] = u.c.hp
	enc.end_turn()
	enc.next_turn()
	for u in enc.units:
		if u.c.hp < hp_before[u.id] and (u.team == 0 or enc.vision.visible.has(u.pos)):
			_float(u, "-%d" % (hp_before[u.id] - u.c.hp), Color("ff3b4f"))
	_after_action()


func _after_action() -> void:
	if enc.refresh_vision():
		pass
	_refresh()
	_update_hover()


func _toast_new_log() -> void:
	for i in range(_log_seen, enc.log.size()):
		if enc.log[i].contains("spots"):
			hud.toast("⚠ " + enc.log[i].to_upper())
	_log_seen = enc.log.size()


## Floating callout over a unit, drawn on the HUD layer so it stays crisp above the pixel filter.
func _float(u: Dictionary, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Hud.F_DISPLAY)
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	var wp := Vector3(u.pos.x + 0.5, u.pos.z * FH + 1.1, u.pos.y + 0.5)
	l.position = cam.unproject_position(wp) * look.pixel - Vector2(30, 20)
	hud.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 50, 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.tween_callback(l.queue_free)


func _update_hover() -> void:
	target_ring.visible = false
	if not _crew_turn():
		hud.tip("", mouse)
		return
	var t := _unit_at(hover)
	if t.is_empty() or t.team == 0 or enc.cur.c.weapons.is_empty():
		if cover_mode and enc.los.blocker(hover) != "":
			hud.tip("[b]%s[/b]" % ("Cover piece · [code]%d HP[/code]" % enc.los.cover_hp[hover] if enc.los.cover_hp.get(hover, 0) > 0 else "Wall / door"), mouse, "// SHOOT COVER", Hud.GOLD)
		elif move_opts.has(hover):
			var p: Array[Vector3i] = enc._with_locks(func(): return enc.nav.path(enc.cur.pos, hover, enc.occupied(enc.cur)))
			hud.tip("[code]%d / %d[/code] squares" % [enc.nav.cost_of(enc.cur.pos, p), enc.turn.squares_available()], mouse, "// MOVE", Color("ffb000"))
		else:
			hud.tip("", mouse)
		return
	target_ring.visible = true
	target_ring.position = Vector3(t.pos.x + 0.5, t.pos.z * FH + 0.04, t.pos.y + 0.5)
	var w: Weapon = enc.cur.c.weapons[0]
	var p := enc.preview(t, w, mode)
	var c: Combatant = t.c
	var lines := ["[b]%s[/b]  [color=#7d8a96]%s[/color]" % [c.display_name, c.role.capitalize()]]
	if p.ok:
		var pct := roundi(p.chance * 100)
		var col := "#39f0a0" if pct >= 65 else ("#f9c80e" if pct >= 35 else "#ff3b4f")
		lines.append("[code][font_size=44][color=%s]%d%%[/color][/font_size][/code]  to hit · %s" % [col, pct, ["Single", "Autofire", "Head shot", "Leg", "Held"][mode]])
		lines.append("Range %d m · DV %d · %s" % [roundi(Los.distance_m(p.from, t.pos)), int(p.dv), w.def.name])
		if p.blocker.x >= 0 and p.from != enc.cur.pos:
			lines.append("[color=#05d9e8]Leaning out of cover[/color]")
	else:
		lines.append("[color=#ff3b4f]%s[/color]" % String(p.reason).capitalize())
		if p.get("blocker", Vector3i(-1, -1, -1)).x >= 0:
			lines.append("[color=#7d8a96]X: shoot the cover in the way[/color]")
	lines.append("HP %d/%d · SP head %d body %d" % [c.hp, c.max_hp(), c.sp("head"), c.sp("body")])
	hud.tip("\n".join(lines), mouse, "// TARGET · HOSTILE", Hud.RED)
