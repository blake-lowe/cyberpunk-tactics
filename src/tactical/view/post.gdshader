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
uniform vec3 palette[48];
uniform int palette_n = 0;
uniform vec2 src_size = vec2(640.0, 360.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[i]) + 0.5) / 16.0 - 0.5;
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// perceptual-ish distance: weight green, and compare in a gamma-lifted space so darks separate
float cdist(vec3 a, vec3 b) {
	vec3 d = sqrt(max(a, 0.0)) - sqrt(max(b, 0.0));
	return dot(d * d, vec3(0.3, 0.5, 0.2));
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
	// S-curve: deepen shadows, keep highlights (neon) bright
	c = clamp(c, 0.0, 1.0);
	c = pow(c, vec3(1.0 + 0.15 * contrast));
	c = mix(c, c * c * (3.0 - 2.0 * c), 0.35 * contrast);
	c = mix(vec3(luma(c)), c, saturation);
	c = clamp(c, 0.0, 1.0);
	if (palette_on && palette_n > 0) {
		c += bayer4(px) * dither * 0.12;
		float best = 1e9;
		vec3 pick = c;
		for (int i = 0; i < palette_n; i++) {
			float d = cdist(c, palette[i]);
			if (d < best) { best = d; pick = palette[i]; }
		}
		c = pick;
	} else if (levels > 0.0) {
		c += bayer4(px) * dither / levels;
		c = floor(clamp(c, 0.0, 1.0) * levels + 0.5) / levels;
	}
	COLOR = vec4(c, 1.0);
}
