shader_type canvas_item;
// The cyberware figure (BodyAnatomy): an engraved anatomical plate (Milton's man, Bell's woman) as light on the dark page.
// TEXTURE (tools/gen_anatomy_ink.py): R the plate printed as light (the paper inside him glows, the
// engraver's lines stay dark: his hatching models the form), G the figure's silhouette, B the deep
// plate the same way (the skeleton, warped onto him), A his outline. A bloom from the mip chain
// softens it.
// The figure is always the hybrid (owner: "aesthetically I prefer the look of the skeletal hybrid
// images... drop the skin on versions"): the deep plate's bones everywhere, the surface plate a faint
// body over them (`skin`, its share of the print).
// The glitch (owner, on an early prototype: "I very much like the horizontal glitch fuzziness"): every
// scan row is nudged sideways a little, and broken horizontal hatching runs off the figure's edges,
// fading out from the body; with motion on, bands of rows now and then tear sideways and the
// hatching re-rolls in steps, and a slow scan line runs down. Under reduced motion all of it holds
// still.
// Bones laid over the figure (segs) give each pixel its body region: its lines take the region's
// tint (cyan meat, violet chrome, gold for the selected location). A chromed region is violet, its
// bones brighter and more bare (the body over them fainter, a glint on their highlights), and a
// chromed limb gets a circuit spine along the bone; external chrome (shell) is a dermal mesh over the
// whole skin.
render_mode blend_add;

uniform vec4 segs[24];          // per bone: from.xy, to.xy (uv)
uniform vec4 segp[24];          // x: reach (uv x units), y: region, z: 1 = a small feature (eye, ear) that wins inside its reach
uniform int nseg = 0;
uniform vec4 tints[11];         // per region: colour, a = how much (0 = meat)
uniform float plated[11];
uniform vec4 meat : source_color = vec4(0.02, 0.85, 0.91, 1.0);
uniform vec4 shell = vec4(0.0);  // external chrome: colour, a = strength
uniform int selected = -1;
uniform float motion = 1.0;
uniform vec2 px = vec2(0.002, 0.001);   // one screen pixel, in uv
uniform float aspect = 0.5;     // the texture's width over its height (uv x units per uv y unit)
uniform float gain = 0.72;      // the print's light
uniform float skin = 0.22;      // the surface plate's share of the print over the bones (the hybrid)
uniform float edge = 0.32;      // the outline's
uniform float fuzz = 1.0;       // the horizontal glitch's strength

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// A thin line where |v| is near 0: `w` wide, in the same units as v.
float rule(float v, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.6, abs(v));
}

void fragment() {
	// --- the glitch: rows nudged sideways ---
	float row = floor(UV.y / (px.y * 2.0));                    // two-pixel scan rows
	float step_t = motion > 0.0 ? floor(TIME * 7.0) : 0.0;      // the smear re-rolls in steps
	float burst = motion > 0.0 ? floor(TIME * 0.7) : 0.0;       // tears come and go
	float rh = hash(vec2(row, 3.1));
	float jit = (hash(vec2(row, step_t * 0.37 + 1.7)) - 0.5) * 1.4;   // under a pixel either way, every row
	float band = floor(UV.y / (px.y * 9.0));                   // a tear: a band of rows, shoved
	float tear = step(0.95, hash(vec2(band, burst))) * motion;
	jit += tear * (hash(vec2(band, burst + 9.0)) - 0.5) * 18.0;
	vec2 uv = UV + vec2(jit * px.x * fuzz, 0.0);

	// (sampled with the page's own gradients: the rows' jumps mustn't blur the mip choice)
	vec2 gx = dFdx(UV);
	vec2 gy = dFdy(UV);
	vec4 tx = textureGrad(TEXTURE, uv, gx, gy);
	float sil = tx.g;
	vec4 b1 = textureLod(TEXTURE, uv, 2.5);
	vec4 b2 = textureLod(TEXTURE, uv, 4.0);

	// --- the region: the nearest bone, as a fraction of its reach (eyes and ear win inside theirs) ---
	vec2 q = vec2(uv.x, uv.y / aspect);                        // isotropic: uv x units
	float best = 1e9;
	int reg = 0;
	float second = 1e9;    // the nearest bone of another region: the two blend at the seam
	int reg2 = 0;
	vec2 lc = vec2(0.0);
	float reach = 0.02;
	bool locked = false;   // inside an eye's or the ear's reach
	for (int i = 0; i < nseg; i++) {
		vec2 pa = vec2(segs[i].x, segs[i].y / aspect);
		vec2 ba = vec2(segs[i].z, segs[i].w / aspect) - pa;
		vec2 pp = q - pa;
		float t = clamp(dot(pp, ba) / max(dot(ba, ba), 1e-9), 0.0, 1.0);
		float d = length(pp - ba * t) / segp[i].x;
		bool small = segp[i].z > 0.5;
		bool win = small ? d < 1.0 && (!locked || d < best) : !locked && d < best;
		int r = int(segp[i].y);
		if (win) {
			if (r != reg && !small) {
				second = best;
				reg2 = reg;
			}
			if (small && !locked) {
				second = 1e9;   // an eye or the ear: crisp
			}
			locked = locked || small;
			best = d;
			reg = r;
			vec2 dir = normalize(ba + vec2(1e-6, 0.0));
			lc = vec2(dot(pp, dir), dot(pp, vec2(-dir.y, dir.x)));
			reach = segp[i].x;
		} else if (!locked && r != reg && d < second) {
			second = d;
			reg2 = r;
		}
	}
	float kb = 0.5 + 0.5 * smoothstep(0.0, 0.16, second - best);   // 1: all the nearest region's
	vec4 t = mix(tints[reg2], tints[reg], kb);
	float body = smoothstep(0.2, 0.6, sil);
	vec3 col = mix(meat.rgb, t.rgb, t.a * body);
	// the selected place: brighter (gold reads olive when dim), pulsing with motion on
	float pulse = (reg == selected) ? (1.4 + 0.3 * motion * sin(TIME * 2.6)) * kb + (1.0 - kb) : 1.0;
	// the hybrid: the bones with a faint body over them; chrome bares and brightens them
	float chrome = body * mix(plated[reg2], plated[reg], kb);
	float sk = skin * (1.0 - 0.45 * chrome);
	float print_ = mix(tx.b, tx.r, sk);
	float bl = mix(b1.b * 0.6 + b2.b * 0.4, b1.r * 0.6 + b2.r * 0.4, sk);
	float muscle = print_ * gain * (1.0 + 0.15 * chrome) + tx.a * edge;
	vec3 o = col * (muscle + bl * 0.22 + (b1.a * 0.6 + b2.a * 0.4) * 0.25) * pulse;
	o += vec3(1.0) * smoothstep(0.8, 1.0, print_) * (0.1 + 0.06 * chrome);   // the highlights whiten (chrome glints)

	// --- the fuzz: horizontal hatching off his edges, the rows fading out from the body (as
	// an engraver shades a figure's flanks), patchy along the contour, every other row or so ---
	if (body < 0.5) {
		float dist = 99.0;   // to the body along the row, in pixels, either side
		for (int k = 1; k <= 14; k++) {
			float dx = float(k) * 3.0;
			float hit = max(textureLod(TEXTURE, uv + vec2(dx * px.x, 0.0), 0.0).g, textureLod(TEXTURE, uv - vec2(dx * px.x, 0.0), 0.0).g);
			if (hit > 0.5 && dist > 98.0) {
				dist = dx;
			}
		}
		float on = step(0.36, rh) * (0.55 + 0.45 * hash(vec2(row, 7.7)));
		float len = mix(6.0, 24.0, hash(vec2(row, step_t + 5.0)));
		float patch = smoothstep(0.25, 0.75, hash(vec2(floor(UV.y / (px.y * 26.0)), 2.3)));
		float dash = step(0.18, hash(vec2(row, floor(UV.x / (px.x * 9.0)) + step_t)));
		o += meat.rgb * exp(-dist / len) * on * dash * mix(0.35, 1.0, patch) * 0.3 * fuzz;
	}

	// --- chrome: a circuit spine down the limb (two rails, broken into runs, vias at the breaks,
	// a dotted trace between them, plate seams across), fading off the bone (not the face) ---
	if (plated[reg] > 0.0 && reg != 1 && reach > px.x * 9.0 && best < 1.0) {
		float ax = abs(lc.y) / reach;
		float fade = (1.0 - smoothstep(0.35, 0.8, ax)) * body;
		float u = lc.x / px.x;
		float off = abs(lc.y) / px.x;
		float rail_d = reach / px.x * 0.24;
		float run = floor(u / 16.0);
		float side = sign(lc.y);
		float onr = step(0.3, hash(vec2(run, side + float(reg) * 3.0)));
		float gapf = fract(u / 16.0);
		float rails = rule(off - rail_d, 0.9) * onr * step(0.12, gapf);
		float via = onr * (1.0 - smoothstep(1.3, 2.0, length(vec2((gapf - 0.12) * 16.0, off - rail_d))));
		float dots = rule(off, 0.9) * step(0.5, fract(u / 4.0));
		float seam = rule((fract(u / 22.0) - 0.5) * 22.0, 0.9) * (1.0 - step(rail_d + 2.0, off));
		o += t.rgb * (rails * 0.55 + via * 0.85 + dots * 0.3 + seam * 0.3) * fade * pulse;
	}
	// external chrome: a dermal mesh over the skin
	if (shell.a > 0.0) {
		vec2 m = vec2(UV.x / px.x, UV.y / px.y) / 7.0;
		float mesh = max(rule((fract((m.x + m.y) * 0.5) - 0.5) * 14.0, 1.0), rule((fract((m.x - m.y) * 0.5) - 0.5) * 14.0, 1.0));
		o += shell.rgb * (mesh * 0.3 + 0.03) * body * shell.a;
	}
	// a slow scan line down the figure
	if (motion > 0.0) {
		float sy = fract(TIME * 0.045) * 1.3 - 0.15;
		float sb = exp(-pow((UV.y - sy) / (px.y * 14.0), 2.0));
		o += col * (muscle * 1.2 + 0.02 * body) * sb;
	}
	COLOR = vec4(o, 1.0);
}
