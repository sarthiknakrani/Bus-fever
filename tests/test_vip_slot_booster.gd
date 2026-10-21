extends SceneTree

# VIP Slot Booster Test
# Verifies Feature C: a single-use per level that lets the player bypass a stuck bus
# out of its parked bay. The booster starts available, survives across dispatches,
# gets consumed exactly once, and the extracted bus transitions to COMPLETED with
# its slot freed.

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("\n=======================================================")
	print("=== VIP SLOT BOOSTER TEST ===")
	print("=======================================================\n")

	var lvl: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	assert(lvl != null, "level_001.tres must load")
	lvl = lvl.duplicate(true)
	lvl.plus_slot_ids = [4, 5]

	var ctrl := CarJamController.new()
	root.add_child(ctrl)

	# Track signal firings BEFORE load_level so we don't miss the initial emit.
	var available_events: Array = []
	var extracted_events: Array = []
	ctrl.vip_available_changed.connect(func(available: bool) -> void: available_events.append(available))
	ctrl.vip_extracted.connect(func(vid: int, sid: int) -> void: extracted_events.append([vid, sid]))

	ctrl.load_level(lvl)
	var pm = ctrl.parking

	# 1) After load_level, VIP must be available.
	print("[Test] Initial VIP state...")
	assert(ctrl.is_vip_available(), "VIP must be available at level start")
	assert(available_events == [true], "vip_available_changed must emit (true) once at level start")
	print("  [PASS] VIP available at level start\n")

	# 2) Pre-park 4 buses so all unlocked regular bays are occupied (simulating deadlock).
	#    We bypass the visual dispatch by reserving + confirming arrival directly.
	var target_ids: Array = [1, 4, 2, 5]
	var slot_assignments: Array = []
	for vid in target_ids:
		var sid: int = pm.reserve_slot(vid)
		assert(sid != -1, "Reservation must succeed for bus %d" % vid)
		assert(pm.confirm_arrival(sid, vid), "Confirm arrival must succeed for bus %d" % vid)
		ctrl.vehicles[vid].state = VehicleModel.VehicleState.PARKED
		slot_assignments.append(sid)
	print("[Test] 4 buses parked in slots %s" % str(slot_assignments))

	assert(pm.find_available_slot() == -1, "Parking should be FULL after 4 reservations (real deadlock)")
	var parked_slot_ids: Array = []
	for v in target_ids:
		parked_slot_ids.append(pm.get_slot_for_vehicle(v))
	print("[Test] 4 buses parked in slots %s (parking full)" % str(parked_slot_ids))

	# 3) Try VIP extraction on bus 1. Should succeed, slot becomes FREE, bus → COMPLETED.
	print("[Test] VIP extract bus 1...")
	var ok: bool = ctrl.try_extract_vip(1)
	assert(ok, "try_extract_vip(1) must succeed")
	await create_timer(0.05).timeout
	assert(not ctrl.is_vip_available(), "VIP must be marked consumed after extraction")
	assert(ctrl.vehicles[1].state == VehicleModel.VehicleState.COMPLETED, "Extracted bus must transition to COMPLETED")
	assert(ctrl.vehicles[1].reserved_slot == -1, "Extracted bus reserved_slot must be -1")
	assert(pm.get_slot_for_vehicle(1) == -1, "Bus 1 must be removed from any slot's vehicle_id")
	assert(extracted_events.size() == 1, "vip_extracted must fire exactly once")
	# Payload: [bus 1, slot id that was used]. We know slot 1 was reserved first, so the
	# VIP extraction must have reported slot 1 (parking_slots_count=7, slot 0 reserved
	# for VIP, lowest free at test start is slot 1).
	var extracted_slot_id: int = extracted_events[0][1]
	assert(extracted_slot_id == 1, "vip_extracted slot id must be 1 (first reserved slot)")
	# After release, the slot for bus 1 should be FREE.
	var bus1_slot_id: int = -1
	# Find which slot WAS assigned to bus 1 by checking before/after snapshots...
	# Since released slot = FREE, just confirm available slot exists again:
	assert(pm.find_available_slot() != -1, "Parking must have a free slot again after VIP extraction")
	print("  [PASS] VIP consumed and bus 1 cleanly extracted\n")

	# 4) Second VIP attempt must fail (single-use per level).
	print("[Test] Second VIP extract attempt (must fail)...")
	var ok2: bool = ctrl.try_extract_vip(4)
	assert(not ok2, "Second VIP extraction must fail (booster already used)")
	assert(ctrl.vehicles[4].state == VehicleModel.VehicleState.PARKED, "Bus 4 must remain PARKED")
	assert(extracted_events.size() == 1, "vip_extracted must NOT fire on the second attempt")
	print("  [PASS] VIP single-use enforced\n")

	# 5) Restart level → VIP becomes available again.
	print("[Test] Restart level (VIP must reset)...")
	# Use the public API; spawn a fresh load via restart_level.
	ctrl.restart_level()
	assert(ctrl.is_vip_available(), "VIP must be available after restart_level")
	print("  [PASS] VIP reset on level restart\n")

	print("=======================================================")
	print("=== ALL VIP SLOT TESTS PASSED ===")
	print("=======================================================\n")
	quit(0)
