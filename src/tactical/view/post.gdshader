shader_type canvas_item;
// Pixel-art post-process for the low-res 3D view (spec: limited palette feel, hard edges,
// controls for pixel scale, contrast and bloom). Applied to the upscaled SubViewport texture.

uniform float levels = 0.0;        // colour steps per channel; 0 = off (full colour)
uniform float dither = 0.0;        // 0..1 ordered (Bayer 4x4) dither strength before quantising
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform float outline = 0.0;       // 0..1 darken pixels on strong luminance edges
uniform vec2 src_size = vec2(640.0, 360.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[i]) + 0.5) / 16.0 - 0.5;
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 px = floor(UV * src_size);
	vec2 uv = (px + 0.5) / src_size;
	vec3 c = texture(TEXTURE, uv).rgb;
	if (outline > 0.0) {
		vec2 t = 1.0 / src_size;
		float l = luma(c);
		float e = max(max(abs(l - luma(texture(TEXTURE, uv + vec2(t.x, 0.0)).rgb)), abs(l - luma(texture(TEXTURE, uv + vec2(0.0, t.y)).rgb))),
			max(abs(l - luma(texture(TEXTURE, uv - vec2(t.x, 0.0)).rgb)), abs(l - luma(texture(TEXTURE, uv - vec2(0.0, t.y)).rgb))));
		// darken the darker side of an edge only, so outlines sit on silhouettes
		float darker = step(l, luma(texture(TEXTURE, uv + vec2(t.x, t.y)).rgb) + 0.02);
		c *= 1.0 - outline * smoothstep(0.08, 0.25, e) * darker * 0.7;
	}
	c = (c - 0.5) * contrast + 0.5;
	c = mix(vec3(luma(c)), c, saturation);
	if (levels > 0.0) {
		c += bayer4(px) * dither / levels;
		c = floor(clamp(c, 0.0, 1.0) * levels + 0.5) / levels;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
