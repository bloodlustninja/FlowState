shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float outline_thickness : hint_range(0.0, 0.2) = 0.03;

// Match these parameters with your main smoke shader
uniform sampler2D noise_tex : repeat_enable;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;
uniform float vertex_displacement : hint_range(0.0, 1.0) = 0.3;

void vertex() {
	// 1. Apply the exact same noise displacement as the base pass
	float n = texture(noise_tex, UV + vec2(TIME * 0.2, TIME * 0.2)).r;
	VERTEX += NORMAL * (n - 0.5) * vertex_displacement;
	
	// 2. Push vertices outward along normals to form the outline hull
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	// Match the alpha dissolve so the outline erodes with the smoke
	float noise = texture(noise_tex, UV).r;
	float edge_mask = noise * COLOR.a;
	
	if (edge_mask < alpha_scissor) {
		discard;
	}
	
	ALBEDO = outline_color.rgb;
}
