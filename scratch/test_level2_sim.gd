extends SceneTree

func _init() -> void:
	call_deferred("_run_level2")

func _run_level2() -> void:
	var gc = root.get_node_or_null("GameController")
	if gc != null: gc.current_level_number = 2
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	
	await create_timer(0.5).timeout
	print("\n=== LEVEL 2 FULL PLAYTHROUGH SIMULATION ===")
	print("Level title: %s" % node.level_title_label.text)
	print("Vehicles count: %d" % node.controller.vehicles.size())
	print("Total passengers: %d" % node.controller.authoritative_passengers.size())
	
	var elapsed := 0.0
	var max_time := 60.0
	var tapped_vids := []
	
	while elapsed < max_time:
		if node.controller.state == CarJamController.GameState.WIN:
			print("[SUCCESS] LEVEL 2 COMPLETED AND WON at elapsed=%.1fs!" % elapsed)
			break
		if node.controller.state == CarJamController.GameState.FAIL:
			print("[FAIL] LEVEL 2 ENTERED FAIL STATE at elapsed=%.1fs!" % elapsed)
			break
			
		# Check if any unlocked slot is free
		var free_slot_exists := false
		for s in node.controller.parking._slots:
			if s.is_unlocked and s.state == CarJamParkingManager.SlotState.FREE:
				free_slot_exists = true
				break
				
		if free_slot_exists:
			# Find unblocked vehicle
			for vid in node.controller.vehicles:
				if vid in tapped_vids:
					continue
				var v = node.controller.vehicles[vid]
				if v.state == VehicleModel.VehicleState.ON_BOARD:
					var esc = node.controller.board.check_swept_escape(v)
					if esc["can_escape"]:
						print("[L2 T=%.1fs] Tapped vehicle %d (%s)" % [elapsed, vid, v.color_id])
						node._on_vehicle_tapped(vid)
						tapped_vids.append(vid)
						break
						
		await create_timer(0.3).timeout
		elapsed += 0.3
		
		if int(elapsed * 10) % 20 == 0:
			var boarded_count = 0
			for pid in node.controller.authoritative_passengers:
				if node.controller.authoritative_passengers[pid]["state"] == "BOARDED":
					boarded_count += 1
			print("[L2 T=%.1fs] Boarded: %d / 480 | Circ: %d | Feeder: %d | State: %d" % [
				elapsed, boarded_count, node._circulating_rows.size(), node._feeder_rows.size(), node.controller.state
			])
			
	# Reset save back to Level 1 so user always starts on Level 1
	var sm = root.get_node_or_null("SaveManager")
	if sm != null:
		sm.set_current_level(1)
	quit()
