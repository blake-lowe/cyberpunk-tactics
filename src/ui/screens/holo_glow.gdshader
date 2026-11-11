shader_type canvas_item;
// The hologram's bloom (ChromeBody): the SubViewport's render (premultiplied: drawn over a clear
// background) plus a soft halo from two rings of taps round each pixel.
render_mode blend_premul_alpha;

uniform float radius = 3.0;     // inner ring, in texture pixels; the outer ring is 2.6x
uniform float strength = 0.9;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 g = vec4(0.0);
	for (int i = 0; i < 10; i++) {
		float an = float(i) * 0.6283185 + 0.31;
		vec2 d = vec2(cos(an), sin(an)) * TEXTURE_PIXEL_SIZE;
		g += texture(TEXTURE, UV + d * radius) * 0.6;
		g += texture(TEXTURE, UV + d * radius * 2.6) * 0.4;
	}
	g /= 10.0;
	vec4 o = c + vec4(g.rgb * strength, g.a * strength * 0.35) * (1.0 - c.a * 0.6);
	COLOR = vec4(o.rgb, clamp(o.a, 0.0, 1.0));
}
