shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

uniform vec4 base_color : source_color = vec4(0.949, 0.937, 0.914, 1.0);     // Warm off-white #F2EFE9
uniform vec4 stripe_color : source_color = vec4(0.0, 0.278, 0.671, 1.0);     // Cobalt Blue #0047AB
uniform vec4 ink_color : source_color = vec4(0.067, 0.067, 0.067, 1.0);      // Black Ink Line #111111
uniform vec4 shadow_color : source_color = vec4(0.20, 0.227, 0.322, 1.0);   // Slate Indigo #333A52
uniform bool has_livery = false;                                              // True for hero muscle body
uniform float glossiness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.05;

varying vec3 v_pos;
varying vec3 v_norm;

void vertex() {
	v_pos = VERTEX;
	v_norm = NORMAL;
}

void fragment() {
	vec3 surface_col = base_color.rgb;

	if (has_livery) {
		float ax = abs(v_pos.x);
		float ay = v_pos.y;
		float az = v_pos.z;

		// 1. Dual bold Cobalt Blue racing stripes down center
		bool in_left_stripe = (ax >= 0.065 && ax <= 0.275);
		// Top facing surfaces (roof, hood, trunk, spoiler)
		if (in_left_stripe && v_norm.y > 0.20) {
			surface_col = stripe_color.rgb;
		}

		// 2. Black ink stroke borders along racing stripes
		bool stripe_border = (abs(ax - 0.065) < 0.012 || abs(ax - 0.275) < 0.012);
		if (stripe_border && v_norm.y > 0.20) {
			surface_col = ink_color.rgb;
		}

		// 3. Panel Seams & Manga Ink Accents
		bool is_ink_seam = false;

		// Side Flank door seams & horizontal shoulder crease
		if (ax > 0.82) {
			// Rear door cut
			if (abs(az - 0.20) < 0.015 && ay > 0.15 && ay < 0.80) {
				is_ink_seam = true;
			}
			// Front door cut
			if (abs(az + 0.65) < 0.015 && ay > 0.15 && ay < 0.80) {
				is_ink_seam = true;
			}
			// Horizontal beltline crease
			if (abs(ay - 0.52) < 0.014 && abs(az) < 1.35) {
				is_ink_seam = true;
			}
			// Wheel arch ink contours (front & rear)
			float rear_arch = length(vec2(az - 1.45, ay - 0.32));
			if (abs(rear_arch - 0.44) < 0.018 && ay > 0.30) {
				is_ink_seam = true;
			}
			float front_arch = length(vec2(az + 1.45, ay - 0.32));
			if (abs(front_arch - 0.44) < 0.018 && ay > 0.30) {
				is_ink_seam = true;
			}
		}

		// Top Panels: Hood cut & trunk cut
		if (v_norm.y > 0.45) {
			// Hood cut
			if (abs(az + 1.05) < 0.016 && ax < 0.82) {
				is_ink_seam = true;
			}
			// Trunk cut
			if (abs(az - 1.15) < 0.016 && ax < 0.80) {
				is_ink_seam = true;
			}
		}

		if (is_ink_seam) {
			surface_col = ink_color.rgb;
		}
	}

	// Stylized grazing anime contour line
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ink_edge = smoothstep(0.12, 0.24, NdotV);
	ALBEDO = mix(ink_color.rgb, surface_col, ink_edge);

	ROUGHNESS = 1.0 - glossiness;
	METALLIC = metallic_val;
	SPECULAR = 0.5;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	// Two-step cel ramp: Lit surfaces full albedo, shadow tint to slate indigo
	float cel_band = step(0.06, NdotL);
	vec3 light_direct = LIGHT_COLOR * ATTENUATION;

	vec3 lit_surface = ALBEDO * light_direct * 0.95;
	vec3 shadowed_surface = ALBEDO * shadow_color.rgb * 1.55;
	DIFFUSE_LIGHT += mix(shadowed_surface, lit_surface, cel_band);

	// Sharp comic specular highlight glint
	vec3 half_vec = normalize(VIEW + LIGHT);
	float NdotH = dot(NORMAL, half_vec);
	float spec_glint = step(0.90, NdotH) * cel_band;
	SPECULAR_LIGHT += spec_glint * vec3(1.0, 1.0, 1.0) * 1.5;
}
