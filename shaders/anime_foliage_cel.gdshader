shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Auto Modellista & Anime Foliage Cel Shader with High-Resolution Texture Atlas
uniform sampler2D foliage_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = true;
uniform vec4 foliage_lit : source_color = vec4(1.10, 1.15, 1.05, 1.0);    // Vibrant anime sunlight boost
uniform vec4 foliage_shadow : source_color = vec4(0.48, 0.55, 0.60, 1.0); // Cool ambient shadow
uniform vec4 trunk_color : source_color = vec4(0.45, 0.30, 0.20, 1.0);    // Cedar wood trunk
uniform vec3 sun_direction = vec3(-0.5, -0.8, -0.3);
uniform float shadow_threshold : hint_range(-0.5, 0.5) = 0.05;

varying float is_trunk;

void vertex() {
	is_trunk = COLOR.r;
}

void fragment() {
	vec4 tex = vec4(1.0);
	if (use_texture) {
		tex = texture(foliage_texture, UV);
		if (tex.a < 0.35) {
			discard;
		}
	}

	vec3 light_dir_view = normalize((VIEW_MATRIX * vec4(-sun_direction, 0.0)).xyz);
	float NdotL = dot(NORMAL, light_dir_view);

	float light_step = smoothstep(shadow_threshold - 0.05, shadow_threshold + 0.05, NdotL);

	vec3 base_lit = tex.rgb * foliage_lit.rgb;
	vec3 base_shadow = tex.rgb * foliage_shadow.rgb;

	float NdotV = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - NdotV, 2.5) * light_step * 0.20;

	vec3 final_color = mix(base_shadow, base_lit, light_step) + (base_lit * rim);

	ALBEDO = final_color;
	ROUGHNESS = 0.90;
	METALLIC = 0.0;
	SPECULAR = 0.05;
}
