# ==============================================================================
# MASTER SPEC: FlowState - Hotfix Camera Rig
# Perspective 65° FOV, chase offset (0, 5.0, 8.0), pitch 32° downward.
# Shows rear bumper, long stretching road, and horizon.
# ==============================================================================
class_name AGFollowCamera
extends Camera3D

# Camera Positioning & Perspective Directive
const BASE_OFFSET: Vector3 = Vector3(0.0, 5.0, 8.0)  # Behind & above car: (0, 5, 8)
const PITCH_ANGLE_DEG: float = -32.0                 # Pitch down 32° (30°-35° range)
const TARGET_FOV: float = 65.0                       # Spec: Perspective FOV 65°
const ROTATIONAL_LAG_TIME: float = 0.14              # SmoothDamp lag time
const LOOK_AHEAD_FACTOR: float = 0.20                # Lateral look-ahead

# Near-Miss Impact Punch
const PUNCH_TIME_DILATION_SCALE: float = 0.1
const PUNCH_DURATION_SEC: float = 0.040
const PUNCH_DISTANCE: float = 0.25

@export var target_vehicle: AGVehicle

var current_yaw: float = 0.0
var yaw_velocity: float = 0.0
var smoothed_look_ahead_x: float = 0.0
var punch_offset: Vector3 = Vector3.ZERO
var punch_timer: float = 0.0

func _ready() -> void:
	top_level = true
	# Ensure perspective projection and 65° FOV
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = TARGET_FOV
	keep_aspect = Camera3D.KEEP_WIDTH
	
	if target_vehicle:
		current_yaw = target_vehicle.global_transform.basis.get_euler().y
		global_position = _calculate_target_position(0.0)
		_apply_camera_rotation()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_vehicle):
		return
	
	# Handle near-miss impact punch recovery
	if punch_timer > 0.0:
		var real_delta: float = delta / max(Engine.time_scale, 0.01)
		punch_timer -= real_delta
		if punch_timer <= 0.0:
			Engine.time_scale = 1.0
			punch_timer = 0.0
		punch_offset = punch_offset.lerp(Vector3.ZERO, 15.0 * delta)
	
	# 1. SmoothDamp Yaw Rotational Lag
	var vehicle_yaw: float = target_vehicle.global_transform.basis.get_euler().y
	current_yaw = _smooth_damp_angle(current_yaw, vehicle_yaw, ROTATIONAL_LAG_TIME, delta)
	
	# 2. Lateral Look-Ahead
	var lateral_vel: float = target_vehicle.get_lateral_velocity()
	var target_look_ahead_x: float = lateral_vel * LOOK_AHEAD_FACTOR
	smoothed_look_ahead_x = lerp(smoothed_look_ahead_x, target_look_ahead_x, 10.0 * delta)
	
	# 3. Dynamic High-Speed FOV expansion (65° -> 74° at top speed)
	var fwd_speed: float = max(0.0, target_vehicle.get_forward_velocity())
	var speed_ratio: float = clamp(fwd_speed / 42.0, 0.0, 1.2)
	fov = lerp(fov, TARGET_FOV + (speed_ratio * 9.0), 4.0 * delta)
	
	# 4. Position & Rotation
	var target_pos: Vector3 = _calculate_target_position(smoothed_look_ahead_x)
	global_position = target_pos + punch_offset
	_apply_camera_rotation()

func _calculate_target_position(look_ahead_x: float) -> Vector3:
	var yaw_basis := Basis(Vector3.UP, current_yaw)
	var local_offset := Vector3(look_ahead_x, BASE_OFFSET.y, BASE_OFFSET.z)
	return target_vehicle.global_position + (yaw_basis * local_offset)

func _apply_camera_rotation() -> void:
	var yaw_basis := Basis(Vector3.UP, current_yaw)
	var pitch_basis := Basis(Vector3.RIGHT, deg_to_rad(PITCH_ANGLE_DEG))
	global_transform.basis = (yaw_basis * pitch_basis).orthonormalized()

func trigger_impact_punch(collision_normal: Vector3 = Vector3.RIGHT) -> void:
	Engine.time_scale = PUNCH_TIME_DILATION_SCALE
	punch_timer = PUNCH_DURATION_SEC
	
	var yaw_basis := Basis(Vector3.UP, current_yaw)
	var local_normal := yaw_basis.inverse() * collision_normal
	var lateral_dir: float = sign(local_normal.x) if abs(local_normal.x) > 0.05 else 1.0
	punch_offset = yaw_basis * Vector3(-lateral_dir * PUNCH_DISTANCE, 0.0, 0.0)

func _smooth_damp_angle(current: float, target: float, smooth_time: float, delta: float) -> float:
	var diff: float = wrapf(target - current, -PI, PI)
	var adjusted_target: float = current + diff
	smooth_time = max(0.0001, smooth_time)
	var omega: float = 2.0 / smooth_time
	var x: float = omega * delta
	var exp_factor: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: float = current - adjusted_target
	var temp: float = (yaw_velocity + omega * change) * delta
	yaw_velocity = (yaw_velocity - omega * temp) * exp_factor
	return adjusted_target + (change + temp) * exp_factor
