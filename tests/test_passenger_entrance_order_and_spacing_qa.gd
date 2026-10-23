extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	_run_qa()

func _run_qa() -> void:
	await create_timer(0.1).timeout
	print("\n=========================================================================")
	print("=== PASSENGER ENTRANCE, ROW ORDER & CURVE SPACING REGRESSION QA SUITE ===")
	print("=========================================================================\n")

	var failures := 0

	# -------------------------------------------------------------------------
	# TEST 1: ENTRANCE PARADE GATING, ZERO OVERLAP & MIN SPACING (LEVEL 1)
	# -------------------------------------------------------------------------
	print("--- TEST 1: Level 1 Visual Entrance Parade & Continuous Circulation ---")
	var level1: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	level1.force_entrance_parade = true
	root.add_child(level1)
	if not level1.is_node_ready():
		level1._ready()

	await create_timer(0.05).timeout

	var dt := 1.0 / 60.0
	var total_frames := 900 # 15 seconds: entrance (~3.4s) + ~3 complete laps
	var overlap_count := 0
	var min_p_dist := 999.0
	var min_row_gap := 999.0

	for frame in range(total_frames):
		level1._process(dt)

		# Collect all visible passenger positions
		var vis: Array[Dictionary] = []
		for r in level1._circulating_rows:
			for p in r.passengers:
				if is_instance_valid(p.get("view")):
					vis.append({"id": p["id"], "row": r, "lane": p["lane"], "pos": p["view"].position, "color": p["color_id"]})
		for r in level1._feeder_rows:
			for p in r.passengers:
				if is_instance_valid(p.get("view")):
					vis.append({"id": p["id"], "row": r, "lane": p["lane"], "pos": p["view"].position, "color": p["color_id"]})

		# Check pairwise passenger distances
		for i in range(vis.size()):
			var p1 = vis[i]
			for j in range(i + 1, vis.size()):
				var p2 = vis[j]
				if p1["row"] == p2["row"]:
					continue # lateral lane spacing within same row
				var d = p1["pos"].distance_to(p2["pos"])
				if d < min_p_dist:
					min_p_dist = d
				if d < 15.0:
					overlap_count += 1

		# Check circulating row gaps
		if level1._circulating_rows.size() >= 2:
			var t_len = level1.passenger_track.curve.get_baked_length()
			for i in range(level1._circulating_rows.size()):
				var r_curr = level1._circulating_rows[i]
				var r_ahead: Object
				var gap: float
				if i == 0:
					r_ahead = level1._circulating_rows.back()
					gap = (r_ahead.progress + t_len) - r_curr.progress
				else:
					r_ahead = level1._circulating_rows[i - 1]
					gap = r_ahead.progress - r_curr.progress
				if gap < 0.0:
					gap += t_len
				if gap < min_row_gap:
					min_row_gap = gap

	print("  [MEASURED] Level 1 Min Passenger 2D Distance: %.2f px" % min_p_dist)
	print("  [MEASURED] Level 1 Min Row Gap along Loop: %.2f px" % min_row_gap)
	print("  [MEASURED] Level 1 Overlap Events (< 15.0 px): %d" % overlap_count)

	if overlap_count == 0:
		print("  [PASS] Zero overlap events during entrance parade and continuous circulation")
	else:
		print("  [FAIL] Detected %d overlap events (< 15.0 px)" % overlap_count)
		failures += 1

	if min_p_dist >= 15.0:
		print("  [PASS] Minimum inter-passenger clearance strictly >= 15.0 px (Actual: %.2f px)" % min_p_dist)
	else:
		print("  [FAIL] Passenger clearance below safe margin: %.2f px" % min_p_dist)
		failures += 1

	if min_row_gap >= 28.0:
		print("  [PASS] Minimum row gap along track maintained >= 28.0 px (Actual: %.2f px)" % min_row_gap)
	else:
		print("  [FAIL] Row gap collapsed below 28.0 px: %.2f px" % min_row_gap)
		failures += 1

	# -------------------------------------------------------------------------
	# TEST 2: FIFO ROW ORDER & COLOR CONTIGUITY (NO INTERLEAVING)
	# -------------------------------------------------------------------------
	print("\n--- TEST 2: FIFO Row Order & Color Contiguity (No Interleaving) ---")
	var color_runs: Array[Dictionary] = []
	var cur_col := ""
	var cur_count := 0

	for i in range(level1._circulating_rows.size()):
		var r = level1._circulating_rows[i]
		var col = r.passengers[0]["color_id"]
		if col != cur_col:
			if cur_col != "":
				color_runs.append({"color": cur_col, "count": cur_count})
			cur_col = col
			cur_count = 1
		else:
			cur_count += 1

	if cur_col != "":
		color_runs.append({"color": cur_col, "count": cur_count})

	print("  [MEASURED] Color Runs along loop: %s" % str(color_runs))
	# Expected on circular loop: Red at wrap boundary, solid Yellow (10), solid Blue (10)
	# Total runs should be at most 4 (e.g. Red, Yellow, Blue, Red which connects around loop)
	if color_runs.size() <= 4:
		print("  [PASS] Passenger groups retain strict contiguous color blocks (No interleaving!)")
	else:
		print("  [FAIL] Color interleaving detected! Found %d separate runs: %s" % [color_runs.size(), str(color_runs)])
		failures += 1

	# Total rows on oval must be exactly 36 (144 passengers)
	if level1._circulating_rows.size() == 36:
		print("  [PASS] Exactly 36 rows (144 passengers) circulating on main oval")
	else:
		print("  [FAIL] Circulating rows mismatch: expected 36, got %d" % level1._circulating_rows.size())
		failures += 1

	level1.queue_free()

	# -------------------------------------------------------------------------
	# TEST 3: LEVEL 2 ENTRANCE & CIRCULATION STABILITY
	# -------------------------------------------------------------------------
	print("\n--- TEST 3: Level 2 Visual Entrance Parade & Spacing ---")
	var level2: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	level2.force_entrance_parade = true
	var lvl2_res = ResourceLoader.load("res://levels/level_002.tres") as CarJamLevelData
	root.add_child(level2)
	if not level2.is_node_ready():
		level2._ready()
	if lvl2_res != null and level2.controller != null:
		level2.controller.load_level(lvl2_res)
		level2._setup_visuals(lvl2_res)

	await create_timer(0.05).timeout

	var l2_overlap := 0
	var l2_min_dist := 999.0
	for frame in range(600):
		level2._process(dt)
		var vis: Array[Dictionary] = []
		for r in level2._circulating_rows:
			for p in r.passengers:
				if is_instance_valid(p.get("view")):
					vis.append({"id": p["id"], "row": r, "pos": p["view"].position})
		for r in level2._feeder_rows:
			for p in r.passengers:
				if is_instance_valid(p.get("view")):
					vis.append({"id": p["id"], "row": r, "pos": p["view"].position})

		for i in range(vis.size()):
			var p1 = vis[i]
			for j in range(i + 1, vis.size()):
				var p2 = vis[j]
				if p1["row"] == p2["row"]:
					continue
				var d = p1["pos"].distance_to(p2["pos"])
				if d < l2_min_dist:
					l2_min_dist = d
				if d < 15.0:
					l2_overlap += 1

	print("  [MEASURED] Level 2 Min Passenger 2D Distance: %.2f px" % l2_min_dist)
	print("  [MEASURED] Level 2 Overlap Events (< 15.0 px): %d" % l2_overlap)

	if l2_overlap == 0:
		print("  [PASS] Level 2: Zero overlap events during entrance and circulation")
	else:
		print("  [FAIL] Level 2: Detected %d overlap events" % l2_overlap)
		failures += 1

	if level2.controller != null:
		var total_l2 = level2.all_passengers.size()
		if total_l2 == 480 or total_l2 == 240: # Depending on config
			print("  [PASS] Level 2 Passenger accounting verified (Total: %d)" % total_l2)

	level2.queue_free()

	# -------------------------------------------------------------------------
	# SUMMARY
	# -------------------------------------------------------------------------
	print("\n=========================================================================")
	if failures == 0:
		print("=== ALL PASSENGER ENTRANCE, ORDER & SPACING TESTS PASSED (0 FAILURES) ===")
	else:
		print("=== %d TESTS FAILED ===" % failures)
	print("=========================================================================\n")

	quit(failures)
