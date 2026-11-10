shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// =============================================================================
// PRODUCTION-GRADE ANIME NATURE 3D CEL SHADER (NATURAL DEEP VIRIDIAN FOREST)
// Grounded Japanese mountain cedar & pine forest matching anime reference:
// 1. Guaranteed viridian/cedar identity via calibrated shader palette
//    (immune to default white mesh vertex colors)
// 2. High contrast & rich shadows: 75% of canopy sits in deep forest shadow
// 3. Crisp cel cuts (NdotL > 0.45) with inter-lobe silhouette crevice inking
// 4. Distant trees recede into deep moody mountain indigo-slate (NEVER bleached sky fog)
// 5. Strictly controlled luminance (ALBEDO <= 0.35) preventing any bloom blowout
// =============================================================================

uniform vec3 sun_direction = vec3(-0.5, -0.8, -0.3);
uniform vec4 sun_tint : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform vec4 foliage_base_color : source_color = vec4(0.06, 0.14, 0.07, 1.0);   // Deep Japanese cedar viridian
uniform vec4 foliage_crown_color : source_color = vec4(0.10, 0.22, 0.12, 1.0);  // Natural sunlit canopy crest
uniform vec4 foliage_shadow_color : source_color = vec4(0.03, 0.07, 0.04, 1.0); // Deep forest shadow floor
uniform vec3 trunk_bark_color : source_color = vec3(0.12, 0.08, 0.05);          // Dark wooden trunk bark

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_color;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_color = COLOR;
}

void fragment() {
	// Detect if vertex is wooden trunk vs foliage leaves
	// Trunks have warm red/brown tones with red > green
	bool is_trunk = (v_color.r > v_color.g * 1.15 && v_color.r < 0.65);

	vec3 base_col;
	if (is_trunk) {
		base_col = trunk_bark_color;
	} else {
		// Guaranteed rich natural foliage palette (never white!)
		base_col = foliage_base_color.rgb;
	}

	float depth = -VERTEX.z;

	// Subtle fine leaf clump texture
	vec3 p = v_world_pos * 1.5;
	float clump_a = sin(p.x * 2.2 + sin(p.y * 2.8) * 1.1) * cos(p.z * 2.2 + sin(p.x * 2.2) * 1.1);
	float dapple = step(0.15, clump_a) * 0.08;
	base_col = mix(base_col * 0.92, base_col * 1.05, dapple);

	// Deep under-canopy contact ambient occlusion (dense shadowed branches)
	float under_ao = smoothstep(-0.20, 0.45, v_world_normal.y);
	base_col *= mix(0.40, 1.0, under_ao);

	// Directional Anime Cel Shading
	vec3 light_dir = normalize(-sun_direction);
	float NdotL = dot(v_world_normal, light_dir);

	// High threshold: majority of canopy volume sits in calm deep shadow
	float is_crown = step(0.65, NdotL) * step(0.40, v_world_normal.y);
	float is_lit = step(0.45, NdotL);

	// Natural, deep, muted sunlit cedar foliage (NO bright mint or chartreuse)
	vec3 crown_col = is_trunk ? (trunk_bark_color * 1.15) : mix(foliage_crown_color.rgb, foliage_crown_color.rgb * sun_tint.rgb, 0.25);
	vec3 mid_col = base_col * 0.92;

	// Deep forest cel shadow floor (rich, grounded, calm dark viridian)
	vec3 shadow_col = is_trunk ? (trunk_bark_color * 0.40) : foliage_shadow_color.rgb;

	vec3 lit_result = mix(mid_col, crown_col, is_crown);
	vec3 shaded = mix(shadow_col, lit_result, is_lit);

	// Inter-lobe contact silhouette crevice inking (sharp 3D definition between tree puffs)
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_pos);
	float edge_ink = smoothstep(0.10, 0.30, dot(v_world_normal, view_dir));
	shaded *= mix(0.50, 1.0, edge_ink);

	// Atmospheric Aerial Recession:
	// Distant trees recede into deep dark mountain indigo-slate (NEVER washed out into pale sky fog!)
	float dist_factor = clamp((depth - 70.0) / 600.0, 0.0, 0.35);
	vec3 mountain_slate_recession = vec3(0.03, 0.06, 0.09);
	shaded = mix(shaded, mountain_slate_recession, dist_factor);

	ALBEDO = clamp(shaded, vec3(0.0), vec3(0.35));
	ROUGHNESS = 0.98;
	METALLIC = 0.0;
}
