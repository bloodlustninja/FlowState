shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Flat, crescent-shaped vertical water spray ribbon behind rear tires
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 0.95);      // Pure white spray core
uniform vec4 aqua_tint : source_color = vec4(0.78, 0.94, 1.0, 0.90);     // #C8F0FF anime water tone
uniform vec4 border_color : source_color = vec4(0.031, 0.031, 0.031, 1.0); // #080808 ink contour

void vertex() {
	// Spherical billboarding to Camera3D
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
}

void fragment() {
	// UV.y is vertical height (0 at bottom, 1 at top)
	// UV.x is lateral (0 to 1, center at 0.5)
	vec2 p = UV;

	// Crescent arc curvature: curves outward as it ascends
	float crescent_curve = sin(p.y * 3.14159) * 0.25;
	float dist_from_arc = abs(p.x - 0.5 - crescent_curve);

	// Width tapers at base and top tip
	float allowed_width = (1.0 - abs(p.y - 0.45) * 1.5) * 0.35;
	if (allowed_width <= 0.0 || dist_from_arc > allowed_width) {
		discard;
	}

	float norm_d = dist_from_arc / allowed_width; // 0 at core, 1 at edge

	vec3 col;
	if (norm_d > 0.78) {
		col = border_color.rgb; // Black ink border
	} else if (norm_d < 0.35) {
		col = core_color.rgb;   // White foaming spray core
	} else {
		col = aqua_tint.rgb;    // Stylized aqua mid-tone
	}

	ALBEDO = col;
	ALPHA = 1.0;
}
