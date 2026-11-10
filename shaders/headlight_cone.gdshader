shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 beam_color : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	// UV.y: 0.0 at car bumper, 1.0 at far end of beam
	// UV.x: 0.0 at left flank, 0.5 at optical center, 1.0 at right flank
	float forward_fade = smoothstep(1.0, 0.08, UV.y);
	float center_dist = abs(UV.x - 0.5) * 2.0;
	float lateral_fade = smoothstep(1.0, 0.15, center_dist);

	// Soft central bulb hotspot
	float hotspot = exp(-center_dist * 3.0) * (1.0 - UV.y);

	float beam_alpha = (forward_fade * lateral_fade * 0.25 + hotspot * 0.20) * intensity;
	ALBEDO = beam_color.rgb;
	ALPHA = clamp(beam_alpha, 0.0, 0.50);
}
