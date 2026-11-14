shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// HAKONE TOUGE GRANITE SNOW CLIFF SHADER (ANIME / MANGA CEL SHADING)
// Matches Reference Image 3:
// 1. Sheer vertical slate-grey granite rock faces with angular facets (#849BB0 / #55687C / #2B3644)
// 2. Thick, puffy pure white snow blankets resting on horizontal shelves (#FCFDFF / #BDD6EB)
// 3. Dark comic crevice ink lines and 45-degree screen-space pen hatching in shadows
// 4. Cool winter alpine ambient tone
// =============================================================================

uniform vec4 sun_tint : source_color = vec4(0.96, 0.98, 1.05, 1.0);
uniform vec4 rock_sun_color : source_color = vec4(0.886, 0.910, 0.941, 1.0);    // Clean Solid Alpine Granite #E2E8F0
uniform vec4 rock_mid_color : source_color = vec4(0.33, 0.41, 0.49, 1.0);    // Slate Granite #55687C
uniform vec4 rock_shadow_color : source_color = vec4(0.17, 0.21, 0.27, 1.0); // Deep Shadow Slate #2B3644
uniform vec4 snow_top_color : source_color = vec4(0.99, 0.99, 1.0, 1.0);     // Pure White Snow #FCFDFF
uniform vec4 snow_shadow_color : source_color = vec4(0.74, 0.84, 0.92, 1.0);  // Soft Cyan Snow Shadow #BDD6EB
uniform vec4 crevice_ink_color : source_color = vec4(0.06, 0.08, 0.12, 1.0); // Dark Comic Ink #10141E
uniform float hatch_density : hint_range(50.0, 300.0) = 145.0;

varying vec3 v_world_pos;
varying vec3 v_normal;
varying vec2 v_uv;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_uv = UV;
}

void fragment() {
	// Reconstruct faceted face normal from screen derivatives for crisp anime polygonal rock facets
	vec3 d_x = dFdx(v_world_pos);
	vec3 d_y = dFdy(v_world_pos);
	vec3 face_n = normalize(cross(d_x, d_y));
	if (dot(face_n, v_normal) < 0.0) {
		face_n = -face_n;
	}

	vec3 norm = normalize(mix(v_normal, face_n, 0.65));

	// Strictly differentiate horizontal snow ledges vs sheer vertical rock faces
	// (Only high ledges above Y=8.0 receive snow caps, road shoulders stay clean rock)
	bool is_snow_ledge = (norm.y > 0.65 && v_world_pos.y > 8.0);

	// Alpine directional light
	vec3 light_dir = normalize(vec3(-0.60, 0.55, 0.40));
	float n_dot_l = dot(norm, light_dir);

	float cel_sun = step(0.12, n_dot_l);
	float cel_mid = step(-0.22, n_dot_l);

	vec3 base_col;
	if (is_snow_ledge) {
		// Puffy Snow Pillow on rock shelf: Pristine white with soft cyan shaded underside (Ref Image 3)
		vec3 snow = mix(snow_shadow_color.rgb, snow_top_color.rgb * sun_tint.rgb, cel_sun);
		base_col = snow;
	} else {
		// Sheer Granite Rock Face: Clean solid cel-shaded granite (Ref Image 3)
		vec3 rock = rock_shadow_color.rgb;
		rock = mix(rock, rock_mid_color.rgb * sun_tint.rgb, cel_mid);
		rock = mix(rock, rock_sun_color.rgb * sun_tint.rgb, cel_sun);

		// Natural subtle fracture variation
		float fracture = sin(v_world_pos.y * 0.60 + v_world_pos.z * 0.05);
		if (fracture > 0.85) {
			rock = mix(rock, crevice_ink_color.rgb, 0.35);
		}

		base_col = rock;
	}

	// 45-Degree Screen-Space Manga Pen Hatching STRICTLY in Deep Shadow Crevices (NdotL < 0.25)
	if (n_dot_l < 0.25 && cel_sun < 0.5) {
		float c45 = (FRAGCOORD.x + FRAGCOORD.y) * (hatch_density / 1080.0);
		float pen_stroke = step(0.48, fract(c45));
		float crevice_depth = clamp((0.25 - n_dot_l) / 0.45, 0.0, 1.0);
		base_col = mix(base_col, crevice_ink_color.rgb, pen_stroke * 0.35 * crevice_depth);
	}

	// Bold geometric crease ink lines on sharp granite facet boundaries
	vec3 d_norm_x = dFdx(norm);
	vec3 d_norm_y = dFdy(norm);
	float crease = length(d_norm_x) + length(d_norm_y);
	if (crease > 0.40) {
		base_col = mix(base_col, crevice_ink_color.rgb, 0.85);
	}

	ALBEDO = base_col;
}
