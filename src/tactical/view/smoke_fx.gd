class_name SmokeFx
extends AmbientFx
## Smoke grenades' clouds in the tactical view (decoration only: the rules are Smoke's). A cloud is
## two soft sheets of drifting haze over exactly its squares (a mask texture, so it hugs the walls that
## stopped it: from the top-down camera the area reads at a glance) and a few slow puffs rolling over
## them on a light breeze. No light, no glow, no ring: cool greys from the palette's neutrals, unlit.
## A cloud billows in when the grenade pops (add) and thins out when its minute is up (sync drops it).
## Cheap: two quads and one small particle node a cloud.

const PUFF := Color(0.7, 0.74, 0.8)
const BREEZE := Vector3(0.12, 0.0, 0.05)   ## m/s²: a slow drift, the same way for every cloud
## Sheet heights over the floor (squares) and their opacity: one at the knee, one at the chest.
const SHEETS := [[0.25, 0.58], [0.85, 0.4]]

const HAZE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(0.78, 0.81, 0.86, 0.6);
uniform vec2 extent = vec2(7.0);
uniform vec2 drift = vec2(0.12, 0.05);
uniform float seed = 0.0;
uniform float fade = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	float m = texture(mask, UV).r;
	vec2 p = UV * extent + TIME * drift + seed;
	float n = noise(p * 0.8) * 0.6 + noise(p * 2.3 + 7.0) * 0.4;
	ALBEDO = tint.rgb * (0.85 + 0.25 * n);
	ALPHA = tint.a * fade * smoothstep(0.08, 0.7, m) * (0.45 + 0.55 * n);
}
"""
static var _haze: Shader

var _clouds := {}   ## cloud id → Node3D


## Show `cloud` (Smoke.add's dictionary) standing on floor height `gy`. `billow`: the grenade just
## popped, so it rolls out over a second; otherwise it's simply there (a reload, a rebuilt world).
func add(cloud: Dictionary, gy: float, billow := false) -> void:
	var id := int(cloud.id)
	if _clouds.has(id):
		return
	if _haze == null:
		_haze = Shader.new()
		_haze.code = HAZE
	var c: Vector3i = cloud.center
	var lo := Vector2i(c.x, c.y)
	var hi := lo
	for v: Vector3i in cloud.cells:
		lo = Vector2i(mini(lo.x, v.x), mini(lo.y, v.y))
		hi = Vector2i(maxi(hi.x, v.x), maxi(hi.y, v.y))
	var size := hi - lo + Vector2i(3, 3)   # a square of empty mask round it: soft edges
	var img := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	for v: Vector3i in cloud.cells:
		img.set_pixel(v.x - lo.x + 1, v.y - lo.y + 1, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	var root := Node3D.new()
	root.position = Vector3(lo.x - 1 + size.x / 2.0, gy, lo.y - 1 + size.y / 2.0)
	add_child(root)
	_clouds[id] = root
	for i in SHEETS.size():
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(size.x, size.y)
		var mt := ShaderMaterial.new()
		mt.shader = _haze
		mt.set_shader_parameter("mask", tex)
		mt.set_shader_parameter("tint", Color(PUFF, float(SHEETS[i][1])))
		mt.set_shader_parameter("extent", Vector2(size))
		mt.set_shader_parameter("seed", float(id * 13 + i * 5))
		mt.set_shader_parameter("drift", Vector2(BREEZE.x, BREEZE.z) * (1.0 + i * 0.6))
		mt.set_shader_parameter("fade", 0.0 if billow else 1.0)
		pm.material = mt
		mi.mesh = pm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = float(SHEETS[i][0])
		root.add_child(mi)
		if billow:
			create_tween().tween_method(func(f: float): mt.set_shader_parameter("fade", f), 0.0, 1.0, 1.0 + i * 0.4)
	var pts := PackedVector3Array()
	for v: Vector3i in cloud.cells:
		pts.append(Vector3(v.x + 0.5, gy, v.y + 0.5))
	var p := _particles(maxi(8, pts.size()), 6.0, _soft_quad(PUFF))
	remove_child(p)
	root.add_child(p)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	p.top_level = true   # the points are in the world
	p.position = Vector3(0, 0.6, 0)
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.gravity = BREEZE
	p.scale_amount_min = 1.2
	p.scale_amount_max = 1.9
	p.scale_amount_curve = _curve(0.7, 1.0, 1.3)
	p.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 0.4), Color(0.92, 0.94, 0.96, 0.32), Color(0.9, 0.92, 0.95, 0)], [0.0, 0.25, 0.7, 1.0])
	if billow:
		p.preprocess = 0.0
		p.speed_scale = 4.0
		create_tween().tween_property(p, "speed_scale", 1.0, 1.2).set_delay(0.4)


## Keep the view's clouds to the encounter's: clouds gone clear away (thin out, then freed); clouds
## not shown yet appear, except those in `pending` (their grenade is still in the air: add billows
## them in when it lands). `gy` gives a cloud's floor height, `shows` whether its floor is drawn.
func sync(clouds: Array, gy: Callable, shows: Callable, pending := {}) -> void:
	var live := {}
	for cl in clouds:
		live[int(cl.id)] = true
		if not _clouds.has(int(cl.id)) and not pending.has(int(cl.id)):
			add(cl, float(gy.call(cl.center)))
		if _clouds.has(int(cl.id)):
			(_clouds[int(cl.id)] as Node3D).visible = bool(shows.call(cl.center))
	for id in _clouds.keys():
		if not live.has(id):
			clear_cloud(int(id))


## The minute is up: the sheets thin out, the puffs stop, and the cloud is freed once they've faded.
func clear_cloud(id: int) -> void:
	if not _clouds.has(id):
		return
	var root: Node3D = _clouds[id]
	_clouds.erase(id)
	if not is_inside_tree():
		root.queue_free()
		return
	for ch in root.get_children():
		if ch is CPUParticles3D:
			(ch as CPUParticles3D).emitting = false
		elif ch is MeshInstance3D:
			var mt := ((ch as MeshInstance3D).mesh as PlaneMesh).material as ShaderMaterial
			create_tween().tween_method(func(f: float): mt.set_shader_parameter("fade", f), 1.0, 0.0, 2.5)
	get_tree().create_timer(6.0).timeout.connect(root.queue_free)


## The clouds on show (cloud ids).
func shown() -> Array:
	return _clouds.keys()
