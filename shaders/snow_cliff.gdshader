shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// HAKONE TOUGE GRANITE SNOW CLIFF SHADER (ANIME / MANGA CEL SHADING)
// Matches Reference Image 3:
// 1. Sheer vertical slate-grey granite rock faces with angular facets
// 2. Thick, puffy pure white snow blankets resting on every ledge and shelf
// 3. Deep comic crevice ink lines and horizontal rock fissures
// 4. Cool winter alpine ambient tone
// =============================================================================

uniform vec4 sun_tint : source_color = vec4(0.96, 0.98, 1.05, 1.0);
uniform vec4 rock_sun_color : source_color = vec4(0.48, 0.56, 0.64, 1.0);    // Cool Granite Rock #7A8F9E
uniform vec4 rock_shadow_color : source_color = vec4(0.24, 0.28, 0.35, 1.0); // Deep Slate Shadow #3D4759
uniform vec4 snow_top_color : source_color = vec4(0.98, 0.99, 1.0, 1.0);     // Pure White Snow #FAFCFF
uniform vec4 snow_shadow_color : source_color = vec4(0.78, 0.86, 0.94, 1.0);  // Soft Cyan Snow Shadow #C8DBF0
uniform vec4 crevice_ink_color : source_color = vec4(0.09, 0.11, 0.15, 1.0); // Dark Comic Ink #171C26

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec2 v_uv;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_uv = UV;
}

void fragment() {
	// Detect horizontal rock ledges vs sheer vertical cliff faces
	bool is_snow_ledge = (v_world_normal.y > 0.35);

	// Directional light vector designed for touge cliff visibility
	vec3 light_dir = normalize(vec3(-0.6, 0.7, 0.4));
	float n_dot_l = dot(v_world_normal, light_dir);
	float cel_light = step(0.0, n_dot_l);

	vec3 base_col;
	if (is_snow_ledge) {
		// Puffy Snow Pillow on rock shelf: Pristine white with soft cyan shaded underside (Ref Image 3)
		vec3 snow = mix(snow_shadow_color.rgb, snow_top_color.rgb * sun_tint.rgb, cel_light);
		base_col = snow;
	} else {
		// Sheer Granite Rock Face: Natural horizontal rock strata & diagonal fractures (Ref Image 3)
		float joint_y = v_world_pos.y * 0.42 + sin(v_world_pos.z * 0.08) * 0.3;
		float joint_band = step(0.89, fract(joint_y));
		float fissure_diag = step(0.95, fract(v_world_pos.z * 0.14 - v_world_pos.y * 0.28));

		vec3 rock = mix(rock_shadow_color.rgb, rock_sun_color.rgb * sun_tint.rgb, cel_light);
		// Apply dark comic ink crevices and granite fractures
		float ink_mask = max(joint_band * 0.75, fissure_diag * 0.65);
		rock = mix(rock, crevice_ink_color.rgb, ink_mask);
		base_col = rock;
	}

	ALBEDO = base_col;
}
