extends SceneTree

var CarJamPuzzleSolver = load("res://scripts/gameplay/puzzle_solver.gd")
var CarJamLevelValidator = load("res://scripts/gameplay/level_validator.gd")

func _init() -> void:
	call_deferred("_run_audit")

func _run_audit() -> void:
	print("--- Running Level 1 & Level 2 Audit ---")
	
	# 1. Audit Level 1
	var lvl1 = load("res://levels/level_001.tres") as CarJamLevelData
	var res1 = CarJamLevelValidator.validate(lvl1)
	print("Level 1 validation ok: ", res1["ok"], " errors: ", res1["errors"])
	
	# 2. Audit Level 2 current
	var lvl2 = load("res://levels/level_002.tres") as CarJamLevelData
	var res2 = CarJamLevelValidator.validate(lvl2)
	print("\nLevel 2 CURRENT validation ok: ", res2["ok"])
	for e in res2["errors"]:
		print("  - ", e)
		
	# 3. Test Candidate Fixes for Level 2
	print("\n--- Testing Candidate Fixes for Level 2 ---")
	# Candidate A: Move v2 to row 0: anchor (4, 0), fp [(0,0), (-1,0)], dir RIGHT (3)
	var candA = lvl2.duplicate(true) as CarJamLevelData
	for v in candA.vehicles:
		if v.id == 2:
			v.anchor = Vector2i(4, 0)
			v.initial_anchor = Vector2i(4, 0)
			var fp: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 0)]
			v.footprint = fp
			v.direction = CarJamVehicleData.Direction.RIGHT
	var resA = CarJamLevelValidator.validate(candA)
	print("Candidate A (v2 at (4,0) & (3,0)) validation: ", resA["ok"], " errors: ", resA["errors"])
	
	# Check board escapes for Candidate A:
	var bm = CarJamBoardModel.new()
	bm.setup(candA.board_size)
	var vmodels: Dictionary = {}
	for vd in candA.vehicles:
		var vm = VehicleModel.new()
		vm.setup_from_data(vd)
		vmodels[vm.id] = vm
		var placed = bm.place_vehicle(vm)
		if not placed:
			print("  [ERROR] Candidate A could not place vehicle: ", vm.id)
	
	print("\nCandidate A Vehicle Escapes:")
	var can_escape_count = 0
	for vid in vmodels:
		var vm = vmodels[vid]
		var esc = bm.check_swept_escape(vm)
		print("  Bus %d (%s, %s, cells=%s, dir=%s): can_escape=%s, blocker=%s" % [
			vm.id, vm.code, vm.color_id, vm.get_occupied_cells(),
			CarJamVehicleData.dir_to_string(vm.direction),
			esc["can_escape"], esc["blocker_id"]
		])
		if esc["can_escape"]:
			can_escape_count += 1
	print("Total immediate escape candidates: ", can_escape_count)
	
	# Also test Solvability via SolvabilityValidator:
	var demand_script = load("res://scripts/universal/passenger_demand.gd")
	var demand = demand_script.from_carjam_level(candA)
	var plan = LevelIntegration.plan_from_authored_groups(candA)
	if plan:
		var val_script = load("res://scripts/universal/solvability_validator.gd")
		var val_res = val_script.validate(demand, plan, 7)
		print("Universal SolvabilityValidator result: solvable=", val_res.solvable, " reason=", val_res.reason)
	
	quit(0)
