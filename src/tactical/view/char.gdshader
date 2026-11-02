shader_type spatial;
// Skinned characters (CharModel). Same lighting contract as unit.gdshader: real lights shade them,
// and the baked light field (global lf_tex) adds local neon spill and a rim so bodies sit in the
// scene. Clothing is painted by region: the base body's vertex COLOR.r carries a region id baked
// from bone weights (0 skin, 1 jacket, 2 sleeve, 3 pants, 4 boots, 5 gloves, 6 belt, 7 collar),
// and each region takes a flat cloth colour with the texture's shading kept faintly for folds.
// mode: 0 body (regions), 1 tinted texture (hair, brows), 2 flat albedo (gear), 3 texture as-is (eyes).

uniform int mode = 2;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec3 skin : source_color = vec3(0.75, 0.55, 0.42);
uniform vec3 jacket : source_color = vec3(0.25, 0.4, 0.55);
uniform vec3 sleeve : source_color = vec3(0.25, 0.4, 0.55);
uniform vec3 pants : source_color = vec3(0.2, 0.22, 0.28);
uniform vec3 boots : source_color = vec3(0.12, 0.13, 0.15);
uniform vec3 gloves : source_color = vec3(0.1, 0.1, 0.12);
uniform vec3 trim : source_color = vec3(0.0, 0.85, 0.9);    // belt light and collar edge (accent)
uniform float trim_glow = 1.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.6;
uniform float flash = 0.0;
uniform bool use_field = true;
global uniform sampler2D lf_tex : filter_linear, repeat_disable;
global uniform vec3 lf_dims;

varying vec3 wpos;
varying vec3 wn;
varying flat int region;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	region = int(COLOR.r * 8.0 + 0.5);
}

vec3 field(vec2 c, float fl) {
	vec2 uv = vec2(c.x / lf_dims.x, (fl * lf_dims.y + clamp(c.y, 0.5, lf_dims.y - 0.5)) / (lf_dims.y * lf_dims.z));
	return texture(lf_tex, uv).rgb;
}

void fragment() {
	vec3 base = albedo.rgb;
	vec3 emit = emission * emission_energy;
	float rough = roughness;
	if (mode == 0) {
		vec3 t = texture(tex, UV).rgb;
		float lum = dot(t, vec3(0.299, 0.587, 0.114));
		if (region == 0) {
			base = skin * (0.55 + 0.9 * lum);           // the texture's face and muscle shading, re-toned
		} else {
			vec3 c = region == 1 ? jacket : region == 2 ? sleeve : region == 3 ? pants : region == 4 ? boots
				: region == 5 ? gloves : region == 6 ? trim * 0.3 : jacket * 0.7;
			base = c * (0.85 + 0.3 * lum);             // faint folds, mostly flat cloth
			rough = region == 4 || region == 5 ? 0.4 : 0.75;
			if (region == 6) emit += trim * trim_glow * 0.9;
		}
	} else if (mode == 1) {
		vec3 t = texture(tex, UV).rgb;
		base = albedo.rgb * (0.35 + 1.1 * dot(t, vec3(0.299, 0.587, 0.114)));
	} else if (mode == 3) {
		base = texture(tex, UV).rgb;
	}
	ALBEDO = mix(base, vec3(1.0), flash);
	ROUGHNESS = rough;
	if (use_field && lf_dims.x > 0.0) {
		float fl = clamp(floor(wpos.y / 1.6 + 0.02), 0.0, lf_dims.z - 1.0);
		vec3 here = field(wpos.xz, fl);
		vec3 faced = field(wpos.xz + wn.xz * 0.6, fl);
		vec3 lf = max(here, faced) * 0.6 + faced * 0.4;
		float pk = max(lf.r, max(lf.g, lf.b));
		lf *= 1.0 / (1.0 + pk * 0.6);
		emit += base * lf * 0.5;
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		emit += lf / max(pk, 0.15) * min(pk, 1.0) * fres * 0.25;
	}
	EMISSION = emit + vec3(flash * 0.8);
}
