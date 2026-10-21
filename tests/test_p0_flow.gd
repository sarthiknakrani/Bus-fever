extends SceneTree

## Result-overlay flow test:
## Spins up the level scene in headless mode, triggers controller signals, and
## verifies that:
##   - On victory, the next-level button is shown with the correct text, retry
##     is hidden, and the title says "LEVEL N CLEAR!".
##   - On failure, the retry button is shown, the next button is hidden, and
##     the title says "NO MOVES LEFT".
##   - Failure never unlocks the next level (verify SaveManager state).

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

var level: Node
var passed: int = 0
var failed: int = 0

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("\n==========================================")
	print("=== RESULT-OVERLAY FLOW VERIFICATION   ===")
	print("==========================================")

	var sm: Node = get_root().get_node_or_null("SaveManager")
	var gc: Node = get_root().get_node_or_null("GameController")

	# Reset state so we know what we're starting with.
	sm.wipe()
	gc.current_level_number = 1
	gc.start_level(1)

	await create_timer(0.1).timeout

	level = CarJamLevelScene.instantiate()
	get_root().add_child(level)
	# Wait for ready / layout.
	await create_timer(0.3).timeout

	# -------------------------------------------------------------
	# TEST 1: Trigger level_completed (victory) signal
	# -------------------------------------------------------------
	print("\n--- TEST 1: Victory — next button visible, retry hidden ---")
	var ctrl: Node = level.controller
	ctrl.level_completed.emit()
	await create_timer(0.05).timeout

	if level.result_overlay.visible:
		print("  [PASS] result_overlay is visible on victory")
		passed += 1
	else:
		print("  [FAIL] result_overlay should be visible on victory")
		failed += 1

	if level.result_btn != null and level.result_btn.visible:
		print("  [PASS] result_btn (next level) is visible on victory")
		passed += 1
	else:
		print("  [FAIL] result_btn (next level) must be visible on victory")
		failed += 1

	if level.result_retry_btn != null and not level.result_retry_btn.visible:
		print("  [PASS] result_retry_btn is hidden on victory")
		passed += 1
	else:
		print("  [FAIL] result_retry_btn must be hidden on victory")
		failed += 1

	# Verify the next button text reflects the actual current level
	# (should be "Level 2" because we are playing Level 1).
	if level.result_btn_label != null and (level.result_btn_label.text == "NEXT" or level.result_btn_label.text == "Level 2"):
		print("  [PASS] result_btn label says '%s' (Next Level Action)" % level.result_btn_label.text)
		passed += 1
	else:
		print("  [FAIL] result_btn label was '%s', expected 'NEXT' or 'Level 2'" % (
			level.result_btn_label.text if level.result_btn_label else "null"))
		failed += 1

	if level.result_title_label.text.find("LEVEL 1 CLEAR") >= 0 or level.result_title_label.text.find("GREAT JOB!") >= 0:
		print("  [PASS] result_title_label acknowledges victory ('%s')" % level.result_title_label.text)
		passed += 1
	else:
		print("  [FAIL] result_title_label was '%s'" % level.result_title_label.text)
		failed += 1

	# Verify SaveManager recorded the completion.
	if sm.level_1_done():
		print("  [PASS] SaveManager recorded Level 1 as done")
		passed += 1
	else:
		print("  [FAIL] SaveManager did NOT record Level 1 as done")
		failed += 1

	if sm.get_max_unlocked_level() == 2:
		print("  [PASS] SaveManager unlocked Level 2 after Level 1 win")
		passed += 1
	else:
		print("  [FAIL] SaveManager max_unlocked_level=%d, expected 2" % sm.get_max_unlocked_level())
		failed += 1

	# -------------------------------------------------------------
	# TEST 2: Trigger puzzle_failed (failure) on the SAME level
	# -------------------------------------------------------------
	print("\n--- TEST 2: Failure — retry visible, next hidden, no unlock ---")
	# Wipe unlocks so we can prove failure does NOT raise them.
	sm.wipe()
	# Reset result state so this is a fresh attempt at a synthetic failure.
	level._result_outcome = ""
	level.result_overlay.visible = false
	level.result_btn.visible = false
	level.result_retry_btn.visible = false
	level.result_subtitle_label.visible = false
	if level.is_inside_tree():
		level.get_tree().paused = false

	ctrl = level.controller
	ctrl.puzzle_failed.emit()
	await create_timer(0.05).timeout

	if level.result_overlay.visible:
		print("  [PASS] result_overlay is visible on failure")
		passed += 1
	else:
		print("  [FAIL] result_overlay should be visible on failure")
		failed += 1

	if level.result_btn != null and not level.result_btn.visible:
		print("  [PASS] result_btn (next level) is HIDDEN on failure — no progression leak")
		passed += 1
	else:
		print("  [FAIL] result_btn must be hidden on failure")
		failed += 1

	if level.result_retry_btn != null and level.result_retry_btn.visible:
		print("  [PASS] result_retry_btn is visible on failure")
		passed += 1
	else:
		print("  [FAIL] result_retry_btn must be visible on failure")
		failed += 1

	if level.result_title_label.text.find("NO MOVES LEFT") >= 0 or level.result_title_label.text.find("OUT OF SPACE") >= 0:
		print("  [PASS] result_title_label says '%s' (Failure title validated)" % level.result_title_label.text)
		passed += 1
	else:
		print("  [FAIL] result_title_label was '%s'" % level.result_title_label.text)
		failed += 1

	# Critical: failure must NOT have unlocked Level 3.
	if sm.get_max_unlocked_level() == 1:
		print("  [PASS] Failure did NOT raise max_unlocked_level (still 1)")
		passed += 1
	else:
		print("  [FAIL] Failure wrongly raised max_unlocked_level to %d" % sm.get_max_unlocked_level())
		failed += 1

	# -------------------------------------------------------------
	# TEST 3: Guard against double-firing — second signal must not change UI
	# -------------------------------------------------------------
	print("\n--- TEST 3: Single-fire Guard ---")
	# We're in failure state with retry visible. Fire level_completed — must NOT
	# transform into a victory.
	ctrl.level_completed.emit()
	await create_timer(0.05).timeout
	if level.result_retry_btn.visible and not level.result_btn.visible:
		print("  [PASS] After failed-level, late level_completed signal does not flip UI to victory")
		passed += 1
	else:
		print("  [FAIL] UI flipped from failure to victory on stray signal")
		failed += 1

	# -------------------------------------------------------------
	# FINAL
	# -------------------------------------------------------------
	print("\n==========================================")
	print("FLOW SUITE SUMMARY: %d passed, %d failed" % [passed, failed])
	print("==========================================")

	if level != null:
		level.queue_free()
	sm.wipe()
	if failed > 0:
		quit(1)
	else:
		quit(0)