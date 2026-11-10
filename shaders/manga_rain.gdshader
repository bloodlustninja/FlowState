shader_type canvas_item;

// Screen-Space Rain: 2D slanted comic ink rain slashes (#FFFFFF at 0.75 opacity) streaming at a sharp 45-degree angle
uniform vec4 rain_color : source_color = vec4(1.0, 1.0, 1.0, 0.75);
uniform float rain_speed : hint_range(1.0, 10.0) = 4.2;
uniform float rain_density : hint_range(10.0, 80.0) = 45.0;
uniform float rain_angle : hint_range(-1.4, 1.4) = 0.55; // Dynamic directional wind slant

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// Dynamic directional rotation based on wind angle
	vec2 uv = UV;
	float c_ang = cos(rain_angle);
	float s_ang = sin(rain_angle);
	vec2 rot_uv = vec2(
		uv.x * c_ang - uv.y * s_ang,
		uv.x * s_ang + uv.y * c_ang
	);

	float mask = 0.0;

	// Layer 1: Foreground long sharp anime rain slashes
	vec2 st1 = vec2(rot_uv.x * rain_density, rot_uv.y * (rain_density * 0.10) - TIME * rain_speed * 3.8);
	vec2 id1 = floor(st1);
	vec2 f1 = fract(st1);
	float h1 = hash21(id1);
	if (h1 > 0.80) {
		float line1 = smoothstep(0.12, 0.0, abs(f1.x - 0.5)) * smoothstep(0.9, 0.1, f1.y);
		mask = max(mask, line1);
	}

	// Layer 2: Rapid background hatched slashes for density
	vec2 st2 = vec2(rot_uv.x * (rain_density * 1.5), rot_uv.y * (rain_density * 0.16) - TIME * rain_speed * 5.2);
	vec2 id2 = floor(st2);
	vec2 f2 = fract(st2);
	float h2 = hash21(id2);
	if (h2 > 0.86) {
		float line2 = smoothstep(0.10, 0.0, abs(f2.x - 0.5)) * smoothstep(0.85, 0.15, f2.y);
		mask = max(mask, line2 * 0.65);
	}

	if (mask <= 0.03) {
		discard;
	}

	COLOR = vec4(rain_color.rgb, mask * rain_color.a);
}
