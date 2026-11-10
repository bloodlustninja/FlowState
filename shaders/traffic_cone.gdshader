shader_type spatial;
render_mode unshaded, cull_back;

// Rubber traffic cone with reflective white collar and black ink boundary
uniform vec4 orange_color : source_color = vec4(1.0, 0.333, 0.0, 1.0);  // Safety Orange #FF5500
uniform vec4 collar_color : source_color = vec4(0.96, 0.96, 1.0, 1.0);   // Reflective White
uniform vec4 ink_border : source_color = vec4(0.04, 0.04, 0.06, 1.0);    // Solid Black Ink

void fragment() {
	// UV.y represents vertical height (0.0 at base to 1.0 at tip)
	vec3 col;
	if (UV.y >= 0.40 && UV.y <= 0.68) {
		float dist_to_collar_edge = min(abs(UV.y - 0.40), abs(UV.y - 0.68));
		if (dist_to_collar_edge < 0.02) {
			col = ink_border.rgb; // Black ink stroke outlining reflective collar
		} else {
			col = collar_color.rgb;
		}
	} else {
		col = orange_color.rgb;
	}

	ALBEDO = col;
	ROUGHNESS = 0.70;
	SPECULAR = 0.20;
}
