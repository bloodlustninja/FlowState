class_name MaterialFailsafe
extends RefCounted

const TRAFFIC_PALETTE: Array[Color] = [
	Color("#E62429"), # Vibrant Anime Crimson Red
	Color("#0A66C2"), # Electric Sapphire Blue
	Color("#FFB703"), # Solar Ochre Gold
	Color("#10B981"), # Vibrant Mint Emerald
	Color("#FF5E00"), # Tangerine Orange
	Color("#8B5CF6"), # Anime Purple
	Color("#E91E63"), # Hot Magenta Pink
	Color("#00E5FF")  # Electric Cyan
]

static var multi_shader: Shader = preload("res://shaders/comic_car_multi.gdshader")

static func create_glass_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#0C0E14") # Deep comic tinted black
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func create_taillight_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#FF0828") # Pure saturated crimson
	mat.emission_enabled = true
	mat.emission = Color("#FF0828")
	mat.emission_energy_multiplier = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func create_tire_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#14161D") # Deep Charcoal
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func create_rim_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#DDE2EC") # Alloy silver
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func create_stripe_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#0047AB") # Cobalt blue racing stripe
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func create_body_material(paint: Color, sun_dir: Vector3 = Vector3(-0.5, -0.8, -0.3), has_stripes: bool = false, is_two_tone: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = multi_shader
	mat.set_shader_parameter("paper_white", Color("#EAE6DF"))
	mat.set_shader_parameter("slate_grey", Color("#6E7485"))
	mat.set_shader_parameter("stripe_blue", Color("#0057E0"))
	mat.set_shader_parameter("navy_diffuser", Color("#1F3861"))
	mat.set_shader_parameter("ink_black", Color("#0A0914"))
	mat.set_shader_parameter("ink_shadow", Color(0.05, 0.05, 0.09, 1.0))
	mat.set_shader_parameter("shadow_tint", Color("#1E202B"))
	mat.set_shader_parameter("paint_color", paint)
	mat.set_shader_parameter("sun_direction", sun_dir)
	mat.set_shader_parameter("shadow_cut", 0.38)
	mat.set_shader_parameter("hatch_base_spacing", 3.6)
	mat.set_shader_parameter("is_two_tone", is_two_tone)
	mat.set_shader_parameter("has_stripes", has_stripes)
	return mat

# Comprehensive non-destructive multi-surface applicator
static func apply_vehicle_materials(root: Node, model_type: String, paint_color: Color, sun_dir: Vector3 = Vector3(-0.5, -0.8, -0.3), is_player: bool = false, td: RefCounted = null) -> ShaderMaterial:
	var glass_mat := create_glass_material()
	var tail_mat := create_taillight_material()
	var tire_mat := create_tire_material()
	var rim_mat := create_rim_material()
	var _stripe_mat := create_stripe_material()
	var is_hero := is_player
	var body_mat := create_body_material(paint_color, sun_dir, is_hero, is_hero)

	if td != null and "taillight_mat" in td:
		td.taillight_mat = tail_mat

	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		# 1. REMOVE DESTRUCTIVE GLOBAL MATERIAL_OVERRIDE:
		# NEVER set mesh_inst.material_override on vehicle meshes! Set to null immediately!
		mi.material_override = null

		var cname := mi.name.to_lower()

		# Separate child meshes by name
		if "glass" in cname or "window" in cname or "windshield" in cname:
			if mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					mi.set_surface_override_material(s, glass_mat)
			continue

		if "light" in cname or "lamp" in cname or "tail" in cname or "hex" in cname:
			if mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					mi.set_surface_override_material(s, tail_mat)
			continue

		if "shadow" in cname or "streak" in cname or "flame" in cname or "tip" in cname or "trail" in cname:
			continue

		if "wheel" in cname:
			if mi.mesh:
				var sc := mi.mesh.get_surface_count()
				for s in range(sc):
					if s == 0:
						mi.set_surface_override_material(s, tire_mat)
					else:
						mi.set_surface_override_material(s, rim_mat)
			continue

		# Body mesh with multiple surface slots:
		if mi.mesh:
			var sc := mi.mesh.get_surface_count()
			for s in range(sc):
				if model_type == "muscle" or is_player:
					match s:
						2: mi.set_surface_override_material(s, glass_mat)
						6: mi.set_surface_override_material(s, tail_mat)
						4: mi.set_surface_override_material(s, body_mat)
						1, 5: mi.set_surface_override_material(s, tire_mat)
						_: mi.set_surface_override_material(s, body_mat)
				elif model_type in ["truck", "heavy_truck"]:
					match s:
						3: mi.set_surface_override_material(s, glass_mat)
						5: mi.set_surface_override_material(s, tail_mat)
						1: mi.set_surface_override_material(s, tire_mat)
						2: mi.set_surface_override_material(s, rim_mat)
						_: mi.set_surface_override_material(s, body_mat)
				elif model_type == "sedan":
					match s:
						2: mi.set_surface_override_material(s, glass_mat)
						4: mi.set_surface_override_material(s, tail_mat)
						1: mi.set_surface_override_material(s, rim_mat)
						5: mi.set_surface_override_material(s, tire_mat)
						_: mi.set_surface_override_material(s, body_mat)
				elif model_type == "suv":
					match s:
						3: mi.set_surface_override_material(s, glass_mat)
						5: mi.set_surface_override_material(s, tail_mat)
						1: mi.set_surface_override_material(s, tire_mat)
						2: mi.set_surface_override_material(s, rim_mat)
						_: mi.set_surface_override_material(s, body_mat)
				elif model_type in ["police", "police_interceptor"]:
					match s:
						2: mi.set_surface_override_material(s, glass_mat)
						4: mi.set_surface_override_material(s, tail_mat)
						0:
							var pol_black := create_body_material(Color("#111216"), sun_dir)
							mi.set_surface_override_material(s, pol_black)
						1:
							var pol_white := create_body_material(Color("#EAE6DF"), sun_dir)
							mi.set_surface_override_material(s, pol_white)
						5:
							if td != null and "strobe_mat_r" in td:
								td.strobe_mat_r = tail_mat
							mi.set_surface_override_material(s, tail_mat)
						6:
							var blue_strobe := StandardMaterial3D.new()
							blue_strobe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
							blue_strobe.albedo_color = Color("#0088FF")
							if td != null and "strobe_mat_b" in td:
								td.strobe_mat_b = blue_strobe
							mi.set_surface_override_material(s, blue_strobe)
						_: mi.set_surface_override_material(s, body_mat)
				elif model_type == "rival":
					match s:
						2: mi.set_surface_override_material(s, glass_mat)
						4, 5, 6: mi.set_surface_override_material(s, tail_mat)
						_:
							var riv_body := create_body_material(Color("#111216"), sun_dir)
							mi.set_surface_override_material(s, riv_body)
				else:
					match s:
						1: mi.set_surface_override_material(s, glass_mat)
						2: mi.set_surface_override_material(s, tail_mat)
						_: mi.set_surface_override_material(s, body_mat)
	return body_mat
