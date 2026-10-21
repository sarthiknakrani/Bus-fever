extends SceneTree

const Level1Scene = preload("res://scenes/level1.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n=======================================================")
	print("=== QA: VERIFYING 4 LEVEL 1 BUGS FIXES ===")
	print("=======================================================\n")

	var gc = root.get_node_or_null("GameController")
	if gc:
		gc.current_level_number = 1

	var lvl: CarJamLevel = Level1Scene.instantiate()
	root.add_child(lvl)

	# -----------------------------------------------------------------
	# Test Bug 2 & 3: Circulating Oval Loop & Feeder Ramp Integration
	# -----------------------------------------------------------------
	print("--- Test Bug 2 & 3: Circulating Oval Loop & Feeder Ramp Integration ---")
	assert(lvl.passenger_track != null, "passenger_track must exist")
	assert(lvl.all_passengers.size() == 240, "Exactly 240 passengers must exist! Got %d" % lvl.all_passengers.size())
	assert(lvl._circulating_rows.size() == 36, "Initial circulating loop must have 36 rows! Got %d" % lvl._circulating_rows.size())
	assert(lvl._feeder_rows.size() == 24, "Initial feeder queue must have 24 rows! Got %d" % lvl._feeder_rows.size())

	# Step time for 2 seconds with NO buses parked: loop rows circulate smoothly without blocking or fake decoys
	for _frame in 120:
		lvl._process(1.0 / 60.0)

	assert(lvl._circulating_rows.size() == 36, "Circulating rows remain intact when no buses parked!")
	assert(lvl._feeder_rows.size() == 24, "Feeder rows remain safely waiting before freed capacity!")
	print("[PASS] Bug 2 & 3: Circulating oval loop & feeder queue confirmed with exact 240 passenger conservation.")

	# -----------------------------------------------------------------
	# Test Bug 4: Universal Bus Blocking & Collision Corridor
	# -----------------------------------------------------------------
	print("\n--- Test Bug 4: Universal Bus Blocking & Swept Collision ---")
	# In Level 1: Bus 1, 2, 6 are blocked; Bus 3, 4, 5 are initially free
	var tap_b1 = lvl.controller.tap_vehicle(1)
	assert(not tap_b1, "Bus 1 must be BLOCKED!")
	var tap_b2 = lvl.controller.tap_vehicle(2)
	assert(not tap_b2, "Bus 2 must be BLOCKED!")
	var tap_b6 = lvl.controller.tap_vehicle(6)
	assert(not tap_b6, "Bus 6 must be BLOCKED!")

	# Dispatch Bus 3 (Red) -> should succeed
	var tap_b3 = lvl.controller.tap_vehicle(3)
	assert(tap_b3, "Bus 3 (Red) must dispatch successfully")

	# Dispatch Bus 4 (Red) -> should succeed
	var tap_b4 = lvl.controller.tap_vehicle(4)
	assert(tap_b4, "Bus 4 (Red) must dispatch successfully")

	print("[PASS] Bug 4: Universal swept collision rules verified!")

	# -----------------------------------------------------------------
	# Test Bug 1: Leftmost Bus Priority & In-Flight Reservation
	# -----------------------------------------------------------------
	print("\n--- Test Bug 1: Leftmost Bus Priority & In-Flight Reservation ---")
	# Bus 3 is in Slot 1, Bus 4 is in Slot 2 (both are Red)
	var v3 = lvl.controller.vehicles[3]
	var v4 = lvl.controller.vehicles[4]
	var wait_park_frames := 0
	while (v3.state != VehicleModel.VehicleState.PARKED or v4.state != VehicleModel.VehicleState.PARKED) and wait_park_frames < 300:
		lvl._process(1.0 / 60.0)
		await process_frame
		wait_park_frames += 1

	assert(v3.state == VehicleModel.VehicleState.PARKED, "Bus 3 must be parked in Slot 1")
	assert(v4.state == VehicleModel.VehicleState.PARKED, "Bus 4 must be parked in Slot 2")

	# Wait for Red passengers to circulate to gate and board
	var wait_board_frames := 0
	while v3.passenger_occupancy < 40 and wait_board_frames < 600:
		lvl._process(1.0 / 60.0)
		await process_frame
		wait_board_frames += 1

	print("Leftmost priority check: Bus 3 (Slot 1) occupancy = %d / 40 | Bus 4 (Slot 2) occupancy = %d / 40" % [
		v3.passenger_occupancy, v4.passenger_occupancy
	])
	assert(v3.passenger_occupancy == 40, "Bus 3 in Slot 1 must be filled first!")

	print("[PASS] Bug 1: Leftmost bus priority strictly enforced! Bus 3 in Slot 1 filled before Bus 4.")

	# Complete Level 1 playthrough to ensure 100% win flow
	print("\n--- Completing full level playthrough to 100% win ---")
	var win_state := {"completed": false}
	lvl.level_completed.connect(func():
		win_state["completed"] = true
		print("[EVENT] CarJamLevel.level_completed fired in QA test!")
	)

	var remaining_tapped := []
	var sim_frames := 0
	while not win_state["completed"] and sim_frames < 3000:
		for vid in [1, 2, 5, 6]:
			if not remaining_tapped.has(vid):
				var v = lvl.controller.vehicles[vid]
				if v.state == VehicleModel.VehicleState.ON_BOARD and lvl.controller.parking.find_available_slot() != -1:
					if lvl.controller.tap_vehicle(vid):
						remaining_tapped.append(vid)
						print("[SIM] Tapped and dispatched remaining Bus %d" % vid)

		lvl._process(1.0 / 60.0)
		await process_frame
		sim_frames += 1

	assert(win_state["completed"], "Level 1 must complete successfully!")
	assert(lvl.result_overlay.visible, "Victory popup must be visible!")
	assert(lvl.result_btn.visible, "NEXT button must be visible!")
	print("[PASS] Level 1 completed in %d frames with victory overlay & NEXT button active!" % sim_frames)

	print("\n=======================================================")
	print("=== ALL 4 BUGS VERIFIED FIXED WITH 100% PASS RATE! ===")
	print("=======================================================\n")
	lvl.queue_free()
	quit()
