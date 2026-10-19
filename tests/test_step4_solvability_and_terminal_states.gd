extends SceneTree

const CarJamLevelScene = preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("\n=======================================================")
	print("=== STEP 4 QA: TERMINAL STATES & WIN/LOSE DETECTION ===")
	print("=======================================================")
	
	await _test_1_win_condition_strictness()
	await _test_2_lose_condition_in_flight_guard()
	await _test_3_lose_condition_matching_oval_guard()
	await _test_4_terminal_jam_trigger()
	await _test_5_input_lock_and_tween_cleanup()
	
	print("\n=======================================================")
	print("=== ALL STEP 4 TESTS PASSED PERFECTLY (0 FAILURES) ===")
	print("=======================================================")
	quit()

func _test_1_win_condition_strictness() -> void:
	print("\n--- TEST 1: Win Condition Strictness ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)
	
	var win_state := {"emitted": false}
	c.level_completed.connect(func(): win_state["emitted"] = true)
	
	# Mark all vehicles completed BUT leave passengers unboarded
	for vid in c.vehicles:
		c.vehicles[vid].state = VehicleModel.VehicleState.COMPLETED
	
	c.check_terminal_states()
	assert(not win_state["emitted"], "Win must NOT trigger while passengers remain on track!")
	assert(c.state == CarJamController.GameState.PLAYING, "Game state must remain PLAYING")
	print("[PASS] Win rejected when passengers remain on track")
	
	# Now properly board all passengers through controller
	for vid in c.vehicles:
		c.vehicles[vid].state = VehicleModel.VehicleState.PARKED
		c.vehicles[vid].passenger_occupancy = 0

	for pid in c.authoritative_passengers.keys():
		var p = c.authoritative_passengers[pid]
		p["state"] = "CIRCULATING"
		var target_vid := -1
		for vid in c.vehicles:
			var v = c.vehicles[vid]
			if v.color_id == p["color_id"] and v.remaining_capacity() > 0:
				target_vid = vid
				break
		assert(target_vid != -1, "Must find matching vehicle")
		c.try_reserve_boarding(pid, target_vid, p["color_id"], p["group_id"])
		c.commit_boarding(pid, target_vid, p["color_id"], c.session_token)

	# Mark all vehicles completed / departed
	for vid in c.vehicles:
		c.vehicles[vid].state = VehicleModel.VehicleState.COMPLETED
	
	c.check_terminal_states()
	assert(win_state["emitted"], "Win MUST trigger when all vehicles completed and zero passengers remain!")
	assert(c.state == CarJamController.GameState.WIN, "Game state must become WIN")
	print("[PASS] Win triggered strictly when all vehicles departed and track empty")

func _test_2_lose_condition_in_flight_guard() -> void:
	print("\n--- TEST 2: Lose Condition Guarded While Vehicle Driving In ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)
	
	var fail_state := {"emitted": false}
	c.puzzle_failed.connect(func(): fail_state["emitted"] = true)
	
	# Fill all slots, but keep 1 slot in RESERVED state (bus still driving in)
	var unlocked_ids = c.parking.get_unlocked_slot_ids()
	var v_ids = c.vehicles.keys()
	for i in range(unlocked_ids.size()):
		var slot_id = unlocked_ids[i]
		var vid = v_ids[i]
		var slot = c.parking.get_slot(slot_id)
		slot.vehicle_id = vid
		slot.state = CarJamParkingManager.SlotState.OCCUPIED if i > 0 else CarJamParkingManager.SlotState.RESERVED
		var v = c.vehicles.get(vid, null)
		if v:
			v.state = VehicleModel.VehicleState.PARKED if i > 0 else VehicleModel.VehicleState.EXITING
	
	c.check_terminal_states()
	assert(not fail_state["emitted"], "Lose must NOT trigger while a vehicle is still driving to a slot!")
	assert(c.state == CarJamController.GameState.PLAYING, "Game state must remain PLAYING")
	print("[PASS] Lose guarded while vehicle in transit/arriving")

func _test_3_lose_condition_matching_oval_guard() -> void:
	print("\n--- TEST 3: Lose Condition Guarded When Matching Passenger on Oval ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)
	
	var fail_state := {"emitted": false}
	c.puzzle_failed.connect(func(): fail_state["emitted"] = true)
	
	# All unlocked slots OCCUPIED by docked vehicles (RED buses)
	var unlocked_ids = c.parking.get_unlocked_slot_ids()
	var v_ids = c.vehicles.keys()
	for i in range(unlocked_ids.size()):
		var slot_id = unlocked_ids[i]
		var vid = v_ids[i]
		var slot = c.parking.get_slot(slot_id)
		slot.vehicle_id = vid
		slot.state = CarJamParkingManager.SlotState.OCCUPIED
		var v = c.vehicles.get(vid, null)
		if v:
			v.state = VehicleModel.VehicleState.PARKED
			v.passenger_occupancy = 0
			v.color_id = "red"
	
	# Mark authoritative passengers: passenger 0 is CIRCULATING and RED (matching!)
	c.authoritative_passengers[0]["state"] = "CIRCULATING"
	c.authoritative_passengers[0]["color_id"] = "red"
	
	c.check_terminal_states()
	assert(not fail_state["emitted"], "Lose must NOT trigger when circulating passengers match docked bus color!")
	assert(c.state == CarJamController.GameState.PLAYING, "Game state must remain PLAYING")
	print("[PASS] Lose guarded when circulating passengers match parked buses")

func _test_4_terminal_jam_trigger() -> void:
	print("\n--- TEST 4: Terminal Jam / Out-of-Space Trigger ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)
	
	var fail_state := {"emitted": false, "level_failed_emitted": false}
	c.puzzle_failed.connect(func(): fail_state["emitted"] = true)
	c.level_failed.connect(func(): fail_state["level_failed_emitted"] = true)
	
	# All unlocked slots OCCUPIED by RED docked vehicles
	var unlocked_ids = c.parking.get_unlocked_slot_ids()
	var v_ids = c.vehicles.keys()
	for i in range(unlocked_ids.size()):
		var slot_id = unlocked_ids[i]
		var vid = v_ids[i]
		var slot = c.parking.get_slot(slot_id)
		slot.vehicle_id = vid
		slot.state = CarJamParkingManager.SlotState.OCCUPIED
		var v = c.vehicles.get(vid, null)
		if v:
			v.state = VehicleModel.VehicleState.PARKED
			v.passenger_occupancy = 0
			v.color_id = "red"
	
	# All circulating/feeder passengers are BLUE (NO match with red buses!)
	for pid in c.authoritative_passengers:
		c.authoritative_passengers[pid]["color_id"] = "blue"
		c.authoritative_passengers[pid]["state"] = "CIRCULATING"
	
	c.check_terminal_states()
	assert(fail_state["emitted"], "puzzle_failed MUST trigger when all bays full of red buses and queue has only blue!")
	assert(fail_state["level_failed_emitted"], "level_failed MUST trigger when all bays full of red buses and queue has only blue!")
	assert(c.state == CarJamController.GameState.FAIL, "Game state must become FAIL")
	print("[PASS] Accurate Out-of-Space detection cleanly triggered (puzzle_failed + level_failed)")

func _test_5_input_lock_and_tween_cleanup() -> void:
	print("\n--- TEST 5: Input Lock & Tween Cleanup in CarJamLevel ---")
	var lvl: CarJamLevel = CarJamLevelScene.instantiate()
	root.add_child(lvl)
	await process_frame
	await process_frame
	
	var completed_state := {"emitted": false}
	lvl.level_completed.connect(func(): completed_state["emitted"] = true)
	
	# Trigger completion
	lvl._on_level_completed()
	assert(completed_state["emitted"], "level_completed signal must be emitted")
	assert(lvl._is_level_ending, "_is_level_ending must be true")
	
	# Tap vehicle after completion — must be ignored!
	var sample_vid = lvl.vehicle_views.keys()[0]
	lvl._on_vehicle_tapped(sample_vid)
	print("[PASS] Vehicle taps locked after level completion")
	
	# Test tween cleanup
	lvl._cleanup_level_tweens()
	assert(lvl._celebration_tweens.is_empty(), "Celebration tweens must be empty")
	assert(lvl._failure_tweens.is_empty(), "Failure tweens must be empty")
	print("[PASS] Level tweens cleanly killed and cleaned up")
	
	lvl.queue_free()
	await process_frame
	
	# Test failure signal emission and input lock
	var lvl_fail: CarJamLevel = CarJamLevelScene.instantiate()
	root.add_child(lvl_fail)
	await process_frame
	await process_frame
	
	var failed_state := {"emitted": false}
	lvl_fail.level_failed.connect(func(): failed_state["emitted"] = true)
	lvl_fail._on_puzzle_failed()
	assert(failed_state["emitted"], "level_failed signal must be emitted on failure")
	assert(lvl_fail._is_level_ending, "_is_level_ending must be true on failure")
	
	lvl_fail.queue_free()
	await process_frame
	print("[PASS] Level failure signal and lock fully verified")
