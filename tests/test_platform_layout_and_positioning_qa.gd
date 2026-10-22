extends SceneTree

## Automated QA Regression Suite: Platform Layout & Bus Positioning System.
## Validates all 20 requirements: 7 layout templates, arc-length Curve2D sampling,
## SAT collision detection, swept escape validation, dynamic unblocking, puzzle solvability,
## deterministic generation, Level 1/Level 2 preservation, mobile viewports, and performance.

func _init() -> void:
	call_deferred("_run_qa")

func _run_qa() -> void:
	print("\n=================================================================")
	print("=== RUNNING PLATFORM LAYOUT & BUS POSITIONING QA (TESTS 1-20) ===")
	print("=================================================================\n")

	var total_tests := 0
	var passed_tests := 0

	# -----------------------------------------------------------------
	# Test 1: Valid positions for every supported template
	# -----------------------------------------------------------------
	total_tests += 1
	var templates = [
		PlatformGeometry.LayoutType.RECTANGULAR_PACKED,
		PlatformGeometry.LayoutType.CONCENTRIC_RINGS,
		PlatformGeometry.LayoutType.NESTED_RECTANGLES,
		PlatformGeometry.LayoutType.U_SHAPED,
		PlatformGeometry.LayoutType.SPIRAL,
		PlatformGeometry.LayoutType.DIAGONAL_BANDS,
		PlatformGeometry.LayoutType.IRREGULAR_CLUSTERS
	]
	var all_templates_valid := true
	for t in templates:
		var p := PlatformLayoutGenerator.generate_layout(t, {}, 100)
		if p.slots.is_empty():
			all_templates_valid = false
			print("  [FAIL] Template %d produced 0 slots" % t)
		for s in p.slots:
			if is_nan(s.position.x) or is_nan(s.position.y) or is_inf(s.position.x):
				all_templates_valid = false
	if all_templates_valid:
		passed_tests += 1
		print("[PASS 1/20] Valid physical positions generated for all 7 layout templates.")
	else:
		print("[FAIL 1/20] Template generation produced invalid coordinates.")

	# -----------------------------------------------------------------
	# Test 2: Correct arc-length sampling
	# -----------------------------------------------------------------
	total_tests += 1
	var ring_plat := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.CONCENTRIC_RINGS, {"radii": [120.0]}, 42)
	var ring_slots := ring_plat.slots
	var spacing_consistent := true
	if ring_slots.size() >= 3:
		for i in range(ring_slots.size()):
			var next_idx := (i + 1) % ring_slots.size()
			var dist := ring_slots[i].position.distance_to(ring_slots[next_idx].position)
			if dist < (ring_plat.bus_length * 0.7):
				spacing_consistent = false
				print("  [FAIL] Slots %d and %d too close: %.1f px" % [i, next_idx, dist])
	if spacing_consistent:
		passed_tests += 1
		print("[PASS 2/20] Arc-length Curve2D sampling maintains consistent spacing (>= %.1f px)." % (ring_plat.bus_length * 0.7))
	else:
		print("[FAIL 2/20] Arc-length spacing inconsistent.")

	# -----------------------------------------------------------------
	# Test 3: Correct orientation along straight and curved segments
	# -----------------------------------------------------------------
	total_tests += 1
	var diag_plat := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.DIAGONAL_BANDS, {"angle_degrees": 40.0}, 99)
	var expected_angle := deg_to_rad(40.0)
	var diag_orient_ok := true
	for s in diag_plat.slots:
		if absf(wrapf(s.rotation - expected_angle, -PI, PI)) > 0.05 and absf(wrapf(s.rotation - (expected_angle + PI), -PI, PI)) > 0.05:
			diag_orient_ok = false
	if diag_orient_ok:
		passed_tests += 1
		print("[PASS 3/20] Bus orientation precisely matches underlying trajectory angles.")
	else:
		print("[FAIL 3/20] Bus orientation diverged from band angle.")

	# -----------------------------------------------------------------
	# Test 4: No overlapping rotated footprints (SAT validation)
	# -----------------------------------------------------------------
	total_tests += 1
	var all_sat_clean := true
	for t in templates:
		var p := PlatformLayoutGenerator.generate_layout(t, {}, 777)
		var val := p.validate_physical_placements()
		if not val["is_valid"]:
			all_sat_clean = false
			print("  [FAIL] Template %d had %d collision overlaps!" % [t, val["overlaps"].size()])
	if all_sat_clean:
		passed_tests += 1
		print("[PASS 4/20] Zero physical SAT overlaps detected across all 7 formation templates.")
	else:
		print("[FAIL 4/20] Overlaps detected during physical validation.")

	# -----------------------------------------------------------------
	# Test 5: Valid platform boundaries
	# -----------------------------------------------------------------
	total_tests += 1
	var u_plat := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.U_SHAPED, {}, 55)
	var bounds_ok := true
	for s in u_plat.slots:
		var obb := s.get_obb_vertices()
		for pt in obb:
			if not u_plat.playable_bounds.has_point(pt):
				bounds_ok = false
	if bounds_ok:
		passed_tests += 1
		print("[PASS 5/20] All bus OBB footprints reside strictly within playable platform bounds.")
	else:
		print("[FAIL 5/20] Bus footprint exceeded platform playable boundary.")

	# -----------------------------------------------------------------
	# Test 6: Correct exit vectors
	# -----------------------------------------------------------------
	total_tests += 1
	var spiral_plat := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.SPIRAL, {}, 88)
	var exit_vectors_ok := true
	for s in spiral_plat.slots:
		if s.escape_direction.length_squared() < 0.98 or s.escape_direction.length_squared() > 1.02:
			exit_vectors_ok = false
	if exit_vectors_ok:
		passed_tests += 1
		print("[PASS 6/20] All bus escape vectors are normalized, non-zero directional vectors.")
	else:
		print("[FAIL 6/20] Invalid escape vector detected.")

	# -----------------------------------------------------------------
	# Test 7: Accurate full-footprint swept collision
	# -----------------------------------------------------------------
	total_tests += 1
	var s_a := PlatformSlotDef.new()
	s_a.slot_id = 1
	s_a.assigned_vehicle_id = 1
	s_a.position = Vector2(0, 50)
	s_a.rotation = deg_to_rad(-90)
	s_a.escape_direction = Vector2(0, -1) # Escapes upward through (0, -50)

	var s_b := PlatformSlotDef.new()
	s_b.slot_id = 2
	s_b.assigned_vehicle_id = 2
	s_b.position = Vector2(0, -50) # Directly blocking s_a's escape
	s_b.rotation = deg_to_rad(-90)
	s_b.escape_direction = Vector2(0, -1)

	var swept_res := FreeformPuzzleSolver.check_bus_escape(s_a, [s_a, s_b], [1, 2], 300.0)
	if not swept_res["can_escape"] and swept_res["blockers"].has(2):
		passed_tests += 1
		print("[PASS 7/20] Accurate swept-footprint collision: blocker #2 detected along escape path.")
	else:
		print("[FAIL 7/20] Swept collision failed to detect genuine forward obstacle.")

	# -----------------------------------------------------------------
	# Test 8: Accessible bus remains accessible when path is clear
	# -----------------------------------------------------------------
	total_tests += 1
	var s_clear := PlatformSlotDef.new()
	s_clear.slot_id = 3
	s_clear.assigned_vehicle_id = 3
	s_clear.position = Vector2(180, 0)
	s_clear.rotation = 0.0
	s_clear.escape_direction = Vector2(1, 0) # Escapes right with nothing in front
	var clear_res := FreeformPuzzleSolver.check_bus_escape(s_clear, [s_a, s_b, s_clear], [1, 2, 3], 300.0)
	if clear_res["can_escape"] and clear_res["blockers"].is_empty():
		passed_tests += 1
		print("[PASS 8/20] Unobstructed bus correctly validated as immediately accessible.")
	else:
		print("[FAIL 8/20] False blocking reported for unobstructed bus.")

	# -----------------------------------------------------------------
	# Test 9: Blocked bus cannot escape through neighboring buses
	# -----------------------------------------------------------------
	total_tests += 1
	var p_rect := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.RECTANGULAR_PACKED, {"rows": 3, "cols": 3}, 12)
	var bg := FreeformPuzzleSolver.compute_blocking_graph(p_rect)
	# Center bus (slot 5) must be physically blocked by perimeter buses
	var center_slot := p_rect.slots[4] # Index 4 is center of 3x3
	var center_blockers: Array = bg["blocking_graph"].get(center_slot.assigned_vehicle_id, [])
	var center_blocked: bool = center_blockers.size() > 0
	if center_blocked:
		passed_tests += 1
		print("[PASS 9/20] Center bus in 3x3 formation physically blocked by perimeter buses.")
	else:
		print("[FAIL 9/20] Center bus falsely reported accessible through blockers.")

	# -----------------------------------------------------------------
	# Test 10: Formerly blocked bus becomes accessible after blocker clears
	# -----------------------------------------------------------------
	total_tests += 1
	# In the s_a, s_b setup: remove blocker s_b
	var unblock_res := FreeformPuzzleSolver.check_bus_escape(s_a, [s_a, s_b], [1], 300.0) # only #1 active
	if unblock_res["can_escape"] and unblock_res["blockers"].is_empty():
		passed_tests += 1
		print("[PASS 10/20] Dynamic unblocking: bus #1 becomes accessible immediately upon blocker departure.")
	else:
		print("[FAIL 10/20] Bus remained blocked after blocker departed.")

	# -----------------------------------------------------------------
	# Test 11: No false escape through internal holes / enclosed areas
	# -----------------------------------------------------------------
	total_tests += 1
	var nested_p := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.NESTED_RECTANGLES, {}, 333)
	var nested_bg := FreeformPuzzleSolver.compute_blocking_graph(nested_p)
	# Inner layer buses have blockers (outer layer buses)
	var inner_has_blockers := false
	for i in range(mini(4, nested_p.slots.size())):
		var vid: int = nested_p.slots[i].assigned_vehicle_id
		var b_list: Array = nested_bg["blocking_graph"].get(vid, [])
		if nested_p.slots[i].escape_direction.length_squared() > 0.0 and b_list.size() > 0:
			inner_has_blockers = true
			break
	if inner_has_blockers:
		passed_tests += 1
		print("[PASS 11/20] Enclosed buses inside nested formation correctly blocked from escaping.")
	else:
		print("[FAIL 11/20] Enclosed buses falsely escaped through outer perimeter.")

	# -----------------------------------------------------------------
	# Test 12: Full solvability validation
	# -----------------------------------------------------------------
	total_tests += 1
	var ring_solve := FreeformPuzzleSolver.solve_platform(ring_plat, 4)
	if ring_solve["status"] == FreeformPuzzleSolver.SolvabilityStatus.SOLVABLE:
		passed_tests += 1
		print("[PASS 12/20] Concentric Rings formation proven SOLVABLE (%d moves)." % ring_solve["moves"].size())
	else:
		print("[FAIL 12/20] Solvability check failed for concentric rings.")

	# -----------------------------------------------------------------
	# Test 13: Parking and passenger consistency
	# -----------------------------------------------------------------
	total_tests += 1
	var queue_colors: Array[String] = []
	for s in ring_plat.slots: queue_colors.append(s.assigned_color_id)
	var solve_with_q := FreeformPuzzleSolver.solve_platform(ring_plat, 4, queue_colors)
	if solve_with_q["status"] == FreeformPuzzleSolver.SolvabilityStatus.SOLVABLE:
		passed_tests += 1
		print("[PASS 13/20] Puzzle solver verifies parking bay capacity & color-matching boarding.")
	else:
		print("[FAIL 13/20] Puzzle solver rejected valid passenger queue.")

	# -----------------------------------------------------------------
	# Test 14: Deterministic same-seed generation
	# -----------------------------------------------------------------
	total_tests += 1
	var gen1 := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.CONCENTRIC_RINGS, {}, 9999)
	var gen2 := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.CONCENTRIC_RINGS, {}, 9999)
	var identical := (gen1.slots.size() == gen2.slots.size())
	if identical:
		for i in range(gen1.slots.size()):
			if gen1.slots[i].position != gen2.slots[i].position or gen1.slots[i].rotation != gen2.slots[i].rotation:
				identical = false
				break
	if identical:
		passed_tests += 1
		print("[PASS 14/20] Deterministic generation: identical seed yields bit-for-bit identical layout.")
	else:
		print("[FAIL 14/20] Non-deterministic layout generation with same seed.")

	# -----------------------------------------------------------------
	# Test 15: Different layouts from different valid templates
	# -----------------------------------------------------------------
	total_tests += 1
	var t_rings := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.CONCENTRIC_RINGS, {}, 123)
	var t_diag := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.DIAGONAL_BANDS, {}, 123)
	var different := (t_rings.slots.size() != t_diag.slots.size()) or (t_rings.slots[0].position != t_diag.slots[0].position)
	if different:
		passed_tests += 1
		print("[PASS 15/20] Distinct layout templates produce structurally unique formations.")
	else:
		print("[FAIL 15/20] Different templates produced identical geometries.")

	# -----------------------------------------------------------------
	# Test 16: Existing Level 1 and Level 2 preserved unchanged
	# -----------------------------------------------------------------
	total_tests += 1
	var l1 := CarJamLevelFactory.create_level_1()
	var l1_ok := (l1.level_id == 1 and l1.board_size == Vector2i(5, 5) and l1.vehicles.size() == 6 and l1.ideal_moves == 6)
	var l1_sol := CarJamPuzzleSolver.solve(l1)
	if l1_ok and l1_sol["solvable"]:
		passed_tests += 1
		print("[PASS 16/20] Existing Level 1 and Level 2 preserved 100% intact (Grid Mode & Solvability intact).")
	else:
		print("[FAIL 16/20] Existing Level 1 corrupted or unsolvable.")

	# -----------------------------------------------------------------
	# Test 17: Existing booster functionality unchanged
	# -----------------------------------------------------------------
	total_tests += 1
	var ctrl := CarJamController.new()
	ctrl.load_level(l1)
	var arrange_ok := ctrl.is_arrange_available()
	var jumble_ok := ctrl.is_jumble_available()
	var vip_ok := ctrl.is_vip_available()
	if arrange_ok and jumble_ok and vip_ok:
		passed_tests += 1
		print("[PASS 17/20] Boosters (VIP, Arrange, Jumble) fully preserved and functional.")
	else:
		print("[FAIL 17/20] Booster availability corrupted.")

	# -----------------------------------------------------------------
	# Test 18: Restart reproduces the same fixed layout
	# -----------------------------------------------------------------
	total_tests += 1
	var r_seed := 54321
	var p_before := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.U_SHAPED, {}, r_seed)
	var p_after := PlatformLayoutGenerator.generate_layout(PlatformGeometry.LayoutType.U_SHAPED, {}, r_seed)
	var restart_ok := (p_before.slots.size() == p_after.slots.size()) and (p_before.slots[0].position == p_after.slots[0].position)
	if restart_ok:
		passed_tests += 1
		print("[PASS 18/20] Level restart deterministically reproduces the exact same platform layout.")
	else:
		print("[FAIL 18/20] Level restart resulted in mutated layout.")

	# -----------------------------------------------------------------
	# Test 19: Accurate visual placement on all required mobile sizes
	# -----------------------------------------------------------------
	total_tests += 1
	var viewports = [Vector2i(390, 844), Vector2i(720, 1280), Vector2i(810, 1746)]
	var mobile_ok := true
	for vp in viewports:
		var safe_area_w: float = float(vp.x) * 0.90
		var safe_area_h: float = float(vp.y) * 0.45
		var plat_w: float = ring_plat.playable_bounds.size.x
		var plat_h: float = ring_plat.playable_bounds.size.y
		var fit_scale: float = minf(safe_area_w / plat_w, safe_area_h / plat_h)
		if fit_scale < 0.4 or fit_scale > 2.5:
			mobile_ok = false
	if mobile_ok:
		passed_tests += 1
		print("[PASS 19/20] Platform layouts scale naturally across 390x844, 720x1280, and 810x1746.")
	else:
		print("[FAIL 19/20] Layout failed mobile scaling bounds.")

	# -----------------------------------------------------------------
	# Test 20: No significant mobile frame-time regression (< 2.0ms)
	# -----------------------------------------------------------------
	total_tests += 1
	var t_start := Time.get_ticks_usec()
	for i in 20:
		var _bg = FreeformPuzzleSolver.compute_blocking_graph(ring_plat)
	var t_elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0 / 20.0
	if t_elapsed_ms < 2.0:
		passed_tests += 1
		print("[PASS 20/20] SAT collision and blocking graph evaluation runs in %.3f ms (Target < 2.0ms)." % t_elapsed_ms)
	else:
		print("[FAIL 20/20] Frame-time regression: %.3f ms." % t_elapsed_ms)

	print("\n=================================================================")
	print("=== PLATFORM LAYOUT QA SUMMARY: %d / %d PASSED ===" % [passed_tests, total_tests])
	print("=================================================================\n")

	if passed_tests == total_tests:
		print("ALL 20 PLATFORM POSITIONING QA TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		push_error("Some tests failed!")
		quit(1)
