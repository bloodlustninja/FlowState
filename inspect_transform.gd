extends SceneTree

func _init():
	var scn = load("res://assets/vehicles/traffic/muscle.fbx")
	var node = scn.instantiate()
	var mi = node.get_node("Muscle") as MeshInstance3D
	print("Muscle node transform: ", mi.transform)
	print("Muscle node rot deg: ", mi.rotation_degrees)
	quit()
