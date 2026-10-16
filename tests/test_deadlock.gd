extends SceneTree

const LevelControllerScript := preload("res://scripts/core/level_controller.gd")
const LevelDataScript := preload("res://scripts/core/level_data.gd")
const VehicleDataScript := preload("res://scripts/core/vehicle_data.gd")
const HintSolverScript := preload("res://scripts/core/hint_solver.gd")

var _passes := 0
var _failures := 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("  [PASS] %s" % msg)
	else:
		_failures += 1
		print("  [FAIL] %s" % msg)

func _init() -> void:
	print("\n=== STARTING QA AUDIT: DEADLOCK DETECTION TEST ===")
	_test_deadlock_condition()
	_test_hint_solver_is_dead_end()
	print("\n=== DEADLOCK AUDIT COMPLETE: %d PASSED, %d FAILED ===" % [_passes, _failures])
	if _failures > 0:
		quit(1)
	else:
		quit(0)

func _test_deadlock_condition() -> void:
	print("\n--- Test 1: LevelController Deadlock Detection ---")
	var lvl := LevelDataScript.new()
	lvl.id = "test_deadlock"
	lvl.display_name = "Test Deadlock"
	lvl.board_size = Vector2i(3, 3)
	lvl.standard_bay_count = 1
	lvl.cell_size = 96.0

	# 2 vehicles on a 3x3 board:
	# A: blue at (1, 2) facing NORTH (blocked by B at 1, 1)
	# B: red at (1, 1) facing NORTH (free to exit board through 1, 0)
	lvl.vehicles = [
		{"id": "A", "color": "blue", "capacity": 4, "position": Vector2i(1, 2), "initial_position": Vector2i(1, 2), "direction": VehicleDataScript.Direction.NORTH},
		{"id": "B", "color": "red",  "capacity": 4, "position": Vector2i(1, 1), "initial_position": Vector2i(1, 1), "direction": VehicleDataScript.Direction.NORTH},
	]
	# Passenger queue demands BLUE first, but only RED can exit to the single bay!
	lvl.passenger_order = ["blue", "blue", "blue", "blue", "red", "red", "red", "red"]

	var ctrl := LevelControllerScript.new()
	ctrl.load_level(lvl)
	_assert(ctrl.game_state == LevelControllerScript.GameState.PLAYING, "Starts in PLAYING state")

	# Tap B (index 1) so it moves to bay 0
	var tapped := ctrl.tap_vehicle(1)
	_assert(tapped, "B tapped and moves towards bay 0")

	# Confirm B arrived at bay 0
	ctrl._on_arrived_at_bay(1, 0)

	# Bay 0 is full with red bus, active demand is blue, and remaining bus A cannot move into any bay
	_assert(ctrl.game_state == LevelControllerScript.GameState.FAIL, "Game detected deadlock and transitioned to FAIL")
	_assert(ctrl.is_interaction_locked(), "Interaction is locked in FAIL state")

func _test_hint_solver_is_dead_end() -> void:
	print("\n--- Test 2: HintSolver is_dead_end BFS verification ---")
	var lvl := LevelDataScript.new()
	lvl.id = "test_solver_deadlock"
	lvl.board_size = Vector2i(3, 3)
	lvl.standard_bay_count = 1
	lvl.vehicles = [
		{"id": "A", "color": "blue", "capacity": 4, "position": Vector2i(1, 2), "initial_position": Vector2i(1, 2), "direction": VehicleDataScript.Direction.NORTH},
		{"id": "B", "color": "red",  "capacity": 4, "position": Vector2i(1, 1), "initial_position": Vector2i(1, 1), "direction": VehicleDataScript.Direction.NORTH},
	]
	lvl.passenger_order = ["blue", "blue", "blue", "blue", "red", "red", "red", "red"]

	var solver := HintSolverScript.new()
	var state := solver.build_initial_state(lvl, false)

	# Move B to bay 0
	var vb: HintSolver.SimVehicle = state.vehicles["B"]
	var nst := solver.apply_move(state, vb, 0)
	_assert(nst != null, "Move B applied to sim state")

	var is_dead := solver.is_dead_end(nst, 500)
	_assert(is_dead, "HintSolver.is_dead_end returns true on dead-end state")
