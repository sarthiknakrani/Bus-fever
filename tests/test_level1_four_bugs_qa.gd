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
	# Test Bug 2 & 3: FIFO Standing Queue & Feeder Integration
	# -----------------------------------------------------------------
	print("--- Test Bug 2 & 3: FIFO Stop-at-Gate & Single Unified 1D Spline ---")
	assert(lvl.passenger_track != null, "passenger_track must exist")
	assert(lvl._circulating_rows.size() == 60, "All 60 rows must be in unified queue! Got %d" % lvl._circulating_rows.size())
	assert(lvl.all_passengers.size() == 240, "Exactly 240 passengers must exist! Got %d" % lvl.all_passengers.size())
	assert(lvl._feeder_rows.is_empty(), "feeder_rows must be empty because queue is unified!")
	assert(lvl._pending_feeder_rows.is_empty(), "pending_feeder_rows must be empty!")

	# Initial row positions
	assert(lvl._circulating_rows[0].progress == 0.0, "Row 0 must start at Gate (dist = 0.0 px)")
	assert(is_equal_approx(lvl._circulating_rows[1].progress, 26.0), "Row 1 must be at 26.0 px")
	assert(is_equal_approx(lvl._circulating_rows[39].progress, 39.0 * 26.0), "Row 39 must be on oval at 1014 px")
	assert(is_equal_approx(lvl._circulating_rows[40].progress, 40.0 * 26.0), "Row 40 must be at 1040 px")
	assert(is_equal_approx(lvl._circulating_rows[59].progress, 59.0 * 26.0), "Row 59 must be at 1534 px on feeder ramp")

	# Step time for 2 seconds with NO buses parked
	for _frame in 120:
		lvl._process(1.0 / 60.0)

	# Verify: No rows should move past 0.0, and no carousel loop!
	assert(lvl._circulating_rows[0].progress >= 0.0 and lvl._circulating_rows[0].progress <= 1.0, "Row 0 must stay stopped at Exit Gate!")
	assert(lvl._circulating_rows.size() == 60, "No rows popped without bus!")
	for r_i in range(lvl._circulating_rows.size()):
		var r = lvl._circulating_rows[r_i]
		var exp_dist = float(r_i) * 26.0
		assert(absf(r.progress - exp_dist) < 2.0, "Row %d must remain stationary at target %f px! (got %f)" % [r_i, exp_dist, r.progress])

	print("[PASS] Bug 2 & 3: Stopped at gate! Zero conveyor carousel rotation! Single 1D spline confirmed.")

	# -----------------------------------------------------------------
	# Test Bug 4: Bus Blocking, Waypoints & Roof Arrows
	# -----------------------------------------------------------------
	print("\n--- Test Bug 4: Bus Blocking, Bump Shake & Roof Arrows ---")
	# Bus 3 blocked by Bus 1
	var tap_b3 = lvl.controller.tap_vehicle(3)
	assert(not tap_b3, "Bus 3 must be BLOCKED by Bus 1!")
	
	# Bus 5 and 6 blocked by Bus 4
	var tap_b5 = lvl.controller.tap_vehicle(5)
	assert(not tap_b5, "Bus 5 must be BLOCKED by Bus 4!")
	var tap_b6 = lvl.controller.tap_vehicle(6)
	assert(not tap_b6, "Bus 6 must be BLOCKED by Bus 4!")

	# Tap Bus 1 (Blue) -> should succeed
	var b1_view = lvl.vehicle_views[1]
	var tap_b1 = lvl.controller.tap_vehicle(1)
	assert(tap_b1, "Bus 1 (Blue) must dispatch successfully")
	assert(b1_view._arrow_cover != null and b1_view._arrow_cover.visible, "Roof arrow must be covered/hidden upon dispatch!")

	print("[PASS] Bug 4: Blocking logic verified! Roof arrow hidden upon dispatch.")

	# -----------------------------------------------------------------
	# Test Bug 1: Leftmost Bus Priority & In-Flight Reservation
	# -----------------------------------------------------------------
	print("\n--- Test Bug 1: Leftmost Bus Priority & In-Flight Reservation ---")
	# Tap Bus 2 (Yellow) -> Slot 2
	var tap_b2 = lvl.controller.tap_vehicle(2)
	assert(tap_b2, "Bus 2 (Yellow) must dispatch")

	# Tap Bus 4 (Blue) -> Slot 3
	var tap_b4 = lvl.controller.tap_vehicle(4)
	assert(tap_b4, "Bus 4 (Blue) must dispatch")

	# Wait until buses park
	var v1 = lvl.controller.vehicles[1]
	var v4 = lvl.controller.vehicles[4]
	var wait_park_frames := 0
	while (v1.state != VehicleModel.VehicleState.PARKED or v4.state != VehicleModel.VehicleState.PARKED) and wait_park_frames < 300:
		lvl._process(1.0 / 60.0)
		await process_frame
		wait_park_frames += 1

	assert(v1.state == VehicleModel.VehicleState.PARKED, "Bus 1 must be parked")
	assert(v4.state == VehicleModel.VehicleState.PARKED, "Bus 4 must be parked")

	# Advance boarding of Batch 0 (36 Blue)
	var wait_board_frames := 0
	while v1.passenger_occupancy < 36 and wait_board_frames < 600:
		lvl._process(1.0 / 60.0)
		await process_frame
		wait_board_frames += 1

	print("After 36 Blue passengers: Bus 1 (Slot 1) occupancy = %d / 40 | Bus 4 (Slot 3) occupancy = %d / 40" % [
		v1.passenger_occupancy, v4.passenger_occupancy
	])
	assert(v1.passenger_occupancy == 36, "Bus 1 in Slot 1 must have received ALL 36 Blue passengers!")
	assert(v4.passenger_occupancy == 0, "Bus 4 in Slot 3 must have received ZERO Blue passengers while Bus 1 had space!")

	print("[PASS] Bug 1: Leftmost bus priority strictly enforced! Bus 4 received 0 passengers while leftmost Bus 1 had seats.")

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
		for vid in [3, 5, 6]:
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
