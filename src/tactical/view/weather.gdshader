shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;
// The weather over the play area (WeatherFx). Only over open sky: a square whose open-sky surface
// (Weather.surface: street, roof, bridge, water with nothing built over it) is in `sky_mask`; under a
// roof, inside a building and over a building the cutaway has opened, nothing shows (indoors stays
// dry). Particles are MultiMesh quads whose instance transform is a bare translation (the spot they
// land on); INSTANCE_CUSTOM = (phase, speed scale, unused, size scale).
// kind 0: rain streaks, falling `span` m at `speed`, slanting `wind` m across per m fallen, catching
//         the neon they fall past (the baked light field) and the lightning;
// kind 1: flakes (ash, ice glints): drifting down at `speed` with the wind (`wind` m/s);
// kind 2: motes (dust, radioactive grit, smog specks): blown along the wind over `span` m, bobbing;
// kind 3: haze (a horizontal layer): drifting noise over the open ground at street level, lit by
//         the neon below it, fading off the map.

uniform int kind = 0;
uniform vec4 col : source_color = vec4(1.0);
uniform float alpha = 0.5;
uniform float len = 0.7;
uniform float width = 0.04;
uniform float size = 0.06;
uniform float span = 9.0;
uniform float speed = 10.0;
uniform vec2 wind = vec2(0.0);
uniform float glow = 0.0;
uniform float day = 0.0;
uniform float street_f = 0.0;
uniform float haze_k = 0.0;
uniform float layer = 0.0;
uniform sampler2D sky_mask : filter_linear, repeat_disable;   // R: open ground at street level; G: (open surface floor + 1) / 255
uniform vec2 map_size = vec2(1.0);
global uniform vec3 cut_center;
global uniform float cut_radius;
global uniform vec4 focus_view;
global uniform sampler2D cut_map : filter_nearest, repeat_disable;
global uniform sampler2D lf_tex : filter_linear, repeat_disable;
global uniform vec3 lf_dims;
global uniform float weather_flash;

const float FH = 1.6;

varying float v_a;
varying vec3 v_lf;
varying vec3 v_w;

bool on_map(vec2 xz) {
	return xz.x >= 0.0 && xz.y >= 0.0 && xz.x < map_size.x && xz.y < map_size.y;
}

// the open-sky surface floor under xz, -1 if none; off the map: the street
float surface(vec2 xz) {
	if (!on_map(xz)) return street_f;
	return floor(texelFetch(sky_mask, ivec2(floor(xz)), 0).g * 255.0 + 0.5) - 1.0;
}

// nothing shows at `p`: inside a building (below the open surface), or over a building the cutaway has opened
bool hidden(vec3 p) {
	float fl = surface(p.xz);
	if (fl < 0.0 || p.y < fl * FH - 0.05) return true;
	if (cut_radius > 0.0 && on_map(p.xz)) {
		vec4 cm = texelFetch(cut_map, ivec2(floor(p.xz)), 0);
		if (cm.r > -0.5 && fl > cm.r + 0.5) return true;
	}
	return false;
}

vec3 field(vec2 xz, float fl) {
	if (lf_dims.x <= 0.0) return vec3(0.0);
	vec2 c = clamp(xz, vec2(0.5), lf_dims.xy - 0.5);
	fl = clamp(fl, 0.0, lf_dims.z - 1.0);
	vec2 uv = vec2(c.x / lf_dims.x, (fl * lf_dims.y + c.y) / (lf_dims.y * lf_dims.z));
	return textureLod(lf_tex, uv, 0.0).rgb;
}

void vertex() {
	v_a = alpha;
	v_lf = vec3(0.0);
	if (kind == 3) {
		v_w = VERTEX;
	} else {
		vec3 o = MODEL_MATRIX[3].xyz;
		vec2 q = (VERTEX - o).xy;
		vec4 cus = INSTANCE_CUSTOM;
		float t = fract(TIME * speed * cus.y / span + cus.x);
		vec3 c;
		if (kind == 0) {
			float fallen = t * span;
			c = o + vec3(0.0, span - fallen, 0.0) + vec3(wind.x, 0.0, wind.y) * (fallen - span);
			vec3 d = normalize(vec3(-wind.x, 1.0, -wind.y));
			vec3 across = normalize(cross(d, INV_VIEW_MATRIX[2].xyz));
			VERTEX = c + across * q.x * width * cus.w + d * (q.y + 0.5) * len * cus.w;
			v_a *= smoothstep(0.0, 0.06, t);
		} else if (kind == 1) {
			float fallen = t * span;
			vec3 sway = vec3(sin(TIME * 0.9 + cus.x * 40.0), 0.0, cos(TIME * 0.7 + cus.x * 31.0)) * 0.3;
			c = o + vec3(0.0, span - fallen, 0.0) + vec3(wind.x, 0.0, wind.y) * (fallen - span) / max(speed, 0.05) + sway;
			VERTEX = c + (INV_VIEW_MATRIX[0].xyz * q.x + INV_VIEW_MATRIX[1].xyz * q.y) * size * cus.w;
			v_a *= smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.92, 1.0, t));
		} else {
			vec2 wd = length(wind) > 0.001 ? normalize(wind) : vec2(1.0, 0.0);
			c = o + vec3(wd.x, 0.0, wd.y) * (t - 0.5) * span + vec3(0.0, sin(TIME * 1.3 + cus.x * 50.0) * 0.18, 0.0);
			vec3 along = vec3(wd.x, 0.0, wd.y);
			VERTEX = c + along * q.y * size * 3.0 * cus.w + INV_VIEW_MATRIX[1].xyz * q.x * size * cus.w;
			v_a *= sin(3.14159 * t);
		}
		if (hidden(c)) v_a = 0.0;
		v_lf = field(c.xz, floor(c.y / FH + 0.02));
		v_w = c;
	}
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	float a = v_a;
	if (a <= 0.003) discard;
	// the see-through hole round the focus (as the skyline's): nothing up in the air hides the crew
	if (kind != 3 && focus_view.w > 0.0 && v_w.y > cut_center.y * FH + 0.9 && -VERTEX.z < focus_view.z - 1.5) {
		float r = length((SCREEN_UV - focus_view.xy) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0)) / focus_view.w;
		a *= smoothstep(0.55, 1.0, r);
	}
	vec3 c = col.rgb;
	float fl = weather_flash;
	if (kind == 0) {
		a *= 0.35 + 0.65 * UV.y;   // a pixel wide: no falloff across, the tail fading up
		c = col.rgb * mix(0.7, 0.95, day) + v_lf * 1.4 * (1.0 - 0.6 * day) + vec3(0.8, 0.85, 1.0) * fl * 1.3;
		a = min(1.0, a * (1.0 + fl * 0.8 + length(v_lf) * 0.8));
	} else if (kind == 1 || kind == 2) {
		float d = length(UV - 0.5) * 2.0;
		a *= smoothstep(1.0, 0.3, d);
		c = col.rgb * mix(0.55 + glow * 0.6, 1.0, day) + v_lf * 0.7 * (1.0 - 0.6 * day) + vec3(0.8, 0.85, 1.0) * fl * 0.6;
	} else {
		vec2 xz = v_w.xz;
		float n = noise(xz * 0.07 + wind * TIME * 0.02 + layer * 7.3) * 0.62 + noise(xz * 0.17 - wind.yx * TIME * 0.03 + layer * 3.1) * 0.38;
		float open = texture(sky_mask, xz / map_size).r;
		vec2 beyond = max(max(-xz, xz - map_size), 0.0);
		float off = 1.0 - smoothstep(0.0, 28.0, length(beyond));
		a = haze_k * smoothstep(0.28, 0.8, n) * open * off;
		if (a <= 0.003) discard;
		vec3 lf = field(xz, street_f);
		c = col.rgb + lf * 0.45 * (1.0 - 0.7 * day) + vec3(0.6, 0.65, 0.8) * fl * 0.5;
	}
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0);
}
