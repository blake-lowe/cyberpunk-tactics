shader_type spatial;
render_mode cull_disabled;
// Everything built by WorldBuilder: lit surface with an off-grid procedural pattern, fog of war
// from a per-cell texture (bilinear, so fog edges are soft rather than square), and an XCOM-style
// radial cutaway around the focus point.
// fog texture: one row block per floor (h rows each); value 0 unknown, ~0.5 explored, 1 visible.
// mode 0: surface (hidden when unknown); 1: unknown interior (hologram, shown only when unknown);
// 2: no fog. `shell`: exterior surfaces never fog out (building shells are always known, XCOM-style).
// lightfield: baked RGB light spill per floor (4 texels per square), blocked by walls; it adds
// colour where the compatibility renderer's per-mesh light limit would drop real lights.
// pattern: 0 plain, 1 tiles, 2 planks, 3 asphalt, 4 slabs, 5 earth, 6 grating, 7 panels,
//          8 corrugated, 9 tower windows, 10 water, 11 brick

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 albedo2 : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform int pattern = 0;
uniform float pattern_scale = 1.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform sampler2D fog : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(1.0);
uniform float floor_idx = 0.0;
uniform float floors = 1.0;
uniform int mode = 0;
uniform float explored_dim = 0.6;
uniform float fog_sat = 0.3;        // colour kept in explored-but-unseen areas (1 = full colour)
uniform float fog_cool = 1.0;       // 1: unseen areas shift blue (night scenes); 0: same hue, just dimmer
uniform bool cuttable = false;
uniform bool shell = false;
uniform sampler2D lightfield : filter_linear, repeat_disable;
uniform float spill = 0.9;
global uniform vec3 cut_center;     // xz focus, y = viewed floor index
global uniform float cut_radius;    // 0 = no cutaway
global uniform vec2 cut_dir;        // camera forward on the ground plane
global uniform vec4 focus_view;     // focus in screen UV (xy), its view depth (z), hole radius (w)
uniform bool flat_shade = false;    // faceted lighting (rocks)
uniform bool offmap = false;        // ground beyond the map: fades out with distance
uniform bool near_fade = false;
uniform bool dry = false;
uniform bool soft_light = false;    // bright scenes (arcology): no hard banding of light pools           // no puddles (roofs: their specular read as white streaks)     // tall surroundings on every side (arcology walls) dissolve on the camera side
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;   // imported models (nature kit)
uniform float tex_mix = 0.0;        // 1: the model's own texture (tinted by albedo) replaces the pattern

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.62 + noise(p * 2.13) * 0.38; }  // no sub-pixel octave
float bayer4(vec2 p) {  // ordered dither, -0.5..0.5
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[x + y * 4]) + 0.5) / 16.0 - 0.5;
}
float line(float x, float w) { float d = abs(fract(x) - 0.5); return smoothstep(0.5 - w, 0.5, d); }

void fragment() {
	vec2 uvbase;
	{
		vec2 c = wpos.xz - wnorm.xz * 0.08;   // sample just inside the surface
		uvbase = vec2(c.x / map_size.x, (floor_idx * map_size.y + clamp(c.y, 0.5, map_size.y - 0.5)) / (map_size.y * floors));
	}
	vec2 fogv = texture(fog, uvbase).rg;
	float bay = bayer4(FRAGCOORD.xy);
	// --- see-through hole: tall things between the camera and the focus (skyline, buildings that
	// haven't been opened) dissolve in a dithered disc around the focus (BG3/Divinity style)
	// camera-side skyline dissolves entirely above street level
	if (mode == 2 && dot(wpos.xz - cut_center.xz, cut_dir) < -4.0 && wpos.y > 1.2 && (near_fade || (wpos.x > -0.5 && wpos.x < map_size.x + 80.0))) {
		float far = smoothstep(4.0, 9.0, -dot(wpos.xz - cut_center.xz, cut_dir));
		if (far > (emission_energy > 0.9 ? 0.35 : bay + 0.5)) discard;   // glowing strips go cleanly (dithered they left dotted lines)
	}
	if ((mode == 2 || (shell && fogv.g < 0.5)) && focus_view.w > 0.0 && wpos.y > cut_center.y * 1.6 + 0.9 && -VERTEX.z < focus_view.z - 1.5) {
		float r = length((SCREEN_UV - focus_view.xy) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0)) / focus_view.w;
		if (smoothstep(0.7, 1.0, r) < bay + 0.5) discard;
	}
	// --- cutaway (XCOM roof-off): in buildings the crew is in or has seen into (fog G), every
	// storey above the viewed one goes, and walls on the camera side of the focus drop to waist
	// height with a dithered edge. Far walls stay up for context. Cut faces show as section caps.
	if (cut_radius > 0.0 && fogv.g > 0.5) {
		if (floor_idx > cut_center.y + 0.5) discard;
		if (cuttable && floor_idx > cut_center.y - 0.5 && wpos.y - floor_idx * 1.6 > 0.72) {
			float along = dot(wpos.xz - cut_center.xz, cut_dir);
			if (smoothstep(-0.12, 0.12, along) < bay + 0.5) discard;
		}
	}
	// --- fog of war: dithered frontier; explored-but-unseen is dimmer, cooler, with lights low
	float f = mode != 2 ? fogv.r : 1.0;
	if (shell) f = 1.0;   // building exteriors are always known and drawn at full value (XCOM-style)
	if (mode == 0 && f < 0.15 + 0.14 * (bay + 0.5)) discard;
	if (mode == 1 && f >= 0.22) discard;
	float vis = smoothstep(0.55, 0.9, f);
	float k = mode == 0 ? mix(explored_dim, 1.0, vis) : 1.0;

	// --- pattern: floors use xz, walls use (along-wall, height)
	bool up = abs(wnorm.y) > 0.5;
	vec2 p = (up ? wpos.xz : vec2(wpos.x + wpos.z, wpos.y)) * pattern_scale;
	float local_h = wpos.y - floor_idx * 1.6;
	vec3 base = albedo.rgb;
	float rough = roughness;
	float wet = 0.0;
	float n = fbm(p * 3.0);
	vec3 emit = emission * emission_energy;
	if (pattern == 0) {
		base *= 0.9 + n * 0.2;
	} else if (pattern == 1) {            // tiles with grout
		float g = max(line(p.x, 0.04), line(p.y, 0.04));
		base = mix(base * (0.92 + hash(floor(p)) * 0.16), albedo2.rgb, g);
		rough = mix(rough, 0.9, g);
	} else if (pattern == 2) {            // planks, staggered
		float row = floor(p.y * 3.0);
		float x = p.x * 0.7 + hash(vec2(row, 1.0)) * 3.0;
		base *= 0.85 + hash(vec2(row, floor(x))) * 0.25 + noise(vec2(p.x * 4.0, row)) * 0.08;
		base = mix(base, albedo2.rgb, max(line(p.y * 3.0, 0.05), line(x, 0.015)));
	} else if (pattern == 3) {            // asphalt: aggregate (faded when sub-pixel), puddles
		float aa = 1.0 - smoothstep(0.4, 0.9, fwidth(p.x) * 10.0);
		float speck = hash(floor(p * 10.0)) * aa;
		base *= 0.85 + n * 0.3 + speck * 0.08;
		float pud = smoothstep(0.72, 0.76, fbm(p * 0.9 + 7.0)) * (dry ? 0.0 : 1.0);   // r7 review: 1-2 square puddles
		rough = mix(rough, 0.45, pud);
		wet = pud;
	} else if (pattern == 4) {            // slabs (sidewalk, roof membrane), offset rows
		vec2 q = vec2(p.x + floor(p.y) * 0.5, p.y);
		float g = max(line(q.x, 0.03), line(q.y, 0.03));
		base *= 0.9 + hash(floor(q)) * 0.15 + n * 0.08;
		base = mix(base, albedo2.rgb, g);
		float pud = smoothstep(0.75, 0.78, fbm(p * 1.1 + 3.0)) * (dry ? 0.0 : 1.0);
		rough = mix(rough, 0.45, pud);
		wet = pud;
	} else if (pattern == 5) {            // earth / grass / sand: two-colour noise
		base = mix(albedo.rgb, albedo2.rgb, smoothstep(0.45, 0.6, fbm(p * 1.3)));
		base *= 0.82 + 0.36 * noise(p * 0.12 + 11.0);   // broad drifts of lighter and darker ground
		float aa5 = 1.0 - smoothstep(0.4, 0.9, fwidth(p.x) * 25.0);
		base *= 0.9 + hash(floor(p * 25.0)) * 0.15 * aa5;
	} else if (pattern == 6) {            // grating
		float g = line(p.x * 4.0, 0.25);
		base = mix(base, albedo2.rgb, g);
	} else if (pattern == 7) {            // facade panels and floor seams
		float g = max(line(p.x * 0.75, 0.012), line(p.y * 0.625 + 0.5, 0.02));
		base *= 0.88 + hash(floor(vec2(p.x * 0.75, p.y * 0.625))) * 0.12 + n * 0.08;
		base = mix(base, albedo2.rgb, g);
		base *= 1.0 - smoothstep(0.55, 0.9, noise(vec2(p.x * 6.0, p.y * 0.3))) * 0.18;   // grime streaks
	} else if (pattern == 8) {            // corrugated metal
		float r = sin(p.x * 12.0) * 0.5 + 0.5;
		base *= 0.8 + r * 0.25 + n * 0.1;
	} else if (pattern == 9) {            // distant towers: lit windows
		vec2 w = vec2(p.x * 2.2, p.y * 1.6);
		vec2 cell = floor(w);
		vec2 fr = fract(w);
		float win = step(0.18, fr.x) * step(fr.x, 0.82) * step(0.25, fr.y) * step(fr.y, 0.8);
		float lit = step(0.8, hash(cell + floor(wpos.xz * 0.05)));
		vec3 wc = mix(vec3(1.0, 0.72, 0.45), vec3(0.55, 0.85, 1.0), hash(cell * 1.7));
		base *= 0.7 + n * 0.3;
		emit += wc * win * lit * 0.6 * (up ? 0.0 : 1.0);
	} else if (pattern == 10) {           // water: dark, glossy, slow ripples
		float r = noise(p * 2.0 + vec2(TIME * 0.15, TIME * 0.1));
		base *= 0.9 + r * 0.12;
		rough = 0.22 + r * 0.1;
		float caust = smoothstep(0.6, 0.82, noise(p * vec2(5.5, 7.0) - vec2(TIME * 0.3, TIME * 0.08)));   // glowing water: brighter ripples
		emit *= 0.6 + r * 0.15 + caust * 0.22;
	} else if (pattern == 11) {           // brick: running-bond courses, mortar joints (set pieces)
		vec2 q = vec2(p.x * 2.6, p.y * 5.0);
		q.x += step(1.0, mod(floor(q.y), 2.0)) * 0.5;
		float g = max(line(q.y, 0.08), line(q.x, 0.04));
		base *= 0.82 + hash(floor(q)) * 0.3 + n * 0.06;
		base = mix(base, albedo2.rgb, g);
	}
	if (tex_mix > 0.0) base = mix(base, texture(tex, UV).rgb * albedo.rgb, tex_mix);
	// --- grounding: contact darkening at wall/prop bases, a light edge on top faces
	if (mode != 2) {
		if (!up) base *= mix(0.6, 1.0, smoothstep(0.0, 0.6, local_h));
		else if (local_h > 0.2) base *= 1.4;
	}
	if (offmap) {   // beyond the map reads like explored-but-unseen ground, then fades with distance
		float od = length(max(abs(wpos.xz - map_size * 0.5) - map_size * 0.5, 0.0));
		float lo = dot(base, vec3(0.3, 0.59, 0.11));
		base = mix(vec3(lo), base, fog_sat) * explored_dim * mix(vec3(1.0), vec3(0.8, 0.9, 1.15), fog_cool);
		base *= mix(1.0, 0.55, smoothstep(0.0, 60.0, od));
	}
	// --- baked light spill (rgb) and contact occlusion (a): walls sample the space they face
	vec2 lfo = up ? vec2(0.0) : wnorm.xz * 0.35;
	vec2 luv = uvbase + vec2(lfo.x / map_size.x, lfo.y / (map_size.y * floors));
	vec2 t = vec2(0.25 / map_size.x, 0.25 / (map_size.y * floors));
	vec4 lfs = (texture(lightfield, luv) * 2.0 + texture(lightfield, luv + vec2(t.x, 0)) + texture(lightfield, luv - vec2(t.x, 0))
		+ texture(lightfield, luv + vec2(0, t.y)) + texture(lightfield, luv - vec2(0, t.y))) / 6.0;
	vec3 lf = lfs.rgb;
	if (up && local_h < 0.2 && mode != 2) base *= 1.0 - 0.45 * clamp(lfs.a, 0.0, 1.0);
	if (!up) lf *= 1.0 - 0.45 * clamp(local_h / 1.6, 0.0, 1.0);
	float pk = max(lf.r, max(lf.g, lf.b));
	lf *= 1.0 / (1.0 + pk * 0.6);   // soft knee: pools keep their hue instead of clipping white
	pk = max(lf.r, max(lf.g, lf.b));
	float lq = soft_light ? pk : floor(pk * 4.0 + 0.5 + bay * 0.6) / 4.0;   // hard pixel-art light bands (soft on bright scenes: bands read as cut-outs)
	lf *= lq / max(pk, 1e-3);
	pk = lq;
	base *= 1.0 - 0.12 * wet;   // puddles: a little darker, a thin saturated reflection (no ink holes)
	vec3 sb = max(base, vec3(0.045));   // spill must show on near-black asphalt too
	emit += sb * lf * spill * (1.0 - wet * 0.25) + (lf / max(pk, 1e-3)) * min(pk, 0.6) * wet * 0.12;
	if (lq >= 0.75) emit += (lf / max(pk, 1e-3)) * 0.12;   // hot core: pools have a coloured centre
	if (k < 1.0) {
		float l = dot(base, vec3(0.3, 0.59, 0.11));
		base = mix(vec3(l), base, mix(fog_sat, 1.0, vis)) * k * mix(mix(vec3(1.0), vec3(0.8, 0.9, 1.15), fog_cool), vec3(1.0), vis);
		emit *= mix(mix(0.4, 0.85, 1.0 - fog_cool), 1.0, vis);
	}
	if (flat_shade) NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metallic;
	EMISSION = emit;
	if (mode == 1) {  // unknown interior: slate with a 45-degree screen hatch and a neutral frontier
		float hatch = step(3.0, mod(FRAGCOORD.x + FRAGCOORD.y, 4.0));
		float edge = smoothstep(0.04, 0.2, fogv.r) * (1.0 - smoothstep(0.2, 0.22, fogv.r));
		ALBEDO = vec3(0.012, 0.018, 0.03);
		EMISSION = vec3(0.016, 0.02, 0.032) * (1.0 + hatch * 1.2) + vec3(0.078, 0.11, 0.18) * edge;   // 1e2636 / 4e5c78
		ROUGHNESS = 0.9;
	} else if (!FRONT_FACING) {  // section cap: pale, matching the lit wall tops
		ALBEDO = vec3(0.25, 0.29, 0.32);
		EMISSION = vec3(0.04, 0.045, 0.05);
	}
}
