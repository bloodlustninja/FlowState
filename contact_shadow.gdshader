shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Hard vehicle contact occlusion shadow quad
uniform vec4 shadow_color : source_color = vec4(0.04, 0.04, 0.08, 0.75);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0; // [-1.0, 1.0]

	// Elliptical black ink decal tightly bounded under tires
	vec2 ellipse_scale = vec2(1.0, 0.55);
	float dist = length(p * ellipse_scale);

	// Inked comic rim falloff (hard ink edge)
	float alpha = smoothstep(0.96, 0.82, dist) * shadow_color.a;

	ALBEDO = shadow_color.rgb;
	ALPHA = alpha;
}
