shader_type canvas_item;
// The "scan" cyberware figure's soft tissue (BodyScan): the body (BodyShape's round cones, blended)
// as a medical render: a bright edge falling off inward like an X-ray, iso-density contours, scan
// slices, a faint halo. Each pixel's region (the nearest part) takes its tint: cyan meat, violet
// chrome (plated: a hexagonal armour lattice), gold for the selected location (it pulses). External
// chrome (shell) is a second skin just outside the edge. A scan band runs down the body only with
// motion on.
render_mode blend_add;

uniform vec4 pa[48];              // per part: from.xy, to.xy (body units: height 1)
uniform vec4 pb[48];              // r from, r to, blend, region
uniform int nparts = 0;
uniform vec4 map = vec4(-0.3, -0.05, 0.6, 1.1);   // body coords at UV 0, and the span of UV 1
uniform float px = 0.002;         // one screen pixel, in body units
uniform vec4 tints[11];
uniform float plated[11];
uniform vec4 meat : source_color = vec4(0.02, 0.85, 0.91, 1.0);
uniform vec4 shell = vec4(0.0);
uniform int selected = -1;
uniform float motion = 1.0;
uniform float band_y = -1.0;      // a held scan band (reduced motion: none)

float cone(vec2 p, vec2 a, vec2 b, float ra, float rb) {
	p -= a;
	vec2 pbv = b - a;
	float h = dot(pbv, pbv);
	if (h < 1e-10) return length(p) - ra;
	vec2 q = vec2(dot(p, vec2(pbv.y, -pbv.x)), dot(p, pbv)) / h;
	q.x = abs(q.x);
	float bb = ra - rb;
	vec2 c = vec2(sqrt(max(h - bb * bb, 0.0)), bb);
	float k = c.x * q.y - c.y * q.x;
	float m = dot(c, q);
	float n = dot(q, q);
	if (k < 0.0) return sqrt(h * n) - ra;
	if (k > c.x) return sqrt(h * (n + 1.0 - 2.0 * q.y)) - rb;
	return m - ra;
}

float smin(float a, float b, float k) {
	if (k <= 0.0) return min(a, b);
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float rule(float v, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.7, abs(v));
}

// A hexagonal lattice's edges: distance to the nearest cell edge, in cell units.
float hex_edge(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return 0.5 - max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x);
}

void fragment() {
	vec2 p = map.xy + UV * map.zw;
	float d = 1e9;
	float best = 1e9;
	int reg = 0;
	for (int i = 0; i < nparts; i++) {
		float di = cone(p, pa[i].xy, pa[i].zw, pb[i].x, pb[i].y);
		d = smin(d, di, pb[i].z);
		if (di < best) {
			best = di;
			reg = int(pb[i].w);
		}
	}
	vec4 t = tints[reg];
	vec3 col = mix(meat.rgb, t.rgb, t.a);
	float pulse = (reg == selected) ? 0.9 + 0.2 * motion * sin(TIME * 2.6) : 1.0;
	float dp = d / px;                                   // screen pixels to the edge
	float inside = 1.0 - smoothstep(-0.8, 0.8, dp);
	float depth = max(-d, 0.0);
	vec3 o = vec3(0.0);
	// tissue: bright at the edge, falling off inward; a little density in the core
	float rim = exp(-depth / 0.009);
	o += col * inside * (0.05 + 0.32 * rim);
	o += col * rule(dp, 1.1) * 0.95;                     // the outline
	// iso-density contours, every 0.011 in from the edge
	float iso = rule((fract(depth / 0.011 + 0.5) - 0.5) * 0.011 / px, 0.8) * step(0.004, depth);
	o += col * iso * inside * 0.16;
	// scan slices: fine horizontal lines through the body
	float sl = rule((fract(p.y / (px * 4.0)) - 0.5) * 4.0, 0.7);
	o += col * sl * inside * 0.045;
	// a faint halo outside
	o += col * (1.0 - inside) * exp(-max(d, 0.0) / 0.012) * 0.07;
	// chrome: a hex armour lattice over the plated regions, brighter at the edge
	if (plated[reg] > 0.0) {
		float he = hex_edge(p / (px * 11.0));
		float lat = 1.0 - smoothstep(0.0, 0.07, he);
		o += t.rgb * inside * (lat * (0.13 + 0.22 * rim) + 0.03) * pulse;
	}
	o *= mix(1.0, pulse, inside);
	// external chrome: a second skin just outside the first
	if (shell.a > 0.0) {
		o += shell.rgb * shell.a * (rule(dp - 3.5, 1.2) * 0.8 + (1.0 - inside) * exp(-max(d, 0.0) / 0.006) * 0.12);
	}
	// the scan band: a bright line across with a fading wake above it
	float by = motion > 0.0 ? fract(TIME * 0.07) * 1.2 - 0.1 : band_y;
	if (by > -0.5) {
		float dy = (p.y - by) / px;
		float line = rule(dy, 1.0);
		float wake = (dy < 0.0) ? exp(dy / 40.0) : 0.0;
		o += col * (inside * (line * 0.45 + wake * 0.1) + line * 0.05);
	}
	COLOR = vec4(o, 1.0);
}
