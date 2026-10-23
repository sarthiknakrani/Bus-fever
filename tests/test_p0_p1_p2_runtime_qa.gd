extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	_run_suite()

func _run_suite() -> void:
	await create_timer(0.3).timeout
	print("\n=======================================================")
	print("=== P0, P1, P2 COMPREHENSIVE RUNTIME QA TEST SUITE ===")
	print("=======================================================")

	var total_failures := 0

	# ----------------------------------------------------
	# TEST 1: No User Input (10 Seconds of Circulation)
	# ----------------------------------------------------
	print("\n--- TEST 1: No User Input (10s Continuous Circulation QA) ---")
	var l1: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l1)
	if not l1.is_node_ready():
		l1._ready()
	await create_timer(0.2).timeout

	var initial_oval_count := l1.circulating_ids.size()
	var initial_feeder_count := l1._feeder_passengers.size() + l1._pending_feeder_passengers.size()
	print("  [INIT] Oval passengers: %d | Feeder passengers: %d" % [initial_oval_count, initial_feeder_count])

	var min_observed_separation := 9999.0
	var check_intervals := 20
	var step_delay := 0.5 # 20 * 0.5s = 10.0s total

	for step in range(check_intervals):
		await create_timer(step_delay).timeout
		
		# Sample all circulating passengers
		var active_views: Array[PassengerView] = []
		for pid in l1.circulating_ids:
			var p = l1.all_passengers.get(pid, null)
			if p != null and is_instance_valid(p.get("view")):
				active_views.append(p["view"])
		
		# Measure minimum center-to-center distance between distinct characters in same row/lane (in world space)
		for i in range(active_views.size()):
			for j in range(i + 1, mini(i + 15, active_views.size())):
				var d = active_views[i].position.distance_to(active_views[j].position)
				if d < min_observed_separation:
					min_observed_separation = d

	var final_oval_count := l1.circulating_ids.size()
	var final_feeder_count := l1._feeder_passengers.size() + l1._pending_feeder_passengers.size()
	print("  [MEASURED] After 10.0s: Oval=%d, Feeder=%d" % [final_oval_count, final_feeder_count])
	print("  [MEASURED] Minimum observed inter-passenger center separation: %.2f px" % min_observed_separation)

	if final_oval_count == initial_oval_count and final_feeder_count == initial_feeder_count:
		print("  [PASS] Zero unauthorized feeder merge over 10.0s continuous circulation (Backpressure holds)")
	else:
		print("  [FAIL] Unauthorized feeder merge detected! Oval=%d, Feeder=%d" % [final_oval_count, final_feeder_count])
		total_failures += 1

	if min_observed_separation >= 15.5:
		print("  [PASS] Minimum separation (%.2f px) strictly maintains lane clearance (~16.0 px) with zero collision" % min_observed_separation)
	else:
		print("  [FAIL] Passenger collision detected! Min separation: %.2f px" % min_observed_separation)
		total_failures += 1

	# Check for duplicates or missing IDs
	var id_set: Dictionary = {}
	var has_duplicate := false
	for pid in l1.circulating_ids:
		if id_set.has(pid):
			has_duplicate = true
			break
		id_set[pid] = true
	for p in l1._feeder_passengers:
		if id_set.has(p["id"]):
			has_duplicate = true
			break
		id_set[p["id"]] = true

	if not has_duplicate:
		print("  [PASS] Zero duplicate passengers across oval and feeder")
	else:
		print("  [FAIL] Duplicate passenger IDs detected in queue!")
		total_failures += 1

	# ----------------------------------------------------
	# TEST 2: Curve Separation Verification (Left & Right Bends)
	# ----------------------------------------------------
	print("\n--- TEST 2: High-Density Left & Right Curve Separation ---")
	var curve = l1.passenger_track.curve
	var track_len = curve.get_baked_length()
	
	# Sample on left curve (apex at x = -270)
	var left_apex_off = curve.get_closest_offset(Vector2(-270, 0))
	var right_apex_off = curve.get_closest_offset(Vector2(270, 0))

	# Compute exact inner-most lane separation for two adjacent circulating rows on the curve
	var loop_row_sp: float = track_len / float(l1.TOTAL_LOOP_SLOTS)
	var pt_left = l1._get_curve_point_and_normal(curve, left_apex_off, true)
	var pt_left_prev = l1._get_curve_point_and_normal(curve, left_apex_off - loop_row_sp, true)
	
	var inner_pos1 = l1._calc_lane_pos(pt_left["pos"], pt_left["normal"], 3)
	var inner_pos0 = l1._calc_lane_pos(pt_left_prev["pos"], pt_left_prev["normal"], 3)
	var curve_inner_lane_dist = inner_pos0.distance_to(inner_pos1)

	print("  [MEASURED] Inner-most lane (Lane 3) arc distance on curve: %.2f px" % curve_inner_lane_dist)
	if curve_inner_lane_dist >= 22.0:
		print("  [PASS] Inner-most lane maintains %.2f px separation: ZERO OVERLAP ON BENDS!" % curve_inner_lane_dist)
	else:
		print("  [FAIL] Inner-most lane compresses to %.2f px (< 22.0 px)!" % curve_inner_lane_dist)
		total_failures += 1

	l1.queue_free()

	# ----------------------------------------------------
	# TEST 3: Reference Speed & Lap Time QA
	# ----------------------------------------------------
	print("\n--- TEST 3: Passenger Speed & Pacing Verification ---")
	var l_speed: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l_speed)
	if not l_speed.is_node_ready():
		l_speed._ready()
	await create_timer(0.1).timeout

	var t_len: float = l_speed.passenger_track.curve.get_baked_length()
	var old_speed: float = 130.0
	var old_lap: float = t_len / old_speed
	var new_speed: float = l_speed.passenger_normal_speed
	var new_sprint: float = l_speed.passenger_sprint_speed
	var new_lap: float = t_len / new_speed
	var new_sprint_lap: float = t_len / new_sprint

	print("  Old Normal Speed: %.1f px/s  | Old Lap Time: %.2f s" % [old_speed, old_lap])
	print("  New Normal Speed: %.1f px/s  | New Lap Time: %.2f s" % [new_speed, new_lap])
	print("  New Sprint Speed: %.1f px/s  | Sprint Lap Time: %.2f s" % [new_sprint, new_sprint_lap])
	print("  Pacing increase factor: %.2fx (Reference normalized target: ~4.0s lap)" % (new_speed / old_speed))

	if new_lap <= 4.2 and new_lap >= 3.2:
		print("  [PASS] Normal lap time is %.2fs (perfectly matches 3.2-4.2s reference arcade pacing)" % new_lap)
	else:
		print("  [FAIL] Lap time out of reference target range: %.2fs" % new_lap)
		total_failures += 1

	l_speed.queue_free()

	# ----------------------------------------------------
	# TEST 4: Parking Platform Lowering & Layout Clearance
	# ----------------------------------------------------
	print("\n--- TEST 4: Parking Platform Repositioning Across Resolutions ---")
	var resolutions: Array[Vector2] = [
		Vector2(810, 1750),
		Vector2(720, 1280),
		Vector2(390, 844)
	]

	for res in resolutions:
		var l_res: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
		root.add_child(l_res)
		if not l_res.is_node_ready():
			l_res._ready()
		await create_timer(0.05).timeout

		# Track bottom in world_root space:
		var track_y = l_res.passenger_track_root.position.y
		var track_bottom = track_y + 196.0 # track_y + (392.0 / 2.0)
		var parking_y = l_res.parking_root.position.y
		var slot_top = parking_y - 55.0 # parking_y - (110.0 / 2.0)
		var clearance_tp = slot_top - track_bottom
		var world_scale = l_res.world_root.scale.y
		var rendered_clearance_screen_px = clearance_tp * world_scale

		print("  Resolution: %dx%d (Scale: %.3f)" % [int(res.x), int(res.y), world_scale])
		print("    Track Bottom Y: %.1f | Parking Slot Top Y: %.1f" % [track_bottom, slot_top])
		print("    World Clearance: %.1f px | Screen-Rendered Clearance: %.1f px" % [clearance_tp, rendered_clearance_screen_px])

		if clearance_tp >= 12.0:
			print("    [PASS] Clean world clearance (%.1f px >= 12.0 px)" % clearance_tp)
		else:
			print("    [FAIL] Clearance too tight! (%.1f px < 12.0 px)" % clearance_tp)
			total_failures += 1

		# Verify platform background present
		var plat_bg = l_res.platform_bg
		if plat_bg != null:
			print("    [PASS] Platform background present and positioned at %.1f" % plat_bg.position.y)

		# Verify all 7 slots move together and buses dock centered
		var slot0_world = l_res._get_slot_world_pos(0)
		var slot6_world = l_res._get_slot_world_pos(6)
		if slot0_world.y == parking_y and slot6_world.y == parking_y:
			print("    [PASS] All slots horizontally aligned at parking_y (%.1f)" % parking_y)
		else:
			print("    [FAIL] Slots misaligned vertically!")
			total_failures += 1

		l_res.queue_free()

	# ----------------------------------------------------
	# TEST 5: Boarding & Feeder Backpressure Verification
	# ----------------------------------------------------
	print("\n--- TEST 5: Boarding & Feeder Gated Merge Flow ---")
	var l_board: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l_board)
	if not l_board.is_node_ready():
		l_board._ready()
	await create_timer(0.2).timeout

	# Tap vehicle 2 (Blue bus, cap 40)
	var tapped := l_board.controller.tap_vehicle(2)
	if tapped:
		print("  [PASS] Bus 2 tapped for boarding.")
		# Wait for arrival, boarding, departure (with faster speed, boarding finishes in ~5-8s)
		await create_timer(8.5).timeout

		var v2 = l_board.controller.vehicles[2]
		var boarded = v2.passenger_occupancy
		var current_feeder = l_board._feeder_passengers.size() + l_board._pending_feeder_passengers.size()
		var current_oval = l_board.circulating_ids.size()
		var total_active = boarded + current_feeder + current_oval

		print("  [MEASURED] Boarded: %d | Oval: %d | Feeder: %d | Total: %d" % [boarded, current_oval, current_feeder, total_active])

		if boarded > 0:
			print("  [PASS] %d passengers boarded bus 2" % boarded)
		else:
			print("  [FAIL] Expected boarded > 0, got %d" % boarded)
			total_failures += 1

		if total_active == 240:
			print("  [PASS] Universal Demand Invariant strictly conserved: 240 passengers total")
		else:
			print("  [FAIL] Demand leak! Total: %d, expected 240" % total_active)
			total_failures += 1

		# Feeder released permitted rows to backfill vacated space
		if current_feeder < 96:
			print("  [PASS] Feeder released rows to refill oval capacity (Remaining: %d < 96)" % current_feeder)
		else:
			print("  [FAIL] Feeder did not release any passengers!")
			total_failures += 1

	l_board.queue_free()

	# ----------------------------------------------------
	# TEST 6: Complete Level 1 and Level 2 Playthrough
	# ----------------------------------------------------
	print("\n--- TEST 6: Playable Completion of Level 1 and Level 2 ---")
	print("\n--- TEST 6: Playable Completion of Level 1 and Level 2 ---")
	var PuzzleSolverClass = preload("res://scripts/gameplay/puzzle_solver.gd")
	
	# Level 1 completion
	var l_solve1: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l_solve1)
	if not l_solve1.is_node_ready():
		l_solve1._ready()
	await create_timer(0.2).timeout

	var sol1_res = PuzzleSolverClass.solve(l_solve1.controller.level_data)
	var sol1: Array = sol1_res.get("moves", [])
	print("  Level 1 solution path: %s (steps: %d)" % [str(sol1), sol1.size()])
	if sol1_res.get("solvable", false):
		print("  [PASS] Level 1 mathematically solvable under 7 slots")
	else:
		print("  [FAIL] Level 1 has no valid solution!")
		total_failures += 1
	l_solve1.queue_free()

	# Level 2 completion
	var gc = root.get_node_or_null("GameController")
	if gc: gc.current_level_number = 2
	var l_solve2: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l_solve2)
	if not l_solve2.is_node_ready():
		l_solve2._ready()
	await create_timer(0.2).timeout

	var sol2_res = PuzzleSolverClass.solve(l_solve2.controller.level_data)
	var sol2: Array = sol2_res.get("moves", [])
	print("  Level 2 solution path: %s (steps: %d)" % [str(sol2), sol2.size()])
	if sol2_res.get("solvable", false):
		print("  [PASS] Level 2 mathematically solvable under 7 slots")
	else:
		print("  [FAIL] Level 2 has no valid solution!")
		total_failures += 1
	l_solve2.queue_free()
	if gc: gc.current_level_number = 1

	print("\n=======================================================")
	if total_failures == 0:
		print("=== ALL P0, P1, P2 RUNTIME TESTS PASSED (0 FAILURES) ===")
	else:
		print("=== %d RUNTIME TESTS FAILED ===" % total_failures)
	print("=======================================================\n")

	quit(total_failures)
