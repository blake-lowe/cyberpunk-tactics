shader_type spatial;
// Character parts. Real lights (lamps, signs, the crew light) shade them as usual; on top, the
// same baked light field the world uses (global lf_tex) colours them, so a unit under a magenta
// sign picks up magenta: spill on the side facing the light plus a neon rim tinted by the local
// light. Mirrors world.gdshader's sampling (4 texels per square, one row block per floor).

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.55;
uniform float flash = 0.0;          // hit flash (juice): 0..1 pushes toward white
uniform bool use_field = true;      // off for the portrait studio (not in the map)
global uniform sampler2D lf_tex : filter_linear, repeat_disable;
global uniform vec3 lf_dims;        // map w, h, floors

varying vec3 wpos;
varying vec3 wn;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 field(vec2 c, float fl) {
	vec2 uv = vec2(c.x / lf_dims.x, (fl * lf_dims.y + clamp(c.y, 0.5, lf_dims.y - 0.5)) / (lf_dims.y * lf_dims.z));
	return texture(lf_tex, uv).rgb;
}

void fragment() {
	ALBEDO = mix(albedo.rgb, vec3(1.0), flash);
	ROUGHNESS = roughness;
	vec3 emit = emission * emission_energy;
	if (use_field && lf_dims.x > 0.0) {
		float fl = clamp(floor(wpos.y / 1.6 + 0.02), 0.0, lf_dims.z - 1.0);
		// light at the surface, nudged toward where the surface faces (that side catches more)
		vec3 here = field(wpos.xz, fl);
		vec3 faced = field(wpos.xz + wn.xz * 0.6, fl);
		vec3 lf = max(here, faced) * 0.6 + faced * 0.4;
		float pk = max(lf.r, max(lf.g, lf.b));
		lf *= 1.0 / (1.0 + pk * 0.6);
		emit += albedo.rgb * lf * 0.5;   // match the world's spill so units blend in
		// neon rim: grazing angles glow in the local light colour
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		emit += lf / max(max(lf.r, max(lf.g, lf.b)), 0.15) * min(pk, 1.0) * fres * 0.25;   // subtle neon rim
	}
	EMISSION = emit + vec3(flash * 0.8);
}
