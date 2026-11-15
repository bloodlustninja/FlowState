class_name BiomeAssetFactory
extends RefCounted

# ==============================================================================
# FLOWSTATE: MASTER PROCEDURAL BIOME COMPOUND ASSET FACTORY
# Builds multi-part compound 3D meshes using manga_env.gdshader + 
# Inverted-Hull Black Ink Outlines (0.035m). Zero single-primitive placeholders.
# ==============================================================================

static var _env_shader: Shader
static var _outline_shader: Shader
static var _mat_cache: Dictionary = {}

static func get_env_mat(base_color: Color, outline_w: float = 0.035, is_emissive: bool = false, emission_color: Color = Color.BLACK, emission_energy: float = 0.0) -> ShaderMaterial:
	var key: String = "%s_%f_%d_%s_%f" % [base_color.to_html(), outline_w, int(is_emissive), emission_color.to_html(), emission_energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	
	if not _env_shader:
		_env_shader = load("res://shaders/manga_env.gdshader")
	if not _outline_shader:
		_outline_shader = load("res://shaders/manga_env_outline.gdshader")
		
	var mat := ShaderMaterial.new()
	mat.shader = _env_shader
	mat.set_shader_parameter("albedo_tint", base_color)
	mat.set_shader_parameter("use_vertex_color", false)
	
	if is_emissive and emission_energy > 0.0:
		# For glowing neon/lanterns, set unshaded emission
		mat.set_shader_parameter("shadow_tint", base_color)
	
	var out_mat := ShaderMaterial.new()
	out_mat.shader = _outline_shader
	out_mat.set_shader_parameter("outline_width", outline_w)
	out_mat.set_shader_parameter("outline_color", Color("#090B10"))
	mat.next_pass = out_mat
	
	_mat_cache[key] = mat
	return mat

static func get_unshaded_glow_mat(color: Color, energy: float = 1.15) -> StandardMaterial3D:
	var key := "glow_" + color.to_html() + "_" + str(energy)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	_mat_cache[key] = mat
	return mat

# ==============================================================================
# 1. NEO-SHINJUKU ALLEY COMPOUND PROPS
# ==============================================================================

# Archetype 1: Izakaya Shopfront (awning, chochin lanterns, noren curtains, menu board)
static func build_izakaya_shopfront() -> Node3D:
	var root := Node3D.new()
	root.name = "IzakayaShopfront"
	
	# Sloped tiled wooden awning
	var awning_mesh := BoxMesh.new()
	awning_mesh.size = Vector3(4.8, 0.16, 1.6)
	var awning_inst := MeshInstance3D.new()
	awning_inst.mesh = awning_mesh
	awning_inst.material_override = get_env_mat(Color("#241A14")) # Dark cedar
	awning_inst.position = Vector3(0.0, 3.4, 0.7)
	awning_inst.rotation.x = deg_to_rad(14.0)
	root.add_child(awning_inst)
	
	# Awning support diagonal timber brackets
	for side in [-1.9, 1.9]:
		var brk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.85, 0.12)
		brk.mesh = bm
		brk.material_override = get_env_mat(Color("#1A120E"))
		brk.position = Vector3(side, 3.1, 0.45)
		brk.rotation.x = deg_to_rad(45.0)
		root.add_child(brk)
	
	# 3 Hanging Glowing Warm Paper Chochin Lanterns (#FFB703)
	for i in range(3):
		var lx: float = -1.35 + float(i) * 1.35
		var lantern_rig := Node3D.new()
		lantern_rig.position = Vector3(lx, 2.7, 1.15)
		
		# Cord
		var cord := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.015; cm.bottom_radius = 0.015; cm.height = 0.25
		cord.mesh = cm
		cord.material_override = get_env_mat(Color("#0B0B0E"), 0.01)
		cord.position = Vector3(0.0, 0.28, 0.0)
		lantern_rig.add_child(cord)
		
		# Paper Lantern Body (warm amber #FFB703 glow)
		var l_inst := MeshInstance3D.new()
		var l_mesh := CylinderMesh.new()
		l_mesh.top_radius = 0.22; l_mesh.bottom_radius = 0.20; l_mesh.height = 0.58; l_mesh.radial_segments = 10
		l_inst.mesh = l_mesh
		l_inst.material_override = get_unshaded_glow_mat(Color("#FFB703"), 1.25)
		lantern_rig.add_child(l_inst)
		
		# Black caps
		for cap_y in [-0.29, 0.29]:
			var cap := MeshInstance3D.new()
			var cpm := CylinderMesh.new()
			cpm.top_radius = 0.16; cpm.bottom_radius = 0.16; cpm.height = 0.05
			cap.mesh = cpm
			cap.material_override = get_env_mat(Color("#111317"))
			cap.position = Vector3(0.0, cap_y, 0.0)
			lantern_rig.add_child(cap)
			
		root.add_child(lantern_rig)
		
	# Fabric Noren Curtains (navy/crimson segmented hanging panels)
	var noren_mesh := BoxMesh.new()
	noren_mesh.size = Vector3(2.6, 0.75, 0.04)
	var noren_inst := MeshInstance3D.new()
	noren_inst.mesh = noren_mesh
	noren_inst.material_override = get_env_mat(Color("#1E3A5F")) # Traditional navy indigo
	noren_inst.position = Vector3(0.0, 2.45, 0.15)
	root.add_child(noren_inst)
	
	# Wooden Menu A-Frame Stand on sidewalk
	var menu_stand := Node3D.new()
	menu_stand.position = Vector3(1.85, 0.52, 1.2)
	menu_stand.rotation.y = deg_to_rad(-20.0)
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.55, 0.95, 0.05)
		leg.mesh = lm
		leg.material_override = get_env_mat(Color("#2A1E16"))
		leg.rotation.x = deg_to_rad(side * 14.0)
		menu_stand.add_child(leg)
	# Chalkboard face
	var board := MeshInstance3D.new()
	var bdm := QuadMesh.new()
	bdm.size = Vector2(0.45, 0.75)
	board.mesh = bdm
	board.material_override = get_env_mat(Color("#111318"))
	board.position = Vector3(0.0, 0.0, 0.14)
	board.rotation.x = deg_to_rad(-14.0)
	menu_stand.add_child(board)
	root.add_child(menu_stand)
	
	return root

# Archetype 2: Konbini Storefront + Twin Vending Machines
static func build_konbini_storefront() -> Node3D:
	var root := Node3D.new()
	root.name = "KonbiniStorefront"
	
	# Illuminated Cyan-Green Fascia Sign
	var fascia := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(6.2, 0.95, 0.25)
	fascia.mesh = fm
	fascia.material_override = get_unshaded_glow_mat(Color("#059669"), 1.2) # Emerald Konbini Green
	fascia.position = Vector3(0.0, 3.8, 0.2)
	root.add_child(fascia)
	
	# 3-Pane Divided Glass Storefront with dark steel mullions & warm interior shelves
	var win_center := Vector3(0.0, 1.7, 0.1)
	var win_frame := MeshInstance3D.new()
	var wfm := BoxMesh.new()
	wfm.size = Vector3(5.6, 2.6, 0.12)
	win_frame.mesh = wfm
	win_frame.material_override = get_env_mat(Color("#151821")) # Dark steel
	win_frame.position = win_center
	root.add_child(win_frame)
	
	# Warm interior glass panes
	for p in range(3):
		var px: float = -1.7 + float(p) * 1.7
		var pane := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.5, 2.3, 0.08)
		pane.mesh = pm
		pane.material_override = get_unshaded_glow_mat(Color("#FDE68A"), 0.55) # Warm interior peach
		pane.position = win_center + Vector3(px, 0.0, 0.04)
		root.add_child(pane)
		
		# Shelf silhouettes inside
		for s in range(3):
			var shelf := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(1.4, 0.06, 0.06)
			shelf.mesh = sm
			shelf.material_override = get_env_mat(Color("#12141C"))
			shelf.position = win_center + Vector3(px, -0.6 + float(s) * 0.55, 0.06)
			root.add_child(shelf)
			
	return root

# Archetype 3: Zakkyo Retro Apartment Details (Balconies, AC Compressors, Conduit Pipes)
static func build_zakkyo_apartment_details(w: float, h: float) -> Node3D:
	var root := Node3D.new()
	root.name = "ZakkyoDetails"
	
	# 3D Extruded Balconies with black metal railings
	var floors: int = int(h / 3.8)
	for fl in range(1, floors):
		var fy: float = float(fl) * 3.8
		for bx in [-w * 0.28, w * 0.28]:
			var balc_slab := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(2.4, 0.25, 1.1)
			balc_slab.mesh = bm
			balc_slab.material_override = get_env_mat(Color("#1E222D"))
			balc_slab.position = Vector3(bx, fy, 0.55)
			root.add_child(balc_slab)
			
			# Balcony black metal safety railing
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(2.4, 0.95, 0.05)
			rail.mesh = rm
			rail.material_override = get_env_mat(Color("#0B0D12"), 0.02)
			rail.position = Vector3(bx, fy + 0.52, 1.05)
			root.add_child(rail)
			
			# Wall-Mounted AC Compressor Box
			var ac := MeshInstance3D.new()
			var acm := BoxMesh.new()
			acm.size = Vector3(0.68, 0.52, 0.38)
			ac.mesh = acm
			ac.material_override = get_env_mat(Color("#B0B8C4")) # Light grey casing
			ac.position = Vector3(bx - 0.7, fy + 0.38, 0.35)
			root.add_child(ac)
			
			# AC fan circular grille
			var ac_fan := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.18; fm.bottom_radius = 0.18; fm.height = 0.04; fm.radial_segments = 8
			ac_fan.mesh = fm
			ac_fan.material_override = get_env_mat(Color("#1A1D24"))
			ac_fan.rotation.x = deg_to_rad(90.0)
			ac_fan.position = ac.position + Vector3(0.12, 0.0, 0.20)
			root.add_child(ac_fan)
			
	# External vertical drainage / conduit pipes
	for px in [-w * 0.48, w * 0.48]:
		var pipe := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.08; pm.bottom_radius = 0.08; pm.height = h; pm.radial_segments = 6
		pipe.mesh = pm
		pipe.material_override = get_env_mat(Color("#1C2029"))
		pipe.position = Vector3(px, h * 0.5, 0.12)
		root.add_child(pipe)
		
	return root

# Archetype 4: Overhead Pedestrian Steel Skybridge spanning across street
static func build_pedestrian_skybridge(span_width: float = 14.5) -> Node3D:
	var bridge := Node3D.new()
	bridge.name = "Skybridge"
	
	# Main enclosed walkway box (elevated at Y = 7.5m)
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(span_width + 4.0, 0.4, 3.2)
	var deck := MeshInstance3D.new()
	deck.mesh = deck_mesh
	deck.material_override = get_env_mat(Color("#1E222D"))
	deck.position = Vector3(0.0, 7.2, 0.0)
	bridge.add_child(deck)
	
	# Glass enclosed sides
	for side_z in [-1.5, 1.5]:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(span_width + 4.0, 1.8, 0.08)
		wall.mesh = wm
		wall.material_override = get_unshaded_glow_mat(Color("#00E5FF"), 0.35)
		wall.position = Vector3(0.0, 8.2, side_z)
		bridge.add_child(wall)
		
	# Roof
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(span_width + 4.2, 0.3, 3.4)
	roof.mesh = rm
	roof.material_override = get_env_mat(Color("#161922"))
	roof.position = Vector3(0.0, 9.2, 0.0)
	bridge.add_child(roof)
	
	return bridge

# Neo-Shinjuku Road Obstacle: Double-Parked Kei Delivery Van + Steam Manhole
static func build_shinjuku_obstacle_kei_van(lane_x: float = 0.0, global_z: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Obstacle_KeiVan"
	root.position = Vector3(lane_x, 0.0, global_z)
	
	# Boxy Kei Van Body (White #F8FAFC with Blue stripe #2563EB)
	var van_mesh := BoxMesh.new()
	van_mesh.size = Vector3(1.48, 1.85, 3.3)
	var van := MeshInstance3D.new()
	van.mesh = van_mesh
	van.material_override = get_env_mat(Color("#F1F5F9"))
	van.position = Vector3(0.0, 1.05, 0.0)
	root.add_child(van)
	
	# Blue commercial lower band
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(1.50, 0.45, 3.32)
	var band := MeshInstance3D.new()
	band.mesh = band_mesh
	band.material_override = get_env_mat(Color("#2563EB"))
	band.position = Vector3(0.0, 0.45, 0.0)
	root.add_child(band)
	
	# Blinking Amber Hazard Lights
	for hx in [-0.62, 0.62]:
		var haz := MeshInstance3D.new()
		haz.name = "HazardLight"
		var hm := BoxMesh.new()
		hm.size = Vector3(0.18, 0.12, 0.08)
		haz.mesh = hm
		haz.material_override = get_unshaded_glow_mat(Color("#FF9500"), 2.2) # High emission hazard amber
		haz.position = Vector3(hx, 0.85, 1.66)
		root.add_child(haz)
		
	# Stacked Plastic Crates on sidewalk/road edge
	for ci in range(3):
		var crate := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.55, 0.38, 0.45)
		crate.mesh = cm
		var col: Color = Color("#2563EB") if ci % 2 == 0 else Color("#F59E0B")
		crate.material_override = get_env_mat(col)
		crate.position = Vector3(0.95, 0.19 + float(ci) * 0.38, 0.8)
		root.add_child(crate)
		
	# Red metal hand-truck leaning against crates
	var ht := Node3D.new()
	ht.name = "HandTruck"
	ht.position = Vector3(1.15, 0.0, 0.3)
	ht.rotation.z = deg_to_rad(-12.0)
	var ht_frame := MeshInstance3D.new()
	var htf_m := BoxMesh.new()
	htf_m.size = Vector3(0.06, 1.25, 0.38)
	ht_frame.mesh = htf_m
	ht_frame.material_override = get_env_mat(Color("#DC2626")) # Bold red hand-truck
	ht_frame.position = Vector3(0.0, 0.62, 0.0)
	ht.add_child(ht_frame)
	# Wheels
	for wz in [-0.18, 0.18]:
		var wh := MeshInstance3D.new()
		var wh_m := CylinderMesh.new()
		wh_m.top_radius = 0.10; wh_m.bottom_radius = 0.10; wh_m.height = 0.05
		wh.mesh = wh_m
		wh.material_override = get_env_mat(Color("#111827"))
		wh.position = Vector3(-0.06, 0.10, wz)
		wh.rotation.x = deg_to_rad(90.0)
		ht.add_child(wh)
	root.add_child(ht)
	
	return root

# Neo-Shinjuku Road Obstacle 2: Cast-Iron Steam Manhole Grate
static func build_steam_manhole() -> Node3D:
	var root := Node3D.new()
	root.name = "SteamManholeGrate"
	
	# Cast-Iron Grate
	var manhole := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.48; mm.bottom_radius = 0.48; mm.height = 0.03; mm.radial_segments = 14
	manhole.mesh = mm
	manhole.material_override = get_env_mat(Color("#1E222D"), 0.02)
	manhole.position = Vector3(0.0, 0.015, 0.0)
	root.add_child(manhole)
	
	# Inked grate slit ribs
	for r in range(4):
		var rib := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.04, 0.035, 0.72)
		rib.mesh = rm
		rib.material_override = get_env_mat(Color("#090B10"), 0.01)
		rib.position = Vector3(-0.24 + float(r) * 0.16, 0.018, 0.0)
		root.add_child(rib)
		
	# 3 Rising Comic Steam Puffs (semi-translucent white plumes)
	for s in range(3):
		var steam := MeshInstance3D.new()
		steam.name = "SteamPlume_" + str(s)
		var sm := QuadMesh.new()
		sm.size = Vector2(0.65 + float(s) * 0.25, 0.95 + float(s) * 0.35)
		sm.orientation = PlaneMesh.FACE_Y
		steam.mesh = sm
		var s_mat := StandardMaterial3D.new()
		s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s_mat.albedo_color = Color(0.95, 0.97, 1.0, 0.35 - float(s) * 0.08)
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		steam.material_override = s_mat
		steam.position = Vector3((randf() - 0.5) * 0.2, 0.35 + float(s) * 0.55, (randf() - 0.5) * 0.2)
		root.add_child(steam)
		
	return root

# ==============================================================================
# 2. HAKONE SNOW PEAKS COMPOUND PROPS
# ==============================================================================

# Multi-Tiered Compound Snow Pine Conifer (5 jagged star-skirt bough tiers)
static func build_hakone_snow_conifer(scale_factor: float = 1.0) -> Node3D:
	var tree := Node3D.new()
	tree.name = "HakoneSnowPine"
	var s: float = clampf(scale_factor, 0.85, 1.35)
	
	# Cedar Trunk
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.18 * s; tm.bottom_radius = 0.32 * s; tm.height = 2.4 * s; tm.radial_segments = 8
	trunk.mesh = tm
	trunk.material_override = get_env_mat(Color("#2B1E1A")) # Cedar bark
	trunk.position = Vector3(0.0, 1.2 * s, 0.0)
	tree.add_child(trunk)
	
	# 5 Jagged Rotated Star-Skirt Bough Tiers
	var tier_radii := [2.3, 1.85, 1.45, 1.05, 0.65]
	var tier_heights := [1.5, 2.7, 3.9, 5.1, 6.3]
	
	for t in range(5):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var b_rad: float = tier_radii[t] * s
		var b_y: float = tier_heights[t] * s
		var apex := Vector3(0.0, b_y + 1.2 * s, 0.0)
		var num_pts: int = 8
		var rot_offset: float = float(t) * 0.42
		
		# Build multi-pointed jagged star vertices
		var bough_verts: Array[Vector3] = []
		for p in range(num_pts):
			var ang: float = rot_offset + float(p) * (TAU / float(num_pts))
			var r_mult: float = 1.0 if (p % 2 == 0) else 0.62
			var vx: float = cos(ang) * b_rad * r_mult
			var vz: float = sin(ang) * b_rad * r_mult
			var vy: float = b_y - (0.35 * s if (p % 2 == 0) else 0.15 * s)
			bough_verts.append(Vector3(vx, vy, vz))
			
		# Top snow-capped facets (#F8FAFC sunlit snow / #BAE6FD shadow)
		for p in range(num_pts):
			var p_next: int = (p + 1) % num_pts
			var v0 := bough_verts[p]
			var v1 := bough_verts[p_next]
			
			# Snow Top Slope
			st.set_color(Color("#F8FAFC"))
			st.set_normal((v0 + v1 + apex).normalized())
			st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(apex)
			
			# Dark Needle Underside (#143627)
			var base_center := Vector3(0.0, b_y - 0.2 * s, 0.0)
			st.set_color(Color("#143627"))
			st.set_normal(Vector3.DOWN)
			st.add_vertex(v1); st.add_vertex(v0); st.add_vertex(base_center)
			
		st.generate_normals()
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = st.commit()
		mesh_inst.material_override = get_env_mat(Color.WHITE, 0.038)
		tree.add_child(mesh_inst)
		
	return tree

# Red-and-White Striped Snow-Depth Marker Pole (Yuki-furi pole)
static func build_snow_depth_pole() -> Node3D:
	var pole := Node3D.new()
	pole.name = "SnowDepthPole"
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg_h: float = 0.55
	for seg in range(6):
		var y0: float = float(seg) * seg_h
		var y1: float = y0 + seg_h
		var col: Color = Color("#DC2626") if (seg % 2 == 1) else Color("#F8FAFC")
		# Cylinder segment
		for p in range(6):
			var a0: float = float(p) * (TAU / 6.0)
			var a1: float = float(p + 1) * (TAU / 6.0)
			var r: float = 0.045
			var v00 := Vector3(cos(a0) * r, y0, sin(a0) * r)
			var v10 := Vector3(cos(a1) * r, y0, sin(a1) * r)
			var v01 := Vector3(cos(a0) * r, y1, sin(a0) * r)
			var v11 := Vector3(cos(a1) * r, y1, sin(a1) * r)
			st.set_color(col)
			st.add_vertex(v00); st.add_vertex(v10); st.add_vertex(v01)
			st.add_vertex(v10); st.add_vertex(v11); st.add_vertex(v01)
	st.generate_normals()
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = get_env_mat(Color.WHITE, 0.035)
	pole.add_child(inst)
	return pole

# Hakone Road Obstacle 1: Black-Ice Apex Patch
static func build_black_ice_patch(length: float = 24.0, width: float = 3.6) -> MeshInstance3D:
	var ice := MeshInstance3D.new()
	ice.name = "BlackIcePatch"
	var pm := PlaneMesh.new()
	pm.size = Vector2(width, length)
	ice.mesh = pm
	# Glossy pale-cyan ice with unshaded white sheen streaks
	var ice_mat := StandardMaterial3D.new()
	ice_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ice_mat.albedo_color = Color(0.73, 0.90, 0.99, 0.85) # Pale ice blue #BAE6FD
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.material_override = ice_mat
	return ice

# Hakone Road Obstacle 2: Plowed Snowbank Drift (1.2m into shoulder)
static func build_plowed_snowbank(length: float = 18.0) -> Node3D:
	var bank := Node3D.new()
	bank.name = "PlowedSnowbank"
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = int(length / 2.0)
	for s in range(steps):
		var z0: float = -float(s) * 2.0
		var z1: float = -float(s + 1) * 2.0
		var w_ext: float = 1.25 + sin(float(s) * 0.8) * 0.25
		var h_ext: float = 0.85 + cos(float(s) * 0.6) * 0.2
		
		var v0_road := Vector3(0.0, 0.0, z0)
		var v1_road := Vector3(0.0, 0.0, z1)
		var v0_crest := Vector3(w_ext * 0.6, h_ext, z0)
		var v1_crest := Vector3(w_ext * 0.6, h_ext, z1)
		var v0_back := Vector3(w_ext * 1.2, 0.0, z0)
		var v1_back := Vector3(w_ext * 1.2, 0.0, z1)
		
		st.set_color(Color("#F8FAFC")) # Bright snow cap
		st.add_vertex(v0_road); st.add_vertex(v1_road); st.add_vertex(v0_crest)
		st.add_vertex(v1_road); st.add_vertex(v1_crest); st.add_vertex(v0_crest)
		
		st.set_color(Color("#BAE6FD")) # Ice-blue shadow flank
		st.add_vertex(v0_crest); st.add_vertex(v1_crest); st.add_vertex(v0_back)
		st.add_vertex(v1_crest); st.add_vertex(v1_back); st.add_vertex(v0_back)
		
	st.generate_normals()
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = get_env_mat(Color.WHITE, 0.035)
	bank.add_child(inst)
	
	# Red/white snow-depth marker poles mounted along the snowbank
	for pz in [-3.0, -15.0]:
		var pole := build_snow_depth_pole()
		pole.position = Vector3(0.75, 0.70, pz)
		bank.add_child(pole)
		
	return bank

# ==============================================================================
# 3. ENOSHIMA SEASIDE COAST COMPOUND PROPS
# ==============================================================================

# Curved Multi-Frond Palm Tree (segmented curved trunk + 7 serrated frond blades)
static func build_curved_palm_tree(scale_factor: float = 1.0) -> Node3D:
	var palm := Node3D.new()
	palm.name = "CurvedPalmTree"
	var s: float = clampf(scale_factor, 0.85, 1.35)
	
	# Segmented Curved Trunk
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg_count: int = 7
	var trunk_pts: Array[Vector3] = []
	for i in range(seg_count + 1):
		var t: float = float(i) / float(seg_count)
		var ty: float = t * 6.5 * s
		var tx: float = sin(t * 1.2) * 1.4 * s # Gentle natural coastal curve
		trunk_pts.append(Vector3(tx, ty, 0.0))
		
	for i in range(seg_count):
		var p0: Vector3 = trunk_pts[i]
		var p1: Vector3 = trunk_pts[i + 1]
		var r0: float = lerp(0.32 * s, 0.16 * s, float(i) / float(seg_count))
		var r1: float = lerp(0.32 * s, 0.16 * s, float(i + 1) / float(seg_count))
		var col: Color = Color("#78350F") if (i % 2 == 0) else Color("#92400E") # Bark rings
		
		for a in range(6):
			var a0: float = float(a) * (TAU / 6.0)
			var a1: float = float(a + 1) * (TAU / 6.0)
			var v00 := p0 + Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
			var v10 := p0 + Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
			var v01 := p1 + Vector3(cos(a0) * r1, 0.0, sin(a0) * r1)
			var v11 := p1 + Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)
			st.set_color(col)
			st.add_vertex(v00); st.add_vertex(v10); st.add_vertex(v01)
			st.add_vertex(v10); st.add_vertex(v11); st.add_vertex(v01)
			
	st.generate_normals()
	var trunk_inst := MeshInstance3D.new()
	trunk_inst.mesh = st.commit()
	trunk_inst.material_override = get_env_mat(Color.WHITE, 0.035)
	palm.add_child(trunk_inst)
	
	# 7 Arched Serrated Frond Blades at top
	var top_pos: Vector3 = trunk_pts[seg_count]
	var frond_st := SurfaceTool.new()
	frond_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for f in range(7):
		var base_ang: float = float(f) * (TAU / 7.0)
		var f_dir := Vector3(cos(base_ang), 0.0, sin(base_ang))
		var frond_len: float = 3.2 * s
		
		var f0 := top_pos
		var f1 := top_pos + (f_dir * (frond_len * 0.55)) + Vector3(0.0, 0.6 * s, 0.0)
		var f2 := top_pos + (f_dir * frond_len) - Vector3(0.0, 1.2 * s, 0.0)
		
		var perp := f_dir.cross(Vector3.UP).normalized() * 0.65 * s
		
		frond_st.set_color(Color("#15803D")) # Vibrant coastal palm green
		frond_st.add_vertex(f0); frond_st.add_vertex(f1 + perp); frond_st.add_vertex(f1)
		frond_st.add_vertex(f0); frond_st.add_vertex(f1); frond_st.add_vertex(f1 - perp)
		frond_st.set_color(Color("#166534")) # Shaded underside
		frond_st.add_vertex(f1); frond_st.add_vertex(f1 + perp); frond_st.add_vertex(f2)
		frond_st.add_vertex(f1); frond_st.add_vertex(f2); frond_st.add_vertex(f1 - perp)
		
	frond_st.generate_normals()
	var fronds_inst := MeshInstance3D.new()
	fronds_inst.mesh = frond_st.commit()
	fronds_inst.material_override = get_env_mat(Color.WHITE, 0.038)
	palm.add_child(fronds_inst)
	
	return palm

# Concrete Wave-Breaker Tetrapod
static func build_tetrapod(scale_factor: float = 1.0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = "Tetrapod"
	var s: float = scale_factor
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirs := [
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.9428, -0.3333, 0.0),
		Vector3(-0.4714, -0.3333, 0.8165),
		Vector3(-0.4714, -0.3333, -0.8165)
	]
	var arm_len: float = 1.35 * s
	var r_base: float = 0.42 * s
	var r_tip: float = 0.26 * s
	
	for d in dirs:
		var tip: Vector3 = d * arm_len
		var side_u: Vector3 = d.cross(Vector3.UP if abs(d.y) < 0.9 else Vector3.RIGHT).normalized()
		var side_v: Vector3 = d.cross(side_u).normalized()
		for a in range(6):
			var a0: float = float(a) * (TAU / 6.0)
			var a1: float = float(a + 1) * (TAU / 6.0)
			var b0: Vector3 = (side_u * cos(a0) + side_v * sin(a0)) * r_base
			var b1: Vector3 = (side_u * cos(a1) + side_v * sin(a1)) * r_base
			var t0: Vector3 = tip + (side_u * cos(a0) + side_v * sin(a0)) * r_tip
			var t1: Vector3 = tip + (side_u * cos(a1) + side_v * sin(a1)) * r_tip
			st.set_color(Color("#64748B")) # Light grey weathered concrete
			st.add_vertex(b0); st.add_vertex(b1); st.add_vertex(t0)
			st.add_vertex(b1); st.add_vertex(t1); st.add_vertex(t0)
			st.add_vertex(tip); st.add_vertex(t0); st.add_vertex(t1) # Tip cap
			
	st.generate_normals()
	inst.mesh = st.commit()
	inst.material_override = get_env_mat(Color.WHITE, 0.035)
	return inst

# Enoshima Road Obstacle 1: Windblown Beach Sand Drift
static func build_beach_sand_drift(length: float = 14.0, encroaching_width: float = 1.4) -> MeshInstance3D:
	var sand := MeshInstance3D.new()
	sand.name = "BeachSandDrift"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var steps: int = int(length / 1.5)
	for i in range(steps):
		var z0: float = -float(i) * 1.5
		var z1: float = -float(i + 1) * 1.5
		var w0: float = sin(float(i) / float(steps) * PI) * encroaching_width
		var w1: float = sin(float(i + 1) / float(steps) * PI) * encroaching_width
		
		var v00 := Vector3(0.0, 0.03, z0)
		var v01 := Vector3(w0, 0.06, z0)
		var v10 := Vector3(0.0, 0.03, z1)
		var v11 := Vector3(w1, 0.06, z1)
		
		st.set_color(Color("#FDE68A")) # Golden beach sand
		st.add_vertex(v00); st.add_vertex(v01); st.add_vertex(v10)
		st.add_vertex(v01); st.add_vertex(v11); st.add_vertex(v10)
		
	st.generate_normals()
	sand.mesh = st.commit()
	sand.material_override = get_env_mat(Color.WHITE, 0.035)
	return sand

# Enoshima Road Obstacle 2: Decorate Cruising Surf Camper Van with Roof Rack & Surfboards
static func decorate_surf_camper(root: Node3D, is_coral: bool = false) -> void:
	if not root: return
	
	# Two colorful surfboards strapped to roof rack
	var colors := [Color("#06B6D4"), Color("#F43F5E")] if is_coral else [Color("#10B981"), Color("#FBBF24")]
	for i in range(2):
		var sb := MeshInstance3D.new()
		var sbm := BoxMesh.new()
		sbm.size = Vector3(0.48, 0.08, 2.3)
		sb.mesh = sbm
		sb.material_override = get_env_mat(colors[i])
		sb.position = Vector3(-0.35 + float(i) * 0.70, 2.25, 0.0)
		sb.rotation.x = deg_to_rad(-6.0)
		root.add_child(sb)
		
	# Roof rack rails
	for rx in [-0.55, 0.55]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.05, 0.06, 2.6)
		rail.mesh = rm
		rail.material_override = get_env_mat(Color("#1E222D"))
		rail.position = Vector3(rx, 2.18, 0.0)
		root.add_child(rail)
