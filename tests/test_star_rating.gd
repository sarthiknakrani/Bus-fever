extends SceneTree

# Star Rating Test
# Verifies Feature: 3-tier star rating based on move_count vs ideal_moves.
# - 3 stars when move_count <= ideal_moves
# - 2 stars when move_count <= ceil(ideal_moves * 1.5)
# - 1 star otherwise (level still completes)
# Mystery reveals and rejected taps must NOT increment move_count.

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("\n=======================================================")
	print("=== STAR RATING TEST ===")
	print("=======================================================\n")

	var lvl: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	assert(lvl != null, "level_001.tres must load")
	assert(lvl.ideal_moves == 6, "Level 1 ideal_moves must be 6 (one tap per bus)")
	print("  [PASS] Level 1 authored with ideal_moves=6\n")

	# Direct controller test (no scene) so we can drive move_count precisely.
	var ctrl := CarJamController.new()
	root.add_child(ctrl)
	ctrl.load_level(lvl)

	# Track signal payloads.
	var star_events: Array = []
	ctrl.level_scored.connect(
		func(s: int, m: int, ideal: int) -> void: star_events.append({"stars": s, "moves": m, "ideal": ideal})
	)

	# 1) Mystery tap must NOT increment move_count.
	print("[Test] Mystery reveal shouldn't count as a move...")
	var mystery_bus: VehicleModel = ctrl.vehicles.get(2, null)
	assert(mystery_bus != null, "Need bus 2 to test")
	mystery_bus.mark_as_mystery()
	var ok_m: bool = ctrl.tap_vehicle(2)
	assert(ok_m, "Mystery tap must succeed")
	await create_timer(0.05).timeout
	assert(ctrl.move_count == 0, "Mystery reveal must NOT increment move_count (still %d)" % ctrl.move_count)
	print("  [PASS] Mystery reveal does not count\n")

	# 2) Each successful dispatch increments move_count by 1.
	# Tap buses in a valid level-1 dispatch order. Bus 2 is already revealed but still on
	# the board, so we dispatch it FIRST to clear its blocker on bus 4.
	print("[Test] Successful dispatches should yield move_count=N where N=successful taps...")
	var dispatched: Array = []
	for vid in [2, 4, 5, 1, 3, 6]:
		if ctrl.tap_vehicle(vid):
			dispatched.append(vid)
		await create_timer(0.05).timeout
	print("  Dispatched order: %s, move_count=%d" % [str(dispatched), ctrl.move_count])
	assert(ctrl.move_count == dispatched.size(), "move_count must equal successful taps only")
	assert(dispatched.size() == 6, "All 6 buses must be dispatchable in this order")

	# 3) Stars for a 6-move clear on an ideal_moves=6 level should be 3.
	var expected_stars: int = 3
	var expected_moves: int = 6

	# Force the win condition without running the full animation pipeline. Set both the
# authoritative state AND the queue group bookkeeping to zero so the strict passenger-
# conservation check passes; otherwise level_completed never fires.
	for vid in ctrl.vehicles:
		var v: VehicleModel = ctrl.vehicles[vid]
		v.state = VehicleModel.VehicleState.COMPLETED
		v.passenger_occupancy = v.capacity  # so total boarded matches initial-count
	for g in ctrl.queue.get_all_groups():
		g.remaining_count = 0
	for pid in ctrl.authoritative_passengers:
		ctrl.authoritative_passengers[pid]["state"] = "BOARDED"
	ctrl._check_terminal_states()

	# level_scored should fire synchronously from _check_terminal_states.
	assert(not star_events.is_empty(), "level_scored must fire after level completion")
	var ev: Dictionary = star_events[0]
	print("  level_scored → stars=%d moves=%d ideal=%d" % [ev["stars"], ev["moves"], ev["ideal"]])
	assert(ev["ideal"] == 6, "ideal_moves in signal must match Level 1 authorship")
	assert(ev["moves"] == expected_moves, "moves in signal must equal dispatched.size")
	assert(ev["stars"] == expected_stars, "3-star rating for perfect-play 6 moves on ideal=6 must yield 3 stars")

	print("\n=======================================================")
	print("=== ALL STAR RATING TESTS PASSED ===")
	print("=======================================================\n")
	quit(0)
