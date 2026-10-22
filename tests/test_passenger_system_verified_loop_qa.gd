extends SceneTree

# ==============================================================================
# BUS FEVER — PASSENGER SYSTEM VERIFIED FIXED-SLOT LOOP QA SUITE (TESTS A - J)
# ==============================================================================
# Authoritatively verifies all requirements from Milestones 1 through 8:
# Test A: Full loop continuous movement without taps (5+ laps, zero stalls)
# Test B: Exact passenger conservation invariant across all states (240 total L1)
# Test C: Boarding exclusivity at the boarding gate (passed_marker gate crossing)
# Test D: Strict FIFO feeder queue progression (no skipping, exact sequence)
# Test E: Feeder backpressure gate (feeder halts when loop is full)
# Test F: Partial row handling (remaining passengers continue circulating)
# Test G: Frame-rate invariance (15 FPS, 60 FPS, 120 FPS deterministic motion)
# Test H: Pause and resume determinism (preserves exact positions and state)
# Test I: Runtime track snapshot & terminal state checks
# Test J: Level 2 scalability (480 passengers, 36 loop slots, 84 feeder rows)
# ==============================================================================

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

var total_passed: int = 0
var total_failed: int = 0

func _init() -> void:
	call_deferred("_run_qa_suite")

func _assert_test(test_id: String, name: String, condition: bool, details: String = "") -> void:
	if condition:
		total_passed += 1
		print("  [PASS] Test %s: %s %s" % [test_id, name, ("(%s)" % details) if details != "" else ""])
	else:
		total_failed += 1
		printerr("  [FAIL] Test %s: %s -> %s" % [test_id, name, details])

func _run_qa_suite() -> void:
	print("\n=========================================================================")
	print("=== RUNNING VERIFIED PASSENGER LOOP SYSTEM QA SUITE (TESTS A - J) ===")
	print("=========================================================================\n")

	var gc_node = root.get_node_or_null("GameController")
	if gc_node == null:
		var gc_script = GDScript.new()
		gc_script.source_code = "extends Node\nvar current_level_number: int = 1\nfunc has_level(n: int) -> bool: return n <= 2\n"
		gc_script.reload()
		gc_node = Node.new()
		gc_node.set_script(gc_script)
		gc_node.name = "GameController"
		root.add_child(gc_node)
	gc_node.current_level_number = 1

	await _test_a_continuous_movement_5_laps()
	await _test_b_passenger_conservation_invariant()
	await _test_c_gate_marker_exclusivity()
	await _test_d_strict_fifo_feeder_queue()
	await _test_e_feeder_backpressure_gate()
	await _test_f_partial_row_handling()
	await _test_g_framerate_invariance()
	await _test_h_pause_resume_determinism()
	await _test_i_terminal_state_snapshot_integration()
	await _test_j_level_2_scale_validation()

	print("\n=========================================================================")
	print("=== SUITE SUMMARY: %d PASSED, %d FAILED ===" % [total_passed, total_failed])
	print("=========================================================================\n")

	quit(total_failed)

# ---------------------------------------------
# TEST A: FULL LOOP CONTINUOUS MOVEMENT (5+ LAPS, 0 STALLS)
# ---------------------------------------------
func _test_a_continuous_movement_5_laps() -> void:
	print("--- TEST A: Continuous Loop Motion (>= 5 Complete Laps Without Taps) ---")
	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl)
	await process_frame
	for f in 10: await process_frame

	var track_len: float = lvl.passenger_track.curve.get_baked_length()
	var req_dist: float = track_len * 5.0
	var initial_u: float = lvl._loop_distance_unwrapped
	var stall_frames: int = 0
	var prev_u: float = initial_u
	var dt: float = 1.0 / 60.0

	var max_steps: int = 2000
	for f in max_steps:
		lvl._process(dt)
		var delta_u = lvl._loop_distance_unwrapped - prev_u
		if delta_u < 1.0:
			stall_frames += 1
		prev_u = lvl._loop_distance_unwrapped
		if (lvl._loop_distance_unwrapped - initial_u) >= req_dist:
			break

	var total_moved: float = lvl._loop_distance_unwrapped - initial_u
	var laps: float = total_moved / track_len

	_assert_test("A", "Continuous Loop Motion (>= 5 Laps, Zero Stalls)",
		total_moved >= req_dist and stall_frames == 0,
		"Circulated %.1f px (%.2f laps), stall_frames=%d" % [total_moved, laps, stall_frames])

	lvl.queue_free()
	await process_frame

# -----------------------------------------------------------------------------
# TEST B: PASSENGER CONSERVATION INVARIANT (240 L1 PASSENGERS)
# -----------------------------------------------------------------------------
func _test_b_passenger_conservation_invariant() -> void:
	print("\n--- TEST B: Exact Passenger Conservation Invariant (L1 = 240) ---")
	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl)
	await process_frame
	for f in 10: await process_frame

	var expected_total: int = 240
	var counts := {"PENDING": 0, "FEEDER": 0, "CIRCULATING": 0, "RESERVED": 0, "BOARDING": 0, "BOARDED": 0}
	var duplicate_pids: int = 0
	var seen: Dictionary = {}

	for pid in lvl.all_passengers:
		if seen.has(pid):
			duplicate_pids += 1
		seen[pid] = true
		var st: String = lvl.all_passengers[pid].get("state", "")
		if counts.has(st):
			counts[st] += 1

	var actual_sum: int = 0
	for k in counts: actual_sum += counts[k]

	_assert_test("B", "Passenger Conservation Invariant Holds Exactly",
		actual_sum == expected_total and duplicate_pids == 0 and counts["CIRCULATING"] == 144 and counts["FEEDER"] == 96,
		"Total=%d (Expected %d), Circ=%d, Feeder=%d, Duplicates=%d" % [
			actual_sum, expected_total, counts["CIRCULATING"], counts["FEEDER"], duplicate_pids
		])

	lvl.queue_free()
	await process_frame

# -----------------------------------------------------------------------------
# TEST C: GATE MARKER EXCLUSIVITY
# -----------------------------------------------------------------------------
func _test_c_gate_marker_exclusivity() -> void:
	print("\n--- TEST C: Boarding Gate Marker Crossing Exclusivity ---")
	var track_len: float = 1142.644
	var gate_prog: float = 285.661

	# Test CarJamLevel.passed_marker math directly
	var pass_crossing: bool = CarJamLevel.passed_marker(280.0, 290.0, gate_prog, track_len)
	var fail_before: bool = CarJamLevel.passed_marker(270.0, 280.0, gate_prog, track_len)
	var fail_after: bool = CarJamLevel.passed_marker(290.0, 300.0, gate_prog, track_len)
	var pass_wrap: bool = CarJamLevel.passed_marker(track_len - 5.0, track_len + 5.0, 0.0, track_len)

	_assert_test("C", "passed_marker Exact Gate Crossing Semantics",
		pass_crossing and not fail_before and not fail_after and pass_wrap,
		"Crossing=true, Before=false, After=false, Wrap=true")

# -----------------------------------------------------------------------------
# TEST D: STRICT FIFO FEEDER QUEUE PROGRESSION
# -----------------------------------------------------------------------------
func _test_d_strict_fifo_feeder_queue() -> void:
	print("\n--- TEST D: Strict FIFO Feeder Queue Sequence ---")
	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl)
	await process_frame
	for f in 10: await process_frame

	var initial_f0_id: int = lvl._feeder_rows[0].row_id if not lvl._feeder_rows.is_empty() else -1
	var initial_f1_id: int = lvl._feeder_rows[1].row_id if lvl._feeder_rows.size() > 1 else -1

	# Release capacity for exactly 1 row (4 seats)
	lvl._oval_freed_capacity += 4
	var merged := false
	for f in 300:
		await process_frame
		if not lvl._feeder_rows.is_empty() and lvl._feeder_rows[0].row_id != initial_f0_id:
			merged = true
			break

	var new_f0_id: int = lvl._feeder_rows[0].row_id if not lvl._feeder_rows.is_empty() else -1

	_assert_test("D", "Strict FIFO Order Preserved on Feeder Merge",
		merged and new_f0_id == initial_f1_id,
		"Row %d merged first; Row %d is now the new head of queue" % [initial_f0_id, new_f0_id])

	lvl.queue_free()
	await process_frame

# -----------------------------------------------------------------------------
# TEST E: FEEDER BACKPRESSURE GATE
# -----------------------------------------------------------------------------
func _test_e_feeder_backpressure_gate() -> void:
	print("\n--- TEST E: Feeder Backpressure (Zero Admission When Oval Is Full) ---")
	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl)
	await process_frame
	for f in 10: await process_frame

	var f_count_start: int = lvl._feeder_rows.size()
	# Simulate 180 frames without tapping any buses or freeing capacity
	for f in 180:
		await process_frame

	var f_count_end: int = lvl._feeder_rows.size()
	var cap_remained_zero: bool = (lvl._oval_freed_capacity == 0)

	_assert_test("E", "Zero Premature Merge Without Boarding",
		f_count_end == f_count_start and cap_remained_zero,
		"Feeder rows strictly stayed %d, freed_cap remained %d" % [f_count_end, lvl._oval_freed_capacity])

	lvl.queue_free()
	await process_frame

# -----------------------------------------------------------------------------
# TEST F: PARTIAL ROW HANDLING
# -----------------------------------------------------------------------------
func _test_f_partial_row_handling() -> void:
	print("\n--- TEST F: Partial Row Handling (Identity Conservation & Circulation) ---")
	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl)
	await process_frame
	for f in 10: await process_frame

	# Take a circulating row and simulate 2 passengers boarding, 2 remaining
	var test_row: CarJamLevel.PassengerRow = lvl._circulating_rows[0]
	var orig_p_count: int = test_row.passengers.size()
	var p_kept_a = test_row.passengers[0]
	var p_kept_b = test_row.passengers[1]
	test_row.passengers = [p_kept_a, p_kept_b]

	# Step 60 frames: partial row continues circulating smoothly
	for f in 60:
		await process_frame

	var still_circulating: bool = lvl._circulating_rows.has(test_row)
	var passengers_intact: bool = (test_row.passengers.size() == 2 and test_row.passengers[0]["id"] == p_kept_a["id"])

	_assert_test("F", "Partial Row Continues Circulating Without Loss or Freeze",
		still_circulating and passengers_intact,
		"Partial row retained %d passengers and remained in circulation" % test_row.passengers.size())

	lvl.queue_free()
	await process_frame

# -----------------------------------------------------------------------------
# TEST G: FRAME-RATE INVARIANCE (15, 60, 120 FPS)
# -----------------------------------------------------------------------------
func _test_g_framerate_invariance() -> void:
	print("\n--- TEST G: Frame-Rate Invariance (Fixed Spacing & Exact Distance) ---")
	var speeds := [1.0 / 15.0, 1.0 / 60.0, 1.0 / 120.0]
	var distances := []

	for dt in speeds:
		var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
		root.add_child(lvl)
		await process_frame
		for f in 5: await process_frame

		var start_u: float = lvl._loop_distance_unwrapped
		var total_time: float = 1.0 # 1 full second
		var steps: int = int(round(total_time / dt))
		for s in steps:
			lvl._process(dt)

		var moved = lvl._loop_distance_unwrapped - start_u
		distances.append(moved)
		lvl.queue_free()
		await process_frame

	var err_60_vs_15: float = absf(distances[0] - distances[1])
	var err_60_vs_120: float = absf(distances[2] - distances[1])

	_assert_test("G", "Deterministic Movement Invariant to Delta Variations",
		err_60_vs_15 < 1.0 and err_60_vs_120 < 1.0,
		"15 FPS: %.2f px, 60 FPS: %.2f px, 120 FPS: %.2f px (Max error < 1.0px)" % [
			distances[0], distances[1], distances[2]
		])

# -----------------------------------------------------------------------------
# TEST H: PAUSE AND RESUME DETERMINISM
# -----------------------------------------------------------------------------
func _test_h_pause_resume_determinism() -> void:
	print("\n--- TEST H: Pause and Resume Movement Determinism ---")
	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl)
	await process_frame
	for f in 10: await process_frame

	for f in 30: await process_frame
	var pre_pause_u: float = lvl._loop_distance_unwrapped
	var pre_pause_rows: int = lvl._circulating_rows.size()

	lvl._on_pause_pressed()
	await process_frame
	for f in 30: await process_frame

	var paused_u: float = lvl._loop_distance_unwrapped
	lvl._on_resume_pressed()
	await process_frame
	for f in 30: await process_frame

	var post_resume_u: float = lvl._loop_distance_unwrapped

	_assert_test("H", "Pause Fully Freezes and Resume Continues Without Drift",
		paused_u == pre_pause_u and post_resume_u > paused_u and lvl._circulating_rows.size() == pre_pause_rows,
		"PrePause=%.2f, DuringPause=%.2f, PostResume=%.2f" % [pre_pause_u, paused_u, post_resume_u])

	lvl.queue_free()
	await process_frame

# -----------------------------------------------------------------------------
# TEST I: RUNTIME TRACK SNAPSHOT & TERMINAL STATES
# -----------------------------------------------------------------------------
func _test_i_terminal_state_snapshot_integration() -> void:
	print("\n--- TEST I: Runtime Track Snapshot & Terminal State Integration ---")
	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl)
	await process_frame
	for f in 10: await process_frame

	var snapshot: Dictionary = lvl.get_runtime_track_snapshot()
	var has_keys: bool = snapshot.has("circulating_rows") and snapshot.has("feeder_rows") and snapshot.has("oval_freed_capacity") and snapshot.has("loop_distance_unwrapped")
	var circ_rows: Array = snapshot.get("circulating_rows", [])
	var feeder_rows: Array = snapshot.get("feeder_rows", [])

	_assert_test("I", "get_runtime_track_snapshot Accurately Reflects Slot Model",
		has_keys and circ_rows.size() == 36 and feeder_rows.size() == 24,
		"Snapshot returned 36 circulating rows, 24 feeder rows, loop_dist=%.1f" % snapshot.get("loop_distance_unwrapped", 0.0))

	lvl.queue_free()
	await process_frame

# -----------------------------------------------------------------------------
# TEST J: LEVEL 2 SCALE VALIDATION (480 PASSENGERS)
# -----------------------------------------------------------------------------
func _test_j_level_2_scale_validation() -> void:
	print("\n--- TEST J: Level 2 Scale Validation (480 Total Passengers) ---")
	var gc_node = root.get_node_or_null("GameController")
	if gc_node:
		gc_node.current_level_number = 2

	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(lvl)
	await process_frame
	for f in 10: await process_frame

	var total_p: int = lvl.all_passengers.size()
	var circ_p: int = lvl.circulating_ids.size()
	var feeder_p: int = lvl._feeder_passengers.size() + lvl._pending_feeder_passengers.size()

	var dt: float = 1.0 / 60.0
	for f in 120:
		lvl._process(dt)

	var circ_rows: int = lvl._circulating_rows.size()
	var loop_dist: float = lvl._loop_distance_unwrapped

	_assert_test("J", "Level 2 480-Passenger Scalability and Oval Capacity (36 Slots)",
		total_p == 480 and circ_p == 144 and feeder_p == 336 and circ_rows == 36 and loop_dist > 500.0,
		"Total=%d, Oval=%d (36 rows), Feeder=%d, LoopMoved=%.1f px" % [total_p, circ_p, feeder_p, loop_dist])

	lvl.queue_free()
	await process_frame
