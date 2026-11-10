shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

// Single-frame amber warning strobe for construction barricades
uniform vec4 amber_active : source_color = vec4(1.0, 0.667, 0.0, 1.0);   // #FFAA00
uniform vec4 amber_idle : source_color = vec4(0.35, 0.18, 0.0, 1.0);      // Dark amber lens
uniform float flash_frequency : hint_range(1.0, 10.0) = 4.0;

void fragment() {
	// Single-frame punchy flash (15% duty cycle at 4 Hz)
	float flash_phase = fract(TIME * flash_frequency);
	bool is_flash = (flash_phase < 0.16);

	if (is_flash) {
		ALBEDO = amber_active.rgb;
		EMISSION = amber_active.rgb * 5.5;
	} else {
		ALBEDO = amber_idle.rgb;
		EMISSION = vec3(0.0);
	}
	ROUGHNESS = 0.35;
	SPECULAR = 0.60;
}
