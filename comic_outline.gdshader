shader_type spatial;
render_mode cull_front, unshaded, depth_draw_always;

uniform vec4 outline_color : source_color = vec4(0.02, 0.02, 0.02, 1.0); // #050505
uniform float outline_width : hint_range(0.001, 0.05) = 0.018;            // 0.018m

void vertex() {
	// Normalize by world matrix scale so vertex push is strictly 0.018 true world meters
	float model_scale = max(0.001, length(MODEL_MATRIX[0].xyz));
	VERTEX += NORMAL * (outline_width / model_scale);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
