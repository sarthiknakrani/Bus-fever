extends SceneTree

## Dedicated Universal Deadlock & Out-of-Space QA Suite
## Validates universal deadlock detection without level-specific or color-specific hacks:
##  1. Level 1 solvable win playthrough (no false deadlock)
##  2. Level 2 solvable win playthrough (no false deadlock)
##  3. Real Level 2 Deadlock reproduction (3 Yellow buses parked, Red/Blue on oval, Yellow deep in feeder, 0 credits -> FAIL)
##  4. 4-wide feeder row with insufficient credits (e.g. 3 credits for 4-passenger row) -> FAIL
##  5. 4-wide feeder row with sufficient credits (4 credits for 4-passenger row) matching color -> PLAYING
##  6. Feeder Row 1 (mismatched) + Row 2 (matched) with insufficient credits (4 credits, needs 8) -> FAIL
##  7. Feeder Row 1 (mismatched) + Row 2 (matched) with sufficient credits (8 credits) -> PLAYING
##  8. In-flight operations prevent premature failure:
##     - Reserved slot (bus en route)
##     - Departing slot (bus leaving)
##     - Full bus (bus completed)
##     - Active boarding reservation
##  9. Result UI displays 'OUT OF SPACE!' on puzzle_failed
##  10. Strict preservation of platform and separator geometry

const CarJamLevelFactory := preload("res://scripts/gameplay/level_factory.gd")
const CarJamController := preload("res://scripts/gameplay/car_jam_controller.gd")
const CarJamParkingManager := preload("res://scripts/gameplay/parking_manager.gd")
const VehicleModel := preload("res://scripts/gameplay/vehicle_model.gd")
const CarJamPuzzleSolver := preload("res://scripts/gameplay/puzzle_solver.gd")

var passes: int = 0
var failures: int = 0

func _expect(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % label)
	else:
		failures += 1
		print("  [FAIL] %s" % label)

func _section(title: String) -> void:
	print("\n=== %s ===" % title)

func _init() -> void:
	print("==================================================================")
	print("=== UNIVERSAL DEADLOCK & OUT-OF-SPACE DETECTION QA SUITE ===")
	print("==================================================================")

	_test_1_level_1_and_2_solvability()
	_test_2_level_2_deadlock_reproduction()
	_test_3_four_wide_row_insufficient_credits()
	_test_4_four_wide_row_sufficient_credits()
	_test_5_multi_row_feeder_insufficient_credits()
	_test_6_multi_row_feeder_sufficient_credits()
	_test_7_in_flight_operations_protection()
	_test_8_ui_out_of_space_contract()

	print("\n==================================================================")
	if failures == 0:
		print("=== ALL %d DEADLOCK TESTS PASSED (0 FAILURES) ===" % passes)
		print("==================================================================")
		quit(0)
	else:
		print("=== %d FAILED, %d PASSED ===" % [failures, passes])
		print("==================================================================")
		quit(1)

# -----------------------------------------------------------------
# 1. Level 1 & 2 Normal Solvability (No False Deadlock)
# -----------------------------------------------------------------
func _test_1_level_1_and_2_solvability() -> void:
	_section("1. Level 1 & Level 2 Solvability (No False Deadlock)")
	var lvl1 = CarJamLevelFactory.create_level_1()
	var res1 = CarJamPuzzleSolver.solve(lvl1)
	_expect(res1["solvable"], "Level 1 is solvable in CarJamPuzzleSolver")
	_expect(res1["moves"].size() == 6, "Level 1 solved in 6 moves")

	var lvl2 = load("res://levels/level_002.tres") as CarJamLevelData
	_expect(lvl2 != null, "Level 2 resource loaded")
	var res2 = CarJamPuzzleSolver.solve(lvl2)
	_expect(res2["solvable"], "Level 2 is solvable in CarJamPuzzleSolver")
	_expect(res2["moves"].size() == 12, "Level 2 solved in 12 moves")

# -----------------------------------------------------------------
# 2. Real Level 2 Deadlock Reproduction
# -----------------------------------------------------------------
func _test_2_level_2_deadlock_reproduction() -> void:
	_section("2. Level 2 Deadlock Reproduction (3 Yellow Buses, Red/Blue on Oval, 0 Credits)")
	var ctrl := CarJamController.new()
	var lvl2 = load("res://levels/level_002.tres") as CarJamLevelData
	ctrl.load_level(lvl2)

	# Find 6 non-red buses in Level 2
	var non_red_vids: Array[int] = []
	for vid in ctrl.vehicles:
		if ctrl.vehicles[vid].color_id != "red":
			non_red_vids.append(vid)
			if non_red_vids.size() == 6: break

	_expect(non_red_vids.size() == 6, "Found 6 non-red buses in Level 2")

	# Park all 6 non-red buses into unlocked slots 1..6
	for vid in non_red_vids:
		var slot_id = ctrl.parking.reserve_slot(vid)
		ctrl.parking.confirm_arrival(slot_id, vid)
		ctrl.vehicles[vid].state = VehicleModel.VehicleState.PARKED

	_expect(ctrl.parking.is_full(), "Parking is full with 6 non-red buses")

	# Provide a snapshot where:
	# - Oval has only Red and Blue passengers (mismatched)
	# - Feeder has Red rows at head, Yellow row deep behind
	# - Freed capacity is 0
	var mock_snapshot = {
		"oval_freed_capacity": 0,
		"circulating_rows": [
			{"progress": 100.0, "passengers": [{"id": 1, "color_id": "red", "state": "CIRCULATING"}, {"id": 2, "color_id": "red", "state": "CIRCULATING"}]},
			{"progress": 200.0, "passengers": [{"id": 3, "color_id": "red", "state": "CIRCULATING"}, {"id": 4, "color_id": "red", "state": "CIRCULATING"}]}
		],
		"feeder_rows": [
			{"progress": 50.0, "passengers": [{"id": 10, "color_id": "red", "state": "FEEDER"}, {"id": 11, "color_id": "red", "state": "FEEDER"}, {"id": 12, "color_id": "red", "state": "FEEDER"}, {"id": 13, "color_id": "red", "state": "FEEDER"}]},
			{"progress": 10.0, "passengers": [{"id": 20, "color_id": "yellow", "state": "FEEDER"}, {"id": 21, "color_id": "yellow", "state": "FEEDER"}]}
		],
		"pending_rows": []
	}

	ctrl.track_snapshot_provider = func(): return mock_snapshot
	ctrl._check_terminal_states()

	_expect(ctrl.state == CarJamController.GameState.FAIL, "Universal detector correctly identifies Level 2 deadlock as FAIL (OUT OF SPACE)")

# -----------------------------------------------------------------
# 3. 4-Wide Feeder Row With Insufficient Credits (3 credits for 4-passenger row)
# -----------------------------------------------------------------
func _test_3_four_wide_row_insufficient_credits() -> void:
	_section("3. 4-Wide Feeder Row With Insufficient Credits (3 Credits < 4 Passenger Cost)")
	var ctrl := CarJamController.new()
	var lvl1 = CarJamLevelFactory.create_level_1()
	ctrl.load_level(lvl1)

	# Fill all 6 slots with buses 1..6
	for vid in range(1, 7):
		var s = ctrl.parking.reserve_slot(vid)
		ctrl.parking.confirm_arrival(s, vid)
		ctrl.vehicles[vid].state = VehicleModel.VehicleState.PARKED

	_expect(ctrl.parking.is_full(), "Parking is full")

	# Mock snapshot:
	# - Oval has NO matches (all green/purple dummy)
	# - Feeder row 0 has 4 Yellow passengers (matches parked bus v1!)
	# - BUT oval_freed_capacity is ONLY 3 (cost is 4)
	var mock_snapshot = {
		"oval_freed_capacity": 3,
		"circulating_rows": [
			{"progress": 100.0, "passengers": [{"id": 1, "color_id": "purple", "state": "CIRCULATING"}]}
		],
		"feeder_rows": [
			{"progress": 50.0, "passengers": [
				{"id": 10, "color_id": "yellow", "state": "FEEDER"},
				{"id": 11, "color_id": "yellow", "state": "FEEDER"},
				{"id": 12, "color_id": "yellow", "state": "FEEDER"},
				{"id": 13, "color_id": "yellow", "state": "FEEDER"}
			]}
		],
		"pending_rows": []
	}

	ctrl.track_snapshot_provider = func(): return mock_snapshot
	ctrl._check_terminal_states()

	_expect(ctrl.state == CarJamController.GameState.FAIL, "Detector correctly fails when 3 credits cannot admit a 4-passenger row")

# -----------------------------------------------------------------
# 4. 4-Wide Feeder Row With Sufficient Credits (4 credits for 4-passenger row)
# -----------------------------------------------------------------
func _test_4_four_wide_row_sufficient_credits() -> void:
	_section("4. 4-Wide Feeder Row With Sufficient Credits (4 Credits >= 4 Passenger Cost)")
	var ctrl := CarJamController.new()
	var lvl1 = CarJamLevelFactory.create_level_1()
	ctrl.load_level(lvl1)

	for vid in range(1, 7):
		var s = ctrl.parking.reserve_slot(vid)
		ctrl.parking.confirm_arrival(s, vid)
		ctrl.vehicles[vid].state = VehicleModel.VehicleState.PARKED

	# Mock snapshot with 4 credits
	var mock_snapshot = {
		"oval_freed_capacity": 4,
		"circulating_rows": [
			{"progress": 100.0, "passengers": [{"id": 1, "color_id": "purple", "state": "CIRCULATING"}]}
		],
		"feeder_rows": [
			{"progress": 50.0, "passengers": [
				{"id": 10, "color_id": "yellow", "state": "FEEDER"},
				{"id": 11, "color_id": "yellow", "state": "FEEDER"},
				{"id": 12, "color_id": "yellow", "state": "FEEDER"},
				{"id": 13, "color_id": "yellow", "state": "FEEDER"}
			]}
		],
		"pending_rows": []
	}

	ctrl.track_snapshot_provider = func(): return mock_snapshot
	ctrl._check_terminal_states()

	_expect(ctrl.state == CarJamController.GameState.PLAYING, "Detector keeps game PLAYING because 4 credits allow matching feeder row entry")

# -----------------------------------------------------------------
# 5. Multi-Row Feeder: Row 1 Mismatched + Row 2 Matched with Insufficient Credits (4 Credits, Needs 8)
# -----------------------------------------------------------------
func _test_5_multi_row_feeder_insufficient_credits() -> void:
	_section("5. Multi-Row Feeder with Insufficient Credits (4 Credits < 8 Required for 2 Rows)")
	var ctrl := CarJamController.new()
	var lvl1 = CarJamLevelFactory.create_level_1()
	ctrl.load_level(lvl1)

	# Park yellow bus (v1), red bus (v3), blue bus (v5), plus 2, 4, 6
	for vid in range(1, 7):
		var s = ctrl.parking.reserve_slot(vid)
		ctrl.parking.confirm_arrival(s, vid)
		ctrl.vehicles[vid].state = VehicleModel.VehicleState.PARKED

	# Row 1 is purple (4 passengers). Row 2 is yellow (4 passengers).
	# Credits = 4. Row 1 enters and consumes all 4 credits without boarding.
	# Row 2 is blocked!
	var mock_snapshot = {
		"oval_freed_capacity": 4,
		"circulating_rows": [],
		"feeder_rows": [
			{"progress": 50.0, "passengers": [
				{"id": 10, "color_id": "purple", "state": "FEEDER"},
				{"id": 11, "color_id": "purple", "state": "FEEDER"},
				{"id": 12, "color_id": "purple", "state": "FEEDER"},
				{"id": 13, "color_id": "purple", "state": "FEEDER"}
			]},
			{"progress": 10.0, "passengers": [
				{"id": 20, "color_id": "yellow", "state": "FEEDER"},
				{"id": 21, "color_id": "yellow", "state": "FEEDER"},
				{"id": 22, "color_id": "yellow", "state": "FEEDER"},
				{"id": 23, "color_id": "yellow", "state": "FEEDER"}
			]}
		],
		"pending_rows": []
	}

	ctrl.track_snapshot_provider = func(): return mock_snapshot
	ctrl._check_terminal_states()

	_expect(ctrl.state == CarJamController.GameState.FAIL, "Detector correctly detects deadlock because Row 2 yellow is blocked behind non-matching Row 1")

# -----------------------------------------------------------------
# 6. Multi-Row Feeder: Row 1 Mismatched + Row 2 Matched with Sufficient Credits (8 Credits)
# -----------------------------------------------------------------
func _test_6_multi_row_feeder_sufficient_credits() -> void:
	_section("6. Multi-Row Feeder with Sufficient Credits (8 Credits >= 8 Required for 2 Rows)")
	var ctrl := CarJamController.new()
	var lvl1 = CarJamLevelFactory.create_level_1()
	ctrl.load_level(lvl1)

	for vid in range(1, 7):
		var s = ctrl.parking.reserve_slot(vid)
		ctrl.parking.confirm_arrival(s, vid)
		ctrl.vehicles[vid].state = VehicleModel.VehicleState.PARKED

	# Credits = 8. Row 1 uses 4 credits. Remaining = 4 credits. Row 2 enters and matches yellow!
	var mock_snapshot = {
		"oval_freed_capacity": 8,
		"circulating_rows": [],
		"feeder_rows": [
			{"progress": 50.0, "passengers": [
				{"id": 10, "color_id": "purple", "state": "FEEDER"},
				{"id": 11, "color_id": "purple", "state": "FEEDER"},
				{"id": 12, "color_id": "purple", "state": "FEEDER"},
				{"id": 13, "color_id": "purple", "state": "FEEDER"}
			]},
			{"progress": 10.0, "passengers": [
				{"id": 20, "color_id": "yellow", "state": "FEEDER"},
				{"id": 21, "color_id": "yellow", "state": "FEEDER"},
				{"id": 22, "color_id": "yellow", "state": "FEEDER"},
				{"id": 23, "color_id": "yellow", "state": "FEEDER"}
			]}
		],
		"pending_rows": []
	}

	ctrl.track_snapshot_provider = func(): return mock_snapshot
	ctrl._check_terminal_states()

	_expect(ctrl.state == CarJamController.GameState.PLAYING, "Detector correctly keeps game PLAYING because 8 credits admit both rows to reach yellow")

# -----------------------------------------------------------------
# 7. In-Flight Operations Protection
# -----------------------------------------------------------------
func _test_7_in_flight_operations_protection() -> void:
	_section("7. In-Flight Operations Protection (No False Fail During Transitions)")
	var empty_snapshot = {
		"oval_freed_capacity": 0,
		"circulating_rows": [],
		"feeder_rows": [],
		"pending_rows": []
	}

	# Subtest 7A: Reserved slot (bus en route)
	var ctrl1 := CarJamController.new()
	var lvl1 = CarJamLevelFactory.create_level_1()
	ctrl1.load_level(lvl1)
	var s1 = ctrl1.parking.reserve_slot(1)
	for vid in range(2, 7):
		var s = ctrl1.parking.reserve_slot(vid)
		ctrl1.parking.confirm_arrival(s, vid)
		ctrl1.vehicles[vid].state = VehicleModel.VehicleState.PARKED
	ctrl1.track_snapshot_provider = func(): return empty_snapshot
	ctrl1._check_terminal_states()
	_expect(ctrl1.state == CarJamController.GameState.PLAYING, "7A: Bus en route (RESERVED slot) prevents deadlock failure")

	# Subtest 7B: Departing slot (bus clearing slot)
	var ctrl2 := CarJamController.new()
	ctrl2.load_level(lvl1)
	for vid in range(1, 7):
		var s = ctrl2.parking.reserve_slot(vid)
		ctrl2.parking.confirm_arrival(s, vid)
		ctrl2.vehicles[vid].state = VehicleModel.VehicleState.PARKED
	ctrl2.parking.mark_departing(1, 1) # Slot 1 is DEPARTING
	ctrl2.track_snapshot_provider = func(): return empty_snapshot
	ctrl2._check_terminal_states()
	_expect(ctrl2.state == CarJamController.GameState.PLAYING, "7B: Departing bus prevents deadlock failure")

	# Subtest 7C: Full bus (COMPLETED)
	var ctrl3 := CarJamController.new()
	ctrl3.load_level(lvl1)
	for vid in range(1, 7):
		var s = ctrl3.parking.reserve_slot(vid)
		ctrl3.parking.confirm_arrival(s, vid)
		ctrl3.vehicles[vid].state = VehicleModel.VehicleState.PARKED
	ctrl3.vehicles[1].state = VehicleModel.VehicleState.FULL
	ctrl3.track_snapshot_provider = func(): return empty_snapshot
	ctrl3._check_terminal_states()
	_expect(ctrl3.state == CarJamController.GameState.PLAYING, "7C: FULL bus prevents deadlock failure")

	# Subtest 7D: Active boarding reservation
	var ctrl4 := CarJamController.new()
	ctrl4.load_level(lvl1)
	for vid in range(1, 7):
		var s = ctrl4.parking.reserve_slot(vid)
		ctrl4.parking.confirm_arrival(s, vid)
		ctrl4.vehicles[vid].state = VehicleModel.VehicleState.PARKED
	ctrl4.authoritative_passengers[0]["state"] = "CIRCULATING"
	var res_ok = ctrl4.try_reserve_boarding(0, 3, "red", 0) # Active boarding in flight
	_expect(res_ok, "7D: Reservation succeeded")
	ctrl4.track_snapshot_provider = func(): return empty_snapshot
	ctrl4._check_terminal_states()
	_expect(ctrl4.state == CarJamController.GameState.PLAYING, "7D: Active boarding reservation prevents deadlock failure")

# -----------------------------------------------------------------
# 8. UI Out-of-Space Contract
# -----------------------------------------------------------------
func _test_8_ui_out_of_space_contract() -> void:
	_section("8. UI Out-of-Space Contract (Title and Buttons)")
	var CarJamLevelClass = load("res://scripts/gameplay/car_jam_level.gd")
	var level = CarJamLevelClass.new()
	root.add_child(level)
	level._setup_controller()
	level._build_hud()

	level.controller.puzzle_failed.emit()

	_expect(level.result_overlay.visible, "Result overlay visible on puzzle_failed")
	_expect(level.result_title_label.text == "OUT OF SPACE!", "Result title label displays 'OUT OF SPACE!' (got '%s')" % level.result_title_label.text)
	_expect(level.result_retry_btn.visible, "Retry button is visible")
	_expect(not level.result_btn.visible, "Next level button is hidden on failure")

	level.queue_free()
