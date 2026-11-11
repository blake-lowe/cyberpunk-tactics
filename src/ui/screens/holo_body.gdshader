shader_type spatial;
// The cyberware screens' hologram (ChromeBody): the crew member's own model as a lit, rim-glowing,
// translucent scan. Unshaded: a fresnel rim, a faint inner fill shaded by a fake key light (so the
// form reads), contour slices up the body, screen scanlines that drift, a scan sweep and a flicker
// (both off under reduced motion). Each body region (vertex COLOR.r, baked from bone weights by
// ChromeBody) takes its own tint: cyan meat, violet chrome, gold for the selected location.
// External chrome (skin) adds a second, violet skin at the silhouette's edge.
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled, fog_disabled;

uniform vec4 meat : source_color = vec4(0.02, 0.85, 0.91, 1.0);
uniform vec4 tints[10] : source_color;   // per region: colour, a = how much of it (0 = meat)
uniform float plated[10];                // per region: 1 = chrome plating (denser contour slices)
uniform int region_fixed = -1;           // hair and gear: the whole mesh is one region
// The outfit, as char.gdshader paints it (mode 0: the body's cloth regions in COLOR.b, the trunk
// split by rest height in COLOR.g; 1: hair, the tinted texture; 2: gear, flat): only its
// brightness comes through, so the jacket, trousers, boots and skin read as they do in a gig.
uniform int mode = 2;
uniform sampler2D tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec3 albedo : source_color = vec3(0.5);
uniform vec3 skin : source_color = vec3(0.75, 0.55, 0.42);
uniform vec3 jacket : source_color = vec3(0.25, 0.4, 0.55);
uniform vec3 sleeve : source_color = vec3(0.25, 0.4, 0.55);
uniform vec3 forearm : source_color = vec3(0.25, 0.4, 0.55);
uniform vec3 pants : source_color = vec3(0.2, 0.22, 0.28);
uniform vec3 boots : source_color = vec3(0.12, 0.13, 0.15);
uniform vec3 gloves : source_color = vec3(0.1, 0.1, 0.12);
uniform vec3 belt : source_color = vec3(0.11, 0.09, 0.07);
uniform float belt_y = 1.0;
uniform float belt_w = 0.03;
uniform float coat_y = 0.98;
uniform float boots_y = 0.3;
uniform vec4 shell : source_color = vec4(0.0);   // external chrome: rgb, a = strength
uniform float motion = 1.0;              // 0 under reduced motion
uniform float gain = 1.0;                // gear and hair a touch dimmer than the body
uniform float top = 0.95;                // figure height (world units), for the sweep

varying flat int region;
varying flat int cloth;
varying float h;
varying float rest_y;

// Worked out in display (sRGB) terms on every renderer: Forward+ hands colours in linear and wants
// linear back; Compatibility works in sRGB throughout (OUTPUT_IS_SRGB).
vec3 to_srgb(vec3 v) {
	return mix(v * 12.92, 1.055 * pow(max(v, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), v));
}

vec3 to_linear(vec3 v) {
	return mix(v / 12.92, pow((max(v, vec3(0.0)) + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), v));
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	region = region_fixed >= 0 ? region_fixed : int(COLOR.r * 16.0 + 0.5);
	cloth = int(COLOR.b * 8.0 + 0.5);
	rest_y = COLOR.g * 2.0;
	h = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	int r = clamp(region, 0, 9);
	vec4 t = tints[r];
	vec3 col = mix(meat.rgb, t.rgb, t.a);
	if (!OUTPUT_IS_SRGB) {
		col = to_srgb(col);
	}
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 2.2);
	// a fake key from the upper left and a cooler fill: the form, not just an outline
	float key = clamp(dot(NORMAL, normalize(vec3(-0.45, 0.55, 0.7))), 0.0, 1.0);
	vec3 base = albedo;
	float seam = 0.0;
	if (mode == 0) {
		float tl = dot(texture(tex, UV).rgb, vec3(0.299, 0.587, 0.114));
		int rg = cloth;
		if (rg == 1) {   // trunk and legs: split by rest height
			rg = rest_y < boots_y ? 4 : rest_y < coat_y ? 3 : abs(rest_y - belt_y) < belt_w ? 6 : 1;
			// hem lines where the cloth changes: the belt's edges, the coat's hem, the boot tops
			float fw = max(fwidth(rest_y), 0.0005);
			seam = max(seam, 1.0 - smoothstep(0.0, fw * 1.5, abs(abs(rest_y - belt_y) - belt_w)));
			seam = max(seam, 1.0 - smoothstep(0.0, fw * 1.5, abs(rest_y - coat_y)));
			seam = max(seam, 1.0 - smoothstep(0.0, fw * 1.5, abs(rest_y - boots_y)));
		}
		base = rg == 0 ? skin * (0.55 + 0.9 * tl) : (rg == 1 ? jacket : rg == 2 ? sleeve : rg == 3 ? pants : rg == 4 ? boots
			: rg == 5 ? gloves : rg == 6 ? belt : forearm) * (0.85 + 0.3 * tl);
	} else if (mode == 1) {
		base = albedo * (0.35 + 1.1 * dot(texture(tex, UV).rgb, vec3(0.299, 0.587, 0.114)));
	}
	if (!OUTPUT_IS_SRGB) {
		base = to_srgb(base);
	}
	float lum = pow(clamp(dot(base, vec3(0.299, 0.587, 0.114)), 0.0, 1.0), 0.6);
	float fill = 0.035 + 0.42 * lum * (0.35 + 0.65 * key);
	// contour slices up the body (a wire look); chrome is plated: finer, brighter slices
	float pl = plated[r];
	float k = mix(70.0, 130.0, pl);
	float s = abs(fract(h * k) - 0.5) * 2.0;
	float slice = smoothstep(1.0 - fwidth(h * k) * 2.5, 1.0, s) * (0.10 + 0.22 * pl);
	// screen scanlines, drifting up a pixel at a time
	float sl = mod(floor(FRAGCOORD.y + floor(TIME * 6.0) * motion), 3.0);
	float scan = sl < 0.5 ? 0.62 : 1.0;
	// the sweep: a bright band rising up the body every few seconds
	float sp = fract(TIME * 0.11) * (top + 0.4) - 0.2;
	float sweep = motion * smoothstep(0.045, 0.0, abs(h - sp)) * 0.35;
	// flicker: a rare dip and a faint shimmer
	float fl = 1.0 - motion * (0.16 * step(0.94, hash(floor(TIME * 13.0))) + 0.03 * sin(TIME * 37.0));
	vec3 c = col * (fill * 0.9 + slice + sweep + seam * 0.35 + rim * 1.3) + vec3(0.35) * pow(rim, 3.0);   // edges run hot, toward white
	float a = clamp(0.28 + fill * 0.9 + rim * 0.9 + slice + sweep + seam * 0.3, 0.0, 1.0);
	if (shell.a > 0.0) {   // external chrome: a violet skin over the edge
		float e = smoothstep(0.35, 0.95, 1.0 - ndv) * shell.a;
		c = mix(c, (OUTPUT_IS_SRGB ? shell.rgb : to_srgb(shell.rgb)) * 1.15, e);
		a = max(a, e);
	}
	c = clamp(c * scan * fl * gain, 0.0, 1.0);
	ALBEDO = OUTPUT_IS_SRGB ? c : to_linear(c);
	ALPHA = a * mix(0.85, 1.0, scan) * gain;
}
