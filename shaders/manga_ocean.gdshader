shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// FLOWSTATE: MANGA OCEAN SHADER (ENOSHIMA SEASIDE COAST)
// Matches Ref Image 1:
// 1. Vast cobalt ocean plane (#1967A3) fading to deep royal blue (#0D3D6E)
// 2. Animated parallel white stepped comic wave-foam lines (#FFFFFF) scrolling toward beach
// 3. Golden sunset glint & sun-path highlights reflecting across the water
// =============================================================================

uniform vec4 ocean_deep : source_color = vec4(0.051, 0.239, 0.431, 1.0);     // #0D3D6E Deep Royal
uniform vec4 ocean_surf : source_color = vec4(0.098, 0.404, 0.639, 1.0);     // #1967A3 Coastal Cobalt
uniform vec4 wave_foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);      // #FFFFFF Stepped Comic Foam
uniform vec4 sun_glint_color : source_color = vec4(1.0, 0.95, 0.63, 1.0);    // #FFF3A1 Golden Glint
uniform float wave_speed : hint_range(0.1, 5.0) = 1.4;

varying vec3 v_world_pos;
varying vec2 v_uv;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_uv = UV;
}

void fragment() {
	// UV.x: 0.0 at beach shoreline, 1.0 at outer horizon ocean
	float shore_t = clamp(v_uv.x, 0.0, 1.0);

	// 1. Stepped Two-Tone Manga Water Surface
	vec3 water = mix(ocean_surf.rgb, ocean_deep.rgb, smoothstep(0.08, 0.65, shore_t));

	// 2. Animated Parallel Stepped Comic Wave-Foam Lines Scrolling Toward Shoreline (Ref Image 1)
	// Waves propagate inwards toward the beach (decreasing v_uv.x)
	float scroll = TIME * wave_speed * 0.12;
	float wave_cycle = fract(shore_t * 5.5 - scroll);

	// Multi-tier stepped breakers with comic zigzag edge displacement
	float zig = sin(v_world_pos.z * 0.18 + scroll * 4.0) * 0.025 + cos(v_world_pos.z * 0.45) * 0.012;
	float wave_front1 = step(0.88, fract(shore_t * 6.0 - scroll + zig));
	float wave_front2 = step(0.92, fract(shore_t * 11.0 - scroll * 1.3 - zig));
	
	// Shoreline breaker: Constant white foam wash directly along the beach edge
	float shore_foam = step(shore_t, 0.035 + sin(v_world_pos.z * 0.20 + TIME * 2.2) * 0.015);

	// Combine foam masks with bold stepped comic borders
	float foam_mask = max(shore_foam, max(wave_front1 * (1.0 - shore_t * 0.7), wave_front2 * (1.0 - shore_t * 0.9)));
	water = mix(water, wave_foam_color.rgb, foam_mask);

	// 3. Golden Sunset Sun-Glint Trail
	// Centered over the bay horizon in positive X
	float sun_track = smoothstep(180.0, 15.0, abs(v_world_pos.x - 55.0));
	float glint_sheen = step(0.65, sin(v_world_pos.z * 0.35 + TIME * 2.5)) * sun_track * step(0.15, shore_t);
	water += sun_glint_color.rgb * glint_sheen * 0.55;

	ALBEDO = water;
}
