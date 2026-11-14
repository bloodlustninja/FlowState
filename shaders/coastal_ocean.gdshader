shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// ENOSHIMA COASTAL OCEAN SHADER (ANIME / MANGA CEL SHADING)
// Matches Reference Image 1:
// 1. Deep cobalt & sapphire blue ocean surface (#0B3464 / #125899 / #188CB8)
// 2. Crisp stepped white comic wave surf lines washing along the golden beach
// 3. Warm golden sunset reflection trail across the water
// =============================================================================

uniform vec4 ocean_deep_color : source_color = vec4(0.045, 0.20, 0.40, 1.0);    // Deep Cobalt Blue #0B3464
uniform vec4 ocean_mid_color : source_color = vec4(0.07, 0.35, 0.60, 1.0);     // Coastal Sapphire #125899
uniform vec4 ocean_shallow_color : source_color = vec4(0.10, 0.55, 0.72, 1.0); // Azure Surf #188CB8
uniform vec4 sun_glitter_color : source_color = vec4(1.0, 0.78, 0.39, 1.0);   // Golden Sunset Glitter #FFC764
uniform vec4 wave_foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);        // Pure White Surf Foam

varying vec3 v_world_pos;
varying vec2 v_uv;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_uv = UV;
}

void fragment() {
	// 1. Shoreline Depth Gradient (UV.x = 0 at shore to 1.0 at far sea)
	vec3 water = mix(ocean_shallow_color.rgb, ocean_mid_color.rgb, smoothstep(0.0, 0.25, v_uv.x));
	water = mix(water, ocean_deep_color.rgb, smoothstep(0.25, 0.75, v_uv.x));

	// 2. Stylized Anime Wave Contours across open sea
	vec2 w_pos = v_world_pos.xz * 0.035;
	float w1 = sin(w_pos.x * 2.5 + w_pos.y * 1.8 + TIME * 0.9);
	float w2 = cos(w_pos.x * 1.5 - w_pos.y * 2.6 + TIME * 0.6);
	float wave = (w1 + w2) * 0.5;

	// Two-tone wave banding
	if (wave > 0.35 && v_uv.x > 0.15) {
		water = mix(water, ocean_shallow_color.rgb * 1.15, 0.45);
	}

	// 3. Stepped White Comic Wave Surf Lines Washing Shoreline (Ref Image 1)
	// Wave 1: Immediate shoreline break
	float surf_noise1 = sin(v_world_pos.z * 0.16 + TIME * 1.8) * 0.025;
	float surf1 = step(abs(v_uv.x - (0.035 + surf_noise1)), 0.018);

	// Wave 2: Mid-surf breaking crest
	float surf_noise2 = cos(v_world_pos.z * 0.11 + TIME * 1.2) * 0.035;
	float surf2 = step(abs(v_uv.x - (0.095 + surf_noise2)), 0.016);

	// Wave 3: Outer swell line
	float surf_noise3 = sin(v_world_pos.z * 0.08 + TIME * 0.8) * 0.045;
	float surf3 = step(abs(v_uv.x - (0.175 + surf_noise3)), 0.014);

	float surf_mask = max(surf1, max(surf2 * 0.90, surf3 * 0.75));
	water = mix(water, wave_foam_color.rgb, surf_mask);

	// 4. Sunset Sun Light Path across water
	// Sun is situated in positive X direction over the ocean
	float sun_path = smoothstep(160.0, 10.0, abs(v_world_pos.x - 55.0));
	float sun_sheen = step(0.40, sin(v_world_pos.z * 0.25 + TIME * 1.5)) * sun_path * (1.0 - smoothstep(0.0, 0.8, v_uv.x));
	water += sun_glitter_color.rgb * sun_sheen * 0.45;

	ALBEDO = water;
}
