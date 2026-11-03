class_name AmbientFx
extends Node3D
## Scene ambience from SceneTheme "ambient" (decoration only, never rules): embers drifting over a
## burning district, flames and smoke columns on burning wrecks, steam off the undercity's runoff
## and water dripping from its pipes, dust motes and shafts of light in the arcology atrium.

var _flames: Array = []   ## [MeshInstance3D, base scale, phase]


func build(m: TacMap, kinds: Array, seed_value: int) -> void:
	for ch in get_children():
		ch.queue_free()
	_flames.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 61 + 5
	var mid := Vector3(m.w / 2.0, 0, m.h / 2.0)
	for k in kinds:
		match String(k):
			"embers":
				var p := _particles(mini(700, m.w * m.h / 9), 8.0, _unlit_quad(Color("ffb050"), true))
				p.position = mid + Vector3(0, 1.4, 0)
				p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				p.emission_box_extents = Vector3(m.w / 2.0, 1.4, m.h / 2.0)
				p.direction = Vector3(0.3, 1, 0.1)
				p.spread = 35.0
				p.initial_velocity_min = 0.15
				p.initial_velocity_max = 0.5
				p.gravity = Vector3(0.35, 0.12, 0.12)
				p.scale_amount_min = 0.07
				p.scale_amount_max = 0.14
				p.color_ramp = _ramp([Color("fff0a0", 0.0), Color("ffb050"), Color("ff5a1a"), Color("8a1a0a", 0.0)], [0.0, 0.08, 0.6, 1.0])
			"motes":
				var p := _particles(mini(320, m.w * m.h / 16), 12.0, _unlit_quad(Color("ffffff"), true))
				p.position = mid + Vector3(0, 1.6, 0)
				p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				p.emission_box_extents = Vector3(m.w / 2.0, 1.6, m.h / 2.0)
				p.direction = Vector3(0.2, 0.3, 0.1)
				p.spread = 180.0
				p.initial_velocity_min = 0.02
				p.initial_velocity_max = 0.08
				p.gravity = Vector3(0.02, 0.01, 0.0)
				p.scale_amount_min = 0.05
				p.scale_amount_max = 0.09
				p.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 0.95, 0.95, 0)], [0.0, 0.5, 1.0])
				_shafts(m, rng)
			"steam":
				var spots: Array = []
				for i in 400:
					var v := Vector2i(rng.randi_range(0, m.w - 1), rng.randi_range(0, m.h - 1))
					if m.t(0, v.x, v.y) == TacMap.T.WATER and spots.all(func(q): return q.distance_to(v) > 7):
						spots.append(v)
					if spots.size() >= 9:
						break
				for v in spots:
					var s := _particles(10, 4.5, _soft_quad(Color("c8f0d0")))
					s.position = Vector3(v.x + 0.5, 0.1, v.y + 0.5)
					s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
					s.emission_sphere_radius = 0.6
					s.direction = Vector3.UP
					s.spread = 15.0
					s.initial_velocity_min = 0.2
					s.initial_velocity_max = 0.35
					s.gravity = Vector3(0.04, 0.02, 0)
					s.scale_amount_min = 0.5
					s.scale_amount_max = 0.9
					s.scale_amount_curve = _curve(0.4, 1.0, 2.0)
					s.color_ramp = _ramp([Color(0.8, 1, 0.85, 0), Color(0.8, 1, 0.85, 0.22), Color(0.8, 1, 0.85, 0)], [0.0, 0.3, 1.0])
			"drips":
				var pts := PackedVector3Array()
				for i in 1600:
					var v := Vector2i(rng.randi_range(1, m.w - 2), rng.randi_range(1, m.h - 2))
					if not m.walkable_tile(m.t(0, v.x, v.y)) and m.t(0, v.x, v.y) != TacMap.T.WATER:
						continue
					var by_wall := false
					for d in MapGen.DIRS:
						if m.t(0, v.x + d.x, v.y + d.y) == TacMap.T.WALL:
							by_wall = true
					if by_wall:
						pts.append(Vector3(v.x + rng.randf(), 0, v.y + rng.randf()) - mid)
					if pts.size() >= 160:
						break
				if not pts.is_empty():
					var d := _particles(90, 0.75, _unlit_quad(Color("d0fff0"), false))
					d.position = mid + Vector3(0, 1.45, 0)
					d.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
					d.emission_points = pts
					d.direction = Vector3.DOWN
					d.spread = 0.0
					d.initial_velocity_min = 0.0
					d.initial_velocity_max = 0.2
					d.gravity = Vector3(0, -2.6, 0)
					d.scale_amount_min = 0.04
					d.scale_amount_max = 0.06
					d.color_ramp = _ramp([Color(0.8, 1, 0.95, 0.9), Color(0.8, 1, 0.95, 0.9), Color(0.8, 1, 0.95, 0)], [0.0, 0.85, 1.0])


## A burning wreck or rubble heap: a cluster of flickering flame blobs, sparks and a smoke column.
func flame(at: Vector3, size: float, smoke: bool) -> void:
	# tongues of flame: tapered cones, outer red-orange round a yellow core, each flickering
	var cols := [Color("e8400c"), Color("ff6a14"), Color("ff8a24"), Color("ffb030"), Color("ffe080")]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(at * 10.0))
	for i in 7:
		var core := i >= 5
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := size * (rng.randf_range(0.1, 0.16) if not core else 0.09)
		var h := size * (rng.randf_range(0.45, 0.8) if not core else 0.42)
		cm.top_radius = 0.0
		cm.bottom_radius = r
		cm.height = h
		cm.radial_segments = 5
		cm.rings = 1
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = cols[4] if core else cols[i % 4]
		cm.material = mt
		mi.mesh = cm
		var ang := i * 2.4 + rng.randf()
		var off := Vector3(cos(ang), 0, sin(ang)) * size * (rng.randf_range(0.08, 0.26) if not core else 0.04)
		mi.position = at + off + Vector3(0, h / 2, 0)
		mi.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		add_child(mi)
		_flames.append([mi, Vector3.ONE, rng.randf() * TAU, off])
	var sp := _particles(int(10 * size), 1.6, _unlit_quad(Color("ffd070"), false))
	sp.position = at + Vector3(0, size * 0.4, 0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = size * 0.3
	sp.direction = Vector3.UP
	sp.spread = 25.0
	sp.initial_velocity_min = 1.0
	sp.initial_velocity_max = 2.0
	sp.gravity = Vector3(0.3, -0.4, 0.1)
	sp.scale_amount_min = 0.06
	sp.scale_amount_max = 0.1
	sp.color_ramp = _ramp([Color("fff0a0"), Color("ff8a24"), Color("a02008", 0.0)], [0.0, 0.5, 1.0])
	if smoke:
		var s := _particles(18, 7.0, _soft_quad(Color("ffffff")))
		s.position = at + Vector3(0, size * 0.8, 0)
		s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		s.emission_sphere_radius = size * 0.3
		s.direction = Vector3.UP
		s.spread = 12.0
		s.initial_velocity_min = 0.5
		s.initial_velocity_max = 0.8
		s.gravity = Vector3(0.28, 0.06, 0.12)
		s.scale_amount_min = 0.7 * size
		s.scale_amount_max = 1.0 * size
		s.scale_amount_curve = _curve(0.6, 1.6, 3.2)
		s.color_ramp = _ramp([Color(0.9, 0.42, 0.16, 0), Color(0.62, 0.32, 0.2, 0.5), Color(0.4, 0.34, 0.32, 0.42), Color(0.46, 0.42, 0.4, 0)], [0.0, 0.1, 0.45, 1.0])


func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f in _flames:
		var mi: MeshInstance3D = f[0]
		var ph: float = f[2]
		var s := 1.0 + 0.22 * sin(t * 9.0 + ph) + 0.12 * sin(t * 23.0 + ph * 2.0)
		mi.scale = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))
		mi.rotation.y = t * 0.6 + ph


## Arcology: shafts of light falling from the atrium's roof, slanted, additive and faint.
func _shafts(m: TacMap, rng: RandomNumberGenerator) -> void:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.no_depth_test = false
	mt.albedo_color = Color(1.0, 0.97, 0.94, 0.035)   # r7 review: shafts read as glass slabs at 0.07
	for i in maxi(4, m.w * m.h / 900):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(2.5, 4.5), 16.0, rng.randf_range(2.5, 4.5))
		bm.material = mt
		mi.mesh = bm
		mi.position = Vector3(rng.randf_range(6, m.w - 6), 8.0, rng.randf_range(6, m.h - 6))
		mi.rotation = Vector3(deg_to_rad(14), deg_to_rad(20), 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _particles(n: int, life: float, mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(1, n)
	p.lifetime = life
	p.mesh = mesh
	p.preprocess = life
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Particle sprites: a camera-facing quad (keeps the particle's scale), coloured by the particle's
## colour ramp, round and soft-edged (smoke, steam, motes) or hard (sparks, drips).
const SPRITE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float soft = 1.0;
void vertex() {
	mat4 bb = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = mix(1.0, smoothstep(1.0, 0.15, d), soft);
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = tint.a * COLOR.a * a;
}
"""
static var _sprite: Shader


func _unlit_quad(col: Color, soft: bool) -> QuadMesh:
	if _sprite == null:
		_sprite = Shader.new()
		_sprite.code = SPRITE
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mt := ShaderMaterial.new()
	mt.shader = _sprite
	mt.set_shader_parameter("tint", col)
	mt.set_shader_parameter("soft", 1.0 if soft else 0.0)
	q.material = mt
	return q


func _soft_quad(col: Color) -> QuadMesh:
	return _unlit_quad(col, true)


func _ramp(cols: Array, offs: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	return g


func _curve(a: float, b: float, c: float) -> Curve:
	var cv := Curve.new()
	cv.max_value = maxf(c, 1.0)
	cv.add_point(Vector2(0, a))
	cv.add_point(Vector2(0.5, b))
	cv.add_point(Vector2(1, c))
	return cv
