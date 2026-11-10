extends SceneTree

func _init():
	var scn = load("res://assets/vehicles/traffic/muscle.fbx")
	var node = scn.instantiate()
	print("MUSCLE SCENE DUMP:")
	_dump_node(node, 0)
	quit()

func _dump_node(n: Node, depth: int):
	var ind = ""
	for i in range(depth):
		ind += "  "
	print(ind, n.name, " (", n.get_class(), ")")
	if n is MeshInstance3D:
		var mi = n as MeshInstance3D
		if mi.mesh:
			print(ind, "  Mesh: ", mi.mesh.get_class(), " surfaces: ", mi.mesh.get_surface_count())
			for s in range(mi.mesh.get_surface_count()):
				var mat = mi.mesh.surface_get_material(s)
				var mat_name = mat.resource_name if mat else "null"
				print(ind, "    Slot ", s, ": ", mat_name)
	for c in n.get_children():
		_dump_node(c, depth + 1)
