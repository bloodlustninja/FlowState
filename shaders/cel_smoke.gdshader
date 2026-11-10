shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 light_color : source_color = vec4(0.95, 0.95, 0.98, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.55, 0.58, 0.68, 1.0);
uniform sampler2D noise_tex : repeat_enable;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_threshold : hint_range(-1.0, 1.0) = 0.1;

void vertex() {
	// Displace vertices with noise for puffy, organic shapes
	float n = texture(noise_tex, UV + vec2(TIME * 0.2, TIME * 0.2)).r;
	VERTEX += NORMAL * (n - 0.5) * 0.3;
}

void fragment() {
	// Use alpha scissor for sharp, non-blurry cartoon edges
	float noise = texture(noise_tex, UV).r;
	float edge_mask = noise * COLOR.a; // COLOR.a comes from particle lifetime
	
	if (edge_mask < alpha_scissor) {
		discard;
	}
	
	ALBEDO = light_color.rgb;
}

void light() {
	// Hard-stepped cel shading based on light direction
	float NdotL = dot(NORMAL, LIGHT);
	float toon_shade = smoothstep(shadow_threshold - 0.02, shadow_threshold + 0.02, NdotL);
	
	vec3 final_color = mix(shadow_color.rgb, light_color.rgb, toon_shade);
	DIFFUSE_LIGHT += final_color * ATTENUATION * LIGHT_COLOR;
}
