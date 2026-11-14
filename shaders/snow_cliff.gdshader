shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// HAKONE TOUGE GRANITE SNOW CLIFF SHADER (ANIME / MANGA CEL SHADING)
// Matches Reference Image 3:
// 1. Sheer vertical slate-grey granite rock faces with angular facets (#849BB0 / #55687C / #2B3644)
// 2. Thick, puffy pure white snow blankets resting on horizontal shelves (#FCFDFF / #BDD6EB)
// 3. Dark comic crevice ink lines and stylized polygonal rock cuts
// 4. Cool winter alpine ambient tone
// =============================================================================

uniform vec4 sun_tint : source_color = vec4(0.96, 0.98, 1.05, 1.0);
uniform vec4 rock_sun_color : source_color = vec4(0.52, 0.61, 0.69, 1.0);    // Cool Granite Rock #849BB0
uniform vec4 rock_mid_color : source_color = vec4(0.33, 0.41, 0.49, 1.0);    // Slate Granite #55687C
uniform vec4 rock_shadow_color : source_color = vec4(0.17, 0.21, 0.27, 1.0); // Deep Shadow Slate #2B3644
uniform vec4 snow_top_color : source_color = vec4(0.99, 0.99, 1.0, 1.0);     // Pure White Snow #FCFDFF
uniform vec4 snow_shadow_color : source_color = vec4(0.74, 0.84, 0.92, 1.0);  // Soft Cyan Snow Shadow #BDD6EB
uniform vec4 crevice_ink_color : source_color = vec4(0.08, 0.10, 0.14, 1.0); // Dark Comic Ink #141A24

varying vec3 v_world_pos;
varying vec2 v_uv;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_uv = UV;
}

void fragment() {
	// Reconstruct pure flat face normal from screen derivatives for crisp anime polygonal rock facets
	vec3 d_x = dFdx(v_world_pos);
	vec3 d_y = dFdy(v_world_pos);
	vec3 face_n = normalize(cross(d_x, d_y));
	// Ensure normal faces out towards the roadway (-X)
	if (face_n.x > 0.0) {
		face_n = -face_n;
	}

	// Strictly differentiate horizontal snow ledges vs sheer vertical rock faces
	bool is_snow_ledge = (face_n.y > 0.52);

	// Alpine directional light
	vec3 light_dir = normalize(vec3(-0.60, 0.55, 0.40));
	float n_dot_l = dot(face_n, light_dir);

	float cel_sun = step(0.12, n_dot_l);
	float cel_mid = step(-0.25, n_dot_l);

	vec3 base_col;
	if (is_snow_ledge) {
		// Puffy Snow Pillow on rock shelf: Pristine white with soft cyan shaded underside (Ref Image 3)
		vec3 snow = mix(snow_shadow_color.rgb, snow_top_color.rgb * sun_tint.rgb, cel_sun);
		base_col = snow;
	} else {
		// Sheer Granite Rock Face: Layered slate granite (Ref Image 3)
		vec3 rock = rock_shadow_color.rgb;
		rock = mix(rock, rock_mid_color.rgb * sun_tint.rgb, cel_mid);
		rock = mix(rock, rock_sun_color.rgb * sun_tint.rgb, cel_sun);

		// Natural subtle fracture variation
		float joint_val = sin(v_world_pos.y * 0.40 - v_world_pos.z * 0.06);
		if (joint_val > 0.86) {
			rock = mix(rock, crevice_ink_color.rgb, 0.60);
		}

		base_col = rock;
	}

	ALBEDO = base_col;
}
