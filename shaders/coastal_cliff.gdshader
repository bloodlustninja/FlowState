shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// ENOSHIMA COASTAL SANDSTONE CLIFF SHADER (ANIME / MANGA CEL SHADING)
// Matches Reference Image 1:
// 1. Natural terraced warm sandstone rock strata (#D89A5A / #9C683B)
// 2. Horizontal rock shelves capped with lush green manga grass & palms
// 3. Dark comic ink crevices and sedimentary shadow lines
// 4. Vibrant warm golden-hour sunset lighting
// =============================================================================

uniform vec4 sun_tint : source_color = vec4(1.0, 0.92, 0.78, 1.0);
uniform vec4 rock_sun_color : source_color = vec4(0.85, 0.60, 0.35, 1.0);    // Warm Sandstone #D89A5A
uniform vec4 rock_shadow_color : source_color = vec4(0.55, 0.36, 0.20, 1.0); // Rich Sandstone Shadow #9C683B
uniform vec4 grass_top_color : source_color = vec4(0.35, 0.59, 0.18, 1.0);   // Lush Tropical Green #5A962E
uniform vec4 grass_shadow_color : source_color = vec4(0.18, 0.40, 0.10, 1.0);// Deep Bush Shadow #2E661A
uniform vec4 crevice_ink_color : source_color = vec4(0.15, 0.10, 0.08, 1.0); // Dark Comic Ink #261A14

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec2 v_uv;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_uv = UV;
}

void fragment() {
	// Detect flat horizontal terrace shelves vs vertical cliff faces
	bool is_shelf = (v_world_normal.y > 0.40);

	// Toon directional lighting from sunset sun
	vec3 light_dir = normalize(vec3(0.5, 0.6, 0.6));
	float n_dot_l = dot(v_world_normal, light_dir);
	float cel_light = step(0.04, n_dot_l);

	vec3 base_col;
	if (is_shelf) {
		// Flat Terrace Shelf: Lush vibrant manga grass with subtle blade stippling
		float blade_noise = fract(sin(dot(floor(v_world_pos.xz * 2.8), vec2(12.9898, 78.233))) * 43758.5453);
		vec3 grass = mix(grass_top_color.rgb, grass_shadow_color.rgb, step(0.65, blade_noise) * 0.22);
		base_col = mix(grass * 0.85, grass * sun_tint.rgb, cel_light);
	} else {
		// Stepped Vertical Rock Face: Natural horizontal sedimentary strata lines (Ref Image 1)
		float strata_y = v_world_pos.y * 0.75 + sin(v_world_pos.z * 0.10) * 0.25;
		float strata_band = step(0.88, fract(strata_y));
		float strata_micro = step(0.92, fract(strata_y * 3.5));

		// Natural diagonal rock joint fissures
		float fissure = step(0.96, fract(v_world_pos.z * 0.18 + v_world_pos.y * 0.32));

		vec3 rock = mix(rock_shadow_color.rgb, rock_sun_color.rgb * sun_tint.rgb, cel_light);
		// Apply dark comic ink crevices and strata lines
		float ink_mask = max(strata_band * 0.70, max(strata_micro * 0.45, fissure * 0.65));
		rock = mix(rock, crevice_ink_color.rgb, ink_mask);
		base_col = rock;
	}

	ALBEDO = base_col;
}
