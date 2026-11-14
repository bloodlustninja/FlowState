shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 0.93, 1.0);  // Blazing white-lemon core #FFFFEE
uniform vec4 mid_color : source_color = vec4(1.0, 0.87, 0.22, 1.0);   // Radiant anime sun yellow #FFDE38
uniform vec4 rim_color : source_color = vec4(1.0, 0.65, 0.13, 1.0);   // Warm sunset golden orange #FFA622
uniform vec4 corona_color : source_color = vec4(1.0, 0.47, 0.12, 0.0);// Soft outer sunset aura

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	// Radial gradient from blazing hot center to rich sunset glow
	float t = smoothstep(0.10, 0.82, r);
	vec3 col = mix(core_color.rgb, mid_color.rgb, t);
	float rim_t = smoothstep(0.68, 0.97, r);
	col = mix(col, rim_color.rgb, rim_t);

	// Crisp manga edge with subtle anti-aliasing
	float alpha = smoothstep(1.0, 0.96, r);

	ALBEDO = col;
	ALPHA = alpha;
}
