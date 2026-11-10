shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

// Auto Modellista / Manga Dry-Brush Directional Shader
uniform vec4 base_color : source_color = vec4(0.941, 0.937, 0.918, 1.0);     // #F0EFEA Warm paper white/cream
uniform vec4 stripe_color : source_color = vec4(0.0, 0.278, 0.671, 1.0);     // #0047AB Cobalt blue accent
uniform vec4 shadow_tint : source_color = vec4(0.196, 0.208, 0.290, 1.0);     // #32354A Cool slate violet/indigo
uniform vec4 ink_line_color : source_color = vec4(0.07, 0.07, 0.09, 1.0);    // Deep Manga Ink

uniform bool has_livery = false;
uniform float brush_grain_strength : hint_range(0.0, 1.0) = 0.40;
uniform float streak_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float glossiness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.05;

varying vec3 v_pos;
varying vec3 v_norm;
varying vec2 v_uv;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_pos = VERTEX;
	v_norm = NORMAL;
	v_uv = UV;
}

void fragment() {
	vec3 surface_col = base_color.rgb;

	// Surface Streaks: Directional noise along car length (v_pos.z / UV.y)
	// Renders dynamic manga dry-brush scratches & ink panel grooves
	vec2 streak_coords = vec2(v_pos.x * 22.0, v_pos.z * 1.6);
	float n_streak = noise2(streak_coords);
	float dry_scratch = step(0.86, n_streak) * streak_intensity;

	if (has_livery) {
		float ax = abs(v_pos.x);
		float ay = v_pos.y;
		float az = v_pos.z;

		// Dual bold Cobalt Blue racing stripes down the center
		bool in_stripe = (ax >= 0.070 && ax <= 0.270);
		if (in_stripe && v_norm.y > 0.20) {
			surface_col = stripe_color.rgb;
		}

		// Black ink border along stripes
		bool stripe_border = (abs(ax - 0.070) < 0.012 || abs(ax - 0.270) < 0.012);
		if (stripe_border && v_norm.y > 0.20) {
			surface_col = ink_line_color.rgb;
		}

		// Manga panel seam cuts (doors, hood, fenders)
		bool is_seam = false;
		if (ax > 0.82) {
			if (abs(az - 0.20) < 0.015 && ay > 0.15 && ay < 0.80) { is_seam = true; } // Rear door
			if (abs(az + 0.65) < 0.015 && ay > 0.15 && ay < 0.80) { is_seam = true; } // Front door
			if (abs(ay - 0.52) < 0.014 && abs(az) < 1.35) { is_seam = true; }         // Beltline
		}
		if (v_norm.y > 0.45) {
			if (abs(az + 1.05) < 0.016 && ax < 0.82) { is_seam = true; }             // Hood cut
			if (abs(az - 1.15) < 0.016 && ax < 0.80) { is_seam = true; }             // Trunk cut
		}
		if (is_seam) {
			surface_col = ink_line_color.rgb;
		}
	}

	// Apply dynamic dry-brush scratches
	surface_col = mix(surface_col, ink_line_color.rgb, dry_scratch * 0.45);

	// Stylized manga grazing ink contour
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ink_contour = smoothstep(0.10, 0.24, NdotV);
	ALBEDO = mix(ink_line_color.rgb, surface_col, ink_contour);

	ROUGHNESS = 1.0 - glossiness;
	METALLIC = metallic_val;
	SPECULAR = 0.5;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);

	// Procedural Brush Grain: High-frequency noise jitter along the light/shadow terminator
	vec2 grain_uv = vec2(v_pos.x * 48.0, v_pos.y * 48.0 + v_pos.z * 16.0);
	float grain = (hash21(grain_uv) - 0.5) * 0.22 * brush_grain_strength;
	float step_threshold = 0.08 + grain;

	// Stepped 2-tone lighting threshold
	float cel_step = step(step_threshold, NdotL);

	vec3 lit_surface = ALBEDO * LIGHT_COLOR * ATTENUATION * 0.96;
	vec3 shadow_surface = ALBEDO * shadow_tint.rgb * 1.55;

	DIFFUSE_LIGHT += mix(shadow_surface, lit_surface, cel_step);

	// Manga sharp specular highlight glint
	vec3 half_vec = normalize(VIEW + LIGHT);
	float NdotH = dot(NORMAL, half_vec);
	float spec_glint = step(0.92, NdotH) * cel_step;
	SPECULAR_LIGHT += spec_glint * vec3(1.0, 1.0, 1.0) * 1.4;
}
