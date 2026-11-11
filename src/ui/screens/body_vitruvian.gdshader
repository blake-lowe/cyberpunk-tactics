shader_type canvas_item;
// The "vitruvian" cyberware figure (BodyVitruvian): Leonardo's ink (TEXTURE: density in red) as
// light on the dark page, with a soft bloom from the mip chain. Bones laid over the drawing (segs,
// both poses) give each pixel its body region: its lines take the region's tint (cyan meat, violet
// chrome, gold for the selected location); a plated region's flesh gets armour plates and circuit
// traces along the bone; external chrome (shell) a dermal mesh over the whole body. A slow scan
// line and the selected place's pulse move only with motion on.
render_mode blend_add;

uniform vec4 segs[28];          // per bone: from.xy, to.xy (uv)
uniform vec4 segp[28];          // x: reach (uv), y: region
uniform int nseg = 0;
uniform vec4 tints[11];         // per region: colour, a = how much (0 = meat)
uniform float plated[11];
uniform vec4 meat : source_color = vec4(0.02, 0.85, 0.91, 1.0);
uniform vec4 shell = vec4(0.0);  // external chrome: colour, a = strength
uniform int selected = -1;
uniform float motion = 1.0;
uniform float px = 0.002;       // one screen pixel, in uv

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A thin line where |v| is near 0: `w` wide, in the same units as v.
float rule(float v, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.6, abs(v));
}

void fragment() {
	float a = texture(TEXTURE, UV).r;
	float bloom = textureLod(TEXTURE, UV, 2.0).r * 0.55 + textureLod(TEXTURE, UV, 3.5).r * 0.45;
	// the nearest bone, as a fraction of its reach
	float best = 1e9;
	int reg = 0;
	vec2 lc = vec2(0.0);
	float reach = 0.02;
	for (int i = 0; i < nseg; i++) {
		vec2 pa = segs[i].xy;
		vec2 ba = segs[i].zw - pa;
		vec2 pp = UV - pa;
		float t = clamp(dot(pp, ba) / max(dot(ba, ba), 1e-9), 0.0, 1.0);
		float d = length(pp - ba * t) / segp[i].x;
		if (d < best) {
			best = d;
			reg = int(segp[i].y);
			vec2 dir = normalize(ba + vec2(1e-6, 0.0));
			lc = vec2(dot(pp, dir), dot(pp, vec2(-dir.y, dir.x)));
			reach = segp[i].x;
		}
	}
	vec4 t = tints[reg];
	float near = 1.0 - smoothstep(1.05, 1.5, best);     // the body's own lines, not the page's hatching
	vec3 col = mix(meat.rgb, t.rgb, t.a * near);
	float pulse = (reg == selected) ? 0.85 + 0.25 * motion * sin(TIME * 2.6) : 1.0;
	// the page's own hatching (round the body) a little dimmer than the body's lines
	vec3 o = col * (a * (0.45 + 0.75 * near) + bloom * (0.14 + 0.2 * near)) * mix(1.0, pulse, near);
	// chrome: a circuit spine down the limb (two rails, broken into runs, vias at the breaks, a
	// dotted trace between them, plate seams across), fading off the bone
	if (plated[reg] > 0.0 && reg != 1 && reach > px * 9.0 && best < 1.0) {   // (not the face)
		float ax = abs(lc.y) / reach;                     // 0 on the bone, 1 at its reach
		float fade = 1.0 - smoothstep(0.35, 0.8, ax);
		float u = lc.x / px;                              // screen pixels along the bone
		float off = abs(lc.y) / px;                       // and off it
		float rail_d = reach / px * 0.24;                 // the rails' distance off the bone
		float run = floor(u / 16.0);
		float side = sign(lc.y);
		float on = step(0.3, hash(vec2(run, side + float(reg) * 3.0)));
		float gapf = fract(u / 16.0);
		float rails = rule(off - rail_d, 0.9) * on * step(0.12, gapf);
		float via = on * (1.0 - smoothstep(1.3, 2.0, length(vec2((gapf - 0.12) * 16.0, off - rail_d))));
		float dots = rule(off, 0.9) * step(0.5, fract(u / 4.0));
		float seam = rule((fract(u / 22.0) - 0.5) * 22.0, 0.9) * (1.0 - step(rail_d + 2.0, off));
		float m = rails * 0.6 + via * 0.9 + dots * 0.3 + seam * 0.35;
		o += t.rgb * m * fade * pulse;
	}
	// external chrome: a dermal mesh over the whole body
	if (shell.a > 0.0) {
		float body = 1.0 - smoothstep(0.7, 1.0, best);
		vec2 q = UV / (px * 7.0);
		float mesh = max(rule((fract((q.x + q.y) * 0.5) - 0.5) * 14.0, 1.0), rule((fract((q.x - q.y) * 0.5) - 0.5) * 14.0, 1.0));
		o += shell.rgb * (mesh * 0.32 + 0.03) * body * shell.a;
	}
	// a slow scan line down the sheet
	if (motion > 0.0) {
		float sy = fract(TIME * 0.045) * 1.3 - 0.15;
		float band = exp(-pow((UV.y - sy) / (px * 14.0), 2.0));
		o += col * (a * 1.4 + 0.015) * band;
	}
	COLOR = vec4(o, 1.0);
}
