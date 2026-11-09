shader_type spatial;
render_mode cull_back;
// Tower facades (TowerDress): the impostor facade under a tower band and the far city's towers.
// style 0: the band's own facade carried down: a mask texture (one row per face: -z, +z, -x, +x;
// one texel per square from the plate's corner) says what the band's lowest storey has in each
// square of its outer wall (r: 1 solid wall, 2 glass run, 3 punched window; g: its room), so the
// storeys below repeat it exactly, rooms lit or dark storey by storey (TowerLook.room_lit odds).
// The solid wall is world.gdshader's panel pattern (7) in the same colours, so there is no seam
// where the band's real walls stop and the impostor starts (owner, V1 verdicts).
// styles 1-4 (setback tiers, the far city): curtain wall, ribbon windows, punched grid, panels.
// per_instance (the far city): INSTANCE_CUSTOM = (seed, lit share, warm share, style), COLOR =
// (accent rgb, seam density).

uniform int style = 0;
uniform bool per_instance = false;
uniform vec3 glass_col : source_color = vec3(0.04);
uniform vec3 spandrel_col : source_color = vec3(0.12);
uniform vec3 mullion_col : source_color = vec3(0.05);
uniform vec3 slab_col : source_color = vec3(0.16);
uniform vec3 warm_a : source_color = vec3(1.0, 0.78, 0.56);
uniform vec3 warm_b : source_color = vec3(1.0, 0.69, 0.44);
uniform vec3 cool_a : source_color = vec3(0.67, 0.96, 1.0);
uniform vec3 cool_b : source_color = vec3(0.87, 0.9, 0.92);
uniform float warm_share = 0.5;
uniform float lit_share = 0.32;
uniform float dark_floors = 0.2;
uniform float sill = 0.32;
uniform float lintel = 1.32;
uniform float mullion_step = 0.5;
uniform float mullion_w = 0.05;
uniform float bay = 3.0;
uniform vec3 seam_col : source_color = vec3(0.0);
uniform float seam_every = 0.0;
uniform float seam_glow = 1.0;
uniform vec3 ledge_col : source_color = vec3(0.0);
uniform float ledge_every = 0.0;
uniform float mech_every = 12.0;
uniform float storey0 = 1.0;        // the storey whose floor is at y = 0 (the band's lowest)
uniform vec4 plate = vec4(0.0);     // the facade's extent: x0, z0, x1, z1 (seams keep a square off its corners)
uniform vec2 origin = vec2(0.0);    // seams and rooms are measured from here
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform float seed = 0.0;
uniform vec3 smog_col : source_color = vec3(0.16, 0.13, 0.22);
uniform float bounce = 0.5;         // the city's light bouncing up off the smog onto the lower storeys
uniform float win_glow = 1.0;
uniform float flood = 0.0;          // the facade floodlit in its own colour
uniform vec3 flood_col : source_color = vec3(0.0);
uniform bool day = false;
uniform vec3 sky_col : source_color = vec3(0.6, 0.66, 0.72);
uniform float haze = 0.0;           // far towers: their colour sinks into the smog with depth
uniform vec3 cast_col : source_color = vec3(1.0);   // the weather's cast (Atmosphere cast): the far city and the shaft deep in the smog
uniform float cast_k = 0.0;
uniform float wet = 0.0;            // rain on the glass (Atmosphere wet): a sheen and runnels down the panes
uniform vec2 map_size = vec2(1.0);
global uniform vec3 cut_center;
global uniform vec2 cut_dir;
global uniform vec4 focus_view;

const float FH = 1.6;

varying vec3 wpos;
varying vec3 wnorm;
varying vec4 inst;
varying vec4 acc;
varying vec4 ext;   // the box's footprint: x0, z0, x1, z1
varying float top_y;   // the box's top (a far tower lights its crown, not its whole shaft)

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	inst = per_instance ? INSTANCE_CUSTOM : vec4(seed, lit_share, warm_share, float(style));
	acc = per_instance ? COLOR : vec4(seam_col, seam_every > 0.0 ? 1.0 : 0.0);
	vec2 c = MODEL_MATRIX[3].xz;
	vec2 hs = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz)) * 0.5;
	ext = per_instance ? vec4(c - hs, c + hs) : plate;
	top_y = MODEL_MATRIX[3].y + length(MODEL_MATRIX[1].xyz) * 0.5;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float h3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.62 + noise(p * 2.13) * 0.38; }
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
	return (float(m[x + y * 4]) + 0.5) / 16.0 - 0.5;
}
float line(float x, float w) { float d = abs(fract(x) - 0.5); return smoothstep(0.5 - w, 0.5, d); }

void fragment() {
	float bay4 = bayer4(FRAGCOORD.xy);
	// as world.gdshader mode 2: dissolve on the camera side above the band's first storey, and in
	// the see-through hole round the focus
	if (dot(wpos.xz - cut_center.xz, cut_dir) < -4.0 && wpos.y > 1.2 && wpos.x > -0.5 && wpos.x < map_size.x + 80.0) {
		float far = smoothstep(4.0, 9.0, -dot(wpos.xz - cut_center.xz, cut_dir));
		if (far > bay4 + 0.5) discard;
	}
	if (focus_view.w > 0.0 && wpos.y > cut_center.y * 1.6 + 0.9 && -VERTEX.z < focus_view.z - 1.5) {
		float r = length((SCREEN_UV - focus_view.xy) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0)) / focus_view.w;
		if (smoothstep(0.7, 1.0, r) < bay4 + 0.5) discard;
	}
	vec3 n = normalize(wnorm);
	float sd = mod(inst.x, 997.0);
	int sty = int(inst.w + 0.5);
	vec3 base;
	vec3 emit = vec3(0.0);
	float rough = 0.85;
	float metal = 0.0;
	float depth = smoothstep(-6.0, -64.0, wpos.y);   // how far down into the smog
	if (abs(n.y) > 0.5) {   // roofs, terraces and ledge tops
		base = mix(spandrel_col, slab_col, 0.35) * 0.6;
		rough = 0.8;
	} else {
		bool xf = abs(n.x) > abs(n.z);
		float along = xf ? wpos.z : wpos.x;
		float face = xf ? (n.x > 0.0 ? 3.0 : 2.0) : (n.z > 0.0 ? 1.0 : 0.0);
		float lo = xf ? ext.y : ext.x;
		float hi = xf ? ext.w : ext.z;
		float o = per_instance ? lo : (xf ? origin.y : origin.x);
		float sy = wpos.y / FH;
		float st = floor(sy);
		float h = (sy - st) * FH;
		float storey = storey0 + st;
		float fw = max(fwidth(along), 1e-4);   // world units per pixel
		// what this square of the facade holds: 1 solid wall, 2 glass, 3 punched window, 4 panel window
		float kind = 2.0;
		float room;
		if (sty == 0) {
			float cell = floor(along) - (xf ? origin.y : origin.x);
			vec4 mk = texelFetch(mask, ivec2(int(clamp(cell, 0.0, 255.0)), int(face)), 0);
			kind = floor(mk.r * 255.0 / 60.0 + 0.5);
			room = floor(mk.g * 255.0 + 0.5) + face * 301.0;
		} else {
			kind = sty == 3 ? 3.0 : (sty == 4 ? 4.0 : 2.0);
			room = floor((along - o) / bay) + face * 301.0;
		}
		float s0 = sty == 1 ? 0.14 : (sty == 2 ? 0.42 : sill);
		float s1 = sty == 1 ? 1.46 : (sty == 2 ? 1.18 : lintel);
		// the solid wall: world.gdshader's panels and storey seams, its contact shade at each foot
		vec2 p7 = vec2(wpos.x + wpos.z, wpos.y);
		float n7 = fbm(p7 * 3.0);
		base = spandrel_col * (0.88 + hash(floor(vec2(p7.x * 0.75, p7.y * 0.625))) * 0.12 + n7 * 0.08);
		base = mix(base, spandrel_col * 0.58, max(line(p7.x * 0.75, 0.012), line(p7.y * 0.625 + 0.5, 0.02)));
		base *= 1.0 - smoothstep(0.55, 0.9, noise(vec2(p7.x * 6.0, p7.y * 0.3))) * 0.18;
		base *= mix(0.6, 1.0, smoothstep(0.0, 0.6, h));
		bool mech = mech_every > 0.0 && storey < storey0 && mod(storey + floor(sd), mech_every) < 0.5;
		bool pane = false;
		float pw = 0.0;   // across the pane, 0..1 from its sill
		if (mech) {   // a plant storey: louvres all round, a vent's dark mouth here and there
			float lv = line(wpos.y * 7.0, 0.22);
			base = mix(spandrel_col * 0.75, mullion_col, lv * 0.8);
			if (h3(vec3(floor(along / 2.0), storey, sd)) < 0.25 && h > 0.3 && h < 1.3) base *= 0.45;
		} else if (kind == 2.0 && h > s0 && h < s1) {
			pane = true;
			pw = (h - s0) / (s1 - s0);
		} else if (kind == 3.0 && abs(fract(along) - 0.5) < 0.23 && h > 0.42 && h < 1.2) {
			pane = true;
			pw = (h - 0.42) / 0.78;
		} else if (kind == 4.0 && abs(fract(along * 2.0) - 0.5) < 0.2 && h > 0.4 && h < 1.2) {
			pane = true;
			pw = (h - 0.4) / 0.8;
		}
		if (pane) {
			float pid = floor(along / mullion_step);
			bool lit = h3(vec3(storey, 0.0, sd + 1.0)) >= dark_floors
				&& (h3(vec3(storey, 0.0, sd + 2.0)) < 0.06 || h3(vec3(storey, room, sd + 3.0)) < inst.y);
			base = glass_col * (0.85 + 0.3 * hash(vec2(pid, storey)));
			rough = 0.12;
			metal = 0.35;
			if (day) {   // the sky in the glass: brighter up the pane, a little different pane to pane
				base = mix(glass_col, sky_col, 0.45 + 0.2 * hash(vec2(pid * 0.37, storey)));
				emit += sky_col * (0.06 + 0.1 * pw) * (0.7 + 0.6 * hash(vec2(floor(along / 2.0), floor(storey / 3.0))));
				metal = 0.6;
				emit += sky_col * 0.22 * smoothstep(0.86, 1.0, sin((along + wpos.y * 0.6) * 0.11 + face * 1.7 + sd));   // a sweep of sky across the glass
			} else {   // the lit smog below in the glass, strongest low in each pane, and now and then
				// a neighbour's lights caught in it
				emit += mix(smog_col, vec3(0.1, 0.14, 0.26), 0.5) * bounce * (0.45 + 0.75 * (1.0 - pw)) * (0.8 + 0.4 * hash(vec2(floor(along / 4.0), floor(storey / 5.0))));
				float spk = step(0.93, hash(vec2(floor(along * 3.0) + sd, floor(wpos.y * 4.0))));
				emit += mix(vec3(1.0, 0.45, 0.6), vec3(0.4, 0.8, 1.0), hash(vec2(floor(along), storey))) * spk * 0.25 * bounce;
			}
			if (wet > 0.0) {   // rain on the glass: glossier, runnels catching the light below
				rough = mix(rough, 0.04, wet);
				float rn = step(0.86, hash(vec2(floor(along * 5.0) + sd, floor(wpos.y * 0.7 - TIME * 1.3 + hash(vec2(floor(along * 5.0), sd)) * 9.0))));
				emit += (day ? sky_col * 0.18 : mix(smog_col, cast_col, 0.5) * 0.22) * rn * wet;
			}
			if (lit) {
				float wsel = h3(vec3(storey, room, sd + 4.0));
				float pick = h3(vec3(storey, room, sd + 5.0));
				vec3 lc = wsel < inst.z ? mix(warm_a, warm_b, step(0.5, pick)) : mix(cool_a, cool_b, step(0.5, pick));
				float inten = 0.6 + 0.4 * h3(vec3(storey, room, sd + 6.0));
				if (hash(vec2(pid + sd, storey)) < 0.22) inten *= 0.35;   // blinds down
				inten *= mix(0.82, 1.12, pw) + step(0.9, pw) * 0.25;      // the ceiling's light strip
				if (h3(vec3(storey, room, sd + 7.0)) < 0.035)   // a failing tube
					inten *= 0.2 + 0.8 * step(0.35, fract(sin(floor(TIME * 9.0) * 12.9898 + room) * 43758.5));
				base = lc * 0.18;
				emit += lc * inten * win_glow * (day ? 0.12 : 1.0);
			}
			// mullions (they fade to the glass once they would be under a pixel apart)
			float md = abs(fract(along / mullion_step + 0.5) - 0.5) * mullion_step;
			float vis = smoothstep(1.6, 3.0, mullion_step / fw);
			float mw = max(mullion_w * 0.5, fw * 0.5);
			if (md < mw) {
				base = mix(base, mullion_col, vis);
				emit *= 1.0 - vis;
			}
			if (pw < 0.04 / (s1 - s0) || pw > 1.0 - 0.06 / (s1 - s0)) {   // the frame at the sill, the lintel's shadow
				base = mix(base, mullion_col, 0.8);
				emit *= 0.3;
			}
		} else if (!mech) {
			if (h < 0.12 || (kind == 1.0 && h > 1.508 && h < 1.588)) base = slab_col * (0.85 + n7 * 0.2);   // slab edge, cornice
			if (ledge_every > 0.0 && mod(storey, ledge_every) < 0.5 && h > s1 + 0.03 && h < s1 + 0.12 && storey < storey0)
				emit += ledge_col * (day ? 0.25 : 1.1);
		}
		if (!pane) emit += flood_col * flood;   // floodlit (the band's skin glows the same: TowerDress.wall_over)
		// vertical light seams
		float every = per_instance ? 3.0 + floor(h3(vec3(sd, 1.0, 9.0)) * 5.0) : seam_every;
		float crown = per_instance ? 1.0 - smoothstep(6.0, 14.0, top_y - wpos.y) : 1.0;   // far towers: the top storeys only
		if (every > 0.0 && acc.a > 0.0 && crown > 0.0 && along > lo + 1.0 && along < hi - 1.0) {
			float d = abs(fract((along - o) / every + 0.5) - 0.5) * every;
			if (d < max(0.035, fw * 0.55)) {
				base = acc.rgb * 0.3 * crown;
				emit = acc.rgb * seam_glow * (day ? 0.3 : 1.0) * (per_instance ? 0.8 : 1.0) * crown;
			}
		}
	}
	if (!day)
		emit += smog_col * bounce * depth * 0.3;   // the city's light, up off the smog
	if (haze > 0.0) {
		float k = haze * smoothstep(-10.0, -70.0, wpos.y);
		base = mix(base, smog_col * (day ? 0.9 : 0.45), k);
		emit *= 1.0 - k * 0.5;
	}
	if (cast_k > 0.0) {   // the weather's cast: the far city (by distance and depth), the shaft deep down
		vec2 mid = (plate.xy + plate.zw) * 0.5;
		float far = per_instance ? max(smoothstep(18.0, 110.0, length(wpos.xz - mid)), smoothstep(-4.0, -40.0, wpos.y)) : smoothstep(-8.0, -56.0, wpos.y);
		float kc = cast_k * far;
		base = mix(base, base * cast_col * 1.3 + cast_col * (day ? 0.12 : 0.025), kc);
		emit = mix(emit, emit * cast_col * 1.25 + cast_col * length(emit) * 0.15, kc * 0.75);
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
