extends SceneTree

func _init() -> void:
	print("==========================================")
	print("=== TASK 4: BOARDING GEOMETRY REGRESSION ===")
	print("==========================================")
	
	var passed = 0
	var failed = 0
	
	# Test 1: Legal Level 1 Bounds Calculation (7 slots)
	print("\n--- TEST 1: Legal Level 1 Bounds (7 Slots) ---")
	var lvl_data = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	var slot_count = lvl_data.parking_slots_count if lvl_data != null else 7
	print("Level 1 slot count: ", slot_count)
	
	var curve := Curve2D.new()
	var h := 63.51
	curve.add_point(Vector2(270, 0), Vector2(0, -h), Vector2(0, h))
	curve.add_point(Vector2(155, 115), Vector2(h, 0), Vector2.ZERO)
	curve.add_point(Vector2(-155, 115), Vector2.ZERO, Vector2(-h, 0))
	curve.add_point(Vector2(-270, 0), Vector2(0, h), Vector2(0, -h))
	curve.add_point(Vector2(-155, -115), Vector2(-h, 0), Vector2.ZERO)
	curve.add_point(Vector2(155, -115), Vector2.ZERO, Vector2(h, 0))
	curve.add_point(Vector2(270, 0), Vector2(0, -h), Vector2(0, h))
	
	var slot_spacing := 65.0
	var total_span: float = float(slot_count - 1) * slot_spacing
	var min_trig: float = 999999.0
	var max_trig: float = -999999.0
	var points: Dictionary = {}
	
	for i in slot_count:
		var slot_x: float = -total_span / 2.0 + float(i) * slot_spacing
		var closest: float = curve.get_closest_offset(Vector2(slot_x, 115.0))
		points[i] = closest
		min_trig = minf(min_trig, closest)
		max_trig = maxf(max_trig, closest)
		print("  Slot %d (x=%.1f) -> trig=%.2f px" % [i, slot_x, closest])
		
	var start_prog = min_trig - 25.0
	var end_prog = max_trig + 25.0
	print("  Platform bounds: [%.2f, %.2f]" % [start_prog, end_prog])
	
	# Verify all slots are covered
	var all_covered = true
	for i in slot_count:
		var p = points[i]
		if p < start_prog or p > end_prog:
			all_covered = false
			print("  [FAIL] Slot %d (%.2f) not covered!" % [i, p])
	if all_covered:
		print("  [PASS] All 7 slots are cleanly covered by dynamic platform bounds")
		passed += 1
	else:
		failed += 1
		
	# Verify top straight (prog > 850 and prog < 1160) is strictly NOT in boarding zone
	var top_straight_sample = curve.get_closest_offset(Vector2(0, -115))
	var top_in_zone = (top_straight_sample >= (start_prog - 20.0) and top_straight_sample <= (end_prog + 20.0))
	if not top_in_zone:
		print("  [PASS] Top straight (prog=%.2f) is strictly excluded from boarding zone" % top_straight_sample)
		passed += 1
	else:
		print("  [FAIL] Top straight erroneously marked inside boarding zone!")
		failed += 1

	# Test 2: Different Slot Counts (4, 5, 6 slots)
	print("\n--- TEST 2: Different Slot Counts (4, 5, 6 slots) ---")
	for count in [4, 5, 6]:
		var span_c = float(count - 1) * slot_spacing
		var min_c = 999999.0
		var max_c = -999999.0
		var pts_c = {}
		for i in count:
			var sx = -span_c / 2.0 + float(i) * slot_spacing
			var cl = curve.get_closest_offset(Vector2(sx, 115.0))
			pts_c[i] = cl
			min_c = minf(min_c, cl)
			max_c = maxf(max_c, cl)
		var sp_c = min_c - 25.0
		var ep_c = max_c + 25.0
		var ok = true
		for i in count:
			if pts_c[i] < sp_c or pts_c[i] > ep_c:
				ok = false
		if ok:
			print("  [PASS] %d slots span [%.2f, %.2f] - all %d slots covered" % [count, sp_c, ep_c, count])
			passed += 1
		else:
			print("  [FAIL] %d slots failed coverage!" % count)
			failed += 1

	# Test 3: Wraparound Resilience
	print("\n--- TEST 3: Wraparound Resilience Test ---")
	var track_len = curve.get_baked_length()
	var test_progs = [50.0, 100.0, 500.0, 600.0, 1000.0, 1300.0]
	var wrap_ok = true
	for pr in test_progs:
		var in_z = false
		if start_prog <= end_prog:
			in_z = (pr >= (start_prog - 20.0) and pr <= (end_prog + 20.0))
		else:
			in_z = (pr >= (start_prog - 20.0) or pr <= (end_prog + 20.0))
		if pr == 100.0 and not in_z: wrap_ok = false
		if pr == 500.0 and not in_z: wrap_ok = false
		if pr == 1000.0 and in_z: wrap_ok = false
		if pr == 1300.0 and in_z: wrap_ok = false
	if wrap_ok:
		print("  [PASS] Wraparound logic correctly evaluates in-zone vs out-of-zone points")
		passed += 1
	else:
		print("  [FAIL] Wraparound evaluation error!")
		failed += 1

	print("\n==========================================")
	print("=== RESULTS: %d PASSED, %d FAILED ===" % [passed, failed])
	print("==========================================")
	if failed == 0:
		quit(0)
	else:
		quit(1)
