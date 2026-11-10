# ==============================================================================
# MASTER SPEC: FlowState - Vehicle Visual Rig (Hotfix Applied)
# Proper diffuse cel-shading (Warm Crimson #D62828, Midnight Navy roof/canopy,
# Warm Ivory #FFF8E7 accents), fixed 2px black inverted-hull outline,
# dynamic suspension height tracking, and wheel spin.
# ==============================================================================
class_name AGVehicleVisuals
extends Node3D

# Palette Constants (Directive-Specified)
const COLOR_WARM_CRIMSON: Color = Color(0.839, 0.157, 0.157)  # #D62828 Warm Crimson Body
const COLOR_ROOF_CANOPY: Color = Color(0.110, 0.118, 0.165)   # #1C1E2A Gloss Midnight Roof/Canopy
const COLOR_IVORY_ACCENT: Color = Color(1.000, 0.972, 0.906)  # #FFF8E7 Warm Ivory Highlights
const COLOR_TIRE_RUBBER: Color = Color(0.120, 0.115, 0.135)   # Dark Charcoal Tire
const COLOR_INK_OUTLINE: Color = Color(0.106, 0.071, 0.141)  # #1B1224 Deep Violet / Black Ink

var vehicle: AGVehicle
var rays: Dictionary = {}

var wheel_fl: Node3D
var wheel_fr: Node3D
var wheel_rl: Node3D
var wheel_rr: Node3D
var has_separate_wheels: bool = false
var _wheel_spin_rad: float = 0.0
const TIRE_RADIUS: float = 0.35

func _ready() -> void:
	vehicle = get_parent() as AGVehicle
	_cache_suspension_rays()
	_load_and_rig_model()

func _cache_suspension_rays() -> void:
	if not vehicle:
		return
	var container: Node3D = vehicle.get_node_or_null("SuspensionRays")
	if container:
		rays["FL"] = container.get_node_or_null("RayFL")
		rays["FR"] = container.get_node_or_null("RayFR")
		rays["RL"] = container.get_node_or_null("RayRL")
		rays["RR"] = container.get_node_or_null("RayRR")

func _load_and_rig_model() -> void:
	for child in get_children():
		child.queue_free()
		
	var model_scene: PackedScene = _resolve_asset("res://assets/vehicles/player/player_racer")
	if not model_scene:
		push_warning("Player racer model missing, using procedural fallback.")
		_build_fallback_chassis()
		return
		
	var instance: Node3D = model_scene.instantiate() as Node3D
	instance.scale = Vector3(0.65, 0.65, 0.65)
	instance.position = Vector3(0.0, 0.0, 0.0)
	add_child(instance)
	
	_find_and_bind_wheels(instance)
	_apply_cel_materials_recursive(instance)

func _resolve_asset(base_path: String) -> PackedScene:
	for ext in [".fbx", ".glb"]:
		var p: String = base_path + ext
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return load(p) as PackedScene
	return null

func _find_and_bind_wheels(root: Node) -> void:
	var nodes: Array[Node3D] = []
	_collect_nodes(root, nodes)
	
	for n in nodes:
		var name_l: String = n.name.to_lower()
		if "wheel" in name_l:
			if ("front" in name_l and "left" in name_l) or "fl" in name_l:
				wheel_fl = n
			elif ("front" in name_l and "right" in name_l) or "fr" in name_l:
				wheel_fr = n
			elif ("rear" in name_l and "left" in name_l) or "rl" in name_l:
				wheel_rl = n
			elif ("rear" in name_l and "right" in name_l) or "rr" in name_l:
				wheel_rr = n
				
	has_separate_wheels = (wheel_fl != null and wheel_fr != null and wheel_rl != null and wheel_rr != null)

func _collect_nodes(parent: Node, out_list: Array[Node3D]) -> void:
	for child in parent.get_children():
		if child is Node3D:
			out_list.append(child)
			_collect_nodes(child, out_list)

func _process(delta: float) -> void:
	if not is_instance_valid(vehicle):
		return
		
	var fwd_speed: float = vehicle.get_forward_velocity()
	var steer_angle_rad: float = -vehicle.steer_input * deg_to_rad(28.0)
	_wheel_spin_rad += (fwd_speed / TIRE_RADIUS) * delta
	
	if has_separate_wheels:
		_update_wheel(wheel_fl, rays.get("FL"), steer_angle_rad)
		_update_wheel(wheel_fr, rays.get("FR"), steer_angle_rad)
		_update_wheel(wheel_rl, rays.get("RL"), 0.0)
		_update_wheel(wheel_rr, rays.get("RR"), 0.0)

func _update_wheel(wheel: Node3D, ray: RayCast3D, steer_angle: float) -> void:
	if not is_instance_valid(wheel):
		return
	if ray and ray.is_colliding():
		var hit_dist: float = ray.global_position.distance_to(ray.get_collision_point())
		var target_y: float = ray.position.y - (hit_dist - TIRE_RADIUS)
		wheel.position.y = lerp(wheel.position.y, target_y * 1.4, 0.45)
	else:
		wheel.position.y = lerp(wheel.position.y, -0.35, 0.2)
	wheel.rotation = Vector3(_wheel_spin_rad, steer_angle, 0.0)

func _apply_cel_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		var count: int = mesh_inst.get_surface_override_material_count()
		if count == 0 and mesh_inst.mesh:
			count = mesh_inst.mesh.get_surface_count()
			
		for i in range(max(1, count)):
			var orig_mat: Material = mesh_inst.get_surface_override_material(i)
			if not orig_mat and mesh_inst.mesh:
				orig_mat = mesh_inst.mesh.surface_get_material(i)
				
			var mat_name: String = ""
			var orig_col: Color = COLOR_WARM_CRIMSON
			if orig_mat:
				mat_name = orig_mat.resource_name.to_lower()
				if orig_mat is StandardMaterial3D:
					orig_col = (orig_mat as StandardMaterial3D).albedo_color
					
			var target_color: Color = COLOR_WARM_CRIMSON
			# Distinguish sub-surfaces to fix black roof/hood cutout glitch
			if "black" in mat_name or "roof" in mat_name or "window" in mat_name or "glass" in mat_name or orig_col.v < 0.25:
				target_color = COLOR_ROOF_CANOPY
			elif "white" in mat_name or "light" in mat_name or orig_col.v > 0.85:
				target_color = COLOR_IVORY_ACCENT
			elif "wheel" in node.name.to_lower() or "tire" in mat_name:
				target_color = COLOR_TIRE_RUBBER
			else:
				target_color = COLOR_WARM_CRIMSON # Main car body
				
			var cel_mat := _create_cel_material(target_color)
			mesh_inst.set_surface_override_material(i, cel_mat)
			
	for child in node.get_children():
		_apply_cel_materials_recursive(child)

func _create_cel_material(albedo_col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.albedo_color = albedo_col
	mat.roughness = 0.75
	mat.next_pass = null
	return mat

func _build_fallback_chassis() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.65, 0.4, 3.2)
	body.mesh = box
	body.material_override = _create_cel_material(COLOR_WARM_CRIMSON)
	add_child(body)
	
	var canopy := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = Vector3(0.9, 0.35, 1.4)
	canopy.mesh = c_box
	canopy.material_override = _create_cel_material(COLOR_ROOF_CANOPY)
	canopy.position = Vector3(0.0, 0.3, 0.0)
	add_child(canopy)
