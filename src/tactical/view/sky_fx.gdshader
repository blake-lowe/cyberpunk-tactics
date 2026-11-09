shader_type spatial;
render_mode cull_disabled, shadows_disabled;
// Lights round a tower band (TowerDress), one MultiMesh each, colour per instance (COLOR).
// kind 0: a lamp, neon strip or letter; INSTANCE_CUSTOM = (phase, blink rate per second (0: steady),
//         duty, glow): aviation lights blink, landing lights chase.
// kind 1: drone traffic; INSTANCE_CUSTOM = (direction x, direction z, speed, phase): each light
//         flies its lane and wraps round after `lane` units, blinking its nav light.
// kind 2: rain (Atmosphere rain); INSTANCE_CUSTOM = (fall, speed, phase, slant): each streak falls
//         `fall` units from where it stands and starts again, slanting `slant` along +x per unit.
// kind 3: blown dust (Atmosphere dust); as kind 1 (direction, speed, phase) along `lane`, steady.
// kinds 2 and 3 glow at `glow_k`.

uniform int kind = 0;
uniform float lane = 220.0;
uniform float glow_k = 0.6;
uniform bool day = false;
uniform vec2 map_size = vec2(1.0);
uniform float crown_floor = -1.0;   // >= 0: the crown above the band's roof, drawn only while the roof is
uniform bool on_wall = false;       // a sign on the band's own outer wall: kept on the camera side, as the wall is
global uniform float cut_radius;
global uniform vec3 cut_center;
global uniform vec2 cut_dir;
global uniform vec4 focus_view;

varying vec3 wpos;
varying vec4 col;
varying vec4 cus;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (kind == 1 || kind == 3) {
		float t = fract(TIME * INSTANCE_CUSTOM.z / lane + INSTANCE_CUSTOM.w) - 0.5;
		w.xz += INSTANCE_CUSTOM.xy * t * lane;
		w.y += sin(TIME * 0.6 + INSTANCE_CUSTOM.w * 40.0) * (kind == 3 ? 0.8 : 0.25);
		VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
	} else if (kind == 2) {
		float d = fract(TIME * INSTANCE_CUSTOM.y / INSTANCE_CUSTOM.x + INSTANCE_CUSTOM.z) * INSTANCE_CUSTOM.x;
		w.y -= d;
		w.x += d * INSTANCE_CUSTOM.w;
		VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
	}
	wpos = w;
	col = COLOR;
	cus = INSTANCE_CUSTOM;
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[x + y * 4]) + 0.5) / 16.0 - 0.5;
}

void fragment() {
	float bay = bayer4(FRAGCOORD.xy);
	if (crown_floor >= 0.0 && cut_radius > 0.0 && cut_center.y < crown_floor - 0.5) discard;
	if (!on_wall && dot(wpos.xz - cut_center.xz, cut_dir) < -4.0 && wpos.y > 1.2 && wpos.x > -0.5 && wpos.x < map_size.x + 80.0) {
		if (smoothstep(4.0, 9.0, -dot(wpos.xz - cut_center.xz, cut_dir)) > 0.35) discard;
	}
	if (focus_view.w > 0.0 && wpos.y > cut_center.y * 1.6 + 0.9 && -VERTEX.z < focus_view.z - 1.5) {
		float r = length((SCREEN_UV - focus_view.xy) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0)) / focus_view.w;
		if (smoothstep(0.7, 1.0, r) < bay + 0.5) discard;
	}
	float on = 1.0;
	float glow = 1.4;
	if (kind == 0) {
		glow = cus.w;
		if (cus.y > 0.0)
			on = step(fract(TIME * cus.y + cus.x), cus.z);
	} else if (kind == 1) {
		on = 0.35 + 0.65 * step(fract(TIME * 1.3 + cus.w * 7.0), 0.5);
	} else {
		glow = glow_k;
	}
	ALBEDO = glow > 0.0 ? col.rgb * (kind >= 2 && day ? 0.75 : 0.15) : col.rgb;   // glow 0: a plain box in its colour (crown steel, fins); rain and dust pale by day
	ROUGHNESS = 0.7;
	EMISSION = col.rgb * glow * mix(0.06, 1.0, on) * (day ? 0.45 : 1.0);
}
