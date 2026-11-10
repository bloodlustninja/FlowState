# ==============================================================================
# MASTER SPEC: FlowState - Dedicated Traffic Manager & 12-Vehicle Pool
# Pre-instantiates 12 real 3D traffic vehicles, tracks road curve & banking,
# and advances them along 3 distinct lanes (-3.5m, 0.0m, +3.5m).
# ==============================================================================
class_name AGTrafficManager
extends Node3D

signal near_miss_triggered(lateral_dir: float)
signal player_collision_triggered()

@export var player_vehicle: AGVehicle
@export var road_track: AGTestGround

const POOL_SIZE: int = 12
const LANE_OFFSETS: Array[float] = [-3.5, 0.0, 3.5]

const SPEED_TABLE: Dictionary = {
	"truck": 18.0,       # Heavy drafting wall
	"sedan": 25.0,       # Civilian cruising
	"suv": 22.0,         # Civilian SUV
	"muscle": 28.0,      # High-speed muscle
	"police": 32.0       # High-speed cruiser
}

const TRAFFIC_MODELS: Array[String] = [
	"truck", "sedan", "police", "suv", "muscle",
	"sedan", "truck", "police", "muscle", "sedan",
	"suv", "truck"
]

class PooledVehicle:
	var instance: AGTrafficVehicle
	var current_z: float = -60.0
	var lane_offset: float = 0.0
	var speed: float = 24.0

var _pool: Array[PooledVehicle] = []

func _ready() -> void:
	_initialize_pool()

func _initialize_pool() -> void:
	var base_z: float = -60.0
	
	for i in range(POOL_SIZE):
		var pv := PooledVehicle.new()
		var v_type: String = TRAFFIC_MODELS[i % TRAFFIC_MODELS.size()]
		
		var tv := AGTrafficVehicle.new()
		tv.vehicle_type = v_type
		tv.collision_layer = 2                        # Layer 2: Traffic
		tv.collision_mask = 1
		add_child(tv)
		
		tv.near_miss_occurred.connect(_on_near_miss)
		
		pv.instance = tv
		pv.speed = SPEED_TABLE.get(v_type, 24.0)
		pv.lane_offset = LANE_OFFSETS[i % LANE_OFFSETS.size()]
		pv.current_z = base_z - (float(i) * 16.0) # Stagger 16m apart
		
		_pool.append(pv)
		_snap_vehicle_to_road(pv)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_vehicle) or not is_instance_valid(road_track):
		return
		
	var player_z: float = player_vehicle.global_position.z
	
	for pv in _pool:
		# Advance forward along -Z at assigned vehicle speed
		pv.current_z -= pv.speed * delta
		
		# Recycle vehicle if it falls > 30m behind player
		if pv.current_z > player_z + 30.0:
			# Respawn 70m to 130m ahead of player
			pv.current_z = player_z - randf_range(70.0, 130.0)
			pv.lane_offset = LANE_OFFSETS.pick_random()
			pv.instance.reset_graze()
			
		_snap_vehicle_to_road(pv)

func _snap_vehicle_to_road(pv: PooledVehicle) -> void:
	if not road_track:
		return
		
	var sample: Dictionary = road_track.get_road_sample_at_z(pv.current_z)
	var center: Vector3 = sample["position"]
	var right_vec: Vector3 = sample["right"]
	var tan_vec: Vector3 = sample["tangent"]
	var normal_vec: Vector3 = sample["normal"]
	var bank_rad: float = sample["bank"]
	
	# Snap to lane offset along road lateral vector
	var target_pos: Vector3 = center + (right_vec * pv.lane_offset) + (normal_vec * 0.35)
	pv.instance.global_position = target_pos
	
	# Orient along road tangent and bank with surface
	var yaw_basis := Basis(Vector3.UP, atan2(-tan_vec.x, -tan_vec.z))
	var bank_basis := Basis(Vector3.FORWARD, bank_rad)
	pv.instance.global_transform.basis = (yaw_basis * bank_basis).orthonormalized()

func _on_near_miss(_v: AGTrafficVehicle, lateral_dir: float) -> void:
	near_miss_triggered.emit(lateral_dir)

func reset_all_traffic() -> void:
	var base_z: float = -60.0
	if is_instance_valid(player_vehicle):
		base_z = player_vehicle.global_position.z - 50.0
		
	for i in range(_pool.size()):
		var pv: PooledVehicle = _pool[i]
		pv.current_z = base_z - (float(i) * 18.0)
		pv.lane_offset = LANE_OFFSETS.pick_random()
		pv.instance.reset_graze()
		_snap_vehicle_to_road(pv)
