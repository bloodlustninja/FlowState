shader_type canvas_item;

// =============================================================================
// FLOWSTATE: MANGA COMIC-PANEL CELL SHADER
// 1. Unfocused: High-contrast monochrome halftone screentone (Initial D manga page)
// 2. Focused: Full vibrant anime color with animated diagonal speed-lines
// 3. Undiscovered: Deep black-ink silhouette (#090B10) with subtle dark hatching
// =============================================================================

uniform float focus_amount : hint_range(0.0, 1.0) = 1.0;
uniform bool is_discovered = true;
uniform float speedline_intensity : hint_range(0.0, 1.0) = 0.40;
uniform vec4 accent_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);

// High-fidelity comic halftone raster function
float halftone_pattern(vec2 p, float angle, float scale) {
	float s = sin(angle);
	float c = cos(angle);
	vec2 r = vec2(c * p.x - s * p.y, s * p.x + c * p.y) * scale;
	return (sin(r.x) * sin(r.y)) * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = UV;
	vec4 base_tex = texture(TEXTURE, uv);

	// Luminance for monochrome manga screentone
	float lum = dot(base_tex.rgb, vec3(0.299, 0.587, 0.114));

	// 45-degree manga halftone dot grid
	float ht = halftone_pattern(FRAGCOORD.xy, 0.785398, 0.42);
	float ht_mask = step(ht, lum * 1.18);
	vec3 mono_col = mix(vec3(0.07, 0.08, 0.12), vec3(0.92, 0.94, 0.97), ht_mask);

	// Animated diagonal comic speed lines streaming across the frame
	float diag = fract((uv.x * 2.8 - uv.y * 4.6) + TIME * 4.2);
	float speedline = smoothstep(0.86, 0.98, diag) * speedline_intensity * focus_amount;

	vec3 final_rgb;
	if (!is_discovered) {
		// Deep black-ink silhouette with dark screentone
		final_rgb = mix(vec3(0.035, 0.043, 0.063), vec3(0.12, 0.14, 0.20), ht_mask * 0.22);
	} else {
		// Rich vibrant manga color
		vec3 vibrant_col = base_tex.rgb;
		// Blend halftone monochrome to full vibrant color
		final_rgb = mix(mono_col, vibrant_col, focus_amount);
		// Add streaming comic speed lines
		final_rgb = mix(final_rgb, vec3(1.0), speedline);
	}

	COLOR = vec4(final_rgb, base_tex.a);
}
