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

	# 2. Sequential reservation (lowest free slot)
	var s0 := parking.reserve_slot(101)
	var s1 := parking.reserve_slot(102)
	var s2 := parking.reserve_slot(103)
	var s3 := parking.reserve_slot(104)

	if s0 != 0 or s1 != 1 or s2 != 2 or s3 != 3:
		failures.append("Slots should allocate sequentially 0, 1, 2, 3; got %d, %d, %d, %d" % [s0, s1, s2, s3])
	else:
		print("  [PASS] Sequential slot allocation 0 -> 1 -> 2 -> 3 verified")

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

	# 5. Arrival confirmation
	parking.confirm_arrival(0, 101)
	var slot0 = parking.get_slot(0)
	if slot0.state != CarJamParkingManager.SlotState.OCCUPIED:
		failures.append("Slot 0 state should be OCCUPIED after arrival")
	else:
		print("  [PASS] Arrival confirmation: slot 0 is OCCUPIED")

	# 6. Release slot
	parking.mark_releasing(0)
	parking.release_slot(0)
	if not slot0.is_available():
		failures.append("Slot 0 should be available after release")
	elif parking.is_full():
		failures.append("Parking should not be full after release")
	else:
		print("  [PASS] Slot release: slot 0 became EMPTY and available")

	# 7. Next vehicle takes freed slot 0
	var s_reuse := parking.reserve_slot(105)
	if s_reuse != 0:
		failures.append("Reused slot should be 0, got %d" % s_reuse)
	else:
		print("  [PASS] Freed slot 0 was correctly reused for vehicle 105")

	if failures.is_empty():
		print("=== All Parking Manager Tests Passed (0 failures) ===")
		quit(0)
	else:
		print("=== Parking Manager Tests FAILED: %s ===" % str(failures))
		quit(1)
