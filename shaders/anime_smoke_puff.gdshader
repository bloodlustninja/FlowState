shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Stepped 2D Anime Tire Smoke Puff
// Circular puff with base tone #F5EFEB and a crisp 1.5px black ink border #080808
uniform vec4 base_color : source_color = vec4(0.961, 0.937, 0.922, 1.0); // #F5EFEB
uniform vec4 border_color : source_color = vec4(0.031, 0.031, 0.031, 1.0); // #080808
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// Spherical billboarding to face Camera3D at all times
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
	if (r > 1.0) {
		discard;
	}

	// Crisp 1.5px border outline
	float border = step(0.80, r);
	vec3 col = mix(base_color.rgb, border_color.rgb, border);
	ALBEDO = col;
	ALPHA = alpha;
}
