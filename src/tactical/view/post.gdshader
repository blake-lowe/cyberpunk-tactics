shader_type canvas_item;
// Pixel-art post-process for the low-res 3D view (spec: limited palette, hard edges, controls for
// pixel scale, contrast and bloom). Applied to the upscaled SubViewport texture.
// Order: outline → tone (gamma S-curve, saturation) → light Bayer dither → nearest colour in a
// curated palette (or plain per-channel steps when the palette is off).

uniform float levels = 0.0;        // per-channel steps when palette_on is false; 0 = off
uniform float dither = 0.3;        // 0..1 ordered (Bayer 4x4) dither strength
uniform float contrast = 1.0;      // strength of the S-curve
uniform float saturation = 1.0;
uniform float outline = 0.0;       // 0..1 darken pixels on strong luminance edges
uniform bool palette_on = true;
uniform vec3 palette[64];          // in OKLab (converted on the CPU)
uniform int palette_n = 0;
uniform int palette_neutral_n = 0;  // entries after this are neon ramps: only for saturated pixels
uniform vec2 src_size = vec2(640.0, 360.0);
// Cyberspace view (while a Netrunner is jacked in): the environment is pushed into the background
// in one of several styles; the NET itself is drawn on top, crisp and bright (NetOverlay).
// 0 off, 1 pointillist, 2 Obra Dinn 1-bit, 3 wireframe, 4 Blackwall, 5 Ghost in the Shell,
// 6 2001 stargate (slit-scan); wireframe variants: 7 crisp (full res), 8 blueprint (full res),
// 9 scan sweep. Owner picked wireframe; the others stay for transitions and effects.
uniform int net_style = 0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[i]) + 0.5) / 16.0 - 0.5;
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
// luminance over a 2x2 block: ordered dither (cutaway edges, fades) averages out, so the edge
// styles trace geometry instead of dotted rings
float lum_at(sampler2D t, vec2 uv) {
	vec2 h = 0.5 / src_size;
	vec3 c = texture(t, uv + vec2(-h.x, -h.y)).rgb + texture(t, uv + vec2(h.x, -h.y)).rgb
		+ texture(t, uv + vec2(-h.x, h.y)).rgb + texture(t, uv + vec2(h.x, h.y)).rgb;
	return dot(c * 0.25, vec3(0.299, 0.587, 0.114));
}
float edge_at(sampler2D t, vec2 uv, vec2 px) {
	float l = lum_at(t, uv);
	return max(max(abs(l - lum_at(t, uv + vec2(px.x, 0.0))), abs(l - lum_at(t, uv + vec2(0.0, px.y)))),
		max(abs(l - lum_at(t, uv - vec2(px.x, 0.0))), abs(l - lum_at(t, uv - vec2(0.0, px.y)))));
}

vec3 cyberspace(sampler2D t, vec2 uv, vec2 px, vec2 cell) {
	vec3 c = texture(t, uv).rgb;
	float l = clamp(luma(c) * 1.6, 0.0, 1.0);
	float e = edge_at(t, uv, 1.0 / src_size);
	if (net_style == 1) {   // pointillist: desaturated dots sized by brightness on near-black
		vec2 g = floor(cell / 3.0) * 3.0 + 1.5;
		vec3 cc = texture(t, (g + 0.5) / src_size).rgb;
		float ll = clamp(luma(cc) * 1.8, 0.0, 1.0);
		float r = 0.35 + 1.25 * sqrt(ll);
		float dotm = step(length(cell + 0.5 - g), r);
		vec3 tint = mix(vec3(ll), cc, 0.25) * vec3(0.75, 0.85, 0.95);
		return mix(vec3(0.02, 0.025, 0.035), tint * 0.75, dotm);
	} else if (net_style == 2) {   // Obra Dinn: 1-bit ordered dither, ink outlines, dim paper
		float b = bayer4(cell);
		float on = step(0.5, l * 0.9 + b * 0.9);
		on *= 1.0 - step(0.09, e);
		return mix(vec3(0.06, 0.065, 0.06), vec3(0.47, 0.5, 0.44), on);
	} else if (net_style == 3 || net_style == 7) {   // wireframe: white edges on black, a ghost of fill
		float line = smoothstep(0.035, 0.1, e);   // geometry edges (lamp pools are off in cyberspace, so gradients are rare)
		return vec3(0.025) + vec3(0.11) * l + vec3(0.52) * line;   // a readable ghost of the scene, still below the NET's brightness
	} else if (net_style == 8) {   // blueprint: cyan lines on deep navy, a faint drafting grid
		float line = smoothstep(0.04, 0.1, e);
		float grid = step(mod(cell.x, 24.0), 0.9) + step(mod(cell.y, 24.0), 0.9);
		return vec3(0.02, 0.05, 0.1) + vec3(0.02, 0.06, 0.1) * min(grid, 1.0) + vec3(0.1, 0.12, 0.16) * l * 0.4 + vec3(0.35, 0.8, 1.0) * line * 0.75;
	} else if (net_style == 9) {   // scan: lines brighten as a slow sweep passes, then fade
		float line = smoothstep(0.04, 0.1, e);
		float sweep = fract(TIME * 0.25);
		float dist = fract(sweep - uv.y);
		float glow = exp(-dist * 6.0);
		return vec3(0.02) + vec3(0.05) * l + vec3(0.25, 0.32, 0.36) * line + vec3(0.6, 0.9, 1.0) * line * glow + vec3(0.02, 0.05, 0.06) * glow;
	} else if (net_style == 4) {   // Blackwall: red-black, tearing rows, chromatic split
		float row = floor(cell.y / 5.0);
		float tear = step(0.94, h21(vec2(row, floor(TIME * 7.0))));
		vec2 u2 = uv + vec2((h21(vec2(row, 3.0 + floor(TIME * 7.0))) - 0.5) * 0.06 * tear, 0.0);
		float lr = clamp(lum_at(t, u2 + vec2(2.0 / src_size.x, 0.0)) * 1.6, 0.0, 1.0);
		float lg = clamp(lum_at(t, u2) * 1.6, 0.0, 1.0);
		vec3 col = vec3(0.42, 0.03, 0.06) * lr + vec3(0.08, 0.0, 0.01) * lg;
		col += vec3(0.9, 0.1, 0.15) * smoothstep(0.05, 0.12, edge_at(t, u2, 1.0 / src_size)) * 0.45;
		col *= 0.7 + 0.3 * step(1.0, mod(cell.y, 3.0));
		return col;
	} else if (net_style == 5) {   // Ghost in the Shell: green phosphor with falling code
		vec3 col = vec3(0.1, 0.85, 0.4) * l * 0.55 + vec3(0.2, 1.0, 0.5) * smoothstep(0.05, 0.12, e) * 0.35;
		float colx = floor(cell.x / 5.0);
		float sp = 0.15 + h21(vec2(colx, 1.0)) * 0.35;
		float y = fract(cell.y / src_size.y - TIME * sp + h21(vec2(colx, 7.0)));
		float glyph = step(0.5, h21(floor(vec2(colx, cell.y / 5.0)) + floor(TIME * 6.0)));
		float trail = smoothstep(0.0, 0.25, 0.25 - y) * glyph * step(mod(cell.x, 5.0), 3.0);
		col += vec3(0.25, 1.0, 0.55) * trail * 0.3 * (1.0 - l);
		col *= 0.8 + 0.2 * step(1.0, mod(cell.y, 2.0));
		return col;
	} else {   // 2001 stargate: slit-scan streaks racing out of the centre over a dark ghost
		vec2 d = uv - 0.5;
		vec3 acc = vec3(0.0);
		for (int i = 0; i < 6; i++) {
			acc += texture(t, 0.5 + d * (1.0 - float(i) * 0.035)).rgb;
		}
		float ls = clamp(luma(acc / 6.0) * 1.6, 0.0, 1.0);
		float band = fract(length(d) * 6.0 - TIME * 0.6);
		vec3 hue = 0.5 + 0.5 * cos(6.2831 * (band + vec3(0.0, 0.33, 0.67)));
		return mix(vec3(ls * 0.25), hue * ls * 0.55, 0.45);
	}
}

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, 0.0), vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
// sRGB -> OKLab, so the nearest palette colour is chosen by hue and lightness together
vec3 oklab(vec3 srgb) {
	vec3 c = to_linear(srgb);
	float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
	l = pow(l, 1.0 / 3.0); m = pow(m, 1.0 / 3.0); s = pow(s, 1.0 / 3.0);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}
vec3 from_oklab(vec3 lab) {
	float l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
	float m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
	float s = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;
	l = l * l * l; m = m * m * m; s = s * s * s;
	return to_srgb(vec3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s));
}

void fragment() {
	vec2 px = floor(UV * src_size);
	vec2 uv = (px + 0.5) / src_size;
	vec3 c = texture(TEXTURE, uv).rgb;
	if (net_style > 0) {
		COLOR = vec4(cyberspace(TEXTURE, uv, 1.0 / src_size, px), 1.0);
	} else {
	if (outline > 0.0) {
		vec2 t = 1.0 / src_size;
		float l = luma(c);
		float e = max(max(abs(l - luma(texture(TEXTURE, uv + vec2(t.x, 0.0)).rgb)), abs(l - luma(texture(TEXTURE, uv + vec2(0.0, t.y)).rgb))),
			max(abs(l - luma(texture(TEXTURE, uv - vec2(t.x, 0.0)).rgb)), abs(l - luma(texture(TEXTURE, uv - vec2(0.0, t.y)).rgb))));
		float darker = step(l, luma(texture(TEXTURE, uv + vec2(t.x, t.y)).rgb) + 0.02);
		c *= 1.0 - outline * smoothstep(0.08, 0.25, e) * darker * 0.7;
	}
	// gentle S-curve pivoted low (keeps shadow detail), then a coloured shadow floor so only
	// deliberate ink reaches black
	c = clamp(c, 0.0, 1.0);
	c = c + 0.25 * contrast * (c - 0.3) * c * (1.0 - c) * 4.0;
	c = c * 0.93 + vec3(0.018, 0.022, 0.045);
	c = mix(vec3(luma(c)), c, saturation);
	c = clamp(c, 0.0, 1.0);
	if (palette_on && palette_n > 0) {
		c += bayer4(px) * dither * 0.1;
		vec3 lab = oklab(clamp(c, 0.0, 1.0));
		float best = 1e9;
		vec3 pick = lab;
		float chroma = length(lab.yz);
		for (int i = 0; i < palette_n; i++) {
			// neon ramps only for pixels that are saturated and roughly that ramp's hue
			if (i >= palette_neutral_n && (chroma < 0.025 || dot(lab.yz / max(chroma, 1e-4), normalize(palette[i].yz)) < 0.9)) continue;
			vec3 d = lab - palette[i];
			float e = dot(d, d * vec3(1.0, 1.6, 1.6));
			if (e < best) { best = e; pick = palette[i]; }
		}
		c = from_oklab(pick);
	} else if (levels > 0.0) {
		c += bayer4(px) * dither / levels;
		c = floor(clamp(c, 0.0, 1.0) * levels + 0.5) / levels;
	}
	COLOR = vec4(c, 1.0);
	}
}
