class_name Portraits
extends Node
## Renders a head-and-shoulders bust of each unit's model once into a small texture, for the HUD
## (party cards, initiative strip). Each bust lives in its own SubViewport set to render once,
## lit with a key light and a rim light in the unit's team colour.

var _cache := {}


func tex(u: Dictionary) -> Texture2D:
	if _cache.has(u.id):
		return _cache[u.id]
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 96)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var model := UnitModel.build(u.team, u.id if u.team == 0 else 0)
	model.rotation.y = deg_to_rad(-25)
	vp.add_child(model)
	var cam := Camera3D.new()
	cam.fov = 28
	cam.position = Vector3(0.06, 0.86, 0.46)
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.79, 0))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, -35, 0)
	key.light_energy = 1.4
	key.light_color = Color("ffe8d0")
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.3, 0.95, -0.4)
	rim.omni_range = 1.5
	rim.light_energy = 4.0
	rim.light_color = UnitModel.CREW_ACCENTS[u.id % 4] if u.team == 0 else Color("ff3030")
	vp.add_child(rim)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("404858")
	env.ambient_light_energy = 0.6
	we.environment = env
	vp.add_child(we)
	_cache[u.id] = vp.get_texture()
	return _cache[u.id]
