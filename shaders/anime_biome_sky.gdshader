shader_type sky;

// =============================================================================
// FLOWSTATE: MASTER ANIME BIOME SKY SHADER (CHRONOLOGICAL 24-HOUR TIME OF DAY)
// Biome 0: SHUTO DUSK (Sunset / 18:30: Crimson-Violet Twilight Sky)
// Biome 1: NEO-SHINJUKU (Midnight / 00:30: Deep Indigo -> Plum -> Glowing Crimson Twilight)
// Biome 2: ENOSHIMA COAST (Golden Afternoon / 16:30: Warm Coastal Rose -> Golden Amber #FDE68A -> #FB7185)
// Biome 3: HAKONE SNOW (Alpine Dawn / 06:30: Pale Morning Ice-Blue #BAE6FD -> Soft Rose-Gold Sunrise #FBCFE8)
// =============================================================================

uniform int biome_mode : hint_range(0, 3) = 0;
uniform bool use_blend = false;
uniform vec4 blend_top : source_color = vec4(0.055, 0.157, 0.392, 1.0);
uniform vec4 blend_mid : source_color = vec4(0.478, 0.486, 0.659, 1.0);
uniform vec4 blend_hor : source_color = vec4(0.910, 0.510, 0.478, 1.0);

// Shuto Dusk (Sunset / 18:30)
uniform vec4 shuto_top : source_color = vec4(0.055, 0.157, 0.392, 1.0);     // #0E2864
uniform vec4 shuto_mid : source_color = vec4(0.478, 0.486, 0.659, 1.0);     // #7A7CA8
uniform vec4 shuto_hor : source_color = vec4(0.910, 0.510, 0.478, 1.0);     // #E8827A

// Neo-Shinjuku Alley (Midnight / 00:30) (Deep Crimson-to-Violet Twilight Sky Gradient: #4A153B -> #131626)
uniform vec4 shinjuku_top : source_color = vec4(0.075, 0.086, 0.149, 1.0);  // #131626 (Deep Violet Night Zenith)
uniform vec4 shinjuku_mid : source_color = vec4(0.180, 0.071, 0.208, 1.0);  // #2E1235 (Deep Plum-Magenta)
uniform vec4 shinjuku_hor : source_color = vec4(0.290, 0.082, 0.231, 1.0);  // #4A153B (Glowing Crimson Twilight Dusk)

// Enoshima Coast (Golden Afternoon / 16:30: #FDE68A -> #FB7185)
uniform vec4 enoshima_top : source_color = vec4(0.984, 0.443, 0.522, 1.0);  // #FB7185 (Warm Coastal Rose)
uniform vec4 enoshima_mid : source_color = vec4(0.957, 0.447, 0.714, 1.0);  // #F472B6 (Sunset Coral Pink)
uniform vec4 enoshima_hor : source_color = vec4(0.992, 0.902, 0.541, 1.0);  // #FDE68A (Warm Golden-Amber Horizon)

// Hakone Snow (Crisp Alpine Dawn / 06:30: #BAE6FD -> #FBCFE8)
uniform vec4 hakone_top : source_color = vec4(0.729, 0.902, 0.992, 1.0);    // #BAE6FD (Pale Morning Ice-Blue)
uniform vec4 hakone_mid : source_color = vec4(0.878, 0.949, 0.996, 1.0);    // #E0F2FE (Soft Morning Frost Azure)
uniform vec4 hakone_hor : source_color = vec4(0.984, 0.812, 0.910, 1.0);    // #FBCFE8 (Soft Rose-Gold Sunrise Horizon)

void sky() {
	// EYEDIR.y ranges from -1.0 (looking down) to +1.0 (looking straight up).
	// Horizon is at EYEDIR.y == 0.0
	float elevation = EYEDIR.y;

	vec3 top_c;
	vec3 mid_c;
	vec3 hor_c;

	if (use_blend) {
		top_c = blend_top.rgb;
		mid_c = blend_mid.rgb;
		hor_c = blend_hor.rgb;
	} else if (biome_mode == 1) {
		top_c = shinjuku_top.rgb;
		mid_c = shinjuku_mid.rgb;
		hor_c = shinjuku_hor.rgb;
	} else if (biome_mode == 2) {
		top_c = enoshima_top.rgb;
		mid_c = enoshima_mid.rgb;
		hor_c = enoshima_hor.rgb;
	} else if (biome_mode == 3) {
		top_c = hakone_top.rgb;
		mid_c = hakone_mid.rgb;
		hor_c = hakone_hor.rgb;
	} else {
		top_c = shuto_top.rgb;
		mid_c = shuto_mid.rgb;
		hor_c = shuto_hor.rgb;
	}

	// Smooth 3-tier anime celestial gradient
	// Below horizon (elevation < 0.02): hold horizon color
	// Mid band: elevation 0.02 to 0.28
	// Zenith band: elevation 0.28 to 0.70
	vec3 sky_color;
	if (elevation < 0.02) {
		sky_color = hor_c;
	} else if (elevation < 0.26) {
		float t = smoothstep(0.02, 0.26, elevation);
		sky_color = mix(hor_c, mid_c, t);
	} else {
		float t = smoothstep(0.26, 0.72, elevation);
		sky_color = mix(mid_c, top_c, t);
	}

	// Subtle horizontal manga cloud bands for Enoshima sunset
	if (biome_mode == 2 && elevation > 0.08 && elevation < 0.38) {
		float cloud_stripe = sin(elevation * 55.0) * cos(EYEDIR.x * 4.0);
		if (cloud_stripe > 0.35) {
			vec3 cloud_col = vec3(0.92, 0.40, 0.34); // Warm sunset peach cloud #EB6657
			sky_color = mix(sky_color, cloud_col, (cloud_stripe - 0.35) * 0.75);
		}
	}

	COLOR = sky_color;
}
