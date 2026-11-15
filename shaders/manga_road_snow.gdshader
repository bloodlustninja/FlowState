shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// FLOWSTATE: MANGA SNOW-DUSTED ASPHALT ROAD SHADER (HAKONE SNOW PEAKS)
// Matches Ref Image 3:
// 1. Crisp dark inked asphalt center (#252A34)
// 2. Irregular white snow accumulation encroaching from both edges
// 3. Dark wet tire-track ruts carved through the slush along the driving lanes
// =============================================================================

uniform vec4 asphalt_center : source_color = vec4(0.145, 0.165, 0.204, 1.0); // #252A34 Dark Inked Asphalt
uniform vec4 snow_accumulation : source_color = vec4(0.957, 0.976, 1.0, 1.0); // #F4F9FF Pure Snow
uniform vec4 wet_rut_color : source_color = vec4(0.063, 0.075, 0.098, 1.0);   // #101319 Deep Wet Tire Rubber
uniform vec4 ink_black : source_color = vec4(0.02, 0.02, 0.03, 1.0);

float road_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 4375.85453);
}

void fragment() {
	vec2 uv = UV;
	float grain = road_hash(vec2(floor(uv.x * 240.0), floor(uv.y * 360.0)));
	vec3 base_col = asphalt_center.rgb * mix(0.95, 1.05, grain);

	// 1. Dual Tire-Track Rut Paths (Ref Image 3: Left & Right Car Track Pairs)
	float rut_l1 = smoothstep(0.040, 0.0, abs(uv.x - 0.310));
	float rut_l2 = smoothstep(0.040, 0.0, abs(uv.x - 0.410));
	float rut_r1 = smoothstep(0.042, 0.0, abs(uv.x - 0.590));
	float rut_r2 = smoothstep(0.042, 0.0, abs(uv.x - 0.690));
	float car_tracks = max(max(rut_l1, rut_l2), max(rut_r1, rut_r2));

	// Carved wet dark rubber tracks
	vec3 road_col = mix(base_col, wet_rut_color.rgb, car_tracks * 0.85);

	// 2. High-Center Compressed Slush Ridges (Between Tire Ruts)
	float slush_mid = smoothstep(0.055, 0.0, abs(uv.x - 0.500)) * 0.80;
	float slush_outer_l = smoothstep(0.045, 0.0, abs(uv.x - 0.220)) * 0.85;
	float slush_outer_r = smoothstep(0.045, 0.0, abs(uv.x - 0.780)) * 0.85;
	road_col = mix(road_col, snow_accumulation.rgb, clamp(slush_mid + slush_outer_l + slush_outer_r, 0.0, 0.90));

	// 3. Irregular Jagged Snow Banks Encroaching from Both Edges (Ref Image 3)
	float edge_noise = sin(uv.y * 24.0) * 0.04 + cos(uv.y * 70.0) * 0.02 + sin(uv.y * 140.0) * 0.008;
	float snow_bank_l = smoothstep(0.24, 0.02, uv.x + edge_noise);
	float snow_bank_r = smoothstep(0.76, 0.98, uv.x - edge_noise);
	float bank_mask = clamp(snow_bank_l + snow_bank_r, 0.0, 1.0);

	// Inked contour border along the snowbank jagged edge
	float ink_edge = step(0.92, bank_mask) * (1.0 - step(0.98, bank_mask));
	vec3 final_col = mix(road_col, snow_accumulation.rgb, bank_mask);
	final_col = mix(final_col, ink_black.rgb, ink_edge * 0.65);

	ALBEDO = final_col;
}
