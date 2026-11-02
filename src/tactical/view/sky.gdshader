shader_type sky;
// Night City sky: near-black zenith, polluted magenta-orange glow on the horizon from the city.
uniform vec3 zenith : source_color = vec3(0.01, 0.012, 0.03);
uniform vec3 mid : source_color = vec3(0.05, 0.03, 0.09);
uniform vec3 horizon : source_color = vec3(0.32, 0.1, 0.16);

void sky() {
	float h = clamp(EYEDIR.y, -1.0, 1.0);
	vec3 c = mix(horizon, mid, smoothstep(0.0, 0.18, h));
	c = mix(c, zenith, smoothstep(0.15, 0.6, h));
	if (h < 0.0) c = horizon * 0.4;
	COLOR = c;
}
