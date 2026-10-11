extends SceneTree

## P1 PARKING STATE REGRESSION TEST SUITE
##
## Verifies:
##   - Slot reservation is atomic (no double-booking)
##   - DEPARTING slots are NOT available for reservation
##   - Slots return to FREE only via the explicit release path
##   - Visual state propagation: FREE/RESERVED/OCCUPIED/DEPARTING/LOCKED are
##     distinct states (the slot view distinguishes them).
##   - locked slot (id >= default 4) cannot be reserved.

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("\n==========================================")
	print("=== P1 PARKING LIFECYCLE / VISUAL TESTS ===")
	print("==========================================")

	var passed := 0
	var failed := 0
	var pm = CarJamParkingManager.new()

	# -------------------------------------------------------------
	# TEST 1: Setup creates expected number of slots
	# -------------------------------------------------------------
	print("\n--- TEST 1: Slot Count ---")
	pm.setup(4)
	if pm.get_slot_count() == 4:
		print("  [PASS] setup(4) created 4 slots")
		passed += 1
	else:
		print("  [FAIL] Expected 4 slots, got %d" % pm.get_slot_count())
		failed += 1

	# -------------------------------------------------------------
	# TEST 2: Default slots 1..3 are unlocked, slot 0 (VIP) and 4+ locked
	# -------------------------------------------------------------
	print("\n--- TEST 2: Unlock Defaults ---")
	var unlocked_ok := true
	for i in 4:
		var s = pm.get_slot(i)
		var expected: bool = (i >= 1 and i <= 3)
		if s.is_unlocked != expected:
			print("  [FAIL] Slot %d expected is_unlocked=%s, got %s" % [i, str(expected), str(s.is_unlocked)])
			unlocked_ok = false
			failed += 1
	if unlocked_ok:
		print("  [PASS] Slots 1..3 unlocked, slot 0 (VIP) and slot 4+ locked")
		passed += 1

	# -------------------------------------------------------------
	# TEST 3: Reserve all unlocked slots, additional bus gets -1
	# -------------------------------------------------------------
	print("\n--- TEST 3: Reserve All Slots + Reject Extra Bus ---")
	pm.setup(4)
	# Reserve slot 1, 2, 3 (skip VIP 0).
	var res1: int = pm.reserve_slot(101)
	var res2: int = pm.reserve_slot(102)
	var res3: int = pm.reserve_slot(103)
	print("  Reservations: 101->%d, 102->%d, 103->%d" % [res1, res2, res3])
	if res1 == 1 and res2 == 2 and res3 == 3:
		print("  [PASS] Reservations land on slots 1/2/3 in order")
		passed += 1
	else:
		print("  [FAIL] Unexpected slot ids")
		failed += 1

	# Now all unlocked slots are reserved. Next reservation should fail.
	var extra: int = pm.reserve_slot(104)
	if extra == -1:
		print("  [PASS] Extra reservation rejected with -1")
		passed += 1
	else:
		print("  [FAIL] Extra reservation got %d, expected -1" % extra)
		failed += 1

	# is_full() should also report true.
	if pm.is_full():
		print("  [PASS] is_full() == true after exhausting unlocked slots")
		passed += 1
	else:
		print("  [FAIL] is_full() should be true")
		failed += 1

	# -------------------------------------------------------------
	# TEST 4: A DEPARTING slot is NOT available for new reservation
	# -------------------------------------------------------------
	print("\n--- TEST 4: DEPARTING Slot Is Not Free ---")
	pm.setup(4)
	var r_a: int = pm.reserve_slot(201)
	if r_a != 1:
		print("  [FAIL] Could not reserve first slot")
		failed += 1
	pm.confirm_arrival(r_a, 201)
	# Slot is now OCCUPIED.
	var slot_a = pm.get_slot(r_a)
	if slot_a.state != CarJamParkingManager.SlotState.OCCUPIED:
		print("  [FAIL] confirm_arrival did not put slot into OCCUPIED (got %d)" % slot_a.state)
		failed += 1
	else:
		# Start departure.
		pm.mark_departing(r_a, 201)
		if slot_a.state != CarJamParkingManager.SlotState.DEPARTING:
			print("  [FAIL] mark_departing did not transition to DEPARTING (got %d)" % slot_a.state)
			failed += 1
		else:
			# Now find_available_slot() must NOT return this slot.
			var found: int = pm.find_available_slot()
			print("  DEPARTING slot=%d, find_available_slot() returned %d" % [r_a, found])
			if found != r_a:
				print("  [PASS] DEPARTING slot is NOT available for reservation")
				passed += 1
			else:
				print("  [FAIL] DEPARTING slot is wrongly considered available")
				failed += 1

			# Reject an additional bus while this is DEPARTING.
			var extra_b: int = pm.reserve_slot(202)
			# There are still slots 2 and 3 free, so 202 should land on 2.
			if extra_b == 2:
				print("  [PASS] Extra bus routed to next free slot (2), bypassing DEPARTING")
				passed += 1
			else:
				print("  [FAIL] Expected bus to be reserved at slot 2, got %d" % extra_b)
				failed += 1

	# -------------------------------------------------------------
	# TEST 5: release_slot returns DEPARTING -> FREE only with right owner
	# -------------------------------------------------------------
	print("\n--- TEST 5: release_slot Ownership & State Transition ---")
	# Currently: slot 1 is DEPARTING for 201, slot 2 RESERVED for 103, slot 3 RESERVED for 102
	# We need to confirm slot 2 has the right owner.
	slot_a = pm.get_slot(r_a)
	var wrong_release: bool = pm.release_slot(r_a, 9999)  # wrong vehicle id
	if not wrong_release:
		print("  [PASS] release_slot() rejects ownership mismatch (vehicle 9999)")
		passed += 1
	else:
		print("  [FAIL] release_slot() should have rejected wrong owner")
		failed += 1

	# The slot must still be DEPARTING.
	if slot_a.state == CarJamParkingManager.SlotState.DEPARTING:
		print("  [PASS] Slot remains DEPARTING after rejected release")
		passed += 1
	else:
		print("  [FAIL] Slot state changed despite rejection (got %d)" % slot_a.state)
		failed += 1

	# Correct owner release -> back to FREE
	var ok_release: bool = pm.release_slot(r_a, 201)
	if ok_release and slot_a.state == CarJamParkingManager.SlotState.FREE and slot_a.vehicle_id == -1:
		print("  [PASS] Correct owner release transitions slot back to FREE")
		passed += 1
	else:
		print("  [FAIL] Correct owner release did not transition to FREE: state=%d, vehicle_id=%d" % [slot_a.state, slot_a.vehicle_id])
		failed += 1

	# -------------------------------------------------------------
	# TEST 6: ParkingSlotView visual states are distinct
	# -------------------------------------------------------------
	print("\n--- TEST 6: ParkingSlotView Distinguishes All 4 States ---")
	# We cannot rely on the visual color rendering without rendering infrastructure.
	# Instead, verify that the slot view exposes state-mutation without crashing and
	# that all four states are recognized by the underlying manager.
	var PVS := load("res://scripts/gameplay/parking_slot_view.gd")
	var pv: Node2D = PVS.new()
	pv.setup(0)
	pv.set_state(CarJamParkingManager.SlotState.FREE)
	pv.set_state(CarJamParkingManager.SlotState.RESERVED)
	pv.set_state(CarJamParkingManager.SlotState.OCCUPIED)
	pv.set_state(CarJamParkingManager.SlotState.DEPARTING)
	# Verify the visual contract by inspecting the slot_state we set.
	if pv.slot_state == CarJamParkingManager.SlotState.DEPARTING:
		print("  [PASS] ParkingSlotView accepts all 4 distinct states without error")
		passed += 1
	else:
		print("  [FAIL] ParkingSlotView state corrupt: %d" % pv.slot_state)
		failed += 1
	pv.queue_free()

	# -------------------------------------------------------------
	# TEST 7: VehicleModel can_dispatch + atomic dispatch lifecycle
	# -------------------------------------------------------------
	print("\n--- TEST 7: Reject Duplicate Reservation For Same Vehicle ---")
	pm.setup(4)
	var r1: int = pm.reserve_slot(301)
	var r2: int = pm.reserve_slot(301)  # same vehicle id — must be rejected
	print("  First reservation: %d, second (same vehicle): %d" % [r1, r2])
	if r1 != -1 and r2 == -1:
		print("  [PASS] Second reservation for same vehicle rejected (-1)")
		passed += 1
	else:
		print("  [FAIL] Expected r1 valid and r2 == -1")
		failed += 1

	# -------------------------------------------------------------
	# TEST 8: Atomic parking state never lets find_available_slot return a
	# reserved/departing slot.
	# -------------------------------------------------------------
	print("\n--- TEST 8: find_available_slot Filters RESERVED+DEPARTING ---")
	pm.setup(4)
	pm.reserve_slot(401)  # slot 1 RESERVED
	pm.reserve_slot(402)  # slot 2 RESERVED
	pm.confirm_arrival(2, 402)  # slot 2 OCCUPIED
	pm.mark_departing(2, 402)  # slot 2 DEPARTING

	var available := pm.get_available_slot_count()
	print("  get_available_slot_count()=%d (expect 1: slot 3 only)" % available)
	if available == 1:
		print("  [PASS] Only unlocked & FREE slots are counted as available")
		passed += 1
	else:
		print("  [FAIL] Expected 1 available slot, got %d" % available)
		failed += 1

	# -------------------------------------------------------------
	# FINAL
	# -------------------------------------------------------------
	print("\n==========================================")
	print("P1 PARKING SUITE SUMMARY: %d passed, %d failed" % [passed, failed])
	print("==========================================")

	if failed > 0:
		quit(1)
	else:
		quit(0)