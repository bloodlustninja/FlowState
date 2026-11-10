shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

// Electronic toll gate lane indicator: Bright Green Arrow vs Glowing Red Cross
uniform bool is_open = false;
uniform vec4 green_color : source_color = vec4(0.0, 1.0, 0.40, 1.0);     // #00FF66
uniform vec4 red_color : source_color = vec4(1.0, 0.08, 0.15, 1.0);       // #FF1525
uniform vec4 bg_color : source_color = vec4(0.05, 0.06, 0.09, 1.0);       // Dark Obsidian

void fragment() {
	vec2 p = UV - vec2(0.5); // Center at (0, 0)
	bool lit = false;

	if (is_open) {
		// Green Downward Arrow "⬇"
		// Vertical stem: abs(p.x) < 0.10 and p.y between -0.35 and 0.10
		bool stem = (abs(p.x) < 0.10 && p.y >= -0.32 && p.y <= 0.12);
		// Arrowhead triangle pointing down
		bool head = (p.y > 0.05 && p.y < 0.38 && (abs(p.x) < (0.38 - p.y) * 1.15));
		lit = (stem || head);
	} else {
		// Red Cross "✖"
		// Two diagonal bars of width 0.12
		float d1 = abs(p.x - p.y);
		float d2 = abs(p.x + p.y);
		bool in_bounds = (abs(p.x) < 0.35 && abs(p.y) < 0.35);
		lit = in_bounds && (d1 < 0.10 || d2 < 0.10);
	}

	if (lit) {
		vec3 col = is_open ? green_color.rgb : red_color.rgb;
		ALBEDO = col;
		EMISSION = col * 4.8;
	} else {
		ALBEDO = bg_color.rgb;
		EMISSION = vec3(0.0);
	}
	ROUGHNESS = 0.50;
	SPECULAR = 0.30;
}
