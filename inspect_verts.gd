extends SceneTree

func _init():
	var scn = load("res://assets/vehicles/traffic/muscle.fbx")
	var node = scn.instantiate()
	var mi = node.get_node("Muscle") as MeshInstance3D
	var mesh = mi.mesh as ArrayMesh
	var arr = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[ArrayMesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[ArrayMesh.ARRAY_NORMAL]
	print("First 10 vertices & normals in Muscle Slot 0:")
	for i in range(min(15, verts.size())):
		print("v: ", verts[i], " norm: ", norms[i])
	quit()
