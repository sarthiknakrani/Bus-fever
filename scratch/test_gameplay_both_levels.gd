extends SceneTree

func _init() -> void:
	call_deferred("_run_full_qa")

func _run_full_qa() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	get_root().size = Vector2i(720, 1280)
	
	var gc = root.get_node_or_null("GameController")
	if gc != null:
		gc.current_level_number = 1
	
	print("\n=======================================================")
	print("=== QA PLAYTHROUGH: LEVEL 1 (REAL 2.5D LAYOUT) ===")
	print("=======================================================")
	
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	
	await create_timer(1.0).timeout
	
	print("[GAMEPLAY] Initializing Level 1...")
	print("[GAMEPLAY] Total vehicles: %d" % node.controller.vehicles.size())
	print("[GAMEPLAY] Total passengers: %d" % node.controller.authoritative_passengers.size())
	
	# Simulate interactive gameplay: tap unblocked vehicles whenever slots are free
	var max_seconds := 30.0
	var elapsed := 0.0
	var tapped_vids := []
	
	while elapsed < max_seconds:
		if node.controller.state == CarJamController.GameState.WIN:
			print("[GAMEPLAY] Level 1 WIN condition achieved at %.2fs!" % elapsed)
			break
		if node.controller.state == CarJamController.GameState.FAIL:
			print("[GAMEPLAY ERROR] Level 1 reached FAIL state at %.2fs!" % elapsed)
			break
			
		# Check if any unlocked slot is free
		var free_slot_exists := false
		for s in node.controller.parking._slots:
			if s.is_unlocked and s.state == CarJamParkingManager.SlotState.FREE:
				free_slot_exists = true
				break
				
		if free_slot_exists:
			# Find an unblocked vehicle on board
			for vid in node.controller.vehicles:
				if vid in tapped_vids:
					continue
				var v = node.controller.vehicles[vid]
				if v.state == VehicleModel.VehicleState.ON_BOARD:
					var esc = node.controller.board.check_swept_escape(v)
					if esc["can_escape"]:
						print("[GAMEPLAY] Tapping unblocked vehicle %d (%s)..." % [vid, v.color_id])
						node._on_vehicle_tapped(vid)
						tapped_vids.append(vid)
						break
						
		await create_timer(0.3).timeout
		elapsed += 0.3
	
	# Let animations finish
	await create_timer(1.5).timeout
	
	var img = get_root().get_texture().get_image()
	if img != null:
		img.save_png("scratch/qa_level1_result.png")
		print("[CAPTURE] Saved scratch/qa_level1_result.png")
		
	print("[GAMEPLAY] Final Level 1 Controller State: %d (2=WIN)" % node.controller.state)
	print("[GAMEPLAY] Next button visible: %s" % (node.result_btn != null and node.result_btn.visible))
	
	# Now press Next button to advance to Level 2!
	if node.result_btn != null and node.result_btn.visible:
		print("[GAMEPLAY] Pressing NEXT button...")
		node._on_result_next_pressed()
		await create_timer(1.0).timeout
		if gc != null:
			print("[GAMEPLAY] Current Level after Next: %d" % gc.current_level_number)
			
	quit()
