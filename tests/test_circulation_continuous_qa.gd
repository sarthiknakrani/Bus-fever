extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	_run_suite()

func _run_suite() -> void:
	await process_frame
	print("\n=========================================================================")
	print("=== P0 MANDATORY CONTINUOUS-CIRCULATION REGRESSION TEST SUITE ===")
	print("=========================================================================\n")

	var failures := 0

	var gc_node = root.get_node_or_null("GameController")
	if gc_node == null:
		gc_node = load("res://scripts/autoload/game_controller.gd").new()
		gc_node.name = "GameController"
		root.add_child(gc_node)
	gc_node.current_level_number = 1

	# -------------------------------------------------------------------------
	# TEST A: FULL OVAL, NO BUS TAPPED — AT LEAST TWO COMPLETE LAPS
	# -------------------------------------------------------------------------
	print("--- TEST A: Full Oval Circulation Liveness (>= 2 Laps, Zero Freeze) ---")
	var l_a: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	l_a.force_entrance_parade = true
	root.add_child(l_a)
	await process_frame
	for f in 5: await process_frame

	var track_len: float = l_a.passenger_track.curve.get_baked_length() # ~1142.64 px

	# 1. Advance through entrance parade until all 36 rows are circulating
	var max_parade_frames := 500
	var parade_done := false
	for f in max_parade_frames:
		await process_frame
		if not l_a._entrance_active and l_a._circulating_rows.size() >= 36:
			parade_done = true
			break

	if not parade_done:
		print("  [FAIL] Test A: Entrance parade did not finish within %d frames" % max_parade_frames)
		failures += 1
	else:
		print("  [PASS] Entrance parade completed. 36 rows now circulating.")

		# 2. Pick 10 sample passenger IDs across front, mid, and rear rows
		var tracked_passengers: Dictionary = {}
		var stride: int = maxi(1, l_a._circulating_rows.size() / 10)
		for r_idx in range(0, l_a._circulating_rows.size(), stride):
			var r = l_a._circulating_rows[r_idx]
			if not r.passengers.is_empty():
				var pid: int = r.passengers[0]["id"]
				tracked_passengers[pid] = {
					"last_prog": r.progress,
					"cum_dist": 0.0,
					"min_frame_dp": 999.0,
					"stall_frames": 0
				}

		# 3. Simulate until all tracked rows achieve at least 2 complete laps (req_dist)
		var req_dist: float = track_len * 2.0
		var min_cum_dist := 0.0
		var max_stall_frames := 0
		var lap_frames := 0

		while min_cum_dist < req_dist and lap_frames < 1200:
			lap_frames += 1
			await process_frame

			for r in l_a._circulating_rows:
				for p in r.passengers:
					var pid: int = p["id"]
					if tracked_passengers.has(pid):
						var info = tracked_passengers[pid]
						var dp = r.progress - info["last_prog"]
						if dp < 0.0: dp += track_len # Handle wrap point
						info["cum_dist"] += dp
						info["min_frame_dp"] = minf(info["min_frame_dp"], dp)
						if dp < 1.0: # Less than 1px in a frame means stall (< 60 px/s)
							info["stall_frames"] += 1
						info["last_prog"] = r.progress

			min_cum_dist = 999999.0
			for pid in tracked_passengers:
				min_cum_dist = minf(min_cum_dist, tracked_passengers[pid]["cum_dist"])

		for pid in tracked_passengers:
			var info = tracked_passengers[pid]
			max_stall_frames = maxi(max_stall_frames, info["stall_frames"])
			var laps = info["cum_dist"] / track_len
			print("    Tracked Passenger %d: CumDist=%.2f px (%.2f Laps) | Stalls=%d" % [
				pid, info["cum_dist"], laps, info["stall_frames"]
			])

		if min_cum_dist >= req_dist and max_stall_frames == 0:
			print("  [PASS] Test A: Continuous circulation verified! Min distance: %.2f px (>= %.2f px, > 2 Laps) in %d frames with 0 stalls" % [
				min_cum_dist, req_dist, lap_frames
			])
		else:
			print("  [FAIL] Test A: Insufficient movement or stalls! MinCumDist=%.2f (req %.2f), MaxStalls=%d" % [
				min_cum_dist, req_dist, max_stall_frames
			])
			failures += 1

	l_a.queue_free()
	await process_frame
	for f in 5: await process_frame

	# -------------------------------------------------------------------------
	# TEST B: FULL OVAL UNDER DENSE SPACING (36 ROWS PACKED AT MIN GAP)
	# -------------------------------------------------------------------------
	print("\n--- TEST B: Full Oval Under Dense Spacing (36 Rows at MIN_ROW_GAP) ---")
	var l_b: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l_b)
	await process_frame
	for f in 5: await process_frame

	# Tightly pack all 36 rows at exactly MIN_ROW_GAP (28.5 px) spacing
	var num_rows = l_b._circulating_rows.size()
	for i in range(num_rows):
		l_b._circulating_rows[i].progress = fposmod(float(track_len - 10.0) - float(i) * 28.5, track_len)

	# Simulate 180 frames (3.0 seconds)
	var dense_cum_dist: float = 0.0
	var prev_lead_prog: float = l_b._circulating_rows[0].progress
	var min_observed_gap: float = 999.0

	for f in 180:
		await process_frame
		var lead_p = l_b._circulating_rows[0].progress
		var dp = lead_p - prev_lead_prog
		if dp < 0.0: dp += track_len
		dense_cum_dist += dp
		prev_lead_prog = lead_p

		for i in range(num_rows):
			var cur_p = l_b._circulating_rows[i].progress
			var ahead_p = l_b._circulating_rows[(i - 1 + num_rows) % num_rows].progress
			var g = ahead_p - cur_p
			if g < 0.0: g += track_len
			min_observed_gap = minf(min_observed_gap, g)

	var dense_speed: float = dense_cum_dist / 3.0
	print("  [MEASURED] Dense Oval 36-Row Speed: %.2f px/s | Min Gap: %.2f px" % [dense_speed, min_observed_gap])
	if dense_speed >= 300.0 and min_observed_gap >= 28.0:
		print("  [PASS] Test B: Dense oval circulates at full speed (%.2f px/s) maintaining safe gap (%.2f px) without freeze!" % [
			dense_speed, min_observed_gap
		])
	else:
		print("  [FAIL] Test B: Dense oval slowed or froze! Speed=%.2f px/s, MinGap=%.2f px" % [dense_speed, min_observed_gap])
		failures += 1

	l_b.queue_free()
	await process_frame
	for f in 5: await process_frame

	# -------------------------------------------------------------------------
	# TEST C: FEEDER WAITING DOES NOT STOP OVAL
	# -------------------------------------------------------------------------
	print("\n--- TEST C: Feeder Waiting While Oval Circulates Continuously ---")
	var l_c: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l_c)
	await process_frame
	for f in 5: await process_frame

	l_c._oval_freed_capacity = 0
	var initial_feeder_count: int = l_c._feeder_rows.size()
	var feeder_lead_pos: float = l_c._feeder_rows[0].progress if not l_c._feeder_rows.is_empty() else 0.0

	var oval_dist: float = 0.0
	var prev_p: float = l_c._circulating_rows[0].progress
	var feeder_moved: float = 0.0

	for f in 120: # 2 seconds
		await process_frame
		var cur_p = l_c._circulating_rows[0].progress
		var dp = cur_p - prev_p
		if dp < 0.0: dp += track_len
		oval_dist += dp
		prev_p = cur_p

	var final_feeder_pos: float = l_c._feeder_rows[0].progress if not l_c._feeder_rows.is_empty() else 0.0
	feeder_moved = absf(final_feeder_pos - feeder_lead_pos)

	print("  [MEASURED] Feeder Lead Row Movement: %.2f px (Waiting at queue threshold)" % feeder_moved)
	print("  [MEASURED] Oval Circulated Distance: %.2f px (~%.2f Laps)" % [oval_dist, oval_dist / track_len])

	if feeder_moved < 1.0 and oval_dist >= 600.0:
		print("  [PASS] Test C: Feeder successfully waited with 0 movement while oval circulated freely for %.2f px!" % oval_dist)
	else:
		print("  [FAIL] Test C: Oval stalled or feeder leaked! OvalDist=%.2f, FeederMoved=%.2f" % [oval_dist, feeder_moved])
		failures += 1

	l_c.queue_free()
	await process_frame
	for f in 5: await process_frame

	# -------------------------------------------------------------------------
	# TEST D: BOARDING AND FEEDER REPLENISHMENT
	# -------------------------------------------------------------------------
	print("\n--- TEST D: Boarding Opens Capacity & Feeder Merges Seamlessly ---")
	var l_d: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l_d)
	await process_frame
	for f in 10: await process_frame

	# Tap vehicle 3 to bay
	var ok_tap = l_d.controller.tap_vehicle(3)
	var saw_boarding_credit := false
	var t_start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_start < 4000:
		await process_frame
		if l_d._oval_freed_capacity > 0:
			saw_boarding_credit = true
			break

	print("  [MEASURED] Real Boarding Capacity Credit Triggered: %s (FreedCap: %d)" % [
		str(saw_boarding_credit), l_d._oval_freed_capacity
	])

	# Now step until feeder row merges into freed capacity (max 150 frames = 2.5s)
	var before_merge_f = l_d._feeder_rows.size()
	var merged := false
	for f in 150:
		await process_frame
		if l_d._feeder_rows.size() < before_merge_f:
			merged = true
			break

	print("  [MEASURED] Feeder Row Merged into Vacated Gap: %s" % str(merged))

	if saw_boarding_credit and merged:
		print("  [PASS] Test D: Boarding generated capacity credits and feeder merged into vacated gap!")
	else:
		print("  [FAIL] Test D: Boarding credit or feeder merge failed! SawCredit=%s, Merged=%s" % [
			str(saw_boarding_credit), str(merged)
		])
		failures += 1

	l_d.queue_free()
	await process_frame
	for f in 5: await process_frame

	# -------------------------------------------------------------------------
	# TEST E: STABILITY, LEVEL 2 & ZERO OVERLAPS ACROSS 480 PASSENGERS
	# -------------------------------------------------------------------------
	print("\n--- TEST E: Level 2 Stability, 480 Passengers & Zero Duplicate Identities ---")
	gc_node.current_level_number = 2

	var l_e: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l_e)
	await process_frame
	for f in 10: await process_frame

	var total_p: int = l_e.all_passengers.size()
	print("  Level 2 Total Registered Passengers: %d (Target: 480)" % total_p)

	var unique_pids: Dictionary = {}
	var duplicates := 0
	for pid in l_e.all_passengers:
		if unique_pids.has(pid):
			duplicates += 1
		unique_pids[pid] = true

	var l2_circ_dist: float = 0.0
	var prev_l2_p: float = l_e._circulating_rows[0].progress if not l_e._circulating_rows.is_empty() else 0.0

	for f in 120: # 2 seconds
		await process_frame
		if not l_e._circulating_rows.is_empty():
			var cur_p = l_e._circulating_rows[0].progress
			var dp = cur_p - prev_l2_p
			if dp < 0.0: dp += track_len
			l2_circ_dist += dp
			prev_l2_p = cur_p

	print("  [MEASURED] Level 2 Circulation Distance in 2s: %.2f px (%.2f Laps)" % [l2_circ_dist, l2_circ_dist / track_len])
	print("  [MEASURED] Duplicate Passenger IDs: %d" % duplicates)

	if total_p == 480 and duplicates == 0 and l2_circ_dist >= 600.0:
		print("  [PASS] Test E: Level 2 480 passengers circulate continuously with zero duplicate identities!")
	else:
		print("  [FAIL] Test E: Level 2 validation failed! Total=%d, Duplicates=%d, Dist=%.2f" % [total_p, duplicates, l2_circ_dist])
		failures += 1

	l_e.queue_free()

	print("\n=========================================================================")
	if failures == 0:
		print("=== ALL 5 CONTINUOUS CIRCULATION TESTS PASSED (0 FAILURES) ===")
	else:
		print("=== %d CONTINUOUS CIRCULATION TESTS FAILED ===" % failures)
	print("=========================================================================\n")

	if failures > 0:
		quit(1)
	else:
		quit(0)
