class_name CockpitCutIn
extends Control

# ==============================================================================
# FLOWSTATE: PROCEDURAL 2D MANGA COCKPIT CUT-IN PANEL
# Detailed custom 2D _draw() manga illustration:
# - Gloved racing driver hand gripping aluminum/leather shift knob
# - Shift boot leather folds and console gate
# - Dynamic radial manga action speed-lines
# - Biome-specific title & Japanese onomatopoeia SFX stamps:
#     * Shuto Dusk: "湾岸 // SUNSET RUN" + "ゴゴゴ"
#     * Neo-Shinjuku: "新宿 // MIDNIGHT DRIFT" + "キュキュッ"
#     * Hakone Snow: "箱根 // ALPINE DAWN" + "ザザッ"
#     * Enoshima Coast: "江ノ島 // OCEAN FLOW" + "ビュンッ"
# ==============================================================================

const INK_COLOR := Color("#0B0D12")
const PAPER_COLOR := Color("#F5F2EB")
const HIGHLIGHT_COLOR := Color("#FFFFFF")
const ACCENT_RED := Color("#E11D48")

var current_biome_id: String = "shuto_dusk"
var anim_phase: float = 0.0

const BIOME_CUTIN_DATA := {
	"shuto_dusk": {
		"tag": "湾岸 // SUNSET RUN",
		"sfx": "ゴゴゴ",
		"sub": "ENGINE RUMBLE SFX",
		"accent": Color("#FF5E00")
	},
	"neo_shinjuku": {
		"tag": "新宿 // MIDNIGHT DRIFT",
		"sfx": "キュキュッ",
		"sub": "TIRE SCREECH SFX",
		"accent": Color("#00E5FF")
	},
	"hakone_snow": {
		"tag": "箱根 // ALPINE DAWN",
		"sfx": "ザザッ",
		"sub": "SNOW CARVE SFX",
		"accent": Color("#BAE6FD")
	},
	"enoshima_coast": {
		"tag": "江ノ島 // OCEAN FLOW",
		"sfx": "ビュンッ",
		"sub": "WIND RUSH SFX",
		"accent": Color("#FDE68A")
	}
}

func _ready() -> void:
	custom_minimum_size = Vector2(480, 420)
	size = Vector2(480, 420)
	clip_contents = true

func _process(delta: float) -> void:
	anim_phase += delta * 6.0
	queue_redraw()

func set_biome(b_id: String) -> void:
	current_biome_id = b_id
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var data: Dictionary = BIOME_CUTIN_DATA.get(current_biome_id, BIOME_CUTIN_DATA["shuto_dusk"])

	# 1. Warm Vintage Manga Paper Background
	draw_rect(Rect2(0, 0, w, h), PAPER_COLOR, true)

	# 2. Screentone Halftone Dot Stippling (Procedural 45-degree grid in upper quadrant)
	var dot_step: float = 14.0
	for x in range(10, int(w), int(dot_step)):
		for y in range(10, int(h * 0.65), int(dot_step)):
			if int(float(x + y) / dot_step) % 2 == 0:
				draw_circle(Vector2(float(x), float(y)), 1.8, Color(0.12, 0.14, 0.18, 0.35))

	# 3. Dynamic Radial Manga Speedlines (Radiating outward from shift knob center at ~ (230, 240))
	var focal := Vector2(w * 0.46, h * 0.56)
	var num_lines: int = 28
	for i in range(num_lines):
		var base_angle: float = float(i) * (TAU / float(num_lines))
		var angle_jitter: float = sin(base_angle * 3.0 + anim_phase) * 0.04
		var angle: float = base_angle + angle_jitter
		var dir := Vector2(cos(angle), sin(angle))
		var inner_rad: float = randf_range(85.0, 115.0)
		var outer_rad: float = max(w, h) * 1.3
		var p1: Vector2 = focal + dir * inner_rad
		var p2: Vector2 = focal + dir * outer_rad
		var thick: float = 1.2 if (i % 2 == 0) else 2.6
		draw_line(p1, p2, INK_COLOR, thick)

	# 4. Center Console Base & Shift Boot Leather Creases
	var boot_pts := PackedVector2Array([
		Vector2(w * 0.18, h * 0.98),
		Vector2(w * 0.28, h * 0.74),
		Vector2(w * 0.40, h * 0.62),
		Vector2(w * 0.54, h * 0.62),
		Vector2(w * 0.66, h * 0.74),
		Vector2(w * 0.78, h * 0.98)
	])
	draw_colored_polygon(boot_pts, INK_COLOR)

	# Leather highlight seams
	draw_line(Vector2(w * 0.32, h * 0.74), Vector2(w * 0.42, h * 0.65), HIGHLIGHT_COLOR, 2.2)
	draw_line(Vector2(w * 0.62, h * 0.74), Vector2(w * 0.52, h * 0.65), HIGHLIGHT_COLOR, 2.2)
	draw_line(Vector2(w * 0.46, h * 0.92), Vector2(w * 0.46, h * 0.68), HIGHLIGHT_COLOR, 1.8)

	# 5. Shift Lever Chrome Shaft
	var lever_bot := Vector2(w * 0.46, h * 0.64)
	var lever_top := Vector2(w * 0.46, h * 0.46)
	draw_line(lever_bot, lever_top, INK_COLOR, 12.0)
	draw_line(lever_bot, lever_top, HIGHLIGHT_COLOR, 4.0)

	# 6. Shift Knob (Aluminum/Leather Teardrop Sphere)
	var knob_center := Vector2(w * 0.46, h * 0.43)
	draw_circle(knob_center, 38.0, INK_COLOR)
	draw_circle(knob_center + Vector2(-6, -6), 32.0, Color(0.20, 0.22, 0.28))
	draw_circle(knob_center + Vector2(-10, -10), 22.0, HIGHLIGHT_COLOR)

	# Shift Gate Pattern Etching (H-pattern: 1-3-5 top, 2-4-R bot)
	var gate_c := knob_center + Vector2(-4, -4)
	draw_line(gate_c + Vector2(-12, -10), gate_c + Vector2(-12, 10), INK_COLOR, 2.0)
	draw_line(gate_c + Vector2(0, -10), gate_c + Vector2(0, 10), INK_COLOR, 2.0)
	draw_line(gate_c + Vector2(12, -10), gate_c + Vector2(12, 10), INK_COLOR, 2.0)
	draw_line(gate_c + Vector2(-12, 0), gate_c + Vector2(12, 0), INK_COLOR, 2.0)

	# 7. Racing Glove & Hand Gripping the Knob
	# Palm & fingers wrapping around knob
	var glove_poly := PackedVector2Array([
		Vector2(w * 0.38, h * 0.35),
		Vector2(w * 0.56, h * 0.33),
		Vector2(w * 0.68, h * 0.40),
		Vector2(w * 0.66, h * 0.54),
		Vector2(w * 0.54, h * 0.58),
		Vector2(w * 0.42, h * 0.56),
		Vector2(w * 0.36, h * 0.46)
	])
	draw_colored_polygon(glove_poly, INK_COLOR)

	# Glove seam stitching & knuckle ventilation holes
	draw_line(Vector2(w * 0.42, h * 0.38), Vector2(w * 0.58, h * 0.37), HIGHLIGHT_COLOR, 2.5)
	draw_circle(Vector2(w * 0.45, h * 0.44), 3.2, HIGHLIGHT_COLOR)
	draw_circle(Vector2(w * 0.53, h * 0.43), 3.2, HIGHLIGHT_COLOR)
	draw_circle(Vector2(w * 0.60, h * 0.45), 3.2, HIGHLIGHT_COLOR)

	# Forearm / Wrist cuff extending off bottom-left
	var arm_poly := PackedVector2Array([
		Vector2(w * 0.10, h * 0.66),
		Vector2(w * 0.38, h * 0.48),
		Vector2(w * 0.42, h * 0.58),
		Vector2(w * 0.16, h * 0.82)
	])
	draw_colored_polygon(arm_poly, INK_COLOR)
	draw_line(Vector2(w * 0.14, h * 0.68), Vector2(w * 0.38, h * 0.52), HIGHLIGHT_COLOR, 3.0)

	# 8. Top Chapter Title Stamp Header (Angled Dark Box)
	var tag_rect := Rect2(16, 16, 260, 36)
	draw_rect(tag_rect, INK_COLOR, true)
	draw_rect(tag_rect, data["accent"], false, 2.5)
	# Accent left tab
	draw_rect(Rect2(16, 16, 8, 36), data["accent"], true)

	var font := ThemeDB.fallback_font
	if is_instance_valid(font):
		draw_string(font, Vector2(32, 40), data["tag"], HORIZONTAL_ALIGNMENT_LEFT, 240, 14, HIGHLIGHT_COLOR)

	# 9. Giant Bold Japanese Onomatopoeia SFX Stamp (Brush Inking with Drop Shadow)
	var sfx_text: String = data["sfx"]
	var sfx_pos := Vector2(w * 0.54, h * 0.28)
	var sfx_font_size: int = 58

	# Heavy black dropshadow
	draw_string(font, sfx_pos + Vector2(5, 6), sfx_text, HORIZONTAL_ALIGNMENT_LEFT, 240, sfx_font_size, INK_COLOR)
	# Accent color fill with high contrast
	draw_string(font, sfx_pos, sfx_text, HORIZONTAL_ALIGNMENT_LEFT, 240, sfx_font_size, data["accent"])
	# Fine inner white ink sheen
	draw_string(font, sfx_pos + Vector2(-1, -2), sfx_text, HORIZONTAL_ALIGNMENT_LEFT, 240, sfx_font_size, HIGHLIGHT_COLOR)

	# Subtitle description label
	var sub_text: String = data["sub"]
	draw_string(font, Vector2(w * 0.54, h * 0.34), sub_text, HORIZONTAL_ALIGNMENT_LEFT, 240, 12, INK_COLOR)

	# 10. Bold 4px Black Ink Outer Border
	draw_rect(Rect2(0, 0, w, h), INK_COLOR, false, 4.0)
