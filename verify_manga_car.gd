extends SceneTree

func _init():
	var main_scene = load("res://monolithic_testbed.tscn").instantiate()
	root.add_child(main_scene)
	_run_captures(main_scene)

func _run_captures(main_scene):
	# Wait for scene initialization and shader warmup
	for i in range(35):
		await process_frame

	var vp = root.get_viewport()
	var cam: Camera3D = main_scene.follow_cam
	var car = main_scene.car_root

	# 1. Chase View (Default elevated 10-degree pitch up view)
	var img1 = vp.get_texture().get_image()
	img1.save_png("C:/Users/jatin/.gemini/antigravity/brain/40ded32f-0a02-44db-8bea-5acffc621743/verify_manga_car_chase.png")
	print("SAVED: verify_manga_car_chase.png")

	# Freeze physics so camera positioning doesn't get overridden by process
	main_scene.set_physics_process(false)
	main_scene.set_process(false)

	# 2. Side Profile View (Focusing on trees and left hillside cel-shading + car side livery)
	if cam and car:
		cam.global_position = car.global_position + Vector3(-5.2, 1.4, -2.0)
		cam.look_at(car.global_position + Vector3(0.0, 0.8, -1.0), Vector3.UP)
		for f in range(6):
			await process_frame
		var img2 = vp.get_texture().get_image()
		img2.save_png("C:/Users/jatin/.gemini/antigravity/brain/40ded32f-0a02-44db-8bea-5acffc621743/verify_manga_car_side.png")
		print("SAVED: verify_manga_car_side.png")

	# 3. Horizon View (Looking straight down highway at city skyline, verifying no mountains in center corridor)
	if cam and car:
		cam.global_position = car.global_position + Vector3(0.0, 1.88, 5.0)
		cam.look_at(car.global_position + Vector3(0.0, 1.25, -24.0), Vector3.UP)
		cam.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(10.0))
		for f in range(6):
			await process_frame
		var img3 = vp.get_texture().get_image()
		img3.save_png("C:/Users/jatin/.gemini/antigravity/brain/40ded32f-0a02-44db-8bea-5acffc621743/verify_manga_car_front.png")
		print("SAVED: verify_manga_car_front.png")

	# 4. Cel-Shaded Drift Smoke & Rear View
	main_scene.drift_active = true
	if main_scene.smoke_left:
		main_scene.smoke_left.emitting = true
		main_scene.smoke_left.visible = true
	if main_scene.smoke_right:
		main_scene.smoke_right.emitting = true
		main_scene.smoke_right.visible = true
	if cam and car:
		cam.global_position = car.global_position + Vector3(2.6, 1.35, 3.8)
		cam.look_at(car.global_position + Vector3(0.0, 0.65, 0.0), Vector3.UP)
		for f in range(8):
			await process_frame
		var img4 = vp.get_texture().get_image()
		img4.save_png("C:/Users/jatin/.gemini/antigravity/brain/40ded32f-0a02-44db-8bea-5acffc621743/verify_manga_drift_auto_modellista.png")
		print("SAVED: verify_manga_drift_auto_modellista.png")

	print("ALL CAPTURES COMPLETED SUCCESSFULLY.")
	quit()
