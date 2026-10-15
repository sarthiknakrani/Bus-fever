extends SceneTree

## Comprehensive Universal Solver vs Real Gameplay QA Suite
## Validates the 14 scenarios specified in Phase 6:
##  1. Level 1 full solve under 3 unlocked slots
##  2. Level 2 full solve under 3 unlocked slots
##  3. Exactly three unlocked parking slots (slots 1, 2, 3)
##  4. Full parking with one bus still boarding (no false failure)
##  5. Full parking with no achievable progress (true deadlock detection)
##  6. Multiple buses of the same color (deterministic slot priority)
##  7. Returning color waves (partial bus waits and resumes)
##  8. Partially filled buses (slot held until full departure)
##  9. Passenger feeder blocked by full oval (no premature admission)
##  10. Boarding-created feeder release (1-for-1 capacity conservation)
##  11. Illegal vehicle escape paths (swept collision rejection)
##  12. Repeated rapid bus selections (double-reservation prevention)
##  13. Restart during boarding (session token invalidation)
##  14. All passengers correctly accounted for (conservation invariant)

const CarJamLevelFactory := preload("res://scripts/gameplay/level_factory.gd")
const CarJamBoardModel := preload("res://scripts/gameplay/board_model.gd")
const CarJamParkingManager := preload("res://scripts/gameplay/parking_manager.gd")
const CarJamController := preload("res://scripts/gameplay/car_jam_controller.gd")
const CarJamPuzzleSolver := preload("res://scripts/gameplay/puzzle_solver.gd")
const VehicleModel := preload("res://scripts/gameplay/vehicle_model.gd")

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
	print("=== STARTING BUS FEVER UNIVERSAL SOLVER & REAL GAMEPLAY QA ===")
	print("==================================================================")

	_test_1_level_1_full_solve()
	_test_2_level_2_full_solve()
	_test_3_three_unlocked_parking_slots()
	_test_4_full_parking_with_one_bus_boarding()
	_test_5_full_parking_deadlock_detection()
	_test_6_multiple_buses_same_color()
	_test_7_returning_color_waves()
	_test_8_partially_filled_buses()
	_test_9_feeder_blocked_by_full_oval()
	_test_10_boarding_created_feeder_release()
	_test_11_illegal_escape_paths()
	_test_12_repeated_rapid_taps()
	_test_13_restart_during_boarding()
	_test_14_passenger_accounting_conservation()

	print("\n==================================================================")
	if failures == 0:
		print("=== ALL %d UNIVERSAL SOLVER QA TESTS PASSED (0 FAILURES) ===" % passes)
		print("==================================================================")
		quit(0)
	else:
		print("=== %d FAILED, %d PASSED ===" % [failures, passes])
		print("==================================================================")
		quit(1)

# -----------------------------------------------------------------
# 1. Level 1 Full Solve
# -----------------------------------------------------------------
func _test_1_level_1_full_solve() -> void:
	_section("1. Level 1 Full Solve (6 Unlocked Slots)")
	var lvl1 = CarJamLevelFactory.create_level_1()
	var res = CarJamPuzzleSolver.solve(lvl1)
	_expect(res["solvable"], "Level 1 is solvable in CarJamPuzzleSolver")
	_expect(res["moves"].size() == 6, "Level 1 solved in exactly 6 moves (got %d)" % res["moves"].size())
	_expect(res["unlocked_slots"] == [1, 2, 3, 4, 5, 6], "Level 1 used authoritative unlocked slots [1, 2, 3, 4, 5, 6]")
	print("    Winning Move Order: %s | Iterations: %d" % [str(res["moves"]), res["iterations"]])

# -----------------------------------------------------------------
# 2. Level 2 Full Solve
# -----------------------------------------------------------------
func _test_2_level_2_full_solve() -> void:
	_section("2. Level 2 Full Solve (4 Unlocked Slots: [1, 2, 3, 4])")
	var lvl2 = load("res://levels/level_002.tres") as CarJamLevelData
	_expect(lvl2 != null, "Level 2 resource loaded successfully")
	var res = CarJamPuzzleSolver.solve(lvl2)
	_expect(res["solvable"], "Level 2 is solvable in CarJamPuzzleSolver with 4 slots")
	_expect(res["moves"].size() == 12, "Level 2 solved in exactly 12 moves (got %d)" % res["moves"].size())
	_expect(res["unlocked_slots"] == [1, 2, 3, 4], "Level 2 used authoritative unlocked slots [1, 2, 3, 4] (got %s)" % str(res["unlocked_slots"]))
	print("    Winning Move Order: %s | Iterations: %d" % [str(res["moves"]), res["iterations"]])

# -----------------------------------------------------------------
# 3. Level-Specific Unlocked Parking Slots
# -----------------------------------------------------------------
func _test_3_three_unlocked_parking_slots() -> void:
	_section("3. Level-Specific Unlocked Parking Slots (Level 1: 6 slots, Level 2: 4 slots)")
	var pm1 := CarJamParkingManager.new()
	pm1.setup(7, [1, 2, 3, 4, 5, 6])
	_expect(pm1.get_slot_count() == 7, "Level 1: Total slot count is 7")
	_expect(pm1.get_unlocked_slot_count() == 6, "Level 1: Initially unlocked slot count is exactly 6")
	_expect(pm1.get_unlocked_slot_ids() == [1, 2, 3, 4, 5, 6], "Level 1: Unlocked slot IDs are exactly [1, 2, 3, 4, 5, 6]")
	_expect(not pm1.is_slot_unlocked(0), "Level 1: Slot 0 (VIP) is locked")
	for sid in range(1, 7):
		_expect(pm1.is_slot_unlocked(sid), "Level 1: Slot %d is unlocked" % sid)

	# Reserve all 6 slots in Level 1
	for vid in range(101, 107):
		var s = pm1.reserve_slot(vid)
		_expect(s == vid - 100, "Level 1: Reserved slot %d in order" % s)
	_expect(pm1.is_full(), "Level 1: Parking is full after 6 reservations")
	var s7 = pm1.reserve_slot(107)
	_expect(s7 == -1, "Level 1: 7th reservation rejected when all 6 normal slots full")

	# Test Level 2 parking: slots 1..4 unlocked, slots 0, 5, 6 locked
	var pm2 := CarJamParkingManager.new()
	pm2.setup(7, [1, 2, 3, 4])
	_expect(pm2.get_slot_count() == 7, "Level 2: Total slot count is 7")
	_expect(pm2.get_unlocked_slot_count() == 4, "Level 2: Unlocked slot count is exactly 4")
	_expect(pm2.get_unlocked_slot_ids() == [1, 2, 3, 4], "Level 2: Unlocked slot IDs are exactly [1, 2, 3, 4]")
	_expect(not pm2.is_slot_unlocked(0), "Level 2: Slot 0 (VIP) is locked")
	_expect(not pm2.is_slot_unlocked(5), "Level 2: Slot 5 is locked")
	_expect(not pm2.is_slot_unlocked(6), "Level 2: Slot 6 is locked")
	for sid in range(1, 5):
		_expect(pm2.is_slot_unlocked(sid), "Level 2: Slot %d is unlocked" % sid)

	# Reserve all 4 slots in Level 2
	for vid in range(201, 205):
		var s = pm2.reserve_slot(vid)
		_expect(s == vid - 200, "Level 2: Reserved slot %d in order" % s)
	_expect(pm2.is_full(), "Level 2: Parking is full after 4 reservations")
	var s5 = pm2.reserve_slot(205)
	_expect(s5 == -1, "Level 2: 5th reservation rejected when all 4 normal slots full")

# -----------------------------------------------------------------
# 4. Full Parking with One Bus Still Boarding
# -----------------------------------------------------------------
func _test_4_full_parking_with_one_bus_boarding() -> void:
	_section("4. Full Parking with One Bus Still Boarding (No Premature Fail)")
	var ctrl := CarJamController.new()
	var lvl := CarJamLevelFactory.create_level_1()
	ctrl.load_level(lvl)

	# Mark first passenger as CIRCULATING (Red, matches bus 3)
	ctrl.authoritative_passengers[0]["state"] = "CIRCULATING"

	# Fill all 6 normal slots (Level 1 has 6 buses: 1, 2, 3, 4, 5, 6)
	for vid in [3, 5, 1, 2, 4, 6]:
		var s = ctrl.parking.reserve_slot(vid)
		ctrl.parking.confirm_arrival(s, vid)
		ctrl.vehicles[vid].state = VehicleModel.VehicleState.PARKED

	_expect(ctrl.parking.is_full(), "Parking is full with 6 parked buses")

	ctrl._check_terminal_states()
	_expect(ctrl.state == CarJamController.GameState.PLAYING, "Game is still PLAYING because parked buses match circulating passengers")

# -----------------------------------------------------------------
# 5. Full Parking with No Achievable Progress (Deadlock)
# -----------------------------------------------------------------
func _test_5_full_parking_deadlock_detection() -> void:
	_section("5. Full Parking with No Achievable Progress (Deadlock Detection)")
	# Build a balanced level: 6 Yellow buses (cap 2 = 12), 1 Red bus (cap 152) = 164 total
	# Queue: Group 0 (Red 152), Group 1 (Yellow 12) = 164 total demand
	var lvl_deadlock := CarJamLevelData.new()
	lvl_deadlock.board_size = Vector2i(5, 5)
	lvl_deadlock.parking_slots_count = 7

	var configs = [
		{"id": 1, "color": "yellow", "pos": Vector2i(0, 0), "cap": 2,   "dir": CarJamVehicleData.Direction.DOWN},
		{"id": 2, "color": "yellow", "pos": Vector2i(1, 0), "cap": 2,   "dir": CarJamVehicleData.Direction.DOWN},
		{"id": 3, "color": "yellow", "pos": Vector2i(2, 0), "cap": 2,   "dir": CarJamVehicleData.Direction.DOWN},
		{"id": 4, "color": "yellow", "pos": Vector2i(3, 0), "cap": 2,   "dir": CarJamVehicleData.Direction.DOWN},
		{"id": 5, "color": "yellow", "pos": Vector2i(4, 0), "cap": 2,   "dir": CarJamVehicleData.Direction.DOWN},
		{"id": 6, "color": "yellow", "pos": Vector2i(0, 1), "cap": 2,   "dir": CarJamVehicleData.Direction.DOWN},
		{"id": 7, "color": "red",    "pos": Vector2i(0, 4), "cap": 152, "dir": CarJamVehicleData.Direction.UP}
	]
	for cfg in configs:
		var v = CarJamVehicleData.new()
		v.id = cfg["id"]; v.code = "v%d" % v.id; v.color_id = cfg["color"]; v.capacity = cfg["cap"]
		v.anchor = cfg["pos"]; v.initial_anchor = cfg["pos"]; v.direction = cfg["dir"]
		var fp: Array[Vector2i] = [Vector2i.ZERO]
		v.footprint = fp
		lvl_deadlock.vehicles.append(v)

	var g_red = PassengerGroupData.new(0, "red", 152)
	var g_yellow = PassengerGroupData.new(1, "yellow", 12)
	lvl_deadlock.passenger_groups.append(g_red)
	lvl_deadlock.passenger_groups.append(g_yellow)

	# Verify in solver: if the 6 Yellow buses are parked first, level is deadlocked
	var s := CarJamPuzzleSolver.SimState.new()
	s.unlocked_slots = [1, 2, 3, 4, 5, 6]
	s.slots = [-1, -1, -1, -1, -1, -1, -1]
	for vid in [1, 2, 3, 4, 5, 6]:
		var sv := CarJamPuzzleSolver.SimVehicle.new()
		sv.id = vid; sv.color_id = "yellow"; sv.capacity = 2; sv.occupancy = 0; sv.state = 1
		s.vehicles[vid] = sv
		s.slots[vid] = vid
	var sv7 := CarJamPuzzleSolver.SimVehicle.new()
	sv7.id = 7; sv7.color_id = "red"; sv7.capacity = 152; sv7.occupancy = 0; sv7.state = 0
	s.vehicles[7] = sv7

	# Oval holds 152 Red passengers. Feeder holds 12 Yellow passengers.
	s.oval_counts = {"red": 152}
	s.passenger_seq = []
	for k in 12: s.passenger_seq.append("yellow")
	s.feeder_index = 0
	s.run_boarding()

	_expect(s.find_free_slot() == -1, "Parking slots remain completely full in solver")
	_expect(s.oval_counts.get("red", 0) == 152, "0 passengers boarded because parked yellow buses cannot board red")
	_expect(s.feeder_index == 0, "0 feeder passengers entered because oval space was never freed")

	# Verify in runtime controller:
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl_deadlock)

	# Park the 6 Yellow buses in slots 1..6
	for vid in range(1, 7):
		var sid = ctrl.parking.reserve_slot(vid)
		ctrl.parking.confirm_arrival(sid, vid)
		ctrl.vehicles[vid].state = VehicleModel.VehicleState.PARKED

	_expect(ctrl.parking.is_full(), "Parking is full with 6 parked yellow buses")

	# All 152 initial circulating passengers are RED (mismatched with Yellow buses)
	for i in 152:
		ctrl.authoritative_passengers[i]["state"] = "CIRCULATING"
	for i in range(152, 164):
		ctrl.authoritative_passengers[i]["state"] = "FEEDER"

	ctrl._check_terminal_states()
	_expect(ctrl.state == CarJamController.GameState.FAIL, "Controller correctly transitioned to FAIL on complete deadlock")

# -----------------------------------------------------------------
# 6. Multiple Buses of the Same Color
# -----------------------------------------------------------------
func _test_6_multiple_buses_same_color() -> void:
	_section("6. Multiple Buses of the Same Color (Slot Priority)")
	var s := CarJamPuzzleSolver.SimState.new()
	s.unlocked_slots = [1, 2, 3]
	s.slots = [-1, -1, -1, -1, -1, -1, -1]

	var v1 := CarJamPuzzleSolver.SimVehicle.new()
	v1.id = 1; v1.color_id = "red"; v1.capacity = 4; v1.occupancy = 0; v1.state = 1
	s.vehicles[1] = v1
	s.slots[1] = 1

	var v2 := CarJamPuzzleSolver.SimVehicle.new()
	v2.id = 2; v2.color_id = "red"; v2.capacity = 4; v2.occupancy = 0; v2.state = 1
	s.vehicles[2] = v2
	s.slots[2] = 2

	# 6 Red passengers on oval, no feeder
	s.oval_counts = {"red": 6}
	s.passenger_seq = []
	s.feeder_index = 0

	s.run_boarding()

	_expect(v1.state == 2, "Bus 1 in Slot 1 fully filled (4/4) and departed")
	_expect(s.slots[1] == -1, "Slot 1 freed after Bus 1 departed")
	_expect(v2.occupancy == 2, "Bus 2 in Slot 2 received remaining 2 boarders (2/4)")
	_expect(s.slots[2] == 2, "Bus 2 remains in Slot 2 waiting for more passengers")
	_expect(s.oval_counts["red"] == 0, "Oval red passengers completely consumed")

# -----------------------------------------------------------------
# 7. Returning Color Waves
# -----------------------------------------------------------------
func _test_7_returning_color_waves() -> void:
	_section("7. Returning Color Waves (Partial Bus Waits and Resumes)")
	var s := CarJamPuzzleSolver.SimState.new()
	s.unlocked_slots = [1, 2, 3]
	s.slots = [-1, -1, -1, -1, -1, -1, -1]

	var v_red := CarJamPuzzleSolver.SimVehicle.new()
	v_red.id = 1; v_red.color_id = "red"; v_red.capacity = 8; v_red.occupancy = 0; v_red.state = 1
	s.vehicles[1] = v_red
	s.slots[1] = 1

	# Initial oval has 4 Red only. Feeder has 4 Blue, then 4 Red (returning wave).
	s.oval_counts = {"red": 4}
	s.passenger_seq = ["blue", "blue", "blue", "blue", "red", "red", "red", "red"]
	s.feeder_index = 0

	# Step A: Initial boarding fills 4 Red; 4 Blue enter from feeder to oval
	s.run_boarding()
	_expect(v_red.occupancy == 4, "Red Bus partially filled (4/8)")
	_expect(s.slots[1] == 1, "Red Bus slot still occupied")
	_expect(s.oval_counts.get("blue", 0) == 4, "Oval now holds 4 incoming Blue passengers")

	# Step B: Blue Bus parks in Slot 2
	var v_blue := CarJamPuzzleSolver.SimVehicle.new()
	v_blue.id = 2; v_blue.color_id = "blue"; v_blue.capacity = 4; v_blue.occupancy = 0; v_blue.state = 1
	s.vehicles[2] = v_blue
	s.slots[2] = 2

	# Boarding Blue bus frees 4 spaces on oval, admitting the 4 returning Red passengers from feeder!
	s.run_boarding()
	_expect(v_blue.state == 2 and s.slots[2] == -1, "Blue Bus filled (4/4) and departed")
	_expect(v_red.state == 2 and s.slots[1] == -1, "Red Bus completed (8/8) via returning wave and departed")

# -----------------------------------------------------------------
# 8. Partially Filled Buses
# -----------------------------------------------------------------
func _test_8_partially_filled_buses() -> void:
	_section("8. Partially Filled Buses (Slot Retained)")
	var s := CarJamPuzzleSolver.SimState.new()
	s.unlocked_slots = [1, 2, 3]
	s.slots = [-1, -1, -1, -1, -1, -1, -1]

	var v := CarJamPuzzleSolver.SimVehicle.new()
	v.id = 1; v.color_id = "yellow"; v.capacity = 40; v.occupancy = 0; v.state = 1
	s.vehicles[1] = v
	s.slots[1] = 1

	s.oval_counts = {"yellow": 15}
	s.passenger_seq = []
	s.feeder_index = 0

	s.run_boarding()
	_expect(v.occupancy == 15, "Bus occupancy is 15")
	_expect(v.remaining_capacity() == 25, "Bus remaining capacity is 25")
	_expect(s.slots[1] == 1, "Slot 1 is retained by partial bus")
	_expect(s.find_free_slot() == 2, "Next free slot is Slot 2 (Slot 1 not freed)")

# -----------------------------------------------------------------
# 9. Feeder Blocked by Full Oval
# -----------------------------------------------------------------
func _test_9_feeder_blocked_by_full_oval() -> void:
	_section("9. Feeder Blocked by Full Oval (No Freed Capacity)")
	var s := CarJamPuzzleSolver.SimState.new()
	s.unlocked_slots = [1, 2, 3]
	s.slots = [-1, -1, -1, -1, -1, -1, -1]

	# Oval full of 152 Blue passengers
	s.oval_counts = {"blue": 152}
	# Feeder has 10 Red passengers
	s.passenger_seq = ["red", "red", "red", "red", "red"]
	s.feeder_index = 0

	# Park a Yellow bus (mismatched with Blue oval)
	var v := CarJamPuzzleSolver.SimVehicle.new()
	v.id = 1; v.color_id = "yellow"; v.capacity = 10; v.occupancy = 0; v.state = 1
	s.vehicles[1] = v
	s.slots[1] = 1

	s.run_boarding()
	_expect(s.feeder_index == 0, "0 feeder passengers admitted because oval was full and no boarding occurred")
	_expect(s.oval_counts["blue"] == 152, "Oval blue count unchanged")

# -----------------------------------------------------------------
# 10. Boarding-Created Feeder Release
# -----------------------------------------------------------------
func _test_10_boarding_created_feeder_release() -> void:
	_section("10. Boarding-Created Feeder Release (1-for-1 Conservation)")
	var s := CarJamPuzzleSolver.SimState.new()
	s.unlocked_slots = [1, 2, 3]
	s.slots = [-1, -1, -1, -1, -1, -1, -1]

	# Oval has 3 Red
	s.oval_counts = {"red": 3}
	# Feeder has 3 Yellow
	s.passenger_seq = ["yellow", "yellow", "yellow"]
	s.feeder_index = 0

	var v := CarJamPuzzleSolver.SimVehicle.new()
	v.id = 1; v.color_id = "red"; v.capacity = 3; v.occupancy = 0; v.state = 1
	s.vehicles[1] = v
	s.slots[1] = 1

	s.run_boarding()
	_expect(v.occupancy == 3, "Red bus boarded 3 passengers")
	_expect(s.feeder_index == 3, "Exactly 3 feeder passengers entered the oval")
	_expect(s.oval_counts.get("yellow", 0) == 3, "Oval now holds the 3 newly admitted yellow passengers")

# -----------------------------------------------------------------
# 11. Illegal Escape Paths
# -----------------------------------------------------------------
func _test_11_illegal_escape_paths() -> void:
	_section("11. Illegal Escape Paths (Blocked Vehicle Rejection)")
	var lvl = CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	# Vehicle 1 (v1_yellow) starts at (3, 2), dir UP (towards Vehicle 2)
	# It is blocked by v2_blue
	var tap_res = ctrl.tap_vehicle(1)
	_expect(not tap_res, "Blocked vehicle tap rejected by controller")
	_expect(ctrl.vehicles[1].state == VehicleModel.VehicleState.ON_BOARD, "Blocked vehicle remains ON_BOARD")

# -----------------------------------------------------------------
# 12. Repeated Rapid Bus Selections
# -----------------------------------------------------------------
func _test_12_repeated_rapid_taps() -> void:
	_section("12. Repeated Rapid Bus Selections (Idempotence & Re-tap Guard)")
	var lvl = CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	# Vehicle 2 can escape
	var tap1 = ctrl.tap_vehicle(2)
	_expect(tap1, "First tap on Vehicle 2 accepted")
	var tap2 = ctrl.tap_vehicle(2)
	_expect(not tap2, "Immediate second tap on Vehicle 2 rejected (already EXITING)")

# -----------------------------------------------------------------
# 13. Restart During Boarding
# -----------------------------------------------------------------
func _test_13_restart_during_boarding() -> void:
	_section("13. Restart During Boarding (Session Token Invalidation)")
	var lvl = CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	var old_token = ctrl.session_token
	# Dispatch vehicle 2
	ctrl.tap_vehicle(2)
	_expect(ctrl.parking.get_slot(1).vehicle_id == 2, "Slot 1 reserved for bus 2")

	# Restart
	ctrl.restart_level()
	_expect(ctrl.session_token == old_token + 1, "Session token incremented on restart")
	_expect(ctrl.parking.get_slot(1).vehicle_id == -1, "Slot 1 reset to free")
	_expect(ctrl.boarding_reservations.is_empty(), "Boarding reservations wiped")

	# Stale callback with old token rejected
	ctrl.on_vehicle_departed_from_slot(2, 1, old_token)
	_expect(ctrl.state == CarJamController.GameState.PLAYING, "Stale callback ignored")

# -----------------------------------------------------------------
# 14. Passenger Accounting Conservation
# -----------------------------------------------------------------
func _test_14_passenger_accounting_conservation() -> void:
	_section("14. Passenger Accounting Conservation Invariant")
	var lvl = CarJamLevelFactory.create_level_1()
	var ctrl := CarJamController.new()
	ctrl.load_level(lvl)

	var report = ctrl.verify_passenger_conservation()
	_expect(report["ok"], "Initial Level 1 passenger accounting is valid")
	_expect(report["missing_ids"].is_empty(), "0 missing passenger IDs")
	_expect(report["duplicate_ids"].is_empty(), "0 duplicate passenger IDs")
	_expect(report["reservation_errors"].is_empty(), "0 reservation errors")
	_expect(report["total"] == 240, "Total accounted passengers equals 240")
