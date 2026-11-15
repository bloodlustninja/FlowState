shader_type canvas_item;

// =============================================================================
// FLOWSTATE: REALISTIC 2D MANGA PAGE-CURL FLIP SHADER
// Simulates physical manga tankobon paper curling from bottom-right to top-left:
// - Cylinder curl axis diagonally advancing across the page
// - Soft ambient drop shadow cast onto the page beneath
// - Cream vintage back-of-page reflection (#EDE7D8)
// - Peeking bottom-right corner tab when progress == 0.0
// =============================================================================

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float curl_radius : hint_range(0.05, 0.5) = 0.16;
uniform vec4 shadow_color : source_color = vec4(0.04, 0.05, 0.08, 0.65);
uniform vec4 back_page_color : source_color = vec4(0.94, 0.92, 0.88, 1.0);
uniform float corner_peek : hint_range(0.0, 0.25) = 0.06; // Small corner curl when idle

void fragment() {
	if (progress >= 0.99) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		return;
	}
	vec2 uv = UV;
	
	// Effective progress blending idle corner curl with active page turn
	float p = clamp(progress + (1.0 - progress) * corner_peek, 0.0, 1.0);
	
	// Diagonal curl axis from bottom-right (1.0, 1.0) towards top-left (0.0, 0.0)
	// Rotation angle: ~35 degrees for realistic manga corner lift
	vec2 curl_origin = vec2(1.2, 1.2) - vec2(p * 2.4, p * 2.2);
	vec2 curl_dir = normalize(vec2(1.0, 0.85)); // Perpendicular to curl crease line
	
	// Distance along curl direction relative to curl origin
	float d = dot(uv - curl_origin, curl_dir);
	
	vec4 col = texture(TEXTURE, uv);
	
	if (d > 0.0) {
		// Inside the curl zone
		float arc = d / curl_radius;
		if (arc < 3.14159) {
			// On the front curved cylinder: mirror back or show underside
			float shadow = smoothstep(3.14159, 1.57, arc) * shadow_color.a;
			vec4 back_col = mix(back_page_color, vec4(0.1, 0.1, 0.1, 1.0), 0.15);
			// Soft ink hatching lines on back of thin manga paper
			float bleed = sin((uv.x + uv.y) * 220.0) * 0.03;
			back_col.rgb += bleed;
			COLOR = mix(back_col, shadow_color, shadow * 0.45);
		} else {
			// Fully curled past crease: completely transparent to reveal next page beneath!
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		}
	} else if (d > -curl_radius * 1.6) {
		// Just before the curl crease: drop shadow cast by the curled page onto flat page
		float shadow_t = 1.0 - (-d / (curl_radius * 1.6));
		float s_alpha = shadow_t * shadow_color.a * (0.3 + 0.7 * progress);
		COLOR = mix(col, shadow_color, s_alpha);
	} else {
		// Normal flat manga page
		COLOR = col;
	}
}
