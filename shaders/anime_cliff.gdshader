shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// JAPANESE MOUNTAIN CLIFF & STEPPED TERRACE CEL SHADER (SELF-CONTAINED CEL SHADING)
// Matches Japanese Anime Reference:
// 1. Concrete Retaining Walls: Formwork seams, tie-rod anchors, drainage slits
// 2. Stepped Terraces: Deep agricultural grass rows, dark edge lip, dappled moss
// 3. Faceted Slate Cliffs: Angular rock strata, quartz bands, dark clefts
// 4. Harsh, high-contrast anime cel lighting: deep shadows provide true depth
// =============================================================================

uniform vec3 sun_direction = vec3(-0.5, -0.8, -0.3);
uniform vec4 sun_tint : source_color = vec4(1.0, 0.98, 0.90, 1.0);
uniform vec4 grass_top_color : source_color = vec4(0.14, 0.28, 0.12, 1.0);     // Natural Deep Anime Grass
uniform vec4 grass_dark_color : source_color = vec4(0.07, 0.16, 0.07, 1.0);    // Deep Shadow Grass
uniform vec4 stone_wall_color : source_color = vec4(0.38, 0.40, 0.44, 1.0);    // Civil Engineering Concrete
uniform vec4 stone_shadow_color : source_color = vec4(0.18, 0.20, 0.24, 1.0);  // Wall Shadow
uniform vec4 rock_sun_color : source_color = vec4(0.32, 0.34, 0.38, 1.0);      // Mountain Rock
uniform vec4 rock_shadow_color : source_color = vec4(0.15, 0.17, 0.22, 1.0);   // Cool Slate Shadow
uniform vec4 forest_ridge_color : source_color = vec4(0.10, 0.22, 0.11, 1.0);  // Deep Ridge Canopy
uniform vec4 horizon_fog_color : source_color = vec4(0.35, 0.38, 0.48, 1.0);

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec2 v_uv;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_uv = UV;
}

void fragment() {
	float h = v_uv.y;
	bool is_flat_top = (abs(v_world_normal.y) > 0.45);

	vec3 base_col;
	if (h < 0.65) {
		// Stepped Terraces (Retaining Walls vs Flat Grass Shelves)
		if (is_flat_top) {
			// Flat Terrace Shelf: Japanese agricultural grass ridges & dappled blades
			float ridge_stripes = abs(fract(v_world_pos.z * 0.45) - 0.5) * 2.0;
			float blade_noise = fract(sin(dot(floor(v_world_pos.xz * 3.2), vec2(12.9898, 78.233))) * 43758.5453);
			float grass_tex = ridge_stripes * 0.15 + (step(0.65, blade_noise) - 0.5) * 0.12;

			// Dark terrace edge lip: border where grass meets retaining wall has deep soil shadow
			float edge_dist = fract(h * 4.5);
			float edge_shadow = step(edge_dist, 0.12) * 0.35;

			vec3 g_col = mix(grass_top_color.rgb, grass_dark_color.rgb, clamp(grass_tex, 0.0, 1.0));
			base_col = g_col * (1.0 - edge_shadow);
		} else {
			// Vertical Retaining Wall Face: Japanese Civil Engineering Concrete Panels
			// 1. Concrete formwork vertical joints every 4.0 meters
			float seam_x = step(0.93, fract(v_uv.x * 16.0));
			// 2. Concrete formwork horizontal lift joints every 2.0 meters
			float seam_y = step(0.92, fract(v_world_pos.y * 0.5));
			// 3. Formwork tie-rod anchors (pairs of circular indents)
			vec2 tie_uv = fract(vec2(v_uv.x * 16.0, v_world_pos.y * 0.5));
			float dist_anchor1 = length(tie_uv - vec2(0.25, 0.5));
			float dist_anchor2 = length(tie_uv - vec2(0.75, 0.5));
			float tie_anchor = step(dist_anchor1, 0.055) + step(dist_anchor2, 0.055);

			// 4. Vertical weeping drainage slits
			float drain_x = step(0.96, fract(v_uv.x * 8.0 + 0.5));
			float drain_y = step(0.2, fract(v_world_pos.y * 0.5)) * step(fract(v_world_pos.y * 0.5), 0.7);
			float drain_slit = drain_x * drain_y;

			vec3 wall_col = stone_wall_color.rgb;
			// Dark joint lines
			wall_col = mix(wall_col, stone_shadow_color.rgb * 0.75, max(seam_x, seam_y) * 0.55);
			// Tie rod holes
			wall_col = mix(wall_col, vec3(0.10, 0.10, 0.12), tie_anchor * 0.75);
			// Dark damp stains below drainage slits
			wall_col = mix(wall_col, vec3(0.12, 0.14, 0.16), drain_slit * 0.65);

			base_col = wall_col;
		}
	} else if (h < 0.85) {
		// Faceted Slate Crags & Cleaved Mountain Rock
		float rock_strata = fract(v_world_pos.y * 0.12 + sin(v_world_pos.x * 0.08) * 0.4);
		float rock_tier = step(0.48, rock_strata);
		float crevice_line = step(0.92, rock_strata);
		float quartz_vein = step(0.88, fract(v_world_pos.y * 0.04 - v_world_pos.x * 0.06));

		vec3 rock_col = mix(rock_shadow_color.rgb, rock_sun_color.rgb, rock_tier);
		rock_col = mix(rock_col, vec3(0.08, 0.08, 0.12), crevice_line * 0.65);
		rock_col = mix(rock_col, vec3(0.55, 0.55, 0.58), quartz_vein * 0.25);
		base_col = is_flat_top ? mix(rock_col, grass_top_color.rgb, 0.40) : rock_col;
	} else {
		// Mountain Ridge & Canopy Crest: Deep dark forest ridge
		float crest_stipple = fract(sin(dot(floor(v_world_pos.xz * 2.5), vec2(12.9898, 78.233))) * 43758.5453);
		base_col = mix(forest_ridge_color.rgb * 0.85, forest_ridge_color.rgb * 1.08, step(0.5, crest_stipple));
	}

	// Directional Anime Cel Shading (High threshold 0.38 for harsh high-contrast shadow)
	vec3 light_dir = normalize(-sun_direction);
	float NdotL = dot(v_world_normal, light_dir);
	float is_lit = step(0.38, NdotL);

	// Diagonal cast shadow bands from upper retaining walls and trees onto terraces
	float cast_shadow_band = step(0.38, fract(v_world_pos.z * 0.08 - v_world_pos.x * 0.06));
	float lit_factor = is_lit * (is_flat_top ? cast_shadow_band : 1.0);

	vec3 lit_col = base_col * sun_tint.rgb * 0.98;
	vec3 shadow_col = base_col * 0.38;

	vec3 shaded = mix(shadow_col, lit_col, lit_factor);

	// Distant Atmospheric Aerial Perspective
	float depth = -VERTEX.z;
	float dist_factor = clamp((depth - 120.0) / 650.0, 0.0, 0.35);
	vec3 atmospheric_cool = mix(shadow_col * 1.1, vec3(0.08, 0.10, 0.14), 0.50);
	shaded = mix(shaded, atmospheric_cool, dist_factor);

	ALBEDO = clamp(shaded, vec3(0.0), vec3(0.42));
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
}
