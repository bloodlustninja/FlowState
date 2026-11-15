shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// FLOWSTATE: MANGA WET ASPHALT PUDDLE ROAD SHADER (NEO-SHINJUKU ALLEY)
// Matches Ref Image 2:
// 1. Dark wet asphalt (#141722) with subtle fine tarmac grain
// 2. Procedural noise puddle masks reflecting magenta (#FF2A55) & cyan (#00E5FF) neons
// 3. Crisp white center lane dashes and solid white shoulder lines
// =============================================================================

uniform vec4 tarmac_base : source_color = vec4(0.078, 0.090, 0.133, 1.0);     // #141722 Dark Wet Asphalt
uniform vec4 neon_magenta : source_color = vec4(1.0, 0.165, 0.333, 1.0);      // #FF2A55 Electric Magenta
uniform vec4 neon_cyan : source_color = vec4(0.0, 0.898, 1.0, 1.0);           // #00E5FF Electric Cyan
uniform vec4 line_white : source_color = vec4(0.96, 0.96, 0.98, 1.0);         // Crisp White
uniform vec4 ink_black : source_color = vec4(0.02, 0.02, 0.03, 1.0);          // Black Ink

float road_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 4375.85453);
}

void fragment() {
	vec2 uv = UV;
	float grain = road_hash(vec2(floor(uv.x * 240.0), floor(uv.y * 360.0)));
	vec3 col = tarmac_base.rgb * mix(0.95, 1.05, grain);

	// 1. Procedural Organic Puddle Masks (Ref Image 2)
	float p1 = sin(uv.y * 4.8 + uv.x * 3.5);
	float p2 = cos(uv.y * 9.5 - uv.x * 5.8);
	float puddle_mask = smoothstep(0.20, 0.72, (p1 + p2) * 0.5);

	// Wet tire tracks specular sheen along left and right wheel paths
	float track_l = smoothstep(0.18, 0.0, abs(uv.x - 0.28));
	float track_r = smoothstep(0.18, 0.0, abs(uv.x - 0.72));
	float wet_sheen = clamp(track_l + track_r + puddle_mask * 0.90, 0.0, 1.0);

	// Deepen base asphalt under wet puddles
	col *= mix(1.0, 0.60, wet_sheen);

	// 2. Multi-Tone Neon Reflections (Magenta on Left, Amber in Center, Cyan on Right)
	// Strictly restricted to driving corridor (uv.x >= 0.055 && uv.x <= 0.945)
	if (uv.x >= 0.055 && uv.x <= 0.945) {
		float mag_dist = smoothstep(0.55, 0.08, uv.x);
		float cyn_dist = smoothstep(0.45, 0.92, uv.x);
		float amb_dist = smoothstep(0.28, 0.50, uv.x) * (1.0 - smoothstep(0.50, 0.72, uv.x));

		vec3 mag_glow = neon_magenta.rgb * mag_dist * (0.22 + 0.78 * wet_sheen);
		vec3 cyn_glow = neon_cyan.rgb * cyn_dist * (0.22 + 0.78 * wet_sheen);
		vec3 amb_glow = vec3(1.0, 0.718, 0.012) * amb_dist * (0.18 + 0.65 * wet_sheen); // Warm Amber #FFB703

		col += (mag_glow + cyn_glow + amb_glow) * 0.90;
	}

	// 3. Crisp Inked Lane Markings & Concrete Sidewalk Shoulder
	// Outer shoulder/sidewalk band: dark slate-concrete (#242834) with crisp light-grey curb line (#64748B)
	if (uv.x < 0.035 || uv.x > 0.965) {
		float d_curb = min(abs(uv.x - 0.035), abs(uv.x - 0.965));
		if (d_curb < 0.0035) {
			col = ink_black.rgb; // Black ink divider line
		} else if (d_curb < 0.014) {
			col = vec3(0.392, 0.455, 0.545); // Crisp light-grey curb line #64748B
		} else {
			col = vec3(0.141, 0.157, 0.204); // Dark slate-concrete #242834
		}
	}
	// Solid white edge lines with black ink border
	else if ((uv.x >= 0.035 && uv.x <= 0.055) || (uv.x >= 0.945 && uv.x <= 0.965)) {
		float d_edge = min(abs(uv.x - 0.035), abs(uv.x - 0.055));
		if (uv.x > 0.5) d_edge = min(abs(uv.x - 0.945), abs(uv.x - 0.965));
		col = (d_edge < 0.0022) ? ink_black.rgb : line_white.rgb;
	}
	// Single white dashed center line
	else {
		float dash = mod(uv.y * 0.72, 1.0);
		if (dash < 0.52) {
			float d_ctr = abs(uv.x - 0.500);
			if (d_ctr < 0.0085) {
				col = line_white.rgb;
			} else if (d_ctr < 0.0108) {
				col = ink_black.rgb;
			}
		}
	}

	ALBEDO = col;
}
