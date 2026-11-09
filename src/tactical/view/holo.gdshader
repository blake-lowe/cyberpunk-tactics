shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, shadows_disabled, specular_disabled;
// Holo-ads and media screens round a tower band (TowerDress): additive light on a quad (QuadMesh,
// UV 0..1), colour per instance (COLOR rgb; a second colour from `col2`), INSTANCE_CUSTOM =
// (seed, kind, brightness, 0). Scanlines, a flicker now and then, a soft fade at the foot.
// kind 0: a column of glyphs (kanji-like blocks); 1: an emblem over lines of text; 2: a media
// screen (moving picture blocks and a ticker); 3: a two-tone ad with a headline block.
// billboard: the quad turns round its vertical axis to face the camera (the far holograms).

uniform bool billboard = false;
uniform vec3 col2 : source_color = vec3(0.02, 0.85, 0.91);
uniform bool day = false;
uniform vec2 map_size = vec2(1.0);
global uniform vec3 cut_center;
global uniform vec2 cut_dir;

varying vec3 wpos;
varying vec4 col;
varying vec4 cus;
varying vec2 qs;   // the quad's size in world units

void vertex() {
	qs = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
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

// a 5x5 glyph cell: blocky strokes, mirrored for the look of a character
float glyph(vec2 uv, float s) {
	vec2 g = floor(uv * 5.0);
	if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) return 0.0;
	vec2 q = vec2(min(g.x, 4.0 - g.x), g.y);
	float on = step(0.52, hash(q + vec2(s * 7.1, s * 3.3)));
	if (g.y == 0.0 || g.x == 2.0) on = max(on, step(0.6, hash(vec2(s, g.y + g.x * 9.0))));
	return on;
}

void fragment() {
	if (dot(wpos.xz - cut_center.xz, cut_dir) < -4.0 && wpos.y > 1.2 && wpos.x > -0.5 && wpos.x < map_size.x + 80.0)
		discard;
	vec2 uv = vec2(UV.x, UV.y);   // y down
	float s = floor(cus.x);
	int k = int(cus.y + 0.5);
	vec3 a = col.rgb;
	vec3 b = col2;
	vec3 c = vec3(0.0);
	float px = qs.y / 40.0;   // the screen's own pixel rows
	if (k == 0) {   // a glyph column in a frame
		float n = max(3.0, floor(qs.y / max(qs.x, 0.1)));
		vec2 cell = vec2(uv.x, uv.y * n);
		float gi = floor(cell.y);
		float t = floor(TIME * 0.7 + s);
		vec2 lu = (fract(cell) - 0.5) / 0.72 + 0.5;
		float g = glyph(vec2(lu.x, lu.y), s + gi * 13.0 + mod(t + gi, 3.0) * 0.0);
		c = a * g * 1.3 + a * 0.08;
	} else if (k == 1) {   // an emblem over three lines of text
		vec2 e = (uv - vec2(0.5, 0.32)) * vec2(qs.x / qs.y * 1.6, 1.0);
		float d = abs(e.x) + abs(e.y);
		float emb = step(abs(d - 0.18), 0.025) + step(d, 0.07);
		float rot = step(abs(abs(e.x) - abs(e.y)), 0.012) * step(d, 0.18);
		float lines = 0.0;
		for (int i = 0; i < 3; i++) {
			float y0 = 0.62 + float(i) * 0.1;
			float len = 0.35 + 0.5 * hash(vec2(s, float(i)));
			lines += step(y0, uv.y) * step(uv.y, y0 + 0.05) * step(abs(uv.x - 0.5), len * 0.5) * step(0.25, hash(vec2(floor(uv.x * 30.0), s + float(i))));
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
	} else {   // a two-tone ad: a headline block, a strap line
		c = mix(a * 0.55, b * 0.45, uv.y);
		float head = step(0.18, uv.y) * step(uv.y, 0.46) * step(abs(uv.x - 0.5), 0.38) * step(0.3, hash(vec2(floor(uv.x * 9.0), s)));
		c += vec3(1.0, 0.95, 0.9) * head * 0.8;
		c += b * step(0.6, uv.y) * step(uv.y, 0.68) * step(abs(uv.x - 0.5), 0.3) * 0.9;
	}
	// the frame, scanlines, a flicker now and then, the foot fading out
	float fr = step(min(min(uv.x, 1.0 - uv.x) * qs.x, min(uv.y, 1.0 - uv.y) * qs.y), 0.12);
	c = max(c, a * fr * 1.2);
	float scan = 0.72 + 0.28 * step(0.5, fract(wpos.y / max(px, 0.05)));
	float fl = 1.0 - 0.6 * step(0.985, hash(vec2(floor(TIME * 12.0), s)));
	float foot = smoothstep(1.0, 0.75, uv.y) * 0.6 + 0.4;
	c *= scan * fl * foot * cus.z * (day ? 0.3 : 1.0);
	ALBEDO = vec3(0.0);
	EMISSION = c;
}
