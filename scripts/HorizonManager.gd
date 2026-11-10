class_name HorizonManager
extends Node3D

@export var player_camera: Camera3D
@export var mountain_distance: float = 480.0

var left_ridge: Node3D
var right_ridge: Node3D
var mountain_mat: StandardMaterial3D
var far_mountain_mat: StandardMaterial3D

func _ready() -> void:
	top_level = true
	_construct_horizon_mountains()

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
	mountain_mat.albedo_color = Color("#554D6E") # Deep grounded anime mountain slate
	mountain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mountain_mat.disable_fog = false

	far_mountain_mat = StandardMaterial3D.new()
	far_mountain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	far_mountain_mat.albedo_color = Color("#7A7CA8") # Distant soft mountain lavender
	far_mountain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	far_mountain_mat.disable_fog = false

	# Left Continuous Mountain Range (Flanking the highway on the mountain pass side)
	left_ridge = _build_continuous_mountain_range(true)
	add_child(left_ridge)

	# Right flank is pure unobstructed Tokyo bay metropolis skyline (no mountain behind city)

func set_horizon_palette(albedo: Color) -> void:
	if mountain_mat:
		mountain_mat.albedo_color = albedo.darkened(0.18)
	if far_mountain_mat:
		far_mountain_mat.albedo_color = albedo

func update_palette(night_factor: float) -> void:
	var sunset_col := Color("#7A7CA8")
	var night_col := Color("#2D3552")
	set_horizon_palette(sunset_col.lerp(night_col, clampf(night_factor, 0.0, 1.0)))

func _build_continuous_mountain_range(is_left: bool) -> Node3D:
	var root_node := Node3D.new()
	var sign_x: float = -1.0 if is_left else 1.0

	# 1. Near Mountain Ridge (Fully Grounded Foothills Y = -40m to +95m)
	var st_near := SurfaceTool.new()
	st_near.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Peak profile profile points (dx along flank, height, dz)
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

	var base_y: float = -45.0 # Extends well beneath road and hillside, 0% gaps
	for i in range(near_pts.size() - 1):
		var pA: Dictionary = near_pts[i]
		var pB: Dictionary = near_pts[i + 1]

		var bA := Vector3(sign_x * pA["x"], base_y, -mountain_distance + pA["z"])
		var bB := Vector3(sign_x * pB["x"], base_y, -mountain_distance + pB["z"])
		var tA := Vector3(sign_x * pA["x"], pA["h"], -mountain_distance + pA["z"])
		var tB := Vector3(sign_x * pB["x"], pB["h"], -mountain_distance + pB["z"])

		# Quad between peak A and peak B
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

	# 2. Far Majestic Mountain Crests (Layer 2, Y up to 185m)
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
