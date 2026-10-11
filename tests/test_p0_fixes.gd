extends SceneTree

## P0 REGRESSION TEST SUITE
## Verifies the level-progression, save-unlock, victory/failure, and persistence
## repairs performed in scripts/gameplay/car_jam_level.gd and scripts/autoload/.
##
## These tests do NOT spin up the full level scene. They exercise the
## SaveManager/GameController state machine directly so failures surface
## fast and reliably without depending on GUI rendering or animation.

const TEST_SAVE_PATH := "user://test_p0_save.cfg"

var sm: Node  # SaveManager autoload (accessed via get_node)
var gc: Node  # GameController autoload

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("\n==========================================")
	print("=== P0 PROGRESSION / SAVE / FLOW TESTS  ===")
	print("==========================================")

	sm = get_root().get_node_or_null("SaveManager")
	gc = get_root().get_node_or_null("GameController")
	if sm == null:
		print("  [FATAL] SaveManager autoload missing — cannot run")
		quit(2)
		return

	var passed := 0
	var failed := 0

	# -------------------------------------------------------------
	# TEST 1: SaveManager.coin reset bug — previously stored coins survive relaunch
	# -------------------------------------------------------------
	print("\n--- TEST 1: Coin Persistence Across Reload ---")
	sm.wipe()
	sm.add_coins(123)
	sm._save()
	var coins_before: int = sm.get_coins()

	# Simulate relaunch by re-invoking the loader.
	sm._load()
	# CRITICAL: _ready() previously called set_value(KEY_COINS, 0) unconditionally.
	# The repaired _ready() must not clobber saved coins.
	sm._ready()

	var coins_after: int = sm.get_coins()
	print("  Coins before reload: ", coins_before)
	print("  Coins after reload:  ", coins_after)
	if coins_after == 123 and coins_before == 123:
		print("  [PASS] Coins survive a reload — _ready() no longer resets them")
		passed += 1
	else:
		print("  [FAIL] Coins did NOT survive. before=%d after=%d" % [coins_before, coins_after])
		failed += 1

	# -------------------------------------------------------------
	# TEST 2: GameController.has_level reports based on disk, not hardcoding
	# -------------------------------------------------------------
	print("\n--- TEST 2: GameController.has_level Uses Disk Truth ---")
	if gc == null:
		print("  [SKIP] GameController autoload not available — skipping")
	else:
		var has_1: bool = gc.has_level(1)
		var has_2: bool = gc.has_level(2)
		var has_3: bool = gc.has_level(3)
		var has_99: bool = gc.has_level(99)
		var has_0: bool = gc.has_level(0)
		var has_neg: bool = gc.has_level(-5)
		print("  has_level(1)=%s, (2)=%s, (3)=%s, (99)=%s, (0)=%s, (-5)=%s" % [has_1, has_2, has_3, has_99, has_0, has_neg])
		if has_1 and has_2 and not has_3 and not has_99 and not has_0 and not has_neg:
			print("  [PASS] has_level() reports only authored levels (1, 2) and rejects others")
			passed += 1
		else:
			print("  [FAIL] has_level() returned wrong answers")
			failed += 1

		# Authoritative available level count should match disk (currently 2).
		var count: int = gc.available_level_count()
		if count == 2:
			print("  [PASS] available_level_count() == 2 (matches authored levels on disk)")
			passed += 1
		else:
			print("  [FAIL] available_level_count()=%d, expected 2" % count)
			failed += 1

	# -------------------------------------------------------------
	# TEST 3: GameController.next_level no longer wraps around to Level 1
	# -------------------------------------------------------------
	print("\n--- TEST 3: next_level() Never Silently Loops to Level 1 ---")
	if gc != null:
		sm.wipe()
		sm.set_current_level(2)

		# We can't reassign gc.goto_scene directly (it's a built-in script method).
		# Instead, simulate by overriding change_scene_to_file via SceneTree stub: we
		# simply read the public state after the call. If next_level() incorrectly
		# wrapped to Level 1, then current_level_number would be 1 again.
		gc.next_level()

		var after_num: int = int(gc.current_level_number)
		print("  After finishing Level 2, gc.current_level_number = %d" % after_num)

		# If next_level() called start_level(1) (the old bug), current_level_number
		# would have been set back to 1. The fixed behavior should NOT have changed
		# current_level_number (since it goes to main.tscn, not start_level).
		if after_num == 2:
			print("  [PASS] next_level() from Level 2 did NOT silently wrap to Level 1 (state preserved at 2)")
			passed += 1
		else:
			print("  [FAIL] next_level() from Level 2 wrapped current_level_number to %d (should remain 2)" % after_num)
			failed += 1

		# Also verify that we don't have a level_003.tres on disk that would have
		# been the *correct* target.
		var path_3 := "res://levels/level_003.tres"
		if not ResourceLoader.exists(path_3):
			print("  [PASS] No level_003.tres exists — next_level() correctly has nothing to advance to")
			passed += 1
		else:
			print("  [FAIL] level_003.tres exists; next_level() should have advanced to Level 3")
			failed += 1

	# -------------------------------------------------------------
	# TEST 4: SaveManager unlock progression rules
	# -------------------------------------------------------------
	print("\n--- TEST 4: SaveManager.unlock_level / get_max_unlocked_level ---")
	sm.wipe()
	if sm.get_max_unlocked_level() != 1:
		print("  [FAIL] After wipe, max_unlocked_level should be 1; got %d" % sm.get_max_unlocked_level())
		failed += 1
	else:
		print("  [PASS] wipe() → max_unlocked_level=1")
		passed += 1

	# Lower-number unlock is a no-op.
	sm.unlock_level(1)
	if sm.get_max_unlocked_level() != 1:
		print("  [FAIL] unlock_level(1) should not raise max_unlocked_level")
		failed += 1
	else:
		print("  [PASS] unlock_level(1) does not regress")
		passed += 1

	sm.unlock_level(3)
	if sm.get_max_unlocked_level() != 3:
		print("  [FAIL] unlock_level(3) should raise max_unlocked_level to 3; got %d" % sm.get_max_unlocked_level())
		failed += 1
	else:
		print("  [PASS] unlock_level(3) raises max_unlocked_level to 3")
		passed += 1

	sm.unlock_level(2)
	if sm.get_max_unlocked_level() != 3:
		print("  [FAIL] unlock_level(2) must not lower max_unlocked_level (still 3); got %d" % sm.get_max_unlocked_level())
		failed += 1
	else:
		print("  [PASS] unlock_level(2) cannot lower max_unlocked_level")
		passed += 1

	# Survive reload.
	sm._load()
	if sm.get_max_unlocked_level() == 3:
		print("  [PASS] unlock state survives _load()")
		passed += 1
	else:
		print("  [FAIL] unlock state lost after reload: %d" % sm.get_max_unlocked_level())
		failed += 1

	# -------------------------------------------------------------
	# TEST 5: SaveManager.set_level_1_done persistence
	# -------------------------------------------------------------
	print("\n--- TEST 5: SaveManager.set_level_1_done Persists ---")
	sm.wipe()
	sm.set_level_1_done(true)
	sm._load()
	if sm.level_1_done():
		print("  [PASS] level_1_done() remains true after reload")
		passed += 1
	else:
		print("  [FAIL] level_1_done() lost after reload")
		failed += 1

	# -------------------------------------------------------------
	# TEST 6: SaveManager coins survive multiple reloads
	# -------------------------------------------------------------
	print("\n--- TEST 6: Coins Survive Multiple Reloads ---")
	sm.wipe()
	sm.add_coins(42)
	sm._load()
	if sm.get_coins() != 42:
		print("  [FAIL] First reload lost coins: %d" % sm.get_coins())
		failed += 1
	else:
		sm.add_coins(8)
		sm._load()
		if sm.get_coins() == 50:
			print("  [PASS] Coins survive multiple reloads (42 + 8 = 50)")
			passed += 1
		else:
			print("  [FAIL] Coins lost on second reload: %d" % sm.get_coins())
			failed += 1

	# -------------------------------------------------------------
	# TEST 7: Bonus persistence (hint/undo/extra_bay)
	# -------------------------------------------------------------
	print("\n--- TEST 7: Booster Counts Survive Reload ---")
	sm.wipe()
	sm.add_booster("hint", 7)
	sm.add_booster("undo", 11)
	sm.add_booster("extra_bay", 2)
	sm._load()
	var ok_h: bool = sm.get_booster_count("hint") == 7 + 5  # 5 default + 7 added = 12
	var ok_u: bool = sm.get_booster_count("undo") == 11 + 5
	var ok_e: bool = sm.get_booster_count("extra_bay") == 2 + 3
	print("  hint=%d, undo=%d, extra_bay=%d" % [
		sm.get_booster_count("hint"),
		sm.get_booster_count("undo"),
		sm.get_booster_count("extra_bay"),
	])
	if ok_h and ok_u and ok_e:
		print("  [PASS] Booster counts survive reload (defaults + adds)")
		passed += 1
	else:
		print("  [FAIL] Booster counts lost")
		failed += 1

	# -------------------------------------------------------------
	# FINAL
	# -------------------------------------------------------------
	print("\n==========================================")
	print("P0 SUITE SUMMARY: %d passed, %d failed" % [passed, failed])
	print("==========================================")

	# Cleanup test state so we leave the save file reasonable for the next run.
	sm.wipe()
	if failed > 0:
		quit(1)
	else:
		quit(0)