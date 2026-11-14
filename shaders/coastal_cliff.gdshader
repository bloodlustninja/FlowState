shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// ENOSHIMA COASTAL SANDSTONE CLIFF SHADER (ANIME / MANGA CEL SHADING)
// Matches Reference Image 1:
// 1. Natural terraced warm sandstone rock strata (#E5A864 / #BD783A / #5C3218)
// 2. Horizontal rock shelves capped with lush vibrant green anime grass (#5C8E24)
// 3. Dark comic ink crevices and natural geometric rock facets
// 4. Vibrant warm golden-hour sunset lighting matching the giant sun disc
// =============================================================================

uniform vec4 sun_tint : source_color = vec4(1.0, 0.90, 0.72, 1.0);
uniform vec4 rock_sun_color : source_color = vec4(0.90, 0.66, 0.39, 1.0);    // Warm Golden Sandstone #E5A864
uniform vec4 rock_mid_color : source_color = vec4(0.74, 0.47, 0.23, 1.0);    // Amber Sandstone #BD783A
uniform vec4 rock_shadow_color : source_color = vec4(0.36, 0.20, 0.09, 1.0); // Deep Warm Manga Shadow #5C3218
uniform vec4 grass_top_color : source_color = vec4(0.36, 0.56, 0.14, 1.0);   // Lush Tropical Green #5C8E24
uniform vec4 grass_shadow_color : source_color = vec4(0.22, 0.35, 0.08, 1.0);// Deep Bush Shadow #385A14
uniform vec4 crevice_ink_color : source_color = vec4(0.13, 0.07, 0.03, 1.0); // Dark Comic Ink #221208

varying vec3 v_world_pos;
varying vec2 v_uv;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_uv = UV;
}

void fragment() {
	// Reconstruct pure flat face normal from screen derivatives for crisp anime rock facets
	vec3 d_x = dFdx(v_world_pos);
	vec3 d_y = dFdy(v_world_pos);
	vec3 face_n = normalize(cross(d_x, d_y));
	// Ensure normal faces out towards the roadway (+X)
	if (face_n.x < 0.0) {
		face_n = -face_n;
	}

	// Strictly differentiate horizontal terrace shelves vs vertical cliff faces
	bool is_shelf = (face_n.y > 0.52);

	// Directional toon lighting from setting coastal sun (over the ocean on +X)
	vec3 light_dir = normalize(vec3(0.65, 0.40, 0.45));
	float n_dot_l = dot(face_n, light_dir);

	float cel_sun = step(0.10, n_dot_l);
	float cel_mid = step(-0.25, n_dot_l);

	vec3 base_col;
	if (is_shelf) {
		// Flat Terrace Shelf: Lush vibrant green grass top (Ref Image 1)
		vec3 grass = mix(grass_shadow_color.rgb, grass_top_color.rgb * sun_tint.rgb, cel_mid);
		grass = mix(grass, grass_top_color.rgb * 1.15 * sun_tint.rgb, cel_sun);
		base_col = grass;
	} else {
		// Stepped Sandstone Rock Face: Layered warm manga palette (Ref Image 1)
		vec3 rock = rock_shadow_color.rgb;
		rock = mix(rock, rock_mid_color.rgb * sun_tint.rgb, cel_mid);
		rock = mix(rock, rock_sun_color.rgb * sun_tint.rgb, cel_sun);

		// Natural subtle sedimentary rock layer variation
		float layer_val = sin(v_world_pos.y * 0.45 + v_world_pos.z * 0.04);
		if (layer_val > 0.85) {
			rock = mix(rock, crevice_ink_color.rgb, 0.50);
		}

		base_col = rock;
	}

	ALBEDO = base_col;
}
