class_name HazardView
extends Node3D
## The safe boundary of an encounter's hazard zone (HazardZone: the Combat Zone's MIST) on the
## map: a tinted haze over the ground outside the safe circle, a bright line and a low curtain of
## light on its edge, and a dashed line where it closes to next. Before the zone first closes only
## the dashed line shows. update() after every turn; view only.

const GROUND := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec2 center;
uniform float radius = 1e6;
uniform float next_radius = 1e6;
uniform vec4 area = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(0.62, 0.95, 0.35, 0.32);
uniform vec4 edge : source_color = vec4(0.75, 1.0, 0.45, 1.0);
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	if (p.x < area.x || p.y < area.y || p.x > area.x + area.z || p.y > area.y + area.w) {
		discard;
	}
	float d = distance(p, center);
	float a = 0.0;
	vec3 col = tint.rgb;
	if (d > radius) {   // the haze: drifting bands, thicker away from the edge
		float bands = 0.5 + 0.5 * sin(d * 0.9 - TIME * 1.4 + sin(p.x * 0.21 + TIME * 0.3) * 1.6);
		a = tint.a * (0.6 + 0.4 * bands) * clamp((d - radius) / 3.0 + 0.4, 0.0, 1.0);
	}
	float e = 1.0 - smoothstep(0.05, 0.22, abs(d - radius));
	col = mix(col, edge.rgb, e);
	a = max(a, e * edge.a);
	float ang = atan(p.y - center.y, p.x - center.x) * next_radius;
	float n = (1.0 - smoothstep(0.04, 0.14, abs(d - next_radius))) * step(0.45, fract(ang * 0.5));
	col = mix(col, vec3(1.0, 0.95, 0.6), n * (1.0 - e));
	a = max(a, n * 0.85);
	if (a < 0.01) {
		discard;
	}
	ALBEDO = col;
	ALPHA = a;
}
"""

const CURTAIN := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 area = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 edge : source_color = vec4(0.75, 1.0, 0.45, 1.0);
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	if (wpos.x < area.x || wpos.z < area.y || wpos.x > area.x + area.z || wpos.z > area.y + area.w) {
		discard;
	}
	float h = clamp(wpos.y / 2.4, 0.0, 1.0);
	float scan = 0.75 + 0.25 * sin(wpos.y * 9.0 - TIME * 4.0);
	ALBEDO = edge.rgb;
	ALPHA = (1.0 - h) * (1.0 - h) * 0.55 * scan;
}
"""

var _ground: MeshInstance3D
var _curtain: MeshInstance3D
var _gmat: ShaderMaterial
var _cmat: ShaderMaterial


func build(m: TacMap, z: HazardZone) -> void:
	var area := Vector4(z.area.position.x, z.area.position.y, z.area.size.x, z.area.size.y)
	_gmat = ShaderMaterial.new()
	_gmat.shader = Shader.new()
	_gmat.shader.code = GROUND
	_gmat.set_shader_parameter("center", z.center)
	_gmat.set_shader_parameter("area", area)
	var pm := PlaneMesh.new()
	pm.size = Vector2(m.w, m.h)
	_ground = MeshInstance3D.new()
	_ground.mesh = pm
	_ground.material_override = _gmat
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground.position = Vector3(m.w / 2.0, 0.13, m.h / 2.0)
	add_child(_ground)
	_cmat = ShaderMaterial.new()
	_cmat.shader = Shader.new()
	_cmat.shader.code = CURTAIN
	_cmat.set_shader_parameter("area", area)
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 2.4
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 128
	cm.rings = 1
	_curtain = MeshInstance3D.new()
	_curtain.mesh = cm
	_curtain.material_override = _cmat
	_curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_curtain)
	update(z)


func update(z: HazardZone) -> void:
	if _gmat == null or z == null:
		return
	var r := z.radius() if z.stage > 0 else 1e6
	var nr := z.next_radius() if z.stage < z.steps() else 1e6
	_gmat.set_shader_parameter("radius", r)
	_gmat.set_shader_parameter("next_radius", nr)
	_curtain.visible = z.stage > 0
	if z.stage > 0:
		_curtain.scale = Vector3(r, 1.0, r)
		_curtain.position = Vector3(z.center.x, 1.2, z.center.y)


## Where the zone's name goes on the map: the point of the line the player is watching (the safe
## edge once it has closed, else the dashed edge it closes to next) inside the area where it's
## drawn, nearest `near` (the middle of the view). Vector2.INF when none of it is inside the area.
static func tag_point(z: HazardZone, near: Vector2) -> Vector2:
	var r := z.radius() if z.stage > 0 else z.next_radius()
	var area := Rect2(z.area).grow(-1)
	var best := Vector2.INF
	var best_d := INF
	for k in 96:
		var p := z.center + Vector2.RIGHT.rotated(TAU * k / 96.0) * r
		var d := p.distance_to(near)
		if area.has_point(p) and d < best_d:
			best_d = d
			best = p
	return best


## The tag's words: the zone's name on its edge, "NEXT" on the dashed line before it first closes.
static func tag_text(z: HazardZone) -> String:
	return z.name if z.stage > 0 else "%s · NEXT" % z.name
