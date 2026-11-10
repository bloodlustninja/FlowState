shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 smear_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);     // Solid opaque white #FFFFFF
uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.06, 1.0); // Thin black boundary outline

void fragment() {
	vec2 uv = UV; // [0, 1]
	// Narrow point at front (y = 0), wider wedge at back (y = 1)
	float half_width = (1.0 - uv.y) * 0.42;
	float dist_x = abs(uv.x - 0.5);

	if (dist_x > half_width) {
		discard;
	}

	// Crisp black boundary stroke
	float border = step(half_width - 0.08, dist_x);
	vec3 col = mix(smear_color.rgb, outline_color.rgb, border);

	ALBEDO = col;
	ALPHA = 1.0; // Solid opaque!
}
