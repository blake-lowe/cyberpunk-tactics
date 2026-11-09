shader_type spatial;
render_mode cull_disabled, shadows_disabled;
// The city far under a tower band (TowerDress): one plane, the street grid drawn on it. Blocks of
// dark roofs with a few lit skylights, streets lined with lamps (warm sodium, cool LED), wider
// avenues every few blocks with traffic running both ways, brighter and dimmer districts. By day:
// grey roofs and darker roads, no lamps.

uniform vec3 warm : source_color = vec3(1.0, 0.72, 0.38);
uniform vec3 cool : source_color = vec3(0.72, 0.85, 1.0);
uniform vec3 glow_col : source_color = vec3(0.16, 0.13, 0.22);
uniform vec3 roof_col : source_color = vec3(0.05, 0.055, 0.07);
uniform float block = 9.0;
uniform float seed = 0.0;
uniform bool day = false;

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

void fragment() {
	vec2 p = wpos.xz + vec2(seed * 13.0, seed * 7.0);
	vec2 b = p / block;
	vec2 id = floor(b);
	vec2 f = fract(b);
	float fw = max(fwidth(p.x), 1e-3);
	float dist = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * block;   // to the nearest street
	bool along_x = min(f.y, 1.0 - f.y) < min(f.x, 1.0 - f.x);
	float avenue_x = step(mod(id.y + (f.y > 0.5 ? 1.0 : 0.0), 4.0), 0.5);
	float avenue_z = step(mod(id.x + (f.x > 0.5 ? 1.0 : 0.0), 4.0), 0.5);
	float avenue = along_x ? avenue_x : avenue_z;
	float sw = mix(0.7, 1.3, avenue);
	float district = smoothstep(0.25, 0.75, noise(p * 0.018 + 3.0));
	vec3 base = roof_col * (0.8 + 0.5 * hash(id));
	vec3 emit = vec3(0.0);
	if (day) {
		base = mix(vec3(0.34, 0.34, 0.33), vec3(0.42, 0.41, 0.4), hash(id)) * (0.8 + 0.25 * noise(p * 0.3));
		if (dist < sw) base = vec3(0.2, 0.21, 0.22);
	} else {
		if (dist < sw) {
			base = vec3(0.02);
			float t = along_x ? p.x : p.y;
			float off = along_x ? (f.y < 0.5 ? f.y : 1.0 - f.y) : (f.x < 0.5 ? f.x : 1.0 - f.x);
			float lane = off * block;   // across the street, 0 at its middle
			// lamps on both kerbs
			float lamp = step(abs(fract(t / 1.7 + hash(id) * 0.3) - 0.5), 0.16) * step(abs(lane - sw * 0.8), 0.22);
			vec3 lc = hash(vec2(floor(t / 30.0), id.x + id.y)) < 0.7 ? warm : cool;
			emit += lc * lamp * (0.5 + district * 0.9);
			// traffic on the avenues: white one way, red the other
			if (avenue > 0.5) {
				float dir = lane < sw * 0.4 ? 1.0 : -1.0;
				float car = step(abs(fract(t / 2.3 - TIME * 0.35 * dir + hash(id.yx)) - 0.5), 0.12) * step(abs(lane - sw * 0.2), 0.18) * step(0.45, hash(vec2(floor(t / 2.3 - TIME * 0.35 * dir), id.x * 3.0 + dir)));
				emit += mix(vec3(1.0, 0.18, 0.15), vec3(1.0, 0.95, 0.85), step(0.0, dir)) * car * 1.1;
			}
			emit += glow_col * 0.25 * (0.3 + district);
		} else {
			float sky = step(0.965, hash(floor(p * 1.5))) * step(0.15, hash(id + 0.5));
			emit += mix(warm, cool, hash(floor(p * 1.5) + 2.0)) * sky * 0.6 * district;
			emit += glow_col * 0.08 * district;
		}
		// past a pixel per lamp, the grid blurs into its glow
		float fade = smoothstep(0.35, 0.9, fw);
		emit = mix(emit, (warm * 0.08 + glow_col * 0.25) * (0.3 + district), fade);
	}
	ALBEDO = base;
	ROUGHNESS = 0.9;
	EMISSION = emit;
}
