extends SceneTree

const CarJamLevelScene = preload("res://scenes/gameplay/car_jam_level.tscn")

var total_failures := 0

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("\n=======================================================")
	print("=== AUTHORITATIVE PASSENGER ACCOUNTING & LIFECYCLE QA ===")
	print("=======================================================")
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		cfg.set_value("data", "current_level", 1)
		cfg.save("user://save.cfg")

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

	# Negative test scenarios
	await _test_13_negative_invalid_group_id()
	await _test_14_negative_wrong_group_color()
	await _test_15_negative_group_exhausted_zero_remaining()
	await _test_16_negative_later_same_color_group_has_demand_while_requested_group_exhausted()
	await _test_17_negative_illegal_state_modifications()
	await _test_18_negative_duplicate_commit()
	await _test_19_negative_cancelled_reservation_late_callback()
	await _test_20_negative_procedural_plan_more_waves_than_authored_groups()
	await _test_21_negative_attempted_invalid_commit_leaves_all_counters_unchanged()
	await _test_22_negative_interrupted_boarding_leaves_no_phantom_seats_or_stranded_passengers()
	await _test_23_level_2_full_playthrough_and_conservation()

	print("\n=======================================================")
	if total_failures == 0:
		print("=== ALL 23 REGRESSION & NEGATIVE TESTS PASSED (0 FAILURES) ===")
	else:
		print("=== %d TESTS FAILED ===" % total_failures)
	print("=======================================================\n")

	quit(total_failures)

func _get_mock_level() -> CarJamLevelData:
	var lvl := CarJamLevelData.new()
	lvl.level_id = 999
	lvl.title = "Mock Level"
	lvl.board_size = Vector2i(5, 5)
	lvl.parking_slots_count = 8
	var unl: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
	lvl.unlocked_slot_ids = unl

	var colors: Array[String] = ["red", "blue", "yellow", "red", "blue", "yellow"]
	var groups: Array[PassengerGroupData] = []
	for i in 6:
		var g := PassengerGroupData.new()
		g.group_id = i
		g.color_id = colors[i]
		g.initial_count = 40
		g.remaining_count = 40
		groups.append(g)
	lvl.passenger_groups = groups

	var vehs: Array[CarJamVehicleData] = []
	var v_defs := [
		{"id": 1, "code": "v1_blue", "color": "blue", "anchor": Vector2i(3, 2), "footprint": [Vector2i(0, 0), Vector2i(0, 1)], "dir": 0},
		{"id": 2, "code": "v2_yellow", "color": "yellow", "anchor": Vector2i(3, 1), "footprint": [Vector2i(0, 0), Vector2i(1, 0)], "dir": 2},
		{"id": 3, "code": "v3_red", "color": "red", "anchor": Vector2i(1, 2), "footprint": [Vector2i(0, 0), Vector2i(1, 0)], "dir": 2},
		{"id": 4, "code": "v4_blue", "color": "blue", "anchor": Vector2i(4, 2), "footprint": [Vector2i(0, 0), Vector2i(0, 1)], "dir": 0},
		{"id": 5, "code": "v5_yellow", "color": "yellow", "anchor": Vector2i(0, 2), "footprint": [Vector2i(0, 0), Vector2i(0, 1)], "dir": 0},
		{"id": 6, "code": "v6_red", "color": "red", "anchor": Vector2i(1, 3), "footprint": [Vector2i(0, 0), Vector2i(1, 0)], "dir": 2}
	]
	for vd in v_defs:
		var v := CarJamVehicleData.new()
		v.id = vd["id"]
		v.code = vd["code"]
		v.color_id = vd["color"]
		v.capacity = 40
		v.anchor = vd["anchor"]
		v.initial_anchor = vd["anchor"]
		var fp: Array[Vector2i] = []
		for p in vd["footprint"]: fp.append(p)
		v.footprint = fp
		v.direction = vd["dir"]
		vehs.append(v)
	lvl.vehicles = vehs
	return lvl

# -----------------------------------------------------------------
# 1. Level 1 Initialization — 240 Unique Passenger IDs
# -----------------------------------------------------------------
func _test_1_level_1_initialization() -> void:
	print("\n--- TEST 1: Level 1 Initialization (240 Unique Passenger IDs) ---")
	var gc = root.get_node_or_null("GameController")
	if gc:
		gc.current_level_number = 1
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
	var lvl: CarJamLevelData = _get_mock_level()
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
	var lvl: CarJamLevelData = _get_mock_level()
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
	var lvl: CarJamLevelData = _get_mock_level()
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
	var lvl: CarJamLevelData = _get_mock_level()
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
	var lvl: CarJamLevelData = _get_mock_level()
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
	var lvl: CarJamLevelData = _get_mock_level()
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
	var lvl: CarJamLevelData = _get_mock_level()
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
	var lvl: CarJamLevelData = _get_mock_level()
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
	var lvl: CarJamLevelData = _get_mock_level()
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
	var lvl: CarJamLevelData = _get_mock_level()
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

# -----------------------------------------------------------------
# 13. Negative Test: Valid Passenger Has Invalid Group ID
# -----------------------------------------------------------------
func _test_13_negative_invalid_group_id() -> void:
	print("\n--- TEST 13 (NEGATIVE): Valid Passenger Has Invalid Group ID ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = _get_mock_level()
	c.load_level(lvl)

	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[10]["state"] = "CIRCULATING"
	c.authoritative_passengers[10]["group_id"] = 999 # Invalid group index

	var res = c.try_reserve_boarding(10, 3, "red", 999)
	if not res:
		print("  [PASS] Reservation with invalid group_id strictly rejected")
	else:
		print("  [FAIL] Reservation allowed with invalid group_id!")
		total_failures += 1

	var com = c.commit_boarding(10, 3, "red", c.session_token)
	if not com:
		print("  [PASS] Commit with invalid group_id strictly rejected")
	else:
		print("  [FAIL] Commit allowed with invalid group_id!")
		total_failures += 1

	if v3.passenger_occupancy == 0:
		print("  [PASS] Bus occupancy unchanged (0/40)")
	else:
		print("  [FAIL] Bus occupancy mutated!")
		total_failures += 1

# -----------------------------------------------------------------
# 14. Negative Test: Passenger Assigned to Wrong Color Group
# -----------------------------------------------------------------
func _test_14_negative_wrong_group_color() -> void:
	print("\n--- TEST 14 (NEGATIVE): Passenger Assigned to Wrong Color Group ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = _get_mock_level()
	c.load_level(lvl)

	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[11]["state"] = "CIRCULATING"
	# Passenger 11 is red, but assigned to Group 1 (which is blue)
	c.authoritative_passengers[11]["group_id"] = 1

	var res = c.try_reserve_boarding(11, 3, "red", 1)
	if not res:
		print("  [PASS] Reservation with mismatched group color strictly rejected")
	else:
		print("  [FAIL] Reservation allowed for mismatched group color!")
		total_failures += 1

	var com = c.commit_boarding(11, 3, "red", c.session_token)
	if not com:
		print("  [PASS] Commit with mismatched group color strictly rejected")
	else:
		print("  [FAIL] Commit allowed for mismatched group color!")
		total_failures += 1

	if v3.passenger_occupancy == 0 and c.queue.get_all_groups()[1].remaining_count == 40:
		print("  [PASS] Bus occupancy and group counters completely untouched")
	else:
		print("  [FAIL] State or counters corrupted by invalid commit!")
		total_failures += 1

# -----------------------------------------------------------------
# 15. Negative Test: Exact Group Has Zero Remaining Demand
# -----------------------------------------------------------------
func _test_15_negative_group_exhausted_zero_remaining() -> void:
	print("\n--- TEST 15 (NEGATIVE): Exact Group Has Zero Remaining Demand ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = _get_mock_level()
	c.load_level(lvl)

	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[12]["state"] = "CIRCULATING"
	c.authoritative_passengers[12]["group_id"] = 0

	# Force Group 0 to have 0 remaining
	c.queue.get_all_groups()[0].remaining_count = 0

	var res = c.try_reserve_boarding(12, 3, "red", 0)
	if not res:
		print("  [PASS] Reservation rejected when exact group has 0 remaining demand")
	else:
		print("  [FAIL] Reservation accepted on exhausted group!")
		total_failures += 1

	var com = c.commit_boarding(12, 3, "red", c.session_token)
	if not com:
		print("  [PASS] Commit rejected when exact group has 0 remaining demand")
	else:
		print("  [FAIL] Commit accepted on exhausted group!")
		total_failures += 1

# -----------------------------------------------------------------
# 16. Negative Test: Later Same-Color Group Demand Not Stolen
# -----------------------------------------------------------------
func _test_16_negative_later_same_color_group_has_demand_while_requested_group_exhausted() -> void:
	print("\n--- TEST 16 (NEGATIVE): No Wrong-Group Fallback When Requested Group Exhausted ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = _get_mock_level()
	c.load_level(lvl)

	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[13]["state"] = "CIRCULATING"
	c.authoritative_passengers[13]["group_id"] = 0

	# Group 0 (Red) exhausted, Group 3 (Red) has 40 remaining
	c.queue.get_all_groups()[0].remaining_count = 0
	var g3_initial_rem: int = c.queue.get_all_groups()[3].remaining_count
	assert(g3_initial_rem == 40, "Group 3 must start with 40 remaining")

	var res = c.try_reserve_boarding(13, 3, "red", 0)
	var com = c.commit_boarding(13, 3, "red", c.session_token)

	if not res and not com:
		print("  [PASS] Both reservation and commit strictly rejected for exhausted Group 0")
	else:
		print("  [FAIL] Reservation or commit accepted on exhausted group!")
		total_failures += 1

	# Critical assertion: Group 3 must NOT have been decremented
	var g3_post_rem: int = c.queue.get_all_groups()[3].remaining_count
	if g3_post_rem == 40:
		print("  [PASS] Strict authoritative isolation: Group 3 remaining demand was NOT stolen (remains 40)")
	else:
		print("  [FAIL] Wrong-group fallback occurred! Group 3 demand decremented from 40 to %d" % g3_post_rem)
		total_failures += 1

# -----------------------------------------------------------------
# 17. Negative Test: Illegal State Modifications
# -----------------------------------------------------------------
func _test_17_negative_illegal_state_modifications() -> void:
	print("\n--- TEST 17 (NEGATIVE): Illegal State Transition Enforcement ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = _get_mock_level()
	c.load_level(lvl)

	# 1. Unknown passenger
	var unknown_res = c.set_passenger_state(9999, "CIRCULATING")
	if not unknown_res:
		print("  [PASS] set_passenger_state rejects unknown passenger ID")
	else:
		print("  [FAIL] set_passenger_state accepted unknown passenger!")
		total_failures += 1

	# 2. Direct assignment of BOARDED (forbidden outside commit_boarding)
	var direct_boarded = c.set_passenger_state(14, "BOARDED")
	if not direct_boarded:
		print("  [PASS] Direct mutation to BOARDED strictly forbidden")
	else:
		print("  [FAIL] Direct mutation to BOARDED permitted!")
		total_failures += 1

	# 3. Direct assignment of BOARDING_RESERVED (forbidden outside try_reserve_boarding)
	var direct_reserved = c.set_passenger_state(14, "BOARDING_RESERVED")
	if not direct_reserved:
		print("  [PASS] Direct mutation to BOARDING_RESERVED strictly forbidden")
	else:
		print("  [FAIL] Direct mutation to BOARDING_RESERVED permitted!")
		total_failures += 1

	# 4. Valid initial placement PENDING -> CIRCULATING
	var valid_circ = c.set_passenger_state(14, "CIRCULATING")
	if valid_circ:
		print("  [PASS] Legitimate transition PENDING -> CIRCULATING allowed")
	else:
		print("  [FAIL] Legitimate initial transition PENDING -> CIRCULATING rejected!")
		total_failures += 1

	# 5. Invalid transition CIRCULATING -> FEEDER
	var circ_to_feeder = c.set_passenger_state(14, "FEEDER")
	if not circ_to_feeder:
		print("  [PASS] Backward transition CIRCULATING -> FEEDER strictly rejected")
	else:
		print("  [FAIL] Backward transition CIRCULATING -> FEEDER accepted!")
		total_failures += 1

	# 6. Commit passenger 14 so it becomes BOARDED
	c.vehicles[3].state = VehicleModel.VehicleState.PARKED
	c.try_reserve_boarding(14, 3, "red", 0)
	c.commit_boarding(14, 3, "red", c.session_token)
	assert(c.authoritative_passengers[14]["state"] == "BOARDED", "Passenger 14 must be BOARDED")

	# 7. Terminal state protection: BOARDED cannot transition away
	var boarded_to_circ = c.set_passenger_state(14, "CIRCULATING")
	var boarded_to_feeder = c.set_passenger_state(14, "FEEDER")
	var boarded_to_pending = c.set_passenger_state(14, "PENDING")
	if not boarded_to_circ and not boarded_to_feeder and not boarded_to_pending:
		print("  [PASS] Terminal state protection: BOARDED passenger cannot be reactivated")
	else:
		print("  [FAIL] BOARDED passenger was illegally reactivated!")
		total_failures += 1

# -----------------------------------------------------------------
# 18. Negative Test: Duplicate Commit Calls
# -----------------------------------------------------------------
func _test_18_negative_duplicate_commit() -> void:
	print("\n--- TEST 18 (NEGATIVE): Duplicate Commit Idempotence & Counter Invariance ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = _get_mock_level()
	c.load_level(lvl)

	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[15]["state"] = "CIRCULATING"

	c.try_reserve_boarding(15, 3, "red", 0)
	var com1 = c.commit_boarding(15, 3, "red", c.session_token)
	if com1:
		print("  [PASS] First commit succeeded")
	else:
		print("  [FAIL] First commit failed!")
		total_failures += 1

	var occ_after_com1: int = v3.passenger_occupancy
	var g0_rem_after_com1: int = c.queue.get_all_groups()[0].remaining_count

	# Duplicate calls
	var com2 = c.commit_boarding(15, 3, "red", c.session_token)
	var com3 = c.commit_boarding(15, 3, "red", c.session_token)

	if not com2 and not com3:
		print("  [PASS] Subsequent duplicate commits cleanly rejected (returned false)")
	else:
		print("  [FAIL] Duplicate commit accepted!")
		total_failures += 1

	if v3.passenger_occupancy == occ_after_com1 and c.queue.get_all_groups()[0].remaining_count == g0_rem_after_com1:
		print("  [PASS] Vehicle occupancy (%d) and group remaining (%d) strictly invariant across duplicate commits" % [occ_after_com1, g0_rem_after_com1])
	else:
		print("  [FAIL] Counters corrupted by duplicate commits!")
		total_failures += 1

# -----------------------------------------------------------------
# 19. Negative Test: Cancelled Reservation Late Callback
# -----------------------------------------------------------------
func _test_19_negative_cancelled_reservation_late_callback() -> void:
	print("\n--- TEST 19 (NEGATIVE): Late Callback After Cancellation ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = _get_mock_level()
	c.load_level(lvl)

	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[16]["state"] = "CIRCULATING"

	c.try_reserve_boarding(16, 3, "red", 0)
	c.cancel_boarding_reservation(16)

	var late_com = c.commit_boarding(16, 3, "red", c.session_token)
	if not late_com:
		print("  [PASS] Stale callback for cancelled reservation strictly rejected")
	else:
		print("  [FAIL] Stale callback accepted after cancellation!")
		total_failures += 1

	if v3.passenger_occupancy == 0 and c.queue.get_all_groups()[0].remaining_count == 40:
		print("  [PASS] Seat and group counters untouched (0 boarded, 40 remaining)")
	else:
		print("  [FAIL] Seat or group counter mutated by stale callback!")
		total_failures += 1

# -----------------------------------------------------------------
# 20. Negative Test: Procedural Plan Has More Waves Than Authored Groups
# -----------------------------------------------------------------
func _test_20_negative_procedural_plan_more_waves_than_authored_groups() -> void:
	print("\n--- TEST 20 (NEGATIVE): Procedural Plan With More Waves Than Authored Groups ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = _get_mock_level()
	c.load_level(lvl)

	var WavePlanClass = load("res://scripts/universal/wave_plan.gd")
	var plan: WavePlan = WavePlanClass.new()
	# Split 240 passengers across 12 waves of 20 (authored level has only 6 groups of 40)
	var wave_colors = ["red", "red", "blue", "blue", "yellow", "yellow", "red", "red", "blue", "blue", "yellow", "yellow"]
	for col in wave_colors:
		plan.waves.append({"color": col, "count": 20})

	# Map waves to authored groups
	plan.assign_source_groups(lvl.passenger_groups)
	var flat = plan.flatten(lvl.passenger_groups)

	# Verify every single passenger has a valid group_id within 0..5
	var all_valid_groups := true
	var group_counts := {}
	for p_info in flat:
		var gid: int = int(p_info["group_id"])
		if gid < 0 or gid >= lvl.passenger_groups.size():
			all_valid_groups = false
			break
		group_counts[gid] = group_counts.get(gid, 0) + 1

	if all_valid_groups:
		print("  [PASS] All 240 passengers mapped to valid authored groups (0..5) despite 12 waves")
	else:
		print("  [FAIL] Mapped passenger had out-of-bounds group ID!")
		total_failures += 1

	# Verify per-group counts: exactly 40 per authored group
	var group_counts_exact := true
	for g_i in lvl.passenger_groups.size():
		if group_counts.get(g_i, 0) != 40:
			group_counts_exact = false
			break

	if group_counts_exact:
		print("  [PASS] Each authored group receives exactly 40 passengers across split waves")
	else:
		print("  [FAIL] Split wave demand did not sum to authored group capacity: %s" % str(group_counts))
		total_failures += 1

	# Register into controller and run conservation validation
	c.register_passengers(flat)
	var cons = c.verify_passenger_conservation()
	if cons["ok"] and cons["group_errors"].is_empty():
		print("  [PASS] Conservation verification passed 100% for split procedural wave plan")
	else:
		print("  [FAIL] Conservation check failed for split wave plan: %s" % str(cons))
		total_failures += 1

# -----------------------------------------------------------------
# 21. Negative Test: Attempted Invalid Commits Leave All Counters Unchanged
# -----------------------------------------------------------------
func _test_21_negative_attempted_invalid_commit_leaves_all_counters_unchanged() -> void:
	print("\n--- TEST 21 (NEGATIVE): Invalid Commits Leave Every Counter Untouched ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = _get_mock_level()
	c.load_level(lvl)

	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED

	var pre_occupancy: int = v3.passenger_occupancy
	var pre_g0_rem: int = c.queue.get_all_groups()[0].remaining_count
	var pre_g1_rem: int = c.queue.get_all_groups()[1].remaining_count
	var pre_active_res: int = c.get_active_reservations_for_vehicle(3)

	# Execute invalid commit operations
	c.commit_boarding(9999, 3, "red", c.session_token) # Nonexistent passenger
	c.commit_boarding(1, 3, "red", 8888) # Wrong session token
	c.commit_boarding(1, 3, "red", c.session_token) # Unreserved passenger
	c.commit_boarding(1, 6, "red", c.session_token) # Wrong bus
	c.commit_boarding(1, 3, "blue", c.session_token) # Wrong color

	var post_occupancy: int = v3.passenger_occupancy
	var post_g0_rem: int = c.queue.get_all_groups()[0].remaining_count
	var post_g1_rem: int = c.queue.get_all_groups()[1].remaining_count
	var post_active_res: int = c.get_active_reservations_for_vehicle(3)

	if pre_occupancy == post_occupancy and pre_g0_rem == post_g0_rem and pre_g1_rem == post_g1_rem and pre_active_res == post_active_res:
		print("  [PASS] Absolute invariance: Occupancy, group counts, and reservations 100% unchanged")
	else:
		print("  [FAIL] Counters were modified by rejected commits!")
		total_failures += 1

# -----------------------------------------------------------------
# 22. Negative Test: Interrupted Boarding Leaves No Phantom Seats Or Stranded Passengers
# -----------------------------------------------------------------
func _test_22_negative_interrupted_boarding_leaves_no_phantom_seats_or_stranded_passengers() -> void:
	print("\n--- TEST 22 (NEGATIVE): Interrupted Boarding Cleanup & Rollback ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = _get_mock_level()
	c.load_level(lvl)

	var v3 = c.vehicles[3]
	v3.state = VehicleModel.VehicleState.PARKED
	c.authoritative_passengers[17]["state"] = "CIRCULATING"

	# Reserve
	c.try_reserve_boarding(17, 3, "red", 0)
	assert(c.get_active_reservations_for_vehicle(3) == 1, "Reservation must be registered")

	# Simulate interruption / animation failure
	var cancel_ok = c.cancel_boarding_reservation(17)
	if cancel_ok:
		print("  [PASS] Reservation cancellation succeeded")
	else:
		print("  [FAIL] Reservation cancellation failed!")
		total_failures += 1

	var active_res: int = c.get_active_reservations_for_vehicle(3)
	var sync_pending: int = int(c.pending_boarders.get(3, 0))
	var p_state: String = c.authoritative_passengers[17]["state"]

	if active_res == 0 and sync_pending == 0 and p_state == "CIRCULATING" and v3.passenger_occupancy == 0:
		print("  [PASS] No phantom seat reservation (active=0, pending=0, occ=0) and passenger restored to CIRCULATING")
	else:
		print("  [FAIL] Residual phantom reservation or passenger state corrupted!")
		total_failures += 1

	# Re-reserve succeeds cleanly
	var re_res = c.try_reserve_boarding(17, 3, "red", 0)
	if re_res:
		print("  [PASS] Interrupted passenger successfully re-reserved without state friction")
	else:
		print("  [FAIL] Failed to re-reserve passenger after interruption!")
		total_failures += 1

# -----------------------------------------------------------------
# 23. Level 2 Full Playthrough and Conservation Invariant Verification
# -----------------------------------------------------------------
func _test_23_level_2_full_playthrough_and_conservation() -> void:
	print("\n--- TEST 23: Level 2 Full Playthrough & Strict Conservation ---")
	var c := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_002.tres")
	c.load_level(lvl)

	# Verify Level 2 initial setup
	assert(c.vehicles.size() == 12, "Level 2 must have 12 vehicles")
	assert(c.authoritative_passengers.size() == 480, "Level 2 must have 480 passengers")

	var level_completed_fired := [false]
	c.level_completed.connect(func(): level_completed_fired[0] = true)

	for vid in c.vehicles:
		var v = c.vehicles[vid]
		v.state = VehicleModel.VehicleState.PARKED

	for pid in c.authoritative_passengers.keys():
		var p = c.authoritative_passengers[pid]
		p["state"] = "CIRCULATING"
		var target_vid := -1
		for vid in c.vehicles:
			var v = c.vehicles[vid]
			if v.color_id == p["color_id"] and v.remaining_capacity() > 0:
				target_vid = vid
				break
		assert(target_vid != -1, "No available bus for Level 2 passenger %d!" % pid)
		c.try_reserve_boarding(pid, target_vid, p["color_id"], p["group_id"])
		c.commit_boarding(pid, target_vid, p["color_id"], c.session_token)

	for vid in c.vehicles:
		var v = c.vehicles[vid]
		v.state = VehicleModel.VehicleState.COMPLETED

	c._check_terminal_states()

	print("  Level 2 Controller Game State: %d (Expected WIN=2) | Level Completed: %s" % [c.state, str(level_completed_fired[0])])
	if c.state == CarJamController.GameState.WIN and level_completed_fired[0]:
		print("  [PASS] Level 2 cleanly reached WIN state with all 480 passengers and 12 buses")
	else:
		print("  [FAIL] Level 2 win state not reached!")
		total_failures += 1

	var final_cons = c.verify_passenger_conservation()
	if final_cons["ok"] and final_cons["state_counts"]["BOARDED"] == 480:
		print("  [PASS] Level 2 Final Conservation Invariant: Exactly 480 passengers BOARDED (0 leaks, 0 group errors)")
	else:
		print("  [FAIL] Level 2 final conservation failed: %s" % str(final_cons))
		total_failures += 1
