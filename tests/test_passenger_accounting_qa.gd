extends SceneTree

const CarJamLevelScene = preload("res://scenes/gameplay/car_jam_level.tscn")

var total_failures := 0

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("\n=======================================================")
	print("=== AUTHORITATIVE PASSENGER ACCOUNTING & LIFECYCLE QA ===")
	print("=======================================================")

	await _test_1_level_1_initialization()
	await _test_2_level_2_initialization()
	await _test_3_partial_bus_boarding()
	await _test_4_repeated_returning_colors()
	await _test_5_two_matching_buses_parked_simultaneously()
	await _test_6_rapid_boarding_reservations()
	await _test_7_repeated_completion_callback_idempotence()
	await _test_8_callback_after_restart()
	await _test_9_callback_after_scene_change()
	await _test_10_pause_resume_during_boarding()
	await _test_11_passenger_cancellation_rollback()
	await _test_12_final_passenger_and_vehicle_completion()

	print("\n=======================================================")
	if total_failures == 0:
		print("=== ALL 12 MANDATORY REGRESSION TESTS PASSED (0 FAILURES) ===")
	else:
		print("=== %d TESTS FAILED ===" % total_failures)
	print("=======================================================\n")

	quit(total_failures)

# -----------------------------------------------------------------
# 1. Level 1 Initialization — 240 Unique Passenger IDs
# -----------------------------------------------------------------
func _test_1_level_1_initialization() -> void:
	print("\n--- TEST 1: Level 1 Initialization (240 Unique Passenger IDs) ---")
	var l: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l)
	if not l.is_node_ready():
		l._ready()
	await create_timer(0.15).timeout

	var c: CarJamController = l.controller
	var p_dict = c.authoritative_passengers
	print("  [MEASURED] Level 1 Total Authoritative Passengers: %d (Expected: 240)" % p_dict.size())

	if p_dict.size() == 240:
		print("  [PASS] Exactly 240 authoritative passengers initialized")
	else:
		print("  [FAIL] Expected 240 passengers, got %d" % p_dict.size())
		total_failures += 1

	var cons = c.verify_passenger_conservation()
	if cons["ok"]:
		print("  [PASS] Conservation verified: Total=%d, Duplicates=0, Missing=0, ColorErrors=0" % cons["total"])
		print("  [STATE BREAKDOWN] %s" % str(cons["state_counts"]))
	else:
		print("  [FAIL] Conservation failed: %s" % str(cons))
		total_failures += 1

	if l.all_passengers.size() == 240:
		print("  [PASS] CarJamLevel all_passengers registry contains all 240 individual passengers")
	else:
		print("  [FAIL] Level all_passengers size mismatch: %d" % l.all_passengers.size())
		total_failures += 1

	# Assert that every ID 0..239 exists uniquely
	var all_ids_unique := true
	for i in 240:
		if not p_dict.has(i) or not l.all_passengers.has(i):
			all_ids_unique = false
			break
	if all_ids_unique:
		print("  [PASS] All IDs 0..239 strictly exist without gaps or duplicates")
	else:
		print("  [FAIL] Missing passenger IDs in range 0..239")
		total_failures += 1

	l.queue_free()

# -----------------------------------------------------------------
# 2. Level 2 Initialization — 480 Unique Passenger IDs
# -----------------------------------------------------------------
func _test_2_level_2_initialization() -> void:
	print("\n--- TEST 2: Level 2 Initialization (480 Unique Passenger IDs) ---")
	var gc = root.get_node_or_null("GameController")
	if gc: gc.current_level_number = 2

	var l: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l)
	if not l.is_node_ready():
		l._ready()
	await create_timer(0.15).timeout

	var c: CarJamController = l.controller
	var p_dict = c.authoritative_passengers
	print("  [MEASURED] Level 2 Total Authoritative Passengers: %d (Expected: 480)" % p_dict.size())

	if p_dict.size() == 480:
		print("  [PASS] Exactly 480 authoritative passengers initialized")
	else:
		print("  [FAIL] Expected 480 passengers, got %d" % p_dict.size())
		total_failures += 1

	var cons = c.verify_passenger_conservation()
	if cons["ok"]:
		print("  [PASS] Level 2 Conservation verified: Total=%d, Duplicates=0, Missing=0" % cons["total"])
		print("  [STATE BREAKDOWN] %s" % str(cons["state_counts"]))
	else:
		print("  [FAIL] Level 2 Conservation failed: %s" % str(cons))
		total_failures += 1

	if gc: gc.current_level_number = 1
	l.queue_free()

# -----------------------------------------------------------------
# 3. Partial Bus Boarding
# -----------------------------------------------------------------
func _test_3_partial_bus_boarding() -> void:
	print("\n--- TEST 3: Partial Bus Boarding ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)

	# Park Bus 3 (Red, capacity 40)
	var v3: VehicleModel = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	v3.reserved_slot = 0
	c.parking.confirm_arrival(0, 3)

	# Prepare 15 red passengers in CIRCULATING state
	var pids_to_board: Array[int] = []
	for pid in c.authoritative_passengers.keys():
		var p = c.authoritative_passengers[pid]
		if p["color_id"] == "red":
			p["state"] = "CIRCULATING"
			pids_to_board.append(pid)
			if pids_to_board.size() == 15:
				break

	# Reserve and commit exactly 15 passengers
	for pid in pids_to_board:
		var p = c.authoritative_passengers[pid]
		var res_ok = c.try_reserve_boarding(pid, 3, p["color_id"], p["group_id"])
		if not res_ok:
			print("  [FAIL] Failed to reserve boarding for passenger %d" % pid)
			total_failures += 1
		var com_ok = c.commit_boarding(pid, 3, p["color_id"], c.session_token)
		if not com_ok:
			print("  [FAIL] Failed to commit boarding for passenger %d" % pid)
			total_failures += 1

	print("  [MEASURED] Bus 3 Occupancy: %d / %d (Remaining: %d)" % [v3.passenger_occupancy, v3.capacity, v3.remaining_capacity()])
	if v3.passenger_occupancy == 15 and v3.remaining_capacity() == 25:
		print("  [PASS] Bus 3 partial occupancy exactly 15/40")
	else:
		print("  [FAIL] Bus occupancy unexpected: %d" % v3.passenger_occupancy)
		total_failures += 1

	var boarded_count := 0
	for pid in pids_to_board:
		if c.authoritative_passengers[pid]["state"] == "BOARDED":
			boarded_count += 1
	if boarded_count == 15:
		print("  [PASS] Exactly 15 passenger records transitioned to BOARDED")
	else:
		print("  [FAIL] Expected 15 boarded passengers, got %d" % boarded_count)
		total_failures += 1

# -----------------------------------------------------------------
# 4. Repeated Returning Colors
# -----------------------------------------------------------------
func _test_4_repeated_returning_colors() -> void:
	print("\n--- TEST 4: Repeated Returning Colors (Independent Group Accounting) ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)

	# Group 0: red, 40 (passengers 0..39)
	# Group 3: red, 40 (passengers 120..159)
	var g0 = c.queue.get_all_groups()[0]
	var g3 = c.queue.get_all_groups()[3]

	print("  [INIT] Group 0 (Red) initial remaining: %d | Group 3 (Red) initial remaining: %d" % [g0.remaining_count, g3.remaining_count])

	var v3: VehicleModel = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	v3.reserved_slot = 0
	c.parking.confirm_arrival(0, 3)

	# Board passenger 10 belonging to Group 0
	c.authoritative_passengers[10]["state"] = "CIRCULATING"
	c.try_reserve_boarding(10, 3, "red", 0)
	c.commit_boarding(10, 3, "red", c.session_token)

	print("  [MEASURED] After boarding P10 (Group 0): G0=%d, G3=%d" % [g0.remaining_count, g3.remaining_count])
	if g0.remaining_count == 39 and g3.remaining_count == 40:
		print("  [PASS] Group 0 decremented by 1, Group 3 remained completely untouched (40)")
	else:
		print("  [FAIL] Group accounting cross-contamination! G0=%d, G3=%d" % [g0.remaining_count, g3.remaining_count])
		total_failures += 1

	# Board passenger 125 belonging to Group 3
	c.authoritative_passengers[125]["state"] = "CIRCULATING"
	c.try_reserve_boarding(125, 3, "red", 3)
	c.commit_boarding(125, 3, "red", c.session_token)

	print("  [MEASURED] After boarding P125 (Group 3): G0=%d, G3=%d" % [g0.remaining_count, g3.remaining_count])
	if g0.remaining_count == 39 and g3.remaining_count == 39:
		print("  [PASS] Group 3 decremented independently by 1! Both groups track accurately")
	else:
		print("  [FAIL] Group 3 decrement failed! G0=%d, G3=%d" % [g0.remaining_count, g3.remaining_count])
		total_failures += 1

# -----------------------------------------------------------------
# 5. Two Matching Buses Parked Simultaneously
# -----------------------------------------------------------------
func _test_5_two_matching_buses_parked_simultaneously() -> void:
	print("\n--- TEST 5: Two Matching Buses Parked Simultaneously ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)

	# Bus 3 (Red, slot 0) and Bus 6 (Red, slot 1)
	var v3: VehicleModel = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	v3.reserved_slot = 0
	c.parking.confirm_arrival(0, 3)

	var v6: VehicleModel = c.vehicles[6]
	v6.state = VehicleModel.VehicleState.PARKED
	v6.reserved_slot = 1
	c.parking.confirm_arrival(1, 6)

	c.authoritative_passengers[1]["state"] = "CIRCULATING"
	c.authoritative_passengers[2]["state"] = "CIRCULATING"

	# P1 reserves Bus 3, P2 reserves Bus 6
	var r1 = c.try_reserve_boarding(1, 3, "red", 0)
	var r2 = c.try_reserve_boarding(2, 6, "red", 0)

	if r1 and r2:
		print("  [PASS] P1 reserved Bus 3 and P2 reserved Bus 6 concurrently")
	else:
		print("  [FAIL] Concurrent reservations failed: r1=%s, r2=%s" % [str(r1), str(r2)])
		total_failures += 1

	# Attempt to commit P1 to Bus 6 (wrong bus!) -> Must fail!
	var wrong_bus_commit = c.commit_boarding(1, 6, "red", c.session_token)
	if not wrong_bus_commit:
		print("  [PASS] Committing P1 to wrong bus (Bus 6) strictly rejected")
	else:
		print("  [FAIL] P1 was illegally committed to a bus it did not reserve!")
		total_failures += 1

	# Commit P1 to Bus 3
	c.commit_boarding(1, 3, "red", c.session_token)
	# Commit P2 to Bus 6
	c.commit_boarding(2, 6, "red", c.session_token)

	print("  [MEASURED] Bus 3 Occupancy: %d | Bus 6 Occupancy: %d" % [v3.passenger_occupancy, v6.passenger_occupancy])
	if v3.passenger_occupancy == 1 and v6.passenger_occupancy == 1:
		print("  [PASS] Each passenger committed exclusively to its assigned bus")
	else:
		print("  [FAIL] Occupancy distribution mismatch: v3=%d, v6=%d" % [v3.passenger_occupancy, v6.passenger_occupancy])
		total_failures += 1

# -----------------------------------------------------------------
# 6. Rapid Boarding Reservations
# -----------------------------------------------------------------
func _test_6_rapid_boarding_reservations() -> void:
	print("\n--- TEST 6: Rapid Boarding Reservations (Capacity Guard) ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)

	var v3: VehicleModel = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	v3.passenger_occupancy = 38 # Only 2 seats remain out of 40!

	var pids: Array[int] = [0, 1, 2, 3, 4]
	var success_count := 0
	var reject_count := 0

	for pid in pids:
		c.authoritative_passengers[pid]["state"] = "CIRCULATING"
		var res = c.try_reserve_boarding(pid, 3, "red", 0)
		if res:
			success_count += 1
		else:
			reject_count += 1

	print("  [MEASURED] Rapid attempts: 5 | Successful: %d | Rejected: %d" % [success_count, reject_count])
	if success_count == 2 and reject_count == 3:
		print("  [PASS] Exactly 2 reservations succeeded (filling 40 seats) and 3 were strictly rejected")
	else:
		print("  [FAIL] Overbooking detected! Success=%d, Reject=%d" % [success_count, reject_count])
		total_failures += 1

# -----------------------------------------------------------------
# 7. Repeated Completion Callback Idempotence
# -----------------------------------------------------------------
func _test_7_repeated_completion_callback_idempotence() -> void:
	print("\n--- TEST 7: Repeated Completion Callback Idempotence ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)

	var v3: VehicleModel = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[5]["state"] = "CIRCULATING"

	c.try_reserve_boarding(5, 3, "red", 0)

	# 1st callback
	var call1 = c.commit_boarding(5, 3, "red", c.session_token)
	var occ1 = v3.passenger_occupancy

	# 2nd callback (duplicate!)
	var call2 = c.commit_boarding(5, 3, "red", c.session_token)
	var occ2 = v3.passenger_occupancy

	# 3rd callback (triplicate!)
	var call3 = c.commit_boarding(5, 3, "red", c.session_token)
	var occ3 = v3.passenger_occupancy

	print("  [MEASURED] Call 1: %s (Occ: %d) | Call 2: %s (Occ: %d) | Call 3: %s (Occ: %d)" % [
		str(call1), occ1, str(call2), occ2, str(call3), occ3
	])

	if call1 == true and call2 == false and call3 == false and occ1 == 1 and occ2 == 1 and occ3 == 1:
		print("  [PASS] Duplicate and triplicate callbacks rejected; occupancy and state perfectly idempotent")
	else:
		print("  [FAIL] Idempotence violated! Double-counting occurred")
		total_failures += 1

# -----------------------------------------------------------------
# 8. Callback After Restart
# -----------------------------------------------------------------
func _test_8_callback_after_restart() -> void:
	print("\n--- TEST 8: Callback After Restart (Session Token Isolation) ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)

	var old_token = c.session_token
	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[6]["state"] = "CIRCULATING"
	c.try_reserve_boarding(6, 3, "red", 0)

	# User restarts the level
	c.restart_level()
	var new_token = c.session_token
	print("  Old Session Token: %d | New Session Token: %d" % [old_token, new_token])

	# Stale callback arrives with old token
	var stale_commit = c.commit_boarding(6, 3, "red", old_token)
	if not stale_commit:
		print("  [PASS] Stale callback from previous session strictly rejected")
	else:
		print("  [FAIL] Stale callback was accepted after restart!")
		total_failures += 1

# -----------------------------------------------------------------
# 9. Callback After Scene Change / Unload
# -----------------------------------------------------------------
func _test_9_callback_after_scene_change() -> void:
	print("\n--- TEST 9: Callback After Scene Change ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)

	# Stale callback with obsolete token 9999
	var invalid_commit = c.commit_boarding(7, 3, "red", 9999)
	if not invalid_commit:
		print("  [PASS] Invalid token callback rejected")
	else:
		print("  [FAIL] Obsolete token callback accepted!")
		total_failures += 1

# -----------------------------------------------------------------
# 10. Pause / Resume During Boarding
# -----------------------------------------------------------------
func _test_10_pause_resume_during_boarding() -> void:
	print("\n--- TEST 10: Pause / Resume During Boarding ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)

	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[8]["state"] = "CIRCULATING"

	# Pause game
	c.state = CarJamController.GameState.PAUSED

	var res_paused = c.try_reserve_boarding(8, 3, "red", 0)
	if not res_paused:
		print("  [PASS] Boarding reservation rejected while game is PAUSED")
	else:
		print("  [FAIL] Reservation allowed during PAUSE!")
		total_failures += 1

	# Resume game
	c.state = CarJamController.GameState.PLAYING

	var res_resumed = c.try_reserve_boarding(8, 3, "red", 0)
	var com_resumed = c.commit_boarding(8, 3, "red", c.session_token)

	if res_resumed and com_resumed:
		print("  [PASS] Reservation and commit succeed cleanly after RESUME")
	else:
		print("  [FAIL] Reservation or commit failed after resume!")
		total_failures += 1

# -----------------------------------------------------------------
# 11. Passenger Cancellation or Animation Interruption Rollback
# -----------------------------------------------------------------
func _test_11_passenger_cancellation_rollback() -> void:
	print("\n--- TEST 11: Passenger Cancellation Rollback ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)

	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[9]["state"] = "CIRCULATING"

	# Reserve
	c.try_reserve_boarding(9, 3, "red", 0)
	print("  State after reservation: %s | Active reservations: %d" % [
		c.authoritative_passengers[9]["state"], c.get_active_reservations_for_vehicle(3)
	])
	if c.authoritative_passengers[9]["state"] == "BOARDING_RESERVED" and c.get_active_reservations_for_vehicle(3) == 1:
		print("  [PASS] Passenger 9 is BOARDING_RESERVED and holding a seat")
	else:
		print("  [FAIL] Reservation state incorrect")
		total_failures += 1

	# Cancel reservation
	var cancel_ok = c.cancel_boarding_reservation(9)
	print("  State after cancellation: %s | Active reservations: %d" % [
		c.authoritative_passengers[9]["state"], c.get_active_reservations_for_vehicle(3)
	])

	if cancel_ok and c.authoritative_passengers[9]["state"] == "CIRCULATING" and c.get_active_reservations_for_vehicle(3) == 0:
		print("  [PASS] Reservation cleanly cancelled; passenger rolled back to CIRCULATING and seat freed")
	else:
		print("  [FAIL] Rollback failed!")
		total_failures += 1

	# Verify passenger can now be reserved again cleanly
	var re_reserve = c.try_reserve_boarding(9, 3, "red", 0)
	if re_reserve:
		print("  [PASS] Rolled back passenger successfully re-reserved")
	else:
		print("  [FAIL] Failed to re-reserve rolled back passenger!")
		total_failures += 1

# -----------------------------------------------------------------
# 12. Final Passenger and Vehicle Completion
# -----------------------------------------------------------------
func _test_12_final_passenger_and_vehicle_completion() -> void:
	print("\n--- TEST 12: Final Passenger and Vehicle Completion (Win State) ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	c.load_level(lvl)

	var level_completed_fired := [false]
	c.level_completed.connect(func(): level_completed_fired[0] = true)

	# Fast-forward simulation of all vehicles and passengers
	for vid in c.vehicles:
		var v = c.vehicles[vid]
		v.state = VehicleModel.VehicleState.PARKED

	for pid in c.authoritative_passengers.keys():
		var p = c.authoritative_passengers[pid]
		p["state"] = "CIRCULATING"
		# Find parked vehicle of matching color with space
		var target_vid := -1
		for vid in c.vehicles:
			var v = c.vehicles[vid]
			if v.color_id == p["color_id"] and v.remaining_capacity() > 0:
				target_vid = vid
				break
		assert(target_vid != -1, "No matching bus for passenger %d!" % pid)
		c.try_reserve_boarding(pid, target_vid, p["color_id"], p["group_id"])
		c.commit_boarding(pid, target_vid, p["color_id"], c.session_token)

	# Mark all vehicles departed
	for vid in c.vehicles:
		var v = c.vehicles[vid]
		v.state = VehicleModel.VehicleState.COMPLETED

	c._check_terminal_states()

	print("  Controller Game State: %d (Expected WIN=2) | Level Completed Emitted: %s" % [c.state, str(level_completed_fired[0])])
	if c.state == CarJamController.GameState.WIN and level_completed_fired[0]:
		print("  [PASS] Game successfully reaches WIN state when all 240 passengers and all buses complete")
	else:
		print("  [FAIL] Win state not reached!")
		total_failures += 1

	var final_cons = c.verify_passenger_conservation()
	if final_cons["ok"] and final_cons["state_counts"]["BOARDED"] == 240:
		print("  [PASS] Final Conservation Invariant: Exactly 240 passengers BOARDED (0 leaks)")
	else:
		print("  [FAIL] Final conservation failed: %s" % str(final_cons))
		total_failures += 1
