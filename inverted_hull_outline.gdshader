// ==============================================================================
// MASTER SPEC: FlowState - Screen-Space Inverted Hull Outline Shader
// Clean clip-space normal extrusion for fixed 2px ink lines without node scale distortion.
// ==============================================================================
shader_type spatial;
render_mode cull_front, unshaded, depth_draw_always;

uniform vec4 outline_color : source_color = vec4(0.106, 0.071, 0.141, 1.0); // #1B1224 Deep Ink Black
uniform float outline_width : hint_range(0.5, 6.0) = 2.0;

void vertex() {
	vec4 clip_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	// Screen-space 2px silhouette offset
	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_pos.w * outline_width * 2.0;
	clip_pos.xy += offset;
	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
