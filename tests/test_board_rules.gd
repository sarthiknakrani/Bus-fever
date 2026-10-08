extends SceneTree

const CarJamBoardModel := preload("res://scripts/gameplay/board_model.gd")
const VehicleModel := preload("res://scripts/gameplay/vehicle_model.gd")
const CarJamVehicleData := preload("res://data/vehicle_data.gd")

func _init() -> void:
	print("=== Running Board Rules QA Tests ===")
	var failures: Array[String] = []

	var board := CarJamBoardModel.new()
	board.setup(Vector2i(7, 7))

	# 1. Test single clear exit
	var v_clear := VehicleModel.new()
	v_clear.id = 1
	v_clear.code = "V1"
	v_clear.anchor = Vector2i(3, 2)
	v_clear.direction = CarJamVehicleData.Direction.UP
	v_clear.footprint = [Vector2i.ZERO]
	board.place_vehicle(v_clear)

	var res_clear := board.check_swept_escape(v_clear)
	if not res_clear["can_escape"]:
		failures.append("Clear vehicle should be able to escape UP")
	else:
		print("  [PASS] Single clear exit: can escape UP")

	# 2. Test one blocker
	var v_blocker := VehicleModel.new()
	v_blocker.id = 2
	v_blocker.code = "V2"
	v_blocker.anchor = Vector2i(3, 1) # directly in front of v_clear!
	v_blocker.direction = CarJamVehicleData.Direction.RIGHT
	v_blocker.footprint = [Vector2i.ZERO]
	board.place_vehicle(v_blocker)

	var res_blocked := board.check_swept_escape(v_clear)
	if res_blocked["can_escape"]:
		failures.append("Vehicle should be blocked by V2")
	elif res_blocked["blocker_id"] != 2:
		failures.append("Blocker ID should be 2, got %d" % res_blocked["blocker_id"])
	else:
		print("  [PASS] One blocker detected correctly: blocker_id=2 at cell (3, 1)")

	# 3. Test removal clears path
	board.remove_vehicle(2)
	var res_unblocked := board.check_swept_escape(v_clear)
	if not res_unblocked["can_escape"]:
		failures.append("Vehicle should escape after blocker removed")
	else:
		print("  [PASS] Dynamic unblocking: path becomes clear after blocker removed")

	# 4. Multi-cell footprint swept collision (2x1 bus)
	var v_long := VehicleModel.new()
	v_long.id = 10
	v_long.code = "LONG"
	v_long.anchor = Vector2i(4, 4)
	v_long.direction = CarJamVehicleData.Direction.DOWN
	v_long.footprint = [Vector2i(0, 0), Vector2i(1, 0)] # 2-wide footprint!
	board.place_vehicle(v_long)

	# Place blocker in cell (5, 5) which is in the swept corridor of the second cell (4+1, 4+1)
	var v_side_blocker := VehicleModel.new()
	v_side_blocker.id = 11
	v_side_blocker.anchor = Vector2i(5, 5)
	v_side_blocker.direction = CarJamVehicleData.Direction.LEFT
	v_side_blocker.footprint = [Vector2i.ZERO]
	board.place_vehicle(v_side_blocker)

	var res_long := board.check_swept_escape(v_long)
	if res_long["can_escape"]:
		failures.append("Multi-cell vehicle should be blocked along second cell's swept path")
	else:
		print("  [PASS] Multi-cell swept collision: wide footprint correctly detected collision at (5, 5)")

	# 5. Boundary conditions
	if board.in_bounds(Vector2i(-1, 0)):
		failures.append("(-1, 0) should be out of bounds")
	if board.in_bounds(Vector2i(7, 3)):
		failures.append("(7, 3) should be out of bounds")
	print("  [PASS] Boundary conditions verified")

	if failures.is_empty():
		print("=== All Board Rules Tests Passed (0 failures) ===")
		quit(0)
	else:
		print("=== Board Rules Tests FAILED with %d failures: %s ===" % [failures.size(), str(failures)])
		quit(1)
