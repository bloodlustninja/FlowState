# ==============================================================================
# MASTER SPEC: FlowState - Procedural Curved Road Chunk (Ghat Highway)
# 100m length, 12m width, Bezier curve with procedural bends (-15m to +15m),
# inward banking (up to 20°), left terracotta cliff, and right retaining wall.
# ==============================================================================
class_name AGRoadChunk
extends Node3D

const ROAD_WIDTH: float = 12.0
const CHUNK_LENGTH: float = 100.0
const NUM_SEGMENTS: int = 50                         # Every 2 meters (50 cross sections)

# Palette Constants
const COLOR_ASPHALT: Color = Color(0.863, 0.839, 0.804)      # #DCD6CD Sun-bleached asphalt
const COLOR_YELLOW_DASH: Color = Color(0.878, 0.663, 0.220)  # #E0A938 Yellow center dash
const COLOR_WHITE_STRIPE: Color = Color(0.98, 0.96, 0.92)    # #FFF8E7 Shoulder stripe
const COLOR_CLIFF: Color = Color(0.553, 0.357, 0.298)        # #8D5B4C Terracotta cliff
const COLOR_BARRIER: Color = Color(0.78, 0.76, 0.72)        # #C7C2B8 Concrete barrier
const COLOR_INK_LINE: Color = Color(0.106, 0.071, 0.141)    # #1B1224 Deep Violet ink

var p0: Vector3                                      # Start position
var p1: Vector3                                      # Control point 1
var p2: Vector3                                      # Control point 2
var p3: Vector3                                      # End position
var exit_tangent: Vector3

var _road_mesh_instance: MeshInstance3D
var _cliff_mesh_instance: MeshInstance3D
var _barrier_mesh_instance: MeshInstance3D
var _static_body: StaticBody3D
var _collision_shape: CollisionShape3D

static var road_mat: StandardMaterial3D
static var cliff_mat: StandardMaterial3D
static var barrier_mat: StandardMaterial3D

func _init() -> void:
	if not road_mat:
		_create_shared_materials()

static func _create_shared_materials() -> void:
	# 1. Procedural Asphalt Texture with yellow center dash and white edges
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_ASPHALT)
	for y in range(256):
		var is_dash: bool = (y % 64) < 36
		if is_dash:
			for x in range(124, 132):
				img.set_pixel(x, y, COLOR_YELLOW_DASH)
		for x in range(10, 14):
			img.set_pixel(x, y, COLOR_WHITE_STRIPE)
		for x in range(242, 246):
			img.set_pixel(x, y, COLOR_WHITE_STRIPE)
			
	var tex := ImageTexture.create_from_image(img)
	road_mat = StandardMaterial3D.new()
	road_mat.albedo_texture = tex
	road_mat.uv1_scale = Vector3(1.0, 12.0, 1.0)
	road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	road_mat.roughness = 0.95
	
	# 2. Cliff Terracotta Material
	cliff_mat = StandardMaterial3D.new()
	cliff_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	cliff_mat.albedo_color = COLOR_CLIFF
	cliff_mat.roughness = 0.9
	
	# 3. Barrier Material
	barrier_mat = StandardMaterial3D.new()
	barrier_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	barrier_mat.albedo_color = COLOR_BARRIER
	barrier_mat.roughness = 0.8

## Setup cubic Bezier curve parameters and build procedural mesh & collision
func setup_curve(start_pt: Vector3, start_tangent: Vector3, delta_x: float, delta_y: float = 0.0) -> void:
	p0 = start_pt
	var fwd: Vector3 = start_tangent.normalized()
	
	# Target end point 100m along general track direction
	p3 = p0 + (fwd * CHUNK_LENGTH * 0.4) + Vector3(delta_x, delta_y, -CHUNK_LENGTH)
	var end_dir: Vector3 = (p3 - p0).normalized()
	
	# Control handles
	p1 = p0 + (fwd * CHUNK_LENGTH * 0.35)
	p2 = p3 - (end_dir * CHUNK_LENGTH * 0.35)
	
	exit_tangent = _sample_tangent(1.0)
	_generate_geometry()

## Cubic Bezier Position
func _sample_pos(t: float) -> Vector3:
	var omt: float = 1.0 - t
	return (omt * omt * omt * p0) + (3.0 * omt * omt * t * p1) + (3.0 * omt * t * t * p2) + (t * t * t * p3)

## Cubic Bezier Tangent (1st derivative)
func _sample_tangent(t: float) -> Vector3:
	var omt: float = 1.0 - t
	var d: Vector3 = (3.0 * omt * omt * (p1 - p0)) + (6.0 * omt * t * (p2 - p1)) + (3.0 * t * t * (p3 - p2))
	return d.normalized()

## Samples position, tangent, right, and bank angle at normalized t [0.0, 1.0]
func sample_at_t(t: float) -> Dictionary:
	var pos: Vector3 = _sample_pos(t)
	var tan_vec: Vector3 = _sample_tangent(t)
	var up_ref := Vector3.UP
	var right_vec := (tan_vec.cross(up_ref)).normalized()
	
	# Curvature calculation: compare tangent at t vs t+0.05
	var tan_next: Vector3 = _sample_tangent(clamp(t + 0.04, 0.0, 1.0))
	var curv_x: float = (tan_next.x - tan_vec.x) * 25.0
	
	# Inward road banking: up to 18 degrees (0.31 rad) tilt into corner
	var bank_rad: float = clamp(-curv_x * 0.55, -deg_to_rad(18.0), deg_to_rad(18.0))
	var banked_right := (Basis(tan_vec, bank_rad) * right_vec).normalized()
	var banked_normal := (Basis(tan_vec, bank_rad) * up_ref).normalized()
	
	return {
		"position": pos,
		"tangent": tan_vec,
		"right": banked_right,
		"normal": banked_normal,
		"bank": bank_rad
	}

func _generate_geometry() -> void:
	# Clean existing nodes
	for child in get_children():
		child.queue_free()
		
	var road_st := SurfaceTool.new()
	road_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var cliff_st := SurfaceTool.new()
	cliff_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var barrier_st := SurfaceTool.new()
	barrier_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_w: float = ROAD_WIDTH * 0.5
	
	for i in range(NUM_SEGMENTS + 1):
		var t: float = float(i) / float(NUM_SEGMENTS)
		var s: Dictionary = sample_at_t(t)
		var center: Vector3 = s["position"]
		var right_vec: Vector3 = s["right"]
		var normal_vec: Vector3 = s["normal"]
		
		var p_left: Vector3 = center - (right_vec * half_w)
		var p_right: Vector3 = center + (right_vec * half_w)
		
		# --- 1. Road Surface (12m width) ---
		var v_uv: float = t * (CHUNK_LENGTH / 8.0)
		road_st.set_uv(Vector2(0.0, v_uv))
		road_st.set_normal(normal_vec)
		road_st.add_vertex(p_left)
		
		road_st.set_uv(Vector2(1.0, v_uv))
		road_st.set_normal(normal_vec)
		road_st.add_vertex(p_right)
		
		# --- 2. Left Terracotta Mountain Cliff (8m - 14m high) ---
		var cliff_h: float = 10.0 + sin(t * 12.0) * 3.5
		var p_cliff_top: Vector3 = p_left - (right_vec * 6.0) + Vector3(0.0, cliff_h, 0.0)
		cliff_st.set_uv(Vector2(0.0, t * 10.0))
		cliff_st.add_vertex(p_left)
		cliff_st.set_uv(Vector2(1.0, t * 10.0))
		cliff_st.add_vertex(p_cliff_top)
		
		# --- 3. Right Concrete Guardrail / Retaining Wall (1.2m high) ---
		var p_barrier_top: Vector3 = p_right + (normal_vec * 1.2)
		barrier_st.set_uv(Vector2(0.0, t * 20.0))
		barrier_st.add_vertex(p_right)
		barrier_st.set_uv(Vector2(1.0, t * 20.0))
		barrier_st.add_vertex(p_barrier_top)
		
	# Connect triangle indices
	for i in range(NUM_SEGMENTS):
		var idx: int = i * 2
		# Road triangles
		road_st.add_index(idx)
		road_st.add_index(idx + 1)
		road_st.add_index(idx + 2)
		road_st.add_index(idx + 1)
		road_st.add_index(idx + 3)
		road_st.add_index(idx + 2)
		
		# Cliff triangles
		cliff_st.add_index(idx)
		cliff_st.add_index(idx + 1)
		cliff_st.add_index(idx + 2)
		cliff_st.add_index(idx + 1)
		cliff_st.add_index(idx + 3)
		cliff_st.add_index(idx + 2)
		
		# Barrier triangles
		barrier_st.add_index(idx)
		barrier_st.add_index(idx + 1)
		barrier_st.add_index(idx + 2)
		barrier_st.add_index(idx + 1)
		barrier_st.add_index(idx + 3)
		barrier_st.add_index(idx + 2)
		
	# Commit road mesh & collision
	road_st.generate_normals()
	var road_mesh: ArrayMesh = road_st.commit()
	_road_mesh_instance = MeshInstance3D.new()
	_road_mesh_instance.mesh = road_mesh
	_road_mesh_instance.material_override = road_mat
	add_child(_road_mesh_instance)
	
	# Solid StaticBody3D collision shape for raycasts & tires
	_static_body = StaticBody3D.new()
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = road_mesh.create_trimesh_shape()
	_static_body.add_child(_collision_shape)
	add_child(_static_body)
	
	# Commit cliff mesh
	cliff_st.generate_normals()
	var cliff_mesh: ArrayMesh = cliff_st.commit()
	_cliff_mesh_instance = MeshInstance3D.new()
	_cliff_mesh_instance.mesh = cliff_mesh
	_cliff_mesh_instance.material_override = cliff_mat
	add_child(_cliff_mesh_instance)
	
	# Commit barrier mesh
	barrier_st.generate_normals()
	var barrier_mesh: ArrayMesh = barrier_st.commit()
	_barrier_mesh_instance = MeshInstance3D.new()
	_barrier_mesh_instance.mesh = barrier_mesh
	_barrier_mesh_instance.material_override = barrier_mat
	add_child(_barrier_mesh_instance)
