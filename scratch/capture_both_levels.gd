extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	get_root().size = Vector2i(720, 1280)
	
	for lvl_id in [1, 2]:
		var gc = root.get_node_or_null("GameController")
		if gc != null:
			gc.current_level_number = lvl_id
		
		# Clear existing children from root except autoloads
		for c in root.get_children():
			if not c.name.begins_with("@") and c.name != "GameController" and c.name != "SaveManager" and c.name != "SettingsManager" and c.name != "AudioManager" and c.name != "_mcp_game_helper":
				c.queue_free()
		
		var scene = load("res://scenes/gameplay/car_jam_level.tscn")
		var node = scene.instantiate()
		root.add_child(node)
		
		await create_timer(1.2).timeout
		var img = get_root().get_texture().get_image()
		if img != null:
			var path = "scratch/test_layout_level%d.png" % lvl_id
			img.save_png(path)
			print("[CAPTURE SUCCESS] Saved ", path)
		node.queue_free()
		await create_timer(0.2).timeout

	quit()
