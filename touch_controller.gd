# ==============================================================================
# MASTER SPEC: FlowState - Section 2: Single-Thumb Touch Controller
# Engine: Godot 4 (GDScript)
# Target: Mobile Portrait (9:16 aspect ratio)
# ==============================================================================
class_name AGTouchController
extends Control

# --- 1. CONSTANTS & SPECIFICATION PARAMETERS ---

# Screen touch partition: bottom 40%
const ACTIVE_VIEWPORT_RATIO_Y: float = 0.60          # Active when Y > viewport_height * 0.60

# Steering Mapping
const STEER_DEADZONE_PX: float = 8.0                 # Spec: Deadzone: 8.0 px
const STEER_SATURATION_PX: float = 120.0             # Spec: Clamp at +/- 120.0 px -> [-1.0, 1.0]

# Drift / Weight-Shift Trigger
const FLICK_DOWN_THRESHOLD_PX: float = 45.0          # Spec: Delta Y > 45.0 px
const FLICK_MIN_VELOCITY: float = 250.0              # Spec: Velocity > 250 px/s

# --- 2. EXPORTS & NODE REFERENCES ---

@export var vehicle: AGVehicle                       # Target vehicle instance
@export var show_debug_gizmo: bool = false           # Hidden by default to not obstruct gameplay

# --- 3. RUNTIME STATE VARIABLES ---

var is_touch_active: bool = false
var touch_index: int = -1                            # Multi-touch tracking (-1 for mouse)
var anchor_position: Vector2 = Vector2.ZERO          # (X0, Y0) dynamic anchor
var current_touch_position: Vector2 = Vector2.ZERO   # Current screen position
var previous_touch_position: Vector2 = Vector2.ZERO  # Position from previous frame
var touch_velocity_y: float = 0.0                    # Pixels per second along Y

var is_drift_locked: bool = false
var current_steer_value: float = 0.0

# --- 4. INPUT PROCESSING ---

func _ready() -> void:
	# Ensure control covers the whole screen to catch input
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _input(event: InputEvent) -> void:
	var viewport_height: float = get_viewport_rect().size.y
	var active_min_y: float = viewport_height * ACTIVE_VIEWPORT_RATIO_Y
	
	# Touch screen events
	if event is InputEventScreenTouch:
		var touch_ev := event as InputEventScreenTouch
		if touch_ev.pressed:
			# Verify touch occurred in bottom 40% of viewport
			if touch_ev.position.y >= active_min_y and not is_touch_active:
				_start_touch(touch_ev.position, touch_ev.index)
		elif touch_ev.index == touch_index:
			_end_touch()
			
	elif event is InputEventScreenDrag:
		var drag_ev := event as InputEventScreenDrag
		if is_touch_active and drag_ev.index == touch_index:
			_update_touch_position(drag_ev.position)
	
	# Mouse emulation for desktop testing
	elif event is InputEventMouseButton:
		var mouse_btn := event as InputEventMouseButton
		if mouse_btn.button_index == MOUSE_BUTTON_LEFT:
			if mouse_btn.pressed:
				if mouse_btn.position.y >= active_min_y and not is_touch_active:
					_start_touch(mouse_btn.position, -1)
			elif is_touch_active and touch_index == -1:
				_end_touch()
				
	elif event is InputEventMouseMotion:
		var mouse_mot := event as InputEventMouseMotion
		if is_touch_active and touch_index == -1:
			_update_touch_position(mouse_mot.position)


func _process(delta: float) -> void:
	if not is_touch_active:
		return
	
	# Compute vertical velocity (pixels / sec)
	if delta > 0.0001:
		var dy_frame: float = current_touch_position.y - previous_touch_position.y
		touch_velocity_y = dy_frame / delta
	
	previous_touch_position = current_touch_position
	
	# Evaluate gesture delta from dynamic anchor
	var delta_pos: Vector2 = current_touch_position - anchor_position
	
	# --------------------------------------------------------------------------
	# A. STEERING CALCULATION (DEADZONE & SATURATION)
	# --------------------------------------------------------------------------
	var delta_x: float = delta_pos.x
	var abs_dx: float = abs(delta_x)
	
	if abs_dx <= STEER_DEADZONE_PX:
		current_steer_value = 0.0
	else:
		# Map [STEER_DEADZONE_PX, STEER_SATURATION_PX] -> [0.0, 1.0]
		var usable_span: float = STEER_SATURATION_PX - STEER_DEADZONE_PX
		var normalized_mag: float = clamp((abs_dx - STEER_DEADZONE_PX) / usable_span, 0.0, 1.0)
		current_steer_value = sign(delta_x) * normalized_mag
	
	if vehicle:
		vehicle.set_steer_input(current_steer_value)
	
	# --------------------------------------------------------------------------
	# B. DRIFT / WEIGHT-SHIFT TRIGGER
	# --------------------------------------------------------------------------
	var delta_y: float = delta_pos.y
	
	# Check flick trigger condition: Delta Y > 45px and downward velocity > 250 px/s
	if not is_drift_locked:
		if delta_y > FLICK_DOWN_THRESHOLD_PX and touch_velocity_y > FLICK_MIN_VELOCITY:
			is_drift_locked = true
			if vehicle:
				vehicle.set_drift_state(true)
	else:
		# Drift state locks until touch release or Delta Y returns within deadzone
		if abs(delta_y) <= STEER_DEADZONE_PX:
			is_drift_locked = false
			if vehicle:
				vehicle.set_drift_state(false)
	
	if show_debug_gizmo:
		queue_redraw()


# --- 5. STATE TRANSITIONS ---

func _start_touch(pos: Vector2, idx: int) -> void:
	is_touch_active = true
	touch_index = idx
	anchor_position = pos
	current_touch_position = pos
	previous_touch_position = pos
	touch_velocity_y = 0.0
	is_drift_locked = false
	current_steer_value = 0.0
	if show_debug_gizmo:
		queue_redraw()


func _end_touch() -> void:
	is_touch_active = false
	touch_index = -1
	current_steer_value = 0.0
	
	if vehicle:
		vehicle.set_steer_input(0.0)
		if is_drift_locked:
			is_drift_locked = false
			vehicle.set_drift_state(false) # Triggers drift exit impulse
	
	if show_debug_gizmo:
		queue_redraw()


func _update_touch_position(pos: Vector2) -> void:
	current_touch_position = pos


# --- 6. DEBUG GIZMO DRAWING ---

func _draw() -> void:
	if not show_debug_gizmo:
		return
		
	var viewport_rect_size: Vector2 = get_viewport_rect().size
	var line_y: float = viewport_rect_size.y * ACTIVE_VIEWPORT_RATIO_Y
	
	# Draw touch boundary line
	draw_line(Vector2(0, line_y), Vector2(viewport_rect_size.x, line_y), Color(1.0, 1.0, 1.0, 0.15), 1.0)
	
	if is_touch_active:
		# Dynamic Anchor circle
		draw_circle(anchor_position, 6.0, Color(0.9, 0.85, 0.7, 0.4))
		# Saturation guide ring
		draw_arc(anchor_position, STEER_SATURATION_PX, 0, TAU, 32, Color(0.9, 0.85, 0.7, 0.15), 1.5)
		# Deadzone ring
		draw_arc(anchor_position, STEER_DEADZONE_PX, 0, TAU, 16, Color(1.0, 0.3, 0.3, 0.3), 1.0)
		# Downward flick threshold line
		var flick_y: float = anchor_position.y + FLICK_DOWN_THRESHOLD_PX
		draw_line(Vector2(anchor_position.x - 30, flick_y), Vector2(anchor_position.x + 30, flick_y), Color(0.3, 0.8, 1.0, 0.4), 2.0)
		
		# Current touch point
		var thumb_color: Color = Color(1.0, 0.2, 0.4, 0.9) if is_drift_locked else Color(0.2, 0.8, 1.0, 0.8)
		draw_line(anchor_position, current_touch_position, thumb_color, 2.5)
		draw_circle(current_touch_position, 14.0, thumb_color)
