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

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[i]) + 0.5) / 16.0 - 0.5;
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

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
			if (i >= palette_neutral_n && chroma < 0.05) continue;
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
