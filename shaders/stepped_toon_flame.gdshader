shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Unshaded 3-tier stepped toon flame:
// Core: #FFFFFF, Mid: #FFD000, Rim: #FF2600, Outer ink contour: #0A0A0A
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);       // #FFFFFF
uniform vec4 mid_color : source_color = vec4(1.0, 0.816, 0.0, 1.0);       // #FFD000
uniform vec4 rim_color : source_color = vec4(1.0, 0.149, 0.0, 1.0);       // #FF2600
uniform vec4 ink_contour : source_color = vec4(0.039, 0.039, 0.039, 1.0); // #0A0A0A

void fragment() {
	// Silhouette detection via Normal dot View
	float ndv = abs(dot(NORMAL, VIEW));

	if (ndv < 0.22) {
		// Outer ink contour at glancing angles / silhouette edge
		ALBEDO = ink_contour.rgb;
		ALPHA = 1.0;
	} else {
		// 3-tier stepped color mapping based on UV.y and view alignment
		// Base of cone is hot white core, mid is vibrant yellow, tip is fiery orange-red
		float step_val = (1.0 - UV.y) * 0.7 + (1.0 - ndv) * 0.3;

		vec3 col;
		if (step_val < 0.35) {
			col = core_color.rgb;
		} else if (step_val < 0.72) {
			col = mid_color.rgb;
		} else {
			col = rim_color.rgb;
		}

		ALBEDO = col;
		ALPHA = 1.0;
	}
}
