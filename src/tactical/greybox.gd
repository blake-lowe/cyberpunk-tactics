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
##   Alt (hold) inspect what's under the cursor    F4 cyberspace style    N peek out of the NET
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
	"bloom": 1.2, "ortho": 1.0, "lights": 1.0, "dim": 0.5, "spill": 1.0, "net_style": 7.0}
const NET_STYLES := ["", "POINTILLIST", "OBRA DINN", "WIRE · PIXEL", "BLACKWALL", "GHOST", "STARGATE", "WIRE · CRISP", "WIRE · BLUEPRINT", "WIRE · SCAN"]
const NET_FULL_RES := [7, 8]   # styles drawn without the pixel filter
const NET_CYCLE := [7, 8, 9, 3, 1, 2, 4, 5, 6]

## Curated palette (M4b critique: a real limited palette instead of free-floating mids): ink and
## navy ramps, warm concrete, cool greys, skin, wood, foliage, and each neon in two steps.
## Round 2: each neon has a 4-step ramp (deep, mid, full, pale) so coloured light keeps its hue in
## shadow and highlight; skin and wood are cut to two steps each; matching happens in OKLab.
## Round 3: neutrals first; neon-ramp entries are only allowed for saturated pixels (post shader),
## so shadows go navy instead of a violet wash. Warm darks added for earth.
## Sunset (badlands): violet-ink shadows, a long sand ramp, rust rock, cool metal greys, dry
## scrub, skin, dusk violet; then the neon ramps for the camp's signs and the UI-coloured effects.
## No orange/yellow neon ramps here: sunlit rock would snap to them and turn garish.
const PALETTE_SUNSET_NEUTRALS := 37
const PALETTE_SUNSET := ["07060a", "120c14", "1c1420", "2a1c2c", "3a2636", "4e3240",
	"3a2a22", "543a2c", "70503a", "8e6648", "ae8058", "c89a6a", "e0b884", "f2d6a8", "fff0d4",
	"4a2418", "6a3220", "8c4428", "ae5a32", "cc7440", "d88a48", "eaa860", "f4c88a",
	"2a2a34", "44444e", "62626c", "84828a", "aaa6a8", "d2ccc6",
	"5a4a30", "7a6840", "9a8a58", "8a5a40", "c08a68", "3a3a5a", "5a5a8a", "8a80b0",
	"5a1040", "ff2a6d", "ffa0c0", "0a4a5a", "05d9e8", "aaf6ff", "4a1a6a", "b537f2", "0e5a3a", "39f0a0", "7a1420", "ff3b4f"]
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
## Optional per scene: "sun" [elevation, world yaw] fixes the key light in the world (a real sun;
## night scenes let the moon key follow the camera), "sky" [zenith, mid, horizon], "palette",
## "rim" colour/energy and "lights" (lamp scale: dusk lamps are weaker than night ones).
const LOOKS := {
	"default": {"ambient": "262c44", "amb_e": 0.65, "key": "8fa0e0", "key_e": 0.5, "fog": "0d1422", "fog_d": 0.0035},
	"badlands": {"ambient": "4c4c90", "amb_e": 0.75, "key": "ffc898", "key_e": 1.15, "fog": "a86a58", "fog_d": 0.0025,
		"sun": [-17.0, 235.0], "sky": ["1c2050", "9a4466", "ff8c3c"], "palette": "sunset", "rim": ["6a5aa0", 0.35], "lights": 0.55,
		"fog_dim": 0.78, "fog_sat": 0.9, "fog_cool": 0.0},
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
var watch_node: MultiMeshInstance3D   ## stealth: squares that visible, unalerted guards are watching
var path_node: MeshInstance3D
var range_img: Image
var range_tex: ImageTexture
var fires: Array[OmniLight3D] = []
var decals := {}              ## unit id → ground glow MeshInstance3D
var _withdraw_ask := -10000    ## withdrawal needs a second press within 3 s
var obj_node: Node3D           ## snatch objective: the package (a case on a gold beacon) and the extraction squares
var dash_opts := {}           ## squares reachable by also spending the Action on a Run (amber contour)
var rim: DirectionalLight3D
var sky_mat: ShaderMaterial


## This scene's light and palette (LOOKS), defaulting to the night city.
func _scene_look() -> Dictionary:
	if m == null:
		return LOOKS["default"]
	return LOOKS.get(String(m.params.get("scene", "")), LOOKS["default"])
var open_cells := {}             ## Vector2i squares the cutaway may open (seen-into rooms + walls)
var room_xy := {}                ## room label → its squares, for opening rooms
const KERB := 0.07               # sidewalk height (WorldBuilder raises sidewalks)
var _last_cur := -1
var fx: Fx
var busy := false             ## animating events: input is ignored
var _rebuild := false         ## cover/wall destroyed during playback: rebuild the world after
var ring: MeshInstance3D
var caret: MeshInstance3D
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
var _jack_demo := false
var _inspect_demo := false
var net_overlay: NetOverlay
var net_view := true          ## N toggles back to the plain world while jacked in
var _net_pos := {}            ## architecture instance id → [pos, ground]
var _net_framed := -1
var _net_full_res := false
var _inspected := false        ## the Alt inspector card is showing
var _inspect_cell := Vector3i(-1, -1, -1)
var _shot_delay := 0.0
var _demo_ms := 0
var _reel := ""
var tool := ""                  ## M5 target-picking action: melee, shell, grenade, stabilize ("" = normal attacks)
var blast_node: MeshInstance3D  ## the grenade's 5x5 blast preview under the cursor
var _net_cleaned := false
var _lf_dims := Vector3.ZERO
var _door_leaves := {}        ## door cell → leaf mesh, so moves can swing doors open as they pass


## Swing a door leaf open (a quarter turn about its hinge) when someone steps into the doorway.
func _swing_door(v: Vector3i) -> void:
	var mi: MeshInstance3D = _door_leaves.get(v)
	if mi == null or not is_instance_valid(mi) or absf(mi.rotation.y) > 0.1:
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(mi, "rotation:y", PI / 2, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position", mi.get_meta("open_at"), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
			"objective": gig["objective"] = kv[1]
			"twist": gig["twist"] = kv[1]
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
			"jack":  # review renders: the Netrunner jacks in at the nearest terminal
				_jack_demo = true
			"reel":  # review videos: script one combat scene, then quit (record with --write-movie)
				_reel = kv[1]
			"inspect":  # review renders: show the Alt inspector card for the hovered square
				_inspect_demo = true
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
	if obj_node and is_instance_valid(obj_node) and int(enc.objective.get("carrier", -1)) >= 0:   # the diamond follows the carrier
		var tag := obj_node.get_node("tag") as Node3D
		tag.position = (unit_nodes[int(enc.objective.carrier)] as Node3D).position + Vector3(0, 2.75, 0)
		tag.rotation.y += delta * 2.0
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
	# hold Alt to inspect what's under the cursor (owner: a dwell timer would be annoying)
	var alt := Input.is_key_pressed(KEY_ALT) or _inspect_demo
	if enc and hover.x >= 0 and alt and (not _inspected or hover != _inspect_cell):
		_inspected = true
		_inspect_cell = hover
		_inspect(hover)
	elif _inspected and not alt:
		_inspected = false
		_update_hover()
	if caret and enc and not enc.cur.is_empty():   # caret follows the active unit, bobbing and turning
		var cn: Node3D = unit_nodes.get(enc.cur.id)
		caret.visible = cn != null and cn.visible and enc.cur.team == 0 and enc.state == "playing"
		if cn:
			var t := Time.get_ticks_msec() / 1000.0
			caret.position = cn.global_position + Vector3(0, 1.55 + 0.05 * sin(t * 4.0), 0)
			caret.rotation.y = t * 1.5
	for fl in fires:  # firelight flicker
		fl.light_energy = fl.get_meta("base", 1.0) * look.lights * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.013 + fl.position.x) + randf() * 0.08)
	if _reel != "":
		_frames += 1
		if _frames == 1:   # set up on the very first frame, so the video opens on the action
			_run_reel()
	elif _shot_path != "":
		_frames += 1
		if _frames == 2 and _shot_hover == Vector2i(-2, -2):  # --hover=guard: the nearest guard in sight
			for u in enc.units:
				if u.team == 1 and (enc.vision.visible.has(u.pos) or not fog_on) and not u.c.dead:
					_shot_hover = Vector2i(u.pos.x, u.pos.y)
		if _frames == 3 and _shot_hover.x >= 0:
			hover = Vector3i(_shot_hover.x, _shot_hover.y, view_floor)
			mouse = _to_screen(Vector3(hover.x + 0.5, view_floor * FH, hover.y + 0.5))
			_update_hover()
			if _inspect_demo:
				_inspected = true
				_inspect_cell = hover
				_inspect(hover)
		if _frames == 10 and _attack_demo:
			_demo_attack()
		if _frames == 10 and _jack_demo:
			_demo_jack()
		var shoot_now: bool = _frames >= 12 if not (_attack_demo or _jack_demo) else (_demo_ms > 0 and Time.get_ticks_msec() - _demo_ms >= int(_shot_delay * 1000.0 / Engine.time_scale))
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
	sky_mat = skm
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
	net_overlay = NetOverlay.new()
	net_overlay.visible = false
	hud.add_child(net_overlay)
	hud.move_child(net_overlay, 0)
	net_overlay.to_screen = _to_screen
	var shields := Hud.Painter.new()
	shields.fn = _draw_cover_shields
	hud.add_child(shields)
	hud.move_child(shields, 0)
	hud.build_hint("WASD  PAN\nWHEEL  ZOOM\nQ / E  ROTATE 90\nMIDDLE-DRAG  ROTATE\nPGUP / PGDN  FLOOR\nC  CUTAWAY   F2  LOOK\nLMB  MOVE   RMB  FIRE\nALT (HOLD)  INSPECT\nF4  NET STYLE   N  PEEK\nH  HIDE THIS")
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
	if _net_full_res:
		return 1.0
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
	var sunset := String(_scene_look().get("palette", "")) == "sunset"
	var pal := PackedVector3Array()
	for h in (PALETTE_SUNSET if sunset else PALETTE):
		pal.append(_oklab(Color(h)))
	var nn := PALETTE_SUNSET_NEUTRALS if sunset else PALETTE_NEUTRALS
	post.set_shader_parameter("palette", pal)
	post.set_shader_parameter("palette_n", pal.size())
	post.set_shader_parameter("palette_neutral_n", nn)
	if hud and hud.portraits:   # portraits stay on the night palette: the HUD is the same in every scene
		var npal := PackedVector3Array()
		for h in PALETTE:
			npal.append(_oklab(Color(h)))
		hud.portraits.post_shader = POST_SHADER
		hud.portraits.palette = npal
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
		l[0].light_energy = l[0].get_meta("base", 1.0) * look.lights * float(_scene_look().get("lights", 1.0))
	_apply_world_look()
	_place_camera()


# --- Gig setup -------------------------------------------------------------------

func new_gig() -> void:
	var o := {"security": gig.security}
	if gig.profile != "":
		o["profile"] = gig.profile
	var camp := Campaign.current
	var campaign_gig: bool = camp != null and not camp.active_gig.is_empty() and _reel == "" and _shot_path == ""
	if campaign_gig:   # a gig taken from the fixer board: its scene, security and crew
		gig.scene = String(camp.active_gig.scene)
		gig.seed = int(camp.active_gig.seed)
		gig.security = int(camp.active_gig.security)
		gig.profile = ""
		o = {"security": gig.security}
	m = SceneGen.generate(gig.seed, "neighborhood" if gig.profile != "" else gig.scene, o)
	dice = Dice.new(gig.seed + 1)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	if campaign_gig:
		crew.clear()
		for c in camp.alive_crew():
			if c.can_act():
				crew.append(c)
	var kind := gig.get("objective", "data") as String
	var tw: Array = [] if String(gig.get("twist", "")) == "" else [String(gig.twist)]
	if campaign_gig:
		kind = Campaign.objective_for(camp.active_gig)
		tw = [] if String(camp.active_gig.get("twist", "")) == "" else [String(camp.active_gig.twist)]
		if camp.active_gig.get("setup", false):   # hidden until it springs
			tw.append_array(["setup", "heavy"])
	enc = Encounter.setup(m, dice, crew, kind, tw)
	if campaign_gig:
		enc.heat = camp.heat
	_log_seen = 0
	var lk := _scene_look()
	env.ambient_light_color = Color(lk.ambient)
	env.ambient_light_energy = lk.amb_e
	sun.light_color = Color(lk.key)
	sun.light_energy = lk.key_e
	env.fog_light_color = Color(lk.fog)
	env.fog_density = lk.fog_d
	var skc: Array = lk.get("sky", ["030308", "0d0817", "521a29"])
	sky_mat.set_shader_parameter("zenith", Color(skc[0]))
	sky_mat.set_shader_parameter("mid", Color(skc[1]))
	sky_mat.set_shader_parameter("horizon", Color(skc[2]))
	var rimc: Array = lk.get("rim", ["5a6aa0", 0.25])
	rim.light_color = Color(rimc[0])
	rim.light_energy = rimc[1]
	sun.directional_shadow_max_distance = 140.0
	_apply_look()
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
		if _focus == "objective" and enc.objective.has("cell"):   # review renders: the snatch package
			var oc: Vector3i = enc.objective.cell
			fc = Vector2(oc.x, oc.y)
			view_floor = oc.z
		elif _focus == "center":
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
	_lf_dims = Vector3(m.w, m.h, m.floors)
	RenderingServer.global_shader_parameter_set("lf_dims", _lf_dims)
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
	caret = _make_caret()
	target_ring = _decal(Color("ff3b4f"), 1.2, true, 0.0)
	decals.clear()
	for u in enc.units:
		_unit_node(u)
	_apply_world_look()
	_refresh()


## A unit's body (built with the world, or when backup arrives mid-gig).
func _unit_node(u: Dictionary) -> CharModel:
	if unit_nodes.has(u.id):
		return unit_nodes[u.id]
	var n := CharModel.build(u.team, u.c.look_seed if u.c.look_seed >= 0 else u.id, String(u.c.role), u.c.weapons[0].id() if not u.c.weapons.is_empty() else "assault_rifle")
	decals[u.id] = _decal(Color("05d9e8"), 0.95, false, 0.0)
	decals[u.id].visible = false   # owner: no glows under units; they blend into the scene
	var blob := _decal(Color.BLACK, 0.75, false, 0.0, true)   # contact shadow
	blob.name = "blob"
	blob.get_parent().remove_child(blob)
	n.add_child(blob)
	blob.position = Vector3(0, 0.02, 0)
	blob.scale = Vector3.ONE / 1.3
	world.add_child(n)
	n.position = Vector3(u.pos.x + 0.5, _gy(u.pos), u.pos.y + 0.5)
	n.scale = Vector3.ONE * 1.3
	unit_nodes[u.id] = n
	return n


func _apply_world_look() -> void:
	if builder:
		for mt in builder.materials():
			var lk := _scene_look()   # per scene: bright natural scenes only dim what's out of sight (owner)
			mt.set_shader_parameter("explored_dim", float(lk.get("fog_dim", look.dim)))
			mt.set_shader_parameter("fog_sat", float(lk.get("fog_sat", 0.3)))
			mt.set_shader_parameter("fog_cool", float(lk.get("fog_cool", 1.0)))
			mt.set_shader_parameter("spill", 0.0 if _net_cleaned else look.spill)   # cyberspace keeps the spill off
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
	_update_objective()
	for l in lights:  # rooms stay dark until explored, so a reveal reads as lights coming on
		var cell: Vector3i = l[1]
		l[0].visible = not _net_cleaned and not ("blackout" in enc.twists) and (l[2] != "room" or not fog_on or enc.vision.explored.has(cell))
	_build_doors()
	for u in enc.units:
		var n: Node3D = _unit_node(u)
		var seen: bool = u.team == 0 or not fog_on or enc.vision.visible.has(u.pos)
		n.visible = seen and not _cut_hides(u.pos)
		var dc: MeshInstance3D = decals[u.id]
		dc.visible = false
		n.set_meta("wound", u.c.wound_state())
		n.set_meta("calm", u.team == 1 and not u.alerted)
		n.set_meta("jack", enc.runs.has(u.id))
		if u.c.dead:
			if not n.get_meta("fallen", false):   # died out of sight: just lie there
				n.position = Vector3(u.pos.x + 0.5, _gy(u.pos), u.pos.y + 0.5)
				(n as CharModel).die(Vector3.BACK.rotated(Vector3.UP, n.rotation.y), false, true)
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
				var fc: Vector2 = u.get("facing", Vector2.ZERO)   # watching their sector
				if fc != Vector2.ZERO:
					n.rotation.y = atan2(fc.x, fc.y)
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
	_update_net()
	_toast_new_log()


# --- Cyberspace view ------------------------------------------------------------------------

func _net_active() -> NetRun:
	if enc == null or enc.cur.is_empty() or enc.cur.team != 0 or not net_view:
		return null
	return enc.runs.get(enc.cur.id)


## Cyberspace reads cleaner without the physical world's lighting: the edge styles otherwise trace
## every lamp pool and light spill as white swaths (owner). While jacked in, lamps go dark, the
## baked spill and sun shadows are off, and the move outline and path are hidden.
func _net_clean(on: bool) -> void:
	if on:
		grid_node.visible = false
		path_node.mesh = null
	if on == _net_cleaned:
		return
	_net_cleaned = on
	for l in lights:
		(l[0] as Node3D).visible = not on and (l[2] != "room" or not fog_on or enc.vision.explored.has(l[1]))
	for fl in fires:
		fl.visible = not on
	sun.shadow_enabled = not on
	if builder:
		for mt in builder.materials():
			mt.set_shader_parameter("spill", 0.0 if on else look.spill)
	RenderingServer.global_shader_parameter_set("lf_dims", Vector3.ZERO if on else _lf_dims)   # units drop the spill too


## While jacked in: the environment goes to the chosen background style, the NET draws on top.
func _update_net() -> void:
	var run := _net_active()
	post.set_shader_parameter("net_style", int(look.net_style) if run else 0)
	var full: bool = run != null and int(look.net_style) in NET_FULL_RES
	if full != _net_full_res:   # crisp styles render the 3D view at full resolution
		_net_full_res = full
		_apply_look()
	net_overlay.visible = run != null
	_net_clean(run != null)
	if run == null:
		return
	var key := run.arch.get_instance_id()
	if not _net_pos.has(key):
		_net_pos[key] = _net_layout(run.arch)
	net_overlay.run = run
	net_overlay.pos = _net_pos[key][0]
	net_overlay.ground = _net_pos[key][1]
	net_overlay.visited[run.current] = true
	if run.current != _net_framed:   # frame the current node and its links
		_net_framed = run.current
		var pts: Array = []
		for id in net_overlay.shown():
			if net_overlay.pos.has(id):
				pts.append(net_overlay.pos[id])
		if not pts.is_empty():
			var c := Vector3.ZERO
			var span := 0.0
			for p in pts:
				c += p
			c /= pts.size()
			for p in pts:
				span = maxf(span, Vector2(p.x - c.x, p.z - c.z).length())
			_pan_to(c, 0.35, clampf(span * 3.2 + 10.0, 16.0, 50.0))


## Where each node floats: over its device(s); net-only nodes near their linked nodes; deeper
## security levels higher. Returns [pos, ground] dictionaries.
func _net_layout(a: NetArchitecture) -> Array:
	var known := {}
	var fl := {}
	for nd in a.nodes:
		var ids: Array = []
		if int(nd.get("device", -1)) >= 0:
			ids = [int(nd.device)]
		elif nd.has("devices"):
			ids = nd.devices
		if ids.is_empty():
			continue
		var acc := Vector2.ZERO
		var f := 0
		for did in ids:
			var d: Dictionary = m.devices[did]
			acc += Vector2(d.pos.x + 0.5, d.pos.y + 0.5)
			f = d.floor
		known[nd.id] = acc / ids.size()
		fl[nd.id] = f
	for pass_i in 8:   # relax: unplaced nodes sit around their placed neighbours
		for nd in a.nodes:
			if known.has(nd.id):
				continue
			var acc2 := Vector2.ZERO
			var k := 0
			var f2 := 0
			for nb in a.neighbors(nd.id):
				if known.has(nb):
					acc2 += known[nb]
					f2 = maxi(f2, fl[nb])
					k += 1
			if k > 0:
				var ang: float = float(nd.id) * 2.39996
				known[nd.id] = acc2 / k + Vector2(cos(ang), sin(ang)) * 1.6
				fl[nd.id] = f2
	for nd in a.nodes:   # anything still unplaced goes round the structure centre (below)
		pass
	# separate: nodes at least 2.2 squares apart so icons and labels don't pile up
	var ids := known.keys()
	for it in 30:
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var pa: Vector2 = known[ids[i]]
				var pb: Vector2 = known[ids[j]]
				var dv := pb - pa
				var dl := dv.length()
				if dl < 2.2:
					var push := (dv / maxf(dl, 0.01) if dl > 0.01 else Vector2(cos(i), sin(i))) * (2.2 - dl) * 0.5
					known[ids[i]] = pa - push
					known[ids[j]] = pb + push
	var st_center := Vector2(m.w / 2.0, m.h / 2.0)
	if a.structure >= 0 and m.structures[a.structure].has("rect"):
		st_center = Vector2((m.structures[a.structure].rect as Rect2i).get_center())
	var pos := {}
	var ground := {}
	for nd in a.nodes:
		var xy: Vector2 = known.get(nd.id, st_center + Vector2(cos(nd.id * 2.4), sin(nd.id * 2.4)) * 2.0)
		var f3: int = fl.get(nd.id, 0)
		pos[nd.id] = Vector3(xy.x, f3 * FH + 1.3 + int(nd.zone) * 0.9, xy.y)
		ground[nd.id] = Vector3(xy.x, f3 * FH, xy.y)
	return [pos, ground]


# --- Cover shields and the hover inspector ---------------------------------------------------

## XCOM-style: while planning a move, the hovered square shows a holographic shield on each side
## that has cover (solid: walls and cover pieces; outlined: see-through bulletproof glass).
func _draw_cover_shields(c: Control) -> void:
	if busy or not _crew_turn() or not (move_opts.has(hover) or dash_opts.has(hover)):
		return
	var t := Time.get_ticks_msec() / 1000.0
	for d in MapGen.DIRS:
		var nb := Vector3i(hover.x + d.x, hover.y + d.y, hover.z)
		var b := enc.los.blocker(nb)
		if b == "":
			continue
		var wp := Vector3(hover.x + 0.5 + d.x * 0.45, _gy(hover) + 0.55, hover.y + 0.5 + d.y * 0.45)
		var p: Vector2 = _to_screen(wp)
		var s := 11.0
		var shape := PackedVector2Array([p + Vector2(-s, -s), p + Vector2(s, -s), p + Vector2(s, s * 0.2), p + Vector2(0, s * 1.3), p + Vector2(-s, s * 0.2), p + Vector2(-s, -s)])
		var col := Color("05d9e8")
		var a := 0.85 + 0.15 * sin(t * 6.0)
		if b != "glass":
			c.draw_colored_polygon(shape, Color(col, 0.35 * a))
		c.draw_polyline(shape, Color(col, a), 2.0)
		c.draw_polyline(PackedVector2Array([p + Vector2(-s * 0.5, -s * 0.2), p + Vector2(0, s * 0.5), p + Vector2(s * 0.5, -s * 0.2)]), Color(col, a), 2.0)


## Hold Alt: a card with what's under the cursor and its game stats.
func _inspect(v: Vector3i) -> void:
	if not m.inb(v.x, v.y):
		return
	var lines: Array[String] = []
	var head := "// INSPECT"
	var u := _unit_at(v)
	if not u.is_empty():
		var c: Combatant = u.c
		var w: Weapon = c.weapons[0] if not c.weapons.is_empty() else null
		lines.append("[b]%s[/b]  [color=#7d8a96]%s[/color]" % [c.display_name, c.role.capitalize()])
		lines.append("[code]REF %d  DEX %d  BODY %d  MOVE %d[/code]" % [c.stat("REF"), c.stat("DEX"), c.stat("BODY"), c.stat("MOVE")])
		lines.append("HP %d/%d · %s" % [c.hp, c.max_hp(), ["Unhurt", "Lightly wounded", "Seriously wounded", "Mortally wounded", "Dead"][c.wound_state()]])
		lines.append("Armor: head SP %d · body SP %d" % [c.sp("head"), c.sp("body")])
		if w:
			lines.append("%s · %dd6 · ROF %d%s" % [w.def.name, w.dice(), w.rof(), (" · %d/%d" % [w.ammo, int(w.def.get("mag", 0))]) if w.uses_ammo() else ""])
		if not c.injuries.is_empty():
			lines.append("[color=#ff3b4f]%s[/color]" % ", ".join(c.injuries.map(func(i): return String(i.get("name", i.id)))))
		head = "// INSPECT · " + ("CREW" if u.team == 0 else "HOSTILE")
	var cover_hp: int = enc.los.cover_hp.get(v, 0)
	for cv in m.cover:
		if cv.floor == v.z and cv.pos == Vector2i(v.x, v.y) and cover_hp > 0:
			lines.append("[b]%s[/b]" % String(cv.kind).replace("_", " ").capitalize())
			lines.append("Material: %s%s" % [cv.material, " (thick)" if cv.thick else ""])
			lines.append("Cover · [code]%d / %d HP[/code]" % [cover_hp, int(cv.hp)])
			if String(cv.get("hazard", "")) != "":
				lines.append("[color=#ff6b1a]Hazard: %s[/color]" % cv.hazard)
	var wc := m.wall_cover(v.z, v.x, v.y)
	if not wc.is_empty():
		var t := m.t(v.z, v.x, v.y)
		var hp_left: int = enc.los.wall_hp.get(v, int(wc.hp))
		lines.append("[b]%s[/b]" % ("Door" if t == TacMap.T.DOOR else "Wall"))
		lines.append("Material: %s" % String(wc.material))
		if wc.cover:
			lines.append("Cover · [code]%d / %d HP[/code]" % [hp_left, int(wc.hp)])
		lines.append("Sight: %s" % ("blocked" if wc.blocks_los else "see-through"))
		if t == TacMap.T.DOOR:
			lines.append("Locked (security)" if enc.nav.locked.has(v) else ("Open" if enc.los.open_doors.has(v) else "Closed"))
	for d in m.devices:
		if d.floor == v.z and d.pos == Vector2i(v.x, v.y):
			var on_net := false
			for sid in m.architectures:
				for ap in m.architectures[sid].access_points:
					if ap.device == d.id:
						on_net = true
			lines.append("Device: %s%s%s" % [String(d.type).replace("_", " "), " · jack-in point" if on_net else "", " · under control" if enc.disabled_devices.has(d.id) else ""])
	if lines.is_empty():
		var t2 := m.t(v.z, v.x, v.y)
		var l := m.label(v.z, v.x, v.y)
		var what := ""
		if l >= 0 and not m.rooms[l].get("outdoor", false):
			what = String(m.rooms[l].kind).replace("_", " ").capitalize() + " · L%d" % int(m.rooms[l].zone)
		else:
			what = ["", "Asphalt", "Sidewalk", "Gravel", "Dirt", "Concrete", "Rail bed", "Dock", "Grass", "Sand"][int(m.ground[v.y * m.w + v.x])] if t2 == TacMap.T.OUTSIDE else ""
		if what == "":
			return
		lines.append("[b]%s[/b]" % what)
		lines.append("Floor %d · no cover" % (v.z + 1))
	hud.tip("\n".join(lines), mouse, head, Hud.GOLD)


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
	_door_leaves.clear()
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
		bm.size = Vector3(0.88, 1.1, 0.05) if horiz else Vector3(0.05, 1.1, 0.88)
		mi.mesh = bm
		mi.position = c
		mi.set_meta("closed", c)
		mi.set_meta("open_at", c + (Vector3(-0.44, 0, 0.44) if horiz else Vector3(0.44, 0, -0.44)))
		if open:
			mi.position = mi.get_meta("open_at")
			mi.rotation.y = PI / 2
		door_nodes.add_child(mi)
		_door_leaves[v] = mi
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
	_draw_watch(grid_node.visible)
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
	var sd: Array = _scene_look().get("sun", [])
	sun.rotation_degrees = Vector3(sd[0], sd[1], 0) if not sd.is_empty() else Vector3(-55, cam_yaw + 35, 0)   # a real sun stays put
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
		p += (Vector2(m.w / 2.0, m.h / 2.0) - p).limit_length(cam_dist * 0.2)   # but keep the unit in view
	cam_target = Vector3(clampf(p.x, 0, m.w), 0, clampf(p.y, 0, m.h))
	view_floor = u.pos.z
	_place_camera()


## Units blend in; the one whose turn it is gets an amber downward caret floating above it
## (owner: instead of the white outline).
## While the crew is undetected and planning a move, tint the squares known guards are watching
## (their view cone, clipped by walls) so sneaking is a readable choice, XCOM-concealment style.
func _draw_watch(show: bool) -> void:
	if watch_node == null or not is_instance_valid(watch_node) or watch_node.get_parent() != world:
		watch_node = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var qm := PlaneMesh.new()
		qm.size = Vector2(0.92, 0.92)
		mm.mesh = qm
		watch_node.multimesh = mm
		watch_node.material_override = _unlit(Hud.RED, 0.2, 1.1)
		watch_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(watch_node)
	var cells := {}
	if show and enc.alarm < 2 and not _net_cleaned:
		for g in enc.units:
			if g.team == 1 and not g.alerted and g.c.can_act() and g.pos.z == view_floor and (not fog_on or enc.vision.visible.has(g.pos)):
				cells.merge(enc.watched_cells(g))
	var mm2 := watch_node.multimesh
	mm2.instance_count = cells.size()
	var i := 0
	for v in cells:
		mm2.set_instance_transform(i, Transform3D(Basis(), Vector3(v.x + 0.5, v.z * FH + 0.12, v.y + 0.5)))
		i += 1
	watch_node.visible = not cells.is_empty()


func _update_outlines() -> void:
	for u in enc.units:
		var n: Node3D = unit_nodes.get(u.id)
		if n and n.has_meta("outlines"):
			for ol in n.get_meta("outlines"):
				(ol as MeshInstance3D).visible = false


func _make_caret() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()   # a 4-sided cone, point down: a caret
	cm.top_radius = 0.13
	cm.bottom_radius = 0.0
	cm.height = 0.2
	cm.radial_segments = 4
	cm.rings = 1
	cm.material = _unlit(Color("ffb000"), 1.0, 1.4)
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	return mi


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
		if net_overlay.visible:
			net_overlay.hot = net_overlay.pick(mouse)
		var h := _pick(ev.position)
		if h != hover:
			hover = h
			_draw_path()
		if not _inspected:
			_update_hover()
	elif ev is InputEventMouseButton and ev.pressed:
		if busy and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP: cam_dist = maxf(8, cam_dist * 0.9); _place_camera()
			MOUSE_BUTTON_WHEEL_DOWN: cam_dist = minf(160, cam_dist * 1.1); _place_camera()
			MOUSE_BUTTON_LEFT:
				var run := _net_active()
				if run:   # in the NET, clicks pick nodes
					var id := net_overlay.pick(ev.position)
					if id >= 0 and id != run.current:
						if run.can_move_to(id):
							_on_hud("net_move", id)
						else:
							hud.toast("Blocked: break the firewall or deal with the ICE first.")
					return
				_click_move()
			MOUSE_BUTTON_RIGHT:
				if tool != "":
					_click_tool()
				else:
					_click_attack(ev.shift_pressed or cover_mode)
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
			KEY_F: _on_hud("tool", "melee")
			KEY_G: _on_hud("tool", "grenade")
			KEY_5: _on_hud("tool", "shell")
			KEY_4: _on_hud("suppress", null)
			KEY_T: _on_hud("tool", "stabilize")
			KEY_B: _on_hud("grab", null)
			KEY_Y: _on_hud("tool", "dose")
			KEY_U: _on_hud("tool", "rig")
			KEY_L: _on_hud("withdraw", null)
			KEY_ESCAPE:
				if tool != "":
					tool = ""
					_refresh(); _update_hover()
			KEY_R: _on_hud("reload", null)
			KEY_J: _on_hud("jack_in", null)
			KEY_SPACE: _on_hud("end_turn", null)
			KEY_F1: gig.seed += 1; new_gig()
			KEY_F2: hud.settings.visible = not hud.settings.visible
			KEY_F3: fog_on = not fog_on; _refresh()
			KEY_F4:
				look.net_style = float(NET_CYCLE[(NET_CYCLE.find(int(look.net_style)) + 1) % NET_CYCLE.size()])
				hud.toast("CYBERSPACE STYLE: " + NET_STYLES[int(look.net_style)])
				_refresh()
			KEY_N: net_view = not net_view; _refresh()


func _on_hud(name: String, arg: Variant) -> void:
	if busy:
		return
	match name:
		"mode":
			mode = [Attack.Mode.SINGLE, Attack.Mode.AUTOFIRE, Attack.Mode.AIMED_HEAD][int(arg)]
			cover_mode = false
			_refresh(); _update_hover()
		"cover_mode": cover_mode = not cover_mode; _refresh(); _update_hover()
		"tool":
			tool = "" if tool == String(arg) else String(arg)
			cover_mode = false
			_refresh(); _update_hover()
		"suppress": _suppress()
		"grab":
			if _crew_turn():
				var r := enc.grab()
				if not r.get("ok", false):
					hud.toast(String(r.get("reason", "can't")))
				_after_action()
		"withdraw":
			if not _crew_turn() or not enc.can_withdraw():
				hud.toast("Everyone still standing must be in the deploy zone")
			elif Time.get_ticks_msec() - _withdraw_ask > 3000:
				_withdraw_ask = Time.get_ticks_msec()
				var lb := enc.left_behind()
				hud.toast("WITHDRAW? PRESS AGAIN" + ("  ·  LEAVING %d BEHIND" % lb.size() if not lb.is_empty() else ""), 3.0)
			else:
				enc.withdraw()
				_after_action()
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
			if not enc.net_move(int(arg)):
				hud.toast("Blocked by a firewall or ICE.")
			_after_action()
		"net_slide":
			if _crew_turn():
				var rs := enc.net_action("slide", int(arg))
				if not rs.get("ok", false):
					hud.toast(String(rs.get("reason", "can't")))
				else:
					_float(enc.cur, "SLIDE %s" % ("OK" if rs.success else "FAILED"), Color("d68cff"))
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
		_after_action()
		return
	if t.team == 0:
		return
	var r := enc.attack(t, w, mode)
	if r.get("ok", true) == false:
		hud.toast(r.reason)
	_after_action()


func _reload() -> void:
	if _crew_turn() and not enc.cur.c.weapons.is_empty():
		if enc.reload(enc.cur.c.weapons[0]):
			_after_action()
		else:
			hud.toast("Magazine full or no Action left.")


## M5: apply the active tool to the hovered square.
func _click_tool() -> void:
	if not _crew_turn():
		return
	var t := _unit_at(hover)
	var w: Weapon = enc.cur.c.weapons[0] if not enc.cur.c.weapons.is_empty() else null
	var r := {"ok": false, "reason": "pick a target"}
	match tool:
		"melee":
			if not t.is_empty() and t.team != enc.cur.team:
				r = enc.melee(t)
		"shell":
			if not t.is_empty() and t.team != enc.cur.team and w:
				r = enc.shotgun_shell(t, w)
		"grenade":
			if hover.x >= 0:
				r = enc.throw_grenade(hover)
		"stabilize":
			if not t.is_empty():
				r = enc.stabilize(t)
		"rig":
			if not t.is_empty():
				r = enc.jury_rig(t)
		"dose":
			if not t.is_empty():
				var drug := enc.best_dose(t)
				r = enc.dose(t, drug) if drug != "" else {"ok": false, "reason": "no drug would help"}
	if not r.get("ok", false):
		hud.toast(String(r.get("reason", "can't")).capitalize())
		return
	tool = ""
	if blast_node:
		blast_node.visible = false
	_after_action()


func _suppress() -> void:
	if not _crew_turn() or enc.cur.c.weapons.is_empty():
		return
	var r := enc.suppress(enc.cur.c.weapons[0])
	if not r.get("ok", false):
		hud.toast(String(r.get("reason", "can't")).capitalize())
		return
	_after_action()


## Hover feedback for the M5 tools: odds and who would be caught; the grenade shows its blast.
func _tool_hover() -> void:
	var c: Combatant = enc.cur.c
	var t := _unit_at(hover)
	if blast_node == null:
		blast_node = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(5, 5)
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;\nvoid fragment() {\n\tvec2 d = abs(UV - 0.5) * 2.0;\n\tfloat edge = step(0.94, max(d.x, d.y));\n\tfloat grid = step(0.92, fract(UV.x * 5.0)) + step(0.92, fract(UV.y * 5.0));\n\tALBEDO = vec3(1.0, 0.55, 0.1) * (0.08 + edge * 0.9 + min(grid, 1.0) * 0.12);\n}"
		sm.shader = sh
		pm.material = sm
		blast_node.mesh = pm
		world.add_child(blast_node)
	blast_node.visible = tool == "grenade" and hover.x >= 0
	match tool:
		"grenade":
			if hover.x < 0:
				hud.tip("", mouse)
				return
			blast_node.position = Vector3(hover.x + 0.5, _gy(hover) + 0.05, hover.y + 0.5)
			var dist := Los.distance_m(enc.cur.pos, hover)
			var ok: bool = dist <= Encounter.THROW_RANGE_M and hover.z == enc.cur.pos.z and enc.los.trace(enc.cur.pos, hover).clear
			var dv := maxi(10, RulesDB.range_dv("grenade_launcher", dist))
			var pct := roundi(Check.chance_vs_dv(c.skill_base("athletics") - c.action_penalty(), dv) * 100)
			var caught := enc.units.filter(func(o): return not o.c.dead and o.pos.z == hover.z and maxi(absi(o.pos.x - hover.x), absi(o.pos.y - hover.y)) <= Encounter.BLAST_HALF)
			var names := caught.map(func(o): return ("[color=#39f0a0]%s[/color]" if o.team == enc.cur.team else "[color=#ff3b4f]%s[/color]") % o.c.display_name)
			hud.tip(("[code][font_size=44]%d%%[/font_size][/code] on target · DV %d · %d m\n6d6 in a 5x5 blast (a miss scatters it)\n%s" % [pct, dv, roundi(dist), ", ".join(names) if not names.is_empty() else "nobody in the blast"]) if ok else "[color=#ff3b4f]Out of reach or no clear throw[/color]", mouse, "// GRENADE ×%d" % c.grenades, Hud.GOLD)
		"melee":
			if t.is_empty() or t.team == enc.cur.team:
				hud.tip("Pick a neighbouring enemy", mouse, "// MELEE", Hud.CYAN)
				return
			var mw := enc.melee_weapon(c)
			var p := enc.preview(t, mw, Attack.Mode.SINGLE)
			hud.tip(("[code][font_size=44]%d%%[/font_size][/code]  %s · %dd6" % [roundi(p.chance * 100), mw.def.name, mw.dice()]) if p.ok else "[color=#ff3b4f]%s[/color]" % String(p.reason).capitalize(), mouse, "// MELEE", Hud.CYAN)
		"shell":
			if t.is_empty() or t.team == enc.cur.team:
				hud.tip("Pick an enemy: everyone in a 90° cone to 6 m is caught", mouse, "// SHOTGUN SHELL", Hud.CYAN)
				return
			var pct2 := roundi(Check.chance_vs_dv(c.skill_base(enc.cur.c.weapons[0].skill()) - c.action_penalty(), Attack.SHOTGUN_SHELL_DV) * 100)
			hud.tip("[code][font_size=44]%d%%[/font_size][/code] vs DV13 · 3d6 to everyone in the cone" % pct2, mouse, "// SHOTGUN SHELL", Hud.CYAN)
		"rig":
			if t.is_empty() or t.team != enc.cur.team:
				hud.tip("Pick yourself or a neighbouring ally with worn armour", mouse, "// JURY-RIG", Hud.CYAN)
				return
			var loc := enc.rig_target_loc(t)
			if loc == "":
				hud.tip("No worn armour that hasn't been rigged already", mouse, "// JURY-RIG", Hud.CYAN)
				return
			var ap: ArmorPiece = t.c.armor[loc]
			var pr := roundi(Check.chance_vs_dv(Encounter.rig_base(c), ArmorPiece.maker_dv(ap.price())) * 100)
			hud.tip("[code][font_size=44]%d%%[/font_size][/code] %s SP %d → %d · TECH + Basic Tech + Field vs DV%d" % [pr, loc.to_upper(), ap.sp, ap.max_sp, ArmorPiece.maker_dv(ap.price())], mouse, "// JURY-RIG", Hud.CYAN)
		"dose":
			if t.is_empty() or t.team != enc.cur.team:
				hud.tip("Pick yourself or a neighbouring ally (%d doses)" % c.doses, mouse, "// PHARMACEUTICALS", Hud.GREEN)
				return
			var drug := enc.best_dose(t)
			if drug == "":
				hud.tip("Nothing helps: unhurt, Mortally Wounded, or already dosed today", mouse, "// PHARMACEUTICALS", Hud.GREEN)
				return
			var what := "+%d HP (BODY + WILL)" % mini(t.c.max_hp() - t.c.hp, t.c.raw_stat("BODY") + t.c.raw_stat("WILL")) if drug == "speedheal" else "ignore Seriously Wounded penalties"
			hud.tip("%s · %s · %d doses left" % [drug.to_upper(), what, c.doses], mouse, "// PHARMACEUTICALS", Hud.GREEN)
		"stabilize":
			if t.is_empty() or t.team != enc.cur.team or t.c.wound_state() != Combatant.Wound.MORTAL:
				hud.tip("Pick a Mortally Wounded ally in reach", mouse, "// STABILIZE", Hud.GREEN)
				return
			var pct3 := roundi(Check.chance_vs_dv(maxi(c.skill_base("first_aid"), c.skill_base("paramedic")) - c.action_penalty(), t.c.stabilization_dv()) * 100)
			hud.tip("[code][font_size=44]%d%%[/font_size][/code] vs DV%d · TECH + First Aid" % [pct3, t.c.stabilization_dv()], mouse, "// STABILIZE", Hud.GREEN)


func _jack_in() -> void:
	if not _crew_turn():
		return
	var pts := enc.jack_points(enc.cur)
	if pts.is_empty():
		hud.toast("No terminal within %d m." % int(Encounter.jack_range(enc.cur.c)))
	elif not enc.jack_in(pts[0]):
		hud.toast("Your Action is spent this turn.")
	_after_action()


func _end_turn() -> void:
	if not _crew_turn():
		return
	enc.end_turn()
	enc.next_turn()
	_after_action()


func _demo_jack() -> void:
	var runner := {}
	for u in enc.alive(0):
		if NetRun.interface_rank(u.c) > 0:
			runner = u
	if runner.is_empty():
		return
	var best := Vector3i(-1, -1, -1)
	for sid in m.architectures:
		var a: NetArchitecture = m.architectures[sid]
		for ap in a.access_points:
			var d: Dictionary = m.devices[ap.device]
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var v := Vector3i(d.pos.x + dx, d.pos.y + dy, d.floor)
					if best.x < 0 and m.walkable(v.z, Vector2i(v.x, v.y)) and not enc.occupied().has(v) and Los.distance_m(v, Vector3i(d.pos.x, d.pos.y, d.floor)) <= 4.0 \
							and not enc._wall_between(v, Vector3i(d.pos.x, d.pos.y, d.floor)):
						best = v
	if best.x < 0:
		return
	runner.pos = best
	enc.cur = runner
	enc.turn = TurnState.begin(dice, runner.c)
	view_floor = best.z
	var pts := enc.jack_points(runner)
	if not pts.is_empty():
		enc.jack_in(pts[0])
		var run: NetRun = enc.runs[runner.id]
		for nb in run.arch.neighbors(run.current):   # step one node in so more of the NET shows
			if run.can_move_to(nb) and run.arch.neighbors(nb).size() > 1:
				enc.net_move(nb)
				break
	enc.refresh_vision()
	_frame_unit(runner)
	_refresh()
	_demo_ms = Time.get_ticks_msec()


## Review videos: one scripted combat beat per reel, recorded with Godot's movie writer
## (tools/review_videos.sh). Outcomes are forced by setting HP/SP before the roll and retrying, so
## each reel shows the effect it is named for.
func _run_reel() -> void:
	var g := _nearest_guard()
	if _reel not in ["move", "jack", "cover", "stabilize", "reload", "dose", "rig", "grab", "backup", "watch"]:
		_reel_setup_shot(g)
	if _reel in ["stabilize", "reload", "dose", "rig", "grab", "backup"]:
		_reel_frame(enc.cur)
	var cell := Vector3i(-1, -1, -1)
	if _reel == "cover":   # a one-square piece that takes a few shots; the shooter stands 3-5 squares off in sight
		var best_hp := 0
		for c in m.cover:
			var v := Vector3i(c.pos.x, c.pos.y, c.floor)
			var hp: int = enc.los.cover_hp.get(v, 0)
			if int(c.get("prop", -1)) >= 0 or hp < 8 or hp > 40 or hp <= best_hp:
				continue
			for s in enc.nav.reachable(v, 6, enc.occupied()):
				var dd := Vector2(s.x - v.x, s.y - v.y).length()
				if s.z == v.z and dd >= 3 and dd <= 5 and enc.los.sight(s, v).visible:
					cell = v
					best_hp = hp
					enc.cur.pos = s
					break
		if cell.x >= 0:
			print("reel cover: %s %s hp %d" % [cell, m.cover.filter(func(c): return Vector3i(c.pos.x, c.pos.y, c.floor) == cell)[0].kind, best_hp])
			view_floor = cell.z
			cam_target = Vector3((enc.cur.pos.x + cell.x) / 2.0 + 0.5, 0, (enc.cur.pos.y + cell.y) / 2.0 + 0.5)
			_place_camera()
			enc.refresh_vision()
			_refresh()   # synchronous: the first rendered frame already frames shooter and target
	await get_tree().create_timer(0.6).timeout
	var tail := 1.6
	match _reel:
		"move":
			var far := Vector3i(-1, -1, -1)
			for v in enc.nav.reachable(enc.cur.pos, enc.turn.squares_available(), enc.occupied()):
				if far.x < 0 or Vector3(v - enc.cur.pos).length() > Vector3(far - enc.cur.pos).length():
					far = v
			enc.move_to(far)
			await _act()
			await get_tree().create_timer(0.6).timeout
			enc.turn.move_left = 0
			var far2 := Vector3i(-1, -1, -1)
			for v in enc.nav.reachable(enc.cur.pos, enc.cur.c.stat("MOVE"), enc.occupied()):
				if far2.x < 0 or Vector3(v - enc.cur.pos).length() > Vector3(far2 - enc.cur.pos).length():
					far2 = v
			enc.move_to(far2, true)   # Run action
			await _act()
		"single", "auto", "kill", "headshot", "armor", "pistol":
			var md: int = {"auto": Attack.Mode.AUTOFIRE, "headshot": Attack.Mode.AIMED_HEAD}.get(_reel, Attack.Mode.SINGLE)
			if _reel in ["kill", "headshot", "armor"]:   # make the beat happen on the first shot
				for sk in enc.cur.c.skills:
					enc.cur.c.skills[sk] = int(enc.cur.c.skills[sk]) + 12
			if _reel in ["kill", "headshot"]:
				g.c.hp = 1
				for loc in ["head", "body"]:
					if g.c.armor[loc]:
						g.c.armor[loc].sp = 0
				tail = 4.0   # the whole fall
			if _reel == "armor":
				for loc in ["head", "body"]:
					if g.c.armor[loc]:
						g.c.armor[loc].sp = 40
			for k in 8:   # retry until the beat happens (a hit for kill/armor/headshot)
				enc.turn.action_available = true
				enc.turn.attacks_left = 0
				var r := enc.attack(g, enc.cur.c.weapons[0], md)
				print("reel %s try %d: %s" % [_reel, k, {"ok": r.get("ok"), "hit": r.get("hit"), "dodged": r.get("dodged"), "damage": r.get("damage"), "through": r.get("through"), "armor": [g.c.armor.head != null, g.c.armor.body != null], "sp": g.c.sp("body"), "reason": r.get("reason"), "dead": g.c.dead}])
				await _act()
				if _reel in ["single", "auto", "pistol"] or g.c.dead:
					break
				if r.get("hit", false) and not r.get("dodged", false):
					break
				await get_tree().create_timer(0.3).timeout
			if _reel in ["kill", "headshot"] and not g.c.dead:
				# 0 HP is Mortally Wounded (DYING); death comes from a failed Death Save at the start
				# of the guard's own turn (p222). Make the save fail and play turns until it does.
				g.c.dsp = 50
				tail = 0.2   # the death event already holds on the body
				for k in 6:
					if g.c.dead:
						break
					_on_hud("end_turn", null)
					await get_tree().create_timer(0.2).timeout
					while busy:
						await get_tree().process_frame
		"cover":
			if cell.x >= 0:
				for k in 8:
					if enc.los.cover_hp.get(cell, 0) <= 0:
						break
					enc.turn.action_available = true
					enc.turn.attacks_left = 0
					enc.shoot_cover(cell, enc.cur.c.weapons[0])
					await _act()
		"enemy":
			enc.attack(g, enc.cur.c.weapons[0], Attack.Mode.SINGLE)   # gunfire rouses the guards into initiative
			await _act()
			var others: Array = enc.units.filter(func(o): return o.team == 1 and not o.alerted and not o.c.dead)
			enc._rouse(others.slice(0, 3))
			await _act()
			for k in 4:   # end crew turns: the guards act in between (AI turns play out inside _after_action)
				_on_hud("end_turn", null)
				await get_tree().create_timer(0.2).timeout
				while busy:
					await get_tree().process_frame
		"jack":
			_demo_jack()
			await get_tree().create_timer(3.5).timeout
		"melee":
			for s in enc.nav.reachable(g.pos, 3, enc.occupied()):
				if enc.adjacent(s, g.pos):
					enc.cur.pos = s
					break
			_reel_frame(g)
			await get_tree().create_timer(0.5).timeout
			for k in 6:
				enc.turn = TurnState.begin(dice, enc.cur.c)
				var r := enc.melee(g)
				await _act()
				if r.get("hit", false) or g.c.dead:
					break
		"suppress":
			await get_tree().create_timer(0.4).timeout
			for k in 4:
				enc.turn = TurnState.begin(dice, enc.cur.c)
				enc.cur.c.weapons[0].reload()
				var r := enc.suppress(enc.cur.c.weapons[0])
				await _act()
				if not r.get("suppressed", []).is_empty():
					break
			for k in 2:   # the pinned guard dives for cover on its turn
				_on_hud("end_turn", null)
				await get_tree().create_timer(0.2).timeout
				while busy:
					await get_tree().process_frame
		"shell":
			var sg := Weapon.from_id("shotgun")
			enc.cur.c.weapons.insert(0, sg)
			(unit_nodes[enc.cur.id] as CharModel).set_weapon("shotgun")
			for s in enc.nav.reachable(g.pos, 4, enc.occupied()):
				if Vector2(s.x - g.pos.x, s.y - g.pos.y).length() >= 2 and Vector2(s.x - g.pos.x, s.y - g.pos.y).length() <= 2.9 and enc.los.sight(s, g.pos).visible:
					enc.cur.pos = s
					break
			_reel_frame(g)
			enc.cur.c.skills["shoulder_arms"] = int(enc.cur.c.skills.get("shoulder_arms", 0)) + 10
			await get_tree().create_timer(0.5).timeout
			for k in 4:
				enc.turn = TurnState.begin(dice, enc.cur.c)
				sg.reload()
				var r := enc.shotgun_shell(g, sg)
				await _act()
				if r.get("hit", false):
					break
		"grenade":
			enc.cur.c.skills["athletics"] = int(enc.cur.c.skills.get("athletics", 0)) + 10
			await get_tree().create_timer(0.4).timeout
			enc.turn = TurnState.begin(dice, enc.cur.c)
			var r := enc.throw_grenade(g.pos)
			print("reel grenade: ", r.get("ok"), " ", r.get("reason", ""), " dmg ", r.get("damage", 0))
			await _act()
			tail = 2.5
		"stabilize":
			var ally: Dictionary = enc.alive(0).filter(func(o): return o != enc.cur)[0]
			for s in enc.nav.reachable(enc.cur.pos, 3, enc.occupied()):
				if enc.adjacent(s, enc.cur.pos):
					ally.pos = s
					break
			ally.c.hp = 0
			_refresh()
			_reel_frame(ally)
			enc.cur.c.skills["first_aid"] = int(enc.cur.c.skills.get("first_aid", 0)) + 10
			await get_tree().create_timer(0.8).timeout
			for k in 4:
				enc.turn = TurnState.begin(dice, enc.cur.c)
				var r := enc.stabilize(ally)
				await _act()
				if r.get("success", false):
					break
		"dose", "rig":
			var ally2: Dictionary = enc.alive(0).filter(func(o): return o != enc.cur)[0]
			for s in enc.nav.reachable(enc.cur.pos, 3, enc.occupied()):
				if enc.adjacent(s, enc.cur.pos):
					ally2.pos = s
					break
			if _reel == "dose":
				enc.cur.c.role = "medtech"
				enc.cur.c.medicine = {"pharma": 2}
				enc.cur.c.doses = 2
				ally2.c.hp = maxi(1, ally2.c.max_hp() / 3)
			else:
				enc.cur.c.maker = {"field": 3}
				enc.cur.c.skills["basic_tech"] = 10
				(ally2.c.armor.body as ArmorPiece).sp = 3
			_refresh()
			_reel_frame(ally2)
			await get_tree().create_timer(0.8).timeout
			enc.turn = TurnState.begin(dice, enc.cur.c)
			var r2 := enc.dose(ally2, "speedheal") if _reel == "dose" else enc.jury_rig(ally2)
			print("reel %s: %s" % [_reel, r2])
			await _act()
		"grab":
			var spot := Vector3i(-1, -1, -1)
			for s in enc.nav.reachable(enc.cur.pos, 3, enc.occupied()):
				if enc.adjacent(s, enc.cur.pos):
					spot = s
					break
			enc.objective = {"kind": "snatch", "done": false, "cell": spot, "carrier": -1}
			_refresh()
			await get_tree().create_timer(1.2).timeout
			enc.turn = TurnState.begin(dice, enc.cur.c)
			print("reel grab: ", enc.grab())
			await _act()
			var far3 := Vector3i(-1, -1, -1)
			for v in enc.nav.reachable(enc.cur.pos, enc.turn.squares_available(), enc.occupied()):
				if far3.x < 0 or Vector3(v - enc.cur.pos).length() > Vector3(far3 - enc.cur.pos).length():
					far3 = v
			enc.move_to(far3)
			await _act()
		"backup":
			await get_tree().create_timer(0.4).timeout
			var gs := enc.alive(1)
			if not gs.is_empty():
				enc._call_it_in(gs[0])
			await _act()
			var roster: Array[String] = ["mook", "mook", "mook"]
			enc._spawn_wave(roster, "Backup", "BACKUP")
			await _act()
			tail = 2.5
		"watch":   # the stealth overlay: a guard's watched squares while the crew plans a move
			fog_on = false
			var gw := _nearest_guard()
			if not gw.is_empty():
				gw.facing = Vector2(enc.cur.pos.x - gw.pos.x, enc.cur.pos.y - gw.pos.y).normalized()
				view_floor = gw.pos.z
				cam_target = Vector3(gw.pos.x + 0.5, 0, gw.pos.y + 0.5)
				_place_camera()
			_refresh()
			tail = 3.0
		"reload":
			await get_tree().create_timer(0.4).timeout
			enc.cur.c.weapons[0].ammo = 2
			enc.turn = TurnState.begin(dice, enc.cur.c)
			enc.reload(enc.cur.c.weapons[0])
			await _act()
	await get_tree().create_timer(tail).timeout
	print("reel %s end: target %s" % [_reel, "dead" if g.get("c") and g.c.dead else "alive"])
	get_tree().quit()


func _reel_frame(u: Dictionary) -> void:
	view_floor = enc.cur.pos.z
	var a := _body_pos(enc.cur)
	var b := _body_pos(u)
	cam_target = Vector3((a.x + b.x) / 2.0, 0, (a.z + b.z) / 2.0)
	_place_camera()
	enc.refresh_vision()
	_refresh()


func _act() -> void:
	_after_action()
	await get_tree().process_frame
	while busy:
		await get_tree().process_frame


func _nearest_guard() -> Dictionary:
	var best := {}
	for u in enc.units:
		if u.team == 1 and not u.c.dead and (best.is_empty() or Vector2(u.pos.x - enc.cur.pos.x, u.pos.y - enc.cur.pos.y).length() < Vector2(best.pos.x - enc.cur.pos.x, best.pos.y - enc.cur.pos.y).length()):
			best = u
	return best


## Put the shooter in sight of the guard, a few squares off, and frame both.
func _reel_setup_shot(g: Dictionary) -> void:
	if g.is_empty():
		return
	if _reel == "pistol":
		for u in enc.alive(0):
			if u.c.weapons[0].id().contains("pistol"):
				enc.cur = u
				enc.turn = TurnState.begin(dice, u.c)
	for v in enc.nav.reachable(g.pos, 6, enc.occupied()):
		var d := Vector2(v.x - g.pos.x, v.y - g.pos.y).length()
		if v != g.pos and d >= 3 and d <= 6 and enc.los.sight(v, g.pos).visible:
			enc.cur.pos = v
			break
	view_floor = enc.cur.pos.z
	cam_target = Vector3((enc.cur.pos.x + g.pos.x) / 2.0 + 0.5, 0, (enc.cur.pos.y + g.pos.y) / 2.0 + 0.5)
	_place_camera()
	enc.refresh_vision()
	_refresh()


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
	if enc.state != "playing" and Campaign.current and not Campaign.current.active_gig.is_empty():
		_finish_gig()


## Snatch gigs: the package sits on a gold beacon until someone carries it (then a gold diamond
## floats over the carrier), and the deploy squares glow as the extraction point.
func _update_objective() -> void:
	var snatch: bool = enc.objective.get("kind", "") == "snatch"
	if obj_node == null or not is_instance_valid(obj_node) or obj_node.get_parent() != world:
		obj_node = Node3D.new()
		world.add_child(obj_node)
		var case := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.42, 0.16, 0.3)
		case.mesh = bm
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color("2a2c30")
		cm.metallic = 0.6
		cm.roughness = 0.35
		case.material_override = cm
		case.position.y = 0.08
		case.name = "case"
		obj_node.add_child(case)
		var beacon := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.42
		cy.bottom_radius = 0.42
		cy.height = 2.2
		cy.cap_top = false
		cy.cap_bottom = false
		beacon.mesh = cy
		beacon.material_override = _unlit(Hud.GOLD, 0.16, 1.3)
		beacon.position.y = 1.1
		beacon.name = "beacon"
		obj_node.add_child(beacon)
		var tag := MeshInstance3D.new()   # the carrier's diamond
		var pm := PrismMesh.new()
		pm.size = Vector3(0.22, 0.3, 0.06)
		tag.mesh = pm
		tag.material_override = _unlit(Hud.GOLD, 1.0, 1.4)
		tag.rotation.z = PI
		tag.name = "tag"
		obj_node.add_child(tag)
		var zone := Node3D.new()
		zone.name = "zone"
		obj_node.add_child(zone)
		for cell in enc.extract_cells:
			var q := MeshInstance3D.new()
			var qm := PlaneMesh.new()
			qm.size = Vector2(0.86, 0.86)
			q.mesh = qm
			q.material_override = _unlit(Hud.GOLD, 0.22, 1.0)
			q.position = Vector3(cell.x + 0.5, _gy(cell) + 0.025, cell.y + 0.5)
			zone.add_child(q)
	obj_node.visible = not _net_cleaned
	var carrier: int = enc.objective.get("carrier", -1)
	var case_n := obj_node.get_node("case") as Node3D
	if not snatch:   # the deploy zone still marks the way out (withdrawal)
		for nm in ["case", "beacon", "tag"]:
			(obj_node.get_node(nm) as Node3D).visible = false
		return
	var beacon_n := obj_node.get_node("beacon") as Node3D
	var tag_n := obj_node.get_node("tag") as Node3D
	if carrier < 0:
		var cell: Vector3i = enc.objective.cell
		var p := Vector3(cell.x + 0.5, _gy(cell), cell.y + 0.5)
		case_n.position = p + Vector3(0, 0.08, 0)
		beacon_n.position = p + Vector3(0, 1.1, 0)
		case_n.visible = not _cut_hides(cell)
		beacon_n.visible = case_n.visible
		tag_n.visible = false
	else:
		case_n.visible = false
		beacon_n.visible = false
		var cn: Node3D = unit_nodes[carrier]
		tag_n.visible = cn.visible
		tag_n.position = cn.position + Vector3(0, 2.75, 0)


## A board gig is over: settle it (pay, injuries, the dead), save, and go back to the board.
func _finish_gig() -> void:
	hud.turn_banner("GIG %s  ·  BACK TO THE BOARD" % ("COMPLETE" if enc.state == "won" else ("ABANDONED" if enc.state == "fled" else "FAILED")), Hud.GREEN if enc.state == "won" else Hud.RED)
	await get_tree().create_timer(3.0).timeout
	var camp := Campaign.current
	var report := camp.resolve(enc)
	camp.set_meta("report", report)
	camp.save()
	get_tree().change_scene_to_file("res://scenes/board.tscn")


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
		if u.team == 1 and not hostile_shown and String(e.type) not in ["alert", "death", "camera"] and not e.get("patrol", false) and _event_visible(e):
			hostile_shown = true
			hud.enemy_phase(true)
			hud.turn_banner("HOSTILE ACTIVITY", Hud.RED)
			await get_tree().create_timer(0.3).timeout
		match String(e.type):
			"move": await _anim_move(e)
			"attack": await _anim_attack(e)
			"cover": await _anim_cover(e)
			"alert": _anim_alert(e)
			"reload": await _anim_reload(e)
			"stabilize": await _anim_stabilize(e)
			"rig":
				var rn: CharModel = unit_nodes[u.id]
				var rt: Dictionary = enc.units[e.target]
				_focus_unit = u.id
				if rt != u:
					var rd := Vector2(rt.pos.x - u.pos.x, rt.pos.y - u.pos.y)
					_turn_to(rn, atan2(rd.x, rd.y), 0.15)
				rn.perform("medtech", 1.0)
				await get_tree().create_timer(1.0).timeout
				_float(rt, ("%s ARMOUR RIGGED" % String(e.loc).to_upper()) if e.ok else "RIG FAILED", Hud.CYAN if e.ok else Hud.RED)
				await get_tree().create_timer(0.4).timeout
			"dose":
				var dn: CharModel = unit_nodes[u.id]
				var dt: Dictionary = enc.units[e.target]
				_focus_unit = u.id
				if dt != u:
					var dd := Vector2(dt.pos.x - u.pos.x, dt.pos.y - u.pos.y)
					_turn_to(dn, atan2(dd.x, dd.y), 0.15)
				dn.duck(0.4)
				await get_tree().create_timer(0.35).timeout
				_float(dt, ("SPEEDHEAL +%d" % int(e.healed)) if e.drug == "speedheal" else "STIMMED", Hud.GREEN)
				await get_tree().create_timer(0.5).timeout
			"suppress": await _anim_suppress(e)
			"shell": await _anim_shell(e)
			"blast": await _anim_blast(e)
			"harm": _anim_harm(e)
			"alarm":
				if _seen(u.pos):
					_float(u, "CALLING IT IN", Hud.RED)
				hud.toast("ALARM: BACKUP IN %d ROUNDS" % int(e.rounds))
			"backup": await _anim_backup(e)
			"camera":
				var tu: Dictionary = enc.units[e.target]
				_float(tu, "ON CAMERA", Hud.RED)
				hud.toast("A CAMERA SPOTTED %s · TAKE THE CAMERAS IN THE NET" % tu.c.display_name.to_upper())
			"death": await _anim_death(e)
			"grab":
				var gn: CharModel = unit_nodes[u.id]
				_focus_unit = u.id
				gn.duck(0.6)
				await get_tree().create_timer(0.4).timeout
				_float(u, "PACKAGE SECURED", Hud.GOLD)
				hud.toast("GET IT TO THE EXTRACTION POINT")
				await get_tree().create_timer(0.5).timeout
			"drop":
				_float(u, "PACKAGE DROPPED", Hud.RED)
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
	if _reel != "" and OS.has_environment("REEL_DEBUG"):
		print("move %s: %s" % [u.c.display_name, (path as Array).map(func(v): return "%d,%d,%d:%s%s" % [v.x, v.y, v.z, m.t(v.z, v.x, v.y), "C" if _cut_hides(v) else ""])])
	var step := 0.22 if e.run else 0.33   # matches the sprint / run clips' stride at unit scale
	if e.get("patrol", false):
		step = 0.62   # a patrol strolls (walk clip)
	n.set_meta("stroll", e.get("patrol", false))
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
		# hidden while on a storey above the cutaway (otherwise they float over the cut-away walls
		# below and seem to walk through them), and guards only where the crew can see
		n.visible = (u.team == 0 or _seen(a) or _seen(b)) and not (_cut_hides(a) and _cut_hides(b))
		var to := Vector3(b.x + 0.5, _gy(b), b.y + 0.5)
		for dv in [a, b]:   # doors open as the walker reaches them, not after the whole playback
			if m.t(dv.z, dv.x, dv.y) == TacMap.T.DOOR:
				_swing_door(dv)
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
	var mz: Node3D = j.get("muzzle")
	return mz.global_position if mz and is_instance_valid(mz) else n.global_position + Vector3(0, 0.8, 0)


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
	var restore_floor := -1
	if su.team == 0 and su.pos.z != view_floor:   # follow a crew shooter to their floor (XCOM-style)
		view_floor = su.pos.z
		_refresh()
	elif su.team == 1 and maxi(su.pos.z, tu.pos.z) > view_floor and _seen(su.pos):   # a guard firing from above: lift the view for the shot
		restore_floor = view_floor
		view_floor = maxi(su.pos.z, tu.pos.z)
		_update_fog()
		_update_cut()
	sn.visible = sn.visible or _seen(su.pos)
	tn.visible = tn.visible or _seen(tu.pos)
	await _frame_pair(_body_pos(su), _body_pos(tu))
	var wid := String(e.get("weapon", "assault_rifle"))
	if wid == "brawling" or wid.begins_with("martial") or wid.ends_with("_melee"):
		await _anim_melee(e, su, tu, sn, tn, wid)
		return
	sn.set_meta("aim_at", _body_pos(tu) + Vector3(0, 0.95 if String(e.get("location", "body")) == "head" else 0.72, 0))   # before the weapon comes up
	var d := Vector2(tu.pos.x - su.pos.x, tu.pos.y - su.pos.y)
	# lean out of cover toward the firing square
	var home := sn.position
	var from: Vector3i = e.get("from", su.pos)
	if from != su.pos:
		var lean := Vector3(from.x - su.pos.x, 0, from.y - su.pos.y).normalized() * 0.35
		create_tween().tween_property(sn, "position", home + lean, 0.12)
	sn.set_meta("crouch_goal", 0.0)   # stand (or lean out) to fire: the muzzle clears low cover; crouch is only the idle in-cover pose
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), float(sn.get_meta("aim", 0.0)), 1.0, 0.1)
	await get_tree().create_timer(0.18).timeout
	var aim := _body_pos(tu) + Vector3(0, 0.95 if String(e.get("location", "body")) == "head" else 0.72, 0) * 1.0
	sn.set_meta("aim_at", aim)
	var rounds: int = int(e.get("rounds", 1)) if int(e.mode) == Attack.Mode.AUTOFIRE else 1
	var connect: int = (int(e.get("mult", 1)) if int(e.mode) == Attack.Mode.AUTOFIRE else 1) if (e.hit and not e.dodged) else 0
	var hit_rounds := {}   # which rounds connect: spread through the burst
	for k in connect:   # floor, not round: a single shot's only round is index 0
		hit_rounds[mini(rounds - 1, int(floor(float(k + 1) * rounds / (connect + 1))))] = true
	var last_hit := -1
	for k in hit_rounds:
		last_hit = maxi(last_hit, k)
	var gap: float = FIRE_GAP.get(wid, 0.0)
	var light := _flash_light(su.id)
	if e.dodged:   # the dodge starts before the rounds arrive, so they pass through empty air
		var side := Vector3(-d.y, 0, d.x).normalized() * 0.32
		(tn as CharModel).duck(0.55)   # a snap down into cover stance while the body slips sideways
		var tw := create_tween()
		tw.tween_property(tn, "position", tn.position + side, 0.09).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.25)
		tw.tween_property(tn, "position", tn.position, 0.2)
		_float(tu, "DODGE", Hud.CYAN)
	var arrived := [0]
	var outcome_shown := [false]
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
				if int(e.damage) > 0 and not is_last:   # rounds that get through bleed; armour sparks
					fx.blood(dest, dir, 0.4, _gy(tu.pos))
				elif int(e.damage) <= 0:
					fx.sparks(dest)
				if is_last:
					outcome_shown[0] = true
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
	if connect > 0 and not outcome_shown[0]:   # safety net: a hit always resolves on screen
		_outcome(e, su, tu, tn, aim, (aim - _muzzle_of(sn)).normalized())
	if not e.hit and not e.dodged:
		_float(tu, "MISS", Hud.DIM)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 1.0, 0.0, 0.25).set_delay(0.3)
	if from != su.pos:
		create_tween().tween_property(sn, "position", home, 0.15).set_delay(0.25)
	await get_tree().create_timer(0.45 if e.hit else 0.3).timeout
	if restore_floor >= 0:
		view_floor = restore_floor
		_update_fog()
		_update_cut()


# --- M5 actions: melee, reload, stabilize, suppressive fire, shotgun shells, grenades -----------

## Melee: a step in, the swing (brawling or blade clip), the outcome on contact, a step back.
func _anim_melee(e: Dictionary, su: Dictionary, tu: Dictionary, sn: Node3D, tn: Node3D, wid: String) -> void:
	var d := Vector2(tu.pos.x - su.pos.x, tu.pos.y - su.pos.y)
	_turn_to(sn, atan2(d.x, d.y), 0.1)
	_turn_to(tn, atan2(-d.x, -d.y), 0.15)
	var home := sn.position
	var lunge := Vector3(d.x, 0, d.y).normalized() * 0.3
	create_tween().tween_property(sn, "position", home + lunge, 0.18).set_trans(Tween.TRANS_QUAD)
	(sn as CharModel).play_once("melee_blade" if wid.ends_with("_melee") else "melee", 0.08)
	await get_tree().create_timer(0.38).timeout
	var at := _body_pos(tu) + Vector3(0, 0.7, 0)
	var dir := Vector3(d.x, 0, d.y).normalized()
	if e.hit and not e.dodged:
		_outcome(e, su, tu, tn, at, dir)
		_kick(_screen_dir(at - dir, at), 3.0)
	else:
		_float(tu, "BLOCKED" if not e.dodged else "DODGE", Hud.CYAN)
	await get_tree().create_timer(0.35).timeout
	create_tween().tween_property(sn, "position", home, 0.2)
	await get_tree().create_timer(0.3).timeout


func _anim_reload(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	if not _seen(u.pos):
		return
	var n: CharModel = unit_nodes[u.id]
	_focus_unit = u.id
	var clip := ("pistol" if n.gun_kind == "pistol" else "rifle") + "_reload"
	n.play_once(clip, 0.12)
	_float(u, "RELOAD", Hud.CYAN)
	await get_tree().create_timer(minf(n.anim.get_animation(clip).length, 2.4) if n.anim.has_animation(clip) else 1.0).timeout


func _anim_stabilize(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var t: Dictionary = enc.units[e.target]
	var n: CharModel = unit_nodes[u.id]
	_focus_unit = u.id
	await _pan_to(_body_pos(t), 0.3)
	var d := Vector2(t.pos.x - u.pos.x, t.pos.y - u.pos.y)
	_turn_to(n, atan2(d.x, d.y), 0.15)
	n.perform("medtech", 1.8)
	await get_tree().create_timer(1.6).timeout
	_float(t, "STABILIZED" if e.ok else "STABILIZE FAILED", Hud.GREEN if e.ok else Hud.RED)
	if e.ok:
		(unit_nodes[t.id] as Node3D).set_meta("slump_goal", 0.0)
	await get_tree().create_timer(0.5).timeout


## Suppressive fire: ten rounds raked across everyone in range; nobody is hurt (p174), the ones
## who lose the contest are PINNED and will dive for cover on their turn.
func _anim_suppress(e: Dictionary) -> void:
	var su: Dictionary = enc.units[e.unit]
	var sn: Node3D = unit_nodes[su.id]
	_focus_unit = su.id
	var targets: Array = (e.targets as Array).map(func(i): return enc.units[i])
	var c := Vector3.ZERO
	for t in targets:
		c += _body_pos(t)
	c /= maxf(1.0, targets.size())
	await _frame_pair(_body_pos(su), c)
	var d := Vector2(c.x - _body_pos(su).x, c.z - _body_pos(su).z)
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	sn.set_meta("crouch_goal", 0.0)
	sn.set_meta("aim_at", c + Vector3(0, 0.7, 0))
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 0.0, 1.0, 0.1)
	await get_tree().create_timer(0.2).timeout
	var wid := String(e.weapon)
	var light := _flash_light(su.id)
	for i in 10:
		var t: Dictionary = targets[i % targets.size()]
		var aim := _body_pos(t) + Vector3(fx.rng.randf_range(-0.6, 0.6), fx.rng.randf_range(0.5, 1.1), fx.rng.randf_range(-0.6, 0.6))
		sn.set_meta("aim_at", aim)
		var m0 := _muzzle_of(sn)
		var dir := (aim - m0).normalized()
		fx.muzzle(m0, dir, wid, light, fx.rng.randf() > 0.25)
		fx.brass(m0 - dir * 0.35, dir.cross(Vector3.UP).normalized(), _gy(su.pos))
		var dest := _miss_point(m0, aim)
		fx.bullet(m0, dest, wid, func(): fx.burst(dest, Color("ffd27a"), 4, 2.0, 0.035, 0.2, 1.6))
		_recoil(sn, true)
		_kick(_screen_dir(m0, aim) * -1.0, 1.0)
		await get_tree().create_timer(FIRE_GAP.get(wid, 0.085)).timeout
	await get_tree().create_timer(0.3).timeout
	for t in targets:
		_float(t, "PINNED" if t.id in e.suppressed else "HOLDS", Hud.GOLD if t.id in e.suppressed else Hud.DIM)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 1.0, 0.0, 0.25).set_delay(0.3)
	await get_tree().create_timer(0.6).timeout


## Reinforcements arrive at an entrance: bodies appear there and the camera glances over.
func _anim_backup(e: Dictionary) -> void:
	var first: Dictionary = {}
	for id in e.units:
		var bu: Dictionary = enc.units[id]
		var n := _unit_node(bu)
		n.visible = _seen(bu.pos)
		if first.is_empty():
			first = bu
	hud.toast("%s HAS ARRIVED" % String(e.get("label", "BACKUP")))
	if not first.is_empty() and _seen(first.pos):
		await _pan_to(_body_pos(first), 0.4)
		await get_tree().create_timer(0.6).timeout


## Damage that isn't an attack (Black ICE brain damage, strained injuries): a number and a flash.
func _anim_harm(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	if not _seen(u.pos):
		return
	_float(u, "-%d %s" % [int(e.damage), String(e.source)], Hud.RED)
	_hit_flash(unit_nodes[u.id])
	hud.hit_unit(u.id)
	_hud_refresh()
	if int(e.wound_before) < Combatant.Wound.MORTAL and int(e.wound_after) >= Combatant.Wound.MORTAL:
		_die(u, unit_nodes[u.id], Vector3.FORWARD, enc.units[e.unit].c.dead)


## A per-target attack-like dict from an area hit, for _outcome.
func _area_outcome_event(h: Dictionary) -> Dictionary:
	var t: Dictionary = enc.units[h.id]
	return {"damage": h.damage, "sp_before": t.c.sp("body"), "sp_after": t.c.sp("body"), "crit": false, "crit_names": [],
		"location": "body", "wound_before": h.wound_before, "wound_after": h.wound_after, "killed": h.killed, "dead": h.dead, "hit": true, "dodged": h.dodged}


## Shotgun shell: one blast, pellets fanning into the cone, everyone caught reacts together.
func _anim_shell(e: Dictionary) -> void:
	var su: Dictionary = enc.units[e.unit]
	var tu: Dictionary = enc.units[e.target]
	var sn: Node3D = unit_nodes[su.id]
	_focus_unit = su.id
	await _frame_pair(_body_pos(su), _body_pos(tu))
	var d := Vector2(tu.pos.x - su.pos.x, tu.pos.y - su.pos.y)
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	sn.set_meta("crouch_goal", 0.0)
	sn.set_meta("aim_at", _body_pos(tu) + Vector3(0, 0.7, 0))
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 0.0, 1.0, 0.1)
	await get_tree().create_timer(0.2).timeout
	var m0 := _muzzle_of(sn)
	var dir := (_body_pos(tu) + Vector3(0, 0.7, 0) - m0).normalized()
	fx.muzzle(m0, dir, "shotgun", _flash_light(su.id))
	for k in 9:   # the spread: pellets fanning across the cone
		var spread := dir.rotated(Vector3.UP, fx.rng.randf_range(-0.6, 0.6)).rotated(dir.cross(Vector3.UP).normalized(), fx.rng.randf_range(-0.12, 0.12))
		var dest := m0 + spread * fx.rng.randf_range(4.0, 6.5)
		fx.bullet(m0, dest, "medium_pistol")
	_recoil(sn, false)
	_kick(_screen_dir(m0, m0 + dir) * -1.0, 3.0)
	await get_tree().create_timer(0.12).timeout
	if e.hit:
		for h in e.hits:
			var t: Dictionary = enc.units[h.id]
			if h.dodged:
				_float(t, "DODGE", Hud.CYAN)
				continue
			_outcome(_area_outcome_event(h), su, t, unit_nodes[t.id], _body_pos(t) + Vector3(0, 0.7, 0), (_body_pos(t) - _body_pos(su)).normalized())
	else:
		_float(tu, "MISS", Hud.DIM)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 1.0, 0.0, 0.25).set_delay(0.3)
	await get_tree().create_timer(0.7).timeout


## Grenade: the toss, the arc, the blast (light, fireball, smoke, scorch), damage to everyone caught,
## and broken cover flying apart.
func _anim_blast(e: Dictionary) -> void:
	var su: Dictionary = enc.units[e.unit]
	var sn: CharModel = unit_nodes[su.id]
	var center: Vector3i = e.center
	var at := Vector3(center.x + 0.5, _gy(center), center.y + 0.5)
	_focus_unit = su.id
	await _frame_pair(_body_pos(su), at)
	var d := Vector2(at.x - _body_pos(su).x, at.z - _body_pos(su).z)
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	sn.play_once("grenade", 0.1)
	await get_tree().create_timer(1.15).timeout   # the release in the toss clip
	var hand := sn.head_point() + Vector3(0, 0.1, 0)
	var landed := [false]
	fx.grenade_arc(hand, at + Vector3(0, 0.06, 0), 0.75, func(): landed[0] = true)
	while not landed[0]:
		await get_tree().process_frame
	if not e.hit:
		_float_at(at + Vector3(0, 0.6, 0), "OFF TARGET", Hud.GOLD)
	await get_tree().create_timer(0.25).timeout   # it rattles for a moment
	fx.explosion(at, _gy(center))
	hud.flash_screen(Color(1.0, 0.75, 0.4, 0.25))
	_kick(Vector2(1, -1).normalized(), 8.0)
	_hit_stop(90)
	for v in e.destroyed:
		builder.hide_cover(v)
		var cv: Array = m.cover.filter(func(c): return c.floor == v.z and c.pos == Vector2i(v.x, v.y))
		fx.shatter(Vector3(v.x + 0.5, v.z * FH + 0.3, v.y + 0.5), String(cv[0].material) if not cv.is_empty() else "wood", Vector3(v.x - center.x, 0, v.y - center.y), v.z * FH, true)
	_float_at(at + Vector3(0, 1.0, 0), "%d" % int(e.damage), Hud.GOLD)
	for h in e.hits:
		var t: Dictionary = enc.units[h.id]
		var dir := Vector3(t.pos.x - center.x, 0, t.pos.y - center.y)
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
		if h.dodged:
			_float(t, "DIVES CLEAR", Hud.CYAN)
			continue
		_outcome(_area_outcome_event(h), su, t, unit_nodes[t.id], _body_pos(t) + Vector3(0, 0.5, 0), dir)
	await get_tree().create_timer(1.2).timeout


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
	fx.blood(at, dir, 1.6 if (e.crit or e.killed) else 1.0, _gy(tu.pos))
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
		_die(tu, tn, dir, bool(e.get("dead", true)), String(e.get("location", "body")) == "head")


func _hud_refresh() -> void:
	hud.tool = tool
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


## Death: a death clip picked by where the shot came from (CharModel.die); the weapon drops.
## Mortally Wounded units slump to their knees instead (they can still be stabilised).
func _die(u: Dictionary, n: Node3D, dir: Vector3, dead: bool, head := false) -> void:
	n.set_meta("slump_goal", 1.0)
	if not dead:
		_float(u, "DYING", Hud.RED)
		return
	_float(u, "DOWN", Hud.RED)
	(n as CharModel).die(dir, head)
	await get_tree().create_timer(0.35).timeout   # the model lets the gun fall (CharModel._drop_gun)
	fx.pool(_body_pos(u))
	(decals[u.id] as Node3D).visible = false


func _anim_cover(e: Dictionary) -> void:
	var su: Dictionary = enc.units[e.unit]
	var sn: Node3D = unit_nodes[su.id]
	var cell: Vector3i = e.cell
	var at := Vector3(cell.x + 0.5, cell.z * FH + 0.45, cell.y + 0.5)
	sn.set_meta("aim_at", at)
	sn.set_meta("crouch_goal", 0.0)   # stand to fire: never shoot into the cover you're crouched behind
	_focus_unit = su.id
	var d := Vector2(cell.x - su.pos.x, cell.y - su.pos.y)
	_turn_to(sn, atan2(d.x, d.y), 0.12)
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 0.0, 1.0, 0.1)
	await get_tree().create_timer(0.15).timeout
	var m0 := _muzzle_of(sn)
	var wid := String(e.get("weapon", "assault_rifle"))
	fx.muzzle(m0, (at - m0).normalized(), wid, _flash_light(su.id))
	_recoil(sn, false)
	var left: int = int(e.get("left", 1))   # HP after this shot (later shots in the same playback don't leak back)
	var gone: bool = left <= 0
	var is_cover: bool = e.get("is_cover", false)
	fx.bullet(m0, at, wid, func():
		fx.debris(at, gone)
		if gone:
			if is_cover:
				builder.hide_cover(cell)   # the piece breaks apart: chunks fly and stay on the floor
				var cv: Array = m.cover.filter(func(c): return c.floor == cell.z and c.pos == Vector2i(cell.x, cell.y))
				fx.shatter(Vector3(cell.x + 0.5, cell.z * FH + 0.3, cell.y + 0.5), String(cv[0].material) if not cv.is_empty() else "concrete", (at - m0).normalized(), cell.z * FH, cv.size() > 0 and bool(cv[0].get("thick", false)))
			else:
				_rebuild = true            # a wall gave way: rebuild after playback
		_kick(_screen_dir(m0, at), 4.0 if gone else 1.5)
		_float_at(at + Vector3(0, 0.5, 0), "-%d · %s" % [int(e.damage), "DESTROYED" if gone else "%d HP" % left], Hud.GOLD if gone else Hud.TEXT))
	await get_tree().create_timer(0.45).timeout
	create_tween().tween_method(func(v: float): sn.set_meta("aim", v), 1.0, 0.0, 0.25)


## A Mortally Wounded unit fails its Death Save at the start of its turn (p222): it dies where it
## knelt, toppling backwards.
func _anim_death(e: Dictionary) -> void:
	var u: Dictionary = enc.units[e.unit]
	var n: Node3D = unit_nodes[u.id]
	if not _seen(u.pos) or n.get_meta("fallen", false):
		return
	_focus_unit = u.id
	await _pan_to(_body_pos(u), 0.3)
	_float(u, "DEATH SAVE FAILED", Hud.RED)
	await _die(u, n, -n.global_transform.basis.z, true)
	await get_tree().create_timer(1.2).timeout


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
	# damped spring back to rest, in small sub-steps: one big explicit step is unstable at low
	# frame rates (at 12 fps the offset blew up and threw the view off screen)
	var left := minf(delta, 0.25)
	while left > 0.0:
		var h := minf(left, 1.0 / 240.0)
		left -= h
		_shake_vel += (-_shake_px * 600.0 - _shake_vel * 22.0) * h
		_shake_px += _shake_vel * h
	if _shake_px.length() < 0.05 and _shake_vel.length() < 0.5:
		_shake_px = Vector2.ZERO
		_shake_vel = Vector2.ZERO
	screen.position = _screen_base + _shake_px.round() * _px()


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
	if blast_node and tool != "grenade":
		blast_node.visible = false
	if not _crew_turn():
		hud.tip("", mouse)
		return
	if tool != "":
		_tool_hover()
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
