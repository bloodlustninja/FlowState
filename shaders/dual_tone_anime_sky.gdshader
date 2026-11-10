shader_type sky;

uniform vec4 sky_zenith : source_color = vec4(0.043, 0.169, 0.408, 1.0);   // Deep Anime Blue #0B2B68
uniform vec4 sky_horizon : source_color = vec4(0.973, 0.914, 0.753, 1.0); // Warm Anime Cream #F8E9C0
uniform float split_elevation : hint_range(-0.1, 0.4) = 0.06;
uniform float band_smoothness : hint_range(0.005, 0.2) = 0.04;

void sky() {
	// EYEDIR.y is the vertical component of the view ray.
	// When looking at or near the horizon (EYEDIR.y <= split_elevation), it blends to warm cream.
	// As elevation rises above the mountain highway horizon, it transitions cleanly to rich cobalt blue.
	float t = smoothstep(split_elevation - band_smoothness, split_elevation + band_smoothness, EYEDIR.y);
	COLOR = mix(sky_horizon.rgb, sky_zenith.rgb, t);
}
