shader_type spatial;
render_mode cull_front, unshaded, depth_draw_always;

// =============================================================================
// FLOWSTATE: MANGA ENVIRONMENT INVERTED-HULL INK OUTLINE SHADER
// Production-grade next-pass inverted-hull black ink contour for all props:
// Guardrails, buildings, rock cliffs, trees, and street furniture.
// =============================================================================

uniform vec4 outline_color : source_color = vec4(0.035, 0.043, 0.063, 1.0); // #090B10 Bold Manga Ink
uniform float outline_width : hint_range(0.01, 0.12) = 0.040;                // 0.040m true world thickness

void vertex() {
	// Normalize by world matrix scale so vertex extrusion is strictly world-consistent
	float model_scale = max(0.001, length(MODEL_MATRIX[0].xyz));
	VERTEX += NORMAL * (outline_width / model_scale);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
