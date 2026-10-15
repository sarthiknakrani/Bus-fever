extends SceneTree

# ==============================================================================
# QA TEST SUITE: PREMIUM LEVEL COMPLETE SCREEN, +50 COIN REWARD & FIREWORKS
# ==============================================================================

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	call_deferred("_run_qa_suite")

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
		passed_count += 1
	else:
		printerr("  [FAIL] %s" % message)
		failed_count += 1

func _run_qa_suite() -> void:
	print("======================================================================")
	print("=== STARTING QA AUDIT: LEVEL COMPLETE REWARD & CELEBRATION SUITE ===")
	print("======================================================================")

	_test_save_manager_currency_engine()
	_test_currency_persistence()
	await _test_victory_ui_and_accounting()
	await _test_failure_ui_isolation()
	await _test_level2_victory_and_end_state()

	print("======================================================================")
	print("=== QA AUDIT COMPLETE: %d PASSED, %d FAILED ===" % [passed_count, failed_count])
	print("======================================================================")

	if failed_count == 0:
		print("STATUS: ALL TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		push_error("STATUS: QA SUITE FAILED!")
		quit(1)

func _test_save_manager_currency_engine() -> void:
	print("\n--- TEST GROUP 1: SaveManager Currency Engine & Idempotency ---")
	
	var save_mgr = root.get_node_or_null("SaveManager")
	_assert(save_mgr != null, "SaveManager autoload is active and reachable")
	if save_mgr == null:
		return

	# Reset save data to clean baseline
	save_mgr.wipe()
	_assert(save_mgr.get_coins() == 0, "Baseline coins reset to 0")

	# 1. Level 1 completion award
	var award1: bool = save_mgr.award_level_completion_reward(1, "run_l1_test_01", 50)
	_assert(award1 == true, "First award for Level 1 run succeeds")
	_assert(save_mgr.get_coins() == 50, "Coins balance increased from 0 to exactly 50")

	# 2. Duplicate award attempt for same run (idempotency check)
	var award_dup: bool = save_mgr.award_level_completion_reward(1, "run_l1_test_01", 50)
	_assert(award_dup == false, "Duplicate award with identical run_id is rejected")
	_assert(save_mgr.get_coins() == 50, "Coins balance remains strictly 50 (zero duplicate payment)")

	# 3. Next level completion award (Level 2)
	var award2: bool = save_mgr.award_level_completion_reward(2, "run_l2_test_02", 50)
	_assert(award2 == true, "Award for Level 2 run succeeds")
	_assert(save_mgr.get_coins() == 100, "Coins balance increased from 50 to 100")

	# 4. Custom existing balance test (e.g. 350 + 50 = 400)
	save_mgr.set_coins(350)
	_assert(save_mgr.get_coins() == 350, "Balance set to 350")
	var award3: bool = save_mgr.award_level_completion_reward(1, "run_l1_custom_03", 50)
	_assert(award3 == true, "Award with existing balance succeeds")
	_assert(save_mgr.get_coins() == 400, "Coins balance correctly increased from 350 to 400")

func _test_currency_persistence() -> void:
	print("\n--- TEST GROUP 2: Disk Persistence & App Restart Recovery ---")
	
	var save_mgr = root.get_node_or_null("SaveManager")
	if save_mgr == null:
		return

	# Ensure saved balance is 400
	save_mgr.set_coins(400)
	save_mgr.save_data()

	# Create a secondary fresh SaveManager instance to simulate cold restart
	var fresh_save = load("res://scripts/autoload/save_manager.gd").new()
	root.add_child(fresh_save)
	fresh_save._load()

	_assert(fresh_save.get_coins() == 400, "Saved balance of 400 coins survives cold restart")
	
	# Verify run idempotency persists across cold restart
	var dup_after_restart: bool = fresh_save.award_level_completion_reward(1, "run_l1_custom_03", 50)
	_assert(dup_after_restart == false, "Previously claimed run_id cannot be re-awarded after restart")
	_assert(fresh_save.get_coins() == 400, "Coins remain 400 after restart idempotency check")

	fresh_save.queue_free()

func _test_victory_ui_and_accounting() -> void:
	print("\n--- TEST GROUP 3: CarJamLevel Victory Presentation & Single Action Button ---")

	var save_mgr = root.get_node_or_null("SaveManager")
	if save_mgr != null:
		save_mgr.set_coins(100)

	var gc = root.get_node_or_null("GameController")
	if gc != null:
		gc.current_level_number = 1

	var level_scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var level_instance = level_scene.instantiate()
	root.add_child(level_instance)

	# Wait 2 frames for _ready and HUD instantiation
	await process_frame
	await process_frame

	# Simulate level completion trigger
	level_instance._on_level_completed()

	_assert(level_instance._result_outcome == "victory", "Result outcome transitioned to 'victory'")
	_assert(level_instance.result_overlay.visible == true, "ResultOverlay is visible on victory")
	
	# Verify reward badge
	_assert(level_instance.reward_badge != null, "Reward badge node exists")
	_assert(level_instance.reward_badge.visible == true, "Reward badge is visible on victory")
	_assert(level_instance.reward_badge_label.text == "+50", "Reward badge displays '+50'")

	# Verify top-left coin counter
	_assert(level_instance.coin_counter_wrapper != null, "Coin counter wrapper exists")
	_assert(level_instance.coin_counter_wrapper.visible == true, "Coin counter is visible on victory")
	_assert(level_instance.coin_counter_icon != null, "Coin counter icon is present")
	_assert(save_mgr.get_coins() == 150, "Total coins awarded: 100 + 50 = 150")

	# Verify strict Single Action Button (NEXT only)
	_assert(level_instance.result_btn.visible == true, "NEXT button is visible on victory")
	_assert(level_instance.result_btn_label.text == "NEXT", "Button label displays 'NEXT'")
	_assert(level_instance.result_retry_btn.visible == false, "Retry button is STRICTLY hidden on victory")
	_assert(level_instance.result_home_btn.visible == false, "Home button is STRICTLY hidden on victory")

	# Verify celebration fireworks & flight animation nodes spawned
	await create_timer(0.2).timeout
	_assert(level_instance._firework_nodes.size() > 0 or level_instance._celebration_tweens.size() > 0, "Celebration fireworks/tweens spawned")

	# Clean up
	level_instance.queue_free()
	await process_frame

func _test_failure_ui_isolation() -> void:
	print("\n--- TEST GROUP 4: Failure Screen Isolation (0 Coins & Retry/Home Buttons) ---")

	var save_mgr = root.get_node_or_null("SaveManager")
	var initial_coins: int = save_mgr.get_coins() if save_mgr != null else 0

	var gc = root.get_node_or_null("GameController")
	if gc != null:
		gc.current_level_number = 1

	var level_scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var level_instance = level_scene.instantiate()
	root.add_child(level_instance)

	await process_frame
	await process_frame

	# Simulate puzzle failure
	level_instance._on_puzzle_failed()

	_assert(level_instance._result_outcome == "failure", "Result outcome transitioned to 'failure'")
	_assert(level_instance.result_overlay.visible == true, "ResultOverlay is visible on failure")
	
	# Strict failure rules
	_assert(level_instance.result_title_label.text == "OUT OF SPACE!", "Title is 'OUT OF SPACE!'")
	_assert(level_instance.result_btn.visible == false, "NEXT button is STRICTLY hidden on failure")
	_assert(level_instance.result_retry_btn.visible == true, "Retry button is visible on failure")
	_assert(level_instance.result_home_btn.visible == true, "Home button is visible on failure")
	_assert(level_instance.reward_badge.visible == false, "Reward badge is STRICTLY hidden on failure")
	_assert(level_instance.coin_counter_wrapper.visible == false, "Coin counter is STRICTLY hidden on failure")
	
	# 0 Coins awarded on failure check
	_assert(save_mgr.get_coins() == initial_coins, "Zero coins awarded on failure (balance unchanged: %d)" % initial_coins)

	level_instance.queue_free()
	await process_frame

func _test_level2_victory_and_end_state() -> void:
	print("\n--- TEST GROUP 5: Level 2 Victory & 'More Levels Coming Soon' End State ---")

	var save_mgr = root.get_node_or_null("SaveManager")
	var initial_coins: int = save_mgr.get_coins() if save_mgr != null else 0

	var gc = root.get_node_or_null("GameController")
	if gc != null:
		gc.current_level_number = 2

	var level_scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var level_instance = level_scene.instantiate()
	root.add_child(level_instance)

	await process_frame
	await process_frame

	# Simulate Level 2 victory
	level_instance._on_level_completed()

	_assert(level_instance._result_outcome == "victory", "Level 2 completed successfully")
	_assert(save_mgr.get_coins() == initial_coins + 50, "Level 2 awards exactly 50 coins (total: %d)" % (initial_coins + 50))

	# Since no Level 3 exists in authored content, verify graceful end state
	var has_l3: bool = gc != null and gc.has_level(3)
	if not has_l3:
		_assert(level_instance.result_btn.visible == false, "NEXT button hidden when no next level exists")
		_assert(level_instance.result_subtitle_label.visible == true, "Subtitle visible when no next level exists")
		_assert(level_instance.result_subtitle_label.text == "More Levels Coming Soon", "Subtitle displays 'More Levels Coming Soon'")
		_assert(level_instance.result_retry_btn.visible == false, "Retry button remains hidden")
		_assert(level_instance.result_home_btn.visible == false, "Home button remains hidden on victory")

	level_instance.queue_free()
	await process_frame
