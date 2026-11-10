extends SceneTree

func _init():
	var scn = load("res://assets/vehicles/traffic/muscle.fbx")
	var node = scn.instantiate()
	var mi = node.get_node("Muscle") as MeshInstance3D
	var mesh = mi.mesh as ArrayMesh
	for s in range(mesh.get_surface_count()):
		var mat = mesh.surface_get_material(s)
		var mname = mat.resource_name if mat else "null"
		var arr = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[ArrayMesh.ARRAY_VERTEX]
		var min_v = Vector3(9999, 9999, 9999)
		var max_v = Vector3(-9999, -9999, -9999)
		for v in verts:
			min_v.x = min(min_v.x, v.x)
			min_v.y = min(min_v.y, v.y)
			min_v.z = min(min_v.z, v.z)
			max_v.x = max(max_v.x, v.x)
			max_v.y = max(max_v.y, v.y)
			max_v.z = max(max_v.z, v.z)
		print("Slot ", s, " (", mname, "): verts=", verts.size(), " Bounds: [", min_v, " to ", max_v, "]")
	quit()
