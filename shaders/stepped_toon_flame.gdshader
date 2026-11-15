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

	if (ndv < 0.18) {
		// Outer ink contour at glancing angles / silhouette edge
		ALBEDO = ink_contour.rgb;
		ALPHA = 1.0;
	} else {
		// Electric cyan-to-white gradient along cone length (#00E5FF -> #FFFFFF)
		// Base (UV.y ~ 1.0) is hot white core, tapering along Z into electric cyan
		float gradient = clamp(UV.y * 1.3 - (1.0 - ndv) * 0.35, 0.0, 1.0);
		vec3 col = mix(mid_color.rgb, core_color.rgb, smoothstep(0.25, 0.85, gradient));

		ALBEDO = col;
		ALPHA = 1.0;
	}
}
