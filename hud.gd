# ==============================================================================
# MASTER SPEC: FlowState - Mobile Portrait HUD
# Engine: Godot 4 (GDScript)
# Minimalist, comic-styled portrait 9:16 telemetry and near-miss popups.
# ==============================================================================
class_name AGHUD
extends Control

@export var player_vehicle: AGVehicle
@export var game_manager: AGGameManager

# Palette Constants
const COLOR_SAND: Color = Color(0.918, 0.859, 0.784)        # #EADBC8 Bone Sand
const COLOR_VIOLET: Color = Color(0.169, 0.118, 0.227)      # #2B1E3A Deep Violet
const COLOR_VERMILION: Color = Color(0.902, 0.224, 0.275)   # #E63946 Comic Red
const COLOR_CYAN: Color = Color(0.2, 0.8, 1.0)              # Flow Cyan

var speed_label: Label
var score_label: Label
var drift_badge: Label
var graze_popup: Label
var flash_rect: ColorRect

var graze_timer: float = 0.0
var flash_timer: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui_elements()
	
	if game_manager:
		game_manager.near_miss_registered.connect(_on_near_miss)
		game_manager.crash_occurred.connect(_on_crash)

func _build_ui_elements() -> void:
	# 1. Crash Flash Overlay
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	
	# Top Container (Portrait Layout)
	var top_box := VBoxContainer.new()
	top_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_box.offset_left = 32.0
	top_box.offset_top = 48.0
	top_box.offset_right = -32.0
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_box)
	
	# Header Row
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(header)
	
	# Speed Display
	speed_label = Label.new()
	speed_label.text = "150 KM/H"
	speed_label.add_theme_font_size_override("font_size", 42)
	speed_label.add_theme_color_override("font_color", COLOR_SAND)
	header.add_child(speed_label)
	
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	# Score Display
	score_label = Label.new()
	score_label.text = "FLOW 0"
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", COLOR_SAND)
	header.add_child(score_label)
	
	# Drift / Flow State Badge
	drift_badge = Label.new()
	drift_badge.text = "[ DRIFT ACTIVE ]"
	drift_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drift_badge.add_theme_font_size_override("font_size", 28)
	drift_badge.add_theme_color_override("font_color", COLOR_VERMILION)
	drift_badge.visible = false
	top_box.add_child(drift_badge)
	
	# Near-Miss Graze Popup
	graze_popup = Label.new()
	graze_popup.text = "GRAZE! +300"
	graze_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	graze_popup.set_anchors_preset(Control.PRESET_CENTER)
	graze_popup.position = Vector2(0, -180.0)
	graze_popup.add_theme_font_size_override("font_size", 54)
	graze_popup.add_theme_color_override("font_color", COLOR_CYAN)
	graze_popup.visible = false
	add_child(graze_popup)

func _process(delta: float) -> void:
	if is_instance_valid(player_vehicle):
		var spd_kmh: int = int(player_vehicle.get_forward_velocity() * 3.6)
		speed_label.text = str(maxi(0, spd_kmh)) + " KM/H"
		drift_badge.visible = player_vehicle.is_drift_active
		
	if game_manager:
		score_label.text = "FLOW " + str(game_manager.total_score)
		
	# Graze popup fade
	if graze_timer > 0.0:
		graze_timer -= delta
		if graze_timer <= 0.0:
			graze_popup.visible = false
			
	# Crash flash fade
	if flash_timer > 0.0:
		flash_timer -= delta
		var alpha: float = clamp(flash_timer / 0.15, 0.0, 1.0)
		flash_rect.color = Color(1.0, 0.95, 0.9, alpha * 0.75)
	else:
		flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)

func _on_near_miss(points: int, _count: int) -> void:
	graze_popup.text = "GRAZE! +" + str(points)
	graze_popup.visible = true
	graze_timer = 0.65 # Visible for 650ms

func _on_crash() -> void:
	flash_timer = 0.18 # 180ms white/ivory flash
