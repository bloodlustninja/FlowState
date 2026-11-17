shader_type canvas_item;
render_mode blend_mix;

// Screen-Edge Comic Speed Needles (Strictly Outer 15% Edges, Center 70% 100% Clear)
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.90);        // Manga White #FFFFFF
uniform vec4 ink_edge_color : source_color = vec4(0.04, 0.04, 0.05, 0.95);  // Crisp black ink border
uniform float aspect = 2.16;

void fragment() {
	if (intensity < 0.01) {
		discard;
	} else {
		vec2 uv = UV;
		float center_dist = abs(uv.x - 0.5);

		// Confined strictly to outer 15% edges (left: uv.x < 0.15, right: uv.x > 0.85)
		// The center 70% of the screen (0.15 <= uv.x <= 0.85) is kept 100% crystal clear for traffic visibility
		if (center_dist <= 0.35) {
			discard;
		} else {
			// Sharp cut-in boundary at 15% margin
			float edge_mask = smoothstep(0.35, 0.375, center_dist);

			// Road vanishing point
			vec2 origin = vec2(0.5, 0.46);
			vec2 d = uv - origin;
			d.x *= (1.0 / max(aspect, 0.01));
			float r = length(d);
			
			// Clamp radius safely away from zero and discard near-horizontal branch cut
			// Eliminates residual horizontal black/white scanline flicker across mobile GPUs
			if (r < 0.08 || abs(d.y) < 0.02) {
				discard;
			}
			
			// Smooth radial polar coordinates (atan(d.y, d.x)) normalized and clamped strictly to [0.001, 0.999]
			float a = atan(d.y, d.x);
			float norm_a = clamp((a + 3.14159265) / 6.2831853, 0.001, 0.999);

			// High frequency flashing (24 FPS stepped anime cadence)
			float t_step = floor(TIME * 24.0);

			// 64 radial sectors radiating from vanishing point
			float num_rays = 64.0;
			float ray_idx = floor(norm_a * num_rays);
			float rand_val = fract(sin(ray_idx * 78.233 + t_step * 0.37) * 43758.5453);
			float rand_len = fract(sin(ray_idx * 13.917 + t_step * 0.19) * 28461.1839);

			// Needle streak profile
			float ray_fract = abs(fract(norm_a * num_rays) - 0.5);

			// Sharp comic speed needles angled toward road vanishing point
			if (rand_val > 0.52 && r > (0.24 + rand_len * 0.20)) {
				if (ray_fract < 0.024) {
					// Sharp Manga White core - clamp strictly to [0.0, 1.0]
					float alpha = clamp(line_color.a * intensity * edge_mask, 0.0, 1.0);
					COLOR = vec4(clamp(line_color.rgb, 0.0, 1.0), alpha);
				} else if (ray_fract < 0.054) {
					// 1px solid black ink edge - clamp strictly to [0.0, 1.0]
					float alpha = clamp(ink_edge_color.a * intensity * edge_mask, 0.0, 1.0);
					COLOR = vec4(clamp(ink_edge_color.rgb, 0.0, 1.0), alpha);
				} else {
					discard;
				}
			} else {
				discard;
			}
		}
	}
}
