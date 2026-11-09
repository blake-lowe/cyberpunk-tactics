shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A neon tube's glow on the raceway and the air round it (SignLib): a quad along the stroke, its
// light falling off with the distance from the tube (a capsule), in the gas's colour. Per instance
// as neon_tube.gdshader; the quad's height is twice the glow's reach.
#include "res://src/tactical/view/sign_common.gdshaderinc"

varying vec3 wpos;
varying vec4 col;
varying vec4 cus;
varying vec3 out_dir;
varying vec2 qs;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	col = COLOR;
	cus = INSTANCE_CUSTOM;
	out_dir = normalize(MODEL_MATRIX[2].xyz);
	qs = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
}

void fragment() {
	if (sign_cut(wpos, out_dir, VERTEX, SCREEN_UV, VIEWPORT_SIZE)) discard;
	float r = qs.y * 0.5;
	vec2 p = (UV - 0.5) * qs;
	float d = length(vec2(max(abs(p.x) - (qs.x * 0.5 - r), 0.0), p.y)) / r;   // 0 at the tube, 1 at the reach
	float g = exp(-d * 3.2) * (1.0 - smoothstep(0.7, 1.0, d));
	float lit = sign_lit(cus, TIME);
	ALBEDO = col.rgb * g * 0.5 * lit * cus.w * (day ? 0.25 : 1.0) * sign_day(0.05);
}
