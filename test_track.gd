# ==============================================================================
# MASTER SPEC: FlowState - 3-Chunk Endless Ghat Highway Generator
# Maintains 3 seamless Bezier chunks [Previous, Current, Next] with procedural bends,
# inward banking, left terracotta cliffs, and right valley guardrails.
# ==============================================================================
class_name AGTestGround
extends Node3D

@export var player_vehicle: AGVehicle

# 3 Active Chunks = 300m total visible highway
var chunks: Array[AGRoadChunk] = []

# Valley Floor Plane
var valley_plane: MeshInstance3D

func _ready() -> void:
	_build_valley_floor()
	_initialize_3_chunks()

func _build_valley_floor() -> void:
	valley_plane = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(800.0, 800.0)
	valley_plane.mesh = plane
	
	var valley_mat := StandardMaterial3D.new()
	valley_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	valley_mat.albedo_color = Color(0.24, 0.18, 0.14) # Deep warm brown valley floor
	valley_plane.material_override = valley_mat
	valley_plane.position.y = -25.0                    # 25m below mountain highway
	add_child(valley_plane)

func _initialize_3_chunks() -> void:
	var start_pos := Vector3(0.0, 0.0, 20.0)
	var start_tan := Vector3(0.0, 0.0, -1.0)
	
	# Curve offsets for first 3 chunks (gentle start, then mountain bends)
	var curve_offsets: Array[float] = [0.0, -12.0, 14.0]
	
	for i in range(3):
		var chunk := AGRoadChunk.new()
		add_child(chunk)
		chunk.setup_curve(start_pos, start_tan, curve_offsets[i])
		start_pos = chunk.p3
		start_tan = chunk.exit_tangent
		chunks.append(chunk)

func _process(_delta: float) -> void:
	if not is_instance_valid(player_vehicle):
		return
		
	var player_z: float = player_vehicle.global_position.z
	
	# Follow player with valley floor
	if valley_plane:
		valley_plane.global_position.z = player_z - 100.0
		valley_plane.global_position.x = player_vehicle.global_position.x
	
	# If player passed the middle of chunk 1 (Current), recycle chunk 0 (Previous) to front
	var chunk_mid: float = (chunks[1].p0.z + chunks[1].p3.z) * 0.5
	if player_z < chunk_mid:
		_recycle_oldest_chunk_to_front()

func _recycle_oldest_chunk_to_front() -> void:
	var old_chunk: AGRoadChunk = chunks.pop_front()
	var last_chunk: AGRoadChunk = chunks[chunks.size() - 1]
	
	# Procedural curve offset for upcoming 100m bend: alternating chicanes (-15m to +15m)
	var delta_x: float = randf_range(-15.0, 15.0)
	# Alternate bias so track stays generally centered
	if last_chunk.p3.x > 15.0:
		delta_x = randf_range(-15.0, -5.0)
	elif last_chunk.p3.x < -15.0:
		delta_x = randf_range(5.0, 15.0)
		
	old_chunk.setup_curve(last_chunk.p3, last_chunk.exit_tangent, delta_x)
	chunks.append(old_chunk)

## Samples the road position, tangent, and banking at any world Z position
func get_road_sample_at_z(world_z: float) -> Dictionary:
	for chunk in chunks:
		var z_max: float = max(chunk.p0.z, chunk.p3.z) + 10.0
		var z_min: float = min(chunk.p0.z, chunk.p3.z) - 10.0
		if world_z <= z_max and world_z >= z_min:
			var t: float = clamp((chunk.p0.z - world_z) / AGRoadChunk.CHUNK_LENGTH, 0.0, 1.0)
			return chunk.sample_at_t(t)
			
	# Fallback if beyond current bounds: extrapolate from nearest chunk
	var nearest: AGRoadChunk = chunks[1] if chunks.size() > 1 else chunks[0]
	return nearest.sample_at_t(0.5)
