class_name AimFx
extends Node3D
## The hovered attack's preview drawn in the 3D world (inside the low-res SubViewport, so the post
## shader pixelates it like everything else): a thin scrolling dashed line of fire or throw arc, an
## X where the shot is blocked, and for melee a translucent slice on the floor with a band sweeping
## across it. The shapes come from AimPreview; greybox.gd feeds the points each frame.

const DASH := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
uniform float dash = 0.32;    // world units per dash + gap
uniform float speed = 6.4;    // periods per second, toward the target (owner: twice the first 3.2)
uniform float alpha = 0.6;
void fragment() {
	float f = fract(UV.x / dash - TIME * speed);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * alpha * step(f, 0.55);
}
"""

const TICK := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
"""

const CROSS := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.23, 0.31, 0.85);
void vertex() {   // billboard
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV - 0.5;
	float d = min(abs(p.x - p.y), abs(p.x + p.y));
	ALBEDO = col.rgb;
	ALPHA = col.a * step(d, 0.11) * step(max(abs(p.x), abs(p.y)), 0.45);
}
"""

const SLICE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float reach = 1.0;       // world units (1 square = 2 m)
uniform float half_ang = 0.785;  // 45 degrees each side
uniform float period = 0.6;      // seconds per sweep
varying vec2 lp;
void vertex() { lp = VERTEX.xz; }
void fragment() {
	float r = length(lp);
	float a = atan(lp.x, lp.y);   // 0 = forward (+Z), negative = the attacker's right
	if (r > reach || r < 0.18 || abs(a) > half_ang) { discard; }
	float u = (a + half_ang) / (2.0 * half_ang);   // 0 right .. 1 left: the swing direction
	float t = fract(TIME / period);
	float head = t * 1.35 - 0.15;
	float band = step(u, head) * (1.0 - smoothstep(0.0, 0.3, head - u));
	float fade = 1.0 - smoothstep(0.55, 1.0, t);
	float rim = smoothstep(reach - 0.07, reach, r);
	ALBEDO = col.rgb;
	ALPHA = col.a * (0.16 + 0.2 * rim + band * fade * (0.3 + 0.4 * r / reach));
}
"""

static var _shaders := {}

var _line: MeshInstance3D
var _im: ImmediateMesh
var _cross: MeshInstance3D
var _slice: MeshInstance3D
var _ticks: MeshInstance3D   ## Alt: the range-bracket cross-ticks along the shot line
var _tick_im: ImmediateMesh


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


static func _mat(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(code)
	m.render_priority = 10
	return m


func _init() -> void:
	_im = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _im
	_line.material_override = _mat(DASH)
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.extra_cull_margin = 1000.0
	add_child(_line)
	_cross = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.32)
	_cross.mesh = q
	_cross.material_override = _mat(CROSS)
	_cross.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cross)
	_slice = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.2, 2.2)
	_slice.mesh = pm
	_slice.material_override = _mat(SLICE)
	_slice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_slice)
	_tick_im = ImmediateMesh.new()
	_ticks = MeshInstance3D.new()
	_ticks.mesh = _tick_im
	_ticks.material_override = _mat(TICK)
	_ticks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ticks.extra_cull_margin = 1000.0
	add_child(_ticks)
	clear()


func clear() -> void:
	_im.clear_surfaces()
	_line.visible = false
	_cross.visible = false
	_slice.visible = false
	_tick_im.clear_surfaces()
	_ticks.visible = false


## Short cross-ticks ([position, colour] pairs) across a line running `along`: each `half_len`
## world units either side of it on screen, `width` thick, facing `eye`.
func set_ticks(ticks: Array, eye: Vector3, width: float, half_len: float, along := Vector3.RIGHT) -> void:
	_tick_im.clear_surfaces()
	_ticks.visible = not ticks.is_empty()
	if ticks.is_empty():
		return
	_tick_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for tc in ticks:
		var p: Vector3 = tc[0]
		var col: Color = tc[1]
		var view := (p - eye).normalized()
		var across := along.cross(view).normalized() * half_len   # perpendicular to the line on screen
		var thick := across.cross(view).normalized() * width * 0.5
		var q := [p - across - thick, p + across - thick, p + across + thick, p - across + thick]
		for k in [0, 1, 2, 0, 2, 3]:
			_tick_im.surface_set_color(col)
			_tick_im.surface_add_vertex(q[k])
	_tick_im.surface_end()


## Dashed ribbons along each path ([points, colour] pairs), `width` world units wide, facing `eye`.
## UV.x runs in world units along the path, so the dashes are even and scroll toward the end.
func set_paths(paths: Array, eye: Vector3, width: float) -> void:
	_im.clear_surfaces()
	_line.visible = false
	for pc in paths:
		var pts: PackedVector3Array = pc[0]
		if pts.size() < 2:
			continue
		var col: Color = pc[1]
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var run := 0.0
		for i in pts.size():
			var p := pts[i]
			if i > 0:
				run += p.distance_to(pts[i - 1])
			var tan := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var side := tan.cross((p - eye).normalized()).normalized() * width * 0.5
			for s in [-1.0, 1.0]:
				_im.surface_set_color(col)
				_im.surface_set_uv(Vector2(run, 0.5 + s * 0.5))
				_im.surface_add_vertex(p + side * s)
		_im.surface_end()
		_line.visible = true


func set_cross(on: bool, at := Vector3.ZERO) -> void:
	_cross.visible = on
	_cross.position = at


## The melee slice: on the floor at `at`, pointing along `yaw` (the facing convention of units).
func set_slice(on: bool, at := Vector3.ZERO, yaw := 0.0, col := Color.WHITE, reach := 1.0) -> void:
	_slice.visible = on
	if on:
		_slice.position = at
		_slice.rotation = Vector3(0, yaw, 0)
		(_slice.material_override as ShaderMaterial).set_shader_parameter("col", col)
		(_slice.material_override as ShaderMaterial).set_shader_parameter("reach", reach)
