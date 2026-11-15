shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Auto Modellista Cel-Shaded Vehicle Spoiler & Component Shader
// Dynamic variable pen-pressure inking + sun lighting + day/night tinting

uniform vec4 base_color : source_color = vec4(0.96, 0.97, 0.99, 1.0);  // Crisp pearl white #F5F7FA, dark charcoal/navy, or alloy silver
uniform vec4 ink_shadow : source_color = vec4(0.08, 0.08, 0.14, 1.0);  // Core shadow ink tone
uniform vec4 day_night_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);  // Ambient sky/sunset tint
uniform vec3 sun_direction = vec3(-0.5, -0.8, -0.3);
uniform float shadow_cut : hint_range(0.0, 1.0) = 0.38;
uniform float hatch_base_spacing : hint_range(1.0, 15.0) = 3.6;

void fragment() {
	vec3 light_dir_view = normalize((VIEW_MATRIX * vec4(-sun_direction, 0.0)).xyz);
	float NdotL = clamp(dot(NORMAL, light_dir_view), 0.0, 1.0);
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);

	// 1. Calculate how deep into shadow the surface sits (0.0 = lit, 1.0 = pitch dark)
	float shadow_depth = clamp((shadow_cut - NdotL) / shadow_cut, 0.0, 1.0);

	// 2. Glancing edge factor: fatten ink strokes on curves turning away from camera
	float rim_factor = pow(1.0 - NdotV, 2.0);

	// 3. Dynamic Pen Thickness: Hairline (0.04) near light border -> Heavy chisel stroke (0.42)
	float half_width = mix(0.04, 0.42, clamp(shadow_depth * 0.75 + rim_factor * 0.40, 0.0, 1.0));

	// 4. Centered Stripe Coordinate [-0.5, 0.5]
	float coord = fract((FRAGCOORD.x + FRAGCOORD.y) / hatch_base_spacing) - 0.5;
	float dist_from_center = abs(coord);

	// 5. Anti-aliased tapered ink stroke
	float stroke = 1.0 - smoothstep(half_width - 0.04, half_width + 0.04, dist_from_center);

	// 6. Surface Tint & Shading (Desaturate day_night_tint so it never dyes white base paint)
	vec3 neutral_tint = mix(vec3(1.0), day_night_tint.rgb, 0.15);
	vec3 lit_tinted = base_color.rgb * neutral_tint;
	vec3 final_color;

	if (NdotL > shadow_cut) {
		// Highlight/Lit: Clean paint with warm ambient/sun tint
		final_color = lit_tinted;
	} else if (shadow_depth > 0.82) {
		// Core shadow: Deep ink block
		final_color = ink_shadow.rgb;
	} else {
		// Transitional shadow zone: Variable pen-pressure comic hatching
		float ink_density = mix(0.55, 1.0, shadow_depth);
		final_color = mix(lit_tinted, ink_shadow.rgb, stroke * ink_density);
	}

	ALBEDO = final_color;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	// 1. Diffuse Cel-Shading Step
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float cel = step(0.12, NdotL);

	// 2. Cool-Slate Manga Shadow (#94A3B8 / vec3(0.580, 0.639, 0.722)) for shaded panels
	vec3 cool_slate_shadow = vec3(0.580, 0.639, 0.722);
	vec3 cel_tone = mix(cool_slate_shadow, vec3(1.0), cel);
	vec3 diffuse_cel = ALBEDO * cel_tone;

	// 3. Desaturate & clamp LIGHT_COLOR influence on main diffuse cel-shaded bands
	vec3 neutral_light = mix(vec3(1.0), clamp(LIGHT_COLOR, 0.0, 1.0), 0.20);

	// 4. Multiply diffuse cel-shading by neutral_light and clamp total brightness <= 1.05
	vec3 diffuse_result = clamp(diffuse_cel * neutral_light * ATTENUATION, vec3(0.0), vec3(1.05));

	// 5. Subtle Fresnel Edge Rim-Light with Biome Color Bounce
	// Bounces sunset gold, neon magenta/cyan, or icy blue off edges, spoiler, and roof contours
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5) * 0.35;
	vec3 rim_bounce = fresnel * clamp(LIGHT_COLOR, 0.0, 1.0) * ATTENUATION;

	DIFFUSE_LIGHT += diffuse_result + rim_bounce;
}
