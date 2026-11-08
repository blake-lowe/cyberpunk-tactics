class_name JackLines
extends Node3D
## A Netrunner's idle turn (owner: make access points easy to find): thin translucent cyan lines
## from the runner to every access point they have seen and could reach and jack in at this turn
## (AccessPoints.in_reach), with small data packets flowing out along them. Drawn in the 3D world
## inside the low-res SubViewport, so the post shader pixelates them like AimFx's line of fire.

const LINE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
uniform float period = 1.1;   // world units between packets
uniform float speed = 0.9;    // periods per second, from the runner out to the port
uniform float base = 0.32;    // the line itself: faint
uniform float packet = 0.68;  // a packet: bright
void fragment() {
	float f = fract(UV.x / period - TIME * speed);
	float p = step(f, 0.22) * (1.0 - 0.5 * f / 0.22);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * (base + packet * p);
}
"""

const COL := Color("39d8ff")

var _im := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var lines := 0   ## lines drawn now (tests, review renders)


func _init() -> void:
	_mi.mesh = _im
	var sh := Shader.new()
	sh.code = LINE
	var mt := ShaderMaterial.new()
	mt.shader = sh
	mt.render_priority = 10   # over the floor's own transparent layers, like AimFx
	_mi.material_override = mt
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 1000.0
	add_child(_mi)
	visible = false


## Draw a line from `from` to each of `to` (world points), `width` world units wide facing `eye`.
## Empty `to` hides them.
func set_lines(from: Vector3, to: Array, eye: Vector3, width: float) -> void:
	_im.clear_surfaces()
	lines = 0
	visible = not to.is_empty()
	for b in to:
		var tgt: Vector3 = b
		var seg := tgt - from
		if seg.length() < 0.5:
			continue
		var n := maxi(2, int(seg.length() / 0.5))
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n + 1:
			var p := from + seg * (float(i) / n)
			var side := seg.normalized().cross((p - eye).normalized()).normalized() * width * 0.5
			for s in [-1.0, 1.0]:
				_im.surface_set_color(Color(COL, 0.9))
				_im.surface_set_uv(Vector2(seg.length() * float(i) / n, 0.5 + s * 0.5))
				_im.surface_add_vertex(p + side * s)
		_im.surface_end()
		lines += 1
