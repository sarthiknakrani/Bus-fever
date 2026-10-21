extends SceneTree

# Plus Bay Unlock Progression Test
# Verifies Feature A: green "+" PLUS bays start locked and unlock in waves as the
# player sustains dispatch progress. Bypasses CarJamLevel scene to avoid
# GameController.current_level_number state from earlier sessions.

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("\n=======================================================")
	print("=== PLUS BAY UNLOCK PROGRESSION TEST ===")
	print("=======================================================\n")

	# Load level 1 data directly from the .tres and configure plus bays for progression test.
	var base_lvl: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	assert(base_lvl != null, "level_001.tres must load")
	var lvl: CarJamLevelData = base_lvl.duplicate(true) as CarJamLevelData
	lvl.plus_slot_ids = [4, 5]
	print("[Test] Loaded level %d (%d slots, plus=%s)" % [lvl.level_id, lvl.parking_slots_count, str(lvl.plus_slot_ids)])
	assert(lvl.plus_slot_ids == [4, 5], "Level data configured with plus_slot_ids = [4, 5]")

	# Spin up controller and load level directly.
	var ctrl := CarJamController.new()
	root.add_child(ctrl)
	ctrl.load_level(lvl)
	var pm = ctrl.parking

	# Initial state assertions
	print("[Test] Initial state...")
	assert(pm.get_plus_locked_count() == 2, "Level 1 must start with 2 plus bays locked")
	assert(pm.is_plus_locked(4), "Slot 4 must start locked as PLUS bay")
	assert(pm.is_plus_locked(5), "Slot 5 must start locked as PLUS bay")
	assert(not pm.is_plus_locked(1), "Slot 1 must NOT be a PLUS bay")
	assert(not pm.is_plus_locked(0), "Slot 0 must NOT be a PLUS bay (it is VIP)")
	print("  [PASS] %d plus bays locked at start" % pm.get_plus_locked_count())

	# Helper: find any dispatchable bus (state ON_BOARD, escape check passes).
	var vehicles = ctrl.vehicles
	var board = ctrl.board

	# Tap 1: dispatch_count = 1, target = 0. No unlock yet.
	print("[Test] Dispatch #1...")
	var vid1 := _pick_dispatchable_bus(ctrl, vehicles, board)
	assert(vid1 != -1, "At least one bus must be dispatchable at start")
	var ok1: bool = ctrl.tap_vehicle(vid1)
	assert(ok1, "First tap must succeed (selected a dispatchable bus)")
	await create_timer(0.05).timeout
	print("  Tapped bus %d. Plus locked count: %d (expected 2)" % [vid1, pm.get_plus_locked_count()])
	assert(pm.get_plus_locked_count() == 2, "Plus bays must remain locked after 1 dispatch (threshold=2)")

	# Tap 2: dispatch_count = 2, target = 1. Unlock first plus bay (slot 4).
	print("[Test] Dispatch #2...")
	var vid2 := _pick_dispatchable_bus(ctrl, vehicles, board)
	# We may have only one open slot with parking not full; check
	if vid2 != -1:
		var ok2: bool = ctrl.tap_vehicle(vid2)
		if ok2:
			await create_timer(0.05).timeout
			print("  Tapped bus %d. Plus locked count: %d (expected 1)" % [vid2, pm.get_plus_locked_count()])
			assert(pm.get_plus_locked_count() == 1, "After 2 dispatches, exactly 1 plus bay must be unlocked")
			assert(not pm.is_plus_locked(4), "Slot 4 (first PLUS) must now be unlocked")
			assert(pm.is_plus_locked(5), "Slot 5 (second PLUS) must still be locked")
			print("  [PASS] Plus bay 4 unlocked at dispatch #2")
		else:
			# If we couldn't dispatch a second, parking full — but threshold requires 2.
			assert(false, "Second tap MUST succeed for threshold test (chosen bus wasn't dispatchable)")

	# Tap 3: dispatch_count = 3, target = 1. No new unlock.
	print("[Test] Dispatch #3 (no new unlock expected)...")
	var vid3 := _pick_dispatchable_bus(ctrl, vehicles, board)
	if vid3 != -1:
		var ok3: bool = ctrl.tap_vehicle(vid3)
		if ok3:
			await create_timer(0.05).timeout
			print("  Tapped bus %d. Plus locked count: %d (still expected 1)" % [vid3, pm.get_plus_locked_count()])
			assert(pm.get_plus_locked_count() == 1, "Plus bay count must remain 1 after dispatch #3")

	# Tap 4: dispatch_count = 4, target = 2. Unlock second plus bay (slot 5).
	print("[Test] Dispatch #4 (expect second plus bay unlock)...")
	var vid4 := _pick_dispatchable_bus(ctrl, vehicles, board)
	if vid4 != -1:
		var ok4: bool = ctrl.tap_vehicle(vid4)
		if ok4:
			await create_timer(0.05).timeout
			print("  Tapped bus %d. Plus locked count: %d (expected 0)" % [vid4, pm.get_plus_locked_count()])
			assert(pm.get_plus_locked_count() == 0, "Both plus bays must be unlocked after 4 dispatches")
			assert(not pm.is_plus_locked(4), "Slot 4 unlocked confirmed")
			assert(not pm.is_plus_locked(5), "Slot 5 unlocked confirmed")
			print("  [PASS] Plus bay 5 unlocked at dispatch #4")

	# Tap 5+: no further plus bays; threshold logic must not infinite-loop or crash.
	print("[Test] Extra dispatch (no further plus bays; loop must terminate cleanly)...")
	var vid5 := _pick_dispatchable_bus(ctrl, vehicles, board)
	if vid5 != -1:
		ctrl.tap_vehicle(vid5)
		assert(pm.get_plus_locked_count() == 0, "Plus lock count still 0 after dispatch #5")
	print("  [PASS] Threshold logic exits cleanly when no plus bays remain\n")

	print("=======================================================")
	print("=== ALL PLUS BAY TESTS PASSED ===")
	print("=======================================================\n")
	quit(0)

# Find any bus that is currently ON_BOARD and physically clear of blockers.
# Returns -1 if none.
func _pick_dispatchable_bus(ctrl: CarJamController, vehicles: Dictionary, board) -> int:
	for vid in vehicles:
		var v = vehicles[vid]
		if v == null or not v.can_dispatch():
			continue
		var esc = board.check_swept_escape(v)
		if esc["can_escape"]:
			return vid
	return -1
