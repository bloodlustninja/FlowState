class_name HorizonManager
extends Node3D

@export var player_camera: Camera3D
@export var mountain_distance: float = 480.0

var left_ridge: Node3D
var right_ridge: Node3D
var enoshima_island: Node3D
var sun_disc: MeshInstance3D
var shinjuku_skyline: Node3D
var hakone_alpine_peaks: Node3D

var mountain_mat: StandardMaterial3D
var far_mountain_mat: StandardMaterial3D
var island_mat: StandardMaterial3D
var sun_disc_mat: ShaderMaterial
var shinjuku_mat: StandardMaterial3D
var alpine_snow_mat: StandardMaterial3D
var alpine_shadow_mat: StandardMaterial3D

func _ready() -> void:
	top_level = true
	_construct_horizon_mountains()
	_construct_coastal_horizon()
	_construct_shinjuku_horizon()
	_construct_hakone_horizon()

func _physics_process(_delta: float) -> void:
	if not player_camera:
		player_camera = get_viewport().get_camera_3d()
	if player_camera:
		global_position.x = player_camera.global_position.x
		global_position.z = player_camera.global_position.z
		global_position.y = 0.0

func _construct_horizon_mountains() -> void:
	mountain_mat = StandardMaterial3D.new()
	mountain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mountain_mat.albedo_color = Color("#3B4259") # Deep grounded anime mountain slate
	mountain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mountain_mat.disable_fog = false

	far_mountain_mat = StandardMaterial3D.new()
	far_mountain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	far_mountain_mat.albedo_color = Color("#7A7CA8") # Distant soft mountain lavender
	far_mountain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	far_mountain_mat.disable_fog = false

	# Left Continuous Mountain Range (Pass side)
	left_ridge = _build_continuous_mountain_range(true)
	add_child(left_ridge)

	# Right Continuous Mountain Range (Used for Hakone Snow and Alpine passes)
	right_ridge = _build_continuous_mountain_range(false)
	right_ridge.visible = false
	add_child(right_ridge)

func _construct_coastal_horizon() -> void:
	# 1. Enoshima Island Silhouette across Sagami Bay (Ref Image 1)
	island_mat = StandardMaterial3D.new()
	island_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	island_mat.albedo_color = Color("#BA4628") # Warm terracotta/rust silhouette (Ref Image 1)
	island_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	enoshima_island = Node3D.new()
	enoshima_island.name = "EnoshimaIsland"

	var isl_st := SurfaceTool.new()
	isl_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Volcanic plateau profile sitting directly across the setting sun disc (Ref Image 1)
	var isl_pts: Array = [
		Vector3(10.0, -22.0, -mountain_distance - 20.0),
		Vector3(18.0, 10.0,  -mountain_distance - 20.0),
		Vector3(28.0, 18.5,  -mountain_distance - 20.0),
		Vector3(45.0, 19.5,  -mountain_distance - 20.0),
		Vector3(62.0, 18.5,  -mountain_distance - 20.0),
		Vector3(72.0, 8.0,   -mountain_distance - 20.0),
		Vector3(86.0, -22.0, -mountain_distance - 20.0)
	]
	for idx in range(isl_pts.size() - 1):
		var pA: Vector3 = isl_pts[idx]
		var pB: Vector3 = isl_pts[idx + 1]
		var bA := Vector3(pA.x, -35.0, pA.z)
		var bB := Vector3(pB.x, -35.0, pB.z)
		isl_st.add_vertex(bA); isl_st.add_vertex(pA); isl_st.add_vertex(pB)
		isl_st.add_vertex(bA); isl_st.add_vertex(pB); isl_st.add_vertex(bB)

	# Enoshima Sea Candle Lighthouse Silhouette on peak (Ref Image 1)
	var lh_base := Vector3(45.0, 19.5, -mountain_distance - 20.0)
	isl_st.add_vertex(lh_base + Vector3(-2.4, 0.0, 0.0))
	isl_st.add_vertex(lh_base + Vector3(-1.4, 22.0, 0.0))
	isl_st.add_vertex(lh_base + Vector3(1.4, 22.0, 0.0))

	isl_st.add_vertex(lh_base + Vector3(-2.4, 0.0, 0.0))
	isl_st.add_vertex(lh_base + Vector3(1.4, 22.0, 0.0))
	isl_st.add_vertex(lh_base + Vector3(2.4, 0.0, 0.0))

	# Lantern observation deck
	isl_st.add_vertex(lh_base + Vector3(-4.0, 22.0, 0.0))
	isl_st.add_vertex(lh_base + Vector3(0.0, 28.0, 0.0))
	isl_st.add_vertex(lh_base + Vector3(4.0, 22.0, 0.0))

	var isl_mesh := isl_st.commit()
	var isl_inst := MeshInstance3D.new()
	isl_inst.mesh = isl_mesh
	isl_inst.material_override = island_mat
	isl_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	enoshima_island.add_child(isl_inst)

	# Atmospheric sunset cloud layers slicing horizontally across the base (Ref Image 1)
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.albedo_color = Color("#E06248")
	cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c_mesh := BoxMesh.new()
	c_mesh.size = Vector3(110.0, 5.2, 0.5)
	var c_inst := MeshInstance3D.new()
	c_inst.mesh = c_mesh
	c_inst.material_override = cloud_mat
	c_inst.position = Vector3(48.0, 7.0, -mountain_distance - 15.0)
	enoshima_island.add_child(c_inst)

	var c_mesh2 := BoxMesh.new()
	c_mesh2.size = Vector3(75.0, 3.6, 0.5)
	var c_inst2 := MeshInstance3D.new()
	c_inst2.mesh = c_mesh2
	c_inst2.material_override = cloud_mat
	c_inst2.position = Vector3(32.0, 14.5, -mountain_distance - 14.0)
	enoshima_island.add_child(c_inst2)

	enoshima_island.visible = false
	add_child(enoshima_island)

	# 2. Giant Radiant Setting Sun Disc (Ref Image 1 - Anime Sunset Masterpiece)
	var sun_sh: Shader = load("res://shaders/sun_disc.gdshader")
	sun_disc_mat = ShaderMaterial.new()
	sun_disc_mat.shader = sun_sh
	sun_disc_mat.set_shader_parameter("core_color", Color("#FFFFE8")) # Brilliant lemon core
	sun_disc_mat.set_shader_parameter("mid_color", Color("#FFD940"))  # Luminous golden sun
	sun_disc_mat.set_shader_parameter("rim_color", Color("#FFA228"))  # Sunset orange edge

	var disc_mesh := QuadMesh.new()
	disc_mesh.size = Vector2(340.0, 340.0)
	disc_mesh.orientation = PlaneMesh.FACE_Z

	sun_disc = MeshInstance3D.new()
	sun_disc.name = "HorizonSunDisc"
	sun_disc.mesh = disc_mesh
	sun_disc.material_override = sun_disc_mat
	sun_disc.position = Vector3(45.0, 36.0, -mountain_distance - 25.0)
	sun_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun_disc.visible = false
	add_child(sun_disc)

func _construct_shinjuku_horizon() -> void:
	shinjuku_mat = StandardMaterial3D.new()
	shinjuku_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shinjuku_mat.albedo_color = Color("#100C18") # Midnight Tokyo Silhouette
	shinjuku_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var win_glow_mat := StandardMaterial3D.new()
	win_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	win_glow_mat.albedo_color = Color("#FFB844") # Amber office light grid
	win_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var red_beacon_mat := StandardMaterial3D.new()
	red_beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red_beacon_mat.albedo_color = Color("#FF2233") # Aviation warning light

	shinjuku_skyline = Node3D.new()
	shinjuku_skyline.name = "ShinjukuSkyline"

	var sky_st := SurfaceTool.new()
	sky_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var win_st := SurfaceTool.new()
	win_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var bcn_st := SurfaceTool.new()
	bcn_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Clustered Shinjuku skyscrapers directly centered down the alley (Ref Image 2)
	var towers: Array = [
		{"x": -75.0, "w": 28.0, "h": 160.0},
		{"x": -45.0, "w": 26.0, "h": 235.0},
		{"x": -20.0, "w": 28.0, "h": 195.0},
		{"x": 0.0,   "w": 32.0, "h": 265.0}, # Central monolithic Tokyo Tower
		{"x": 24.0,  "w": 26.0, "h": 215.0},
		{"x": 52.0,  "w": 24.0, "h": 245.0},
		{"x": 80.0,  "w": 30.0, "h": 170.0}
	]
	for tw in towers:
		var x: float = tw["x"]
		var w: float = tw["w"]
		var h: float = tw["h"]
		var z: float = -mountain_distance + 40.0
		var p0 := Vector3(x - w * 0.5, -20.0, z)
		var p1 := Vector3(x + w * 0.5, -20.0, z)
		var p2 := Vector3(x + w * 0.5, h, z)
		var p3 := Vector3(x - w * 0.5, h, z)
		sky_st.add_vertex(p0); sky_st.add_vertex(p1); sky_st.add_vertex(p2)
		sky_st.add_vertex(p0); sky_st.add_vertex(p2); sky_st.add_vertex(p3)

		# Rooftop antennae / spires
		var sp0 := Vector3(x - 0.8, h, z)
		var sp1 := Vector3(x + 0.8, h, z)
		var sp2 := Vector3(x, h + 28.0, z)
		sky_st.add_vertex(sp0); sky_st.add_vertex(sp1); sky_st.add_vertex(sp2)

		# Red aviation beacon on spire tip
		var bc0 := Vector3(x - 1.2, h + 27.0, z - 0.2)
		var bc1 := Vector3(x + 1.2, h + 27.0, z - 0.2)
		var bc2 := Vector3(x, h + 29.5, z - 0.2)
		bcn_st.add_vertex(bc0); bcn_st.add_vertex(bc1); bcn_st.add_vertex(bc2)

		# Vertical grid columns of illuminated office windows
		var num_cols: int = int(w / 4.2)
		for c in range(num_cols):
			var cx: float = (x - w * 0.5) + float(c + 1) * (w / float(num_cols + 1))
			var col_y_start: float = 20.0 + fposmod(x * 13.0 + float(c) * 7.0, 40.0)
			var col_h: float = h - col_y_start - 15.0
			if col_h > 20.0:
				var wp0 := Vector3(cx - 0.65, col_y_start, z - 0.1)
				var wp1 := Vector3(cx + 0.65, col_y_start, z - 0.1)
				var wp2 := Vector3(cx + 0.65, col_y_start + col_h, z - 0.1)
				var wp3 := Vector3(cx - 0.65, col_y_start + col_h, z - 0.1)
				win_st.add_vertex(wp0); win_st.add_vertex(wp1); win_st.add_vertex(wp2)
				win_st.add_vertex(wp0); win_st.add_vertex(wp2); win_st.add_vertex(wp3)

	var s_mesh := sky_st.commit()
	var s_inst := MeshInstance3D.new()
	s_inst.mesh = s_mesh
	s_inst.material_override = shinjuku_mat
	s_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shinjuku_skyline.add_child(s_inst)

	var w_mesh := win_st.commit()
	var w_inst := MeshInstance3D.new()
	w_inst.mesh = w_mesh
	w_inst.material_override = win_glow_mat
	w_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shinjuku_skyline.add_child(w_inst)

	var b_mesh := bcn_st.commit()
	var b_inst := MeshInstance3D.new()
	b_inst.mesh = b_mesh
	b_inst.material_override = red_beacon_mat
	b_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shinjuku_skyline.add_child(b_inst)

	shinjuku_skyline.visible = false
	add_child(shinjuku_skyline)

func _construct_hakone_horizon() -> void:
	# Majestic Jagged Alpine Snow Peaks (Ref Image 3 - Northern Alps Winter Touge)
	alpine_snow_mat = StandardMaterial3D.new()
	alpine_snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	alpine_snow_mat.albedo_color = Color("#FAFDFF") # Pristine sunlit alpine snow #FAFDFF
	alpine_snow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	alpine_shadow_mat = StandardMaterial3D.new()
	alpine_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	alpine_shadow_mat.albedo_color = Color("#7696B8") # Cool alpine shadow rock slate #7696B8
	alpine_shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var alpine_mid_mat := StandardMaterial3D.new()
	alpine_mid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	alpine_mid_mat.albedo_color = Color("#9CB8D4") # Intermediate snow facet #9CB8D4
	alpine_mid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var forest_ridge_mat := StandardMaterial3D.new()
	forest_ridge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	forest_ridge_mat.albedo_color = Color("#1A3026") # Deep evergreen alpine foothills #1A3026
	forest_ridge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	hakone_alpine_peaks = Node3D.new()
	hakone_alpine_peaks.name = "HakoneAlpinePeaks"

	var snow_st := SurfaceTool.new()
	snow_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mid_st := SurfaceTool.new()
	mid_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var shd_st := SurfaceTool.new()
	shd_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var for_st := SurfaceTool.new()
	for_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var z_dist: float = -mountain_distance - 20.0
	var base_y: float = -30.0

	# 1. Main Central Alpine Peak (Ref Image 3: Towering apex rising behind the touge road)
	# Peak apex at (-18.0, 185.0)
	var p_apex := Vector3(-18.0, 185.0, z_dist)
	var p_ridge_r := Vector3(25.0, 135.0, z_dist + 5.0)
	var p_sub_apex_r := Vector3(55.0, 120.0, z_dist + 10.0)
	var p_ridge_l := Vector3(-65.0, 140.0, z_dist + 5.0)
	var p_shoulder_l := Vector3(-115.0, 110.0, z_dist + 10.0)
	var p_chute := Vector3(-12.0, 75.0, z_dist + 8.0)
	var p_base_mid := Vector3(-15.0, base_y, z_dist)
	var p_base_l := Vector3(-160.0, base_y, z_dist)
	var p_base_r := Vector3(130.0, base_y, z_dist)

	# Main Peak - Sunlit Right Facets (Crisp anime white snow)
	snow_st.add_vertex(p_apex); snow_st.add_vertex(p_chute); snow_st.add_vertex(p_ridge_r)
	snow_st.add_vertex(p_ridge_r); snow_st.add_vertex(p_chute); snow_st.add_vertex(p_sub_apex_r)
	snow_st.add_vertex(p_sub_apex_r); snow_st.add_vertex(p_chute); snow_st.add_vertex(p_base_r)

	# Main Peak - Intermediate Couloir Facet
	mid_st.add_vertex(p_chute); mid_st.add_vertex(p_base_mid); mid_st.add_vertex(p_base_r)

	# Main Peak - Shadowed Left Facets (Cool icy blue slate)
	shd_st.add_vertex(p_apex); shd_st.add_vertex(p_ridge_l); shd_st.add_vertex(p_chute)
	shd_st.add_vertex(p_ridge_l); shd_st.add_vertex(p_shoulder_l); shd_st.add_vertex(p_chute)
	shd_st.add_vertex(p_shoulder_l); shd_st.add_vertex(p_base_l); shd_st.add_vertex(p_chute)
	shd_st.add_vertex(p_chute); shd_st.add_vertex(p_base_l); shd_st.add_vertex(p_base_mid)

	# 2. Far Left Mountain Massif (Ref Image 3: Layered alpine ridges descending into valley)
	var z_far: float = z_dist - 35.0
	var l_apex := Vector3(-190.0, 160.0, z_far)
	var l_r := Vector3(-130.0, 115.0, z_far)
	var l_l := Vector3(-280.0, base_y, z_far)
	var l_mid := Vector3(-190.0, base_y, z_far)
	var l_bot_r := Vector3(-120.0, base_y, z_far)

	snow_st.add_vertex(l_apex); snow_st.add_vertex(l_mid); snow_st.add_vertex(l_r)
	snow_st.add_vertex(l_r); snow_st.add_vertex(l_mid); snow_st.add_vertex(l_bot_r)
	shd_st.add_vertex(l_apex); shd_st.add_vertex(l_l); shd_st.add_vertex(l_mid)

	# 3. Far Right Mountain Massif
	var r_apex := Vector3(150.0, 155.0, z_far)
	var r_l := Vector3(100.0, 110.0, z_far)
	var r_r := Vector3(260.0, base_y, z_far)
	var r_mid := Vector3(150.0, base_y, z_far)
	var r_bot_l := Vector3(90.0, base_y, z_far)

	snow_st.add_vertex(r_apex); snow_st.add_vertex(r_mid); snow_st.add_vertex(r_r)
	shd_st.add_vertex(r_apex); shd_st.add_vertex(r_l); shd_st.add_vertex(r_mid)
	shd_st.add_vertex(r_l); shd_st.add_vertex(r_bot_l); shd_st.add_vertex(r_mid)

	# 4. Dense Alpine Evergreen Foothills Band across base of mountains (Ref Image 3)
	var foot_pts: Array = [
		Vector3(-320.0, base_y, z_dist + 20.0),
		Vector3(-240.0, 42.0,   z_dist + 20.0),
		Vector3(-160.0, 35.0,   z_dist + 20.0),
		Vector3(-90.0,  55.0,   z_dist + 20.0),
		Vector3(-20.0,  48.0,   z_dist + 20.0),
		Vector3(45.0,   60.0,   z_dist + 20.0),
		Vector3(120.0,  45.0,   z_dist + 20.0),
		Vector3(200.0,  38.0,   z_dist + 20.0),
		Vector3(280.0,  base_y, z_dist + 20.0)
	]
	for idx in range(foot_pts.size() - 1):
		var pA: Vector3 = foot_pts[idx]
		var pB: Vector3 = foot_pts[idx + 1]
		var bA := Vector3(pA.x, base_y, pA.z)
		var bB := Vector3(pB.x, base_y, pB.z)
		for_st.add_vertex(bA); for_st.add_vertex(pA); for_st.add_vertex(pB)
		for_st.add_vertex(bA); for_st.add_vertex(pB); for_st.add_vertex(bB)

	var snow_m := snow_st.commit()
	var snow_i := MeshInstance3D.new()
	snow_i.mesh = snow_m
	snow_i.material_override = alpine_snow_mat
	snow_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hakone_alpine_peaks.add_child(snow_i)

	var mid_m := mid_st.commit()
	if is_instance_valid(mid_m) and mid_m.get_surface_count() > 0:
		var mid_i := MeshInstance3D.new()
		mid_i.mesh = mid_m
		mid_i.material_override = alpine_mid_mat
		mid_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hakone_alpine_peaks.add_child(mid_i)

	var shd_m := shd_st.commit()
	var shd_i := MeshInstance3D.new()
	shd_i.mesh = shd_m
	shd_i.material_override = alpine_shadow_mat
	shd_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hakone_alpine_peaks.add_child(shd_i)

	var for_m := for_st.commit()
	if is_instance_valid(for_m) and for_m.get_surface_count() > 0:
		var for_i := MeshInstance3D.new()
		for_i.mesh = for_m
		for_i.material_override = forest_ridge_mat
		for_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hakone_alpine_peaks.add_child(for_i)

	hakone_alpine_peaks.visible = false
	add_child(hakone_alpine_peaks)

func set_horizon_palette(albedo: Color) -> void:
	if mountain_mat:
		mountain_mat.albedo_color = albedo.darkened(0.18)
	if far_mountain_mat:
		far_mountain_mat.albedo_color = albedo

func update_palette(night_factor: float) -> void:
	var sunset_col := Color("#7A7CA8")
	var night_col := Color("#2D3552")
	set_horizon_palette(sunset_col.lerp(night_col, clampf(night_factor, 0.0, 1.0)))

func set_biome_style(biome_id: String) -> void:
	match biome_id:
		"shuto_dusk":
			if is_instance_valid(left_ridge): left_ridge.visible = true
			if is_instance_valid(right_ridge): right_ridge.visible = false
			if is_instance_valid(enoshima_island): enoshima_island.visible = false
			if is_instance_valid(sun_disc): sun_disc.visible = false
			if is_instance_valid(shinjuku_skyline): shinjuku_skyline.visible = false
			if is_instance_valid(hakone_alpine_peaks): hakone_alpine_peaks.visible = false
			if mountain_mat: mountain_mat.albedo_color = Color("#3B4259")
			if far_mountain_mat: far_mountain_mat.albedo_color = Color("#7A7CA8")

		"neo_shinjuku":
			# Midnight urban alley — show centered Shinjuku skyscrapers rising behind alley
			if is_instance_valid(left_ridge): left_ridge.visible = false
			if is_instance_valid(right_ridge): right_ridge.visible = false
			if is_instance_valid(enoshima_island): enoshima_island.visible = false
			if is_instance_valid(sun_disc): sun_disc.visible = false
			if is_instance_valid(shinjuku_skyline): shinjuku_skyline.visible = true
			if is_instance_valid(hakone_alpine_peaks): hakone_alpine_peaks.visible = false

		"enoshima_coast":
			# Open ocean horizon on right with island & giant setting sun; coastal cliffs on left
			if is_instance_valid(left_ridge): left_ridge.visible = false
			if is_instance_valid(right_ridge): right_ridge.visible = false
			if is_instance_valid(enoshima_island): enoshima_island.visible = true
			if is_instance_valid(sun_disc): sun_disc.visible = true
			if is_instance_valid(shinjuku_skyline): shinjuku_skyline.visible = false
			if is_instance_valid(hakone_alpine_peaks): hakone_alpine_peaks.visible = false

		"hakone_snow":
			# Distant snow-capped alpine peaks rising above touge pass
			if is_instance_valid(left_ridge): left_ridge.visible = false
			if is_instance_valid(right_ridge): right_ridge.visible = false
			if is_instance_valid(enoshima_island): enoshima_island.visible = false
			if is_instance_valid(sun_disc): sun_disc.visible = false
			if is_instance_valid(shinjuku_skyline): shinjuku_skyline.visible = false
			if is_instance_valid(hakone_alpine_peaks): hakone_alpine_peaks.visible = true

func _build_continuous_mountain_range(is_left: bool) -> Node3D:
	var root_node := Node3D.new()
	var sign_x: float = -1.0 if is_left else 1.0

	# Near Mountain Ridge
	var st_near := SurfaceTool.new()
	st_near.begin(Mesh.PRIMITIVE_TRIANGLES)

	var near_pts: Array = [
		{"x": 140.0, "h": 25.0,  "z": 40.0},
		{"x": 180.0, "h": 58.0,  "z": 10.0},
		{"x": 220.0, "h": 92.0,  "z": -20.0},
		{"x": 270.0, "h": 125.0, "z": -45.0},
		{"x": 320.0, "h": 85.0,  "z": -70.0},
		{"x": 370.0, "h": 110.0, "z": -100.0},
		{"x": 420.0, "h": 75.0,  "z": -130.0},
		{"x": 480.0, "h": 40.0,  "z": -160.0}
	]

	var base_y: float = -45.0
	for i in range(near_pts.size() - 1):
		var pA: Dictionary = near_pts[i]
		var pB: Dictionary = near_pts[i + 1]

		var bA := Vector3(sign_x * pA["x"], base_y, -mountain_distance + pA["z"])
		var bB := Vector3(sign_x * pB["x"], base_y, -mountain_distance + pB["z"])
		var tA := Vector3(sign_x * pA["x"], pA["h"], -mountain_distance + pA["z"])
		var tB := Vector3(sign_x * pB["x"], pB["h"], -mountain_distance + pB["z"])

		if is_left:
			st_near.add_vertex(bA); st_near.add_vertex(tA); st_near.add_vertex(tB)
			st_near.add_vertex(bA); st_near.add_vertex(tB); st_near.add_vertex(bB)
		else:
			st_near.add_vertex(bA); st_near.add_vertex(tB); st_near.add_vertex(tA)
			st_near.add_vertex(bA); st_near.add_vertex(bB); st_near.add_vertex(tB)

	var near_mesh := st_near.commit()
	var near_inst := MeshInstance3D.new()
	near_inst.mesh = near_mesh
	near_inst.material_override = mountain_mat
	near_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root_node.add_child(near_inst)

	# Far Mountain Ridge
	var st_far := SurfaceTool.new()
	st_far.begin(Mesh.PRIMITIVE_TRIANGLES)

	var far_pts: Array = [
		{"x": 160.0, "h": 45.0,  "z": -60.0},
		{"x": 210.0, "h": 115.0, "z": -80.0},
		{"x": 260.0, "h": 178.0, "z": -110.0},
		{"x": 310.0, "h": 140.0, "z": -140.0},
		{"x": 360.0, "h": 165.0, "z": -170.0},
		{"x": 430.0, "h": 130.0, "z": -210.0},
		{"x": 520.0, "h": 50.0,  "z": -250.0}
	]

	for i in range(far_pts.size() - 1):
		var pA: Dictionary = far_pts[i]
		var pB: Dictionary = far_pts[i + 1]

		var bA := Vector3(sign_x * pA["x"], base_y, -mountain_distance + pA["z"])
		var bB := Vector3(sign_x * pB["x"], base_y, -mountain_distance + pB["z"])
		var tA := Vector3(sign_x * pA["x"], pA["h"] * 1.15, -mountain_distance + pA["z"])
		var tB := Vector3(sign_x * pB["x"], pB["h"] * 1.15, -mountain_distance + pB["z"])

		if is_left:
			st_far.add_vertex(bA); st_far.add_vertex(tA); st_far.add_vertex(tB)
			st_far.add_vertex(bA); st_far.add_vertex(tB); st_far.add_vertex(bB)
		else:
			st_far.add_vertex(bA); st_far.add_vertex(tB); st_far.add_vertex(tA)
			st_far.add_vertex(bA); st_far.add_vertex(bB); st_far.add_vertex(tB)

	var far_mesh := st_far.commit()
	var far_inst := MeshInstance3D.new()
	far_inst.mesh = far_mesh
	far_inst.material_override = far_mountain_mat
	far_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root_node.add_child(far_inst)

	return root_node
