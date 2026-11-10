shader_type canvas_item;

// Screen-Space Anime Snowfall: Soft fluttering circular flakes with subtle drift
uniform vec4 snow_color : source_color = vec4(0.96, 0.98, 1.0, 0.85);
uniform float snow_speed : hint_range(0.5, 5.0) = 1.6;
uniform float snow_density : hint_range(10.0, 60.0) = 32.0;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float mask = 0.0;

	// Layer 1: Foreground gentle tumbling snowflakes
	vec2 st1 = vec2(uv.x * snow_density + sin(TIME * 1.2 + uv.y * 4.0) * 0.4, uv.y * (snow_density * 0.6) - TIME * snow_speed);
	vec2 id1 = floor(st1);
	vec2 f1 = fract(st1) - 0.5;
	float h1 = hash21(id1);
	if (h1 > 0.78) {
		float radius = mix(0.12, 0.28, hash21(id1 + 1.0));
		float flake = 1.0 - smoothstep(radius * 0.6, radius, length(f1));
		mask = max(mask, flake);
	}

	// Layer 2: Background smaller swirling flakes
	vec2 st2 = vec2(uv.x * (snow_density * 1.8) + cos(TIME * 1.5 + uv.y * 6.0) * 0.5, uv.y * (snow_density * 1.1) - TIME * (snow_speed * 1.4));
	vec2 id2 = floor(st2);
	vec2 f2 = fract(st2) - 0.5;
	float h2 = hash21(id2);
	if (h2 > 0.82) {
		float radius2 = mix(0.08, 0.20, hash21(id2 + 2.0));
		float flake2 = (1.0 - smoothstep(radius2 * 0.6, radius2, length(f2))) * 0.65;
		mask = max(mask, flake2);
	}

	if (mask <= 0.02) {
		discard;
	}

	COLOR = vec4(snow_color.rgb, mask * snow_color.a);
}
