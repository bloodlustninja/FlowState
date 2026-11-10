shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;

uniform vec4 asphalt_color : source_color = vec4(0.157, 0.176, 0.231, 1.0); // Dark Graphic Tarmac #282D3B
uniform vec4 line_yellow : source_color = vec4(1.0, 0.816, 0.0, 1.0);       // Vibrant Anime Golden Yellow #FFD000
uniform vec4 line_white : source_color = vec4(0.96, 0.96, 0.98, 1.0);
uniform vec4 curb_red : source_color = vec4(0.851, 0.125, 0.153, 1.0);       // Safety Red Curb #D92027
uniform vec4 curb_white : source_color = vec4(1.0, 1.0, 1.0, 1.0);           // Crisp White Curb #FFFFFF
uniform vec4 tar_seam_color : source_color = vec4(0.08, 0.09, 0.12, 1.0);    // Dark Tar Seam #14171F
uniform bool is_wet = false;
uniform float wet_reflectivity : hint_range(0.0, 1.0) = 0.0;

float road_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 4375.85453);
}

void fragment() {
	vec2 uv = UV;
	
	// Procedural road-grain noise
	float grain = road_hash(vec2(floor(uv.x * 240.0), floor(uv.y * 360.0)));
	vec3 base_tarmac = asphalt_color.rgb * mix(0.92, 1.06, grain);

	// Wet Tarmac Material: Deepen road albedo to dark slate #141722 when raining
	if (is_wet) {
		base_tarmac = mix(base_tarmac, vec3(0.078, 0.090, 0.133), 0.75); // Dark Slate #141722
	}

	// Dark tar seam streaks running along Z-axis (wheel tracks & asphalt seams)
	float seam1 = smoothstep(0.005, 0.0, abs(uv.x - 0.280));
	float seam2 = smoothstep(0.004, 0.0, abs(uv.x - 0.500));
	float seam3 = smoothstep(0.005, 0.0, abs(uv.x - 0.720));
	float wheel_groove1 = smoothstep(0.035, 0.0, abs(uv.x - 0.390)) * 0.22;
	float wheel_groove2 = smoothstep(0.035, 0.0, abs(uv.x - 0.610)) * 0.22;
	float tar_mask = clamp(seam1 * 0.55 + seam2 * 0.45 + seam3 * 0.55 + wheel_groove1 + wheel_groove2, 0.0, 0.70);
	vec3 col = mix(base_tarmac, tar_seam_color.rgb, tar_mask);

	// Wet reflective gloss along wheel grooves & taillight reflection band
	if (is_wet) {
		float wet_track1 = smoothstep(0.05, 0.0, abs(uv.x - 0.390));
		float wet_track2 = smoothstep(0.05, 0.0, abs(uv.x - 0.610));
		float wet_sheen = max(wet_track1, wet_track2) * wet_reflectivity * 0.60;
		col = mix(col, vec3(0.18, 0.22, 0.32), wet_sheen);
	}

	// Alternating red/white safety curb stripe pattern along outer shoulders (~1.1m wide)
	float curb_w = 0.055;
	if (uv.x < curb_w || uv.x > (1.0 - curb_w)) {
		float curb_step = mod(uv.y * 1.5, 2.0);
		col = (curb_step < 1.0) ? curb_red.rgb : curb_white.rgb;
	}
	// Solid white shoulder line inside the curb with clean 1px solid black ink edge
	else if ((uv.x >= 0.055 && uv.x < 0.070) || (uv.x > 0.930 && uv.x <= 0.945)) {
		float d_edge = min(abs(uv.x - 0.055), abs(uv.x - 0.070));
		if (uv.x > 0.5) {
			d_edge = min(abs(uv.x - 0.930), abs(uv.x - 0.945));
		}
		if (d_edge < 0.0025) {
			col = vec3(0.04, 0.04, 0.06); // 1px black ink border
		} else {
			col = line_white.rgb;
		}
	}
	// 3 Dashed yellow divider lines separating the 4 lanes (at 28%, 50%, 72%)
	else {
		float dash = mod(uv.y * 0.8, 1.0);
		if (dash < 0.54) { // 54% painted dash, 46% asphalt gap
			float d1 = abs(uv.x - 0.280);
			float d2 = abs(uv.x - 0.500);
			float d3 = abs(uv.x - 0.720);
			float min_d = min(min(d1, d2), d3);
			if (min_d < 0.0075) {
				// Subtle road-wear variation across yellow paint
				float paint_wear = mix(0.93, 1.05, grain);
				col = line_yellow.rgb * paint_wear;
			} else if (min_d < 0.0095) {
				col = vec3(0.04, 0.04, 0.06); // Crisp black ink border
			}
		}
	}

	ALBEDO = col;
	if (is_wet) {
		ROUGHNESS = 0.18;
		SPECULAR = 0.75; // Increased specular toon stepping
	} else {
		ROUGHNESS = 0.82;
		SPECULAR = 0.15;
	}
}
