shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// =============================================================================
// FLOWSTATE: MASTER MANGA ENVIRONMENT CEL SHADER (ALL PROPS & CLIFFS)
// Matches the visual craft of the player vehicle comic ink shaders:
// 1. 2-Step Cel-Shaded Lighting with sharp comic threshold
// 2. 45-Degree Screen-Space Manga Pen Crosshatching inside shadows
// 3. Geometric Crease & Silhouette Ink Outlining via Screen Derivatives
// 4. Per-Vertex Color Blending for single-draw-call prop batching
// =============================================================================

uniform bool use_vertex_color = true;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.796, 0.835, 0.882, 1.0);     // Crisp Manga Shadow #CBD5E1
uniform vec4 ink_color : source_color = vec4(0.031, 0.035, 0.051, 1.0);       // Bold Pen Ink #08090D
uniform vec3 sun_dir = vec3(0.55, 0.65, 0.45);                               // Direction to celestial light source
uniform float hatch_density : hint_range(50.0, 300.0) = 145.0;
uniform bool enable_hatching = false;
uniform float hatch_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool enable_crease_ink = true;
uniform vec4 rim_color : source_color = vec4(0.220, 0.255, 0.349, 0.0);       // Rim color & alpha strength (disabled by default)

varying vec3 v_world_pos;
varying vec3 v_normal;
varying vec4 v_color;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_color = COLOR;
}

void fragment() {
	// Reconstruct flat faceted face normal from screen derivatives for crisp comic edges
	vec3 dx = dFdx(v_world_pos);
	vec3 dy = dFdy(v_world_pos);
	vec3 face_n = normalize(cross(dx, dy));
	if (face_n.z < 0.0 && dot(face_n, v_normal) < 0.0) {
		face_n = -face_n;
	}

	// Blend geometric face normal with interpolated vertex normal
	vec3 norm = normalize(mix(v_normal, face_n, 0.55));

	// 1. Base Albedo determination (vertex color batching support)
	vec3 base_col = albedo_tint.rgb;
	if (use_vertex_color) {
		base_col *= v_color.rgb;
	}

	// 2. 2-Step Cel-Shaded Directional Lighting
	vec3 l_dir = normalize(sun_dir);
	float n_dot_l = dot(norm, l_dir);
	float cel_lit = step(0.08, n_dot_l);
	float cel_mid = step(-0.22, n_dot_l);

	// Calculate shadow color shifted towards cool ink shadow tint
	vec3 shadow_col = base_col * shadow_tint.rgb;
	// For bright snow surfaces (base luminance > 0.82), keep cel shadow clean & crisp
	if (dot(base_col, vec3(0.299, 0.587, 0.114)) > 0.82) {
		shadow_col = shadow_tint.rgb;
	}

	// 3. 45-Degree Screen-Space Manga Pen Hatching STRICTLY in Deep Shadow Crevices (NdotL < 0.25)
	float hatch_fade = 0.0;
	if (enable_hatching && hatch_strength > 0.001 && n_dot_l < 0.25 && cel_lit < 0.5) {
		float c45 = (FRAGCOORD.x + FRAGCOORD.y) * (hatch_density / 1080.0);
		float pen_stroke = step(0.48, fract(c45));
		// Subdued hatch opacity
		float crevice_depth = clamp((0.25 - n_dot_l) / 0.45, 0.0, 1.0);
		hatch_fade = pen_stroke * hatch_strength * crevice_depth;
	}

	// Composite cel-shaded color
	vec3 lit_col = base_col;
	vec3 mid_col = mix(shadow_col, base_col, 0.45);
	vec3 shaded = mix(shadow_col, mid_col, cel_mid);
	shaded = mix(shaded, lit_col, cel_lit);
	// Apply subtle crevice ink hatching without corduroy striping
	shaded = mix(shaded, ink_color.rgb, hatch_fade);

	// 4. Bold Crease Ink Lines on Facet Boundaries & Geometric Edges
	if (enable_crease_ink) {
		vec3 d_norm_x = dFdx(v_normal);
		vec3 d_norm_y = dFdy(v_normal);
		float crease = length(d_norm_x) + length(d_norm_y);
		if (crease > 0.45) {
			shaded = mix(shaded, ink_color.rgb, 0.88);
		}
	}

	// 5. Architectural Top-Edge Rim Highlights (#384159) for Silhouettes Against Night Sky
	if (rim_color.a > 0.001) {
		float top_rim = clamp(dot(norm, vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
		float view_rim = 1.0 - clamp(dot(VIEW, norm), 0.0, 1.0);
		float rim = pow(view_rim, 2.5) * (0.35 + 0.65 * top_rim);
		shaded = mix(shaded, rim_color.rgb, rim * rim_color.a);
	}

	// Clamp final RGB <= vec3(0.95) to prevent HDR blowout
	ALBEDO = min(shaded, vec3(0.95));
}
