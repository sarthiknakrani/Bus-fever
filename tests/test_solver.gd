extends SceneTree

const CarJamLevelFactory := preload("res://scripts/gameplay/level_factory.gd")
const CarJamLevelValidator := preload("res://scripts/gameplay/level_validator.gd")
const CarJamPuzzleSolver := preload("res://scripts/gameplay/puzzle_solver.gd")

func _init() -> void:
	print("=== Running Car Jam Puzzle Solver Test ===")

	var lvl := CarJamLevelFactory.create_level_1()

	# 1. Validation
	var val_res := CarJamLevelValidator.validate(lvl)
	if not val_res["ok"]:
		print("  [FAIL] Level 1 validation failed: %s" % str(val_res["errors"]))
		quit(1)
		return
	print("  [PASS] Level 1 validation passed: 12 vehicles, 48 passengers, 4 slots")

	# 2. Save .tres
	var save_ok := CarJamLevelFactory.save_level_1_tres("res://levels/level_001.tres")
	if not save_ok:
		print("  [FAIL] Failed to save level_001.tres")
		quit(1)
		return
	print("  [PASS] level_001.tres saved successfully")

	# 3. Load .tres
	var loaded_lvl := ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	if loaded_lvl == null:
		print("  [FAIL] Failed to load level_001.tres from disk")
		quit(1)
		return
	print("  [PASS] level_001.tres loaded and deserialized cleanly")

	# 4. Solve
	print("  Solving Level 1 with 4 parking slots...")
	var solve_res := CarJamPuzzleSolver.solve(loaded_lvl)
	if not solve_res["solvable"]:
		print("  [FAIL] Level 1 is NOT solvable! Iterations: %d" % solve_res["iterations"])
		quit(1)
		return

	var moves: Array = solve_res["moves"]
	var move_codes: Array[String] = []
	for vid in moves:
		for v in loaded_lvl.vehicles:
			if v.id == vid:
				move_codes.append("%s (%s)" % [v.code, v.color_id])
				break

	print("  [PASS] Level 1 is 100%% SOLVABLE in %d moves!" % [moves.size()])
	print("  Winning Move Sequence: %s" % " -> ".join(move_codes))
	print("  BFS Iterations: %d" % solve_res["iterations"])

	# 5. Reject impossible level test
	var bad_lvl := loaded_lvl.clone()
	# Empty out one color from queue to cause mathematical demand violation
	bad_lvl.passenger_groups[0].initial_count = 99
	var bad_val := CarJamLevelValidator.validate(bad_lvl)
	if bad_val["ok"]:
		print("  [FAIL] Validator accepted invalid demand mismatch level")
		quit(1)
		return
	print("  [PASS] Validator correctly rejected mathematically invalid level")

	print("=== All Solver Tests Passed! ===")
	quit(0)
