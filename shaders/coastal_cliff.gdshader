shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// ENOSHIMA COASTAL SANDSTONE CLIFF SHADER (ANIME / MANGA CEL SHADING)
// Matches Reference Image 1:
// 1. Natural terraced warm sandstone rock strata (#E5A864 / #BD783A / #5C3218)
// 2. Horizontal rock shelves capped with lush vibrant green anime grass (#5C8E24)
// 3. Dark comic ink crevices and 45-degree screen-space pen hatching in shadows
// 4. Vibrant warm golden-hour sunset lighting matching the giant sun disc
// =============================================================================

uniform vec4 sun_tint : source_color = vec4(1.0, 0.90, 0.72, 1.0);
uniform vec4 rock_sun_color : source_color = vec4(0.851, 0.627, 0.400, 1.0);    // Warm Golden Sandstone #D9A066
uniform vec4 rock_mid_color : source_color = vec4(0.74, 0.47, 0.23, 1.0);    // Amber Sandstone #BD783A
uniform vec4 rock_shadow_color : source_color = vec4(0.36, 0.20, 0.09, 1.0); // Deep Warm Manga Shadow #5C3218
uniform vec4 grass_top_color : source_color = vec4(0.36, 0.56, 0.14, 1.0);   // Lush Tropical Green #5C8E24
uniform vec4 grass_shadow_color : source_color = vec4(0.22, 0.35, 0.08, 1.0);// Deep Bush Shadow #385A14
uniform vec4 crevice_ink_color : source_color = vec4(0.08, 0.05, 0.03, 1.0); // Dark Comic Ink #140D08
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
	// Reconstruct faceted face normal from screen derivatives for crisp anime rock facets
	vec3 d_x = dFdx(v_world_pos);
	vec3 d_y = dFdy(v_world_pos);
	vec3 face_n = normalize(cross(d_x, d_y));
	if (dot(face_n, v_normal) < 0.0) {
		face_n = -face_n;
	}

	// Blend face normal with vertex normal for faceted cartoon rocks
	vec3 norm = normalize(mix(v_normal, face_n, 0.65));

	// Strictly differentiate horizontal terrace shelves vs vertical cliff faces
	// (Only high terrace ledges above Y=9.0 get grass caps, road shoulders stay clean rock)
	bool is_shelf = (norm.y > 0.70 && v_world_pos.y > 9.0);

	// Directional toon lighting from setting coastal sun (over the ocean on +X)
	vec3 light_dir = normalize(vec3(0.65, 0.35, 0.40));
	float n_dot_l = dot(norm, light_dir);

	float cel_sun = step(0.12, n_dot_l);
	float cel_mid = step(-0.20, n_dot_l);

	vec3 base_col;
	if (is_shelf) {
		// Flat Terrace Shelf: Lush vibrant green grass top (Ref Image 1)
		vec3 grass = mix(grass_shadow_color.rgb, grass_top_color.rgb * sun_tint.rgb, cel_mid);
		grass = mix(grass, grass_top_color.rgb * 1.15 * sun_tint.rgb, cel_sun);
		base_col = grass;
	} else {
		// Stepped Sandstone Rock Face: Clean solid cel-shaded rock color (Ref Image 1)
		vec3 rock = rock_shadow_color.rgb;
		rock = mix(rock, rock_mid_color.rgb * sun_tint.rgb, cel_mid);
		rock = mix(rock, rock_sun_color.rgb * sun_tint.rgb, cel_sun);

		// Natural sedimentary rock horizontal strata banding
		float layer_val = sin(v_world_pos.y * 0.45 + v_world_pos.z * 0.04);
		if (layer_val > 0.85) {
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

	// Bold geometric crease ink lines on sharp facet boundaries
	vec3 d_norm_x = dFdx(norm);
	vec3 d_norm_y = dFdy(norm);
	float crease = length(d_norm_x) + length(d_norm_y);
	if (crease > 0.40) {
		base_col = mix(base_col, crevice_ink_color.rgb, 0.85);
	}

	ALBEDO = base_col;
}
