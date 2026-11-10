extends SceneTree

func _init():
	var scn = load("res://assets/vehicles/player/player_racer.fbx")
	if not scn:
		print("Failed to load player_racer.fbx")
		quit()
		return
	var inst = scn.instantiate()
	_dump(inst, 0)
	quit()

func _dump(node: Node, depth: int):
	var indent = ""
	for i in range(depth):
		indent += "  "
	var extra = ""
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		if mi.mesh:
			extra = " [Mesh: %s, surfaces=%d]" % [mi.mesh.get_class(), mi.mesh.get_surface_count()]
			for s in range(mi.mesh.get_surface_count()):
				var mat = mi.mesh.surface_get_material(s)
				var mat_name = mat.resource_name if mat else "null"
				extra += "\n" + indent + "   surf %d: %s" % [s, mat_name]
	print(indent + node.name + " (" + node.get_class() + ")" + extra)
	for c in node.get_children():
		_dump(c, depth + 1)
