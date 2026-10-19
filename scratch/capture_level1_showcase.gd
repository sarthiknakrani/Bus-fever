extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	get_root().size = Vector2i(1080, 1920)

	var scene = load("res://scenes/level1.tscn")
	var node = scene.instantiate()
	root.add_child(node)

	# Wait for layout & initial frame render
	await create_timer(0.8).timeout

	# 1. Capture Initial Layout
	var img1 = get_root().get_texture().get_image()
	if img1 != null:
		var path1 = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827/level1_initial_layout.png"
		img1.save_png(path1)
		print("[CAPTURE 1 SUCCESS] Saved ", path1)

	# 2. Tap Bus 1 (Blue) -> Dispatches via perimeter road to Slot 1
	if node.bus_grid_ctrl != null:
		node.bus_grid_ctrl.tap_bus(1)

	# Wait for Bus 1 to pull into Slot 1
	await create_timer(1.2).timeout

	# 3. Tap Bus 2 (Yellow) -> Dispatches to Slot 2
	if node.bus_grid_ctrl != null:
		node.bus_grid_ctrl.tap_bus(2)

	# Wait for boarding runners to dispatch from gate
	await create_timer(1.2).timeout

	# 4. Capture Live Boarding State
	var img2 = get_root().get_texture().get_image()
	if img2 != null:
		var path2 = "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827/level1_boarding_showcase.png"
		img2.save_png(path2)
		print("[CAPTURE 2 SUCCESS] Saved ", path2)

	quit()
