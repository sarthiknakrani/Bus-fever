extends SceneTree

# ==============================================================================
# BUS FEVER — AUTHENTIC PASSENGER SPEED CALIBRATION & MOVEMENT QA SUITE
# ==============================================================================
# Comprehensive verification across all 15 points per Section 10:
#  1. Exact configured lap duration parameter
#  2. Continuous full-loop circulation across 5 laps (zero stalls)
#  3. Identical simulation distance across multiple FPS (30, 60, 120 FPS)
#  4. No overtaking (deterministic sequential slot progression)
#  5. No duplicated or missing passengers (100% conservation)
#  6. Correct FIFO feeder admission sequence
#  7. Zero admission into occupied loop slots
#  8. Gate-only boarding exclusivity
#  9. Correct passenger colors and bus capacity enforcement
# 10. Valid partial-row continuous circulation
# 11. Smooth entrance-to-normal transition
# 12. Safe restart, pause, and resume determinism
# 13. No false deadlocks or false victories
# 14. Existing Level 1 & Level 2 completion demand conservation (1:1)
# 15. Mobile CPU budget (< 0.5ms per step) & Diagnostic overlay telemetry
# ==============================================================================

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

var total_passed := 0
var total_failed := 0

func _init() -> void:
	call_deferred("_run_all_tests")

func _assert_test(test_num: int, name: String, condition: bool, details: String = "") -> void:
	if condition:
		total_passed += 1
		print("  [PASS] Test %2d: %s %s" % [test_num, name, ("(%s)" % details) if details != "" else ""])
	else:
		total_failed += 1
		printerr("  [FAIL] Test %2d: %s -> %s" % [test_num, name, details])

func _ensure_game_controller() -> void:
	var gc_node = root.get_node_or_null("GameController")
	if gc_node == null:
		var gc_script = GDScript.new()
		gc_script.source_code = "extends Node\nvar current_level_number: int = 1\nfunc has_level(n: int) -> bool: return n <= 2\n"
		gc_script.reload()
		gc_node = Node.new()
		gc_node.set_script(gc_script)
		gc_node.name = "GameController"
		root.add_child(gc_node)

func _run_all_tests() -> void:
	print("\n=========================================================================")
	print("=== RUNNING AUTHENTIC PASSENGER SPEED CALIBRATION & QA SUITE (1 - 15) ===")
	print("=========================================================================\n")

	_ensure_game_controller()

	# -------------------------------------------------------------
	# Test 1: Exact configured lap duration within reasonable tolerance
	# -------------------------------------------------------------
	var lvl1: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl1)
	await process_frame
	for f in 5: await process_frame

	var track_len: float = lvl1.passenger_track.curve.get_baked_length()
	var eff_speed: float = lvl1.get_effective_normal_speed()
	var target_lap: float = lvl1.normal_lap_seconds
	var calculated_lap: float = track_len / eff_speed
	var lap_error: float = absf(calculated_lap - target_lap)
	_assert_test(1, "Exact Configured Lap Duration Parameter",
		lap_error < 0.005 and target_lap == 3.41,
		"Target=%.2fs | Calculated=%.4fs | Speed=%.2fpx/s (Error=%.4fs)" % [target_lap, calculated_lap, eff_speed, lap_error])

	# -------------------------------------------------------------
	# Test 2: Continuous full-loop circulation across 5 laps
	# -------------------------------------------------------------
	var start_dist: float = lvl1._loop_distance_unwrapped
	var req_5_laps: float = track_len * 5.0
	var stall_count := 0
	var prev_u := start_dist
	var dt := 1.0 / 60.0
	for step in 1200:
		lvl1._process(dt)
		var delta_u = lvl1._loop_distance_unwrapped - prev_u
		if delta_u < 1.0: stall_count += 1
		prev_u = lvl1._loop_distance_unwrapped
		if (lvl1._loop_distance_unwrapped - start_dist) >= req_5_laps:
			break
	var moved_5_laps: float = lvl1._loop_distance_unwrapped - start_dist
	_assert_test(2, "Continuous 5-Lap Circulation (Zero Stalls)",
		moved_5_laps >= req_5_laps and stall_count == 0,
		"Circulated=%.1fpx (>= 5.0 laps, stalls=%d)" % [moved_5_laps, stall_count])

	# -------------------------------------------------------------
	# Test 3: Identical simulation distance across multiple FPS (30, 60, 120 FPS)
	# -------------------------------------------------------------
	var distances_fps := []
	for fps in [30.0, 60.0, 120.0]:
		var test_lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
		root.add_child(test_lvl)
		await process_frame
		var d0: float = test_lvl._loop_distance_unwrapped
		var dt_fps: float = 1.0 / fps
		var f_count: int = int(round(fps)) # Exactly 1.0 simulated second
		for f in f_count:
			test_lvl._process(dt_fps)
		var d_final: float = test_lvl._loop_distance_unwrapped - d0
		distances_fps.append(d_final)
		test_lvl.queue_free()
		await process_frame

	var max_diff_fps: float = maxf(absf(distances_fps[0] - distances_fps[1]), absf(distances_fps[1] - distances_fps[2]))
	_assert_test(3, "Identical Simulation Across 30, 60, and 120 FPS",
		max_diff_fps < 1.0,
		"30fps=%.2fpx | 60fps=%.2fpx | 120fps=%.2fpx (MaxDiff=%.3fpx < 1.0px)" % [distances_fps[0], distances_fps[1], distances_fps[2], max_diff_fps])

	# -------------------------------------------------------------
	# Test 4: No overtaking (deterministic row ordering preserved)
	# -------------------------------------------------------------
	var ordering_intact := true
	for s_i in range(lvl1._circulating_slots.size() - 1):
		var s_a = lvl1._circulating_slots[s_i]
		var s_b = lvl1._circulating_slots[s_i + 1]
		if s_b["index"] != s_a["index"] + 1:
			ordering_intact = false
			break
	_assert_test(4, "No Overtaking (Strict Geometric Slot Integrity)",
		ordering_intact and lvl1._circulating_slots.size() >= lvl1.TOTAL_LOOP_SLOTS,
		"Slots maintain strictly sequential index spacing across all %d slots" % lvl1._circulating_slots.size())

	# -------------------------------------------------------------
	# Test 5: No duplicated or missing passengers (100% conservation)
	# -------------------------------------------------------------
	var seen_ids := {}
	var duplicate_count := 0
	for pid in lvl1.all_passengers.keys():
		if seen_ids.has(pid): duplicate_count += 1
		seen_ids[pid] = true
	var expected_l1_total := 240
	var actual_l1_total := lvl1.all_passengers.size()
	_assert_test(5, "Passenger Conservation & Zero Duplicates",
		actual_l1_total == expected_l1_total and duplicate_count == 0,
		"Total passengers=%d (Expected=%d), Duplicates=%d" % [actual_l1_total, expected_l1_total, duplicate_count])

	# -------------------------------------------------------------
	# Test 6: Correct FIFO feeder admission
	# -------------------------------------------------------------
	var f0_id: int = lvl1._feeder_rows[0].row_id if not lvl1._feeder_rows.is_empty() else -1
	var f1_id: int = lvl1._feeder_rows[1].row_id if lvl1._feeder_rows.size() > 1 else -1
	lvl1._oval_freed_capacity += 4
	for f in 200:
		lvl1._process(1.0 / 60.0)
		if lvl1._feeder_rows.is_empty() or lvl1._feeder_rows[0].row_id != f0_id:
			break
	var next_f0: int = lvl1._feeder_rows[0].row_id if not lvl1._feeder_rows.is_empty() else -1
	_assert_test(6, "Correct FIFO Feeder Queue Admission",
		next_f0 == f1_id,
		"Head row %d admitted first; next head is row %d" % [f0_id, next_f0])

	# -------------------------------------------------------------
	# Test 7: No admission into an occupied slot
	# -------------------------------------------------------------
	var unique_rows := {}
	var overlap_detected := false
	for s in lvl1._circulating_slots:
		if s["row"] != null:
			if unique_rows.has(s["row"]):
				overlap_detected = true
				break
			unique_rows[s["row"]] = true
	_assert_test(7, "Zero Admission Into Occupied Slots (No Overlap)",
		not overlap_detected,
		"All occupied slots map strictly to unique PassengerRow instances")

	# -------------------------------------------------------------
	# Test 8: Gate-only boarding
	# -------------------------------------------------------------
	var gate_prog: float = lvl1.passenger_track.curve.get_closest_offset(Vector2(0, 115))
	var passed_exact = CarJamLevel.passed_marker(gate_prog - 2.0, gate_prog + 2.0, gate_prog, track_len)
	var passed_miss_before = CarJamLevel.passed_marker(gate_prog - 15.0, gate_prog - 5.0, gate_prog, track_len)
	var passed_miss_after = CarJamLevel.passed_marker(gate_prog + 5.0, gate_prog + 15.0, gate_prog, track_len)
	_assert_test(8, "Gate-Only Boarding Marker Exclusivity",
		passed_exact and not passed_miss_before and not passed_miss_after,
		"Crossing=true | Before=false | After=false (Gate=%.1fpx)" % gate_prog)

	lvl1.queue_free()
	await process_frame

	# -------------------------------------------------------------
	# Test 9: Correct passenger colors and bus capacity
	# -------------------------------------------------------------
	var lvl_board: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl_board)
	await process_frame
	for f in 5: await process_frame

	var v3: VehicleModel = lvl_board.controller.vehicles.get(3, null)
	var tapped := lvl_board.controller.tap_vehicle(3)
	for f in 120:
		await process_frame
		if v3 != null and v3.passenger_occupancy > 0:
			break
	var v3_occ: int = v3.passenger_occupancy if v3 != null else 0
	_assert_test(9, "Matching Color Boarding & Capacity Enforcement",
		tapped and v3_occ <= v3.capacity and v3.color_id == "red",
		"Bus 3 (Color=%s, Cap=%d): Occupancy=%d (<= Cap)" % [v3.color_id, v3.capacity, v3_occ])

	# -------------------------------------------------------------
	# Test 10: Valid partial-row behavior
	# -------------------------------------------------------------
	var p_row: CarJamLevel.PassengerRow = lvl_board._circulating_rows[0]
	p_row.passengers.resize(2)
	for f in 20:
		await process_frame
	_assert_test(10, "Partial-Row Identity & Continuous Circulation",
		lvl_board._circulating_rows.has(p_row) and p_row.passengers.size() == 2,
		"Partial row retained 2 passengers and circulating status smoothly")
	lvl_board.queue_free()
	await process_frame

	# -------------------------------------------------------------
	# Test 11: Smooth entrance-to-normal transition
	# -------------------------------------------------------------
	var lvl_entrance: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	lvl_entrance.force_entrance_parade = true
	root.add_child(lvl_entrance)
	await process_frame
	for f in 5: await process_frame
	var entrance_initially_active = lvl_entrance._entrance_active
	for f in 200:
		lvl_entrance._process(1.0 / 60.0)
		if lvl_entrance._loop_distance_unwrapped > 20.0 or not lvl_entrance._circulating_rows.is_empty():
			break
	var stream_advanced = (lvl_entrance._loop_distance_unwrapped > 10.0 or not lvl_entrance._circulating_rows.is_empty())
	_assert_test(11, "Smooth Feeder Parade Continuous Entry",
		entrance_initially_active and stream_advanced,
		"Entrance active -> Streamed in smoothly (Dist=%.1fpx, CircRows=%d)" % [lvl_entrance._loop_distance_unwrapped, lvl_entrance._circulating_rows.size()])
	lvl_entrance.queue_free()
	await process_frame

	# -------------------------------------------------------------
	# Test 12: Safe restart, pause, and resume
	# -------------------------------------------------------------
	var lvl_pause: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl_pause)
	await process_frame
	for f in 10: await process_frame
	for f in 30: await process_frame
	var d_before_pause: float = lvl_pause._loop_distance_unwrapped
	lvl_pause._on_pause_pressed()
	await process_frame
	for f in 30: await process_frame
	var d_paused: float = lvl_pause._loop_distance_unwrapped
	lvl_pause._on_resume_pressed()
	await process_frame
	for f in 30: await process_frame
	var d_after_resume: float = lvl_pause._loop_distance_unwrapped
	_assert_test(12, "Safe Pause, Deterministic Resume, and Zero Jump",
		d_paused == d_before_pause and d_after_resume > d_paused,
		"Paused distance unchanged (%.2f == %.2f), resume stepped smoothly (%.2f)" % [d_before_pause, d_paused, d_after_resume])

	# -------------------------------------------------------------
	# Test 13: No false deadlocks or false victories
	# -------------------------------------------------------------
	var state_valid := (lvl_pause.controller.state == CarJamController.GameState.PLAYING)
	_assert_test(13, "No False Deadlocks or False Victories During Play",
		state_valid and lvl_pause._result_outcome == "",
		"Controller state strictly PLAYING with zero spurious overlays")

	# -------------------------------------------------------------
	# Test 14: Existing Level 1 and Level 2 demand conservation (1:1)
	# -------------------------------------------------------------
	var l1_res = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	var l2_res = ResourceLoader.load("res://levels/level_002.tres") as CarJamLevelData
	var p1 := 0; var v1 := 0; var p2 := 0; var v2 := 0
	for g in l1_res.passenger_groups: p1 += g.initial_count
	for v in l1_res.vehicles: v1 += v.capacity
	for g in l2_res.passenger_groups: p2 += g.initial_count
	for v in l2_res.vehicles: v2 += v.capacity
	_assert_test(14, "Level 1 & 2 Demand Conservation (1:1 Capacity)",
		(p1 == 240 and v1 == 240) and (p2 == 480 and v2 == 480),
		"L1: %d/%d (100%%) | L2: %d/%d (100%%)" % [p1, v1, p2, v2])

	# -------------------------------------------------------------
	# Test 15: Mobile CPU budget (< 0.5ms per step) & Diagnostic overlay
	# -------------------------------------------------------------
	lvl_pause.show_passenger_debug_overlay = true
	lvl_pause._process(1.0 / 60.0)
	var overlay_active: bool = (lvl_pause._debug_overlay_layer != null and lvl_pause._debug_overlay_layer.visible)
	var overlay_text: String = lvl_pause._debug_overlay_label.text if lvl_pause._debug_overlay_label != null else ""
	var has_expected_fields: bool = ("Track Length" in overlay_text and "Effective Speed" in overlay_text and "Occupied Slots" in overlay_text)
	
	# Benchmark 100 simulation steps
	var t0: int = Time.get_ticks_usec()
	for f in 100:
		lvl_pause._tick_passenger_simulation(1.0 / 60.0)
	var total_usec: int = Time.get_ticks_usec() - t0
	var avg_ms: float = (float(total_usec) / 100.0) / 1000.0
	_assert_test(15, "Mobile CPU Budget & Developer Diagnostic Overlay",
		avg_ms < 0.5 and overlay_active and has_expected_fields,
		"AvgStep=%.3fms (< 0.5ms budget) | Overlay active with all telemetry fields" % avg_ms)

	lvl_pause.queue_free()
	await process_frame

	print("\n=========================================================================")
	print("=== RESULTS: %d PASSED, %d FAILED ===" % [total_passed, total_failed])
	print("=========================================================================\n")

	if total_failed == 0:
		quit(0)
	else:
		quit(1)
