shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// FLOWSTATE HIGHWAY ROADWAY CEL SHADER (ALL 4 MANGA BIOMES)
// Production-grade unshaded anime styling matching reference concept art:
// Mode 0: Shuto Dusk (Expressway asphalt, red/white curbs, yellow dashes)
// Mode 1: Neo-Shinjuku (Dark wet tarmac, magenta & cyan neon puddle reflections)
// Mode 2: Enoshima Coast (Sunlit coastal asphalt, white edge lines, yellow center)
// Mode 3: Hakone Snow (Alpine tarmac, rubber drift skid marks, snow slush edges)
// =============================================================================

uniform int biome_mode : hint_range(0, 3) = 0;
uniform vec4 asphalt_color : source_color = vec4(0.165, 0.185, 0.245, 1.0); // Clean Slate Tarmac #2A2F3E
uniform vec4 line_yellow : source_color = vec4(1.0, 0.82, 0.0, 1.0);       // Vibrant Anime Golden Yellow #FFD000
uniform vec4 line_white : source_color = vec4(0.96, 0.96, 0.98, 1.0);
uniform vec4 curb_red : source_color = vec4(0.85, 0.12, 0.15, 1.0);        // Safety Red Curb #D92027
uniform vec4 curb_white : source_color = vec4(1.0, 1.0, 1.0, 1.0);          // Crisp White Curb #FFFFFF
uniform vec4 tar_seam_color : source_color = vec4(0.09, 0.10, 0.14, 1.0);   // Dark Tar Seam #171A24

float road_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 4375.85453);
}

void fragment() {
	vec2 uv = UV;
	
	// Procedural road-grain noise
	float grain = road_hash(vec2(floor(uv.x * 240.0), floor(uv.y * 360.0)));
	vec3 base_tarmac = asphalt_color.rgb * mix(0.94, 1.06, grain);

	// Biome-specific asphalt base tones
	if (biome_mode == 1) {
		// Neo-Shinjuku: Dark wet midnight tarmac (Ref Image 2)
		base_tarmac = vec3(0.08, 0.09, 0.13) * mix(0.96, 1.04, grain);
	} else if (biome_mode == 2) {
		// Enoshima Coast: Warm sunlit coastal asphalt (Ref Image 1)
		base_tarmac = vec3(0.34, 0.30, 0.32) * mix(0.94, 1.06, grain);
	} else if (biome_mode == 3) {
		// Hakone Snow: Cold alpine asphalt (Ref Image 3)
		base_tarmac = vec3(0.15, 0.17, 0.22) * mix(0.93, 1.07, grain);
	}

	// Dark tar seam streaks running along Z-axis (wheel tracks & asphalt seams)
	float seam1 = smoothstep(0.005, 0.0, abs(uv.x - 0.280));
	float seam2 = smoothstep(0.004, 0.0, abs(uv.x - 0.500));
	float seam3 = smoothstep(0.005, 0.0, abs(uv.x - 0.720));
	float wheel_groove1 = smoothstep(0.035, 0.0, abs(uv.x - 0.390)) * 0.22;
	float wheel_groove2 = smoothstep(0.035, 0.0, abs(uv.x - 0.610)) * 0.22;
	float tar_mask = clamp(seam1 * 0.55 + seam2 * 0.45 + seam3 * 0.55 + wheel_groove1 + wheel_groove2, 0.0, 0.70);
	vec3 col = mix(base_tarmac, tar_seam_color.rgb, tar_mask);

	// =========================================================================
	// BIOME 1: NEO-SHINJUKU ALLEY — VIBRANT WET NEON PUDDLE REFLECTIONS (Ref Image 2)
	// =========================================================================
	if (biome_mode == 1) {
		// Wet asphalt specular sheen
		float wet_track1 = smoothstep(0.12, 0.0, abs(uv.x - 0.320));
		float wet_track2 = smoothstep(0.12, 0.0, abs(uv.x - 0.680));
		float wet_sheen = max(wet_track1, wet_track2);

		// Puddle noise mask
		float p_noise = sin(uv.y * 28.0) * cos(uv.x * 16.0);
		float puddle_mask = smoothstep(-0.15, 0.65, p_noise);

		// LEFT LANE: Electric Magenta / Hot Pink Neon Reflections (#FF1875)
		float mag_lane = smoothstep(0.50, 0.10, uv.x);
		vec3 mag_neon = vec3(1.0, 0.10, 0.46); // Electric Magenta #FF1875
		vec3 mag_reflect = mag_neon * mag_lane * (0.35 + 0.65 * puddle_mask);

		// RIGHT LANE: Electric Cyan Neon Reflections (#00E5FF)
		float cyn_lane = smoothstep(0.50, 0.90, uv.x);
		vec3 cyn_neon = vec3(0.0, 0.88, 1.0);  // Electric Cyan #00E5FF
		vec3 cyn_reflect = cyn_neon * cyn_lane * (0.35 + 0.65 * puddle_mask);

		col += (mag_reflect + cyn_reflect) * 0.80;
	}

	// =========================================================================
	// BIOME 3: HAKONE SNOW — HEAVY DRIFT TIRE TRACKS & SNOW EDGES (Ref Image 3)
	// =========================================================================
	if (biome_mode == 3) {
		// Prominent dark black rubber drift skid marks & twin tire tracks
		float track1 = smoothstep(0.045, 0.0, abs(uv.x - 0.340));
		float track2 = smoothstep(0.045, 0.0, abs(uv.x - 0.440));
		float track3 = smoothstep(0.050, 0.0, abs(uv.x - 0.560));
		float track4 = smoothstep(0.050, 0.0, abs(uv.x - 0.660));
		// Lateral drift arc overlay
		float drift_arc = smoothstep(0.075, 0.0, abs(uv.x - (0.50 + sin(uv.y * 6.5) * 0.16)));
		// Heavy rubber tire tracks mask
		float rubber = clamp((track1 + track2 + track3 + track4) * 0.75 + drift_arc * 0.60, 0.0, 0.92);
		col = mix(col, vec3(0.04, 0.05, 0.07), rubber); // Deep black rubber drift tracks

		// Road edge snow slush dusting encroaching onto tarmac
		float snow_left = smoothstep(0.16, 0.01, uv.x);
		float snow_right = smoothstep(0.84, 0.99, uv.x);
		float edge_noise = sin(uv.y * 35.0) * 0.04 + cos(uv.y * 90.0) * 0.02;
		float snow_mask = clamp((snow_left + snow_right + edge_noise), 0.0, 1.0);
		col = mix(col, vec3(0.94, 0.97, 1.0), snow_mask); // Frosted pure snow slush
	}

	// --- ROAD LANE MARKINGS & CURBS ---

	// MODE 0: SHUTO EXPRESSWAY (Original standard with red/white curbs)
	if (biome_mode == 0) {
		float curb_w = 0.055;
		if (uv.x < curb_w || uv.x > (1.0 - curb_w)) {
			float curb_step = mod(uv.y * 1.5, 2.0);
			col = (curb_step < 1.0) ? curb_red.rgb : curb_white.rgb;
		} else if ((uv.x >= 0.055 && uv.x < 0.070) || (uv.x > 0.930 && uv.x <= 0.945)) {
			float d_edge = min(abs(uv.x - 0.055), abs(uv.x - 0.070));
			if (uv.x > 0.5) {
				d_edge = min(abs(uv.x - 0.930), abs(uv.x - 0.945));
			}
			if (d_edge < 0.0025) {
				col = vec3(0.04, 0.04, 0.06); // 1px black ink border
			} else {
				col = line_white.rgb;
			}
		} else {
			float dash = mod(uv.y * 0.8, 1.0);
			if (dash < 0.54) {
				float d1 = abs(uv.x - 0.280);
				float d2 = abs(uv.x - 0.500);
				float d3 = abs(uv.x - 0.720);
				float min_d = min(min(d1, d2), d3);
				if (min_d < 0.0075) {
					col = line_yellow.rgb * mix(0.93, 1.05, grain);
				} else if (min_d < 0.0095) {
					col = vec3(0.04, 0.04, 0.06);
				}
			}
		}
	}
	// MODE 1: NEO-SHINJUKU ALLEY (Urban Japanese street: clean white lines, no red/white curbs)
	else if (biome_mode == 1) {
		// Crisp solid white edge lines
		if ((uv.x >= 0.035 && uv.x <= 0.055) || (uv.x >= 0.945 && uv.x <= 0.965)) {
			col = line_white.rgb;
		}
		// Single white dashed center line dividing 2 lanes
		else {
			float dash = mod(uv.y * 0.70, 1.0);
			if (dash < 0.52) {
				float d_ctr = abs(uv.x - 0.500);
				if (d_ctr < 0.0085) {
					col = line_white.rgb;
				} else if (d_ctr < 0.0105) {
					col = vec3(0.03, 0.03, 0.05);
				}
			}
		}
	}
	// MODE 2: ENOSHIMA COAST (Sunlit coastal highway: golden-yellow dashed center, solid white edge)
	else if (biome_mode == 2) {
		// Clean solid white edge line on right (ocean side) & left (cliff side)
		if ((uv.x >= 0.035 && uv.x <= 0.055) || (uv.x >= 0.945 && uv.x <= 0.965)) {
			float d_edge = min(abs(uv.x - 0.035), abs(uv.x - 0.055));
			if (uv.x > 0.5) d_edge = min(abs(uv.x - 0.945), abs(uv.x - 0.965));
			if (d_edge < 0.002) {
				col = vec3(0.04, 0.04, 0.06);
			} else {
				col = line_white.rgb;
			}
		}
		// Single prominent golden-yellow dashed centerline (Ref Image 1)
		else {
			float dash = mod(uv.y * 0.75, 1.0);
			if (dash < 0.52) {
				float d_ctr = abs(uv.x - 0.500);
				if (d_ctr < 0.0090) {
					col = line_yellow.rgb;
				} else if (d_ctr < 0.0115) {
					col = vec3(0.04, 0.04, 0.06);
				}
			}
		}
	}
	// MODE 3: HAKONE SNOW (Alpine touge pass: icy white roadside snow dusting, tire marks)
	else if (biome_mode == 3) {
		// Worn white edge lines partially obscured by snow
		if ((uv.x >= 0.075 && uv.x <= 0.092) || (uv.x >= 0.908 && uv.x <= 0.925)) {
			col = mix(col, line_white.rgb, 0.80);
		}
		// Worn yellow dashed centerline
		else {
			float dash = mod(uv.y * 0.75, 1.0);
			if (dash < 0.50) {
				float d_ctr = abs(uv.x - 0.500);
				if (d_ctr < 0.0080) {
					col = mix(col, line_yellow.rgb, 0.75); // Slightly weathered touge paint
				}
			}
		}
	}

	ALBEDO = col;
}
