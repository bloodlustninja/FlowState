shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// ENOSHIMA COASTAL OCEAN SHADER (ANIME / MANGA CEL SHADING)
// Matches Reference Image 1:
// 1. Deep cobalt blue ocean surface with anime wave crests (#166BA5)
// 2. Stepped white comic wave surf lines washing up onto golden sand
// 3. Warm golden sunset sun reflection trail across the water
// =============================================================================

uniform vec4 ocean_deep_color : source_color = vec4(0.08, 0.32, 0.62, 1.0);    // Cobalt Blue #14529E
uniform vec4 ocean_shallow_color : source_color = vec4(0.12, 0.45, 0.78, 1.0); // Azure Surf #1F73C7
uniform vec4 sun_glitter_color : source_color = vec4(1.0, 0.88, 0.45, 1.0);   // Golden Sunset Glitter #FFE073
uniform vec4 wave_foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);        // Pure White Surf Foam
uniform vec3 sun_direction = vec3(-0.3, -0.5, -0.8);

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Multi-frequency manga ocean waves
	vec2 uv_wave = v_world_pos.xz * 0.04;
	float w1 = sin(uv_wave.x * 2.8 + uv_wave.y * 1.5 + TIME * 1.1);
	float w2 = cos(uv_wave.x * 1.8 - uv_wave.y * 2.2 + TIME * 0.8);
	float w3 = sin((uv_wave.x + uv_wave.y) * 3.5 + TIME * 1.4);
	float wave = (w1 + w2 * 0.7 + w3 * 0.4) * 0.5;

	// Two-tone anime cel water
	float wave_step = step(0.15, wave);
	vec3 water = mix(ocean_deep_color.rgb, ocean_shallow_color.rgb, wave_step);

	// White wave crest caps
	float foam_cap = step(0.68, wave);
	water = mix(water, wave_foam_color.rgb, foam_cap);

	// Stepped white cartoon surf breakers washing ashore (Ref Image 1)
	float surf_dist = v_world_pos.x;
	float surf_wave = sin(v_world_pos.z * 0.12 - TIME * 1.5) * 3.5 + cos(v_world_pos.z * 0.35) * 1.8;
	float surf_line1 = step(abs(surf_dist - (18.0 + surf_wave)), 1.2);
	float surf_line2 = step(abs(surf_dist - (25.0 + surf_wave * 0.8)), 1.4);
	float surf_line3 = step(abs(surf_dist - (35.0 + surf_wave * 0.6)), 1.6);
	float surf_mask = max(surf_line1, max(surf_line2 * 0.85, surf_line3 * 0.70));
	water = mix(water, wave_foam_color.rgb, surf_mask);

	// Sunset sun reflection path running across the water towards the sun disc
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_pos);
	vec3 light_dir = normalize(-sun_direction);
	vec3 half_vec = normalize(view_dir + light_dir);
	float spec = pow(max(0.0, dot(vec3(0.0, 1.0, 0.0), half_vec)), 32.0);
	float spec_cel = step(0.20, spec);
	// Sun glitter column width along X (aligned with sun disc at x=45m)
	float sun_col_mask = smoothstep(120.0, 20.0, abs(v_world_pos.x - 45.0));
	vec3 glitter = sun_glitter_color.rgb * spec_cel * sun_col_mask * 0.80;

	ALBEDO = water + glitter;
}
