shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 base_color : source_color = vec4(0.90, 0.14, 0.14, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.22, 0.14, 0.32, 1.0); // Violet comic shadow
uniform float shadow_threshold : hint_range(-1.0, 1.0) = 0.15;
uniform float shadow_softness : hint_range(0.001, 0.3) = 0.04;
uniform float specular_size : hint_range(0.5, 0.99) = 0.88;
uniform bool is_emissive = false;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.22;
	SPECULAR = 0.5;
	if (is_emissive) {
		EMISSION = emission_color.rgb;
	}
}

void light() {
	if (is_emissive) {
		DIFFUSE_LIGHT += ALBEDO;
	} else {
		float NdotL = dot(NORMAL, LIGHT);
		float atten = clamp(ATTENUATION, 0.0, 1.0);
		float light_intensity = NdotL * atten;

		// Sharp comic 2-band cel-shade threshold
		float shadow_mask = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, light_intensity);

		// Lit surface vs saturated comic shadow
		vec3 lit_color = ALBEDO * LIGHT_COLOR.rgb;
		vec3 dark_color = ALBEDO * shadow_color.rgb * 1.85;
		vec3 diffuse = mix(dark_color, lit_color, shadow_mask);

		// Sharp comic specular glint
		vec3 half_vec = normalize(VIEW + LIGHT);
		float NdotH = dot(NORMAL, half_vec);
		float spec_mask = step(specular_size, NdotH) * shadow_mask;
		vec3 spec = vec3(spec_mask * 0.75) * LIGHT_COLOR.rgb;

		DIFFUSE_LIGHT += diffuse;
		SPECULAR_LIGHT += spec;
	}
}
