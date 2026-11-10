// ==============================================================================
// MASTER SPEC: FlowState - Mobile-Optimized Comic Toon Shader
// Stepped diffuse cel lighting with 45° screen-space crosshatching in shadows.
// ==============================================================================
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.839, 0.157, 0.157, 1.0);   // #D62828 Warm Crimson
uniform vec4 shadow_color : source_color = vec4(0.169, 0.118, 0.227, 1.0); // #2B1E3A Deep Violet
uniform float hatch_density : hint_range(50.0, 300.0) = 140.0;
uniform bool enable_crosshatch = true;

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float stepped = smoothstep(0.0, 0.08, n_dot_l);
	
	float hatch = 1.0;
	if (enable_crosshatch) {
		float c45 = (FRAGCOORD.x + FRAGCOORD.y) * (hatch_density / 1080.0);
		float line1 = step(0.35, fract(c45));
		hatch = mix(line1, 1.0, stepped);
	}
	
	vec3 lit = LIGHT_COLOR * ATTENUATION * stepped;
	vec3 dark = shadow_color.rgb * hatch;
	DIFFUSE_LIGHT += mix(dark, lit, stepped) * ALBEDO;
}
