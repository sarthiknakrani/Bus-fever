extends SceneTree

# ==============================================================================
# VIP FLY & PLACE REGRESSION TEST
# ==============================================================================
# Verifies the full user flow:
# 1. VIP button click activates VIP selection mode (_vip_pending = true).
# 2. Player can select ANY bus on the board—even physically blocked buses!
# 3. Selected bus takes off, clears board cells immediately (unblocking others),
#    plays flight arc into VIP Slot 0.
# 4. Lands in VIP Slot 0 and becomes OCCUPIED.
# 5. Matching circulating passengers board normally from Slot 0.
# 6. Single-use per level is strictly enforced.
# ==============================================================================

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("\n=======================================================")
	print("=== VIP FLY & PLACE TO SLOT 0 TEST ===")
	print("=======================================================\n")

	var lvl = CarJamLevelScene.instantiate()
	root.add_child(lvl)

	await process_frame
	for f in 10: await process_frame

	var ctrl: CarJamController = lvl.controller
	assert(ctrl != null, "Controller must exist")
	var pm = ctrl.parking
	assert(pm != null, "Parking manager must exist")

	# 1. VIP available at start
	print("[Test 1] Initial VIP state...")
	assert(ctrl.is_vip_available(), "VIP booster must be available at level start")
	var slot0 = pm.get_slot(0)
	assert(slot0 != null, "Slot 0 must exist")
	assert(slot0.bay_kind == CarJamParkingManager.BayKind.VIP, "Slot 0 must be VIP bay kind")
	assert(slot0.state == CarJamParkingManager.SlotState.FREE, "Slot 0 must start FREE")
	assert(not slot0.is_unlocked, "Slot 0 must not be unlocked for normal dispatches")
	print("  [PASS] Initial VIP state confirmed\n")

	# 2. Normal dispatch avoids Slot 0
	print("[Test 2] Normal dispatch avoids Slot 0...")
	# Find an unblocked vehicle to tap normally
	var normal_vid: int = -1
	for vid in ctrl.vehicles.keys():
		var v: VehicleModel = ctrl.vehicles[vid]
		if v.state == VehicleModel.VehicleState.ON_BOARD and ctrl.board.check_swept_escape(v)["can_escape"]:
			normal_vid = vid
			break
	assert(normal_vid != -1, "Should find at least one unblocked bus")
	var normal_ok: bool = ctrl.tap_vehicle(normal_vid)
	assert(normal_ok, "Normal tap must succeed")
	var normal_slot = ctrl.vehicles[normal_vid].reserved_slot
	assert(normal_slot != 0, "Normal dispatch must NEVER reserve Slot 0 (reserved slot %d)" % normal_slot)
	print("  [PASS] Normal bus dispatched to Slot %d (Slot 0 remained free for VIP)\n" % normal_slot)

	# 3. Find a physically BLOCKED bus on the board
	print("[Test 3] Finding physically blocked bus on board...")
	var blocked_vid: int = -1
	for vid in ctrl.vehicles.keys():
		var v: VehicleModel = ctrl.vehicles[vid]
		if v.state == VehicleModel.VehicleState.ON_BOARD:
			var esc = ctrl.board.check_swept_escape(v)
			if not esc["can_escape"]:
				blocked_vid = vid
				print("  Found physically blocked bus: %d (blocked by %d)" % [blocked_vid, esc["blocker_id"]])
				break
	assert(blocked_vid != -1, "Should find a physically blocked bus on Level 1")

	# Verify normal tap is REJECTED because it is blocked
	var normal_blocked_tap = ctrl.tap_vehicle(blocked_vid)
	assert(not normal_blocked_tap, "Normal tap on blocked bus must be rejected")
	print("  [PASS] Confirmed bus %d is physically trapped\n" % blocked_vid)

	# 4. Activate VIP button
	print("[Test 4] Activating VIP booster mode...")
	lvl._on_vip_button_pressed()
	assert(lvl._vip_pending, "VIP pending mode must be active after pressing VIP button")
	print("  [PASS] VIP selection mode activated (_vip_pending = true)\n")

	# 5. Tap the physically BLOCKED bus in VIP mode -> FLIES to Slot 0!
	print("[Test 5] Selecting blocked bus %d with VIP..." % blocked_vid)
	var blocked_bus_color = ctrl.vehicles[blocked_vid].color_id
	var blocked_cells = ctrl.vehicles[blocked_vid].get_occupied_cells()
	
	lvl._on_vehicle_tapped(blocked_vid)

	assert(not lvl._vip_pending, "VIP pending mode must clear after bus selection")
	assert(not ctrl.is_vip_available(), "VIP booster must now be marked consumed")
	assert(slot0.state == CarJamParkingManager.SlotState.RESERVED, "Slot 0 must now be RESERVED")
	assert(slot0.vehicle_id == blocked_vid, "Slot 0 vehicle_id must match chosen bus")
	assert(ctrl.vehicles[blocked_vid].reserved_slot == 0, "Chosen bus reserved_slot must be 0")

	# Verify board cells occupied by the flying bus are IMMEDIATELY cleared!
	for cell in blocked_cells:
		assert(ctrl.board.get_vehicle_at(cell) == -1, "Cell %s must be freed immediately when bus flies" % str(cell))
	print("  [PASS] Bus %d launched! Board grid cells freed immediately.\n" % blocked_vid)

	# 6. Simulate frames until bus lands in Slot 0
	print("[Test 6] Stepping frames until touchdown in Slot 0...")
	var landed := false
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3500:
		await process_frame
		if slot0.state == CarJamParkingManager.SlotState.OCCUPIED:
			landed = true
			break

	assert(landed, "Bus must land in Slot 0 within 3.5s")
	assert(ctrl.vehicles[blocked_vid].state == VehicleModel.VehicleState.PARKED, "Bus must be PARKED in Slot 0")
	assert(lvl.slot_views[0].slot_state == CarJamParkingManager.SlotState.OCCUPIED, "Slot 0 view must show OCCUPIED")
	print("  [PASS] Bus %d smoothly landed in VIP Slot 0 and is now PARKED!\n" % blocked_vid)

	# 7. Step frames to verify circulating matching passengers board from Slot 0
	print("[Test 7] Checking passenger boarding at VIP Slot 0...")
	var initial_occ = ctrl.vehicles[blocked_vid].passenger_occupancy
	print("  Bus %d initial occupancy: %d / %d (color=%s)" % [blocked_vid, initial_occ, ctrl.vehicles[blocked_vid].capacity, blocked_bus_color])
	
	# Run simulation to let circulating passengers reach slot 0 boarding point
	var boarded := false
	var t_board = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_board < 5000:
		await process_frame
		if ctrl.vehicles[blocked_vid].passenger_occupancy > initial_occ or ctrl.vehicles[blocked_vid].state == VehicleModel.VehicleState.DEPARTING or ctrl.vehicles[blocked_vid].state == VehicleModel.VehicleState.COMPLETED:
			boarded = true
			break

	assert(boarded, "Passengers must board bus at Slot 0")
	print("  Bus %d occupancy after circulation: %d / %d" % [blocked_vid, ctrl.vehicles[blocked_vid].passenger_occupancy, ctrl.vehicles[blocked_vid].capacity])
	print("  [PASS] Passenger boarding from VIP Slot 0 verified!\n")

	# 8. Try VIP button again (must fail - single-use)
	print("[Test 8] Second VIP button press must be rejected...")
	lvl._on_vip_button_pressed()
	assert(not lvl._vip_pending, "Second VIP press must NOT activate pending mode")
	print("  [PASS] Single-use constraint strictly enforced\n")

	print("=======================================================")
	print("=== ALL VIP FLY & PLACE TESTS PASSED! ===")
	print("=======================================================\n")
	quit(0)
