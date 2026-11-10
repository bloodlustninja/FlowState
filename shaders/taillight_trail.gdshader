shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform vec4 trail_color : source_color = vec4(1.0, 0.08, 0.16, 0.65);

void fragment() {
	// UV.y is along trail length: 0.0 at car taillight, 1.0 at trailing tip
	// Smooth quadratic taper & fade along length so it smoothly vanishes
	float fade_len = pow(1.0 - clamp(UV.y, 0.0, 1.0), 2.2);
	
	// Soft beam falloff across ribbon width (UV.x from 0 to 1)
	float edge_dist = abs(UV.x - 0.5) * 2.0; // 0 at center, 1 at outer edges
	float fade_w = pow(1.0 - clamp(edge_dist, 0.0, 1.0), 2.0);
	
	// Intense glowing white-hot core down the center
	float core = pow(1.0 - clamp(edge_dist * 1.8, 0.0, 1.0), 3.5);
	
	vec3 col = mix(trail_color.rgb * 0.75, vec3(1.0, 0.70, 0.70), core * 0.65);
	float intensity = (fade_w * 0.50 + core * 0.50) * fade_len * trail_color.a;
	
	// In blend_add, ALBEDO directly adds light onto background without occluding geometry
	ALBEDO = col * intensity;
}
