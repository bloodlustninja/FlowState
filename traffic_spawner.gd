# ==============================================================================
# MASTER SPEC: FlowState - Choreographed Traffic Spawner
# Engine: Godot 4 (GDScript)
# Spawns real vehicle models: Sedans, SUVs, Heavy Trucks (drafting walls),
# Police Interceptors, and Muscle cars into Zipper and Funnel choreographies.
# ==============================================================================
class_name AGTrafficSpawner
extends Node3D

signal near_miss_triggered(lateral_dir: float)
signal player_collision_triggered()

@export var player_vehicle: AGVehicle
@export var spawn_distance_ahead: float = 95.0
@export var despawn_distance_behind: float = 45.0

# Road Lane Offsets
const LANE_LEFT_WIDE: float = -5.0
const LANE_LEFT: float = -2.5
const LANE_RIGHT: float = 2.5
const LANE_RIGHT_WIDE: float = 5.0

var _active_vehicles: Array[AGTrafficVehicle] = []
var _next_spawn_z: float = -40.0
var _current_pattern: int = 0
var _pattern_step: int = 0

const CIVILIAN_TYPES: Array[String] = ["sedan", "suv", "muscle"]

func _ready() -> void:
	for i in range(8):
		_spawn_next_choreography_step()

func _process(_delta: float) -> void:
	if not is_instance_valid(player_vehicle):
		return
		
	var player_z: float = player_vehicle.global_position.z
	
	while _next_spawn_z > (player_z - spawn_distance_ahead):
		_spawn_next_choreography_step()
		
	for i in range(_active_vehicles.size() - 1, -1, -1):
		var v: AGTrafficVehicle = _active_vehicles[i]
		if is_instance_valid(v):
			if v.global_position.z > (player_z + despawn_distance_behind):
				_active_vehicles.remove_at(i)
				v.queue_free()
		else:
			_active_vehicles.remove_at(i)

func _spawn_next_choreography_step() -> void:
	if _current_pattern == 0:
		_spawn_zipper_step()
	else:
		_spawn_funnel_step()
		
	_pattern_step += 1
	if _pattern_step >= 6:
		_pattern_step = 0
		_current_pattern = 1 - _current_pattern

func _spawn_zipper_step() -> void:
	var x_pos: float = LANE_LEFT if (_pattern_step % 2 == 0) else LANE_RIGHT
	# Alternate civilian cars with police interceptors
	var v_type: String = "police" if (_pattern_step == 3 or _pattern_step == 5) else CIVILIAN_TYPES.pick_random()
	_instantiate_traffic_vehicle(Vector3(x_pos, 0.0, _next_spawn_z), v_type)
	_next_spawn_z -= 28.0

func _spawn_funnel_step() -> void:
	match _pattern_step:
		0, 1:
			# Outer heavy truck walls (ideal for drafting / pinch-point walls)
			_instantiate_traffic_vehicle(Vector3(LANE_LEFT_WIDE, 0.0, _next_spawn_z), "truck")
			_instantiate_traffic_vehicle(Vector3(LANE_RIGHT_WIDE, 0.0, _next_spawn_z), "truck")
			_next_spawn_z -= 28.0
		2, 3:
			# Medium pinchers: civilian SUV and sedan
			_instantiate_traffic_vehicle(Vector3(LANE_LEFT, 0.0, _next_spawn_z), "suv")
			_instantiate_traffic_vehicle(Vector3(LANE_RIGHT, 0.0, _next_spawn_z), "sedan")
			_next_spawn_z -= 24.0
		4, 5:
			# Apex release slot with a police interceptor or civilian car
			var open_lane: float = LANE_RIGHT if randf() > 0.5 else LANE_LEFT
			var blocker_type: String = "police" if randf() > 0.5 else "muscle"
			_instantiate_traffic_vehicle(Vector3(-open_lane, 0.0, _next_spawn_z), blocker_type)
			_next_spawn_z -= 32.0

func _instantiate_traffic_vehicle(pos: Vector3, type_name: String) -> void:
	var traffic := AGTrafficVehicle.new()
	traffic.vehicle_type = type_name
	traffic.position = pos
	traffic.near_miss_occurred.connect(_on_vehicle_near_miss)
	add_child(traffic)
	_active_vehicles.append(traffic)

func _on_vehicle_near_miss(_v: AGTrafficVehicle, lateral_dir: float) -> void:
	near_miss_triggered.emit(lateral_dir)

func reset_all_traffic() -> void:
	for v in _active_vehicles:
		if is_instance_valid(v):
			v.queue_free()
	_active_vehicles.clear()
	
	if is_instance_valid(player_vehicle):
		_next_spawn_z = player_vehicle.global_position.z - 35.0
	else:
		_next_spawn_z = -40.0
		
	_current_pattern = 0
	_pattern_step = 0
	
	for i in range(6):
		_spawn_next_choreography_step()
