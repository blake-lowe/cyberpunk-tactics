extends Node
## Playable tactical view: a generated scene in 3D, driven by Encounter.
## M4 first pass (M3 playtest verdicts): pixel-art render (low-res SubViewport + palette/dither
## post), night lighting with neon signs, street lamps and room lights, bloom; fog of war (building
## interiors appear only once the squad sees them; guards are drawn only while in sight); a
## Baldur's Gate 3 style HUD (view/hud.gd).
##
## Controls
##   WASD / arrows   pan          Mouse wheel   zoom
##   Q / E           rotate 90° (smooth)        Middle-drag   rotate freely        H  controls hint
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
var look := {"pixel": 0.0, "palette": 1.0, "levels": 0.0, "dither": 0.3, "contrast": 1.0, "saturation": 1.1, "outline": 0.35,
	"bloom": 1.2, "ortho": 1.0, "lights": 1.0, "dim": 0.5, "spill": 1.0}

## Curated palette (M4b critique: a real limited palette instead of free-floating mids): ink and
## navy ramps, warm concrete, cool greys, skin, wood, foliage, and each neon in two steps.
## Round 2: each neon has a 4-step ramp (deep, mid, full, pale) so coloured light keeps its hue in
## shadow and highlight; skin and wood are cut to two steps each; matching happens in OKLab.
## Round 3: neutrals first; neon-ramp entries are only allowed for saturated pixels (post shader),
## so shadows go navy instead of a violet wash. Warm darks added for earth.
const PALETTE_NEUTRALS := 35
const PALETTE := ["05060a", "0b0e16", "141a26", "1e2636", "2a3448", "3a4660", "4e5c78",
	"1a1714", "2b2622", "3d3630", "554b42", "70665a", "8e8476",
	"4a5560", "66717c", "8a96a0", "b4bec6", "dfe6ea", "fff4e0",
	"8a5a40", "c08a68", "3a2418", "6a4a2a", "12261a", "1f4a2a", "3a6a3a", "6a5a50", "8a7a68",
	"241c18", "3a2c22", "5a4636", "2a3a5a", "2e1c10", "5a3414", "a0601e",
	"2a0a1e", "5a1040", "ff2a6d", "ffa0c0", "062430", "0a4a5a", "05d9e8", "aaf6ff",
	"2a1e06", "6a4a08", "f9c80e", "fff0a0", "1e0a2e", "4a1a6a", "b537f2", "e2b0ff",
	"2e1206", "7a3008", "ff6b1a", "ffc8a0", "06261a", "0e5a3a", "39f0a0", "b8ffe0",
	"7a1420", "ff3b4f"]
## Per-scene light: ambient, moon key, fog (round 2: the desert needs moonlit sand).
const LOOKS := {
	"default": {"ambient": "262c44", "amb_e": 0.65, "key": "8fa0e0", "key_e": 0.5, "fog": "0d1422", "fog_d": 0.0035},
	"badlands": {"ambient": "3a3550", "amb_e": 1.0, "key": "9ab0e8", "key_e": 0.75, "fog": "1a1828", "fog_d": 0.004},
}
const DECAL := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.0, 0.85, 0.9, 1.0);
uniform float pulse = 0.0;
uniform float ring = 0.0;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.15, d) * 0.45;
	if (ring > 0.5) a = max(a * 0.35, smoothstep(0.1, 0.0, abs(d - 0.82)));
	a *= 1.0 + pulse * 0.45 * sin(TIME * 4.0);
	ALBEDO = col.rgb * a * 1.6;
}
"""
const RANGE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec4 col : source_color = vec4(0.02, 0.85, 0.91, 1.0);
uniform vec4 col2 : source_color = vec4(1.0, 0.69, 0.0, 1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 v = texture(mask, UV).rg;
	float e1 = smoothstep(0.44, 0.5, v.r) - smoothstep(0.5, 0.56, v.r);
	float e2 = (smoothstep(0.44, 0.5, v.g) - smoothstep(0.5, 0.56, v.g)) * (1.0 - smoothstep(0.4, 0.5, v.r));
	float fill = smoothstep(0.45, 0.55, v.r);
	float dash = step(0.5, fract((wpos.x + wpos.z) * 1.2 - TIME * 0.5));
	ALBEDO = col.rgb * (e1 * (0.75 + 0.25 * dash) + fill * 0.04) + col2.rgb * e2 * 0.85 * (0.6 + 0.4 * dash);
}
"""

var svp: SubViewport
var screen: TextureRect
var post: ShaderMaterial
var env: Environment
var sun: DirectionalLight3D
var cam: Camera3D
var cam_target := Vector3.ZERO
var cam_yaw := 45.0
var yaw_goal := 45.0
var cam_dist := 20.0
var hud: Hud
var world: Node3D
var floor_nodes: Array[Node3D] = []
var unit_nodes := {}
var door_nodes: Node3D
var grid_node: MeshInstance3D
var path_node: MeshInstance3D
var range_img: Image
var range_tex: ImageTexture
var fires: Array[OmniLight3D] = []
var decals := {}              ## unit id → ground glow MeshInstance3D
var dash_opts := {}           ## squares reachable by also spending the Action on a Run (amber contour)
var rim: DirectionalLight3D
var open_cells := {}             ## Vector2i squares the cutaway may open (seen-into rooms + walls)
var room_xy := {}                ## room label → its squares, for opening rooms
const KERB := 0.07               # sidewalk height (WorldBuilder raises sidewalks)
var _last_cur := -1
var fx: Fx
var busy := false             ## animating events: input is ignored
var _rebuild := false         ## cover/wall destroyed during playback: rebuild the world after
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
var _focus := ""
var _attack_demo := false
var _shot_delay := 0.0
var _demo_ms := 0


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
			"yaw":
				cam_yaw = float(kv[1])
				yaw_goal = cam_yaw
			"reveal":  # review renders: everything explored
				_reveal = true
			"walk":  # review renders: the crew walks n squares toward the target first
				_walk = int(kv[1])
			"focus":  # review renders: centre the camera on a square ("center" = the target building)
				_focus = kv[1]
			"attack":  # review renders: the active crew member fires at the nearest guard
				_attack_demo = true
			"delay":  # review renders: take the shot this many seconds after the demo action
				_shot_delay = float(kv[1])
			"slow":  # review renders: slow motion so short effects land in a frame (software GL is slow)
				Engine.time_scale = float(kv[1])
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
		cam_target += pan.rotated(Vector3.UP, deg_to_rad(cam_yaw)).normalized() * delta * cam_dist * 0.9
		_place_camera()
	if absf(cam_yaw - yaw_goal) > 0.01:   # smooth Q/E turns
		cam_yaw = yaw_goal if absf(cam_yaw - yaw_goal) < 0.3 else lerpf(cam_yaw, yaw_goal, minf(1.0, delta * 12.0))
		_place_camera()
	_update_shake(delta)
	_animate_bodies(delta)
	for fl in fires:  # firelight flicker
		fl.light_energy = fl.get_meta("base", 1.0) * look.lights * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.013 + fl.position.x) + randf() * 0.08)
	if _shot_path != "":
		_frames += 1
		if _frames == 2 and _shot_hover == Vector2i(-2, -2):  # --hover=guard: the nearest guard in sight
			for u in enc.units:
				if u.team == 1 and (enc.vision.visible.has(u.pos) or not fog_on) and not u.c.dead:
					_shot_hover = Vector2i(u.pos.x, u.pos.y)
		if _frames == 3 and _shot_hover.x >= 0:
			hover = Vector3i(_shot_hover.x, _shot_hover.y, view_floor)
			mouse = _to_screen(Vector3(hover.x + 0.5, view_floor * FH, hover.y + 0.5))
			_update_hover()
		if _frames == 10 and _attack_demo:
			_demo_attack()
		var shoot_now: bool = _frames >= 12 if not _attack_demo else (_demo_ms > 0 and Time.get_ticks_msec() - _demo_ms >= int(_shot_delay * 1000.0 / Engine.time_scale))
		if shoot_now:
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
	env.ambient_light_color = Color("222a48")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR   # ACES washed saturated neon to white
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:  # wide, chunky halos once the low-res buffer is upscaled
		env.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)
	env.ssao_enabled = true        # Forward+ only; ignored by the compatibility renderer
	env.ssr_enabled = true         # wet-street reflections on the user's GPU
	env.fog_enabled = true
	env.fog_height = 1.2          # low haze over the far city
	env.fog_height_density = 0.08
	env.fog_light_color = Color("2a1020")
	env.fog_density = 0.006
	we.environment = env
	svp.add_child(we)
	sun = DirectionalLight3D.new()   # cold moonlight, just enough to read the blockout
	sun.rotation_degrees = Vector3(-55, 80, 0)   # key moonlight from the camera side (set in _place_camera)
	sun.light_color = Color("7f9cd0")
	sun.light_energy = 0.35
	sun.shadow_enabled = true
	svp.add_child(sun)
	rim = DirectionalLight3D.new()   # weak back light for silhouettes; `sun` is the key from the camera side
	rim.light_color = Color("5a6aa0")
	rim.light_energy = 0.25
	svp.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 34
	svp.add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.action.connect(_on_hud)
	hud.build_hint("WASD  PAN\nWHEEL  ZOOM\nQ / E  ROTATE 90\nMIDDLE-DRAG  ROTATE\nPGUP / PGDN  FLOOR\nC  CUTAWAY   F2  LOOK\nLMB  MOVE   RMB  FIRE\nH  HIDE THIS")
	hud.build_settings(look, [["pixel", "Pixel scale (0 auto)", 0, 6, 1], ["palette", "Palette", 0, 1, 1], ["levels", "Channel steps", 0, 32, 1], ["dither", "Dither", 0, 1, 0.05], ["spill", "Light spill", 0, 2, 0.05],
		["contrast", "Contrast", 0.6, 1.6, 0.05], ["saturation", "Saturation", 0, 2, 0.05], ["outline", "Outline", 0, 1, 0.05],
		["bloom", "Bloom", 0, 2, 0.05], ["lights", "Light level", 0.2, 2, 0.05], ["ortho", "Orthographic", 0, 1, 1]], _apply_look)
	get_viewport().size_changed.connect(_apply_look)
	_apply_look()


static func _oklab(c: Color) -> Vector3:
	var lin := func(x: float) -> float: return x / 12.92 if x <= 0.04045 else pow((x + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m2 := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s2 := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m2 - 0.0040720468 * s2,
		1.9779984951 * l - 2.4285922050 * m2 + 0.4505937099 * s2,
		0.0259040371 * l + 0.7827717662 * m2 - 0.8086757660 * s2)


## Screen pixels per buffer pixel: set, or auto so the buffer is ~360 lines tall at any window size.
func _px() -> float:
	if look.pixel >= 1.0:
		return float(look.pixel)
	return maxf(1.0, roundf(get_viewport().get_visible_rect().size.y / 360.0))


func _apply_look() -> void:
	var px := _px()
	var win := Vector2(get_viewport().get_visible_rect().size)
	# one spare buffer pixel on each side so the texel-snapped camera can shift the image sub-pixel
	svp.size = Vector2i(maxi(1, int(win.x / px)) + 2, maxi(1, int(win.y / px)) + 2)
	screen.size = Vector2(svp.size) * px
	post.set_shader_parameter("src_size", Vector2(svp.size))
	post.set_shader_parameter("palette_on", look.palette > 0.5)
	var pal := PackedVector3Array()
	for h in PALETTE:
		pal.append(_oklab(Color(h)))
	post.set_shader_parameter("palette", pal)
	post.set_shader_parameter("palette_n", pal.size())
	post.set_shader_parameter("palette_neutral_n", PALETTE_NEUTRALS)
	if hud and hud.portraits:   # portraits go through the same palette shader
		hud.portraits.post_shader = POST_SHADER
		hud.portraits.palette = pal
		hud.portraits.palette_neutral_n = PALETTE_NEUTRALS
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
	var lk: Dictionary = LOOKS.get(String(m.params.get("scene", "")), LOOKS["default"])
	env.ambient_light_color = Color(lk.ambient)
	env.ambient_light_energy = lk.amb_e
	sun.light_color = Color(lk.key)
	sun.light_energy = lk.key_e
	env.fog_light_color = Color(lk.fog)
	env.fog_density = lk.fog_d
	_build_world()
	_last_cur = -1
	_frame_unit(enc.units[0])
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
		_frame_unit(enc.cur)
	if _focus != "":
		var fc := Vector2(m.w / 2.0, m.h / 2.0)
		if _focus == "center":
			for st in m.structures:
				if st.target and st.has("rect"):
					fc = Vector2((st.rect as Rect2i).get_center())
		else:
			var xy := _focus.split(",")
			fc = Vector2(float(xy[0]), float(xy[1]))
		cam_target = Vector3(fc.x, 0, fc.y)
		_place_camera()
		_last_cur = enc.cur.id
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
	fog_img = Image.create(m.w, m.h * m.floors, false, Image.FORMAT_RG8)
	fog_tex = ImageTexture.create_from_image(fog_img)
	_update_fog()
	room_xy.clear()
	for f in m.floors:
		for y in m.h:
			for x in m.w:
				var l := m.label(f, x, y)
				if l >= 0:
					room_xy.get_or_add(l, []).append(Vector2i(x, y))
	builder = WorldBuilder.new(m, enc.vision, fog_tex)
	floor_nodes = builder.build(world)
	for s in builder.surfaces():
		floor_nodes[int(s.get_meta("floor", 0))].add_child(s)
	builder.lightfield = LightField.bake(m, enc.los, LightPlan.plan(m, m.seed_value) + builder.emitters)
	RenderingServer.global_shader_parameter_set("lf_tex", builder.lightfield)   # units read it too
	RenderingServer.global_shader_parameter_set("lf_dims", Vector3(m.w, m.h, m.floors))
	unit_nodes.clear()
	lights.clear()
	_build_lights()
	door_nodes = Node3D.new()
	world.add_child(door_nodes)
	fx = Fx.new()
	fx.rng.seed = gig.seed * 7 + 3
	world.add_child(fx)
	_flash_lights.clear()
	grid_node = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(m.w, m.h)
	grid_node.mesh = pm
	grid_node.position = Vector3(m.w / 2.0, 0, m.h / 2.0)
	var rsh := Shader.new()
	rsh.code = RANGE
	var rmt := ShaderMaterial.new()
	rmt.shader = rsh
	grid_node.material_override = rmt
	range_img = Image.create(m.w, m.h, false, Image.FORMAT_RG8)
	range_tex = null
	world.add_child(grid_node)
	path_node = MeshInstance3D.new()
	world.add_child(path_node)
	ring = _decal(Color("f9c80e"), 1.1, true, 1.0)
	target_ring = _decal(Color("ff3b4f"), 1.2, true, 0.0)
	decals.clear()
	for u in enc.units:
		var n := UnitModel.build(u.team, u.id if u.team == 0 else 0, String(u.c.role))
		decals[u.id] = _decal(Color("05d9e8"), 0.95, false, 0.0)
		decals[u.id].visible = false   # owner: no glows under units; they blend into the scene
		var blob := _decal(Color.BLACK, 0.75, false, 0.0, true)   # contact shadow
		blob.name = "blob"
		blob.get_parent().remove_child(blob)
		n.add_child(blob)
		blob.position = Vector3(0, 0.02, 0)
		blob.scale = Vector3.ONE / 1.3
		world.add_child(n)
		unit_nodes[u.id] = n
	_apply_world_look()
	_refresh()


func _apply_world_look() -> void:
	if builder:
		for mt in builder.materials():
			mt.set_shader_parameter("explored_dim", look.dim)
			mt.set_shader_parameter("spill", look.spill)
			mt.set_shader_parameter("lightfield", builder.lightfield)


## A soft additive glow on the ground (team colour under units; a ring for the active unit and
## the hovered target).
func _decal(col: Color, size: float, ring_mode: bool, pulse: float, shadow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(size, size)
	var sh := Shader.new()
	sh.code = DECAL if not shadow else DECAL.replace("blend_add", "blend_mul").replace("ALBEDO = col.rgb * a * 1.6;", "ALBEDO = mix(vec3(1.0), vec3(0.35), clamp(a * 2.2, 0.0, 1.0));")
	var mt := ShaderMaterial.new()
	mt.shader = sh
	mt.set_shader_parameter("col", col)
	mt.set_shader_parameter("ring", 1.0 if ring_mode else 0.0)
	mt.set_shader_parameter("pulse", pulse)
	q.material = mt
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	return mi


func _build_lights() -> void:
	fires.clear()
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
				bm.material = _unlit(e.color, 1.0, 1.5)
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
				var housing := MeshInstance3D.new()
				var hb := BoxMesh.new()
				hb.size = Vector3(0.14, 0.06, 0.14)
				hb.material = pm.material
				housing.mesh = hb
				housing.position = base + Vector3(0.22, 1.52, 0.3)
				fn.add_child(housing)
				var head := MeshInstance3D.new()
				var hm := BoxMesh.new()
				hm.size = Vector3(0.11, 0.015, 0.11)
				hm.material = _unlit(e.color, 1.0, 1.4)
				head.mesh = hm
				head.position = base + Vector3(0.22, 1.485, 0.3)
				fn.add_child(head)
				l.position = head.position - Vector3(0, 0.05, 0)
			"room":
				l.position = base + Vector3(0, FH * 0.85, 0)
				l.set_meta("base", e.energy * 0.5)   # the baked light field does most of the work
			"fire":
				l.position = base + Vector3(0, 0.45, 0)
				var pit := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.22
				cm.bottom_radius = 0.26
				cm.height = 0.1
				cm.material = builder.mat("stone", 0, false)
				pit.mesh = cm
				pit.position = base + Vector3(0, 0.05, 0)
				fn.add_child(pit)
				var flame := MeshInstance3D.new()
				var fm := SphereMesh.new()
				fm.radius = 0.16
				fm.height = 0.36
				fm.radial_segments = 6
				fm.rings = 3
				fm.material = _unlit(Color("ff9a30"), 1.0, 1.6)
				flame.mesh = fm
				flame.position = base + Vector3(0, 0.2, 0)
				fn.add_child(flame)
				fires.append(l)
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
		var dc: MeshInstance3D = decals[u.id]
		dc.visible = false
		n.set_meta("wound", u.c.wound_state())
		if u.c.dead:
			if not n.get_meta("fallen", false):   # died out of sight: just lie there
				n.position = Vector3(u.pos.x + 0.5, _gy(u.pos) + 0.08, u.pos.y + 0.5)
				n.rotation = Vector3(deg_to_rad(-88), n.rotation.y, 0)
				n.set_meta("fallen", true)
			continue
		n.position = Vector3(u.pos.x + 0.5, _gy(u.pos), u.pos.y + 0.5)
		n.scale = Vector3.ONE * 1.3   # a touch larger than life, still in scale with 1.15-high doors
		dc.position = n.position + Vector3(0, 0.03, 0)
		n.set_meta("slump_goal", 1.0 if u.c.wound_state() == Combatant.Wound.MORTAL else 0.0)
		n.set_meta("crouch_goal", 1.0 if _beside_cover(u.pos) else 0.0)   # crouching reads as "in cover"
		if true:
			n.rotation.x = 0
			var foes := enc.alive(1 - u.team).filter(func(o): return o.alerted or u.team == 1)
			if u.team == 1 and not u.alerted:
				foes = []
			if not foes.is_empty():
				foes.sort_custom(func(a, b): return Vector3(a.pos - u.pos).length() < Vector3(b.pos - u.pos).length())
				var d: Vector3i = foes[0].pos - u.pos
				n.rotation.y = atan2(float(d.x), float(d.y))
	if not enc.cur.is_empty():
		ring.visible = false   # the white outline marks the active unit now
		_update_outlines()
		ring.position = Vector3(enc.cur.pos.x + 0.5, _gy(enc.cur.pos) + 0.04, enc.cur.pos.y + 0.5)
	_draw_grid()
	_hud_refresh()
	_toast_new_log()


func _beside_cover(v: Vector3i) -> bool:
	for d in MapGen.DIRS:
		var b := enc.los.blocker(Vector3i(v.x + d.x, v.y + d.y, v.z))
		if b == "cover" or b == "wall":
			return true
	return false


func _cut_radius() -> float:
	return clampf(cam_dist * 0.3, 5.0, 13.0) if cutaway else 0.0


func _update_cut() -> void:
	var fwd := Vector2(-cam.global_transform.basis.z.x, -cam.global_transform.basis.z.z)
	RenderingServer.global_shader_parameter_set("cut_dir", fwd.normalized() if fwd.length() > 0.01 else Vector2(0, -1))
	RenderingServer.global_shader_parameter_set("cut_center", Vector3(cam_target.x, view_floor, cam_target.z))
	# see-through hole around the focus (screen UV, view depth, radius)
	if svp and svp.size.y > 0:
		# the hole follows the active crew member (it exists to keep them visible), else the focus
		var fp := Vector3(cam_target.x, view_floor * FH, cam_target.z)
		if enc and _focus_unit >= 0:
			var fu: Dictionary = enc.units[_focus_unit]
			fp = Vector3(fu.pos.x + 0.5, fu.pos.z * FH, fu.pos.y + 0.5)
		elif enc and not enc.cur.is_empty() and enc.cur.team == 0:
			fp = Vector3(enc.cur.pos.x + 0.5, enc.cur.pos.z * FH, enc.cur.pos.y + 0.5)
		var uv := cam.unproject_position(fp) / Vector2(svp.size)
		var dep := (fp - cam.global_position).dot(-cam.global_transform.basis.z)
		RenderingServer.global_shader_parameter_set("focus_view", Vector4(uv.x, uv.y, dep, 0.14))
	RenderingServer.global_shader_parameter_set("cut_radius", _cut_radius())


func _cut_hides(v: Vector3i) -> bool:
	if v.z <= view_floor or not cutaway:
		return false
	return open_cells.has(Vector2i(v.x, v.y))


## Fog texture: R = vision state per square, G = 1 where the cutaway may open: rooms the crew is
## in or has seen into (grown by one square for their walls), on every floor so the storeys above
## them lift too. Unseen rooms keep their walls and roof (round-4 critique).
func _update_fog() -> void:
	open_cells.clear()
	var open_rooms := {}
	for u in enc.alive(0):
		var l := m.label(u.pos.z, u.pos.x, u.pos.y)
		if l >= 0 and not m.rooms[l].get("outdoor", false):
			open_rooms[l] = true
	for v in enc.vision.explored:
		var l2 := m.label(v.z, v.x, v.y)
		if l2 >= 0 and v.z <= view_floor and not m.rooms[l2].get("outdoor", false):
			open_rooms[l2] = true
	for l3 in open_rooms:
		for c in room_xy.get(l3, []):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					open_cells[Vector2i(c.x + dx, c.y + dy)] = true
	if not fog_on:
		for st in m.structures:
			if st.has("rect"):
				var r: Rect2i = (st.rect as Rect2i).grow(1)
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						open_cells[Vector2i(x, y)] = true
	var data := PackedByteArray()
	data.resize(m.w * m.h * m.floors * 2)
	for f in m.floors:
		for y in m.h:
			for x in m.w:
				var i := ((f * m.h + y) * m.w + x) * 2
				data[i] = 255 if not fog_on else [0, 128, 255][enc.vision.state(Vector3i(x, y, f))]
	for c in open_cells:
		if m.inb(c.x, c.y):
			for f in m.floors:
				data[((f * m.h + c.y) * m.w + c.x) * 2 + 1] = 255
	fog_img.set_data(m.w, m.h * m.floors, false, Image.FORMAT_RG8, data)
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
		bm.material = builder.mat("door", d.floor)   # world shader: obeys cutaway and fog
		var along := horiz != open
		bm.size = Vector3(0.88, 1.1, 0.05) if along else Vector3(0.05, 1.1, 0.88)
		mi.mesh = bm
		mi.position = c
		if open:
			mi.position += Vector3(-0.44, 0, 0.44) if horiz else Vector3(0.44, 0, -0.44)
		door_nodes.add_child(mi)
		var lamp := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.09, 0.11, 0.09)
		var locked: bool = enc.nav.locked.has(v)
		lm.material = builder.mat("dark", d.floor, true, {"glow": 1.2, "emit": Color("ff3b4f") if locked else Color("39f0a0")})
		lamp.mesh = lm
		lamp.position = c + (Vector3(0.47, 0.05, 0.26) if horiz else Vector3(0.26, 0.05, 0.47))
		door_nodes.add_child(lamp)


## Move range as a soft contour (a cubic-upscaled mask drawn by the RANGE shader): no tiles,
## no stair-steps; the hovered path is a ribbon.
func _draw_grid() -> void:
	move_opts = {}
	dash_opts = {}
	if _crew_turn() and enc.turn.can_move():
		move_opts = enc.move_options()
	if _crew_turn() and enc.turn.action_available:
		var budget: int = enc.turn.squares_available() + enc.cur.c.stat("MOVE")
		dash_opts = enc._with_locks(func(): return enc.nav.reachable(enc.cur.pos, budget, enc.occupied(enc.cur)))
	var data := PackedByteArray()
	data.resize(m.w * m.h * 2)
	for v in move_opts:
		if v.z == view_floor:
			data[(v.y * m.w + v.x) * 2] = 255
	if not move_opts.is_empty():   # draw-only: the contour never wraps a teammate's square
		for u in enc.alive(0):
			if u.pos.z == view_floor:
				data[(u.pos.y * m.w + u.pos.x) * 2] = 255
				data[(u.pos.y * m.w + u.pos.x) * 2 + 1] = 255
	for v in dash_opts:
		if v.z == view_floor:
			data[(v.y * m.w + v.x) * 2 + 1] = 255
	grid_node.visible = not (move_opts.is_empty() and dash_opts.is_empty())
	if grid_node.visible:
		range_img.set_data(m.w, m.h, false, Image.FORMAT_RG8, data)
		var big := range_img.duplicate() as Image
		big.resize(m.w * 4, m.h * 4, Image.INTERPOLATE_CUBIC)
		if range_tex == null:
			range_tex = ImageTexture.create_from_image(big)
		else:
			range_tex.update(big)
		(grid_node.material_override as ShaderMaterial).set_shader_parameter("mask", range_tex)
		grid_node.position.y = view_floor * FH + 0.1
	_draw_path()


func _draw_path() -> void:
	var pts: Array[Vector3] = []
	if move_opts.has(hover) and _crew_turn():
		var cells: Array[Vector3i] = enc._with_locks(func(): return enc.nav.path(enc.cur.pos, hover, enc.occupied(enc.cur)))
		cells.push_front(enc.cur.pos)
		for c in cells:
			pts.append(Vector3(c.x + 0.5, c.z * FH + 0.12, c.y + 0.5))
	if pts.size() < 2:
		path_node.mesh = null
		return
	# Catmull-Rom through square centres, then a flat ribbon with an end diamond
	var smooth: Array[Vector3] = []
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for k in 4:
			var t := k / 4.0
			smooth.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	smooth.append(pts[-1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.05
	for i in smooth.size() - 1:
		var a := smooth[i]
		var b := smooth[i + 1]
		var side := (b - a).cross(Vector3.UP).normalized() * w
		for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
			st.add_vertex(v)
	var e := pts[-1] + Vector3(0, 0.01, 0)
	for v in [e + Vector3(-0.2, 0, 0), e + Vector3(0, 0, -0.2), e + Vector3(0.2, 0, 0), e + Vector3(-0.2, 0, 0), e + Vector3(0.2, 0, 0), e + Vector3(0, 0, 0.2)]:
		st.add_vertex(v)
	var mesh := st.commit()
	var mt := _unlit(Color("f9c80e"), 1.0, 1.0)
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mt)
	path_node.mesh = mesh


## Pitch follows zoom (close: low, to see facades and signs; far: high, a planning view). In
## orthographic mode the camera is snapped to the buffer's texel grid and the sub-texel remainder
## is applied as a screen-space shift, so the pixel art doesn't crawl while panning.
func _place_camera() -> void:
	var fy := view_floor * FH
	var pitch := deg_to_rad(lerpf(36.0, 62.0, clampf(inverse_lerp(12.0, 70.0, cam_dist), 0.0, 1.0)))
	var off := Vector3(0, sin(pitch), cos(pitch)).rotated(Vector3.UP, deg_to_rad(cam_yaw)) * cam_dist
	var focus := cam_target + Vector3(0, fy, 0)
	cam.position = focus + off
	cam.look_at(focus)
	cam.size = cam_dist * 0.62
	var px := _px()
	var shift := Vector2.ZERO
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL and svp.size.y > 0:
		var texel := cam.size / float(svp.size.y)
		var bx := cam.global_transform.basis.x
		var by := cam.global_transform.basis.y
		var lx := bx.dot(cam.position)
		var ly := by.dot(cam.position)
		var sx := roundf(lx / texel) * texel
		var sy := roundf(ly / texel) * texel
		cam.position += bx * (sx - lx) + by * (sy - ly)
		shift = Vector2(-(lx - sx), (ly - sy)) / texel * px
	_screen_base = Vector2(-px, -px) + shift
	screen.position = _screen_base + _shake_px.round() * px
	sun.rotation_degrees = Vector3(-55, cam_yaw + 35, 0)
	if enc and not unit_nodes.is_empty():
		_update_outlines()
	if rim:
		rim.rotation_degrees = Vector3(-30, cam_yaw + 190, 0)
	_update_cut()


## Put the unit a little above screen centre (the hotbar covers the bottom), clamped to the map.
func _frame_unit(u: Dictionary) -> void:
	var fwd := Vector2(-sin(deg_to_rad(cam_yaw)), -cos(deg_to_rad(cam_yaw)))
	var p := Vector2(u.pos.x + 0.5, u.pos.y + 0.5) - fwd * cam_dist * 0.12
	if _last_cur == -1 and m.w > 40:   # first turn on a big map: lean toward the middle (objective)
		p = p.lerp(Vector2(m.w / 2.0, m.h / 2.0), 0.2)
	cam_target = Vector3(clampf(p.x, 0, m.w), 0, clampf(p.y, 0, m.h))
	view_floor = u.pos.z
	_place_camera()


## Only the unit whose turn it is gets a white pixel outline; everyone else blends in.
func _update_outlines() -> void:
	for u in enc.units:
		var n: Node3D = unit_nodes.get(u.id)
		if n and n.has_meta("outlines"):
			var on: bool = not enc.cur.is_empty() and u.id == enc.cur.id and not u.c.dead
			for ol in n.get_meta("outlines"):
				(ol as MeshInstance3D).visible = on


## Height of the walkable surface of a square (sidewalks are raised by a kerb).
func _gy(v: Vector3i) -> float:
	var y := v.z * FH
	if v.z == 0 and m.inb(v.x, v.y) and m.t(0, v.x, v.y) == TacMap.T.OUTSIDE and m.label(0, v.x, v.y) < 0 \
			and m.ground[v.y * m.w + v.x] == TacMap.G.SIDEWALK:
		y += KERB
	return y


func _to_screen(p: Vector3) -> Vector2:
	return cam.unproject_position(p) * _px() + screen.position


# --- Input ------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		if ev.button_mask & MOUSE_BUTTON_MASK_MIDDLE:   # middle-drag: free rotation
			yaw_goal -= ev.relative.x * 0.35
			cam_yaw = yaw_goal
			_place_camera()
		mouse = ev.position
		var h := _pick(ev.position)
		if h != hover:
			hover = h
			_draw_path()
		_update_hover()
	elif ev is InputEventMouseButton and ev.pressed:
		if busy and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP: cam_dist = maxf(8, cam_dist * 0.9); _place_camera()
			MOUSE_BUTTON_WHEEL_DOWN: cam_dist = minf(160, cam_dist * 1.1); _place_camera()
			MOUSE_BUTTON_LEFT: _click_move()
			MOUSE_BUTTON_RIGHT: _click_attack(ev.shift_pressed or cover_mode)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_Q: yaw_goal = snappedf(yaw_goal, 45.0) - 90
			KEY_E: yaw_goal = snappedf(yaw_goal, 45.0) + 90
			KEY_H: hud.toggle_hint()
			KEY_PAGEUP: view_floor = mini(view_floor + 1, m.floors - 1); _place_camera(); _refresh()
			KEY_PAGEDOWN: view_floor = maxi(view_floor - 1, 0); _place_camera(); _refresh()
			KEY_C: cutaway = not cutaway; _refresh()
			KEY_1: _on_hud("mode", 0)
			KEY_2: _on_hud("mode", 1)
			KEY_3: _on_hud("mode", 2)
			KEY_X: _on_hud("cover_mode", null)
			KEY_ESCAPE: pass
			KEY_R: _on_hud("reload", null)
			KEY_J: _on_hud("jack_in", null)
			KEY_SPACE: _on_hud("end_turn", null)
			KEY_F1: gig.seed += 1; new_gig()
			KEY_F2: hud.settings.visible = not hud.settings.visible
			KEY_F3: fog_on = not fog_on; _refresh()


func _on_hud(name: String, arg: Variant) -> void:
	if busy:
		return
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
	var sp := (screen_pos - screen.position) / _px()
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	var hit: Variant = Plane(Vector3.UP, view_floor * FH).intersects_ray(o, d)
	if hit == null:
		return Vector3i(-1, -1, -1)
	return Vector3i(floori(hit.x), floori(hit.z), view_floor)


func _crew_turn() -> bool:
	return enc.state == "playing" and not enc.cur.is_empty() and enc.cur.team == 0


func _click_move() -> void:
	if not _crew_turn():
		return
	if move_opts.has(hover) and enc.move_to(hover):
		_after_action()
	elif dash_opts.has(hover) and enc.move_to(hover, true):   # Run Action (p127)
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
			_rebuild = r.left == 0
		_after_action()
		return
	if t.team == 0:
		return
	var r := enc.attack(t, w, mode)
	if r.get("ok", true) == false:
		hud.toast(r.reason)
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
	enc.end_turn()
	enc.next_turn()
	_after_action()


func _demo_attack() -> void:
	var best := {}
	for u in enc.units:
		if u.team == 1 and not u.c.dead and (best.is_empty() or Vector2(u.pos.x - enc.cur.pos.x, u.pos.y - enc.cur.pos.y).length() < Vector2(best.pos.x - enc.cur.pos.x, best.pos.y - enc.cur.pos.y).length()):
			best = u
	if best.is_empty():
		return
	var g: Dictionary = best
	var near := enc.nav.reachable(g.pos, 6, enc.occupied())
	for v in near:   # put the shooter in sight of the guard for the demo
		if v != g.pos and enc.los.sight(v, g.pos).visible and Vector2(v.x - g.pos.x, v.y - g.pos.y).length() >= 3:
			enc.cur.pos = v
			break
	view_floor = enc.cur.pos.z
	cam_target = Vector3((enc.cur.pos.x + g.pos.x) / 2.0 + 0.5, 0, (enc.cur.pos.y + g.pos.y) / 2.0 + 0.5)
	_place_camera()
	enc.refresh_vision()
	_refresh()
	mode = Attack.Mode.AUTOFIRE
	enc.turn.action_available = true
	enc.attack(g, enc.cur.c.weapons[0], mode)
	_demo_ms = Time.get_ticks_msec()
	_after_action()


## After any rules call: play what happened (moves, shots, alerts) as animation, then sync.
func _after_action() -> void:
	busy = true
	grid_node.visible = false
	path_node.mesh = null
	await _play_events()
	busy = false
	if _rebuild:
		_rebuild = false
		_build_world()
	enc.refresh_vision()
	var new_turn: bool = not enc.cur.is_empty() and enc.cur.team == 0 and enc.cur.id != _last_cur
	if new_turn:
		_frame_unit(enc.cur)   # new crew turn: centre the active unit in the space between the panels
	_last_cur = enc.cur.id if not enc.cur.is_empty() else -1
	_refresh()
	_update_hover()
	if new_turn and enc.state == "playing":
		hud.turn_banner("%s  ·  YOUR MOVE" % enc.cur.c.display_name.to_upper(), Hud.GOLD)


# --- Juice: event playback ----------------------------------------------------------
# Timing rule (game-feel review): every outcome fires when its round arrives; the camera frames
# who is acting; bodies wind up, recoil and react on the joint rig; HUD drains at impact.

const FIRE_GAP := {"smg": 0.06, "heavy_smg": 0.07, "assault_rifle": 0.085}
const SAFE := Rect2(260, 110, 0, 0)   # HUD-free area: left edge, top; right/bottom margins below
const SAFE_BOTTOM := 170.0

var _focus_unit := -1                 ## unit the see-through hole and cutaway follow during playback
var _shake_px := Vector2.ZERO         ## screen-space shake offset (buffer pixels) and its velocity
var _shake_vel := Vector2.ZERO
var _screen_base := Vector2.ZERO
var _callout_stack := {}              ## unit id → [count, msec] so callouts stack instead of overlapping
var _flash_lights := {}               ## unit id → pooled muzzle OmniLight3D


func _seen(v: Vector3i) -> bool:
	return not fog_on or enc.vision.visible.has(v)


func _body_pos(u: Dictionary) -> Vector3:
	return Vector3(u.pos.x + 0.5, _gy(u.pos), u.pos.y + 0.5)


func _play_events() -> void:
	var hostile_shown := false
	while not enc.events.is_empty():
		var e: Dictionary = enc.events.pop_front()
		var u: Dictionary = enc.units[e.unit]
		if u.team == 1 and not hostile_shown and String(e.type) != "alert" and _event_visible(e):
			hostile_shown = true
			hud.enemy_phase(true)
			hud.turn_banner("HOSTILE ACTIVITY", Hud.RED)
			await get_tree().create_timer(0.3).timeout
		match String(e.type):
			"move": await _anim_move(e)
			"attack": await _anim_attack(e)
			"cover": await _anim_cover(e)
			"alert": _anim_alert(e)
	hud.enemy_phase(false)
	_focus_unit = -1


func _event_visible(e: Dictionary) -> bool:
	match String(e.type):
		"move":
			return (e.path as Array).any(func(v): return _seen(v))
		"attack":
			return _seen(enc.units[e.unit].pos) or _seen(enc.units[e.target].pos)
	return _seen(enc.units[e.unit].pos)


## HUD-safe screen rect (outside the panels).
func _safe_rect() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	return Rect2(SAFE.position, Vector2(vs.x - SAFE.position.x - 40, vs.y - SAFE.position.y - SAFE_BOTTOM))


## Smoothly move the camera focus (and optionally zoom) over `secs`.
func _pan_to(p: Vector3, secs := 0.3, dist := -1.0) -> void:
	var from := cam_target
	var d0 := cam_dist
	var d1 := dist if dist > 0 else cam_dist
	var tw := create_tween()
	tw.tween_method(func(t: float):
		cam_target = from.lerp(Vector3(p.x, 0, p.z), t)
		cam_dist = lerpf(d0, d1, t)
		_place_camera(), 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Frame two points inside the safe rect, zooming out if they don't fit.
func _frame_pair(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) / 2
	var span := Vector2(a.x - b.x, a.z - b.z).length()
	var want := maxf(cam_dist, minf(60.0, span * 1.9 + 6.0))
	var sa := _to_screen(a)
	var sb := _to_screen(b)
	var sr := _safe_rect().grow(-40)
	if sr.has_point(sa) and sr.has_point(sb) and want <= cam_dist + 0.1:
		return
	await _pan_to(mid, 0.28, want)


## Walk the body along the path, square by square, facing the way it goes; the camera follows
## softly once the walker leaves the middle of the safe area.
func _anim_move(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var n: Node3D = unit_nodes[u.id]
	var path: Array = e.path
	if u.team == 1 and not _event_visible(e):
		return
	_focus_unit = u.id
	var step := 0.075 if e.run else 0.105
	n.set_meta("walk", true)
	n.set_meta("run", e.run)
	n.set_meta("crouch_goal", 0.0)
	var inner := _safe_rect().grow_individual(-_safe_rect().size.x * 0.2, -_safe_rect().size.y * 0.2, -_safe_rect().size.x * 0.2, -_safe_rect().size.y * 0.2)
	for i in range(1, path.size()):
		var a: Vector3i = path[i - 1]
		var b: Vector3i = path[i]
		var d := Vector2(b.x - a.x, b.y - a.y)
		if d.length() > 0.01:
			_turn_to(n, atan2(d.x, d.y), 0.06)
		if u.team == 1:
			n.visible = _seen(a) or _seen(b)
		var to := Vector3(b.x + 0.5, _gy(b), b.y + 0.5)
		var tw := create_tween()
		tw.tween_property(n, "position", to, step * (1.0 if d.length() < 1.2 else 1.4))
		(decals[u.id] as Node3D).position = to + Vector3(0, 0.03, 0)
		if u == enc.cur:
			ring.position = to + Vector3(0, 0.04, 0)
		if n.visible and not inner.has_point(_to_screen(to)):
			_pan_to(to, 0.35)   # soft follow (not awaited)
		await tw.finished
	n.set_meta("walk", false)


func _turn_to(n: Node3D, yaw: float, secs := 0.12) -> void:
	var goal := n.rotation.y + wrapf(yaw - n.rotation.y, -PI, PI)
	create_tween().tween_property(n, "rotation:y", goal, secs).set_trans(Tween.TRANS_SINE)


func _muzzle_of(n: Node3D) -> Vector3:
	var j: Dictionary = n.get_meta("j", {})
	var w: Node3D = j.get("weapon")
	return w.global_transform * Vector3(0, 0.02, 0.42) if w else n.global_position + Vector3(0, 0.8, 0)


func _flash_light(uid: int) -> OmniLight3D:
	if not _flash_lights.has(uid) or not is_instance_valid(_flash_lights[uid]):
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		fx.add_child(l)
		_flash_lights[uid] = l
	return _flash_lights[uid]


## Where a missed round ends: offset clear of the body, then on along the line until it meets a
## wall or the floor.
func _miss_point(m0: Vector3, aim: Vector3) -> Vector3:
	var dir := (aim - m0).normalized()
	var side := dir.cross(Vector3.UP).normalized() * (fx.rng.randf_range(0.4, 0.75) * (1.0 if fx.rng.randf() < 0.5 else -1.0))
	var p := aim + side + Vector3(0, fx.rng.randf_range(-0.25, 0.45), 0)
	var d2 := (p - m0).normalized()
	for k in 48:
		p += d2 * 0.25
		var f := clampi(int(floor(p.y / FH)), 0, m.floors - 1)
		var c := Vector3i(int(floor(p.x)), int(floor(p.z)), f)
		if not m.inb(c.x, c.y) or p.y <= f * FH + 0.02 or enc.los.blocker(c) == "wall":
			return p
	return p


## Shots on the rig: lean out, turn and raise, fire round by round (each impact on arrival),
## recoil with muzzle climb, then the outcome on the last connecting round.
func _anim_attack(e: Dictionary) -> void:
	if not _event_visible(e):
		return
	var su: Dictionary = enc.units[e.unit]
	var tu: Dictionary = enc.units[e.target]
	var sn: Node3D = unit_nodes[su.id]
	var tn: Node3D = unit_nodes[tu.id]
	_focus_unit = su.id
	if su.team == 0 and su.pos.z != view_floor:   # follow a crew shooter to their floor (XCOM-style)
		view_floor = su.pos.z
		_refresh()
	sn.visible = sn.visible or _seen(su.pos)
	tn.visible = tn.visible or _seen(tu.pos)
	await _frame_pair(_body_pos(su), _body_pos(tu))
	var wid := String(e.get("weapon", "assault_rifle"))
	var d := Vector2(tu.pos.x - su.pos.x, tu.pos.y - su.pos.y)
	# lean out of cover toward the firing square
	var home := sn.position
	var from: Vector3i = e.get("from", su.pos)
	if from != su.pos:
		var lean := Vector3(from.x - su.pos.x, 0, from.y - su.pos.y).normalized() * 0.35
		create_tween().tween_property(sn, "position", home + lean, 0.12)
	sn.set_meta("crouch_goal", 0.0)
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), float(sn.get_meta("aim", 0.0)), 1.0, 0.1)
	await get_tree().create_timer(0.18).timeout
	var aim := _body_pos(tu) + Vector3(0, 0.95 if String(e.get("location", "body")) == "head" else 0.72, 0) * 1.0
	var rounds: int = int(e.get("rounds", 1)) if int(e.mode) == Attack.Mode.AUTOFIRE else 1
	var connect: int = (int(e.get("mult", 1)) if int(e.mode) == Attack.Mode.AUTOFIRE else 1) if (e.hit and not e.dodged) else 0
	var hit_rounds := {}   # which rounds connect: spread through the burst
	for k in connect:
		hit_rounds[int(round(float(k + 1) * rounds / (connect + 1)))] = true
	var last_hit := -1
	for k in hit_rounds:
		last_hit = maxi(last_hit, k)
	var gap: float = FIRE_GAP.get(wid, 0.0)
	var light := _flash_light(su.id)
	if e.dodged:   # the dodge starts before the rounds arrive, so they pass through empty air
		var side := Vector3(-d.y, 0, d.x).normalized() * 0.32
		var tw := create_tween()
		tw.tween_property(tn, "position", tn.position + side, 0.09).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25)
		tw.tween_property(tn, "position", tn.position, 0.2)
		_float(tu, "DODGE", Hud.CYAN)
	var arrived := [0]
	for i in rounds:
		var m0 := _muzzle_of(sn)
		var dir := (aim - m0).normalized()
		fx.muzzle(m0, dir, wid, light, rounds == 1 or fx.rng.randf() > 0.25)
		if not wid.contains("launcher") and not wid.contains("bow"):
			fx.brass(m0 - dir * 0.35, dir.cross(Vector3.UP).normalized(), _gy(su.pos))
		var hits: bool = hit_rounds.has(i)
		var dest := aim + Vector3(fx.rng.randf_range(-0.08, 0.08), fx.rng.randf_range(-0.08, 0.08), fx.rng.randf_range(-0.08, 0.08)) if hits else _miss_point(m0, aim)
		var is_last := i == last_hit
		fx.bullet(m0, dest, wid, func():
			arrived[0] += 1
			if hits:
				fx.sparks(dest)
				if is_last:
					_outcome(e, su, tu, tn, dest, dir)
			else:
				fx.burst(dest, Color("ffd27a"), 5, 2.0, 0.035, 0.2, 1.6)
				fx.burst(dest, Color("8a8478"), 3, 0.6, 0.12, 0.6, 0.0, 0.4))
		_recoil(sn, rounds > 1)
		_kick(_screen_dir(m0, aim) * -1.0, 1.0 if rounds > 1 else 1.5)
		await get_tree().create_timer(gap + fx.rng.randf_range(0.0015, 0.003) if rounds > 1 else 0.05).timeout
	# wait for the last round to land, then hold the framing a moment
	var t0 := Time.get_ticks_msec()
	while arrived[0] < rounds and Time.get_ticks_msec() - t0 < 600:
		await get_tree().process_frame
	if not e.hit and not e.dodged:
		_float(tu, "MISS", Hud.DIM)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 1.0, 0.0, 0.25).set_delay(0.3)
	if from != su.pos:
		create_tween().tween_property(sn, "position", home, 0.15).set_delay(0.25)
	await get_tree().create_timer(0.45 if e.hit else 0.3).timeout


## The result on the target, when the connecting round lands.
func _outcome(e: Dictionary, su: Dictionary, tu: Dictionary, tn: Node3D, at: Vector3, dir: Vector3) -> void:
	var dmg := int(e.damage)
	if dmg <= 0:   # armour stopped it: sparks and a ricochet, cyan ARMOR and the SP ablation
		fx.burst(at, Color("fff0b0"), 14, 4.5, 0.04, 0.3, 2.0)
		fx.bullet(at, at + (Vector3.UP * 0.8 + dir.cross(Vector3.UP) * fx.rng.randf_range(-1.0, 1.0) - dir * 0.3).normalized() * 3.0, "medium_pistol")
		_float(tu, "ARMOR", Hud.CYAN)
		_float(tu, "SP %d→%d" % [int(e.sp_before), int(e.sp_after)], Hud.CYAN)
		_react(tn, dir, 0.4)
		_kick(_screen_dir(at - dir, at), 1.5)
		return
	fx.blood(at, e.crit)
	_hit_flash(tn)
	_react(tn, dir, 1.0 if not e.crit else 1.5)
	_float(tu, "-%d" % dmg, Hud.RED)
	if String(e.get("location", "body")) == "head":
		_float(tu, "HEADSHOT", Hud.GOLD)
	if int(e.sp_after) < int(e.sp_before):
		_float(tu, "SP %d→%d" % [int(e.sp_before), int(e.sp_after)], Hud.CYAN)
	_kick(_screen_dir(at - dir, at), 2.0)
	hud.hit_unit(tu.id)
	_hud_refresh()   # HP drains at the moment of impact
	if e.crit:
		var names: Array = e.get("crit_names", [])
		_float(tu, "CRITICAL · %s" % (String(names[0]).to_upper() if not names.is_empty() else ""), Hud.GOLD)
		hud.flash_screen(Color(1, 0.2, 0.2, 0.22))
		_kick(_screen_dir(at - dir, at), 4.0)
		_hit_stop(90)
	if int(e.wound_before) < Combatant.Wound.SERIOUS and int(e.wound_after) == Combatant.Wound.SERIOUS:
		_float(tu, "SERIOUSLY WOUNDED", Color("ffb000"))
	if e.killed:
		_die(tu, tn, dir, bool(e.get("dead", true)))


func _hud_refresh() -> void:
	hud.refresh(enc, mode, cover_mode, "%s  ·  FLOOR %d/%d" % [String(m.params.get("scene", gig.scene)).replace("_", " ").to_upper(), view_floor + 1, m.floors])


## Recoil: kick the weapon back and the chest up; autofire climbs, capped; settles with a spring.
func _recoil(n: Node3D, burst: bool) -> void:
	var r: float = n.get_meta("recoil", 0.0)
	n.set_meta("recoil", minf(r + (0.05 if burst else 0.12), 0.24))
	n.set_meta("recoil_kick", 1.0)


## Hit reaction: the upper body snaps away from the shot, then springs back.
func _react(n: Node3D, dir: Vector3, strength: float) -> void:
	n.set_meta("hit_dir", dir)
	n.set_meta("hit_t", 0.0)
	n.set_meta("hit_amp", strength)
	var tw := create_tween()   # a small shove along the shot
	tw.tween_property(n, "position", n.position + Vector3(dir.x, 0, dir.z).normalized() * 0.08 * strength, 0.05)
	tw.tween_property(n, "position", n.position, 0.22)


func _hit_flash(n: Node3D) -> void:
	for mt in n.get_meta("mats", []):
		(mt as ShaderMaterial).set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float):
		for mt in n.get_meta("mats", []):
			(mt as ShaderMaterial).set_shader_parameter("flash", v), 1.0, 0.0, 0.25)


## Death: knees go, then the body falls along the shot with one small bounce; the weapon drops.
## Mortally Wounded units slump to their knees instead (they can still be stabilised).
func _die(u: Dictionary, n: Node3D, dir: Vector3, dead: bool) -> void:
	n.set_meta("slump_goal", 1.0)
	if not dead:
		_float(u, "DYING", Hud.RED)
		return
	_float(u, "DOWN", Hud.RED)
	await get_tree().create_timer(0.15).timeout
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	var axis := Vector3.UP.cross(flat).normalized()
	if axis.length() < 0.5:
		axis = Vector3.RIGHT
	var b0 := n.transform.basis
	var b1 := Basis(axis, deg_to_rad(86)) * b0
	var q0 := b0.get_rotation_quaternion()
	var q1 := b1.get_rotation_quaternion()
	var scl := n.scale
	var tw := create_tween()
	tw.tween_method(func(t: float): n.basis = Basis(q0.slerp(q1, t)).scaled(scl), 0.0, 1.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(t: float): n.basis = Basis(q1.slerp(q0, 0.06 * sin(t * PI))).scaled(scl), 0.0, 1.0, 0.18)
	n.set_meta("fallen", true)
	var j: Dictionary = n.get_meta("j", {})
	if j.has("weapon"):
		var w: Node3D = j.weapon
		var gp := w.global_transform
		w.get_parent().remove_child(w)
		fx.add_child(w)
		w.global_transform = gp
		var land := Vector3(gp.origin.x, _gy(u.pos) + 0.03, gp.origin.z) + flat * 0.4
		var wt := create_tween()
		wt.tween_property(w, "global_position", land, 0.3).set_ease(Tween.EASE_IN)
		wt.parallel().tween_property(w, "rotation", w.rotation + Vector3(0, fx.rng.randf_range(2, 5), 1.4), 0.3)
	fx.pool(_body_pos(u))
	(decals[u.id] as Node3D).visible = false


func _anim_cover(e: Dictionary) -> void:
	var su: Dictionary = enc.units[e.unit]
	var sn: Node3D = unit_nodes[su.id]
	var cell: Vector3i = e.cell
	var at := Vector3(cell.x + 0.5, cell.z * FH + 0.45, cell.y + 0.5)
	_focus_unit = su.id
	var d := Vector2(cell.x - su.pos.x, cell.y - su.pos.y)
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 0.0, 1.0, 0.1)
	await get_tree().create_timer(0.15).timeout
	var m0 := _muzzle_of(sn)
	var wid := String(e.get("weapon", "assault_rifle"))
	fx.muzzle(m0, (at - m0).normalized(), wid, _flash_light(su.id))
	_recoil(sn, false)
	var gone: bool = enc.los.cover_hp.get(cell, 1) == 0 or m.t(cell.z, cell.x, cell.y) != TacMap.T.WALL and m.t(cell.z, cell.x, cell.y) != TacMap.T.DOOR and not enc.los.cover_hp.has(cell)
	fx.bullet(m0, at, wid, func():
		fx.debris(at, gone)
		_kick(_screen_dir(m0, at), 4.0 if gone else 1.5)
		var left: int = enc.los.cover_hp.get(cell, enc.los.wall_hp.get(cell, 0))
		_float_at(at + Vector3(0, 0.5, 0), "-%d · %s" % [int(e.damage), "DESTROYED" if gone else "%d HP" % left], Hud.GOLD if gone else Hud.TEXT))
	await get_tree().create_timer(0.45).timeout
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 1.0, 0.0, 0.25)


func _anim_alert(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	if _seen(u.pos):
		(unit_nodes[u.id] as Node3D).visible = true
		_float(u, "!", Hud.RED)
		hud.flash_screen(Color(1, 0.15, 0.2, 0.12))
	_hud_refresh()   # the stealth chip flips to ENGAGED now, not after playback


# --- Shake and hit-stop (screen space: whole buffer pixels, so the pixel art never crawls) ----

func _screen_dir(a: Vector3, b: Vector3) -> Vector2:
	var v := cam.unproject_position(b) - cam.unproject_position(a)
	return v.normalized() if v.length() > 0.01 else Vector2.RIGHT


func _kick(dir: Vector2, px: float) -> void:
	_shake_vel += dir * px * 60.0


func _hit_stop(ms: int) -> void:
	var tws := get_tree().get_processed_tweens()
	for t in tws:
		t.pause()
	fx.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	for t in tws:
		if t.is_valid():
			t.play()
	fx.process_mode = Node.PROCESS_MODE_INHERIT


func _update_shake(delta: float) -> void:
	# damped spring back to rest
	var acc := -_shake_px * 600.0 - _shake_vel * 22.0
	_shake_vel += acc * delta
	_shake_px += _shake_vel * delta
	if _shake_px.length() < 0.05 and _shake_vel.length() < 0.5:
		_shake_px = Vector2.ZERO
		_shake_vel = Vector2.ZERO
	screen.position = _screen_base + _shake_px.round() * _px()


# --- Bodies: walk cycle, aim, recoil, hit reactions, idle, crouch, slump -----------------

func _animate_bodies(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for id in unit_nodes:
		var n: Node3D = unit_nodes[id]
		if not n.visible or not n.has_meta("j") or n.get_meta("fallen", false):
			continue
		var j: Dictionary = n.get_meta("j")
		var walking: bool = n.get_meta("walk", false)
		var ph: float = n.get_meta("ph", 0.0)
		if walking:
			ph += delta * (19.0 if n.get_meta("run", false) else 14.0)
			n.set_meta("ph", ph)
		var sw := sin(ph) if walking else 0.0
		var amp := 0.7 if n.get_meta("run", false) else 0.5
		# crouch (beside cover) and slump (Mortally Wounded) ease toward their goals
		var cr := move_toward(float(n.get_meta("crouch", 0.0)), float(n.get_meta("crouch_goal", 0.0)), delta * 5.0)
		n.set_meta("crouch", cr)
		var sl := move_toward(float(n.get_meta("slump", 0.0)), float(n.get_meta("slump_goal", 0.0)), delta * 4.0)
		n.set_meta("slump", sl)
		var low := maxf(cr, sl)
		var limp: float = 1.0 if int(n.get_meta("wound", 0)) >= Combatant.Wound.SERIOUS else 0.0
		_pose(j, "leg_l", sw * amp - low * 0.6)
		_pose(j, "leg_r", -sw * amp * (1.0 - 0.4 * limp) - low * 0.6)
		_pose(j, "knee_l", (maxf(0.0, -sw) * 0.8 if walking else 0.0) + low * 1.1)
		_pose(j, "knee_r", (maxf(0.0, sw) * 0.8 * (1.0 - 0.5 * limp) if walking else 0.0) + low * 1.1)
		if j.has("hips"):
			var hp: Node3D = j.hips
			var rest: Transform3D = hp.get_meta("rest")
			hp.position = rest.origin + Vector3(0.015 * sin(t * 3.1 + id * 1.7), (absf(sw) * 0.025 if walking else 0.0) - low * 0.13, 0)
		# aim, recoil and hit reaction on the chest; aim raises the arms and weapon
		var aim: float = n.get_meta("aim", 0.0)
		var rc: float = n.get_meta("recoil", 0.0)
		var kick: float = n.get_meta("recoil_kick", 0.0)
		n.set_meta("recoil", move_toward(rc, 0.0, delta * 0.9))
		n.set_meta("recoil_kick", move_toward(kick, 0.0, delta * 14.0))
		var ht: float = n.get_meta("hit_t", 9.0) + delta
		n.set_meta("hit_t", ht)
		var hit_env := exp(-ht * 9.0) * sin(minf(ht * 26.0, PI * 2.5)) * float(n.get_meta("hit_amp", 0.0)) if ht < 0.6 else 0.0
		var hd: Vector3 = n.get_meta("hit_dir", Vector3.FORWARD)
		var local_hd := n.global_transform.basis.inverse() * Vector3(hd.x, 0, hd.z).normalized() if hd.length() > 0.01 else Vector3.ZERO
		if j.has("chest"):
			var ch: Node3D = j.chest
			var rest_c: Transform3D = ch.get_meta("rest")
			var pitch := -rc - kick * 0.06 - sl * 0.5 + local_hd.z * 0.35 * hit_env + (0.0 if walking else 0.012 * sin(t * 2.3 + id))
			var roll := -local_hd.x * 0.35 * hit_env
			ch.transform = rest_c * Transform3D(Basis.from_euler(Vector3(pitch, 0, roll)), Vector3.ZERO)
		if j.has("head"):
			var hd_n: Node3D = j.head
			var rest_h: Transform3D = hd_n.get_meta("rest")
			var scan := 0.6 if (enc and id < enc.units.size() and enc.units[id].team == 1 and not enc.units[id].alerted) else 0.25
			var yaw := scan * sin(t * 0.45 + id * 2.1) * (1.0 - aim)
			hd_n.transform = rest_h * Transform3D(Basis.from_euler(Vector3(local_hd.z * 0.5 * hit_env, yaw, 0)), Vector3.ZERO)
		for side in ["l", "r"]:
			_pose(j, "shoulder_" + side, -0.25 * aim)
		if j.has("weapon"):
			var w: Node3D = j.weapon
			var rest_w: Transform3D = w.get_meta("rest")
			w.position = rest_w.origin + Vector3(0, 0.05 * aim + 0.006 * sin(t * 1.7 + id * 2.0) + (0.01 * sw if walking else 0.0), -0.03 * kick)


func _pose(j: Dictionary, name: String, x: float) -> void:
	if not j.has(name):
		return
	var nd: Node3D = j[name]
	var rest: Transform3D = nd.get_meta("rest")
	nd.transform = rest * Transform3D(Basis(Vector3.RIGHT, x), Vector3.ZERO)


func _toast_new_log() -> void:
	for i in range(_log_seen, enc.log.size()):
		if enc.log[i].contains("spots"):
			hud.toast("⚠ " + enc.log[i].to_upper())
	_log_seen = enc.log.size()


## Floating callout over a unit, on the HUD layer so it stays crisp above the pixel filter.
## Callouts on the same unit stack upward instead of overlapping; all stay inside the safe rect.
func _float(u: Dictionary, text: String, col: Color, offset := Vector2.ZERO) -> void:
	var now := Time.get_ticks_msec()
	var st: Array = _callout_stack.get(u.id, [0, 0])
	var k: int = st[0] + 1 if now - int(st[1]) < 900 else 0
	_callout_stack[u.id] = [k, now]
	var n: Node3D = unit_nodes.get(u.id)
	var base := n.global_position if n else _body_pos(u)
	_float_at(base + Vector3(0, 1.4, 0), text, col, offset + Vector2(0, -30 * k))


func _float_at(wp: Vector3, text: String, col: Color, offset := Vector2.ZERO) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Hud.F_DISPLAY)
	l.add_theme_font_size_override("font_size", 30 if text.length() > 3 else 40)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(Hud.MAGENTA, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	var sr := _safe_rect()
	var p := _to_screen(wp) - Vector2(30, 20) + offset
	l.position = Vector2(clampf(p.x, sr.position.x, sr.end.x - 200), clampf(p.y, sr.position.y, sr.end.y))
	l.scale = Vector2(1.25, 1.25)
	hud.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 46, 1.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.tween_callback(l.queue_free)


func _update_hover() -> void:
	target_ring.visible = false
	hud.mode_pcts({})
	if not _crew_turn():
		hud.tip("", mouse)
		return
	var t := _unit_at(hover)
	if t.is_empty() or t.team == 0 or enc.cur.c.weapons.is_empty():
		if cover_mode and enc.los.blocker(hover) != "":
			hud.tip("[b]%s[/b]" % ("Cover piece · [code]%d HP[/code]" % enc.los.cover_hp[hover] if enc.los.cover_hp.get(hover, 0) > 0 else "Wall / door"), mouse, "// SHOOT COVER", Hud.GOLD)
		elif move_opts.has(hover):
			var p: Array[Vector3i] = enc._with_locks(func(): return enc.nav.path(enc.cur.pos, hover, enc.occupied(enc.cur)))
			hud.tip("[code]%d / %d[/code] squares" % [enc.nav.cost_of(enc.cur.pos, p), enc.turn.squares_available()], mouse, "// MOVE", Hud.CYAN)
		elif dash_opts.has(hover):
			hud.tip("Uses your [b]Action[/b] as a Run (an extra Move Action)", mouse, "// RUN", Color("ffb000"))
		else:
			hud.tip("", mouse)
		return
	target_ring.visible = false   # no rings under units (owner)
	if not busy and unit_nodes.has(enc.cur.id):   # the active unit turns to aim at the hovered target
		var dd := Vector2(t.pos.x - enc.cur.pos.x, t.pos.y - enc.cur.pos.y)
		(unit_nodes[enc.cur.id] as Node3D).rotation.y = atan2(dd.x, dd.y)
	target_ring.position = Vector3(t.pos.x + 0.5, _gy(t.pos) + 0.04, t.pos.y + 0.5)
	var w: Weapon = enc.cur.c.weapons[0]
	var p := enc.preview(t, w, mode)
	var pcts := {}
	for k in 3:   # hit chance per fire mode, shown on the hotbar buttons
		var pm := enc.preview(t, w, [Attack.Mode.SINGLE, Attack.Mode.AUTOFIRE, Attack.Mode.AIMED_HEAD][k])
		pcts[k] = roundi(pm.chance * 100) if pm.ok else -1
	hud.mode_pcts(pcts)
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
	# CPR armour often stops everything: show what the weapon averages through it
	var loc := "head" if mode == Attack.Mode.AIMED_HEAD else "body"
	var avg := w.dice() * 3.5
	var thru := maxf(0.0, avg - c.sp(loc)) * (2.0 if loc == "head" else 1.0)
	lines.append("[code]%dd6 vs SP %d: ~%d through[/code]" % [w.dice(), c.sp(loc), roundi(thru)] + ("  [color=#ff3b4f]armor likely stops it[/color]" if thru < 1.0 else ""))
	hud.tip("\n".join(lines), mouse, "// TARGET · HOSTILE", Hud.RED)
