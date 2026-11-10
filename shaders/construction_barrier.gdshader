shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

// High-contrast orange/white diagonal chevron warning stripes with solid black ink borders
uniform vec4 orange_color : source_color = vec4(1.0, 0.333, 0.0, 1.0);  // #FF5500
uniform vec4 white_color : source_color = vec4(0.96, 0.96, 0.98, 1.0);   // #FFFFFF
uniform vec4 ink_border : source_color = vec4(0.04, 0.04, 0.06, 1.0);    // #0A0A0F
uniform float stripe_frequency : hint_range(2.0, 20.0) = 8.0;

void fragment() {
	// 45-degree diagonal stripe coordinate
	float stripe_coord = (UV.x + UV.y) * stripe_frequency;
	float f = fract(stripe_coord);
	
	vec3 col;
	if (f < 0.06 || (f >= 0.50 && f < 0.56)) {
		col = ink_border.rgb; // Crisp black ink line separating stripes
	} else if (f < 0.50) {
		col = orange_color.rgb;
	} else {
		col = white_color.rgb;
	}

	ALBEDO = col;
	ROUGHNESS = 0.65;
	SPECULAR = 0.20;
}
