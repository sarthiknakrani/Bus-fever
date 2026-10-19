extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	get_root().size = Vector2i(720, 1280)
	var gc = root.get_node_or_null("GameController")
	if gc != null:
		gc.current_level_number = 2
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	
	await create_timer(1.0).timeout
	var img = get_root().get_texture().get_image()
	if img != null:
		var path = "scratch/test_level2_capture.png"
		img.save_png(path)
		print("[CAPTURE SUCCESS] Saved ", path)
	quit()
