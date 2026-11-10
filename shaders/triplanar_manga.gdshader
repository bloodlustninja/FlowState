shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 base_paint : source_color = vec4(0.94, 0.92, 0.88, 1.0); // Warm cream
uniform vec4 shadow_tint : source_color = vec4(0.38, 0.36, 0.52, 1.0); // Rich comic slate indigo
uniform vec4 ink_black : source_color = vec4(0.05, 0.05, 0.05, 1.0);

uniform float streak_scale : hint_range(1.0, 50.0) = 18.0;
uniform float ink_density : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.35;

varying vec3 local_coords;

void vertex() {
	// Grab local model position so streaks stick to the car during motion
	local_coords = VERTEX;
}

// Procedural 1D ink scratch hash
float hash(vec2 p) {
	p = fract(abs(p) * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float brush_streak(vec2 p) {
	vec2 st = p * vec2(1.5, streak_scale);
	float id = floor(st.y);
	float f = fract(st.y);
	float n = hash(vec2(floor(st.x * 4.0), id));
	return smoothstep(1.0 - ink_density, 1.0, sin(f * 3.14159) * n);
}

void fragment() {
	// Triplanar projection using local coordinates (immune to broken UVs)
	vec3 norm = abs(NORMAL);
	norm /= (norm.x + norm.y + norm.z);

	// Generate directional scratches across all 3 spatial planes (Sides, Roof/Hood, Rear/Front)
	float streak_side = brush_streak(local_coords.zy);
	float streak_top = brush_streak(local_coords.zx);
	float streak_rear = brush_streak(local_coords.xy);
	float final_streaks = streak_side * norm.x + streak_top * norm.y + streak_rear * norm.z;

	// Inked silhouette edge (Fresnel / Rim inking)
	float fresnel = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ink_edge = smoothstep(0.65, 0.85, fresnel);

	// Blend base paint with dry-brush ink streaks and edge inking
	vec3 surface = mix(base_paint.rgb, ink_black.rgb, clamp(final_streaks + (ink_edge * 0.9), 0.0, 1.0));

	ALBEDO = surface;
	ROUGHNESS = 0.85;
}

void light() {
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float att = ATTENUATION;
	float light_val = NdotL * att;

	// Two-tone stepped comic band
	if (light_val > shadow_threshold) {
		DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO;
	} else {
		DIFFUSE_LIGHT += shadow_tint.rgb * ALBEDO * 0.85;
	}
}
