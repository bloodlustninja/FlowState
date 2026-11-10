shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded, fog_disabled;

// =============================================================================
// TOKYO SHUTO & KEIHIN INDUSTRIAL METROPOLIS VOLUMETRIC CEL SHADER
// Production-grade anime metropolitan aesthetic matching reference image:
// 1. Dark architectural steel, slate concrete & tinted glass silhouettes
// 2. Iconic Tokyo Tower with vibrant international orange & white lattice
// 3. Discrete window illumination: discrete warm amber pinpricks at sunset/night
// 4. Grounded harbor foundations with subtle low-lying dark coastal mist
// 5. Strictly controlled luminance (ALBEDO <= 0.45) eliminating any white blowout
// =============================================================================

uniform vec4 building_base_color : source_color = vec4(0.14, 0.17, 0.22, 1.0);
uniform vec4 window_lit_color : source_color = vec4(1.0, 0.78, 0.35, 1.0);
uniform vec4 window_cyan_color : source_color = vec4(0.25, 0.65, 0.85, 1.0);
uniform vec4 neon_magenta_color : source_color = vec4(0.85, 0.18, 0.45, 1.0);
uniform vec4 sodium_lamp_color : source_color = vec4(1.0, 0.60, 0.15, 1.0);
uniform vec4 hazard_red_color : source_color = vec4(0.92, 0.18, 0.12, 1.0);
uniform vec4 hazard_white_color : source_color = vec4(0.68, 0.72, 0.78, 1.0);
uniform vec4 horizon_haze_color : source_color = vec4(0.25, 0.28, 0.38, 1.0);
uniform vec3 sun_direction = vec3(-0.5, -0.8, -0.3);
uniform vec4 sun_tint : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float night_glow : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world_normal;
varying vec3 v_world_pos;
varying vec3 v_local_pos;
varying vec3 v_local_normal;
varying vec4 v_vertex_color;
varying vec2 v_uv;

void vertex() {
	v_world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_local_pos = VERTEX;
	v_local_normal = NORMAL;
	v_vertex_color = COLOR;
	v_uv = UV;
}

// Stable deterministic pseudo-random hash
float stable_hash(vec2 p) {
	vec2 i = floor(p);
	return fract(sin(dot(i, vec2(127.1, 311.7))) * 437.5854);
}

void fragment() {
	vec3 lp = v_local_pos;
	vec3 wn = normalize(v_world_normal);
	vec3 ln = normalize(v_local_normal);
	bool is_roof = (wn.y > 0.65 || ln.y > 0.65);

	// Style classification
	float col_r = v_vertex_color.r;
	int b_style = 0;
	float b_seed = v_vertex_color.g;
	if (col_r > 0.03 && col_r < 0.92) {
		b_style = int(round(col_r * 10.0));
	} else if (col_r >= 0.92) {
		b_seed = stable_hash(floor(lp.xz * 0.035));
		b_style = int(b_seed * 4.99);
	} else {
		b_style = 0;
	}
	b_style = clamp(b_style, 0, 8);

	if (b_seed <= 0.001) {
		b_seed = stable_hash(floor(lp.xz * 0.035));
	}

	float u_coord = v_uv.x;
	float v_coord = v_uv.y;
	if (length(v_uv) < 0.0001 && !is_roof) {
		u_coord = (abs(ln.x) > 0.5) ? lp.z : lp.x;
		v_coord = max(0.0, lp.y + 25.0);
	}

	// Deep architectural base color (dark silhouette foundation)
	vec3 facade_color = building_base_color.rgb;
	float win_glow = 0.0;
	vec3 glow_color = window_lit_color.rgb;

	if (!is_roof) {
		if (b_style == 0) {
			// STYLE 0: Ribbon Window Highrise (Dark charcoal spandrels & deep tinted glass)
			float floor_frac = fract(v_coord / 4.2);
			float is_strip = step(0.35, floor_frac) * step(floor_frac, 0.85);
			float mullion = step(0.12, fract(u_coord / 2.8));
			float col_seed = stable_hash(vec2(floor(u_coord / 2.8), floor(v_coord / 4.2)) + b_seed * 7.1);
			win_glow = is_strip * mullion * step(0.82, col_seed);
			glow_color = (col_seed > 0.92) ? window_cyan_color.rgb : window_lit_color.rgb;
			vec3 glass_col = vec3(0.08, 0.10, 0.15);
			vec3 spandrel_col = building_base_color.rgb * 0.90;
			facade_color = mix(spandrel_col, glass_col, is_strip * mullion);
		}
		else if (b_style == 1) {
			// STYLE 1: Vertical Pinstripe Skyscraper (Dark slate fins & dark glass)
			float col_frac = fract(u_coord / 2.4);
			float is_pane = step(0.25, col_frac) * step(col_frac, 0.75);
			float floor_div = step(0.12, fract(v_coord / 4.5));
			float cell_rnd = stable_hash(vec2(floor(u_coord / 2.4), floor(v_coord / 4.5)) + b_seed * 9.3);
			win_glow = is_pane * floor_div * step(0.84, cell_rnd);
			glow_color = (cell_rnd > 0.93) ? window_cyan_color.rgb : window_lit_color.rgb;
			vec3 glass_col = vec3(0.08, 0.10, 0.14);
			facade_color = mix(building_base_color.rgb * 0.92, glass_col, is_pane);
		}
		else if (b_style == 2) {
			// STYLE 2: Concrete Wharf Quays & Seawall Foundations (Solid weathered dark slate)
			facade_color = vec3(0.14, 0.16, 0.20);
			// Roll-up logistics doors at base
			float bay_frac = fract(u_coord / 20.0);
			if (bay_frac > 0.18 && bay_frac < 0.52 && v_coord < 5.5) {
				float door_slat = step(0.35, fract(v_coord * 2.0));
				facade_color = vec3(0.10, 0.11, 0.14) * (0.90 + 0.15 * door_slat);
			}
			// Muted warm sodium lamps along wharf
			float lamp_u = step(0.94, fract(u_coord / 18.0));
			float lamp_v = step(0.90, fract(v_coord / 8.0));
			win_glow = lamp_u * lamp_v;
			glow_color = sodium_lamp_color.rgb * 0.85;
		}
		else if (b_style == 3) {
			// STYLE 3: High-Density Punch Window Grid
			vec2 grid = fract(vec2(u_coord / 3.4, v_coord / 3.8));
			vec2 cell = floor(vec2(u_coord / 3.4, v_coord / 3.8));
			float is_win = step(0.28, grid.x) * step(grid.x, 0.72) * step(0.32, grid.y) * step(grid.y, 0.68);
			float w_rnd = stable_hash(cell + b_seed * 13.7);
			win_glow = is_win * step(0.84, w_rnd);
			glow_color = (w_rnd > 0.94) ? window_cyan_color.rgb : window_lit_color.rgb;
			vec3 glass_col = vec3(0.07, 0.09, 0.13);
			facade_color = mix(building_base_color.rgb, glass_col, is_win);
		}
		else if (b_style == 4) {
			// STYLE 4: Shuto Commercial Highrise & Subtle Neon
			float floor_frac = fract(v_coord / 4.0);
			float is_win = step(0.32, floor_frac) * step(floor_frac, 0.75);
			win_glow = is_win * step(0.82, stable_hash(vec2(floor(u_coord / 3.0), floor(v_coord / 4.0)) + b_seed * 5.5));
			glow_color = window_lit_color.rgb;
			facade_color = building_base_color.rgb * 0.90;

			// Discrete rooftop neon accent
			if (v_coord > 12.0 && v_coord < 22.0 && abs(u_coord - 12.0) < 8.0) {
				win_glow = 0.85;
				float neon_pulse = 0.92 + 0.08 * sin(TIME * 3.0 + b_seed * 6.28);
				vec3 n_color = (b_seed > 0.5) ? neon_magenta_color.rgb : window_cyan_color.rgb;
				glow_color = n_color * neon_pulse * 0.70;
			}
		}
		else if (b_style == 5) {
			// STYLE 5: Industrial Storage Tanks (Dark cylindrical steel)
			float ring = step(0.94, fract(v_coord / 5.0));
			facade_color = vec3(0.16, 0.18, 0.22) * (0.92 + 0.12 * ring);
		}
		else if (b_style == 6) {
			// STYLE 6: Cranes & Industrial Chimneys (Dark weathered steel & muted hazard markings)
			float band_idx = floor(v_coord / 6.0);
			facade_color = (mod(band_idx, 2.0) < 1.0) ? hazard_red_color.rgb * 0.75 : vec3(0.24, 0.26, 0.30);
			float curve_shade = 0.85 + 0.20 * cos(u_coord * 1.4);
			facade_color *= curve_shade;
		}
		else if (b_style == 7) {
			// STYLE 7: TOKYO TOWER (Iconic International Orange & White Lattice)
			float lattice = step(0.38, fract((u_coord + v_coord) * 0.4)) * step(0.38, fract((u_coord - v_coord) * 0.4));
			vec3 lattice_col = (v_coord > 95.0) ? hazard_white_color.rgb * 0.80 : hazard_red_color.rgb * 0.88;
			facade_color = mix(lattice_col * 0.75, lattice_col * 1.05, lattice);
		}
		else {
			// STYLE 8: Rainbow Bridge Towers & Cables (Weathered Dark Structural Steel)
			float diag1 = step(0.42, fract((u_coord + v_coord) * 0.25));
			float diag2 = step(0.42, fract((u_coord - v_coord) * 0.25));
			float truss = clamp(diag1 + diag2, 0.0, 1.0);
			vec3 steel_col = mix(vec3(0.16, 0.19, 0.24), vec3(0.22, 0.26, 0.32), truss);
			facade_color = steel_col;
			// Discrete sodium safety lights along bridge deck
			if (v_coord < 8.0) {
				float lamp_pearl = step(0.88, fract(u_coord / 8.0));
				win_glow = lamp_pearl * 0.80;
				glow_color = sodium_lamp_color.rgb * 0.85;
			}
		}
	} else {
		// Rooftop surface & Wharf concrete decks (Dark industrial charcoal)
		facade_color = building_base_color.rgb * 0.85;
	}

	// 3D Directional Facade Cel-Shading
	vec3 light_dir = normalize(-sun_direction);
	float NdotL = dot(wn, light_dir);
	float sun_facade = 0.80 + 0.25 * step(0.15, NdotL);

	float face_shade = 1.0;
	if (wn.y > 0.65) {
		face_shade = 1.05; // Top-lit rooftop
	} else if (wn.x < -0.30) {
		face_shade = 1.02; // Highway-facing face
	} else if (wn.z > 0.30) {
		face_shade = 0.95; // Forward facade
	} else {
		face_shade = 0.72; // Shadow side
	}

	// Base color: Grounded dark silhouette architecture
	vec3 base = facade_color * face_shade * sun_facade;

	// Window illumination: ONLY active at dusk and night
	// At noon: night_glow is 0, so windows remain completely unlit and dark!
	float dusk_night_ramp = pow(clamp(night_glow, 0.0, 1.0), 2.0);
	float lit_intensity = win_glow * dusk_night_ramp * 0.80;
	vec3 col = mix(base, glow_color, lit_intensity);

	// Red aircraft warning beacons on tall spires
	if ((b_style == 6 || b_style == 7 || is_roof) && v_coord > 28.0) {
		float beacon_pulse = step(0.5, fract(TIME * 1.5 + b_seed * 3.14));
		col = mix(col, vec3(0.85, 0.12, 0.12), beacon_pulse * (0.50 + 0.35 * night_glow));
	}

	// =========================================================================
	// GROUNDED COASTAL WATERLINE MIST
	// Softly grounds the seawalls & building foundations into Tokyo Bay (Y < 14m)
	// Keeps skyscrapers dark and sharp against the sky gradient (no washed-out haze!)
	// =========================================================================
	float ground_mist = (1.0 - smoothstep(-6.0, 18.0, lp.y)) * 0.30;
	vec3 harbor_water_tint = mix(vec3(0.06, 0.09, 0.14), sodium_lamp_color.rgb * 0.30, 0.10 * night_glow);
	col = mix(col, harbor_water_tint, ground_mist);

	ALBEDO = clamp(col, vec3(0.0), vec3(0.42));
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
}
