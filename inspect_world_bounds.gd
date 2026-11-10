extends SceneTree

func _init():
	var scn = load("res://assets/vehicles/traffic/muscle.fbx")
	var node = scn.instantiate()
	root.add_child(node)
	var mi = node.get_node("Muscle") as MeshInstance3D
	var mesh = mi.mesh as ArrayMesh
	var arr = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[ArrayMesh.ARRAY_VERTEX]
	var t = mi.global_transform
	var min_w = Vector3(9999, 9999, 9999)
	var max_w = Vector3(-9999, -9999, -9999)
	for v in verts:
		var wv = t * v
		min_w.x = min(min_w.x, wv.x)
		min_w.y = min(min_w.y, wv.y)
		min_w.z = min(min_w.z, wv.z)
		max_w.x = max(max_w.x, wv.x)
		max_w.y = max(max_w.y, wv.y)
		max_w.z = max(max_w.z, wv.z)
	print("WORLD SPACE BOUNDS OF MUSCLE BODY:")
	print("Min: ", min_w)
	print("Max: ", max_w)
	print("Center: ", (min_w + max_w) * 0.5)
	print("Size: ", max_w - min_w)
	quit()
