extends Node3D

func _ready():
	var main_scene = load("res://monolithic_testbed.tscn").instantiate()
	add_child(main_scene)
	_run_all_tests(main_scene)

func _run_all_tests(main_scene):
	var brain_dir = "C:/Users/jatin/.gemini/antigravity/brain/40ded32f-0a02-44db-8bea-5acffc621743/"
	var vp = get_viewport()
	main_scene.player_speed = 46.1 # ~166 km/h

	# 1. Sunset Rain (Direct user reference test)
	main_scene.tod_mode = 2 # DUSK
	main_scene.day_cycle_progress = 0.32
	main_scene.current_weather = 1 # RAIN
	main_scene.is_raining = true
	main_scene.is_snowing = false
	for f in range(60):
		await get_tree().process_frame
	var img = vp.get_texture().get_image()
	img.save_png(brain_dir + "live_driving_sunset_rain.png")
	print("SAVED: live_driving_sunset_rain.png")

	# 2. Noon Sunny (Direct user reference test)
	main_scene.tod_mode = 1 # NOON
	main_scene.day_cycle_progress = 0.0
	main_scene.current_weather = 0 # SUNNY
	main_scene.is_raining = false
	for f in range(45):
		await get_tree().process_frame
	var img2 = vp.get_texture().get_image()
	img2.save_png(brain_dir + "live_driving_noon_sunny.png")
	print("SAVED: live_driving_noon_sunny.png")

	# 3. Midnight Sunny (Cyber city night test)
	main_scene.tod_mode = 3 # NIGHT
	main_scene.day_cycle_progress = 0.60
	main_scene.current_weather = 0 # SUNNY
	for f in range(45):
		await get_tree().process_frame
	var img3 = vp.get_texture().get_image()
	img3.save_png(brain_dir + "test_midnight_sunny.png")
	print("SAVED: test_midnight_sunny.png")

	# 4. Sunset Snow (Winter season test)
	main_scene.tod_mode = 2 # DUSK
	main_scene.day_cycle_progress = 0.32
	main_scene.current_weather = 2 # SNOW
	main_scene.is_raining = false
	main_scene.is_snowing = true
	for f in range(45):
		await get_tree().process_frame
	var img4 = vp.get_texture().get_image()
	img4.save_png(brain_dir + "test_sunset_snow.png")
	print("SAVED: test_sunset_snow.png")

	get_tree().quit()
