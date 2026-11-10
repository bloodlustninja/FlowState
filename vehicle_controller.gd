# ==============================================================================
# MASTER SPEC: FlowState - Grounded 4-Wheel Performance Chassis Rig
# Engine: Godot 4 (GDScript)
# Model: Grounded 4-wheel raycast suspension with per-axle tire friction curves
# ==============================================================================
class_name AGVehicle
extends RigidBody3D

# --- 1. CONSTANTS & SPECIFICATION PARAMETERS ---

# Chassis Mass & Geometry
const VEHICLE_MASS: float = 1200.0                   # Spec: 1200.0 kg
const TIRE_RADIUS: float = 0.35                      # Spec: 0.35m tire radius
const SUSPENSION_REST_LENGTH: float = 0.55           # Spec: 0.55m suspension travel length
const TOTAL_RAY_LENGTH: float = 0.95                 # Ray depth reach (rest_length + tire_radius + margin)

# Strut Spring & Damper Physics
const SPRING_K: float = 450.0                        # Spec: Spring Stiffness (k) = 450.0
const SPRING_C: float = 32.0                         # Spec: Damping (c) = 32.0

# Per-Axle Lateral Traction
const FRONT_AXLE_GRIP: float = 0.95                  # Spec: 0.95 sharp front bite, zero float
const REAR_AXLE_GRIP_CRUISE: float = 0.90            # Spec: 0.90 planted rear tracking
const REAR_AXLE_GRIP_DRIFT: float = 0.28             # Spec: 0.28 controlled rear oversteer
const MAX_STEER_ANGLE_DEG: float = 28.0              # Max front wheel steering angle
const DRIFT_EXIT_IMPULSE_SPEED: float = 15.0         # Spec: +15.0 m/s * forward_vector

# Propulsion & Surface Suction
const BASE_CRUISE_SPEED: float = 42.0                # Spec: 42.0 m/s (~150 km/h)
const CRUISE_ACCEL_FORCE: float = 24000.0            # Forward thrust authority
const DOWNFORCE_ACCEL: float = 35.0                  # Spec: 35.0 m/s^2 along -ground_normal
const ALIGNMENT_SPEED: float = 12.0                  # Surface alignment speed = 12.0 * delta

# Visual Body Roll
const ROLL_MAX_RAD: float = 0.15                     # Max body roll tilt (~8.6 degrees)
const ROLL_DAMPING_SPEED: float = 14.0               # Smooth weight transfer transition

# Ray Anchor Offsets (X right, Y up, -Z forward)
const STRUT_OFFSETS: Dictionary = {
	"FL": Vector3(-0.8, 0.0, -1.4),
	"FR": Vector3( 0.8, 0.0, -1.4),
	"RL": Vector3(-0.8, 0.0,  1.4),
	"RR": Vector3( 0.8, 0.0,  1.4)
}

# --- 2. EXPORTS & NODE REFERENCES ---

@export var visual_chassis: Node3D                   # Child node that visually rolls on lateral Gs

# --- 3. RUNTIME STATE VARIABLES ---

var is_drift_active: bool = false
var steer_input: float = 0.0                         # Range [-1.0, 1.0]
var average_ground_normal: Vector3 = Vector3.UP
var ground_contact_count: int = 0
var is_grounded: bool = false

var _current_roll: float = 0.0
var _prev_lateral_vel: float = 0.0
var _rays: Array[RayCast3D] = []

# --- 4. LIFECYCLE & INITIALIZATION ---

func _ready() -> void:
	mass = VEHICLE_MASS
	gravity_scale = 0.0                              # Replaced by banked ground-effect downforce
	continuous_cd = true
	custom_integrator = false
	
	if not visual_chassis:
		visual_chassis = get_node_or_null("VisualChassis")
	
	_setup_wheel_struts()


func _setup_wheel_struts() -> void:
	_rays.clear()
	var container: Node3D = get_node_or_null("SuspensionRays")
	if not container:
		container = Node3D.new()
		container.name = "SuspensionRays"
		add_child(container)
	
	for strut_key in STRUT_OFFSETS.keys():
		var ray_name: String = "Ray" + strut_key
		var ray: RayCast3D = container.get_node_or_null(ray_name)
		if not ray:
			ray = RayCast3D.new()
			ray.name = ray_name
			container.add_child(ray)
		
		ray.position = STRUT_OFFSETS[strut_key]
		ray.target_position = Vector3(0.0, -TOTAL_RAY_LENGTH, 0.0)
		ray.enabled = true
		ray.exclude_parent = true
		ray.collision_mask = 1
		_rays.append(ray)


# --- 5. CORE PHYSICS INTEGRATION (60 Hz FIXED TIMESTEP) ---

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var delta: float = state.step
	
	# Coordinate frame vectors (-Z is Forward, +X is Right, +Y is Up)
	var forward_dir: Vector3 = -global_transform.basis.z.normalized()
	var right_dir: Vector3 = global_transform.basis.x.normalized()
	var up_dir: Vector3 = global_transform.basis.y.normalized()
	
	# --------------------------------------------------------------------------
	# A. 4-WHEEL RAYCAST STRUT SUSPENSION WITH TIRE RADIUS OFFSET
	# --------------------------------------------------------------------------
	var accumulated_normal: Vector3 = Vector3.ZERO
	ground_contact_count = 0
	
	for i in range(_rays.size()):
		var ray: RayCast3D = _rays[i]
		var strut_key: String = STRUT_OFFSETS.keys()[i]
		var is_front_wheel: bool = strut_key.begins_with("F")
		
		if ray.is_colliding():
			ground_contact_count += 1
			var hit_point: Vector3 = ray.get_collision_point()
			var hit_normal: Vector3 = ray.get_collision_normal()
			accumulated_normal += hit_normal
			
			var ray_origin_global: Vector3 = ray.global_transform.origin
			var distance_to_hit: float = ray_origin_global.distance_to(hit_point)
			
			# Effective suspension length considering tire radius
			var suspension_length: float = distance_to_hit - TIRE_RADIUS
			var compression: float = SUSPENSION_REST_LENGTH - suspension_length
			
			# Compression velocity (rate of change along local vertical axis)
			var point_vel: Vector3 = state.get_velocity_at_local_position(ray.position)
			var compression_vel: float = -point_vel.dot(up_dir)
			
			# Spring Force: F = (k * x - c * v) * (mass / 4)
			var spring_force_mag: float = (SPRING_K * compression) - (SPRING_C * compression_vel)
			spring_force_mag = max(spring_force_mag, 0.0)
			
			var spring_force_vector: Vector3 = up_dir * (spring_force_mag * (VEHICLE_MASS / 4.0))
			state.apply_force(spring_force_vector, ray.global_transform.origin - global_transform.origin)
			
			# ------------------------------------------------------------------
			# B. PER-AXLE TIRE TRACTION & FRICTION CURVES
			# ------------------------------------------------------------------
			# Front wheels steer based on steer_input; rear wheels remain locked to chassis
			var wheel_right_dir: Vector3
			var tire_lateral_grip: float
			
			if is_front_wheel:
				# Front Axle: Yaw offset = steer_input * 28 deg (Godot -Z forward: right turn = negative yaw)
				var steer_angle_rad: float = -steer_input * deg_to_rad(MAX_STEER_ANGLE_DEG)
				var steer_rot := Basis(Vector3.UP, steer_angle_rad)
				wheel_right_dir = (global_transform.basis * (steer_rot * Vector3.RIGHT)).normalized()
				tire_lateral_grip = FRONT_AXLE_GRIP # Spec: 0.95 sharp front bite
			else:
				# Rear Axle: Locked parallel to chassis
				wheel_right_dir = right_dir
				tire_lateral_grip = REAR_AXLE_GRIP_DRIFT if is_drift_active else REAR_AXLE_GRIP_CRUISE
			
			# Compute lateral slip speed for this tire
			var tire_lateral_speed: float = point_vel.dot(wheel_right_dir)
			
			# Canceling friction force along contact patch
			var grip_ratio: float = clamp(tire_lateral_grip * (delta * 60.0), 0.0, 1.0)
			var tire_damping_force: Vector3 = -wheel_right_dir * (tire_lateral_speed * grip_ratio * (VEHICLE_MASS / 4.0) / delta)
			state.apply_force(tire_damping_force, ray.global_transform.origin - global_transform.origin)
	
	is_grounded = ground_contact_count > 0
	
	# --------------------------------------------------------------------------
	# C. SURFACE NORMAL AVERAGING & BANKED GHAT DOWNFORCE
	# --------------------------------------------------------------------------
	if is_grounded:
		average_ground_normal = (accumulated_normal / float(ground_contact_count)).normalized()
	else:
		average_ground_normal = average_ground_normal.slerp(Vector3.UP, 2.0 * delta).normalized()
	
	# Ground-effect downforce: 35.0 m/s^2 directed along -average_ground_normal
	var downforce_vector: Vector3 = -average_ground_normal * (DOWNFORCE_ACCEL * VEHICLE_MASS)
	state.apply_central_force(downforce_vector)
	
	# Slerp chassis basis Y to bank normal (spec: 12.0 * delta)
	if is_grounded:
		var align_rot: Quaternion = Quaternion(up_dir, average_ground_normal)
		var slerp_factor: float = clamp(ALIGNMENT_SPEED * delta, 0.0, 1.0)
		var interpolated_rot: Quaternion = Quaternion.IDENTITY.slerp(align_rot, slerp_factor)
		var new_basis: Basis = Basis(interpolated_rot) * state.transform.basis
		state.transform.basis = new_basis.orthonormalized()
	
	# --------------------------------------------------------------------------
	# D. PROPULSION: REAR-WHEEL CRUISE SPEED (42.0 m/s)
	# --------------------------------------------------------------------------
	var current_fwd_speed: float = state.linear_velocity.dot(forward_dir)
	var speed_error: float = BASE_CRUISE_SPEED - current_fwd_speed
	
	if is_grounded:
		var thrust_magnitude: float = clamp(speed_error * 2500.0, -CRUISE_ACCEL_FORCE * 0.5, CRUISE_ACCEL_FORCE)
		state.apply_central_force(forward_dir * thrust_magnitude)
	
	# --------------------------------------------------------------------------
	# E. VISUAL CHASSIS ROLL (G-FORCE TILT ALONG LOCAL Z)
	# --------------------------------------------------------------------------
	var current_lateral_vel: float = state.linear_velocity.dot(right_dir)
	var lateral_accel: float = (current_lateral_vel - _prev_lateral_vel) / max(delta, 0.001)
	_prev_lateral_vel = current_lateral_vel
	
	# Centripetal G-force lean
	var target_roll: float = clamp(-lateral_accel / 9.8 * 0.08, -ROLL_MAX_RAD, ROLL_MAX_RAD)
	_current_roll = lerp(_current_roll, target_roll, ROLL_DAMPING_SPEED * delta)
	
	if visual_chassis:
		visual_chassis.rotation.z = _current_roll


# --- 6. PUBLIC API & STATE TOGGLES ---

## Toggle drift mode. When exiting drift mode, rear grip snaps back to 0.90 and an impulse is applied.
func set_drift_state(active: bool) -> void:
	if is_drift_active and not active:
		_apply_drift_exit_impulse()
	
	is_drift_active = active


## Applies instantaneous +15.0 m/s * forward_vector impulse on drift exit
func _apply_drift_exit_impulse() -> void:
	var forward_dir: Vector3 = -global_transform.basis.z.normalized()
	var impulse_vector: Vector3 = forward_dir * (DRIFT_EXIT_IMPULSE_SPEED * VEHICLE_MASS)
	apply_central_impulse(impulse_vector)


## Steering input injection [-1.0, 1.0] from single-thumb input controller
func set_steer_input(value: float) -> void:
	steer_input = clamp(value, -1.0, 1.0)


## Returns current lateral velocity component (signed, +X is right)
func get_lateral_velocity() -> float:
	var right_dir: Vector3 = global_transform.basis.x.normalized()
	return linear_velocity.dot(right_dir)


## Returns current forward velocity component (signed, -Z is forward)
func get_forward_velocity() -> float:
	var forward_dir: Vector3 = -global_transform.basis.z.normalized()
	return linear_velocity.dot(forward_dir)
