extends SceneTree

# Mystery Bus Factory Helper Test
# Verifies Feature B's authoring path: create_level_1_with_mystery() returns a
# CarJamLevelData where the requested vehicle IDs are flagged is_mystery=true in the
# VehicleData. After load_level, the runtime VehicleModel mirrors the same flag,
# is_unlocked on color (true), and the controller's tap_vehicle signal pipeline
# still drives the reveal flow.

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("\n=======================================================")
	print("=== MYSTERY BUS FACTORY HELPER TEST ===")
	print("=======================================================\n")

	# 1) Authored data: requested vehicle IDs are flagged is_mystery=true.
	var lvl: CarJamLevelData = CarJamLevelFactory.create_level_1_with_mystery([1, 5])
	assert(lvl != null, "Factory must return a level")
	var mystery_count: int = 0
	var mystery_ids_found: Array = []
	for vd in lvl.vehicles:
		if vd.is_mystery:
			mystery_count += 1
			mystery_ids_found.append(vd.id)
	print("[Test] Mystery buses authored: %s (expected [1, 5])" % str(mystery_ids_found))
	assert(mystery_count == 2, "Exactly 2 mystery buses must be authored")
	assert(1 in mystery_ids_found, "Bus 1 (yellow) must be mystery")
	assert(5 in mystery_ids_found, "Bus 5 (blue) must be mystery")
	assert(not lvl.vehicles[0].color_id.is_empty(), "Mystery buses still carry their true color_id")
	# Bus 1's true color is preserved (the controller hides it until reveal):
	assert(lvl.vehicles[0].color_id == "yellow", "Bus 1 color_id must remain yellow in data")
	print("  [PASS] Authoring produces 2 mystery buses with intact color data\n")

	# 2) Runtime: load_level mirrors the mystery flag onto VehicleModel.
	var ctrl := CarJamController.new()
	root.add_child(ctrl)
	ctrl.load_level(lvl)
	var bus1: VehicleModel = ctrl.vehicles.get(1, null)
	var bus5: VehicleModel = ctrl.vehicles.get(5, null)
	var bus2: VehicleModel = ctrl.vehicles.get(2, null)
	assert(bus1 != null and bus5 != null and bus2 != null, "Required vehicles must exist")
	assert(bus1.is_mystery, "Bus 1 runtime is_mystery must be true after load_level")
	assert(bus5.is_mystery, "Bus 5 runtime is_mystery must be true")
	assert(not bus2.is_mystery, "Bus 2 runtime is_mystery must remain false")
	# The buses still report their true colors (used for matching after reveal):
	assert(bus1.color_id == "yellow", "Bus 1 runtime color_id must still be yellow")
	assert(bus5.color_id == "blue", "Bus 5 runtime color_id must still be blue")
	print("  [PASS] Runtime mirroring of is_mystery flag\n")

	# 3) First tap on a mystery bus emits mystery_revealed (no dispatch, state stays ON_BOARD).
	var revealed: Array = []
	var dispatched: Array = []
	ctrl.mystery_revealed.connect(func(vid: int) -> void: revealed.append(vid))
	ctrl.vehicle_dispatch_started.connect(func(vid: int, sid: int, corridor: Array) -> void: dispatched.append(vid))

	var ok: bool = ctrl.tap_vehicle(1)
	assert(ok, "Mystery tap must succeed (return true)")
	await create_timer(0.05).timeout
	assert(revealed.size() == 1 and revealed[0] == 1, "mystery_revealed signal must fire once for bus 1")
	assert(dispatched.is_empty(), "vehicle_dispatch_started must NOT fire on mystery tap")
	assert(not bus1.is_mystery, "Bus 1 is_mystery must flip to false after reveal")
	assert(bus1.state == VehicleModel.VehicleState.ON_BOARD, "Bus 1 must stay ON_BOARD")
	print("  [PASS] First tap reveals; no dispatch\n")

	print("=======================================================")
	print("=== ALL MYSTERY FACTORY TESTS PASSED ===")
	print("=======================================================\n")
	quit(0)
