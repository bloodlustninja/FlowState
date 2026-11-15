shader_type canvas_item;

// =============================================================================
// FLOWSTATE: BLACK-AND-WHITE MANGA INK & HALFTONE SCREEN-TONE SHADER
// Filters live 3D SubViewport camera feeds into high-contrast B&W manga panels:
// - Deep black ink shadows (#0B0D12)
// - 45-degree diagonal ink cross-hatching in dark midtones
// - Ben-Day / manga screentone dot raster in bright midtones
// - Crisp paper-white highlights (#F8FAFC)
// - Dynamic Sobel/tap edge detection for black manga line-work
// - 'bw_ink_mix' and 'wipe_radius' for seamless zoom dive into full-color 3D!
// =============================================================================

uniform float bw_ink_mix : hint_range(0.0, 1.0) = 0.75;
uniform float wipe_radius : hint_range(0.0, 2.5) = 0.0;
uniform vec2 wipe_center = vec2(0.5, 0.5);
uniform float halftone_scale : hint_range(0.1, 2.0) = 0.55;
uniform float hatch_density : hint_range(0.1, 2.0) = 0.65;
uniform float edge_strength : hint_range(0.0, 5.0) = 1.6;
uniform vec3 ink_color : source_color = vec3(0.043, 0.051, 0.071); // #0B0D12 Deep Black Manga Ink
uniform vec3 paper_color : source_color = vec3(0.973, 0.965, 0.941); // #F8F6F0 Warm Manga Paper

// 45-Degree Rotated Manga Halftone Dot Raster
float get_halftone(vec2 p, float scale) {
	float angle = 0.785398; // 45 degrees
	mat2 rot = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
	vec2 rp = rot * p * scale;
	vec2 grid = fract(rp) - vec2(0.5);
	return length(grid) * 2.0; // Distance to cell center [0, ~1.414]
}

// 45-Degree Diagonal Manga Cross-Hatching
float get_hatching(vec2 p, float density) {
	float d1 = sin((p.x + p.y) * density * 0.75);
	float d2 = sin((p.x - p.y) * density * 0.75);
	return max(step(0.35, d1), step(0.65, d2));
}

void fragment() {
	vec2 uv = UV;
	vec4 col = texture(TEXTURE, uv);

	// 1. Luminance
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));

	// 2. High-Frequency Screen-Space Pixel Coordinates for Stippling/Halftone
	vec2 sp = FRAGCOORD.xy;

	// 3. Multi-tier Manga Ink Tone Mapping
	vec3 bw_col;

	if (lum < 0.20) {
		// Pure Black Ink Shadows
		bw_col = ink_color;
	} else if (lum < 0.44) {
		// Dark Midtone: Diagonal Cross-Hatching + Deep Ink
		float hatch = get_hatching(sp, hatch_density);
		bw_col = mix(ink_color, paper_color, (1.0 - hatch) * (lum - 0.20) / 0.24 * 0.45);
	} else if (lum < 0.78) {
		// Bright Midtone: Ben-Day Halftone Screentone Grid
		float dot_dist = get_halftone(sp, halftone_scale);
		float dot_threshold = (1.0 - lum) * 1.35;
		float dot_mask = step(dot_dist, dot_threshold);
		bw_col = mix(paper_color, ink_color, dot_mask);
	} else {
		// Sunlit / High-Gleam Manga Paper Highlights
		bw_col = paper_color;
	}

	// 4. Contrast Boost & Edge Pop (Simulate manga pen inking on high contrast contours)
	vec2 px = TEXTURE_PIXEL_SIZE;
	float lum_r = dot(texture(TEXTURE, uv + vec2(px.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	float lum_u = dot(texture(TEXTURE, uv + vec2(0.0, px.y)).rgb, vec3(0.299, 0.587, 0.114));
	float edge = (abs(lum - lum_r) + abs(lum - lum_u)) * edge_strength;
	if (edge > 0.18) {
		bw_col = mix(bw_col, ink_color, clamp((edge - 0.18) * 3.5, 0.0, 1.0));
	}

	// 5. Radial Ink-Wash Wipe (for seamless dive into color)
	float aspect = 1080.0 / 1920.0;
	vec2 wipe_uv = (uv - wipe_center) * vec2(1.0, 1.0 / aspect);
	float dist_from_center = length(wipe_uv);
	float wipe_mask = smoothstep(wipe_radius - 0.15, wipe_radius + 0.15, dist_from_center);

	// Combined blend factor: 0.75 = 25% Color + 75% Manga Ink, 0.0 = Vibrant 3D Color
	float effective_bw = clamp(bw_ink_mix * wipe_mask, 0.0, 1.0);

	// Subtle saturation pop so 25% color reads rich and vivid like manga watercolor
	vec3 sat_col = mix(vec3(lum), col.rgb, 1.20);
	vec3 final_rgb = mix(sat_col, bw_col, effective_bw);
	COLOR = vec4(final_rgb, col.a);
}
