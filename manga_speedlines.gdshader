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
			float a = atan(d.y, d.x);

			// High frequency flashing (24 FPS stepped anime cadence)
			float t_step = floor(TIME * 24.0);

			// 64 radial sectors radiating from vanishing point
			float num_rays = 64.0;
			float ray_idx = floor(a * (num_rays / 6.2831853));
			float rand_val = fract(sin(ray_idx * 78.233 + t_step * 0.37) * 43758.5453);
			float rand_len = fract(sin(ray_idx * 13.917 + t_step * 0.19) * 28461.1839);

			// Needle streak profile
			float ray_fract = abs(fract(a * (num_rays / 6.2831853)) - 0.5);

			// Sharp comic speed needles angled toward road vanishing point
			if (rand_val > 0.52 && r > (0.24 + rand_len * 0.20)) {
				if (ray_fract < 0.024) {
					// Sharp Manga White core
					COLOR = vec4(line_color.rgb, line_color.a * intensity * edge_mask);
				} else if (ray_fract < 0.054) {
					// 1px solid black ink edge
					COLOR = vec4(ink_edge_color.rgb, ink_edge_color.a * intensity * edge_mask);
				} else {
					discard;
				}
			} else {
				discard;
			}
		}
	}
}
