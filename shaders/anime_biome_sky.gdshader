shader_type sky;

// =============================================================================
// FLOWSTATE: MASTER ANIME BIOME SKY SHADER (EXACT CONCEPT ART COLOR MATCH)
// Biome 0: SHUTO DUSK (Classic Initial D sunset: Indigo -> Lavender -> Peach)
// Biome 1: NEO-SHINJUKU (Midnight Rain: Deep Indigo -> Plum -> Glowing Crimson Twilight)
// Biome 2: ENOSHIMA COAST (Golden Hour: Vibrant Coral/Rose -> Golden Peach -> Lemon Sun)
// Biome 3: HAKONE SNOW (Alpine Winter: Crisp Cold Azure -> Frosted Cyan -> White Icy Mist)
// =============================================================================

uniform int biome_mode : hint_range(0, 3) = 0;

// Shuto Dusk
uniform vec4 shuto_top : source_color = vec4(0.055, 0.157, 0.392, 1.0);     // #0E2864
uniform vec4 shuto_mid : source_color = vec4(0.478, 0.486, 0.659, 1.0);     // #7A7CA8
uniform vec4 shuto_hor : source_color = vec4(0.910, 0.510, 0.478, 1.0);     // #E8827A

// Neo-Shinjuku Alley (Ref Image 2: Deep Midnight Indigo -> Dark Plum -> Glowing Crimson Horizon)
uniform vec4 shinjuku_top : source_color = vec4(0.035, 0.025, 0.065, 1.0);  // #090610
uniform vec4 shinjuku_mid : source_color = vec4(0.125, 0.055, 0.160, 1.0);  // #200E29
uniform vec4 shinjuku_hor : source_color = vec4(0.550, 0.090, 0.180, 1.0);  // #8C172E (Glowing Crimson Twilight)

// Enoshima Coast (Ref Image 1: Deep Crimson Rose -> Vibrant Coral Salmon -> Radiant Golden Lemon)
uniform vec4 enoshima_top : source_color = vec4(0.560, 0.135, 0.285, 1.0);  // #8F2249 (Deep Anime Rose)
uniform vec4 enoshima_mid : source_color = vec4(0.940, 0.420, 0.300, 1.0);  // #F06B4D (Warm Coral Sunset)
uniform vec4 enoshima_hor : source_color = vec4(1.000, 0.820, 0.320, 1.0);  // #FFD152 (Radiant Golden Horizon)

// Hakone Snow (Ref Image 3: Cold Alpine Azure -> Frosted Cyan Mist -> Icy Pure Mountain Horizon)
uniform vec4 hakone_top : source_color = vec4(0.280, 0.460, 0.640, 1.0);    // #4775A3 (Cold Alpine Azure)
uniform vec4 hakone_mid : source_color = vec4(0.620, 0.790, 0.890, 1.0);    // #9EC9E3 (Frosted Cyan)
uniform vec4 hakone_hor : source_color = vec4(0.910, 0.960, 0.990, 1.0);    // #E8F5FC (Icy Mountain Mist)

void sky() {
	// EYEDIR.y ranges from -1.0 (looking down) to +1.0 (looking straight up).
	// Horizon is at EYEDIR.y == 0.0
	float elevation = EYEDIR.y;

	vec3 top_c;
	vec3 mid_c;
	vec3 hor_c;

	if (biome_mode == 1) {
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
