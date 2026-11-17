class_name BiomeLandmarkSystem
extends Node3D

# ==============================================================================
# FLOWSTATE: MASTER PROCEDURAL BIOME LANDMARK SYSTEM (1,250M MID-STAGE MARK)
# Constructs architectural-grade compound 3D landmarks for each of the 4 biomes.
# Zero single-primitive shortcuts. Every landmark features 12+ sub-components,
# custom SurfaceTool / ArrayMesh geometry, bevels, diagonal cross-braces,
# manga_env cel-shading + Next-Pass Inverted-Hull Black Ink Outlines (0.04m, #090B10).
# ==============================================================================

# Shaders
static var _env_shader: Shader
static var _outline_shader: Shader
static var _mat_cache: Dictionary = {}

# Active Landmark Nodes (1 instance per biome, pooled and positioned)
var landmark_shuto: Node3D
var landmark_shinjuku: Node3D
var landmark_hakone: Node3D
var landmark_enoshima: Node3D

# Monorail train animation state (Neo-Shinjuku)
var monorail_train: Node3D
var monorail_train_t: float = 0.0

# Lighthouse light beam animation state (Enoshima)
var lighthouse_beam: Node3D
var lighthouse_angle: float = 0.0

# Road sample callbacks (provided by monolithic_testbed)
var sample_road_x_cb: Callable
var sample_road_tangent_cb: Callable

# Current active state
var current_active_biome: String = ""
var landmark_spawn_z: float = -999999.0
var landmark_is_visible: bool = false

# ==============================================================================
# MATERIAL CACHING & CREATION (manga_env.gdshader + Inverted-Hull Outlines)
# ==============================================================================
static func get_landmark_mat(
	base_color: Color,
	outline_w: float = 0.040,
	is_unshaded: bool = false,
	shadow_color: Color = Color("#CBD5E1")
) -> ShaderMaterial:
	var key: String = "%s_%f_%d_%s" % [base_color.to_html(), outline_w, int(is_unshaded), shadow_color.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]

	if not _env_shader:
		_env_shader = load("res://shaders/manga_env.gdshader")
	if not _outline_shader:
		_outline_shader = load("res://shaders/manga_env_outline.gdshader")

	var mat := ShaderMaterial.new()
	mat.shader = _env_shader
	mat.set_shader_parameter("albedo_tint", base_color)
	mat.set_shader_parameter("shadow_tint", shadow_color)
	mat.set_shader_parameter("ink_color", Color("#090B10"))
	mat.set_shader_parameter("use_vertex_color", false)
	mat.set_shader_parameter("enable_crease_ink", true)

	if is_unshaded:
		# Glowing sign / neon / lantern
		mat.set_shader_parameter("shadow_tint", base_color)

	if outline_w > 0.001:
		var out_mat := ShaderMaterial.new()
		out_mat.shader = _outline_shader
		out_mat.set_shader_parameter("outline_width", outline_w)
		out_mat.set_shader_parameter("outline_color", Color("#090B10"))
		mat.next_pass = out_mat

	_mat_cache[key] = mat
	return mat

static func get_beam_mat() -> StandardMaterial3D:
	var key := "sea_candle_beam_mat"
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.95, 0.75, 0.28)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = mat
	return mat

func _ready() -> void:
	_build_all_landmarks()

# ==============================================================================
# PROCEDURAL GEOMETRY HELPERS (SurfaceTool / ArrayMesh with Bevels & Facets)
# ==============================================================================

# Helper: Create an ArrayMesh for a chamfered / beveled rectangular girder
static func create_chamfered_box_mesh(size: Vector3, chamfer: float, color: Color = Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var ch: float = min(chamfer, min(hx, min(hy, hz)) * 0.45)

	# 8 corner offsets with chamfer
	# Top (+Y) face
	_add_quad(st,
		Vector3(-hx + ch, hy, -hz + ch), Vector3(hx - ch, hy, -hz + ch),
		Vector3(hx - ch, hy, hz - ch), Vector3(-hx + ch, hy, hz - ch),
		Vector3.UP, color)

	# Bottom (-Y) face
	_add_quad(st,
		Vector3(-hx + ch, -hy, hz - ch), Vector3(hx - ch, -hy, hz - ch),
		Vector3(hx - ch, -hy, -hz + ch), Vector3(-hx + ch, -hy, -hz + ch),
		Vector3.DOWN, color)

	# Front (-Z) face
	_add_quad(st,
		Vector3(-hx + ch, -hy + ch, -hz), Vector3(hx - ch, -hy + ch, -hz),
		Vector3(hx - ch, hy - ch, -hz), Vector3(-hx + ch, hy - ch, -hz),
		Vector3.FORWARD, color)

	# Back (+Z) face
	_add_quad(st,
		Vector3(hx - ch, -hy + ch, hz), Vector3(-hx + ch, -hy + ch, hz),
		Vector3(-hx + ch, hy - ch, hz), Vector3(hx - ch, hy - ch, hz),
		Vector3.BACK, color)

	# Left (-X) face
	_add_quad(st,
		Vector3(-hx, -hy + ch, hz - ch), Vector3(-hx, -hy + ch, -hz + ch),
		Vector3(-hx, hy - ch, -hz + ch), Vector3(-hx, hy - ch, hz - ch),
		Vector3.LEFT, color)

	# Right (+X) face
	_add_quad(st,
		Vector3(hx, -hy + ch, -hz + ch), Vector3(hx, -hy + ch, hz - ch),
		Vector3(hx, hy - ch, hz - ch), Vector3(hx, hy - ch, -hz + ch),
		Vector3.RIGHT, color)

	# Top-Front chamfer bevel
	_add_quad(st,
		Vector3(-hx + ch, hy - ch, -hz), Vector3(hx - ch, hy - ch, -hz),
		Vector3(hx - ch, hy, -hz + ch), Vector3(-hx + ch, hy, -hz + ch),
		(Vector3.UP + Vector3.FORWARD).normalized(), color)

	# Top-Back chamfer bevel
	_add_quad(st,
		Vector3(hx - ch, hy - ch, hz), Vector3(-hx + ch, hy - ch, hz),
		Vector3(-hx + ch, hy, hz - ch), Vector3(hx - ch, hy, hz - ch),
		(Vector3.UP + Vector3.BACK).normalized(), color)

	# Top-Left chamfer bevel
	_add_quad(st,
		Vector3(-hx, hy - ch, -hz + ch), Vector3(-hx, hy - ch, hz - ch),
		Vector3(-hx + ch, hy, hz - ch), Vector3(-hx + ch, hy, -hz + ch),
		(Vector3.UP + Vector3.LEFT).normalized(), color)

	# Top-Right chamfer bevel
	_add_quad(st,
		Vector3(hx, hy - ch, hz - ch), Vector3(hx, hy - ch, -hz + ch),
		Vector3(hx - ch, hy, -hz + ch), Vector3(hx - ch, hy, hz - ch),
		(Vector3.UP + Vector3.RIGHT).normalized(), color)

	return st.commit()

# Helper: Quad with normal
static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, norm: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(norm)
	st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(p1)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p2)

	st.set_color(col)
	st.set_normal(norm)
	st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(p2)
	st.set_uv(Vector2(0, 1)); st.add_vertex(p3)

# Helper: Create a tapered 4-sided box girder column
static func create_tapered_column_mesh(bot_size: Vector2, top_size: Vector2, height: float, color: Color = Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hbx: float = bot_size.x * 0.5
	var hbz: float = bot_size.y * 0.5
	var htx: float = top_size.x * 0.5
	var htz: float = top_size.y * 0.5

	var b0 := Vector3(-hbx, 0.0, -hbz)
	var b1 := Vector3(hbx, 0.0, -hbz)
	var b2 := Vector3(hbx, 0.0, hbz)
	var b3 := Vector3(-hbx, 0.0, hbz)

	var t0 := Vector3(-htx, height, -htz)
	var t1 := Vector3(htx, height, -htz)
	var t2 := Vector3(htx, height, htz)
	var t3 := Vector3(-htx, height, htz)

	# Front
	_add_quad(st, b0, b1, t1, t0, Vector3.FORWARD, color)
	# Right
	_add_quad(st, b1, b2, t2, t1, Vector3.RIGHT, color)
	# Back
	_add_quad(st, b2, b3, t3, t2, Vector3.BACK, color)
	# Left
	_add_quad(st, b3, b0, t0, t3, Vector3.LEFT, color)
	# Top cap
	_add_quad(st, t0, t1, t2, t3, Vector3.UP, color)
	# Bottom cap
	_add_quad(st, b3, b2, b1, b0, Vector3.DOWN, color)

	return st.commit()

# Helper: Create an X-truss bracing assembly between two vertical heights
static func create_x_truss_mesh(width: float, height: float, depth: float, strut_w: float, color: Color = Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw: float = width * 0.5
	var hh: float = height * 0.5
	var hd: float = depth * 0.5
	var sw: float = strut_w * 0.5

	# Diagonal strut 1: from (-hw, -hh) to (hw, hh)
	var d1_start := Vector3(-hw, -hh, 0.0)
	var d1_end := Vector3(hw, hh, 0.0)
	var d1_dir := (d1_end - d1_start).normalized()
	var d1_norm := Vector3(-d1_dir.y, d1_dir.x, 0.0) * sw

	_add_quad(st,
		d1_start - d1_norm + Vector3(0, 0, -hd), d1_start + d1_norm + Vector3(0, 0, -hd),
		d1_end + d1_norm + Vector3(0, 0, -hd), d1_end - d1_norm + Vector3(0, 0, -hd),
		Vector3.FORWARD, color)
	_add_quad(st,
		d1_end - d1_norm + Vector3(0, 0, hd), d1_end + d1_norm + Vector3(0, 0, hd),
		d1_start + d1_norm + Vector3(0, 0, hd), d1_start - d1_norm + Vector3(0, 0, hd),
		Vector3.BACK, color)

	# Diagonal strut 2: from (-hw, hh) to (hw, -hh)
	var d2_start := Vector3(-hw, hh, 0.0)
	var d2_end := Vector3(hw, -hh, 0.0)
	var d2_dir := (d2_end - d2_start).normalized()
	var d2_norm := Vector3(-d2_dir.y, d2_dir.x, 0.0) * sw

	_add_quad(st,
		d2_start - d2_norm + Vector3(0, 0, -hd), d2_start + d2_norm + Vector3(0, 0, -hd),
		d2_end + d2_norm + Vector3(0, 0, -hd), d2_end - d2_norm + Vector3(0, 0, -hd),
		Vector3.FORWARD, color)
	_add_quad(st,
		d2_end - d2_norm + Vector3(0, 0, hd), d2_end + d2_norm + Vector3(0, 0, hd),
		d2_start + d2_norm + Vector3(0, 0, hd), d2_start - d2_norm + Vector3(0, 0, hd),
		Vector3.BACK, color)

	# Horizontal top rail
	_add_quad(st,
		Vector3(-hw, hh - sw, -hd), Vector3(hw, hh - sw, -hd),
		Vector3(hw, hh + sw, -hd), Vector3(-hw, hh + sw, -hd),
		Vector3.FORWARD, color)
	_add_quad(st,
		Vector3(hw, hh - sw, hd), Vector3(-hw, hh - sw, hd),
		Vector3(-hw, hh + sw, hd), Vector3(hw, hh + sw, hd),
		Vector3.BACK, color)

	# Horizontal bottom rail
	_add_quad(st,
		Vector3(-hw, -hh - sw, -hd), Vector3(hw, -hh - sw, -hd),
		Vector3(hw, -hh + sw, -hd), Vector3(-hw, -hh + sw, -hd),
		Vector3.FORWARD, color)
	_add_quad(st,
		Vector3(hw, -hh - sw, hd), Vector3(-hw, -hh - sw, hd),
		Vector3(-hw, -hh + sw, hd), Vector3(hw, -hh + sw, hd),
		Vector3.BACK, color)

	return st.commit()

# Helper: Swept 3D polygonal tube / ribbon along a list of path points (for suspension cables & pipes)
static func create_swept_tube_mesh(points: Array[Vector3], radius: float, sides: int = 6, color: Color = Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	if points.size() < 2:
		return st.commit()

	var rings: Array = []
	for p_idx in range(points.size()):
		var pt: Vector3 = points[p_idx]
		var forward: Vector3 = Vector3.FORWARD
		if p_idx < points.size() - 1:
			forward = (points[p_idx + 1] - pt).normalized()
		elif p_idx > 0:
			forward = (pt - points[p_idx - 1]).normalized()

		var up := Vector3.UP
		if abs(forward.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var right := forward.cross(up).normalized()
		up = right.cross(forward).normalized()

		var ring_verts: Array[Vector3] = []
		for s in range(sides):
			var angle: float = float(s) / float(sides) * TAU
			var offset := (right * cos(angle) + up * sin(angle)) * radius
			ring_verts.append(pt + offset)
		rings.append(ring_verts)

	# Connect rings with quads
	for r in range(rings.size() - 1):
		var r0: Array[Vector3] = rings[r]
		var r1: Array[Vector3] = rings[r + 1]
		for s in range(sides):
			var next_s: int = (s + 1) % sides
			var p0 := r0[s]
			var p1 := r0[next_s]
			var p2 := r1[next_s]
			var p3 := r1[s]
			var norm := (p1 - p0).cross(p3 - p0).normalized()
			_add_quad(st, p0, p1, p2, p3, norm, color)

	return st.commit()

# ==============================================================================
# 1. BIOME 1 — SHUTO DUSK: RAINBOW BRIDGE SUSPENSION SPAN (1,250M)
# ==============================================================================
func _build_shuto_rainbow_bridge() -> Node3D:
	var root := Node3D.new()
	root.name = "Landmark_Shuto_RainbowBridge"

	var steel_white := Color("#DDE5ED") # Studio Japanese bridge steel
	var steel_shadow := Color("#94A3B8")
	var dark_accent := Color("#1E293B")
	var beacon_red := Color("#FF2A55")

	var mat_pylon := get_landmark_mat(steel_white, 0.045, false, steel_shadow)
	var mat_accent := get_landmark_mat(dark_accent, 0.035, false)
	var mat_cable := get_landmark_mat(steel_shadow, 0.030, false, Color("#64748B"))
	var mat_beacon := get_landmark_mat(beacon_red, 0.025, true)

	# Twin H-Frame Steel Pylons at X = -11.5m and X = +11.5m (Height 42m, zero road obstruction)
	var pylon_x_offsets: Array[float] = [-11.5, 11.5]

	for px in pylon_x_offsets:
		var pylon_root := Node3D.new()
		pylon_root.position.x = px
		root.add_child(pylon_root)

		# Sub-component 1: Massive Beveled Pier Foundation Pedestal (Y = -2.0m to 1.5m)
		var pier_pedestal := MeshInstance3D.new()
		pier_pedestal.mesh = create_chamfered_box_mesh(Vector3(3.6, 3.5, 5.0), 0.35)
		pier_pedestal.position = Vector3(0.0, -0.25, 0.0)
		pier_pedestal.material_override = mat_accent
		pylon_root.add_child(pier_pedestal)

		# Sub-component 2: Lower Tapered Box-Girder Legs (Y = 1.5m to 14.0m)
		var lower_leg := MeshInstance3D.new()
		lower_leg.mesh = create_tapered_column_mesh(Vector2(2.6, 3.8), Vector2(2.2, 3.2), 12.5)
		lower_leg.position = Vector3(0.0, 1.5, 0.0)
		lower_leg.material_override = mat_pylon
		pylon_root.add_child(lower_leg)

		# Sub-component 3: Mid Tapered Box-Girder Legs (Y = 14.0m to 28.0m)
		var mid_leg := MeshInstance3D.new()
		mid_leg.mesh = create_tapered_column_mesh(Vector2(2.2, 3.2), Vector2(1.8, 2.6), 14.0)
		mid_leg.position = Vector3(0.0, 14.0, 0.0)
		mid_leg.material_override = mat_pylon
		pylon_root.add_child(mid_leg)

		# Sub-component 4: Upper Tapered Box-Girder Legs (Y = 28.0m to 42.0m)
		var upper_leg := MeshInstance3D.new()
		upper_leg.mesh = create_tapered_column_mesh(Vector2(1.8, 2.6), Vector2(1.4, 2.0), 14.0)
		upper_leg.position = Vector3(0.0, 28.0, 0.0)
		upper_leg.material_override = mat_pylon
		pylon_root.add_child(upper_leg)

		# Sub-component 5: Pylon Cap & Aviation Warning Beacon (#FF2A55) atop cap
		var cap_mesh := MeshInstance3D.new()
		cap_mesh.mesh = create_chamfered_box_mesh(Vector3(1.8, 1.2, 2.4), 0.20)
		cap_mesh.position = Vector3(0.0, 42.6, 0.0)
		cap_mesh.material_override = mat_accent
		pylon_root.add_child(cap_mesh)

		var beacon := MeshInstance3D.new()
		beacon.mesh = create_chamfered_box_mesh(Vector3(0.55, 0.75, 0.55), 0.12)
		beacon.position = Vector3(0.0, 43.5, 0.0)
		beacon.material_override = mat_beacon
		pylon_root.add_child(beacon)

	# Sub-component 6, 7, 8: Three Tiered Horizontal Cross-Beams connecting pylons across the highway
	var beam_heights: Array[float] = [14.0, 28.0, 41.5]
	var beam_sizes: Array[Vector3] = [
		Vector3(23.0, 2.2, 2.8), # Lower beam (clearance 12.9m, high above 4.5m traffic)
		Vector3(23.0, 1.8, 2.2), # Middle beam
		Vector3(23.0, 1.5, 1.8)  # Top beam
	]

	for bi in range(3):
		var x_beam := MeshInstance3D.new()
		x_beam.mesh = create_chamfered_box_mesh(beam_sizes[bi], 0.25)
		x_beam.position = Vector3(0.0, beam_heights[bi], 0.0)
		x_beam.material_override = mat_pylon
		root.add_child(x_beam)

	# Sub-component 9 & 10: Diagonal X-Bracing Trusses between the upper tiers
	var x_truss_mid := MeshInstance3D.new()
	x_truss_mid.mesh = create_x_truss_mesh(21.0, 12.0, 0.8, 0.55, steel_white)
	x_truss_mid.position = Vector3(0.0, 21.0, 0.0)
	x_truss_mid.material_override = mat_pylon
	root.add_child(x_truss_mid)

	var x_truss_top := MeshInstance3D.new()
	x_truss_top.mesh = create_x_truss_mesh(21.0, 11.5, 0.7, 0.45, steel_white)
	x_truss_top.position = Vector3(0.0, 35.0, 0.0)
	x_truss_top.material_override = mat_pylon
	root.add_child(x_truss_top)

	# Sub-component 11 & 12: Parabolic Swept Main Suspension Cables (Left & Right)
	# Swept curve from Z = -70m (deck level) -> Z = 0m (pylon peak Y=42m) -> Z = +70m (deck level)
	for cable_side in [-1.0, 1.0]:
		var cable_pts: Array[Vector3] = []
		var cable_x_base: float = cable_side * 11.5
		for step in range(36):
			var t: float = float(step) / 35.0
			var cz: float = lerp(-70.0, 70.0, t)
			# Parabola: peak 42.0m at cz=0, dips down to 3.5m at cz = +/-68m
			var cy: float = 3.5 + 38.5 * (1.0 - pow(cz / 70.0, 2.0))
			# Slight inward cradle toward deck at ends
			var cx: float = cable_x_base + (cable_side * -1.2 * (1.0 - pow(cz / 70.0, 2.0)))
			cable_pts.append(Vector3(cx, cy, cz))

		var main_cable := MeshInstance3D.new()
		main_cable.mesh = create_swept_tube_mesh(cable_pts, 0.28, 8, steel_shadow)
		main_cable.material_override = mat_cable
		root.add_child(main_cable)

	# Sub-component 13: 16 Vertical Suspender Hanger Cables (8 pairs along each side)
	var suspender_z_offsets: Array[float] = [-56.0, -48.0, -38.0, -26.0, -14.0, 14.0, 26.0, 38.0, 48.0, 56.0]
	for sz in suspender_z_offsets:
		for s_side in [-1.0, 1.0]:
			var s_cy: float = 3.5 + 38.5 * (1.0 - pow(sz / 70.0, 2.0))
			var s_cx: float = (s_side * 11.5) + (s_side * -1.2 * (1.0 - pow(sz / 70.0, 2.0)))
			var s_pts: Array[Vector3] = [
				Vector3(s_cx, s_cy, sz),
				Vector3(s_cx, 1.2, sz)
			]
			var suspender := MeshInstance3D.new()
			suspender.mesh = create_swept_tube_mesh(s_pts, 0.08, 5, steel_shadow)
			suspender.material_override = mat_cable
			root.add_child(suspender)

	# Sub-component 14: Underslung Steel Deck Trusses outside road edge (X = +/- 9.5m to 11.2m)
	for d_side in [-1.0, 1.0]:
		var deck_truss := MeshInstance3D.new()
		deck_truss.mesh = create_chamfered_box_mesh(Vector3(1.4, 2.2, 140.0), 0.15)
		deck_truss.position = Vector3(d_side * 10.4, -0.6, 0.0)
		deck_truss.material_override = mat_accent
		root.add_child(deck_truss)

	return root

# ==============================================================================
# 2. BIOME 2 — NEO-SHINJUKU: KABUKICHO NEON ARCH & OVERHEAD MONORAIL (1,250M)
# ==============================================================================
func _build_neo_shinjuku_kabukicho() -> Node3D:
	var root := Node3D.new()
	root.name = "Landmark_Neo_Shinjuku_Kabukicho"

	var crimson := Color("#DC2626")
	var gold := Color("#F59E0B")
	var dark_steel := Color("#111827")
	var concrete_gray := Color("#9CA3AF")
	var train_silver := Color("#E5E7EB")
	var train_cyan := Color("#06B6D4")
	var train_window := Color("#0F172A")
	var interior_glow := Color("#FEF08A")

	var mat_crimson := get_landmark_mat(crimson, 0.040, false)
	var mat_gold := get_landmark_mat(gold, 0.035, true)
	var mat_steel := get_landmark_mat(dark_steel, 0.035, false)
	var mat_concrete := get_landmark_mat(concrete_gray, 0.040, false)
	var mat_train_body := get_landmark_mat(train_silver, 0.038, false)
	var mat_train_stripe := get_landmark_mat(train_cyan, 0.030, true)
	var mat_train_win := get_landmark_mat(train_window, 0.025, false)
	var mat_train_interior := get_landmark_mat(interior_glow, 0.020, true)

	# --- PART A: MULTI-TIERED KABUKICHO ARCHWAY (Clearance 9.5m) ---
	var arch_root := Node3D.new()
	arch_root.name = "KabukichoArch"
	root.add_child(arch_root)

	# Sub-components 1 & 2: Twin Steel Lattice Columns on sidewalks (X = -6.2m and X = +6.2m, outside guardrail)
	for col_side in [-1.0, 1.0]:
		var col_x: float = col_side * 6.2

		# Pedestal
		var base_ped := MeshInstance3D.new()
		base_ped.mesh = create_chamfered_box_mesh(Vector3(1.6, 1.8, 1.6), 0.20)
		base_ped.position = Vector3(col_x, 0.9, 0.0)
		base_ped.material_override = mat_steel
		arch_root.add_child(base_ped)

		# Vertical Column Girder
		var col_mesh := MeshInstance3D.new()
		col_mesh.mesh = create_tapered_column_mesh(Vector2(1.2, 1.2), Vector2(1.0, 1.0), 9.0)
		col_mesh.position = Vector3(col_x, 1.8, 0.0)
		col_mesh.material_override = mat_steel
		arch_root.add_child(col_mesh)

		# Diagonal Gusset Knee Bracket (at Y = 8.5m to 10.0m)
		var gusset_pts: Array[Vector3] = [
			Vector3(col_x, 8.2, 0.0),
			Vector3(col_x - col_side * 1.8, 10.0, 0.0)
		]
		var gusset := MeshInstance3D.new()
		gusset.mesh = create_swept_tube_mesh(gusset_pts, 0.22, 6, crimson)
		gusset.material_override = mat_crimson
		arch_root.add_child(gusset)

	# Sub-component 3: Primary Transverse Box Beam (Span 13.5m, Height Y = 10.2m)
	var main_beam := MeshInstance3D.new()
	main_beam.mesh = create_chamfered_box_mesh(Vector3(13.6, 1.4, 1.8), 0.22)
	main_beam.position = Vector3(0.0, 10.2, 0.0)
	main_beam.material_override = mat_crimson
	arch_root.add_child(main_beam)

	# Sub-component 4: Stepped Upper Arch Canopy Roof (Traditional stepped Japanese gate crest)
	var canopy_tier1 := MeshInstance3D.new()
	canopy_tier1.mesh = create_chamfered_box_mesh(Vector3(12.0, 0.8, 2.2), 0.18)
	canopy_tier1.position = Vector3(0.0, 11.2, 0.0)
	canopy_tier1.material_override = mat_gold
	arch_root.add_child(canopy_tier1)

	var canopy_tier2 := MeshInstance3D.new()
	canopy_tier2.mesh = create_chamfered_box_mesh(Vector3(9.5, 0.9, 1.9), 0.18)
	canopy_tier2.position = Vector3(0.0, 12.0, 0.0)
	canopy_tier2.material_override = mat_crimson
	arch_root.add_child(canopy_tier2)

	# Sub-component 5: Protruding Vertical Kanji Signboard Blades & Center Sign ("歌舞伎町一番街")
	var sign_board := MeshInstance3D.new()
	sign_board.mesh = create_chamfered_box_mesh(Vector3(7.2, 1.6, 0.35), 0.08)
	sign_board.position = Vector3(0.0, 10.2, -0.95)
	sign_board.material_override = mat_gold
	arch_root.add_child(sign_board)

	for sign_blade_x in [-4.8, 4.8]:
		var blade := MeshInstance3D.new()
		blade.mesh = create_chamfered_box_mesh(Vector3(0.45, 3.2, 0.8), 0.08)
		blade.position = Vector3(sign_blade_x, 9.8, -0.6)
		blade.material_override = mat_crimson
		arch_root.add_child(blade)

	# Sub-component 6: Glowing Lantern Trim / Downlight Strip (Under-beam floodlights)
	for lx in range(-5, 6):
		var lantern := MeshInstance3D.new()
		lantern.mesh = create_chamfered_box_mesh(Vector3(0.35, 0.55, 0.35), 0.08)
		lantern.position = Vector3(float(lx) * 1.1, 9.35, 0.0)
		lantern.material_override = mat_gold
		arch_root.add_child(lantern)

	# --- PART B: ELEVATED STRADDLE-BEAM MONORAIL & 3-CAR ARTICULATED TRAIN (Height 13.5m) ---
	var monorail_root := Node3D.new()
	monorail_root.name = "ElevatedMonorail"
	monorail_root.position.z = -14.0 # Sits slightly past the archway
	root.add_child(monorail_root)

	# Guideway crosses diagonally at 24 degrees across highway
	var guideway_angle := deg_to_rad(24.0)
	monorail_root.rotation.y = guideway_angle

	# Sub-components 7 & 8: T-Shaped Concrete Piers (X = -13.0m and X = +13.0m along rotated local axis)
	for pier_x in [-13.0, 13.0]:
		var pier_col := MeshInstance3D.new()
		pier_col.mesh = create_tapered_column_mesh(Vector2(2.0, 2.0), Vector2(1.8, 1.8), 12.0)
		pier_col.position = Vector3(pier_x, 0.0, 0.0)
		pier_col.material_override = mat_concrete
		monorail_root.add_child(pier_col)

		var hammerhead := MeshInstance3D.new()
		hammerhead.mesh = create_chamfered_box_mesh(Vector3(4.5, 1.6, 2.2), 0.28)
		hammerhead.position = Vector3(pier_x, 12.5, 0.0)
		hammerhead.material_override = mat_concrete
		monorail_root.add_child(hammerhead)

	# Sub-component 9: Chamfered Concrete Guideway Beam (Length 70m, Height Y = 13.4m)
	var guideway_beam := MeshInstance3D.new()
	guideway_beam.mesh = create_chamfered_box_mesh(Vector3(70.0, 1.8, 1.3), 0.22)
	guideway_beam.position = Vector3(0.0, 13.4, 0.0)
	guideway_beam.material_override = mat_concrete
	monorail_root.add_child(guideway_beam)

	# Sub-components 10, 11, 12: 3-Car Articulated Commuter Monorail Train
	monorail_train = Node3D.new()
	monorail_train.name = "MonorailTrain"
	monorail_train.position.y = 14.3
	monorail_root.add_child(monorail_train)

	var car_length: float = 12.5
	var car_offsets: Array[float] = [-13.2, 0.0, 13.2]

	for ci in range(3):
		var car_pos_x: float = car_offsets[ci]
		var car_node := Node3D.new()
		car_node.position.x = car_pos_x
		monorail_train.add_child(car_node)

		# Car Body (chamfered streamliner)
		var body := MeshInstance3D.new()
		body.mesh = create_chamfered_box_mesh(Vector3(car_length, 2.6, 2.8), 0.35)
		body.position = Vector3(0.0, 1.3, 0.0)
		body.material_override = mat_train_body
		car_node.add_child(body)

		# Cyan Accent Racing Stripe
		var stripe := MeshInstance3D.new()
		stripe.mesh = create_chamfered_box_mesh(Vector3(car_length + 0.02, 0.35, 2.84), 0.08)
		stripe.position = Vector3(0.0, 0.6, 0.0)
		stripe.material_override = mat_train_stripe
		car_node.add_child(stripe)

		# Dark Tinted Window Bands
		for win_side in [-1.0, 1.0]:
			var win_band := MeshInstance3D.new()
			win_band.mesh = create_chamfered_box_mesh(Vector3(car_length * 0.85, 0.95, 0.12), 0.05)
			win_band.position = Vector3(0.0, 1.6, win_side * 1.42)
			win_band.material_override = mat_train_win
			car_node.add_child(win_band)

		# Illuminated Interior Strip
		var interior := MeshInstance3D.new()
		interior.mesh = create_chamfered_box_mesh(Vector3(car_length * 0.80, 0.55, 1.8), 0.05)
		interior.position = Vector3(0.0, 1.6, 0.0)
		interior.material_override = mat_train_interior
		car_node.add_child(interior)

		# Rooftop Dual AC Pods
		for ac_x in [-3.5, 3.5]:
			var ac_pod := MeshInstance3D.new()
			ac_pod.mesh = create_chamfered_box_mesh(Vector3(2.6, 0.45, 1.6), 0.12)
			ac_pod.position = Vector3(ac_x, 2.8, 0.0)
			ac_pod.material_override = mat_concrete
			car_node.add_child(ac_pod)

		# Articulation Bellows Gangway (between cars)
		if ci < 2:
			var bellows := MeshInstance3D.new()
			bellows.mesh = create_chamfered_box_mesh(Vector3(1.2, 2.3, 2.4), 0.15)
			bellows.position = Vector3(car_pos_x + 6.6, 1.3, 0.0)
			bellows.material_override = mat_steel
			monorail_train.add_child(bellows)

	return root

# ==============================================================================
# 3. BIOME 3 — HAKONE SNOW: LAKE ASHI OVERLOOK & CRIMSON TORII GATE (1,250M)
# ==============================================================================
func _build_hakone_torii_overlook() -> Node3D:
	var root := Node3D.new()
	root.name = "Landmark_Hakone_ToriiOverlook"

	var vermilion := Color("#E11D48")     # Sacred Japanese Torii Vermilion
	var dark_timber := Color("#1E1B18")    # Weathered dark timber / shimaki cap
	var stone_gray := Color("#475569")     # Granite kamebara pedestal
	var snow_white := Color("#F1F5F9")     # Cel-shaded alpine snow
	var snow_shadow := Color("#CBD5E1")    # Snow shadow
	var gold := Color("#F59E0B")           # Plaque calligraphy gold
	var ice_mirror := Color("#BAE6FD")     # Lake Ashi mirror ice
	var lantern_glow := Color("#FBBF24")   # Warm stone lantern firebox

	var mat_vermilion := get_landmark_mat(vermilion, 0.045, false, Color("#9F1239"))
	var mat_timber := get_landmark_mat(dark_timber, 0.035, false)
	var mat_stone := get_landmark_mat(stone_gray, 0.035, false)
	var mat_snow := get_landmark_mat(snow_white, 0.035, false, snow_shadow)
	var mat_gold := get_landmark_mat(gold, 0.025, true)
	var mat_ice := get_landmark_mat(ice_mirror, 0.030, false, Color("#93C5FD"))
	var mat_firebox := get_landmark_mat(lantern_glow, 0.020, true)

	# Sub-component 1: Frozen Lake Ashi Overlook Ice Basin (X = +10.0m to +110.0m, Y = -0.5m)
	var lake_ice := MeshInstance3D.new()
	lake_ice.mesh = create_chamfered_box_mesh(Vector3(100.0, 0.6, 150.0), 0.25)
	lake_ice.position = Vector3(60.0, -0.6, 0.0)
	lake_ice.material_override = mat_ice
	root.add_child(lake_ice)

	# Shoreline snow banks (smooth transition along the road edge at X = +10.5m)
	var shore_snow := MeshInstance3D.new()
	shore_snow.mesh = create_chamfered_box_mesh(Vector3(3.2, 0.7, 150.0), 0.30)
	shore_snow.position = Vector3(10.2, -0.3, 0.0)
	shore_snow.material_override = mat_snow
	root.add_child(shore_snow)

	# Sub-component 2: Distant Snow-Capped Mt. Fuji Silhouette (in background at X = +75m, Y = 10m to 60m)
	var fuji_st := SurfaceTool.new()
	fuji_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f_center := Vector3(80.0, 0.0, -45.0)
	var f_peak := f_center + Vector3(0.0, 58.0, 0.0)
	var f_sides: int = 14
	var f_base_r: float = 65.0
	var f_snow_y: float = 34.0

	for fs in range(f_sides):
		var fa0: float = float(fs) / float(f_sides) * TAU
		var fa1: float = float(fs + 1) / float(f_sides) * TAU
		var b0 := f_center + Vector3(cos(fa0) * f_base_r, 0.0, sin(fa0) * f_base_r)
		var b1 := f_center + Vector3(cos(fa1) * f_base_r, 0.0, sin(fa1) * f_base_r)
		var m0: Vector3 = b0.lerp(f_peak, 0.58)
		var m1: Vector3 = b1.lerp(f_peak, 0.58)

		# Lower mountain body (slate blue)
		fuji_st.set_color(Color("#64748B"))
		_add_quad(fuji_st, b0, b1, m1, m0, Vector3.UP, Color("#64748B"))
		# Upper snow cap (pure white)
		fuji_st.set_color(snow_white)
		fuji_st.set_normal(Vector3.UP)
		fuji_st.set_uv(Vector2(0, 0)); fuji_st.add_vertex(m0)
		fuji_st.set_uv(Vector2(1, 0)); fuji_st.add_vertex(m1)
		fuji_st.set_uv(Vector2(0.5, 1)); fuji_st.add_vertex(f_peak)

	var fuji_mesh := MeshInstance3D.new()
	fuji_mesh.mesh = fuji_st.commit()
	fuji_mesh.material_override = mat_snow
	root.add_child(fuji_mesh)

	# --- PART B: TRADITIONAL MYOJIN-STYLE VERMILION TORII GATE (X = +12.5m in shallows) ---
	var torii_root := Node3D.new()
	torii_root.name = "ToriiGate"
	torii_root.position = Vector3(12.5, -0.3, 0.0)
	# Angled at 45 degrees toward oncoming traffic so driver sees frontal arch, kasagi and snow caps
	torii_root.rotation.y = deg_to_rad(-45.0)
	root.add_child(torii_root)

	var pillar_span: float = 8.5
	var pillar_height: float = 12.0
	var pillar_tilt_angle: float = deg_to_rad(2.5) # Traditional inward 'uchikorobi' tilt

	# Sub-components 3 & 4: Twin Inward-Tilted Main Pillars ('hashira') with Granite Pedestals ('kamebara')
	for p_side in [-1.0, 1.0]:
		var px: float = p_side * (pillar_span * 0.5)

		# Dark stone kamebara pedestal
		var kamebara := MeshInstance3D.new()
		kamebara.mesh = create_chamfered_box_mesh(Vector3(1.8, 1.4, 1.8), 0.28)
		kamebara.position = Vector3(px, 0.6, 0.0)
		kamebara.material_override = mat_stone
		torii_root.add_child(kamebara)

		# Inward-tilted hashira column
		var pillar := MeshInstance3D.new()
		pillar.mesh = create_tapered_column_mesh(Vector2(1.2, 1.2), Vector2(0.95, 0.95), pillar_height)
		pillar.position = Vector3(px, 1.2, 0.0)
		pillar.rotation.z = -p_side * pillar_tilt_angle
		pillar.material_override = mat_vermilion
		torii_root.add_child(pillar)

		# Secondary A-Frame Stabilizing Legs (Ryobu-style chigo-bashira in water)
		for leg_z in [-1.4, 1.4]:
			var chigo := MeshInstance3D.new()
			chigo.mesh = create_tapered_column_mesh(Vector2(0.65, 0.65), Vector2(0.45, 0.45), 4.2)
			chigo.position = Vector3(px, 0.5, leg_z)
			chigo.rotation.x = -sign(leg_z) * deg_to_rad(14.0)
			chigo.material_override = mat_vermilion
			torii_root.add_child(chigo)

	# Sub-component 5: Secondary Horizontal Tie-Beam ('nuki') with Locking Wedges ('kusabi')
	var nuki := MeshInstance3D.new()
	nuki.mesh = create_chamfered_box_mesh(Vector3(pillar_span + 2.8, 0.75, 0.65), 0.12)
	nuki.position = Vector3(0.0, 8.8, 0.0)
	nuki.material_override = mat_vermilion
	torii_root.add_child(nuki)

	# Kusabi wedges pinning nuki against hashira
	for k_side in [-1.0, 1.0]:
		var kusabi := MeshInstance3D.new()
		kusabi.mesh = create_chamfered_box_mesh(Vector3(0.25, 0.95, 0.85), 0.06)
		kusabi.position = Vector3(k_side * (pillar_span * 0.5 + 0.55), 8.8, 0.0)
		kusabi.material_override = mat_timber
		torii_root.add_child(kusabi)

	# Sub-component 6: Dedication Tablet Plaque ('gakuzuka') centered between nuki and kasagi
	var gakuzuka := MeshInstance3D.new()
	gakuzuka.mesh = create_chamfered_box_mesh(Vector3(1.2, 1.8, 0.35), 0.08)
	gakuzuka.position = Vector3(0.0, 10.2, 0.0)
	gakuzuka.material_override = mat_gold
	torii_root.add_child(gakuzuka)

	# Sub-component 7 & 8: Upward-Curving Top Lintel ('kasagi') and Dark Cap ('shimaki') via SurfaceTool
	# Classic Japanese parabolic upward sweep ('sori')
	var kasagi_len: float = pillar_span + 4.8
	var kasagi_pts: Array[Vector3] = []
	var shimaki_pts: Array[Vector3] = []
	var snow_pts: Array[Vector3] = []

	var k_steps: int = 24
	for ks in range(k_steps + 1):
		var kt: float = float(ks) / float(k_steps)
		var kx: float = lerp(-kasagi_len * 0.5, kasagi_len * 0.5, kt)
		# Parabolic flare lift at winged tips
		var flare: float = pow(abs(kx) / (kasagi_len * 0.5), 2.2) * 0.85
		var ky_base: float = 11.5 + flare
		kasagi_pts.append(Vector3(kx, ky_base, 0.0))
		shimaki_pts.append(Vector3(kx * 0.95, ky_base - 0.45, 0.0))
		snow_pts.append(Vector3(kx, ky_base + 0.42, 0.0))

	# Dark shimaki under-lintel
	var shimaki := MeshInstance3D.new()
	shimaki.mesh = create_swept_tube_mesh(shimaki_pts, 0.45, 6, dark_timber)
	shimaki.material_override = mat_timber
	torii_root.add_child(shimaki)

	# Primary vermilion kasagi lintel
	var kasagi := MeshInstance3D.new()
	kasagi.mesh = create_swept_tube_mesh(kasagi_pts, 0.60, 6, vermilion)
	kasagi.material_override = mat_vermilion
	torii_root.add_child(kasagi)

	# Sub-components 9 & 10: Sculpted Snow Blanket along Kasagi and Nuki
	var kasagi_snow := MeshInstance3D.new()
	kasagi_snow.mesh = create_swept_tube_mesh(snow_pts, 0.32, 6, snow_white)
	kasagi_snow.material_override = mat_snow
	torii_root.add_child(kasagi_snow)

	var nuki_snow := MeshInstance3D.new()
	nuki_snow.mesh = create_chamfered_box_mesh(Vector3(pillar_span + 2.6, 0.22, 0.72), 0.08)
	nuki_snow.position = Vector3(0.0, 9.25, 0.0)
	nuki_snow.material_override = mat_snow
	torii_root.add_child(nuki_snow)

	# Sub-component 11: Traditional Stone Lanterns ('toro') flanking the torii in the ice
	for l_side in [-1.0, 1.0]:
		var toro_root := Node3D.new()
		toro_root.position = Vector3(l_side * (pillar_span * 0.5 + 2.8), 0.0, 2.2)
		torii_root.add_child(toro_root)

		# Base
		var t_base := MeshInstance3D.new()
		t_base.mesh = create_chamfered_box_mesh(Vector3(1.1, 0.5, 1.1), 0.15)
		t_base.position.y = 0.25
		t_base.material_override = mat_stone
		toro_root.add_child(t_base)

		# Column
		var t_col := MeshInstance3D.new()
		t_col.mesh = create_tapered_column_mesh(Vector2(0.55, 0.55), Vector2(0.50, 0.50), 1.6)
		t_col.position.y = 0.5
		t_col.material_override = mat_stone
		toro_root.add_child(t_col)

		# Firebox with glowing warm opening
		var t_firebox := MeshInstance3D.new()
		t_firebox.mesh = create_chamfered_box_mesh(Vector3(0.85, 0.75, 0.85), 0.12)
		t_firebox.position.y = 2.45
		t_firebox.material_override = mat_firebox
		toro_root.add_child(t_firebox)

		# Pagoda roof with snow cap
		var t_roof := MeshInstance3D.new()
		t_roof.mesh = create_chamfered_box_mesh(Vector3(1.35, 0.35, 1.35), 0.15)
		t_roof.position.y = 2.95
		t_roof.material_override = mat_stone
		toro_root.add_child(t_roof)

		var t_snow := MeshInstance3D.new()
		t_snow.mesh = create_chamfered_box_mesh(Vector3(1.25, 0.22, 1.25), 0.10)
		t_snow.position.y = 3.18
		t_snow.material_override = mat_snow
		toro_root.add_child(t_snow)

	return root

# ==============================================================================
# 4. BIOME 4 — ENOSHIMA: PIER & SEA CANDLE LIGHTHOUSE (1,250M)
# ==============================================================================
func _build_enoshima_sea_candle() -> Node3D:
	var root := Node3D.new()
	root.name = "Landmark_Enoshima_SeaCandle"

	var timber_brown := Color("#8B5A2B")    # Boardwalk cedar planks
	var timber_dark := Color("#4A2E18")     # Heavy pilings
	var steel_white := Color("#F1F5F9")     # Inverted lattice steel
	var concrete_gray := Color("#94A3B8")   # Base terraces
	var glass_cyan := Color("#38BDF8")      # Observation gallery glass
	var beacon_amber := Color("#F59E0B")    # Lantern room & beam
	var lantern_glow := Color("#FFD166")    # Warm string lanterns

	var mat_boardwalk := get_landmark_mat(timber_brown, 0.035, false)
	var mat_piling := get_landmark_mat(timber_dark, 0.035, false)
	var mat_lattice := get_landmark_mat(steel_white, 0.040, false, Color("#94A3B8"))
	var mat_concrete := get_landmark_mat(concrete_gray, 0.040, false)
	var mat_glass := get_landmark_mat(glass_cyan, 0.030, true)
	var mat_beacon := get_landmark_mat(beacon_amber, 0.025, true)
	var mat_lantern := get_landmark_mat(lantern_glow, 0.020, true)

	# --- PART A: TIMBER-PLANKED COASTAL PIER (X = +9.5m to +24.0m beyond guardrail) ---
	var pier_root := Node3D.new()
	pier_root.name = "CoastalPier"
	pier_root.position = Vector3(16.5, 0.6, 0.0)
	root.add_child(pier_root)

	var pier_width: float = 14.0 # Extends 14m into ocean from X = +9.5m to +23.5m
	var pier_length: float = 45.0

	# Sub-component 1: Cross-Planked Wooden Boardwalk Deck
	var deck := MeshInstance3D.new()
	deck.mesh = create_chamfered_box_mesh(Vector3(pier_width, 0.35, pier_length), 0.08)
	deck.position.y = 0.0
	deck.material_override = mat_boardwalk
	pier_root.add_child(deck)

	# Sub-component 2: 12 Heavy Timber Pilings with Diagonal Cross-Bracing into waves
	var piling_xs: Array[float] = [-5.5, 0.0, 5.5]
	var piling_zs: Array[float] = [-18.0, -6.0, 6.0, 18.0]

	for px in piling_xs:
		for pz in piling_zs:
			var piling := MeshInstance3D.new()
			piling.mesh = create_tapered_column_mesh(Vector2(0.55, 0.55), Vector2(0.50, 0.50), 3.5)
			piling.position = Vector3(px, -3.2, pz)
			piling.material_override = mat_piling
			pier_root.add_child(piling)

	# Sub-component 3: Wooden Handrails & Rope Posts along Pier Edges
	for p_edge_x in [-pier_width * 0.48, pier_width * 0.48]:
		var rail := MeshInstance3D.new()
		rail.mesh = create_chamfered_box_mesh(Vector3(0.18, 0.15, pier_length), 0.04)
		rail.position = Vector3(p_edge_x, 1.1, 0.0)
		rail.material_override = mat_boardwalk
		pier_root.add_child(rail)

		for rz in range(-4, 5):
			var post := MeshInstance3D.new()
			post.mesh = create_chamfered_box_mesh(Vector3(0.16, 1.15, 0.16), 0.04)
			post.position = Vector3(p_edge_x, 0.55, float(rz) * 5.2)
			post.material_override = mat_piling
			pier_root.add_child(post)

	# Sub-component 4: Warm String-Lantern Wooden Posts
	for lz in [-14.0, 0.0, 14.0]:
		var l_post := MeshInstance3D.new()
		l_post.mesh = create_chamfered_box_mesh(Vector3(0.20, 2.6, 0.20), 0.05)
		l_post.position = Vector3(pier_width * 0.45, 1.3, lz)
		l_post.material_override = mat_piling
		pier_root.add_child(l_post)

		var lantern := MeshInstance3D.new()
		lantern.mesh = create_chamfered_box_mesh(Vector3(0.40, 0.55, 0.40), 0.10)
		lantern.position = Vector3(pier_width * 0.45 - 0.45, 2.4, lz)
		lantern.material_override = mat_lantern
		pier_root.add_child(lantern)

	# --- PART B: ENOSHIMA SEA CANDLE OBSERVATION LIGHTHOUSE (At X = +24.0m on Island Bluff) ---
	var candle_root := Node3D.new()
	candle_root.name = "SeaCandleLighthouse"
	candle_root.position = Vector3(24.0, 0.0, -8.0)
	root.add_child(candle_root)

	# Sub-component 5: Octagonal Multi-Tiered Concrete Base Deck (Stepped terrace)
	var base_tier1 := MeshInstance3D.new()
	base_tier1.mesh = create_chamfered_box_mesh(Vector3(16.0, 2.2, 16.0), 0.8)
	base_tier1.position.y = 1.1
	base_tier1.material_override = mat_concrete
	candle_root.add_child(base_tier1)

	var base_tier2 := MeshInstance3D.new()
	base_tier2.mesh = create_chamfered_box_mesh(Vector3(12.5, 1.8, 12.5), 0.6)
	base_tier2.position.y = 3.0
	base_tier2.material_override = mat_concrete
	candle_root.add_child(base_tier2)

	# Sub-component 6: Central Cylindrical Elevator / Utility Core (Diameter 3.2m, Height 30m)
	var core := MeshInstance3D.new()
	core.mesh = create_tapered_column_mesh(Vector2(3.2, 3.2), Vector2(3.0, 3.0), 28.0)
	core.position.y = 3.8
	core.material_override = mat_concrete
	candle_root.add_child(core)

	# Sub-component 7 & 8: Iconic Inverted-Cone Steel Lattice Tower Frame!
	# The signature Enoshima Sea Candle architecture: narrow at base (diameter 4.4m), expands outward to 9.2m at top!
	var tower_st := SurfaceTool.new()
	tower_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tower_height: float = 26.0
	var tower_base_y: float = 3.8
	var legs: int = 8
	var tiers: int = 5

	for t_idx in range(tiers):
		var y0: float = tower_base_y + (float(t_idx) / float(tiers)) * tower_height
		var y1: float = tower_base_y + (float(t_idx + 1) / float(tiers)) * tower_height
		# Inverted cone radius expansion!
		var r0: float = lerp(2.2, 4.6, float(t_idx) / float(tiers))
		var r1: float = lerp(2.2, 4.6, float(t_idx + 1) / float(tiers))

		for leg in range(legs):
			var a0: float = float(leg) / float(legs) * TAU
			var a1: float = float(leg + 1) / float(legs) * TAU
			var p0 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p2 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var p3 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)

			var n := (p1 - p0).cross(p3 - p0).normalized()
			# Outer perimeter ring strut
			_add_quad(tower_st, p0, p1, p2, p3, n, steel_white)
			# Crisscrossing diagonal X-strut
			_add_quad(tower_st, p0, p2, p1, p3, n, steel_white)

	var lattice_tower := MeshInstance3D.new()
	lattice_tower.mesh = tower_st.commit()
	lattice_tower.material_override = mat_lattice
	candle_root.add_child(lattice_tower)

	# Sub-component 9: Cantilevered Circular Glass Observation Gallery Ring (Diameter 11.2m at Y = 29.8m)
	var gallery_base := MeshInstance3D.new()
	gallery_base.mesh = create_chamfered_box_mesh(Vector3(11.5, 0.85, 11.5), 0.6)
	gallery_base.position.y = 29.8
	gallery_base.material_override = mat_concrete
	candle_root.add_child(gallery_base)

	var gallery_glass := MeshInstance3D.new()
	gallery_glass.mesh = create_chamfered_box_mesh(Vector3(10.8, 2.4, 10.8), 0.5)
	gallery_glass.position.y = 31.2
	gallery_glass.material_override = mat_glass
	candle_root.add_child(gallery_glass)

	var gallery_roof := MeshInstance3D.new()
	gallery_roof.mesh = create_chamfered_box_mesh(Vector3(11.8, 0.75, 11.8), 0.6)
	gallery_roof.position.y = 32.7
	gallery_roof.material_override = mat_lattice
	candle_root.add_child(gallery_roof)

	# Sub-component 10: Top Lantern Room & Beacon Cupola (Y = 33.5m to 37.0m)
	var cupola := MeshInstance3D.new()
	cupola.mesh = create_chamfered_box_mesh(Vector3(4.8, 2.8, 4.8), 0.4)
	cupola.position.y = 34.5
	cupola.material_override = mat_beacon
	candle_root.add_child(cupola)

	# Sub-component 11: Lightning Spire Mast extending to Y = 45m
	var spire_pts: Array[Vector3] = [
		Vector3(0.0, 36.0, 0.0),
		Vector3(0.0, 45.0, 0.0)
	]
	var spire := MeshInstance3D.new()
	spire.mesh = create_swept_tube_mesh(spire_pts, 0.14, 5, steel_white)
	spire.material_override = mat_lattice
	candle_root.add_child(spire)

	# Sub-component 12: Rotating Warm Lighthouse Light Beam
	lighthouse_beam = Node3D.new()
	lighthouse_beam.name = "LightBeamRoot"
	lighthouse_beam.position.y = 35.5
	candle_root.add_child(lighthouse_beam)

	# Create a conical beam mesh sweeping into sky
	var beam_st := SurfaceTool.new()
	beam_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beam_len: float = 120.0
	var beam_radius: float = 18.0
	var apex := Vector3.ZERO

	for bs in range(12):
		var ba0: float = float(bs) / 12.0 * TAU
		var ba1: float = float(bs + 1) / 12.0 * TAU
		var bp0 := Vector3(cos(ba0) * beam_radius, sin(ba0) * beam_radius * 0.45, -beam_len)
		var bp1 := Vector3(cos(ba1) * beam_radius, sin(ba1) * beam_radius * 0.45, -beam_len)
		beam_st.set_normal(Vector3.FORWARD)
		beam_st.set_uv(Vector2(0, 0)); beam_st.add_vertex(apex)
		beam_st.set_uv(Vector2(1, 0)); beam_st.add_vertex(bp0)
		beam_st.set_uv(Vector2(1, 1)); beam_st.add_vertex(bp1)

	var beam_mesh := MeshInstance3D.new()
	beam_mesh.mesh = beam_st.commit()
	beam_mesh.material_override = get_beam_mat()
	# Tilt beam slightly downward toward horizon
	beam_mesh.rotation.x = deg_to_rad(-8.0)
	lighthouse_beam.add_child(beam_mesh)

	return root

# ==============================================================================
# INITIALIZATION & POOLING
# ==============================================================================
func _build_all_landmarks() -> void:
	landmark_shuto = _build_shuto_rainbow_bridge()
	landmark_shuto.visible = false
	add_child(landmark_shuto)

	landmark_shinjuku = _build_neo_shinjuku_kabukicho()
	landmark_shinjuku.visible = false
	add_child(landmark_shinjuku)

	landmark_hakone = _build_hakone_torii_overlook()
	landmark_hakone.visible = false
	add_child(landmark_hakone)

	landmark_enoshima = _build_enoshima_sea_candle()
	landmark_enoshima.visible = false
	add_child(landmark_enoshima)

# ==============================================================================
# RUNTIME UPDATE & BIOME ISOLATION
# ==============================================================================
func update(
	player_z: float,
	stage_start_z: float,
	current_biome: String,
	fork_active: bool,
	delta: float
) -> void:
	# Continuous train and lighthouse animation
	if is_instance_valid(monorail_train):
		monorail_train_t += delta * 18.0 # 18 m/s commuter speed
		# Loop train position along guideway between -35m and +35m
		monorail_train.position.x = wrapf(monorail_train_t, -35.0, 35.0)

	if is_instance_valid(lighthouse_beam):
		lighthouse_angle += delta * 0.85 # Gentle atmospheric rotation
		lighthouse_beam.rotation.y = lighthouse_angle

	# Clean Biome Isolation & Fork Suppression (Directive Section 5):
	# Immediately despawn upon entering any 2,500m tunnel fork or during transition
	var stage_dist: float = abs(player_z - stage_start_z)
	if fork_active or stage_dist >= 2380.0:
		_hide_all_landmarks()
		return

	# Landmark target Z is strictly at 1,250m mark of current biome stage
	var target_landmark_z: float = stage_start_z - 1250.0
	var dist_to_landmark: float = player_z - target_landmark_z # positive = approaching, negative = past

	# Active window: visible from 450m ahead down to 150m behind player camera
	var in_view_window: bool = (dist_to_landmark <= 450.0 and dist_to_landmark >= -150.0)

	if not in_view_window:
		_hide_all_landmarks()
		return

	# Show only the current biome's landmark, hide all others
	_show_biome_landmark(current_biome, target_landmark_z)

func _show_biome_landmark(biome: String, target_z: float) -> void:
	if current_active_biome != biome:
		_hide_all_landmarks()
		current_active_biome = biome

	var active_node: Node3D = null
	match biome:
		"shuto_dusk":
			active_node = landmark_shuto
		"neo_shinjuku":
			active_node = landmark_shinjuku
		"hakone_snow":
			active_node = landmark_hakone
		"enoshima_coast":
			active_node = landmark_enoshima

	if not is_instance_valid(active_node):
		return

	# Align landmark position with road center
	var road_cx: float = 0.0
	if sample_road_x_cb.is_valid():
		road_cx = sample_road_x_cb.call(target_z)

	var road_tan := Vector3.FORWARD
	if sample_road_tangent_cb.is_valid():
		road_tan = sample_road_tangent_cb.call(target_z)

	active_node.position = Vector3(road_cx, 0.0, target_z)
	var yaw: float = atan2(-road_tan.x, -road_tan.z)
	active_node.rotation.y = yaw

	if not active_node.visible:
		active_node.visible = true

func _hide_all_landmarks() -> void:
	if is_instance_valid(landmark_shuto): landmark_shuto.visible = false
	if is_instance_valid(landmark_shinjuku): landmark_shinjuku.visible = false
	if is_instance_valid(landmark_hakone): landmark_hakone.visible = false
	if is_instance_valid(landmark_enoshima): landmark_enoshima.visible = false
	current_active_biome = ""

func on_biome_transition(_new_biome: String) -> void:
	_hide_all_landmarks()

func purge() -> void:
	_hide_all_landmarks()
