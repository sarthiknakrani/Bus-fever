extends SceneTree

## Automated Regression QA Suite for Reference-Accurate Bus Core Gameplay (Tests A through R)
## Validates complete bus puzzle mechanics, swept-footprint collisions, in-flight corridor protection,
## parking lifecycle, boarding gate integration, solver consistency, and booster integrity.

var failures: Array[String] = []
var passed_count: int = 0

func _init() -> void:
	call_deferred("_run_all_tests")

func _assert_test(cond: bool, test_name: String, detail: String = "") -> void:
	if cond:
		passed_count += 1
		print("  [PASS] %s %s" % [test_name, detail])
	else:
		failures.append("%s: %s" % [test_name, detail])
		print("  [FAIL] %s: %s" % [test_name, detail])

func _run_all_tests() -> void:
	print("\n=========================================================================")
	print("=== RUNNING REFERENCE-ACCURATE BUS CORE GAMEPLAY QA SUITE (A - R) ===")
	print("=========================================================================\n")

	_test_a_directional_escapes()
	_test_b_blocked_directional_escapes()
	_test_c_full_footprint_collision()
	_test_d_dynamic_unblocking()
	_test_e_double_tap_idempotency()
	_test_f_simultaneous_transit_and_corridor_reservation()
	_test_g_parking_full_rejection()
	_test_h_parking_lifecycle_transitions()
	_test_i_color_matching_strictness()
	_test_j_full_capacity_automatic_departure()
	_test_k_partial_capacity_waiting()
	_test_l_passenger_conservation_accounting()
	_test_m_genuine_deadlock_detection()
	_test_n_false_deadlock_prevention()
	await _test_o_full_level_completion()
	_test_p_booster_regressions()
	_test_q_restart_and_pause_determinism()
	_test_r_solver_gameplay_agreement()

	print("\n=========================================================================")
	if failures.is_empty():
		print("=== ALL REFERENCE-ACCURATE BUS GAMEPLAY TESTS PASSED (%d / %d) ===" % [passed_count, passed_count])
		print("=========================================================================\n")
		quit(0)
	else:
		print("=== TEST FAILURES ENCOUNTERED (%d failures, %d passed) ===" % [failures.size(), passed_count])
		for f in failures:
			print("  - %s" % f)
		print("=========================================================================\n")
		quit(1)

# -----------------------------------------------------------------
# TEST A: Clear directional escape (UP, DOWN, LEFT, RIGHT)
# -----------------------------------------------------------------
func _test_a_directional_escapes() -> void:
	print("--- TEST A: Clear Directional Escapes (UP, DOWN, LEFT, RIGHT) ---")
	var board := CarJamBoardModel.new()
	board.setup(Vector2i(6, 6))

	var v_up := _make_vehicle(1, Vector2i(1, 4), CarJamVehicleData.Direction.UP, [Vector2i(0, 0), Vector2i(0, 1)])
	var v_down := _make_vehicle(2, Vector2i(3, 1), CarJamVehicleData.Direction.DOWN, [Vector2i(0, 0), Vector2i(0, 1)])
	var v_left := _make_vehicle(3, Vector2i(4, 3), CarJamVehicleData.Direction.LEFT, [Vector2i(0, 0), Vector2i(1, 0)])
	var v_right := _make_vehicle(4, Vector2i(0, 0), CarJamVehicleData.Direction.RIGHT, [Vector2i(0, 0)])

	board.place_vehicle(v_up)
	board.place_vehicle(v_down)
	board.place_vehicle(v_left)
	board.place_vehicle(v_right)

	var esc_up = board.check_swept_escape(v_up)
	var esc_down = board.check_swept_escape(v_down)
	var esc_left = board.check_swept_escape(v_left)
	var esc_right = board.check_swept_escape(v_right)

	_assert_test(esc_up["can_escape"], "Test A1", "Bus facing UP escapes with clear path")
	_assert_test(esc_down["can_escape"], "Test A2", "Bus facing DOWN escapes with clear path")
	_assert_test(esc_left["can_escape"], "Test A3", "Bus facing LEFT escapes with clear path")
	_assert_test(esc_right["can_escape"], "Test A4", "Bus facing RIGHT escapes with clear path")

# -----------------------------------------------------------------
# TEST B: Blocked directional escape
# -----------------------------------------------------------------
func _test_b_blocked_directional_escapes() -> void:
	print("--- TEST B: Blocked Directional Escapes ---")
	var board := CarJamBoardModel.new()
	board.setup(Vector2i(6, 6))

	# Bus 1 facing UP at (2, 4), blocked by Bus 2 at (2, 2)
	var v1 := _make_vehicle(1, Vector2i(2, 4), CarJamVehicleData.Direction.UP, [Vector2i(0, 0)])
	var blocker_up := _make_vehicle(2, Vector2i(2, 2), CarJamVehicleData.Direction.RIGHT, [Vector2i(0, 0)])
	board.place_vehicle(v1)
	board.place_vehicle(blocker_up)

	var res_up = board.check_swept_escape(v1)
	_assert_test(not res_up["can_escape"] and res_up["blocker_id"] == 2, "Test B1", "Bus blocked facing UP detected blocker_id=2")

	# Bus 3 facing DOWN at (4, 1), blocked by Bus 4 at (4, 4)
	var v3 := _make_vehicle(3, Vector2i(4, 1), CarJamVehicleData.Direction.DOWN, [Vector2i(0, 0)])
	var blocker_down := _make_vehicle(4, Vector2i(4, 4), CarJamVehicleData.Direction.LEFT, [Vector2i(0, 0)])
	board.place_vehicle(v3)
	board.place_vehicle(blocker_down)

	var res_down = board.check_swept_escape(v3)
	_assert_test(not res_down["can_escape"] and res_down["blocker_id"] == 4, "Test B2", "Bus blocked facing DOWN detected blocker_id=4")

# -----------------------------------------------------------------
# TEST C: Full-footprint collision (multi-cell geometries)
# -----------------------------------------------------------------
func _test_c_full_footprint_collision() -> void:
	print("--- TEST C: Full-Footprint Collision Checking ---")
	var board := CarJamBoardModel.new()
	board.setup(Vector2i(7, 7))

	# Bus 10 has a 2-wide footprint [ (0, 0), (1, 0) ] at (1, 3) facing UP
	# If center or left cell is clear but right cell (2, 1) has an obstacle, must detect collision!
	var v10 := _make_vehicle(10, Vector2i(1, 3), CarJamVehicleData.Direction.UP, [Vector2i(0, 0), Vector2i(1, 0)])
	var obstacle := _make_vehicle(99, Vector2i(2, 1), CarJamVehicleData.Direction.RIGHT, [Vector2i(0, 0)])

	board.place_vehicle(v10)
	board.place_vehicle(obstacle)

	var esc = board.check_swept_escape(v10)
	_assert_test(not esc["can_escape"], "Test C1", "Wide footprint detected blocker on right swept lane")
	_assert_test(esc["blocker_id"] == 99, "Test C2", "Correct blocker ID returned for edge collision")

# -----------------------------------------------------------------
# TEST D: Dynamic unblocking
# -----------------------------------------------------------------
func _test_d_dynamic_unblocking() -> void:
	print("--- TEST D: Dynamic Unblocking ---")
	var board := CarJamBoardModel.new()
	board.setup(Vector2i(5, 5))

	var v_blocked := _make_vehicle(1, Vector2i(2, 3), CarJamVehicleData.Direction.UP, [Vector2i(0, 0), Vector2i(0, 1)])
	var v_blocker := _make_vehicle(2, Vector2i(2, 1), CarJamVehicleData.Direction.RIGHT, [Vector2i(0, 0), Vector2i(1, 0)])

	board.place_vehicle(v_blocked)
	board.place_vehicle(v_blocker)

	_assert_test(not board.check_swept_escape(v_blocked)["can_escape"], "Test D1", "Initial state: vehicle 1 is blocked")

	# Remove blocker (simulating blocker departure)
	board.remove_vehicle(2)

	_assert_test(board.check_swept_escape(v_blocked)["can_escape"], "Test D2", "After blocker removal: vehicle 1 becomes legally escapable")

# -----------------------------------------------------------------
# TEST E: Double tap idempotency
# -----------------------------------------------------------------
func _test_e_double_tap_idempotency() -> void:
	print("--- TEST E: Double Tap Idempotency ---")
	var lvl := CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	# Bus 4 is free at start
	var tap1 = ctrl.tap_vehicle(4)
	var tap2 = ctrl.tap_vehicle(4)

	_assert_test(tap1 == true, "Test E1", "First tap accepted")
	_assert_test(tap2 == false, "Test E2", "Rapid second tap rejected")
	_assert_test(ctrl.move_count == 1, "Test E3", "move_count incremented exactly once")
	_assert_test(ctrl.parking.get_available_slot_count() == ctrl.parking.get_unlocked_slot_count() - 1, "Test E4", "Only one parking slot reserved")

# -----------------------------------------------------------------
# TEST F: Simultaneous transit & in-flight corridor protection
# -----------------------------------------------------------------
func _test_f_simultaneous_transit_and_corridor_reservation() -> void:
	print("--- TEST F: Simultaneous Transit & In-Flight Corridor Protection ---")
	var board := CarJamBoardModel.new()
	board.setup(Vector2i(7, 7))

	# Bus 10 at (1, 1) facing DOWN. Its swept corridor: (1, 2), (1, 3), (1, 4), (1, 5), (1, 6)
	var v10 := _make_vehicle(10, Vector2i(1, 1), CarJamVehicleData.Direction.DOWN, [Vector2i(0, 0), Vector2i(0, 1)])
	# Bus 20 at (1, 5) facing DOWN (directly in Bus 10's exit path)
	var v20 := _make_vehicle(20, Vector2i(1, 5), CarJamVehicleData.Direction.DOWN, [Vector2i(0, 0)])
	# Bus 30 at (5, 5) facing UP (independent corridor on the right side)
	var v30 := _make_vehicle(30, Vector2i(5, 5), CarJamVehicleData.Direction.UP, [Vector2i(0, 0), Vector2i(0, 1)])

	board.place_vehicle(v10)
	board.place_vehicle(v30)

	# Simulate Bus 10 dispatch: reserve its in-flight corridor and remove from static grid
	var esc10 = board.check_swept_escape(v10)
	board.reserve_in_flight(10, v10.get_occupied_cells(), esc10["swept_corridor"])
	board.remove_vehicle(10)

	# Now test if Bus 20 (whose footprint or path crosses Bus 10's in-flight cells) is blocked
	v20.state = VehicleModel.VehicleState.ON_BOARD
	var esc20 = board.check_swept_escape(v20)
	_assert_test(not esc20["can_escape"] and esc20["blocker_id"] == 10, "Test F1", "Conflicting Bus 20 blocked by in-flight Bus 10")

	# Now test independent Bus 30 on column 5
	var esc30 = board.check_swept_escape(v30)
	_assert_test(esc30["can_escape"], "Test F2", "Independent Bus 30 can transit simultaneously without collision")

	# Release Bus 10 after clearing the board
	board.clear_in_flight(10)
	var esc20_after = board.check_swept_escape(v20)
	_assert_test(esc20_after["can_escape"], "Test F3", "Bus 20 becomes legally dispatchable after Bus 10 clears the board")

# -----------------------------------------------------------------
# TEST G: Parking full dispatch rejection
# -----------------------------------------------------------------
func _test_g_parking_full_rejection() -> void:
	print("--- TEST G: Parking Full Rejection ---")
	var lvl := CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	# Fill all available slots (slots 1..6)
	var unlocked_slots = ctrl.parking.get_unlocked_slot_ids()
	for s_id in unlocked_slots:
		var slot = ctrl.parking.get_slot(s_id)
		slot.state = CarJamParkingManager.SlotState.OCCUPIED
		slot.vehicle_id = 900 + s_id

	_assert_test(ctrl.parking.is_full(), "Test G1", "Parking is completely full")

	# Try to dispatch free bus 4
	var warning_fired := [false]
	ctrl.parking_full_warning.connect(func(): warning_fired[0] = true)

	var ok = ctrl.tap_vehicle(4)
	_assert_test(not ok, "Test G2", "Dispatch rejected when parking is full")
	_assert_test(warning_fired[0], "Test G3", "parking_full_warning signal emitted")
	_assert_test(ctrl.vehicles[4].state == VehicleModel.VehicleState.ON_BOARD, "Test G4", "Bus remains ON_BOARD")

# -----------------------------------------------------------------
# TEST H: Parking lifecycle (FREE -> RESERVED -> OCCUPIED -> DEPARTING -> FREE)
# -----------------------------------------------------------------
func _test_h_parking_lifecycle_transitions() -> void:
	print("--- TEST H: Parking Lifecycle Transitions ---")
	var pm := CarJamParkingManager.new()
	pm.setup(4)

	# Initial: Slot 1 is FREE
	var s1 = pm.get_slot(1)
	_assert_test(s1.state == CarJamParkingManager.SlotState.FREE, "Test H1", "Initial slot state is FREE")

	# 1. Reservation
	var reserved_id = pm.reserve_slot(42)
	_assert_test(reserved_id == 1 and s1.state == CarJamParkingManager.SlotState.RESERVED, "Test H2", "Transition to RESERVED")
	_assert_test(not s1.is_available(), "Test H3", "RESERVED slot is not available")

	# 2. Arrival
	var arrived = pm.confirm_arrival(1, 42)
	_assert_test(arrived and s1.state == CarJamParkingManager.SlotState.OCCUPIED, "Test H4", "Transition to OCCUPIED on arrival")

	# 3. Departure started
	pm.mark_departing(1, 42)
	_assert_test(s1.state == CarJamParkingManager.SlotState.DEPARTING, "Test H5", "Transition to DEPARTING")
	_assert_test(not s1.is_available(), "Test H6", "DEPARTING slot remains unavailable")

	# 4. Off-screen release
	var released = pm.release_slot(1, 42)
	_assert_test(released and s1.state == CarJamParkingManager.SlotState.FREE, "Test H7", "Transition back to FREE on final exit")
	_assert_test(s1.vehicle_id == -1 and s1.is_available(), "Test H8", "Slot is now free and available for next vehicle")

# -----------------------------------------------------------------
# TEST I: Color matching strictness
# -----------------------------------------------------------------
func _test_i_color_matching_strictness() -> void:
	print("--- TEST I: Color Matching Strictness ---")
	var lvl := CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	# Bus 3 is RED. Park it in slot 1
	var sid = ctrl.parking.reserve_slot(3)
	ctrl.parking.confirm_arrival(sid, 3)
	ctrl.vehicles[3].state = VehicleModel.VehicleState.PARKED

	# In Level 1, passengers 0..39 are RED (group 0), passengers 40..79 are BLUE (group 1)
	ctrl.authoritative_passengers[0]["state"] = "CIRCULATING"
	ctrl.authoritative_passengers[40]["state"] = "CIRCULATING"

	# Try to reserve blue passenger 40 into red bus 3
	var res_blue = ctrl.try_reserve_boarding(40, 3, "blue", 1)
	_assert_test(not res_blue, "Test I1", "Mismatched color boarding rejected (blue -> red bus)")

	# Try to reserve red passenger 0 into red bus 3
	var res_red = ctrl.try_reserve_boarding(0, 3, "red", 0)
	_assert_test(res_red, "Test I2", "Matching color boarding accepted (red -> red bus)")

# -----------------------------------------------------------------
# TEST J: Full capacity automatic departure
# -----------------------------------------------------------------
func _test_j_full_capacity_automatic_departure() -> void:
	print("--- TEST J: Full Capacity Automatic Departure ---")
	var lvl := CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	var v = ctrl.vehicles[3] # Red bus, cap 40
	v.capacity = 2 # Set small capacity for test
	var sid = ctrl.parking.reserve_slot(3)
	ctrl.parking.confirm_arrival(sid, 3)
	v.state = VehicleModel.VehicleState.PARKED

	ctrl.authoritative_passengers[10]["state"] = "CIRCULATING"
	ctrl.authoritative_passengers[11]["state"] = "CIRCULATING"

	var filled_event := [false]
	ctrl.vehicle_filled.connect(func(vid, _s): if vid == 3: filled_event[0] = true)

	ctrl.try_reserve_boarding(10, 3, "red", 0)
	ctrl.commit_boarding(10, 3, "red", ctrl.session_token)
	_assert_test(v.passenger_occupancy == 1 and not filled_event[0], "Test J1", "Half-full bus does not depart")

	ctrl.try_reserve_boarding(11, 3, "red", 0)
	ctrl.commit_boarding(11, 3, "red", ctrl.session_token)
	_assert_test(v.is_full() and filled_event[0], "Test J2", "Bus filled signal emitted at exact capacity")
	_assert_test(ctrl.parking.get_slot(sid).state == CarJamParkingManager.SlotState.DEPARTING, "Test J3", "Parking slot marked DEPARTING")

# -----------------------------------------------------------------
# TEST K: Partial capacity waiting
# -----------------------------------------------------------------
func _test_k_partial_capacity_waiting() -> void:
	print("--- TEST K: Partial Capacity Waiting ---")
	var lvl := CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	var v = ctrl.vehicles[3]
	v.capacity = 4
	var sid = ctrl.parking.reserve_slot(3)
	ctrl.parking.confirm_arrival(sid, 3)
	v.state = VehicleModel.VehicleState.PARKED

	ctrl.authoritative_passengers[1]["state"] = "CIRCULATING"

	ctrl.try_reserve_boarding(1, 3, "red", 0)
	ctrl.commit_boarding(1, 3, "red", ctrl.session_token)

	_assert_test(v.passenger_occupancy == 1 and v.remaining_capacity() == 3, "Test K1", "Partially occupied bus registers exact occupancy")
	_assert_test(v.state == VehicleModel.VehicleState.PARKED, "Test K2", "Bus stays PARKED waiting for future matching passengers")

# -----------------------------------------------------------------
# TEST L: Passenger accounting invariant
# -----------------------------------------------------------------
func _test_l_passenger_conservation_accounting() -> void:
	print("--- TEST L: 100% Passenger Conservation Accounting ---")
	var lvl := CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	var report = ctrl.verify_passenger_conservation()
	_assert_test(report["is_valid"], "Test L1", "Passenger accounting invariant valid on level load")
	_assert_test(report["total_accounted"] == 240, "Test L2", "Exact 240 passengers conserved in Level 1")
	_assert_test(report["duplicate_ids"].is_empty(), "Test L3", "Zero duplicate passenger IDs")

# -----------------------------------------------------------------
# TEST M: Genuine deadlock detection
# -----------------------------------------------------------------
func _test_m_genuine_deadlock_detection() -> void:
	print("--- TEST M: Genuine Deadlock Detection ---")
	var lvl := CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	# Fill parking with docked buses whose colors do not match any passenger
	var unlocked_slots = ctrl.parking.get_unlocked_slot_ids()
	for sid in unlocked_slots:
		var slot = ctrl.parking.get_slot(sid)
		slot.state = CarJamParkingManager.SlotState.OCCUPIED
		slot.vehicle_id = 90 + sid
		var fake_v := VehicleModel.new()
		fake_v.id = 90 + sid
		fake_v.color_id = "purple" # No purple passengers exist in level 1
		fake_v.capacity = 4
		fake_v.passenger_occupancy = 0
		fake_v.state = VehicleModel.VehicleState.PARKED
		ctrl.vehicles[fake_v.id] = fake_v

	# Set all passengers to CIRCULATING
	for pid in ctrl.authoritative_passengers:
		ctrl.authoritative_passengers[pid]["state"] = "CIRCULATING"

	ctrl._check_terminal_states()
	_assert_test(ctrl.state == CarJamController.GameState.FAIL, "Test M1", "Controller strictly detects unrecoverable deadlock")

# -----------------------------------------------------------------
# TEST N: False-deadlock prevention
# -----------------------------------------------------------------
func _test_n_false_deadlock_prevention() -> void:
	print("--- TEST N: False-Deadlock Prevention (Legal Match Available) ---")
	var lvl := CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	# Fill parking, but one bus is RED and can board circulating red passengers
	var unlocked_slots = ctrl.parking.get_unlocked_slot_ids()
	for i in range(unlocked_slots.size()):
		var sid = unlocked_slots[i]
		var slot = ctrl.parking.get_slot(sid)
		slot.state = CarJamParkingManager.SlotState.OCCUPIED
		slot.vehicle_id = 80 + sid
		var fake_v := VehicleModel.new()
		fake_v.id = 80 + sid
		fake_v.color_id = "red" if i == 0 else "purple"
		fake_v.capacity = 4
		fake_v.passenger_occupancy = 0
		fake_v.state = VehicleModel.VehicleState.PARKED
		ctrl.vehicles[fake_v.id] = fake_v

	for pid in ctrl.authoritative_passengers:
		ctrl.authoritative_passengers[pid]["state"] = "CIRCULATING"

	ctrl._check_terminal_states()
	_assert_test(ctrl.state == CarJamController.GameState.PLAYING, "Test N1", "No premature failure when parked bus can board circulating passenger")

# -----------------------------------------------------------------
# TEST O: Full level completion
# -----------------------------------------------------------------
func _test_o_full_level_completion() -> void:
	print("--- TEST O: Full Level Completion (Boarding & Departures) ---")
	var lvl: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	var won := [false]
	ctrl.level_completed.connect(func(): won[0] = true)

	# Dispatch buses in legal order: 3 -> 4 -> 1 -> 2 -> 5 -> 6
	for vid in [3, 4, 1, 2, 5, 6]:
		var ok = ctrl.tap_vehicle(vid)
		_assert_test(ok, "Test O1", "Bus %d dispatched" % vid)
		var sid = ctrl.vehicles[vid].reserved_slot
		ctrl.on_vehicle_arrived_at_slot(vid, sid, ctrl.session_token)

	# Board all passengers into matching parked buses
	for pid in ctrl.authoritative_passengers.keys():
		var p = ctrl.authoritative_passengers[pid]
		p["state"] = "CIRCULATING"
		for vid in [3, 4, 1, 2, 5, 6]:
			var v = ctrl.vehicles[vid]
			if v.color_id == p["color_id"] and v.remaining_capacity() > 0:
				ctrl.try_reserve_boarding(pid, vid, p["color_id"], p["group_id"])
				ctrl.commit_boarding(pid, vid, p["color_id"], ctrl.session_token)
				break

	# Complete all departures
	for vid in [3, 4, 1, 2, 5, 6]:
		var sid = ctrl.parking.get_slot_for_vehicle(vid)
		ctrl.on_vehicle_cleared_slot(vid, sid, ctrl.session_token)
		ctrl.on_vehicle_departed_from_slot(vid, sid, ctrl.session_token)

	_assert_test(won[0] and ctrl.state == CarJamController.GameState.WIN, "Test O2", "Level 1 100% completed with legitimate victory")

# -----------------------------------------------------------------
# TEST P: Booster regressions (VIP, Arrange, Jumble)
# -----------------------------------------------------------------
func _test_p_booster_regressions() -> void:
	print("--- TEST P: Booster Regressions ---")
	var lvl := CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	# 1. VIP booster
	_assert_test(ctrl.is_vip_available(), "Test P1", "VIP booster available initially")
	# Dispatch VIP on blocked bus 1
	var ok_vip = ctrl.try_dispatch_vip(1)
	_assert_test(ok_vip and not ctrl.is_vip_available(), "Test P2", "VIP booster dispatched blocked bus and consumed")
	_assert_test(ctrl.vehicles[1].reserved_slot == 0, "Test P3", "Bus assigned to VIP Slot 0")

	# 2. Intelligent Arrange
	var ctrl2 := CarJamController.new()
	ctrl2.load_level(lvl)
	_assert_test(ctrl2.is_arrange_available(), "Test P4", "Arrange booster available initially")
	var res_arr = ctrl2.try_arrange_intelligent()
	_assert_test(res_arr["ok"] and not ctrl2.is_arrange_available(), "Test P5", "Arrange booster found legal move and consumed")

	# 3. Jumble booster
	var ctrl3 := CarJamController.new()
	ctrl3.load_level(lvl)
	_assert_test(ctrl3.is_jumble_available(), "Test P6", "Jumble booster available initially")
	var ok_jum = ctrl3.try_jumble_buses()
	_assert_test(ok_jum and not ctrl3.is_jumble_available(), "Test P7", "Jumble booster permuted colors and consumed")

# -----------------------------------------------------------------
# TEST Q: Restart and pause determinism (stale token rejection)
# -----------------------------------------------------------------
func _test_q_restart_and_pause_determinism() -> void:
	print("--- TEST Q: Restart and Pause Determinism ---")
	var lvl := CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	var old_token = ctrl.session_token
	ctrl.tap_vehicle(4)
	var sid = ctrl.vehicles[4].reserved_slot

	# Restart level increments session_token
	ctrl.restart_level()
	var new_token = ctrl.session_token
	_assert_test(new_token > old_token, "Test Q1", "restart_level increments session_token")

	# Stale arrival callback from previous session
	ctrl.on_vehicle_arrived_at_slot(4, sid, old_token)
	_assert_test(ctrl.vehicles[4].state == VehicleModel.VehicleState.ON_BOARD, "Test Q2", "Stale arrival callback safely rejected")

# -----------------------------------------------------------------
# TEST R: Solver agreement with runtime gameplay
# -----------------------------------------------------------------
func _test_r_solver_gameplay_agreement() -> void:
	print("--- TEST R: Solver Agreement with Runtime Gameplay ---")
	var lvl: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	var solver_res = CarJamPuzzleSolver.solve(lvl)
	_assert_test(solver_res["solvable"], "Test R1", "Solver successfully solves Level 1 with 144 oval capacity")

	# Check each first-move candidate in solver vs gameplay
	for v in lvl.vehicles:
		var solver_escape: bool = false
		var d = CarJamVehicleData.dir_to_vector(v.direction)
		# Test in authoritative board
		var board_escape: bool = ctrl.board.check_swept_escape(ctrl.vehicles[v.id])["can_escape"]

		var init_sim := CarJamPuzzleSolver.SimVehicle.new()
		init_sim.id = v.id; init_sim.anchor = v.anchor; init_sim.footprint = v.footprint.duplicate()
		init_sim.direction = v.direction; init_sim.state = 0
		var sim_state := CarJamPuzzleSolver.SimState.new()
		sim_state.size = lvl.board_size
		sim_state.grid = ctrl.board.snapshot()
		var sim_esc = sim_state.can_vehicle_escape(init_sim)

		_assert_test(board_escape == sim_esc, "Test R2", "Bus %s: board_escape (%s) == sim_escape (%s)" % [v.code, str(board_escape), str(sim_esc)])

# -----------------------------------------------------------------
# HELPER: Make a simple vehicle
# -----------------------------------------------------------------
func _make_vehicle(id: int, anchor: Vector2i, dir: int, fp: Array[Vector2i]) -> VehicleModel:
	var v := VehicleModel.new()
	v.id = id
	v.code = "v%d" % id
	v.anchor = anchor
	v.initial_anchor = anchor
	v.direction = dir
	v.footprint = fp.duplicate()
	v.state = VehicleModel.VehicleState.ON_BOARD
	v.capacity = 4
	v.color_id = "red"
	return v
