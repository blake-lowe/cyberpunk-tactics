shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
// A neon tube (SignLib): a thin cylinder along one stroke, white-hot down the middle where it faces
// the eye and its colour at the edges; dark glass when it's off. Per instance: COLOR the gas's
// colour, INSTANCE_CUSTOM (phase, anim, rate, energy) (sign_common sign_lit). The instance basis'
// z axis is the sign's facing.
#include "res://src/tactical/view/sign_common.gdshaderinc"

varying vec3 wpos;
varying vec4 col;
varying vec4 cus;
varying vec3 out_dir;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	col = COLOR;
	cus = INSTANCE_CUSTOM;
	out_dir = normalize(MODEL_MATRIX[2].xyz);
}

void fragment() {
	if (sign_cut(wpos, out_dir, VERTEX, SCREEN_UV, VIEWPORT_SIZE)) discard;
	float lit = sign_lit(cus, TIME);
	float face = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = pow(face, 3.0);
	vec3 on = mix(col.rgb, vec3(1.0, 0.97, 0.94), core * 0.55) * (0.75 + 0.4 * face) * cus.w;
	vec3 off = col.rgb * 0.07 + vec3(0.035) + vec3(0.12) * pow(face, 8.0);   // dead glass catches a little light
	ALBEDO = mix(off, mix(off, on, sign_day(0.3)), lit) * (day ? 0.6 : 1.0);
}
