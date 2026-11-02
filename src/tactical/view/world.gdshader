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
//          8 corrugated, 9 tower windows, 10 water

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
uniform bool cuttable = false;
uniform bool shell = false;
uniform sampler2D lightfield : filter_linear, repeat_disable;
uniform float spill = 0.9;
global uniform vec3 cut_center;     // xz focus, y = viewed floor index
global uniform float cut_radius;    // 0 = no cutaway
global uniform vec2 cut_dir;        // camera forward on the ground plane

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
float line(float x, float w) { float d = abs(fract(x) - 0.5); return smoothstep(0.5 - w, 0.5, d); }

void fragment() {
	// --- cutaway: only the near side of the focus (a capsule reaching toward the camera), so the
	// far walls stay up and give vertical context. Floors above the viewed one vanish there; walls
	// on it drop to waist height. Cut faces show as dark section caps with a cyan core.
	vec2 uvbase;
	{
		vec2 c = wpos.xz - wnorm.xz * 0.08;   // sample just inside the surface
		uvbase = vec2(c.x / map_size.x, (floor_idx * map_size.y + clamp(c.y, 0.5, map_size.y - 0.5)) / (map_size.y * floors));
	}
	vec2 fogv = texture(fog, uvbase).rg;
	if (cut_radius > 0.0 && fogv.g > 0.5) {
		vec2 rel = wpos.xz - cut_center.xz;
		float along = dot(rel, cut_dir);
		float lateral = length(rel - cut_dir * along);
		if (lateral < cut_radius && along < cut_radius * 0.3 && along > -cut_radius * 3.0) {
			if (floor_idx > cut_center.y + 0.5) discard;
			if (cuttable && floor_idx > cut_center.y - 0.5 && wpos.y - floor_idx * 1.6 > 0.72) discard;
		}
	}
	// --- fog of war
	float f = mode != 2 ? fogv.r : 1.0;
	if (shell) f = max(f, 0.5);
	if (mode == 0 && f < 0.22) discard;
	if (mode == 1 && f >= 0.22) discard;
	float k = mode == 0 ? mix(explored_dim, 1.0, smoothstep(0.55, 0.9, f)) : 1.0;

	// --- pattern: floors use xz, walls use (along-wall, height)
	bool up = abs(wnorm.y) > 0.5;
	vec2 p = (up ? wpos.xz : vec2(wpos.x + wpos.z, wpos.y)) * pattern_scale;
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
	} else if (pattern == 3) {            // asphalt: aggregate, patches, puddles
		float speck = hash(floor(p * 10.0));
		base *= 0.85 + n * 0.3 + speck * 0.08;
		float pud = smoothstep(0.62, 0.68, fbm(p * 0.35 + 7.0));
		rough = mix(rough, 0.04, pud);
		wet = pud;
	} else if (pattern == 4) {            // sidewalk slabs, offset rows, a few cracks
		vec2 q = vec2(p.x + floor(p.y) * 0.5, p.y);
		float g = max(line(q.x, 0.03), line(q.y, 0.03));
		base *= 0.9 + hash(floor(q)) * 0.15 + n * 0.08;
		base = mix(base, albedo2.rgb, g);
		float pud = smoothstep(0.7, 0.74, fbm(p * 0.5 + 3.0));
		rough = mix(rough, 0.08, pud);
		wet = pud;
	} else if (pattern == 5) {            // earth / grass / sand: two-colour noise
		base = mix(albedo.rgb, albedo2.rgb, smoothstep(0.3, 0.75, fbm(p * 1.3)));
		base *= 0.9 + hash(floor(p * 25.0)) * 0.15;
	} else if (pattern == 6) {            // grating
		float g = line(p.x * 4.0, 0.25);
		base = mix(base, albedo2.rgb, g);
	} else if (pattern == 7) {            // facade panels and floor seams
		float g = max(line(p.x * 0.75, 0.012), line(p.y * 0.625 + 0.5, 0.02));
		base *= 0.88 + hash(floor(vec2(p.x * 0.75, p.y * 0.625))) * 0.12 + n * 0.08;
		base = mix(base, albedo2.rgb, g);
		// grime streaks running down from the top
		base *= 1.0 - smoothstep(0.55, 0.9, noise(vec2(p.x * 6.0, p.y * 0.3))) * 0.18;
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
		base *= 0.8 + r * 0.3;
		rough = 0.22 + r * 0.1;   // glossy enough to catch spill, not a white hotspot
	}
	// --- baked light spill: walls sample the space they face; puddles reflect it brighter
	vec2 lfo = up ? vec2(0.0) : wnorm.xz * 0.35;
	vec2 luv = uvbase + vec2(lfo.x / map_size.x, lfo.y / (map_size.y * floors));
	vec2 t = vec2(0.25 / map_size.x, 0.25 / (map_size.y * floors));
	vec3 lf = (texture(lightfield, luv).rgb * 2.0 + texture(lightfield, luv + vec2(t.x, 0)).rgb + texture(lightfield, luv - vec2(t.x, 0)).rgb
		+ texture(lightfield, luv + vec2(0, t.y)).rgb + texture(lightfield, luv - vec2(0, t.y)).rgb) / 6.0;
	if (!up) lf *= 1.0 - 0.45 * clamp((wpos.y - floor_idx * 1.6) / 1.6, 0.0, 1.0);
	float pk = max(lf.r, max(lf.g, lf.b));
	lf *= 1.0 / (1.0 + pk * 0.6);   // soft knee: pools keep their hue instead of clipping white
	pk = max(lf.r, max(lf.g, lf.b));
	// puddles: a darker surface with a thin saturated reflection, not a bright stain
	base *= 1.0 - 0.5 * wet;
	emit += base * lf * spill * (1.0 - wet * 0.6) + (lf / max(pk, 1e-3)) * min(pk, 1.0) * wet * 0.25;
	if (k < 1.0) base = mix(vec3(dot(base, vec3(0.3, 0.59, 0.11))), base, 0.5) * k;
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metallic;
	EMISSION = emit * k;
	if (mode == 1) {  // unknown interior: dark hologram, screen-space scanlines, cyan edge at the frontier
		float scan = step(2.0, mod(FRAGCOORD.y + floor(TIME * 8.0), 3.0));
		float fr = texture(fog, uvbase).r;
		float edge = smoothstep(0.04, 0.2, fr) * (1.0 - smoothstep(0.2, 0.22, fr));
		ALBEDO = vec3(0.06, 0.08, 0.11);
		EMISSION = vec3(0.03, 0.09, 0.12) * (0.7 + scan * 0.6) + vec3(0.02, 0.85, 0.91) * edge;
		ROUGHNESS = 0.9;
	} else if (!FRONT_FACING) {  // section cap where the cutaway opened a wall
		ALBEDO = vec3(0.015);
		EMISSION = vec3(0.02, 0.35, 0.4) * 0.5;
	}
}
