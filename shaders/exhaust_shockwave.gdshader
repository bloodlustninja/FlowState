shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Concentric flat unshaded ring quad (White inner stroke, black inked outer stroke)
uniform vec4 inner_stroke_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);       // #FFFFFF
uniform vec4 outer_stroke_color : source_color = vec4(0.031, 0.031, 0.031, 1.0); // #080808

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
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);

	if (r < 0.55 || r > 1.0) {
		discard;
	}

	vec3 col;
	if (r < 0.65) {
		col = outer_stroke_color.rgb; // Inner black ink contour
	} else if (r < 0.88) {
		col = inner_stroke_color.rgb; // Vivid white shockwave core
	} else {
		col = outer_stroke_color.rgb; // Outer black ink contour
	}

	ALBEDO = col;
	ALPHA = 1.0;
}
