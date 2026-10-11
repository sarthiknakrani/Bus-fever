extends SceneTree

var CarJamLevelValidator = load("res://scripts/gameplay/level_validator.gd")
var SolvabilityValidator = load("res://scripts/universal/solvability_validator.gd")
var PassengerDemand = load("res://scripts/universal/passenger_demand.gd")
var LevelIntegration = load("res://scripts/universal/level_integration.gd")

func _init() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	print("==========================================")
	print("=== AUTOMATED LEVEL DATA INTEGRITY QA ===")
	print("==========================================")
	
	var levels_to_test = [
		"res://levels/level_001.tres",
		"res://levels/level_002.tres"
	]
	
	var total_passes = 0
	var total_failures = 0
	
	for path in levels_to_test:
		print("\n--- Validating: %s ---" % path)
		if not ResourceLoader.exists(path):
			print("  [FAIL] Level file does not exist: %s" % path)
			total_failures += 1
			continue
			
		var lvl: CarJamLevelData = ResourceLoader.load(path) as CarJamLevelData
		if lvl == null:
			print("  [FAIL] Failed to load level: %s" % path)
			total_failures += 1
			continue
			
		# 1. Structural Validator
		var res = CarJamLevelValidator.validate(lvl)
		if res["ok"]:
			print("  [PASS] Board boundaries, unique IDs, non-overlapping footprints, demand conservation")
			total_passes += 1
		else:
			print("  [FAIL] Structural validation failed:")
			for err in res["errors"]:
				print("    * %s" % err)
			total_failures += 1
			
		# 2. Board Model Placement Test
		var board = CarJamBoardModel.new()
		board.setup(lvl.board_size)
		var all_placed = true
		for vd in lvl.vehicles:
			var vm = VehicleModel.new()
			vm.setup_from_data(vd)
			var placed = board.place_vehicle(vm)
			if not placed:
				print("  [FAIL] Board placement rejected vehicle %d ('%s')" % [vm.id, vm.code])
				all_placed = false
				total_failures += 1
		if all_placed:
			print("  [PASS] All %d vehicles successfully placed into CarJamBoardModel without conflict" % lvl.vehicles.size())
			total_passes += 1
			
		# 3. Escape Routes Check (at least 1 immediate legal move)
		var immediate_escapes = 0
		for vd in lvl.vehicles:
			var vm = VehicleModel.new()
			vm.setup_from_data(vd)
			var esc = board.check_swept_escape(vm)
			if esc["can_escape"]:
				immediate_escapes += 1
		print("  Immediate legal escapes available: %d" % immediate_escapes)
		if immediate_escapes > 0:
			print("  [PASS] Level has open escape corridors at start (not completely deadlocked)")
			total_passes += 1
		else:
			print("  [FAIL] Level has 0 immediate legal escapes!")
			total_failures += 1
			
		# 4. Solvability Verification
		var demand = PassengerDemand.from_carjam_level(lvl)
		var plan = LevelIntegration.plan_from_authored_groups(lvl)
		if plan == null:
			var gen = load("res://scripts/universal/wave_generator.gd")
			plan = gen.generate(demand)
		var sol_res = SolvabilityValidator.validate(demand, plan, lvl.parking_slots_count)
		if sol_res.solvable:
			print("  [PASS] Level is mathematically solvable under %d parking slots" % lvl.parking_slots_count)
			total_passes += 1
		else:
			print("  [FAIL] Level not solvable: %s" % sol_res.reason)
			total_failures += 1

	print("\n==========================================")
	print("LEVEL VALIDATION SUMMARY: %d passed, %d failed" % [total_passes, total_failures])
	print("==========================================")
	
	if total_failures > 0:
		quit(1)
	else:
		quit(0)
