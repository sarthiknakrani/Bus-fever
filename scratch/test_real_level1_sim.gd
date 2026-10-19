extends SceneTree

func _init() -> void:
	call_deferred("_test_real_level1")

func _test_real_level1() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	get_root().size = Vector2i(720, 1280)
	var gc = root.get_node_or_null("GameController")
	if gc != null:
		gc.current_level_number = 1
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	node.is_level1_mode = false
	root.add_child(node)
	
	node.is_level1_mode = false
	var lvl = load("res://levels/level_001.tres")
	node.controller.load_level(lvl)
	node._setup_visuals(lvl)
	
	# Wait for load
	await create_timer(0.5).timeout
	
	print("[TEST] Vehicles in Level 1:")
	for vid in node.controller.vehicles:
		var v = node.controller.vehicles[vid]
		print("  Vehicle %d: color=%s, cap=%d, occ=%d" % [v.id, v.color_id, v.capacity, v.passenger_occupancy])
	
	# Let's tap unblocked vehicles
	# In level 1: board is 5x5
	for step in range(30):
		for vid in node.controller.vehicles:
			var v = node.controller.vehicles[vid]
			if v.state == VehicleModel.VehicleState.ON_BOARD:
				var path = node.controller.find_exit_path(vid)
				if not path.is_empty():
					print("[TEST Step %d] Tapping unblocked vehicle %d (%s)..." % [step, vid, v.color_id])
					node.controller.tap_vehicle(vid)
					await create_timer(1.2).timeout
					break
		await create_timer(0.5).timeout
		if node.controller.state == CarJamController.GameState.WIN:
			print("[TEST SUCCESS] Level 1 WIN reached!")
			break
		if node.controller.state == CarJamController.GameState.FAIL:
			print("[TEST FAILED] Level 1 GAME OVER / FAIL!")
			break
	
	print("[TEST] Controller state: %d (0=INIT, 1=PLAYING, 2=WIN, 3=LOSE)" % node.controller.state)
	var img = get_root().get_texture().get_image()
	if img != null:
		img.save_png("scratch/test_real_level1_sim.png")
	quit()
