shader_type spatial;
// Everything in the tactical world: lit surface + fog of war from a per-cell texture.
// fog texture: one row block per floor (h rows each); value 0 unknown, ~0.5 explored, 1 visible.
// mode 0: normal surface (hidden when unknown); 1: "unknown" cap (shown only when unknown);
// mode 2: always shown (ignores fog).

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform sampler2D fog : filter_nearest;
uniform vec2 map_size = vec2(1.0);
uniform float floor_idx = 0.0;
uniform float floors = 1.0;
uniform int mode = 0;
uniform float explored_dim = 0.38;

varying flat vec2 cell;

void vertex() {
	cell = floor((MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
}

void fragment() {
	float f = 1.0;
	if (mode != 2) {
		vec2 uv = vec2((cell.x + 0.5) / map_size.x, (floor_idx * map_size.y + cell.y + 0.5) / (map_size.y * floors));
		f = texture(fog, uv).r;
	}
	if (mode == 0 && f < 0.25) discard;
	if (mode == 1 && f >= 0.25) discard;
	float k = (mode == 0 && f < 0.75) ? explored_dim : 1.0;
	vec3 base = albedo.rgb;
	if (k < 1.0) base = mix(vec3(dot(base, vec3(0.3, 0.59, 0.11))), base, 0.4) * k;
	ALBEDO = base;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	EMISSION = emission * emission_energy * k;
}
