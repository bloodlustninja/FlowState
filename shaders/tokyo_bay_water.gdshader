shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// PRODUCTION-GRADE TOKYO BAY WATER CEL SHADER (UNSHADED ANIME WATER)
// 1. Deep Tokyo Bay naval tones with stylized anime wave ripples
// 2. Subtle warm sunset sky reflection trail across the bay towards the highway
// 3. Grounded water boundary meeting seawalls and piers naturally
// 4. Zero blown-out specular flare
// =============================================================================

uniform vec4 water_deep_color : source_color = vec4(0.04, 0.08, 0.14, 1.0);
uniform vec4 water_shallow_color : source_color = vec4(0.08, 0.14, 0.22, 1.0);
uniform vec4 horizon_fog_color : source_color = vec4(0.20, 0.24, 0.32, 1.0);
uniform vec4 sun_reflection_color : source_color = vec4(0.85, 0.60, 0.35, 1.0);
uniform vec3 sun_direction = vec3(-0.5, -0.8, -0.3);
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Multi-octave stylized anime bay ripple
	vec2 uv_wave = v_world_pos.xz * 0.022;
	float wave1 = sin(uv_wave.x * 3.2 + uv_wave.y * 1.8 + TIME * 0.75);
	float wave2 = cos(uv_wave.x * 2.2 - uv_wave.y * 2.9 + TIME * 0.55);
	float wave3 = sin((uv_wave.x + uv_wave.y) * 4.2 + TIME * 0.95);
	float ripple = (wave1 + wave2 * 0.75 + wave3 * 0.40) * 0.45;

	// Deep anime water palette with time-of-day adaptation
	vec3 deep_tone = mix(water_deep_color.rgb, vec3(0.02, 0.04, 0.08), night_factor * 0.75);
	vec3 shallow_tone = mix(water_shallow_color.rgb, vec3(0.05, 0.08, 0.14), night_factor * 0.75);

	// Stylized 2-step anime water ripple bands
	float wave_cel = step(0.10, ripple);
	vec3 water_col = mix(deep_tone, shallow_tone, wave_cel * 0.45 + 0.55);

	// Subtle warm sunset sun reflection trail across Tokyo Bay
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_pos);
	vec3 light_dir = normalize(-sun_direction);
	vec3 half_vec = normalize(view_dir + light_dir);
	float spec = pow(max(0.0, dot(vec3(0.0, 1.0, 0.0), half_vec)), 48.0);
	float spec_break = step(0.20, spec) * spec;
	vec3 sun_glint = sun_reflection_color.rgb * spec_break * (1.0 - night_factor * 0.85) * 0.35;

	// Distant harbor & skyline light reflection shimmer at dusk/night
	float city_reflect = step(0.25, ripple) * (0.02 + 0.12 * night_factor) * step(80.0, v_world_pos.x);
	vec3 city_gleam = vec3(0.85, 0.70, 0.35) * city_reflect;

	// Smooth atmospheric horizon grounding
	float cam_z = INV_VIEW_MATRIX[3].z;
	float dist_z = abs(v_world_pos.z - cam_z);
	float dist_fog = clamp((dist_z - 550.0) / 1200.0, 0.0, 0.35);

	vec3 maritime_depth = mix(vec3(0.05, 0.09, 0.15), horizon_fog_color.rgb * 0.35, 0.25);
	vec3 final_water = mix(water_col + sun_glint + city_gleam, maritime_depth, dist_fog);

	ALBEDO = clamp(final_water, vec3(0.0), vec3(0.40));
	ROUGHNESS = 0.90;
	METALLIC = 0.0;
}
