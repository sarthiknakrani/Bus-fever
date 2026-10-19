extends SceneTree

const Level1Scene = preload("res://scenes/level1.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n=======================================================")
	print("=== QA: FULL LEVEL 1 COMPLETION & LEVEL 2 ADVANCE ===")
	print("=======================================================")

	var gc = root.get_node_or_null("GameController")
	if gc:
		gc.current_level_number = 1

	var lvl: CarJamLevel = Level1Scene.instantiate()
	root.add_child(lvl)

	var win_state := {"completed": false, "controller_win": false}
	lvl.level_completed.connect(func():
		win_state["completed"] = true
		print("[EVENT] CarJamLevel.level_completed fired!")
	)
	lvl.controller.level_completed.connect(func():
		win_state["controller_win"] = true
		print("[EVENT] CarJamController.level_completed fired!")
	)

	# Run simulation frame by frame
	var time_elapsed := 0.0
	var max_sim_time := 160.0 # seconds of simulated physics
	var dt := 1.0 / 60.0

	var tapped_vids := []

	while time_elapsed < max_sim_time and not win_state["completed"]:
		# Periodically try to tap any available vehicle that can be dispatched
		for vid in lvl.controller.vehicles.keys():
			var v = lvl.controller.vehicles[vid]
			if v.state == VehicleModel.VehicleState.ON_BOARD and lvl.controller.parking.find_available_slot() != -1:
				if not tapped_vids.has(vid):
					var ok = lvl.controller.tap_vehicle(vid)
					if ok:
						tapped_vids.append(vid)
						print("[SIM] Tapped and dispatched Vehicle %d (color=%s)" % [vid, v.color_id])

		# Step physics & frame
		lvl._process(dt)
		await process_frame
		time_elapsed += dt

	print("\nSimulated time: %.2fs" % time_elapsed)
	print("Tapped vehicles: ", tapped_vids.size(), " / ", lvl.controller.vehicles.size())
	print("Authoritative passengers remaining: ", lvl.controller.queue.get_remaining_total())
	print("Controller State: ", lvl.controller.state)

	assert(win_state["controller_win"], "CarJamController must emit level_completed!")
	assert(win_state["completed"], "CarJamLevel must emit level_completed!")
	assert(lvl.result_overlay != null and lvl.result_overlay.visible, "Victory overlay must be visible!")
	assert(lvl.result_btn != null and lvl.result_btn.visible, "NEXT button must be visible!")
	print("[PASS] Level 1 victory cleanly triggered with full UI celebration!")

	# Now test pressing NEXT to advance to Level 2
	print("[SIM] Pressing NEXT button...")
	lvl._on_result_next_pressed()
	await process_frame
	
	if gc:
		print("GameController current_level_number: ", gc.current_level_number)
		assert(gc.current_level_number == 2, "GameController must advance to Level 2!")
		print("[PASS] Successfully jumped to Level 2!")

	lvl.queue_free()
	await process_frame

	print("\n=======================================================")
	print("=== ALL LEVEL 1 -> LEVEL 2 ADVANCE TESTS PASSED! ===")
	print("=======================================================\n")
	quit()
