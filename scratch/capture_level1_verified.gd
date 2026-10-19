extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	get_root().size = Vector2i(1080, 1920)

	var scene = load("res://scenes/level1.tscn")
	var lvl: CarJamLevel = scene.instantiate()
	root.add_child(lvl)

	# Wait for layout & initial frame render
	await create_timer(0.6).timeout

	# 1. Capture Initial Layout
	var img1 = get_root().get_texture().get_image()
	if img1 != null:
		var path1 = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827/level1_verified_initial.png"
		img1.save_png(path1)
		print("[CAPTURE 1 SUCCESS] Saved ", path1)

	# 2. Tap Bus 1 (Blue)
	if lvl.controller != null:
		lvl.controller.tap_vehicle(1)

	# Wait for Bus 1 to arrive and start boarding
	await create_timer(1.2).timeout

	# 3. Capture Boarding State
	var img2 = get_root().get_texture().get_image()
	if img2 != null:
		var path2 = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827/level1_verified_boarding.png"
		img2.save_png(path2)
		print("[CAPTURE 2 SUCCESS] Saved ", path2)

	lvl.queue_free()
	quit()
