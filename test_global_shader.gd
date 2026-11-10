extends SceneTree

func _init():
	RenderingServer.global_shader_parameter_add("day_night_tint", RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(1, 1, 1, 1))
	RenderingServer.global_shader_parameter_set("day_night_tint", Color(0.5, 0.6, 0.8, 1))
	print("GLOBAL PARAMETER ADDED & SET SUCCESSFULLY!")
	var s = Shader.new()
	s.code = """
	shader_type spatial;
	global uniform vec4 day_night_tint;
	void fragment() {
		ALBEDO = day_night_tint.rgb;
	}
	"""
	print("SHADER CODE SET, MODE: ", s.get_mode())
	quit()
