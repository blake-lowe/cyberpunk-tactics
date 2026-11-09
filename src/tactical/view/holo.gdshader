shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, shadows_disabled, specular_disabled;
// Holo-ads and media screens (the sign library, SignLib; TowerDress, AmbientFx, WorldBuilder):
// additive light on a quad (QuadMesh, UV 0..1), translucent, scanlined, with a little jitter.
// Colour per instance (COLOR rgb); the second colour `col2` per material, or SignLib's palette
// index packed into the seed (seed + 1000 * (index + 1)).
// INSTANCE_CUSTOM = (seed, kind, brightness, text) where text = atlas row * 1024 + the name's width
// in pixels (SignLib.atlas(): each library entry's name, then its strap line, in the 5x7 pixel
// font, 8 pixel rows each: 16 a row).
// kind 0: a column of abstract glyphs; 1: an emblem over lines of text; 2: a media screen (moving
// picture blocks and a ticker); 3: a two-tone ad with a headline block; 4: a logo: the name,
// cycling with an emblem; 5: a news ticker scrolling under a header; 6: a dancing silhouette
// over the name; 7: a product (a can) turning, the name under it.
// billboard: the quad turns round its vertical axis to face the camera (the far holograms).
#include "res://src/tactical/view/sign_common.gdshaderinc"

uniform bool billboard = false;
uniform vec3 col2 : source_color = vec3(0.02, 0.85, 0.91);
uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform vec3 pal[10];   // SignLib.PALETTE (linear): a library holo's second colour, by index in its seed

varying vec3 wpos;
varying vec4 col;
varying vec4 cus;
varying vec2 qs;   // the quad's size in world units
varying vec3 out_dir;

void vertex() {
	qs = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	out_dir = normalize(MODEL_MATRIX[2].xyz);
	if (billboard) {
		vec3 c = MODEL_MATRIX[3].xyz;
		vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
		vec3 w = c + right * VERTEX.x * qs.x + vec3(0.0, VERTEX.y * qs.y, 0.0);
		wpos = w;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	} else {   // (writing POSITION in one branch means writing it in both)
		wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wpos, 1.0);
	}
	col = COLOR;
	cus = INSTANCE_CUSTOM;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// a 5x5 glyph cell: blocky strokes, mirrored for the look of a character (abstract, not a script)
float glyph(vec2 uv, float s) {
	vec2 g = floor(uv * 5.0);
	if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) return 0.0;
	vec2 q = vec2(min(g.x, 4.0 - g.x), g.y);
	float on = step(0.52, hash(q + vec2(s * 7.1, s * 3.3)));
	if (g.y == 0.0 || g.x == 2.0) on = max(on, step(0.6, hash(vec2(s, g.y + g.x * 9.0))));
	return on;
}

// The atlas text `row` (width `len` pixels) in the box `b` (x0, y0, x1, y1 in UV, y down): its
// pixels kept square on the quad, centred. `scroll`: pixels shifted left (a ticker, wrapping).
// line: the entry's strap line (left-aligned, its width unknown here), else its name.
float text(vec2 uv, vec4 b, float row, bool line, float len, float scroll) {
	if (uv.x < b.x || uv.x > b.z || uv.y < b.y || uv.y > b.w || (len < 1.0 && !line)) return 0.0;
	vec2 bw = vec2(b.z - b.x, b.w - b.y) * qs;           // the box in world units
	float px = (scroll > 0.0 || line) ? bw.y / 8.0 : min(bw.y / 8.0, bw.x / (len + 2.0));
	vec2 p = (uv - b.xy) * qs / px;                     // in text pixels from the box's corner
	float w = line ? 1000.0 : len;
	float x0 = (scroll > 0.0 || line) ? 0.0 : (bw.x / px - len) * 0.5;
	float y0 = (bw.y / px - 7.0) * 0.5;
	float tx = p.x - x0 + scroll;
	if (scroll > 0.0) tx = mod(tx, len + 12.0);
	float ty = p.y - y0;
	if (tx < 0.0 || tx >= w || ty < 0.0 || ty >= 7.0) return 0.0;
	if (tx >= float(textureSize(atlas, 0).x)) return 0.0;
	return texelFetch(atlas, ivec2(int(tx), int(row) * 16 + (line ? 8 : 0) + int(ty)), 0).r;
}

float emblem(vec2 uv, vec2 c, float s, float t) {
	vec2 e = (uv - c) * vec2(qs.x / qs.y, 1.0) / s;
	float a = t * 0.8;
	e = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * e;
	float d = abs(e.x) + abs(e.y);
	return step(abs(d - 0.75), 0.1) + step(d, 0.28) + step(abs(abs(e.x) - abs(e.y)), 0.05) * step(d, 0.75);
}

// a dancing figure, in a box of height 1 centred at the origin (y up)
float dancer(vec2 p, float t) {
	float sway = sin(t * 4.0) * 0.06;
	float bob = abs(sin(t * 4.0)) * 0.04;
	vec2 hip = vec2(sway, -0.05 + bob);
	vec2 neck = hip + vec2(-sway * 0.6, 0.32);
	vec2 head = neck + vec2(0.0, 0.1);
	float arm = sin(t * 4.0 + 1.0);
	vec2 ha = neck + vec2(-0.18, 0.08 + 0.18 * arm);
	vec2 hb = neck + vec2(0.18, 0.08 - 0.18 * arm);
	vec2 ea = neck + vec2(-0.12, -0.02 + 0.06 * arm);
	vec2 eb = neck + vec2(0.12, -0.02 - 0.06 * arm);
	float kick = sin(t * 4.0 + 2.0) * 0.08;
	vec2 fa = vec2(-0.12 - kick, -0.48);
	vec2 fb = vec2(0.12 + kick, -0.48);
	vec2 ka = hip + vec2(-0.08, -0.2);
	vec2 kb = hip + vec2(0.08 - kick, -0.18);
	float d = length(p - head) - 0.07;
	vec2 segs[9] = {hip, neck, neck, ea, ea, ha, neck, eb, eb};
	vec2 segs2[9] = {neck, neck, ea, ha, ha, ha, eb, hb, hb};
	for (int i = 0; i < 9; i++) {
		vec2 a = segs[i];
		vec2 b = segs2[i];
		vec2 pa = p - a;
		vec2 ba = b - a;
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
		d = min(d, length(pa - ba * h) - (i == 0 ? 0.06 : 0.025));
	}
	vec2 la[4] = {hip, ka, hip, kb};
	vec2 lb[4] = {ka, fa, kb, fb};
	for (int i = 0; i < 4; i++) {
		vec2 pa = p - la[i];
		vec2 ba = lb[i] - la[i];
		float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
		d = min(d, length(pa - ba * h) - 0.032);
	}
	return d;
}

void fragment() {
	if (sign_cut(wpos, out_dir, VERTEX, SCREEN_UV, VIEWPORT_SIZE)) discard;
	vec2 uv = vec2(UV.x, UV.y);   // y down
	float s = mod(floor(cus.x), 1000.0);
	int pi = int(floor(cus.x / 1000.0));
	int k = int(cus.y + 0.5);
	float row = floor(cus.w / 1024.0);
	float len = mod(cus.w, 1024.0);
	// jitter: now and then a band of rows slips sideways
	float jt = floor(TIME * 8.0);
	float band = floor(uv.y * 9.0);
	uv.x += (hash(vec2(jt, band + s)) - 0.5) * 0.06 * step(0.94, hash(vec2(jt, s * 0.37)));
	vec3 a = col.rgb;
	vec3 b = pi > 0 ? pal[min(pi - 1, 9)] : col2;
	vec3 c = vec3(0.0);
	float px = qs.y / 40.0;   // the screen's own pixel rows
	if (k == 0) {   // a glyph column in a frame
		float n = max(3.0, floor(qs.y / max(qs.x, 0.1)));
		vec2 cell = vec2(uv.x, uv.y * n);
		float gi = floor(cell.y);
		vec2 lu = (fract(cell) - 0.5) / 0.72 + 0.5;
		float g = glyph(vec2(lu.x, lu.y), s + gi * 13.0);
		c = a * g * 1.3 + a * 0.08;
	} else if (k == 1) {   // an emblem over three lines of text
		vec2 e = (uv - vec2(0.5, 0.32)) * vec2(qs.x / qs.y * 1.6, 1.0);
		float d = abs(e.x) + abs(e.y);
		float emb = step(abs(d - 0.18), 0.025) + step(d, 0.07);
		float rot = step(abs(abs(e.x) - abs(e.y)), 0.012) * step(d, 0.18);
		float lines = 0.0;
		for (int i = 0; i < 3; i++) {
			float y0 = 0.62 + float(i) * 0.1;
			float ln = 0.35 + 0.5 * hash(vec2(s, float(i)));
			lines += step(y0, uv.y) * step(uv.y, y0 + 0.05) * step(abs(uv.x - 0.5), ln * 0.5) * step(0.25, hash(vec2(floor(uv.x * 30.0), s + float(i))));
		}
		c = a * (emb + rot) * 1.4 + b * lines * 1.1 + a * 0.06;
	} else if (k == 2) {   // a media screen: moving blocks of picture, a ticker along the foot
		vec2 g = floor(uv * vec2(12.0, 8.0));
		float t = floor(TIME * 1.5);
		float v = hash(g + vec2(t * 0.37, s));
		float wave = 0.5 + 0.5 * sin(uv.x * 6.0 + TIME * 0.8 + s) * sin(uv.y * 4.0 - TIME * 0.5);
		c = mix(a, b, step(0.5, wave)) * (0.35 + 0.65 * v) * step(uv.y, 0.82);
		float tick = step(0.86, uv.y) * step(uv.y, 0.96) * step(0.4, hash(vec2(floor(uv.x * 40.0 + TIME * 6.0), s)));
		c += vec3(1.0) * tick * 0.9;
	} else if (k == 3) {   // a two-tone ad: a headline block, a strap line
		c = mix(a * 0.55, b * 0.45, uv.y);
		float head = step(0.18, uv.y) * step(uv.y, 0.46) * step(abs(uv.x - 0.5), 0.38) * step(0.3, hash(vec2(floor(uv.x * 9.0), s)));
		c += vec3(1.0, 0.95, 0.9) * head * 0.8;
		c += b * step(0.6, uv.y) * step(uv.y, 0.68) * step(abs(uv.x - 0.5), 0.3) * 0.9;
	} else if (k == 4) {   // a logo: the name, then its emblem turning, then the name again
		float ph = mod(TIME + s * 1.7, 9.0);
		float glitch = step(abs(ph - 6.0), 0.12) + step(abs(ph - 9.0), 0.12) + step(ph, 0.12);
		uv.x += glitch * (hash(vec2(floor(uv.y * 20.0), floor(TIME * 30.0))) - 0.5) * 0.2;
		if (ph < 6.0) {
			c = a * text(uv, vec4(0.06, 0.18, 0.94, 0.66), row, false, len, 0.0) * 1.5;
			c += b * step(0.76, uv.y) * step(uv.y, 0.8) * step(abs(uv.x - 0.5), 0.36) * 0.9;
		} else {
			c = a * emblem(uv, vec2(0.5, 0.48), 0.32, TIME) * 1.3 + b * 0.06;
		}
		c += a * 0.05;
	} else if (k == 5) {   // a ticker: a header bar in the second colour, the news running under it
		float head = step(uv.y, 0.3);
		c = b * head * 0.32 + a * (1.0 - head) * 0.08;
		c += vec3(1.0) * head * text(uv, vec4(0.04, 0.06, 0.96, 0.26), row, true, 0.0, 0.0);
		c += a * 1.5 * text(uv, vec4(0.0, 0.46, 1.0, 0.78), row, false, len, TIME * 9.0 + s * 10.0);
		c += b * step(0.93, uv.y) * step(0.5, fract(uv.x * 20.0 - TIME * 2.0)) * 0.5;
	} else if (k == 6) {   // a dancer over the name, the light behind them sweeping
		vec2 p = (uv - vec2(0.5, 0.4)) * vec2(qs.x / qs.y, -1.0) / 0.66;
		float d = dancer(p, TIME + s);
		float sweep = 0.5 + 0.5 * sin(uv.x * 7.0 - TIME * 2.0);
		c = mix(a, b, sweep) * 0.16 * step(uv.y, 0.8);
		c += a * (1.0 - smoothstep(0.0, 0.012, d)) * 1.3 + b * (1.0 - smoothstep(0.0, 0.05, abs(d))) * 0.5;
		c += mix(b, vec3(1.0), 0.35) * 1.6 * text(uv, vec4(0.04, 0.73, 0.96, 0.99), row, false, len, 0.0);
	} else {   // a product: a can turning, its label sliding round, the name under it
		vec2 p = (uv - vec2(0.5, 0.4)) * vec2(qs.x / qs.y, 1.0);
		float can = step(abs(p.x), 0.17) * step(abs(p.y), 0.28);
		float u = p.x / 0.17;
		float ang = asin(clamp(u, -1.0, 1.0)) + TIME * 1.6 + s;
		float label = step(0.5, fract(ang / 3.14159 * 1.5)) * step(abs(p.y), 0.14);
		float shine = exp(-pow((u + 0.45) * 4.0, 2.0));
		float shade = sqrt(max(1.0 - u * u, 0.0));
		c = (mix(a * 0.5, b, label) * (0.4 + 0.6 * shade) + vec3(shine) * 0.7) * can;
		c += a * (step(abs(p.y + 0.29), 0.012) + step(abs(p.y - 0.29), 0.012)) * step(abs(p.x), 0.15);
		c += a * 0.06 + mix(b, vec3(1.0), 0.35) * 1.6 * text(uv, vec4(0.04, 0.72, 0.96, 0.99), row, false, len, 0.0);
	}
	// the frame, scanlines, a flicker now and then, the foot fading out
	float fr = step(min(min(uv.x, 1.0 - uv.x) * qs.x, min(uv.y, 1.0 - uv.y) * qs.y), 0.12 * min(1.0, qs.y));
	c = max(c, a * fr * 1.2);
	float scan = 0.72 + 0.28 * step(0.5, fract(wpos.y / max(px, 0.02)));
	float fl = 1.0 - 0.6 * step(0.985, hash(vec2(floor(TIME * 12.0), s)));
	float foot = smoothstep(1.0, 0.75, uv.y) * 0.6 + 0.4;
	c *= scan * fl * foot * cus.z * (day ? 0.3 : 1.0) * sign_day(0.15);
	ALBEDO = vec3(0.0);
	EMISSION = c;
}
