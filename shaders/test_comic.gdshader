shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

uniform vec4 paint_color : source_color = vec4(0.92, 0.90, 0.85, 1.0);
uniform vec4 ink_shadow : source_color = vec4(0.05, 0.05, 0.09, 1.0);
uniform float shadow_cut : hint_range(0.0, 1.0) = 0.30;
uniform float hatch_spacing : hint_range(2.0, 20.0) = 8.0;

void fragment() {
	ALBEDO = paint_color.rgb;
	// Graphic ambient baseline: the car is NEVER a black void
	EMISSION = mix(paint_color.rgb * 0.40, ink_shadow.rgb, 0.35);
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	SPECULAR = 0.1;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float atten = clamp(ATTENUATION, 0.0, 1.0);
	float light_val = NdotL * atten;

	// 45-degree screen-space hatching
	float screen_stripe = fract((FRAGCOORD.x + FRAGCOORD.y) / hatch_spacing);
	float hatch_line = step(0.42, screen_stripe);

	vec3 lit_val = LIGHT_COLOR.rgb * ALBEDO * 0.9;
	vec3 hatch_val = (hatch_line > 0.5) ? ink_shadow.rgb : ALBEDO * 0.55;
	vec3 shadow_val = ALBEDO * mix(ink_shadow.rgb, LIGHT_COLOR.rgb * 0.25, 0.25);

	vec3 diff;
	if (light_val > shadow_cut) {
		diff = lit_val;
	} else if (light_val > shadow_cut * 0.35) {
		diff = hatch_val;
	} else {
		diff = shadow_val;
	}
	DIFFUSE_LIGHT += diff;
}
