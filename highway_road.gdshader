shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// FLOWSTATE HIGHWAY ROADWAY CEL SHADER (ALL 4 MANGA BIOMES)
// Production-grade unshaded anime styling matching reference concept art:
// Mode 0: Shuto Dusk (Expressway asphalt, red/white curbs, yellow dashes)
// Mode 1: Neo-Shinjuku (Dark wet tarmac, specular neon puddle reflections)
// Mode 2: Enoshima Coast (Sunlit coastal asphalt, white edge lines, yellow center)
// Mode 3: Hakone Snow (Alpine touge tarmac, dark rubber tire ruts, snowbanks)
// =============================================================================

uniform int biome_mode : hint_range(0, 3) = 0;
uniform vec4 asphalt_color : source_color = vec4(0.165, 0.185, 0.245, 1.0); // Clean Slate Tarmac #2A2F3E
uniform vec4 line_yellow : source_color = vec4(1.0, 0.82, 0.0, 1.0);       // Vibrant Anime Golden Yellow #FFD000
uniform vec4 line_white : source_color = vec4(0.96, 0.96, 0.98, 1.0);
uniform vec4 curb_red : source_color = vec4(0.85, 0.12, 0.15, 1.0);        // Safety Red Curb #D92027
uniform vec4 curb_white : source_color = vec4(1.0, 1.0, 1.0, 1.0);          // Crisp White Curb #FFFFFF
uniform vec4 tar_seam_color : source_color = vec4(0.09, 0.10, 0.14, 1.0);   // Dark Tar Seam #171A24
uniform vec4 ink_black : source_color = vec4(0.03, 0.03, 0.05, 1.0);

float road_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 4375.85453);
}

void fragment() {
	vec2 uv = UV;
	
	// Procedural road-grain noise
	float grain = road_hash(vec2(floor(uv.x * 240.0), floor(uv.y * 360.0)));
	vec3 base_tarmac = asphalt_color.rgb * mix(0.95, 1.05, grain);

	// Biome-specific asphalt base tones
	if (biome_mode == 1) {
		// Neo-Shinjuku: Dark wet midnight tarmac (Ref Image 2)
		base_tarmac = vec3(0.08, 0.09, 0.12) * mix(0.96, 1.04, grain);
	} else if (biome_mode == 2) {
		// Enoshima Coast: Warm sunlit coastal asphalt (Ref Image 1)
		base_tarmac = vec3(0.24, 0.25, 0.28) * mix(0.95, 1.05, grain);
	} else if (biome_mode == 3) {
		// Hakone Snow: Cold wet alpine asphalt (Ref Image 3)
		base_tarmac = vec3(0.14, 0.16, 0.20) * mix(0.94, 1.06, grain);
	}

	// Longitudinal asphalt seams & wheel groove shading
	float seam1 = smoothstep(0.005, 0.0, abs(uv.x - 0.280));
	float seam2 = smoothstep(0.004, 0.0, abs(uv.x - 0.500));
	float seam3 = smoothstep(0.005, 0.0, abs(uv.x - 0.720));
	float wheel_groove1 = smoothstep(0.035, 0.0, abs(uv.x - 0.390)) * 0.18;
	float wheel_groove2 = smoothstep(0.035, 0.0, abs(uv.x - 0.610)) * 0.18;
	float tar_mask = clamp(seam1 * 0.45 + seam2 * 0.35 + seam3 * 0.45 + wheel_groove1 + wheel_groove2, 0.0, 0.60);
	vec3 col = mix(base_tarmac, tar_seam_color.rgb, tar_mask);

	// =========================================================================
	// BIOME 1: NEO-SHINJUKU ALLEY — AUTHENTIC WET ASPHALT WITH PUDDLE REFLECTIONS (Ref Image 2)
	// =========================================================================
	if (biome_mode == 1) {
		// Organic irregular puddle noise masks
		float p1 = sin(uv.y * 6.5 + uv.x * 4.2);
		float p2 = cos(uv.y * 13.8 - uv.x * 7.5);
		float p3 = sin(uv.y * 28.0 + uv.x * 12.0) * 0.25;
		float puddle_island = smoothstep(0.35, 0.78, (p1 + p2 + p3) * 0.45);

		// Wet wheel path tracks (subtle glossy sheen)
		float wet_track_l = smoothstep(0.12, 0.0, abs(uv.x - 0.300)) * 0.55;
		float wet_track_r = smoothstep(0.12, 0.0, abs(uv.x - 0.700)) * 0.55;
		float wet_sheen = clamp(puddle_island * 0.95 + wet_track_l + wet_track_r, 0.0, 1.0);

		// Darken asphalt base under wet water
		col = mix(col, vec3(0.04, 0.05, 0.07), wet_sheen * 0.65);

		// Left lane magenta neon reflections (#FF1473) strictly on puddles and wet sheen
		float mag_falloff = smoothstep(0.60, 0.05, uv.x);
		vec3 mag_neon = vec3(1.0, 0.08, 0.45);
		vec3 mag_reflect = mag_neon * mag_falloff * wet_sheen * 0.90;

		// Right lane cyan neon reflections (#00E5FF) strictly on puddles and wet sheen
		float cyn_falloff = smoothstep(0.40, 0.95, uv.x);
		vec3 cyn_neon = vec3(0.0, 0.88, 1.0);
		vec3 cyn_reflect = cyn_neon * cyn_falloff * wet_sheen * 0.90;

		col += mag_reflect + cyn_reflect;
	}

	// =========================================================================
	// BIOME 3: HAKONE SNOW — ALPINE TOUGE TIRE RUTS & SNOWBANKS (Ref Image 3)
	// =========================================================================
	if (biome_mode == 3) {
		vec3 snow_tarmac = vec3(0.14, 0.16, 0.20);

		// Realistic carved dark rubber tire ruts (Ref Image 3: distinct tire paths)
		float rut_l1 = smoothstep(0.038, 0.0, abs(uv.x - 0.290));
		float rut_l2 = smoothstep(0.038, 0.0, abs(uv.x - 0.390));
		float rut_r1 = smoothstep(0.038, 0.0, abs(uv.x - 0.610));
		float rut_r2 = smoothstep(0.038, 0.0, abs(uv.x - 0.710));
		float tire_tracks = max(max(rut_l1, rut_l2), max(rut_r1, rut_r2));

		// Tread modulation inside tire tracks
		float tread = step(0.45, fract(uv.y * 36.0));
		vec3 rut_col = mix(snow_tarmac, vec3(0.05, 0.06, 0.08), tire_tracks * (0.65 + 0.25 * tread));

		// Compressed slush ridges between tire ruts
		float slush_center = smoothstep(0.050, 0.0, abs(uv.x - 0.500)) * 0.70;
		float slush_l = smoothstep(0.040, 0.0, abs(uv.x - 0.210)) * 0.75;
		float slush_r = smoothstep(0.040, 0.0, abs(uv.x - 0.790)) * 0.75;
		vec3 snow_col = vec3(0.96, 0.98, 1.0);
		rut_col = mix(rut_col, snow_col, clamp(slush_center + slush_l + slush_r, 0.0, 0.75));

		// Fluffy snowbanks encroaching from outer edges with irregular contour
		float edge_noise = sin(uv.y * 20.0) * 0.035 + cos(uv.y * 60.0) * 0.018;
		float snow_bank_l = smoothstep(0.18, 0.02, uv.x + edge_noise);
		float snow_bank_r = smoothstep(0.82, 0.98, uv.x - edge_noise);
		float bank_mask = clamp(snow_bank_l + snow_bank_r, 0.0, 1.0);

		// Black manga ink border along snowbank jagged edge
		float ink_border = step(0.92, bank_mask) * (1.0 - step(0.98, bank_mask));

		col = mix(rut_col, snow_col, bank_mask);
		col = mix(col, ink_black.rgb, ink_border * 0.70);
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
				col = ink_black.rgb; // Black ink border
			} else {
				col = line_white.rgb;
			}
		} else {
			float dash = mod(uv.y * 0.80, 1.0);
			if (dash < 0.54) {
				float d1 = abs(uv.x - 0.280);
				float d2 = abs(uv.x - 0.500);
				float d3 = abs(uv.x - 0.720);
				float min_d = min(min(d1, d2), d3);
				if (min_d < 0.0075) {
					col = line_yellow.rgb * mix(0.93, 1.05, grain);
				} else if (min_d < 0.0095) {
					col = ink_black.rgb;
				}
			}
		}
	}
	// MODE 1: NEO-SHINJUKU ALLEY (Clean white lines with black ink border, Ref Image 2)
	else if (biome_mode == 1) {
		// Solid white edge lines with ink border
		if ((uv.x >= 0.035 && uv.x <= 0.055) || (uv.x >= 0.945 && uv.x <= 0.965)) {
			float d_edge = min(abs(uv.x - 0.035), abs(uv.x - 0.055));
			if (uv.x > 0.5) d_edge = min(abs(uv.x - 0.945), abs(uv.x - 0.965));
			col = (d_edge < 0.0022) ? ink_black.rgb : line_white.rgb;
		}
		// Single white dashed center line dividing 2 lanes
		else {
			float dash = mod(uv.y * 0.70, 1.0);
			if (dash < 0.52) {
				float d_ctr = abs(uv.x - 0.500);
				if (d_ctr < 0.0085) {
					col = line_white.rgb;
				} else if (d_ctr < 0.0108) {
					col = ink_black.rgb;
				}
			}
		}
	}
	// MODE 2: ENOSHIMA COAST (Golden-yellow dashed center line, solid white edge lines, Ref Image 1)
	else if (biome_mode == 2) {
		if ((uv.x >= 0.035 && uv.x <= 0.055) || (uv.x >= 0.945 && uv.x <= 0.965)) {
			float d_edge = min(abs(uv.x - 0.035), abs(uv.x - 0.055));
			if (uv.x > 0.5) d_edge = min(abs(uv.x - 0.945), abs(uv.x - 0.965));
			col = (d_edge < 0.0022) ? ink_black.rgb : line_white.rgb;
		} else {
			float dash = mod(uv.y * 0.70, 1.0);
			if (dash < 0.52) {
				float d_ctr = abs(uv.x - 0.500);
				if (d_ctr < 0.0085) {
					col = line_yellow.rgb;
				} else if (d_ctr < 0.0108) {
					col = ink_black.rgb;
				}
			}
		}
	}
	// MODE 3: HAKONE SNOW (Single white dashed center line through tire ruts, Ref Image 3)
	else if (biome_mode == 3) {
		float dash = mod(uv.y * 0.65, 1.0);
		if (dash < 0.50) {
			float d_ctr = abs(uv.x - 0.500);
			if (d_ctr < 0.0080) {
				col = line_white.rgb;
			} else if (d_ctr < 0.0102) {
				col = ink_black.rgb;
			}
		}
	}

	ALBEDO = col;
}
