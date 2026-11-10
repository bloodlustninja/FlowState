# ==============================================================================
# MASTER SPEC: FlowState - Game Manager & Sub-300ms Crash-Restart Loop
# Engine: Godot 4 (GDScript)
# Manages state machine: RUNNING, CRASHED, RESETTING with <300ms recovery budget.
# ==============================================================================
class_name AGGameManager
extends Node

signal near_miss_registered(points: int, total_near_misses: int)
signal state_changed(new_state: int)
signal crash_occurred()

enum GameState {
	RUNNING,
	CRASHED,
	RESETTING
}

@export var player_vehicle: AGVehicle
@export var follow_camera: AGFollowCamera
@export var traffic_manager: Node
@export var hud_node: Control

var current_state: GameState = GameState.RUNNING
var total_score: int = 0
var near_miss_count: int = 0
var flow_combo: int = 1

# Sub-300ms Crash Timeline Constants
const CRASH_FREEZE_TIME_MS: float = 0.120            # 120ms initial impact freeze
const CRASH_TOTAL_RESTART_MS: float = 0.280          # 280ms total restart (well below 300ms)

var _crash_timer: float = 0.0

func _ready() -> void:
	if traffic_manager and traffic_manager.has_signal("near_miss_triggered"):
		traffic_manager.near_miss_triggered.connect(_on_near_miss)
	
	if player_vehicle:
		player_vehicle.max_contacts_reported = 4
		player_vehicle.contact_monitor = true
		player_vehicle.body_entered.connect(_on_player_body_entered)

func _physics_process(delta: float) -> void:
	if current_state == GameState.RUNNING:
		# Continuous distance scoring
		if is_instance_valid(player_vehicle):
			var forward_spd: float = player_vehicle.get_forward_velocity()
			if forward_spd > 5.0:
				var multiplier: float = 2.0 if player_vehicle.is_drift_active else 1.0
				total_score += int(forward_spd * delta * 10.0 * multiplier)
				
	elif current_state == GameState.CRASHED:
		_crash_timer += delta / max(Engine.time_scale, 0.01) # Real time
		
		# Step 1: Reposition vehicle at 120ms
		if _crash_timer >= CRASH_FREEZE_TIME_MS and current_state != GameState.RESETTING:
			current_state = GameState.RESETTING
			_instant_reset_vehicle()
			
		# Step 2: Resume full gameplay at 280ms (< 300ms requirement)
		if _crash_timer >= CRASH_TOTAL_RESTART_MS:
			_complete_restart()

func _on_player_body_entered(body: Node) -> void:
	if current_state != GameState.RUNNING:
		return
		
	# If colliding with an obstacle (Layer 2)
	if body is AGTrafficVehicle:
		trigger_crash()

## Sub-300ms crash-restart sequence
func trigger_crash() -> void:
	if current_state != GameState.RUNNING:
		return
		
	current_state = GameState.CRASHED
	_crash_timer = 0.0
	flow_combo = 1
	
	# Stop player craft instantly
	if is_instance_valid(player_vehicle):
		player_vehicle.linear_velocity = Vector3.ZERO
		player_vehicle.angular_velocity = Vector3.ZERO
		
	# Screen punch and crash notification
	if follow_camera:
		follow_camera.trigger_impact_punch(Vector3.FORWARD)
		
	crash_occurred.emit()
	state_changed.emit(current_state)

func _instant_reset_vehicle() -> void:
	if not is_instance_valid(player_vehicle):
		return
		
	# Reposition vehicle slightly ahead on current road center, upright
	var cur_z: float = player_vehicle.global_position.z
	player_vehicle.global_position = Vector3(0.0, 1.2, cur_z - 8.0)
	player_vehicle.global_transform.basis = Basis.IDENTITY
	player_vehicle.linear_velocity = Vector3(0.0, 0.0, -10.0) # Initial roll-out speed
	player_vehicle.angular_velocity = Vector3.ZERO
	player_vehicle.set_steer_input(0.0)
	player_vehicle.set_drift_state(false)
	
	if traffic_manager and traffic_manager.has_method("reset_all_traffic"):
		traffic_manager.reset_all_traffic()

func _complete_restart() -> void:
	current_state = GameState.RUNNING
	_crash_timer = 0.0
	state_changed.emit(current_state)

func _on_near_miss(lateral_dir: float) -> void:
	if current_state != GameState.RUNNING:
		return
		
	near_miss_count += 1
	flow_combo = mini(flow_combo + 1, 8)
	var points: int = 150 * flow_combo
	total_score += points
	
	# Trigger camera 40ms time dilation & 0.25m lateral punch
	if follow_camera:
		follow_camera.trigger_impact_punch(Vector3(lateral_dir, 0.0, 0.0))
		
	near_miss_registered.emit(points, near_miss_count)
