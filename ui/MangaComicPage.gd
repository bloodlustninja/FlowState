class_name MangaComicPage
extends Control

const CockpitCutIn = preload("res://ui/CockpitCutIn.gd")

# ==============================================================================
# FLOWSTATE: FULL-SCREEN FLIPPABLE MANGA COMIC-BOOK START SPREAD
# Modeled directly on classic Japanese street-racing manga spreads (Initial D / Wangan Midnight).
# - Warm vintage manga paper canvas (#F3EFE6) with outer 5px ink border & stacked page edges.
# - 4-Panel diagonal manga layout with 12px white gutters & 4px black ink outlines:
#     1. Top Establishing Panel: Live 3D PanoramaCam (skyline & highway vista)
#     2. Center Hero Action Panel: Live 3D MainChaseCam (cruising car in B&W manga halftone)
#     3. Bottom-Left Cut-In Panel: Procedural 2D CockpitCutIn (gloved hand, shifter, SFX stamp)
#     4. Bottom-Right Cut-In Panel: Live 3D WheelCloseCam (rear tire, diffuser, tarmac spray)
# - Interactive page curl flip between biomes (0.4s curl peel)
# - Seamless "Dive Into The Panel" B&W-to-color zoom launch transition (0.55s)
# ==============================================================================

signal page_flip_requested(next_biome_id: String)
signal launch_requested(biome_id: String)

const INK_COLOR := Color("#0B0D12")
const PAPER_COLOR := Color("#F3EFE6")
const GUTTER_COLOR := Color("#FFFFFF")

const BIOME_PAGES: Array[Dictionary] = [
	{
		"id": "shuto_dusk",
		"chapter": "CHAPTER 01 // 首都高",
		"stage": "STAGE 1",
		"title": "SHUTO DUSK",
		"kanji_stamp": "首都高 // SUNSET DUSK",
		"time": "18:30 SUNSET",
		"sub": "Sunset Expressway · 165 KM/H · 1.0x",
		"caption": "THE LEGENDARY C1 LOOP AT SUNSET. TIRES BITE WARM ASPHALT AS THE DUSK GLOW IGNITES TOKYO SKYLINE...",
		"accent": Color("#FF5E00")
	},
	{
		"id": "neo_shinjuku",
		"chapter": "CHAPTER 02 // 新宿",
		"stage": "STAGE 2",
		"title": "NEO-SHINJUKU",
		"kanji_stamp": "新宿 // MIDNIGHT DRIFT",
		"time": "00:30 MIDNIGHT",
		"sub": "Midnight Neon Canyon · 185 KM/H · 1.25x",
		"caption": "MIDNIGHT IN THE NEON CANYON. MONSOON RAIN SLICKS THE ASPHALT UNDER MONORAIL GIRDERS AND ELECTRIC BILLBOARDS...",
		"accent": Color("#00E5FF")
	},
	{
		"id": "hakone_snow",
		"chapter": "CHAPTER 03 // 箱根",
		"stage": "STAGE 3",
		"title": "HAKONE SNOW",
		"kanji_stamp": "箱根 // ALPINE DAWN",
		"time": "06:30 DAWN",
		"sub": "Alpine Dawn Pass · 205 KM/H · 1.5x",
		"caption": "CRISP ALPINE DAWN OVER HAKONE PASS. FRESH SNOW CAPS COMPOUND PINES AS ROSE-GOLD LIGHT BREAKS ACROSS PEAKS...",
		"accent": Color("#BAE6FD")
	},
	{
		"id": "enoshima_coast",
		"chapter": "CHAPTER 04 // 江の島",
		"stage": "STAGE 4",
		"title": "ENOSHIMA COAST",
		"kanji_stamp": "江ノ島 // SEASIDE FLOW",
		"time": "16:30 AFTERNOON",
		"sub": "Golden Afternoon Ocean · 225 KM/H · 2.0x",
		"caption": "GOLDEN AFTERNOON ON SHONAN COASTLINE. PALMS SWAY IN PACIFIC WINDS AS WAVES BREAK BENEATH A RETRO SUN...",
		"accent": Color("#FDE68A")
	}
]

var current_page_idx: int = 0
var is_flipping: bool = false
var is_launching: bool = false

# UI Nodes
var page_root: Control
var header_chapter_lbl: Label
var header_title_lbl: Label
var header_meta_lbl: Label

# Live 3D Panel Viewport Textures & Materials
var top_rect: TextureRect
var top_mat: ShaderMaterial
var top_stamp_lbl: Label
var top_stamp_box: Control

var hero_panel_root: Control
var hero_rect: TextureRect
var hero_mat: ShaderMaterial
var hero_caption_lbl: Label
var hero_border: ReferenceRect

var cockpit_cutin: Control

var wheel_rect: TextureRect
var wheel_mat: ShaderMaterial

# Page Curl Transition Overlay
var curl_overlay: ColorRect
var curl_mat: ShaderMaterial
var curled_corner_btn: Button

# DRIVE Button & Subtitles
var drive_btn: Button
var hint_lbl: Label

# Swipe tracking
var swipe_start_x: float = 0.0
var is_swiping: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(1080, 1920)
	size = Vector2(1080, 1920)
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS

	_build_comic_page_ui()
	_update_page_content(current_page_idx)

func set_current_biome(b_id: String) -> void:
	for i in range(BIOME_PAGES.size()):
		if BIOME_PAGES[i]["id"] == b_id:
			current_page_idx = i
			_update_page_content(current_page_idx)
			return

func get_current_biome_id() -> String:
	return BIOME_PAGES[current_page_idx]["id"]

# Connect external SubViewport camera textures into panels
func set_viewport_textures(top_tex: Texture2D, hero_tex: Texture2D, wheel_tex: Texture2D) -> void:
	if is_instance_valid(top_rect) and top_tex:
		top_rect.texture = top_tex
	if is_instance_valid(hero_rect) and hero_tex:
		hero_rect.texture = hero_tex
	if is_instance_valid(wheel_rect) and wheel_tex:
		wheel_rect.texture = wheel_tex

func _build_comic_page_ui() -> void:
	# 1. Main Page Root Container
	page_root = Control.new()
	page_root.name = "MangaPageSpread"
	page_root.set_anchors_preset(PRESET_FULL_RECT)
	page_root.mouse_filter = MOUSE_FILTER_PASS
	add_child(page_root)

	# 2. Warm Vintage Manga Paper Canvas (#F3EFE6)
	var paper_bg := ColorRect.new()
	paper_bg.set_anchors_preset(PRESET_FULL_RECT)
	paper_bg.color = PAPER_COLOR
	paper_bg.mouse_filter = MOUSE_FILTER_IGNORE
	page_root.add_child(paper_bg)

	# 3. Stacked Comic Book Page Edges along Right Margin (Physical Tankobon Depth)
	var book_edge := Control.new()
	book_edge.position = Vector2(1062, 0)
	book_edge.size = Vector2(18, 1920)
	book_edge.mouse_filter = MOUSE_FILTER_IGNORE
	page_root.add_child(book_edge)

	for i in range(5):
		var page_line := ColorRect.new()
		page_line.position = Vector2(float(i * 3 + 2), 0)
		page_line.size = Vector2(1.5, 1920)
		page_line.color = Color(0.20, 0.22, 0.26, 0.45 if i == 0 else 0.25)
		book_edge.add_child(page_line)

	# 4. Bold 5px Black Ink Outer Border (#0B0D12)
	var outer_border := ReferenceRect.new()
	outer_border.position = Vector2(14, 14)
	outer_border.size = Vector2(1052, 1892)
	outer_border.border_color = INK_COLOR
	outer_border.border_width = 5.0
	outer_border.editor_only = false
	outer_border.mouse_filter = MOUSE_FILTER_IGNORE
	page_root.add_child(outer_border)

	# 5. Header / Tankobon Chapter Stamp Bar
	var header_bar := Control.new()
	header_bar.position = Vector2(24, 20)
	header_bar.size = Vector2(1032, 54)
	header_bar.mouse_filter = MOUSE_FILTER_IGNORE
	page_root.add_child(header_bar)

	header_chapter_lbl = Label.new()
	header_chapter_lbl.position = Vector2(6, 6)
	header_chapter_lbl.size = Vector2(360, 26)
	header_chapter_lbl.add_theme_font_size_override("font_size", 16)
	header_chapter_lbl.add_theme_color_override("font_color", INK_COLOR)
	header_bar.add_child(header_chapter_lbl)

	header_title_lbl = Label.new()
	header_title_lbl.position = Vector2(360, 4)
	header_title_lbl.size = Vector2(360, 32)
	header_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_title_lbl.add_theme_font_size_override("font_size", 22)
	header_title_lbl.add_theme_color_override("font_color", INK_COLOR)
	header_bar.add_child(header_title_lbl)

	header_meta_lbl = Label.new()
	header_meta_lbl.position = Vector2(720, 6)
	header_meta_lbl.size = Vector2(306, 26)
	header_meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_meta_lbl.add_theme_font_size_override("font_size", 14)
	header_meta_lbl.add_theme_color_override("font_color", Color(0.35, 0.38, 0.44))
	header_bar.add_child(header_meta_lbl)

	var header_sep := ColorRect.new()
	header_sep.position = Vector2(0, 44)
	header_sep.size = Vector2(1032, 2.5)
	header_sep.color = INK_COLOR
	header_bar.add_child(header_sep)

	# Preload Shaders
	var bw_shader: Shader = preload("res://shaders/manga_bw_panel.gdshader")

	# ==========================================================================
	# PANEL 1: TOP ESTABLISHING PANEL (LIVE 3D PANORAMA CAM)
	# ==========================================================================
	var p1_root := Control.new()
	p1_root.name = "Panel1_Panorama"
	p1_root.position = Vector2(28, 76)
	p1_root.size = Vector2(1024, 430)
	p1_root.clip_contents = true
	p1_root.mouse_filter = MOUSE_FILTER_PASS
	page_root.add_child(p1_root)

	# Outer White Gutter & Black Ink Border
	var p1_gutter := ColorRect.new()
	p1_gutter.set_anchors_preset(PRESET_FULL_RECT)
	p1_gutter.color = GUTTER_COLOR
	p1_root.add_child(p1_gutter)

	top_rect = TextureRect.new()
	top_rect.position = Vector2(8, 8)
	top_rect.size = Vector2(1008, 414)
	top_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	top_rect.mouse_filter = MOUSE_FILTER_IGNORE

	top_mat = ShaderMaterial.new()
	top_mat.shader = bw_shader
	top_mat.set_shader_parameter("bw_ink_mix", 1.0)
	top_mat.set_shader_parameter("halftone_scale", 0.65)
	top_rect.material = top_mat
	p1_root.add_child(top_rect)

	var p1_border := ReferenceRect.new()
	p1_border.set_anchors_preset(PRESET_FULL_RECT)
	p1_border.border_color = INK_COLOR
	p1_border.border_width = 4.0
	p1_border.editor_only = false
	p1_border.mouse_filter = MOUSE_FILTER_IGNORE
	p1_root.add_child(p1_border)

	# Bold Vertical Japanese Biome Stamp Ribbon (Top-Right)
	top_stamp_box = Control.new()
	top_stamp_box.position = Vector2(810, 16)
	top_stamp_box.size = Vector2(190, 48)
	p1_root.add_child(top_stamp_box)

	var stamp_bg := ColorRect.new()
	stamp_bg.set_anchors_preset(PRESET_FULL_RECT)
	stamp_bg.color = INK_COLOR
	top_stamp_box.add_child(stamp_bg)

	var stamp_border := ReferenceRect.new()
	stamp_border.set_anchors_preset(PRESET_FULL_RECT)
	stamp_border.border_color = GUTTER_COLOR
	stamp_border.border_width = 2.0
	stamp_border.editor_only = false
	top_stamp_box.add_child(stamp_border)

	top_stamp_lbl = Label.new()
	top_stamp_lbl.set_anchors_preset(PRESET_FULL_RECT)
	top_stamp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_stamp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_stamp_lbl.add_theme_font_size_override("font_size", 16)
	top_stamp_lbl.add_theme_color_override("font_color", GUTTER_COLOR)
	top_stamp_box.add_child(top_stamp_lbl)

	# ==========================================================================
	# PANEL 2: CENTER HERO ACTION PANEL (LIVE 3D MAIN CHASE CAM)
	# ==========================================================================
	hero_panel_root = Control.new()
	hero_panel_root.name = "Panel2_HeroAction"
	hero_panel_root.position = Vector2(28, 520)
	hero_panel_root.size = Vector2(1024, 760)
	hero_panel_root.pivot_offset = Vector2(512, 380)
	hero_panel_root.clip_contents = true
	hero_panel_root.mouse_filter = MOUSE_FILTER_PASS
	page_root.add_child(hero_panel_root)

	var p2_gutter := ColorRect.new()
	p2_gutter.set_anchors_preset(PRESET_FULL_RECT)
	p2_gutter.color = GUTTER_COLOR
	hero_panel_root.add_child(p2_gutter)

	hero_rect = TextureRect.new()
	hero_rect.position = Vector2(8, 8)
	hero_rect.size = Vector2(1008, 744)
	hero_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_rect.mouse_filter = MOUSE_FILTER_IGNORE

	hero_mat = ShaderMaterial.new()
	hero_mat.shader = bw_shader
	hero_mat.set_shader_parameter("bw_ink_mix", 1.0)
	hero_mat.set_shader_parameter("wipe_radius", 0.0)
	hero_mat.set_shader_parameter("halftone_scale", 0.50)
	hero_rect.material = hero_mat
	hero_panel_root.add_child(hero_rect)

	hero_border = ReferenceRect.new()
	hero_border.set_anchors_preset(PRESET_FULL_RECT)
	hero_border.border_color = INK_COLOR
	hero_border.border_width = 4.0
	hero_border.editor_only = false
	hero_border.mouse_filter = MOUSE_FILTER_IGNORE
	hero_panel_root.add_child(hero_border)

	# Narrator Manga Caption Box (Top-Left of Hero Panel)
	var caption_box := Control.new()
	caption_box.position = Vector2(20, 18)
	caption_box.size = Vector2(540, 68)
	hero_panel_root.add_child(caption_box)

	var cap_bg := ColorRect.new()
	cap_bg.set_anchors_preset(PRESET_FULL_RECT)
	cap_bg.color = Color(0.05, 0.06, 0.09, 0.88)
	caption_box.add_child(cap_bg)

	var cap_border := ReferenceRect.new()
	cap_border.set_anchors_preset(PRESET_FULL_RECT)
	cap_border.border_color = GUTTER_COLOR
	cap_border.border_width = 2.0
	cap_border.editor_only = false
	caption_box.add_child(cap_border)

	hero_caption_lbl = Label.new()
	hero_caption_lbl.position = Vector2(12, 8)
	hero_caption_lbl.size = Vector2(516, 52)
	hero_caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_caption_lbl.add_theme_font_size_override("font_size", 13)
	hero_caption_lbl.add_theme_color_override("font_color", GUTTER_COLOR)
	caption_box.add_child(hero_caption_lbl)

	# Click Trigger on Hero Panel -> Launch!
	var hero_click := Button.new()
	hero_click.set_anchors_preset(PRESET_FULL_RECT)
	hero_click.flat = true
	hero_click.focus_mode = FOCUS_NONE
	hero_click.mouse_filter = MOUSE_FILTER_STOP
	hero_click.pressed.connect(func(): _on_launch_pressed())
	hero_panel_root.add_child(hero_click)

	# ==========================================================================
	# PANEL 3: BOTTOM-LEFT COCKPIT CUT-IN (PROCEDURAL 2D VECTOR INK)
	# ==========================================================================
	var p3_root := Control.new()
	p3_root.name = "Panel3_Cockpit"
	p3_root.position = Vector2(28, 1294)
	p3_root.size = Vector2(504, 436)
	p3_root.clip_contents = true
	p3_root.mouse_filter = MOUSE_FILTER_PASS
	page_root.add_child(p3_root)

	cockpit_cutin = CockpitCutIn.new()
	cockpit_cutin.position = Vector2(0, 0)
	cockpit_cutin.size = Vector2(504, 436)
	p3_root.add_child(cockpit_cutin)

	# ==========================================================================
	# PANEL 4: BOTTOM-RIGHT WHEEL/TAILLIGHT CUT-IN (LIVE 3D WHEEL CLOSE CAM)
	# ==========================================================================
	var p4_root := Control.new()
	p4_root.name = "Panel4_WheelClose"
	p4_root.position = Vector2(548, 1294)
	p4_root.size = Vector2(504, 436)
	p4_root.clip_contents = true
	p4_root.mouse_filter = MOUSE_FILTER_PASS
	page_root.add_child(p4_root)

	var p4_gutter := ColorRect.new()
	p4_gutter.set_anchors_preset(PRESET_FULL_RECT)
	p4_gutter.color = GUTTER_COLOR
	p4_root.add_child(p4_gutter)

	wheel_rect = TextureRect.new()
	wheel_rect.position = Vector2(8, 8)
	wheel_rect.size = Vector2(488, 420)
	wheel_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wheel_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wheel_rect.mouse_filter = MOUSE_FILTER_IGNORE

	wheel_mat = ShaderMaterial.new()
	wheel_mat.shader = bw_shader
	wheel_mat.set_shader_parameter("bw_ink_mix", 1.0)
	wheel_mat.set_shader_parameter("halftone_scale", 0.60)
	wheel_rect.material = wheel_mat
	p4_root.add_child(wheel_rect)

	var p4_border := ReferenceRect.new()
	p4_border.set_anchors_preset(PRESET_FULL_RECT)
	p4_border.border_color = INK_COLOR
	p4_border.border_width = 4.0
	p4_border.editor_only = false
	p4_border.mouse_filter = MOUSE_FILTER_IGNORE
	p4_root.add_child(p4_border)

	# Wheel Traction Stamp (Bottom of Panel 4)
	var traction_pill := Control.new()
	traction_pill.position = Vector2(16, 386)
	traction_pill.size = Vector2(230, 32)
	p4_root.add_child(traction_pill)

	var tr_bg := ColorRect.new()
	tr_bg.set_anchors_preset(PRESET_FULL_RECT)
	tr_bg.color = INK_COLOR
	traction_pill.add_child(tr_bg)

	var tr_lbl := Label.new()
	tr_lbl.set_anchors_preset(PRESET_FULL_RECT)
	tr_lbl.text = "REAR TRACTION // 100%"
	tr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tr_lbl.add_theme_font_size_override("font_size", 12)
	tr_lbl.add_theme_color_override("font_color", GUTTER_COLOR)
	traction_pill.add_child(tr_lbl)

	# ==========================================================================
	# BOTTOM ACTION BAR: MANGA "DRIVE >>" STAMP & REALISTIC CURLED CORNER
	# ==========================================================================
	var bottom_bar := Control.new()
	bottom_bar.position = Vector2(28, 1744)
	bottom_bar.size = Vector2(1024, 150)
	bottom_bar.mouse_filter = MOUSE_FILTER_PASS
	page_root.add_child(bottom_bar)

	# Bold Yellow Manga DRIVE Action Stamp
	drive_btn = Button.new()
	drive_btn.text = "DRIVE  >>"
	drive_btn.position = Vector2(232, 14)
	drive_btn.size = Vector2(560, 78)
	drive_btn.focus_mode = FOCUS_NONE
	drive_btn.mouse_filter = MOUSE_FILTER_STOP
	drive_btn.add_theme_font_size_override("font_size", 38)
	drive_btn.add_theme_color_override("font_color", INK_COLOR)

	var drive_style := StyleBoxFlat.new()
	drive_style.bg_color = Color("#FFD000")
	drive_style.set_corner_radius_all(6)
	drive_style.border_width_left = 4
	drive_style.border_width_top = 4
	drive_style.border_width_right = 4
	drive_style.border_width_bottom = 4
	drive_style.border_color = INK_COLOR
	drive_style.shadow_size = 6
	drive_style.shadow_offset = Vector2(5, 5)
	drive_style.shadow_color = Color(0.05, 0.06, 0.09, 0.9)
	drive_btn.add_theme_stylebox_override("normal", drive_style)

	var drive_hover := drive_style.duplicate() as StyleBoxFlat
	drive_hover.bg_color = Color("#FFE54C")
	drive_btn.add_theme_stylebox_override("hover", drive_hover)

	drive_btn.pressed.connect(func(): _on_launch_pressed())
	bottom_bar.add_child(drive_btn)

	# Gentle inviting pulse on DRIVE button
	var tw_drive := create_tween().set_loops()
	tw_drive.tween_property(drive_btn, "scale", Vector2(1.025, 1.025), 0.75).set_trans(Tween.TRANS_SINE)
	tw_drive.tween_property(drive_btn, "scale", Vector2(1.0, 1.0), 0.75).set_trans(Tween.TRANS_SINE)
	drive_btn.pivot_offset = Vector2(280, 39)

	hint_lbl = Label.new()
	hint_lbl.text = "TAP HERO PANEL TO DIVE IN  ·  SWIPE OR TAP CORNER TO TURN PAGE"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.position = Vector2(0, 100)
	hint_lbl.size = Vector2(1024, 30)
	hint_lbl.add_theme_font_size_override("font_size", 16)
	hint_lbl.add_theme_color_override("font_color", Color(0.35, 0.38, 0.44))
	hint_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	bottom_bar.add_child(hint_lbl)

	# Realistic Folded/Curled Paper Corner in Bottom-Right
	curled_corner_btn = Button.new()
	curled_corner_btn.name = "CurledCorner"
	curled_corner_btn.position = Vector2(880, 20)
	curled_corner_btn.size = Vector2(130, 95)
	curled_corner_btn.flat = true
	curled_corner_btn.focus_mode = FOCUS_NONE
	curled_corner_btn.mouse_filter = MOUSE_FILTER_STOP
	curled_corner_btn.pressed.connect(func(): flip_next_page())
	bottom_bar.add_child(curled_corner_btn)

	var curl_draw := Control.new()
	curl_draw.set_anchors_preset(PRESET_FULL_RECT)
	curl_draw.mouse_filter = MOUSE_FILTER_IGNORE
	curled_corner_btn.add_child(curl_draw)
	curl_draw.draw.connect(func():
		var cw: float = 130.0
		var ch: float = 95.0
		# Drop shadow underneath curl flap
		var shadow_poly := PackedVector2Array([Vector2(0, ch), Vector2(cw, 0), Vector2(cw, ch)])
		curl_draw.draw_colored_polygon(shadow_poly, Color(0.04, 0.05, 0.08, 0.40))
		# Curled flap (triangle lifted from corner)
		var flap_poly := PackedVector2Array([Vector2(12, ch), Vector2(cw, 10), Vector2(cw - 40, ch - 40)])
		curl_draw.draw_colored_polygon(flap_poly, Color("#EDE7D8"))
		curl_draw.draw_line(Vector2(12, ch), Vector2(cw, 10), INK_COLOR, 3.0)
		var font := ThemeDB.fallback_font
		if is_instance_valid(font):
			curl_draw.draw_string(font, Vector2(cw * 0.35, ch * 0.72), "PAGE ⮞", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, INK_COLOR)
	)

	# 6. Page Curl Transition Full-Screen Overlay
	var curl_shader: Shader = preload("res://shaders/manga_page_curl.gdshader")
	curl_overlay = ColorRect.new()
	curl_overlay.name = "PageCurlOverlay"
	curl_overlay.set_anchors_preset(PRESET_FULL_RECT)
	curl_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	curl_overlay.visible = false

	curl_mat = ShaderMaterial.new()
	curl_mat.shader = curl_shader
	curl_mat.set_shader_parameter("progress", 0.0)
	curl_overlay.material = curl_mat
	add_child(curl_overlay)

func _update_page_content(idx: int) -> void:
	if idx < 0 or idx >= BIOME_PAGES.size():
		return
	var page: Dictionary = BIOME_PAGES[idx]

	if is_instance_valid(header_chapter_lbl):
		header_chapter_lbl.text = page["chapter"]
	if is_instance_valid(header_title_lbl):
		header_title_lbl.text = page["title"]
	if is_instance_valid(header_meta_lbl):
		header_meta_lbl.text = page["sub"]
	if is_instance_valid(top_stamp_lbl):
		top_stamp_lbl.text = "【 " + page["kanji_stamp"] + " 】"
	if is_instance_valid(hero_caption_lbl):
		hero_caption_lbl.text = page["caption"]
	if is_instance_valid(cockpit_cutin):
		cockpit_cutin.set_biome(page["id"])

# ==============================================================================
# PAGE TURN & HORIZONTAL SWIPE
# ==============================================================================
func flip_next_page() -> void:
	if is_flipping or is_launching:
		return
	var next_idx: int = (current_page_idx + 1) % BIOME_PAGES.size()
	_play_page_turn(next_idx)

func flip_prev_page() -> void:
	if is_flipping or is_launching:
		return
	var prev_idx: int = (current_page_idx - 1 + BIOME_PAGES.size()) % BIOME_PAGES.size()
	_play_page_turn(prev_idx)

func _play_page_turn(target_idx: int) -> void:
	is_flipping = true
	current_page_idx = target_idx
	var next_id: String = BIOME_PAGES[current_page_idx]["id"]

	# Notify coordinator to switch 3D world to next biome
	page_flip_requested.emit(next_id)

	# 0.4s Realistic Page Peel Curl Animation
	if is_instance_valid(curl_overlay) and is_instance_valid(curl_mat):
		curl_overlay.visible = true
		curl_mat.set_shader_parameter("progress", 0.0)
		var tw := create_tween()
		tw.tween_method(func(val: float): curl_mat.set_shader_parameter("progress", val), 0.0, 1.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			_update_page_content(current_page_idx)
			curl_overlay.visible = false
			curl_mat.set_shader_parameter("progress", 0.0)
			is_flipping = false
		)
	else:
		_update_page_content(current_page_idx)
		is_flipping = false

func _gui_input(event: InputEvent) -> void:
	if is_flipping or is_launching:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start_x = event.position.x
			is_swiping = true
		else:
			is_swiping = false
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			swipe_start_x = event.position.x
			is_swiping = true
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			is_swiping = false
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and is_swiping):
		var diff: float = event.position.x - swipe_start_x
		if abs(diff) > 48.0:
			is_swiping = false
			if diff < 0.0:
				flip_next_page()
			else:
				flip_prev_page()

# ==============================================================================
# SEAMLESS "DIVE INTO THE PANEL" B&W-TO-COLOR LAUNCH TRANSITION
# ==============================================================================
func _on_launch_pressed() -> void:
	if is_launching or is_flipping:
		return
	launch_requested.emit(BIOME_PAGES[current_page_idx]["id"])

func play_dive_in_transition(callback: Callable) -> void:
	if is_launching:
		return
	is_launching = true

	# 1. Expand the Center Hero Action Panel (scale 1.0x -> 3.2x over 0.55s)
	# Center panel overflows the viewport seamlessly into full-screen driving
	var tw_hero := create_tween().set_parallel(true)
	tw_hero.tween_property(hero_panel_root, "scale", Vector2(3.2, 3.2), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# 2. Animate B&W ink mix -> 0.0 in radial wipe (pure B&W manga page -> vibrant 3D colors)
	if is_instance_valid(hero_mat):
		tw_hero.tween_method(func(val: float): hero_mat.set_shader_parameter("bw_ink_mix", val), 1.0, 0.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw_hero.tween_method(func(val: float): hero_mat.set_shader_parameter("wipe_radius", val), 0.0, 2.5, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 3. Surrounding panels & page elements slide/fade outward
	var top_node := page_root.get_node_or_null("Panel1_Panorama")
	var cockpit_node := page_root.get_node_or_null("Panel3_Cockpit")
	var wheel_node := page_root.get_node_or_null("Panel4_WheelClose")

	if is_instance_valid(top_node):
		tw_hero.tween_property(top_node, "position:y", -500.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_hero.tween_property(top_node, "modulate:a", 0.0, 0.35)
	if is_instance_valid(cockpit_node):
		tw_hero.tween_property(cockpit_node, "position:x", -600.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_hero.tween_property(cockpit_node, "modulate:a", 0.0, 0.35)
	if is_instance_valid(wheel_node):
		tw_hero.tween_property(wheel_node, "position:x", 1200.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_hero.tween_property(wheel_node, "modulate:a", 0.0, 0.35)
	if is_instance_valid(drive_btn):
		tw_hero.tween_property(drive_btn, "modulate:a", 0.0, 0.25)
	if is_instance_valid(hint_lbl):
		tw_hero.tween_property(hint_lbl, "modulate:a", 0.0, 0.25)

	# 4. On finish: call completion callback
	var seq := create_tween()
	seq.tween_interval(0.55)
	seq.tween_callback(func():
		if callback.is_valid():
			callback.call()
	)
