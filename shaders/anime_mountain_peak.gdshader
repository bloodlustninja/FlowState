shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded, fog_disabled;

// =============================================================================
// PRODUCTION-GRADE ANIME GRAND MOUNTAIN PEAK SHADER (SELF-CONTAINED CEL SHADING)
// Natural, dark, majestic Japanese Alpine Peak:
// 1. Cool mountain slate and dark granite mass (NO flat white/yellow blowout)
// 2. High shadow volume: mountain sits primarily in deep cool slate cel shadow
// 3. Crisp rock strata, crevice lines and faceted cleavage
// 4. Subtle, calm sunlit facets with strictly controlled luminance (<= 0.45)
// 5. Soft atmospheric mist at base, dark horn crest silhouetted against sky
// =============================================================================

uniform vec3 sun_direction = vec3(-0.5, -0.8, -0.3);
uniform vec4 sun_tint : source_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform vec4 horizon_fog_color : source_color = vec4(0.35, 0.38, 0.48, 1.0);

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_color;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_color = COLOR;
}

void fragment() {
	// Base rock: deep cool mountain slate
	vec3 base_col = mix(v_color.rgb * 0.65, vec3(0.18, 0.22, 0.28), 0.45);
	float depth = -VERTEX.z;

	// Rock Strata Striations & Cleavage Lines on Mountain Massif
	float rock_strata = fract(v_world_pos.y * 0.06 + sin(v_world_pos.x * 0.04) * 0.35);
	float crevice = step(0.90, rock_strata); // Dark crevice fracture line
	base_col = mix(base_col, vec3(0.06, 0.08, 0.12), crevice * 0.75);

	// Directional Anime Cel Shading (High threshold 0.45: mountain stays largely in shadow)
	vec3 light_dir = normalize(-sun_direction);
	float NdotL = dot(v_world_normal, light_dir);
	float is_lit = step(0.45, NdotL);

	// Lit Facet: Subtle weathered granite highlight (strictly capped, never glowing)
	vec3 lit_color = mix(base_col * 1.25, base_col * sun_tint.rgb * 1.10, 0.25);

	// Shadow Facet: Deep cool slate-indigo cel shadow
	vec3 shadow_color = mix(base_col * 0.45, vec3(0.10, 0.12, 0.18), 0.60);

	vec3 shaded_rock = mix(shadow_color, lit_color, is_lit);

	// Distant Atmospheric Aerial Perspective
	// Base has soft horizon mist, crest rises dark and sharp against the sky
	float dist_fog = clamp((depth - 350.0) / 950.0, 0.0, 0.35);
	float height_fade = clamp((v_world_pos.y + 20.0) / 360.0, 0.0, 1.0);
	float final_haze = dist_fog * (1.0 - height_fade * 0.80);

	vec3 mist_tone = mix(vec3(0.12, 0.15, 0.22), horizon_fog_color.rgb * 0.50, 0.30);
	vec3 final_col = mix(shaded_rock, mist_tone, final_haze);

	ALBEDO = clamp(final_col, vec3(0.0), vec3(0.45));
	ROUGHNESS = 0.98;
	METALLIC = 0.0;
}
