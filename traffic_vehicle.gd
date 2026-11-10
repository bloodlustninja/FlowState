# ==============================================================================
# MASTER SPEC: FlowState - Traffic Vehicle Asset Rig
# Engine: Godot 4 (GDScript)
# Loads real traffic 3D models (Sedan, SUV, Heavy Truck, Police Interceptor, Muscle),
# applies the Moebius / Comic shader pipeline, and sizes solid AABB + <0.4m graze box.
# ==============================================================================
class_name AGTrafficVehicle
extends AnimatableBody3D

signal player_crashed(obstacle: AGTrafficVehicle)
signal near_miss_occurred(obstacle: AGTrafficVehicle, lateral_dir: float)

# Preload Comic Shaders
const TOON_SHADER: Shader = preload("res://comic_toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://inverted_hull_outline.gdshader")

# Palette Constants
const COLOR_SHADOW: Color = Color(0.169, 0.118, 0.227)        # #2B1E3A Deep Violet
const GRAZE_CLEARANCE: float = 0.40                           # Spec: <0.4m proximity grazing

# Vehicle Profile Definitions
const VEHICLE_PROFILES: Dictionary = {
	"sedan": {
		"asset": "res://assets/vehicles/traffic/sedan_civilian",
		"size": Vector3(1.8, 0.8, 3.4),
		"scale": Vector3(0.65, 0.65, 0.65),
		"speed": 22.0,
		"fallback_color": Color(0.15, 0.45, 0.65)
	},
	"suv": {
		"asset": "res://assets/vehicles/traffic/suv_civilian",
		"size": Vector3(2.0, 1.1, 3.8),
		"scale": Vector3(0.65, 0.65, 0.65),
		"speed": 20.0,
		"fallback_color": Color(0.25, 0.55, 0.35)
	},
	"truck": {
		"asset": "res://assets/vehicles/traffic/heavy_truck",
		"size": Vector3(2.4, 1.8, 6.2),                       # Large wall for drafting & pinch points
		"scale": Vector3(0.68, 0.68, 0.68),
		"speed": 17.0,
		"fallback_color": Color(0.85, 0.55, 0.20)
	},
	"police": {
		"asset": "res://assets/vehicles/traffic/police_interceptor",
		"size": Vector3(1.8, 0.85, 3.4),
		"scale": Vector3(0.65, 0.65, 0.65),
		"speed": 28.0,
		"fallback_color": Color(0.12, 0.14, 0.22)
	},
	"muscle": {
		"asset": "res://assets/vehicles/traffic/muscle",
		"size": Vector3(1.8, 0.8, 3.5),
		"scale": Vector3(0.65, 0.65, 0.65),
		"speed": 25.0,
		"fallback_color": Color(0.80, 0.22, 0.22)
	}
}

@export var vehicle_type: String = "sedan"
var speed: float = 22.0
var vehicle_size: Vector3 = Vector3(1.8, 0.8, 3.4)
var has_been_grazed: bool = false
var forward_vector: Vector3 = Vector3(0, 0, -1)

func _ready() -> void:
	_init_vehicle_profile()
	_load_traffic_model()
	_setup_collision_and_graze()

func _init_vehicle_profile() -> void:
	if not VEHICLE_PROFILES.has(vehicle_type):
		vehicle_type = "sedan"
		
	var profile: Dictionary = VEHICLE_PROFILES[vehicle_type]
	speed = profile["speed"]
	vehicle_size = profile["size"]

func _resolve_asset(base_path: String) -> PackedScene:
	var glb_path: String = base_path + ".glb"
	var fbx_path: String = base_path + ".fbx"
	
	if ResourceLoader.exists(glb_path):
		return load(glb_path) as PackedScene
	elif ResourceLoader.exists(fbx_path):
		return load(fbx_path) as PackedScene
	elif FileAccess.file_exists(glb_path):
		return load(glb_path) as PackedScene
	elif FileAccess.file_exists(fbx_path):
		return load(fbx_path) as PackedScene
	return null

func _load_traffic_model() -> void:
	var profile: Dictionary = VEHICLE_PROFILES[vehicle_type]
	var scene: PackedScene = _resolve_asset(profile["asset"])
	
	if scene:
		var instance: Node3D = scene.instantiate() as Node3D
		instance.scale = profile["scale"]
		add_child(instance)
		_apply_comic_materials_recursive(instance)
	else:
		_build_procedural_fallback(profile["fallback_color"])

func _setup_collision_and_graze() -> void:
	collision_layer = 2                                       # Traffic Obstacle Layer
	collision_mask = 1
	
	# 1. Solid AABB Collision Shape
	var solid_col := CollisionShape3D.new()
	var solid_box := BoxShape3D.new()
	solid_box.size = vehicle_size
	solid_col.shape = solid_box
	solid_col.position.y = vehicle_size.y * 0.5
	add_child(solid_col)
	
	# 2. Near-Miss Graze Zone (<0.4m clearance perimeter)
	var graze_area := Area3D.new()
	graze_area.name = "GrazeZone"
	graze_area.collision_layer = 4
	graze_area.collision_mask = 1
	
	var graze_col := CollisionShape3D.new()
	var graze_box := BoxShape3D.new()
	# Expand exactly by GRAZE_CLEARANCE (0.4m) along X and Z
	graze_box.size = vehicle_size + Vector3(GRAZE_CLEARANCE * 2.0, 0.4, GRAZE_CLEARANCE * 2.0)
	graze_col.shape = graze_box
	graze_col.position.y = vehicle_size.y * 0.5
	graze_area.add_child(graze_col)
	
	graze_area.body_entered.connect(_on_graze_body_entered)
	add_child(graze_area)

func _physics_process(delta: float) -> void:
	global_position += forward_vector * (speed * delta)

func _on_graze_body_entered(body: Node3D) -> void:
	if has_been_grazed:
		return
		
	if body is AGVehicle:
		var rel_pos: Vector3 = body.global_position - global_position
		var lateral_dir: float = sign(rel_pos.x)
		has_been_grazed = true
		near_miss_occurred.emit(self, lateral_dir)

func _apply_comic_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		var count: int = mesh_inst.get_surface_override_material_count()
		if count == 0 and mesh_inst.mesh:
			count = mesh_inst.mesh.get_surface_count()
			
		for i in range(max(1, count)):
			var orig_mat: Material = mesh_inst.get_surface_override_material(i)
			if not orig_mat and mesh_inst.mesh:
				orig_mat = mesh_inst.mesh.surface_get_material(i)
				
			var base_col: Color = VEHICLE_PROFILES[vehicle_type]["fallback_color"]
			if orig_mat is StandardMaterial3D:
				base_col = (orig_mat as StandardMaterial3D).albedo_color
			elif orig_mat is ORMMaterial3D:
				base_col = (orig_mat as ORMMaterial3D).albedo_color
				
			var comic_mat: ShaderMaterial = _create_comic_mat(base_col)
			mesh_inst.set_surface_override_material(i, comic_mat)
			
	for child in node.get_children():
		_apply_comic_materials_recursive(child)

func _create_comic_mat(base_col: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("base_color", base_col)
	mat.set_shader_parameter("shadow_color", COLOR_SHADOW)
	mat.set_shader_parameter("hatch_density", 160.0)
	mat.set_shader_parameter("enable_crosshatch", true)
	mat.next_pass = null
	return mat

func _build_procedural_fallback(color: Color) -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = vehicle_size
	body.mesh = box
	body.material_override = _create_comic_mat(color)
	body.position.y = vehicle_size.y * 0.5
	add_child(body)
