shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// A layer of smog under a tower band (TowerDress): drifting, patchy, lit from below by the city
// (warmer and pinker over the bright districts). Several layers, each a little thicker, fade the
// facade out storey by storey (the owner's fog: kept as it was, given some body).

uniform vec3 smog : source_color = vec3(0.16, 0.13, 0.22);
uniform vec3 lit_a : source_color = vec3(0.42, 0.2, 0.36);
uniform vec3 lit_b : source_color = vec3(0.48, 0.3, 0.16);
uniform float alpha = 0.12;
uniform float glow = 0.35;
uniform float drift = 0.4;
uniform float seed = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.5 + noise(p * 2.03) * 0.3 + noise(p * 4.1) * 0.2; }

void fragment() {
	vec2 p = wpos.xz * 0.035 + vec2(TIME * 0.01 * drift, TIME * 0.006 * drift) + seed;
	float d = fbm(p);
	float patch = smoothstep(0.3, 0.75, fbm(wpos.xz * 0.012 + seed * 1.7));
	vec3 lit = mix(lit_a, lit_b, smoothstep(0.35, 0.65, noise(wpos.xz * 0.008 + 5.0)));
	ALBEDO = smog * (0.55 + 0.35 * d) + lit * glow * patch * patch * (0.3 + 0.7 * d);
	ALPHA = clamp(alpha * (0.55 + 0.9 * d), 0.0, 1.0);
}
