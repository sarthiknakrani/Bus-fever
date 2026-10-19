extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	get_root().size = Vector2i(1080, 1920)

	var scene = load("res://scenes/level1.tscn")
	var lvl: CarJamLevel = scene.instantiate()
	root.add_child(lvl)

	await create_timer(0.6).timeout

	print("Level 1 loaded! Vehicles count:", lvl.controller.vehicles.size())
	for vid in lvl.controller.vehicles:
		var v = lvl.controller.vehicles[vid]
		print("Bus %d: color=%s, cap=%d, state=%d" % [vid, v.color_id, v.capacity, v.state])

	print("Total passengers in level:", lvl.all_passengers.size())
	print("Rows count:", lvl._circulating_rows.size())

	# Capture initial layout
	var img = get_root().get_texture().get_image()
	if img != null:
		img.save_png("scratch/flawless_initial_preview.png")
		print("Saved scratch/flawless_initial_preview.png")

	lvl.queue_free()
	quit()
