extends SceneTree

const CarJamParkingManager := preload("res://scripts/gameplay/parking_manager.gd")

func _init() -> void:
	print("=== Running Parking Manager QA Tests ===")
	var failures: Array[String] = []

	var parking := CarJamParkingManager.new()
	parking.setup(4)

	# 1. Slot count
	if parking.get_slot_count() != 4:
		failures.append("Slot count should be 4, got %d" % parking.get_slot_count())
	else:
		print("  [PASS] 4 parking slots initialized")

	# 2. Slot 0 is VIP/locked by design; unlocked slots are 1..3.
	# Reservations must therefore start at slot 1, not slot 0.
	var s0 := parking.reserve_slot(101)
	var s1 := parking.reserve_slot(102)
	var s2 := parking.reserve_slot(103)
	var s3 := parking.reserve_slot(104)

	if s0 != 1 or s1 != 2 or s2 != 3 or s3 != -1:
		failures.append("Slots should allocate 1, 2, 3 for unlocked bays; got %d, %d, %d, %d" % [s0, s1, s2, s3])
	else:
		print("  [PASS] Sequential slot allocation 1 -> 2 -> 3 verified (slot 0 is VIP)")

	# 3. Double-reservation guard
	var dup := parking.reserve_slot(101)
	if dup != -1:
		failures.append("Double reservation for vehicle 101 should fail, got slot %d" % dup)
	else:
		print("  [PASS] Double reservation prevented for vehicle 101")

	# 4. Full parking refusal
	var s_overflow := parking.reserve_slot(105)
	if s_overflow != -1 or not parking.is_full():
		failures.append("Parking should be full and refuse 5th vehicle")
	else:
		print("  [PASS] Full parking correctly refused 5th vehicle (is_full=true)")

	# 5. Arrival confirmation on the first reserved slot
	parking.confirm_arrival(1, 101)
	var slot1 = parking.get_slot(1)
	if slot1.state != CarJamParkingManager.SlotState.OCCUPIED:
		failures.append("Slot 1 state should be OCCUPIED after arrival")
	else:
		print("  [PASS] Arrival confirmation: slot 1 is OCCUPIED")

	# 6. Release slot
	parking.mark_releasing(1)
	parking.release_slot(1, 101)
	if not slot1.is_available():
		failures.append("Slot 1 should be available after release")
	elif parking.is_full():
		failures.append("Parking should not be full after release")
	else:
		print("  [PASS] Slot release: slot 1 became EMPTY and available")

	# 7. Next vehicle takes the freed slot 1
	var s_reuse := parking.reserve_slot(105)
	if s_reuse != 1:
		failures.append("Reused slot should be 1, got %d" % s_reuse)
	else:
		print("  [PASS] Freed slot 1 was correctly reused for vehicle 105")

	# 8. VIP (slot 0) must never be reservable
	var vip_try := parking.reserve_slot(900)
	# vip_try must not be 0 — should pick the next free slot instead.
	if vip_try == 0:
		failures.append("VIP slot 0 must not be reservable, but reservation landed there")
	else:
		print("  [PASS] VIP slot 0 is not reservable (reservation went to slot %d)" % vip_try)

	if failures.is_empty():
		print("=== All Parking Manager Tests Passed (0 failures) ===")
		quit(0)
	else:
		print("=== Parking Manager Tests FAILED: %s ===" % str(failures))
		quit(1)
