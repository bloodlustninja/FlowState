class_name MangaComicPage
extends Control

const CockpitCutInScript = preload("res://ui/CockpitCutIn.gd")

# ==============================================================================
# FLOWSTATE: FULL-SCREEN DRAGGABLE MANGA COMIC-BOOK START SPREAD
# - Truly full-screen (edge-to-edge 0px margins, responsive to any screen aspect)
# - 25% Color + 75% Manga Ink (bw_ink_mix = 0.75 for retro colored-manga print look)
# - 1:1 Real-time touch/mouse draggable & swipable page turns (no corner button!)
# - 4-Panel diagonal manga layout with live 3D viewports and vector cockpit art
# - Seamless "Dive Into The Panel" zoom transition into 3D gameplay
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

# UI Hierarchy Nodes
var paper_bg: ColorRect
var page_root: Control
var header_bar: Control
var header_chapter_lbl: Label
var header_title_lbl: Label
var header_meta_lbl: Label
var header_sep: ColorRect

# Live 3D Panel Viewports & Shaders (25% Color)
var p1_root: Control
var top_rect: TextureRect
var top_mat: ShaderMaterial
var p1_border: ReferenceRect
var top_stamp_box: Control
var top_stamp_lbl: Label

var hero_panel_root: Control
var hero_rect: TextureRect
var hero_mat: ShaderMaterial
var hero_border: ReferenceRect
var caption_box: Control
var hero_caption_lbl: Label

var p3_root: Control
var cockpit_cutin: Control

var p4_root: Control
var wheel_rect: TextureRect
var wheel_mat: ShaderMaterial
var p4_border: ReferenceRect
var traction_pill: Control
var tr_lbl: Label

# Bottom Action Bar & Pips
var bottom_bar: Control
var bot_bg: ColorRect
var bot_line: ColorRect
var pips_container: HBoxContainer
var pip_buttons: Array[Button] = []
var drive_btn: Button
var hint_lbl: Label

# 1:1 Interactive Touch / Mouse Dragging System
var is_dragging: bool = false
var is_drag_gesture: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_last_pos: Vector2 = Vector2.ZERO
var drag_start_time: float = 0.0
var drag_velocity_x: float = 0.0

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS

	_build_comic_page_ui()
	_layout_panels()
	_update_page_content(current_page_idx)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_panels()

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

# ==============================================================================
# UI CONSTRUCTION (EDGE-TO-EDGE FULL SCREEN)
# ==============================================================================
func _build_comic_page_ui() -> void:
	# 1. Warm Vintage Manga Paper Background Canvas (Full Viewport)
	paper_bg = ColorRect.new()
	paper_bg.set_anchors_preset(PRESET_FULL_RECT)
	paper_bg.color = PAPER_COLOR
	paper_bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(paper_bg)

	# 2. Main Draggable Page Root
	page_root = Control.new()
	page_root.name = "MangaPageSpread"
	page_root.set_anchors_preset(PRESET_FULL_RECT)
	page_root.mouse_filter = MOUSE_FILTER_PASS
	add_child(page_root)

	# 3. Header / Tankobon Chapter Stamp Bar
	header_bar = Control.new()
	header_bar.name = "HeaderBar"
	header_bar.mouse_filter = MOUSE_FILTER_IGNORE
	page_root.add_child(header_bar)

	header_chapter_lbl = Label.new()
	header_chapter_lbl.add_theme_font_size_override("font_size", 16)
	header_chapter_lbl.add_theme_color_override("font_color", INK_COLOR)
	header_bar.add_child(header_chapter_lbl)

	header_title_lbl = Label.new()
	header_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_title_lbl.add_theme_font_size_override("font_size", 22)
	header_title_lbl.add_theme_color_override("font_color", INK_COLOR)
	header_bar.add_child(header_title_lbl)

	header_meta_lbl = Label.new()
	header_meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_meta_lbl.add_theme_font_size_override("font_size", 14)
	header_meta_lbl.add_theme_color_override("font_color", Color(0.35, 0.38, 0.44))
	header_bar.add_child(header_meta_lbl)

	header_sep = ColorRect.new()
	header_sep.color = INK_COLOR
	header_bar.add_child(header_sep)

	# Preload 25% Color Manga Shader
	var bw_shader: Shader = preload("res://shaders/manga_bw_panel.gdshader")

	# ==========================================================================
	# PANEL 1: TOP ESTABLISHING PANEL (LIVE 3D PANORAMA CAM)
	# ==========================================================================
	p1_root = Control.new()
	p1_root.name = "Panel1_Panorama"
	p1_root.clip_contents = true
	p1_root.mouse_filter = MOUSE_FILTER_PASS
	page_root.add_child(p1_root)

	var p1_gutter := ColorRect.new()
	p1_gutter.set_anchors_preset(PRESET_FULL_RECT)
	p1_gutter.color = GUTTER_COLOR
	p1_root.add_child(p1_gutter)

	top_rect = TextureRect.new()
	top_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	top_rect.mouse_filter = MOUSE_FILTER_IGNORE

	top_mat = ShaderMaterial.new()
	top_mat.shader = bw_shader
	top_mat.set_shader_parameter("bw_ink_mix", 0.75) # 25% Color + 75% Manga Ink
	top_mat.set_shader_parameter("halftone_scale", 0.65)
	top_rect.material = top_mat
	p1_root.add_child(top_rect)

	p1_border = ReferenceRect.new()
	p1_border.set_anchors_preset(PRESET_FULL_RECT)
	p1_border.border_color = INK_COLOR
	p1_border.border_width = 4.0
	p1_border.editor_only = false
	p1_border.mouse_filter = MOUSE_FILTER_IGNORE
	p1_root.add_child(p1_border)

	# Biome Stamp Ribbon (Top-Right)
	top_stamp_box = Control.new()
	top_stamp_box.size = Vector2(210, 40)
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
	top_stamp_lbl.add_theme_font_size_override("font_size", 14)
	top_stamp_lbl.add_theme_color_override("font_color", GUTTER_COLOR)
	top_stamp_box.add_child(top_stamp_lbl)

	# ==========================================================================
	# PANEL 2: CENTER HERO ACTION PANEL (LIVE 3D MAIN CHASE CAM)
	# ==========================================================================
	hero_panel_root = Control.new()
	hero_panel_root.name = "Panel2_HeroAction"
	hero_panel_root.clip_contents = true
	hero_panel_root.mouse_filter = MOUSE_FILTER_PASS
	page_root.add_child(hero_panel_root)

	var p2_gutter := ColorRect.new()
	p2_gutter.set_anchors_preset(PRESET_FULL_RECT)
	p2_gutter.color = GUTTER_COLOR
	hero_panel_root.add_child(p2_gutter)

	hero_rect = TextureRect.new()
	hero_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_rect.mouse_filter = MOUSE_FILTER_IGNORE

	hero_mat = ShaderMaterial.new()
	hero_mat.shader = bw_shader
	hero_mat.set_shader_parameter("bw_ink_mix", 0.75) # 25% Color + 75% Manga Ink
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
	caption_box = Control.new()
	caption_box.position = Vector2(16, 12)
	caption_box.size = Vector2(500, 64)
	hero_panel_root.add_child(caption_box)

	var cap_bg := ColorRect.new()
	cap_bg.set_anchors_preset(PRESET_FULL_RECT)
	cap_bg.color = Color(0.05, 0.06, 0.09, 0.90)
	caption_box.add_child(cap_bg)

	var cap_border := ReferenceRect.new()
	cap_border.set_anchors_preset(PRESET_FULL_RECT)
	cap_border.border_color = GUTTER_COLOR
	cap_border.border_width = 2.0
	cap_border.editor_only = false
	caption_box.add_child(cap_border)

	hero_caption_lbl = Label.new()
	hero_caption_lbl.position = Vector2(12, 6)
	hero_caption_lbl.size = Vector2(476, 52)
	hero_caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_caption_lbl.add_theme_font_size_override("font_size", 13)
	hero_caption_lbl.add_theme_color_override("font_color", GUTTER_COLOR)
	caption_box.add_child(hero_caption_lbl)

	# Tap Trigger on Hero Panel -> Launch into race
	var hero_click := Button.new()
	hero_click.set_anchors_preset(PRESET_FULL_RECT)
	hero_click.flat = true
	hero_click.focus_mode = FOCUS_NONE
	hero_click.mouse_filter = MOUSE_FILTER_STOP
	hero_click.pressed.connect(func():
		if not is_drag_gesture:
			_on_launch_pressed()
	)
	hero_panel_root.add_child(hero_click)

	# ==========================================================================
	# PANEL 3: BOTTOM-LEFT COCKPIT CUT-IN (PROCEDURAL 2D VECTOR INK + 25% WASH)
	# ==========================================================================
	p3_root = Control.new()
	p3_root.name = "Panel3_Cockpit"
	p3_root.clip_contents = true
	p3_root.mouse_filter = MOUSE_FILTER_PASS
	page_root.add_child(p3_root)

	cockpit_cutin = CockpitCutInScript.new()
	p3_root.add_child(cockpit_cutin)

	# ==========================================================================
	# PANEL 4: BOTTOM-RIGHT WHEEL/TAILLIGHT CUT-IN (LIVE 3D WHEEL CLOSE CAM)
	# ==========================================================================
	p4_root = Control.new()
	p4_root.name = "Panel4_WheelClose"
	p4_root.clip_contents = true
	p4_root.mouse_filter = MOUSE_FILTER_PASS
	page_root.add_child(p4_root)

	var p4_gutter := ColorRect.new()
	p4_gutter.set_anchors_preset(PRESET_FULL_RECT)
	p4_gutter.color = GUTTER_COLOR
	p4_root.add_child(p4_gutter)

	wheel_rect = TextureRect.new()
	wheel_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wheel_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wheel_rect.mouse_filter = MOUSE_FILTER_IGNORE

	wheel_mat = ShaderMaterial.new()
	wheel_mat.shader = bw_shader
	wheel_mat.set_shader_parameter("bw_ink_mix", 0.75) # 25% Color + 75% Manga Ink
	wheel_mat.set_shader_parameter("halftone_scale", 0.60)
	wheel_rect.material = wheel_mat
	p4_root.add_child(wheel_rect)

	p4_border = ReferenceRect.new()
	p4_border.set_anchors_preset(PRESET_FULL_RECT)
	p4_border.border_color = INK_COLOR
	p4_border.border_width = 4.0
	p4_border.editor_only = false
	p4_border.mouse_filter = MOUSE_FILTER_IGNORE
	p4_root.add_child(p4_border)

	traction_pill = Control.new()
	traction_pill.size = Vector2(200, 28)
	p4_root.add_child(traction_pill)

	var tr_bg := ColorRect.new()
	tr_bg.set_anchors_preset(PRESET_FULL_RECT)
	tr_bg.color = INK_COLOR
	traction_pill.add_child(tr_bg)

	tr_lbl = Label.new()
	tr_lbl.set_anchors_preset(PRESET_FULL_RECT)
	tr_lbl.text = "REAR TRACTION // 100%"
	tr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tr_lbl.add_theme_font_size_override("font_size", 12)
	tr_lbl.add_theme_color_override("font_color", GUTTER_COLOR)
	traction_pill.add_child(tr_lbl)

	# ==========================================================================
	# BOTTOM ACTION BAR: CHAPTER INDICATOR PIPS & DRIVE BUTTON (NO CORNER BUTTON)
	# ==========================================================================
	bottom_bar = Control.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.mouse_filter = MOUSE_FILTER_PASS
	page_root.add_child(bottom_bar)

	bot_bg = ColorRect.new()
	bot_bg.name = "BottomBarBg"
	bot_bg.set_anchors_preset(PRESET_FULL_RECT)
	bot_bg.color = PAPER_COLOR
	bot_bg.mouse_filter = MOUSE_FILTER_IGNORE
	bottom_bar.add_child(bot_bg)

	bot_line = ColorRect.new()
	bot_line.name = "BottomBarBorder"
	bot_line.color = INK_COLOR
	bot_line.mouse_filter = MOUSE_FILTER_IGNORE
	bottom_bar.add_child(bot_line)

	# Chapter Indicator Pips (● ○ ○ ○)
	pips_container = HBoxContainer.new()
	pips_container.alignment = BoxContainer.ALIGNMENT_CENTER
	pips_container.add_theme_constant_override("separation", 14)
	bottom_bar.add_child(pips_container)

	for i in range(BIOME_PAGES.size()):
		var pip := Button.new()
		pip.custom_minimum_size = Vector2(14, 14)
		pip.focus_mode = FOCUS_NONE
		pip.mouse_filter = MOUSE_FILTER_STOP
		var page_num: int = i
		pip.pressed.connect(func():
			if not is_drag_gesture:
				_go_to_page(page_num)
		)
		pips_container.add_child(pip)
		pip_buttons.append(pip)

	# Bold Yellow Manga DRIVE Action Stamp
	drive_btn = Button.new()
	drive_btn.text = "DRIVE  >>"
	drive_btn.focus_mode = FOCUS_NONE
	drive_btn.mouse_filter = MOUSE_FILTER_STOP
	drive_btn.add_theme_font_size_override("font_size", 36)
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
	drive_style.shadow_offset = Vector2(4, 4)
	drive_style.shadow_color = Color(0.05, 0.06, 0.09, 0.9)
	drive_btn.add_theme_stylebox_override("normal", drive_style)

	var drive_hover := drive_style.duplicate() as StyleBoxFlat
	drive_hover.bg_color = Color("#FFE54C")
	drive_btn.add_theme_stylebox_override("hover", drive_hover)

	drive_btn.pressed.connect(func():
		if not is_drag_gesture:
			_on_launch_pressed()
	)
	bottom_bar.add_child(drive_btn)

	var tw_drive := create_tween().set_loops()
	tw_drive.tween_property(drive_btn, "scale", Vector2(1.025, 1.025), 0.75).set_trans(Tween.TRANS_SINE)
	tw_drive.tween_property(drive_btn, "scale", Vector2(1.0, 1.0), 0.75).set_trans(Tween.TRANS_SINE)

	hint_lbl = Label.new()
	hint_lbl.text = "◀  DRAG SCREEN TO FLIP CHAPTER  ▶  ·  TAP TO DRIVE"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 14)
	hint_lbl.add_theme_color_override("font_color", Color(0.35, 0.38, 0.44))
	hint_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	bottom_bar.add_child(hint_lbl)

# ==============================================================================
# RESPONSIVE EDGE-TO-EDGE FULL SCREEN LAYOUT
# ==============================================================================
func _layout_panels() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1080.0, 1920.0)

	var w: float = vp_size.x
	var h: float = vp_size.y
	custom_minimum_size = vp_size
	size = vp_size

	# 1. Header Bar (Full width across top)
	var header_h: float = 44.0
	if is_instance_valid(header_bar):
		header_bar.position = Vector2(0, 0)
		header_bar.size = Vector2(w, header_h)
	if is_instance_valid(header_chapter_lbl):
		header_chapter_lbl.position = Vector2(16, 6)
		header_chapter_lbl.size = Vector2(w * 0.32, 26)
	if is_instance_valid(header_title_lbl):
		header_title_lbl.position = Vector2(w * 0.28, 4)
		header_title_lbl.size = Vector2(w * 0.44, 32)
	if is_instance_valid(header_meta_lbl):
		header_meta_lbl.position = Vector2(w - 326, 6)
		header_meta_lbl.size = Vector2(310, 26)
	if is_instance_valid(header_sep):
		header_sep.position = Vector2(0, 42)
		header_sep.size = Vector2(w, 2.5)

	# 2. Bottom Action Bar
	var bottom_bar_h: float = 136.0
	if is_instance_valid(bottom_bar):
		bottom_bar.position = Vector2(0, h - bottom_bar_h)
		bottom_bar.size = Vector2(w, bottom_bar_h)
	if is_instance_valid(bot_line):
		bot_line.position = Vector2(0, 0)
		bot_line.size = Vector2(w, 2.5)
	if is_instance_valid(pips_container):
		pips_container.position = Vector2(0, 8)
		pips_container.size = Vector2(w, 18)
	if is_instance_valid(drive_btn):
		var btn_w: float = clamp(w * 0.58, 320.0, 520.0)
		var btn_h: float = 64.0
		drive_btn.position = Vector2((w - btn_w) * 0.5, 34)
		drive_btn.size = Vector2(btn_w, btn_h)
		drive_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
	if is_instance_valid(hint_lbl):
		hint_lbl.position = Vector2(0, 106)
		hint_lbl.size = Vector2(w, 20)

	# 3. Dynamic Vertical Proportions for Panels (Spans exactly from header_h to h - bottom_bar_h)
	var gutter: float = 5.0
	var total_panel_h: float = max(h - bottom_bar_h - header_h, 300.0)
	var net_panel_h: float = total_panel_h - (gutter * 2.0)

	var p1_h: float = net_panel_h * 0.24
	var p2_h: float = net_panel_h * 0.48
	var p3_h: float = net_panel_h - p1_h - p2_h

	# Panel 1: Top Establishing Panorama (Edge-to-edge full width)
	var p1_y: float = header_h
	if is_instance_valid(p1_root):
		p1_root.position = Vector2(0, p1_y)
		p1_root.size = Vector2(w, p1_h)
	if is_instance_valid(top_rect):
		top_rect.position = Vector2(4, 4)
		top_rect.size = Vector2(w - 8, p1_h - 8)
	if is_instance_valid(top_stamp_box):
		top_stamp_box.position = Vector2(w - 224, 10)

	# Panel 2: Center Hero Action Panel (Edge-to-edge full width)
	var p2_y: float = p1_y + p1_h + gutter
	if is_instance_valid(hero_panel_root):
		hero_panel_root.position = Vector2(0, p2_y)
		hero_panel_root.size = Vector2(w, p2_h)
		hero_panel_root.pivot_offset = Vector2(w * 0.5, p2_h * 0.5)
	if is_instance_valid(hero_rect):
		hero_rect.position = Vector2(4, 4)
		hero_rect.size = Vector2(w - 8, p2_h - 8)
	if is_instance_valid(caption_box):
		caption_box.position = Vector2(16, 12)
		caption_box.size = Vector2(min(520.0, w - 32.0), 64.0)

	# Bottom Split Row (Cockpit Cut-in on left, Wheel Close on right)
	var p3_y: float = p2_y + p2_h + gutter
	var col_w: float = (w - gutter) * 0.5

	# Panel 3: Cockpit Cut-In
	if is_instance_valid(p3_root):
		p3_root.position = Vector2(0, p3_y)
		p3_root.size = Vector2(col_w, p3_h)
	if is_instance_valid(cockpit_cutin):
		cockpit_cutin.position = Vector2(0, 0)
		cockpit_cutin.size = Vector2(col_w, p3_h)

	# Panel 4: Wheel Close-Up
	if is_instance_valid(p4_root):
		p4_root.position = Vector2(col_w + gutter, p3_y)
		p4_root.size = Vector2(col_w, p3_h)
	if is_instance_valid(wheel_rect):
		wheel_rect.position = Vector2(4, 4)
		wheel_rect.size = Vector2(col_w - 8, p3_h - 8)
	if is_instance_valid(traction_pill):
		traction_pill.position = Vector2(12, p3_h - 36)

# ==============================================================================
# CONTENT UPDATES & PIPS STYLING
# ==============================================================================
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

	# Update Chapter Indicator Pips
	for i in range(pip_buttons.size()):
		var pip := pip_buttons[i]
		if not is_instance_valid(pip):
			continue
		var style := StyleBoxFlat.new()
		if i == idx:
			style.bg_color = Color("#FFD000") # Active yellow accent pill
			style.set_corner_radius_all(5)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = INK_COLOR
			pip.custom_minimum_size = Vector2(26, 10)
		else:
			style.bg_color = Color(0.40, 0.44, 0.50, 0.65) # Inactive dot
			style.set_corner_radius_all(5)
			pip.custom_minimum_size = Vector2(10, 10)
		pip.add_theme_stylebox_override("normal", style)
		pip.add_theme_stylebox_override("hover", style)
		pip.add_theme_stylebox_override("pressed", style)

# ==============================================================================
# 1:1 INTERACTIVE DRAG & SWIPE ENGINE
# ==============================================================================
func _input(event: InputEvent) -> void:
	if not visible or is_launching or is_flipping:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventScreenDrag and is_dragging:
		_process_drag(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			else:
				_end_drag(event.position)
	elif event is InputEventMouseMotion and is_dragging:
		_process_drag(event.position)

func _start_drag(pos: Vector2) -> void:
	is_dragging = true
	is_drag_gesture = false
	drag_start_pos = pos
	drag_last_pos = pos
	drag_start_time = float(Time.get_ticks_msec()) * 0.001
	drag_velocity_x = 0.0

func _process_drag(pos: Vector2) -> void:
	var delta_x: float = pos.x - drag_start_pos.x
	var delta_y: float = pos.y - drag_start_pos.y

	if not is_drag_gesture and (abs(delta_x) > 10.0 or abs(delta_y) > 10.0):
		if abs(delta_x) > abs(delta_y) * 0.65:
			is_drag_gesture = true

	if is_drag_gesture and is_instance_valid(page_root):
		drag_velocity_x = (pos.x - drag_last_pos.x) / max(get_process_delta_time(), 0.001)
		drag_last_pos = pos

		# Real-time physical page drag with subtle dynamic tilt
		var drag_t: float = delta_x / max(size.x, 1.0)
		page_root.position.x = delta_x * 0.95
		page_root.rotation_degrees = -drag_t * 2.5
		page_root.modulate.a = clamp(1.0 - abs(drag_t) * 0.35, 0.65, 1.0)

func _end_drag(pos: Vector2) -> void:
	if not is_dragging:
		return
	is_dragging = false

	if not is_drag_gesture:
		# Simple tap - ensure page is aligned at center
		if is_instance_valid(page_root):
			page_root.position.x = 0.0
			page_root.rotation_degrees = 0.0
			page_root.modulate.a = 1.0
		return

	var delta_x: float = pos.x - drag_start_pos.x
	var threshold: float = size.x * 0.15

	if delta_x < -threshold or drag_velocity_x < -400.0:
		# Swiped left -> Next chapter!
		flip_next_page()
	elif delta_x > threshold or drag_velocity_x > 400.0:
		# Swiped right -> Previous chapter!
		flip_prev_page()
	else:
		# Released below threshold -> Elastic spring snap-back to center
		_spring_back_to_center()

func _spring_back_to_center() -> void:
	if not is_instance_valid(page_root):
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(page_root, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(page_root, "rotation_degrees", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(page_root, "modulate:a", 1.0, 0.18)

# ==============================================================================
# PAGE TURNING & DIRECT CHAPTER NAVIGATION
# ==============================================================================
func _go_to_page(target_idx: int) -> void:
	if is_flipping or is_launching or target_idx == current_page_idx:
		return
	var dir: int = 1 if target_idx > current_page_idx else -1
	_play_page_slide(target_idx, dir)

func flip_next_page() -> void:
	if is_flipping or is_launching:
		return
	var next_idx: int = (current_page_idx + 1) % BIOME_PAGES.size()
	_play_page_slide(next_idx, 1)

func flip_prev_page() -> void:
	if is_flipping or is_launching:
		return
	var prev_idx: int = (current_page_idx - 1 + BIOME_PAGES.size()) % BIOME_PAGES.size()
	_play_page_slide(prev_idx, -1)

func _play_page_slide(target_idx: int, dir: int) -> void:
	is_flipping = true
	var w: float = size.x

	# 1. Slide active page out in drag direction (0.18s)
	var exit_x: float = -w * 1.15 if dir > 0 else w * 1.15
	var tw_out := create_tween().set_parallel(true)
	tw_out.tween_property(page_root, "position:x", exit_x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_out.tween_property(page_root, "rotation_degrees", -dir * 3.5, 0.18)
	tw_out.tween_property(page_root, "modulate:a", 0.0, 0.15)

	tw_out.chain().tween_callback(func():
		current_page_idx = target_idx
		var next_id: String = BIOME_PAGES[current_page_idx]["id"]
		page_flip_requested.emit(next_id)
		_update_page_content(current_page_idx)

		# 2. Reset position to opposite side and slide smoothly into center (0.22s)
		page_root.position.x = w * 1.15 if dir > 0 else -w * 1.15
		page_root.rotation_degrees = dir * 2.5
		page_root.modulate.a = 0.0

		var tw_in := create_tween().set_parallel(true)
		tw_in.tween_property(page_root, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_in.tween_property(page_root, "rotation_degrees", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_in.tween_property(page_root, "modulate:a", 1.0, 0.18)

		tw_in.chain().tween_callback(func():
			is_flipping = false
		)
	)

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

	# 1. Expand Center Hero Action Panel (scale 1.0x -> 3.5x over 0.55s)
	var tw_hero := create_tween().set_parallel(true)
	tw_hero.tween_property(hero_panel_root, "scale", Vector2(3.5, 3.5), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# Fade out hero border and caption immediately so zero border lines persist into gameplay
	if is_instance_valid(hero_border):
		tw_hero.tween_property(hero_border, "modulate:a", 0.0, 0.15)
	if is_instance_valid(caption_box):
		tw_hero.tween_property(caption_box, "modulate:a", 0.0, 0.15)

	# 2. Animate B&W ink mix from 0.75 -> 0.0 in radial wipe into 100% 3D color
	if is_instance_valid(hero_mat):
		tw_hero.tween_method(func(val: float): hero_mat.set_shader_parameter("bw_ink_mix", val), 0.75, 0.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw_hero.tween_method(func(val: float): hero_mat.set_shader_parameter("wipe_radius", val), 0.0, 2.5, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 3. Surrounding panels slide outward off-screen
	if is_instance_valid(p1_root):
		tw_hero.tween_property(p1_root, "position:y", -500.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_hero.tween_property(p1_root, "modulate:a", 0.0, 0.35)
	if is_instance_valid(p3_root):
		tw_hero.tween_property(p3_root, "position:x", -600.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_hero.tween_property(p3_root, "modulate:a", 0.0, 0.35)
	if is_instance_valid(p4_root):
		tw_hero.tween_property(p4_root, "position:x", size.x + 600.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_hero.tween_property(p4_root, "modulate:a", 0.0, 0.35)
	if is_instance_valid(bottom_bar):
		tw_hero.tween_property(bottom_bar, "position:y", size.y + 200.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_hero.tween_property(bottom_bar, "modulate:a", 0.0, 0.30)
	if is_instance_valid(header_bar):
		tw_hero.tween_property(header_bar, "position:y", -80.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 4. On finish: strictly hide all start page elements and call coordinator completion callback
	var seq := create_tween()
	seq.tween_interval(0.55)
	seq.tween_callback(func():
		visible = false
		if is_instance_valid(paper_bg): paper_bg.visible = false
		if is_instance_valid(hero_panel_root): hero_panel_root.visible = false
		if is_instance_valid(p1_root): p1_root.visible = false
		if is_instance_valid(p3_root): p3_root.visible = false
		if is_instance_valid(p4_root): p4_root.visible = false
		if callback.is_valid():
			callback.call()
	)
