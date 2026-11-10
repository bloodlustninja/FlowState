shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Spoiler Wingtip Vortex - Manga White (#FFFFFF) with 1px Solid Black Ink Edge (#080808)
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);      // Manga White #FFFFFF, alpha = 0.85
uniform vec4 ink_edge_color : source_color = vec4(0.03, 0.03, 0.04, 1.0); // 1px solid black ink edge
uniform float edge_threshold : hint_range(0.5, 0.95) = 0.72;

void fragment() {
	// In the needle ribbon mesh:
	// UV.y is 0.0 at the spoiler wingtip base and 1.0 at the trailing needle tail tip (3.2m trailing)
	// The blade tapers linearly to 0.0 width at the tip
	float hw_uv = 0.5 * (1.0 - UV.y);
	if (hw_uv <= 0.0001) {
		discard;
	}
	float norm_dist = abs(UV.x - 0.5) / hw_uv;
	if (norm_dist > 1.0) {
		discard;
	}

	// Smooth taper fade near the very end of the 3.2m needle
	float tip_fade = clamp(1.0 - (UV.y * 0.90), 0.0, 1.0);

	// Outer boundary renders crisp black ink contour edge; interior renders Manga White core
	if (norm_dist >= edge_threshold) {
		ALBEDO = ink_edge_color.rgb;
		ALPHA = ink_edge_color.a * tip_fade;
	} else {
		ALBEDO = core_color.rgb;
		ALPHA = core_color.a * tip_fade;
	}
}
