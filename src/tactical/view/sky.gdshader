shader_type sky;
// Night City sky: near-black zenith, polluted magenta-orange glow on the horizon from the city.
// Below the horizon: `below` (the dark ground, horizon x 0.4, by default; a tower band's lit smog,
// greybox LOOKS smog), reached from the horizon over `below_blend` (0: a hard edge, as it always was).
uniform vec3 zenith : source_color = vec3(0.01, 0.012, 0.03);
uniform vec3 mid : source_color = vec3(0.05, 0.03, 0.09);
uniform vec3 horizon : source_color = vec3(0.32, 0.1, 0.16);
uniform vec3 below : source_color = vec3(0.128, 0.04, 0.064);
uniform float below_blend = 0.0;

void sky() {
	float h = clamp(EYEDIR.y, -1.0, 1.0);
	vec3 c = mix(horizon, mid, smoothstep(0.0, 0.18, h));
	c = mix(c, zenith, smoothstep(0.15, 0.6, h));
	if (h < 0.0) c = below_blend > 0.0 ? mix(horizon, below, smoothstep(0.0, below_blend, -h)) : below;
	COLOR = c;
}
