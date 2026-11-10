shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Unshaded stepped toon guardrail spark: Core: #FFFFFF, Mid: #FFAA00, Rim: #080808
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);       // #FFFFFF
uniform vec4 mid_color : source_color = vec4(1.0, 0.667, 0.0, 1.0);       // #FFAA00
uniform vec4 rim_color : source_color = vec4(0.031, 0.031, 0.031, 1.0);   // #080808

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
	// Elongated geometric spark wedge in UV space
	vec2 p = UV - vec2(0.5, 0.5);
	float r = length(p * vec2(1.0, 0.35));

	if (r > 0.5) {
		discard;
	}

	vec3 col;
	if (r < 0.18) {
		col = core_color.rgb;
	} else if (r < 0.38) {
		col = mid_color.rgb;
	} else {
		col = rim_color.rgb;
	}

	ALBEDO = col;
	ALPHA = 1.0;
}
