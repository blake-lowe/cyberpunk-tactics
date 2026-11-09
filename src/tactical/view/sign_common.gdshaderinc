// Shared by the sign library's shaders (neon_tube, neon_halo; SignLib): when a sign is off, and
// when it gives way to the camera, the way the building it hangs on does (world.gdshader).
// place 0: on a street facade or a roof's edge (goes with its building in the XCOM cutaway);
// place 1 (the default): out over the city (the camera-side skyline dissolves, as world.gdshader mode 2).
global uniform vec3 cut_center;
global uniform float cut_radius;
global uniform vec2 cut_dir;
global uniform vec4 focus_view;
global uniform sampler2D cut_map : filter_nearest, repeat_disable;
global uniform float day_factor;   // the campaign hour's daylight (project.godot): 0 night, 0.6 dawn/dusk, 1 day
uniform int place = 1;
uniform vec2 map_size = vec2(1.0);
uniform bool day = false;

// How much of a sign's light shows in daylight: neon tubes fade to a faint glow by day, their halo
// and the holo screens nearly go (owner: night stays as it was, day_factor 0).
float sign_day(float keep) { return mix(1.0, keep, clamp(day_factor, 0.0, 1.0)); }

float sign_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// How lit a tube or letter is now (0..1). cus: (phase, anim, rate, energy); anim 0 steady,
// 1 flicker (drops out now and then), 2 dead (the broken letter), 3 sputter, 4 chase, 5 buzz.
float sign_lit(vec4 cus, float t) {
	int a = int(cus.y + 0.5);
	float ph = cus.x;
	if (a == 2) return 0.0;
	if (a == 1) {
		float slot = floor(t * 9.0);
		float off = step(0.93, sign_hash(vec2(slot, ph * 13.0))) + step(0.85, sign_hash(vec2(floor(t * 0.4), ph))) * step(0.5, fract(t * 7.0 + ph));
		return 1.0 - 0.88 * min(off, 1.0);
	}
	if (a == 3) {
		float s = sign_hash(vec2(floor(t * 14.0), ph * 7.0));
		return step(0.45, s) * (0.6 + 0.4 * s) * step(0.3, sign_hash(vec2(floor(t * 0.7), ph)));
	}
	if (a == 4) return step(fract(ph - t * max(cus.z, 0.1)), 0.34) * 0.9 + 0.1;
	if (a == 5) return 0.86 + 0.14 * sin(t * 60.0 + ph * 6.0) - 0.5 * step(0.985, sign_hash(vec2(floor(t * 20.0), ph)));
	return 1.0;
}

// Whether this fragment of a sign is cut away. out: the sign's facing (into the street).
bool sign_cut(vec3 wpos, vec3 out_dir, vec3 view_pos, vec2 screen_uv, vec2 vsize) {
	if (place == 1) {
		if (dot(wpos.xz - cut_center.xz, cut_dir) < -4.0 && wpos.y > 1.2 && wpos.x > -0.5 && wpos.x < map_size.x + 80.0)
			return true;
		return false;
	}
	vec2 c = wpos.xz - out_dir.xz * 0.45;   // the wall square behind the sign
	ivec2 sq = ivec2(floor(c));
	vec4 cm = (sq.x >= 0 && sq.y >= 0 && float(sq.x) < map_size.x && float(sq.y) < map_size.y) ? texelFetch(cut_map, sq, 0) : vec4(-1.0);
	bool cut_open = cm.r > -0.5;
	if (cut_radius > 0.0 && cut_open) {
		float fl = floor((wpos.y + 0.02) / 1.6);
		if (fl > cm.r + 0.5) return true;
		if (fl > cm.r - 0.5 && wpos.y - fl * 1.6 > 0.72) {
			vec2 lo = vec2(mod(cm.g, 1024.0), mod(cm.b, 1024.0));
			vec2 hi = vec2(floor(cm.g / 1024.0), floor(cm.b / 1024.0)) + 1.0;
			vec2 piv = clamp(cut_center.xz, lo + 1.5, max(hi - 1.5, lo + 1.5));
			if (dot(c - piv, cut_dir) < 0.0) return true;
		}
	}
	// (no see-through hole: like the walls they hang on, only the roofs dissolve there)
	return false;
}
