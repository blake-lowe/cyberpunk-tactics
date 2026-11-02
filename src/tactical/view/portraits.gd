class_name Portraits
extends Node
## Portraits v3 (owner: "more realistically lit 3D, processed with our pixel shader"): each
## character's actual 3D model, head and shoulders, rendered at pixel-art resolution (32×32, shown 2x; small hides imperfections) in a
## small studio: a warm key light from the front left, a strong rim in the team accent from behind,
## a cool fill, and out-of-focus neon "bokeh" behind. The HUD draws the texture nearest-upscaled
## through the same palette post shader as the world (see `material()`), so portraits and the scene
## share one pixel and colour language. Gear and looks come from CharModel/UnitLook, so they match.
## Rendered once (UPDATE_ONCE); wound states are applied by the HUD as tints.

const S := 32

var post_shader: Shader            ## set by the view: the world's palette post shader
var palette: PackedVector3Array    ## and its palette (OKLab)
var palette_neutral_n := 0
var _cache := {}
var _mat: ShaderMaterial


func tex(u: Dictionary, _state := 0) -> Texture2D:
	if _cache.has(u.id):
		return _cache[u.id]
	var vp := SubViewport.new()
	vp.size = Vector2i(S, S)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var model := CharModel.build(u.team, u.id, String(u.c.role), u.c.weapons[0].id() if not u.c.weapons.is_empty() else "assault_rifle")
	var look: Dictionary = model.look
	for mt in model.get_meta("mats", []):
		(mt as ShaderMaterial).set_shader_parameter("use_field", false)
	model.rotation.y = deg_to_rad(-18)
	vp.add_child(model)
	model.pose_still("idle" if u.team == 0 else "rifle_idle", 0.4)   # a calm frame for the bust
	var accent: Color = look.accent
	# backdrop: plain dark (owner: the bokeh was messy)
	var cam := Camera3D.new()
	cam.fov = 26
	vp.add_child(cam)
	var face := model.head_point()   # frame the posed head, whatever the clip and body
	cam.look_at_from_position(face + Vector3(0.02, 0.07, 0.72), face + Vector3(0, -0.03, 0))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -40, 0)
	key.light_energy = 0.8   # softer (owner: lighting too harsh)
	key.light_color = Color("ffe2c4")
	key.light_cull_mask = 0xFFFFF
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.35, 1.05, -0.45)
	rim.omni_range = 1.6
	rim.light_energy = 2.2
	rim.light_color = accent if u.team == 0 else Color("ff3030")
	rim.light_cull_mask = 0xFFFFF
	vp.add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.6, 0.8, 0.4)
	fill.omni_range = 2.0
	fill.light_energy = 1.0
	fill.light_color = Color("6a80c0")
	fill.light_cull_mask = 0xFFFFF
	vp.add_child(fill)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141a26")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2a3248")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	vp.add_child(we)
	_cache[u.id] = vp.get_texture()
	return _cache[u.id]


## Material for drawing portraits: the palette post shader at portrait resolution.
func material() -> ShaderMaterial:
	if _mat == null and post_shader:
		_mat = ShaderMaterial.new()
		_mat.shader = post_shader
		_mat.set_shader_parameter("src_size", Vector2(S, S))
		_mat.set_shader_parameter("palette", palette)
		_mat.set_shader_parameter("palette_n", palette.size())
		_mat.set_shader_parameter("palette_neutral_n", palette_neutral_n)
		_mat.set_shader_parameter("palette_on", true)
		_mat.set_shader_parameter("dither", 0.25)
		_mat.set_shader_parameter("outline", 0.5)
	return _mat


## HUD tint per wound state: 2 Seriously Wounded, 3 Mortally Wounded, 4 dead.
static func tint(state: int) -> Color:
	match state:
		2: return Color(1.0, 0.78, 0.78)
		3: return Color(0.75, 0.45, 0.45)
		4: return Color(0.32, 0.33, 0.36)
	return Color.WHITE
