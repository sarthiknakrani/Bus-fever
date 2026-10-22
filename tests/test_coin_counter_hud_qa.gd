extends SceneTree

const CoinCounterHUDClass := preload("res://scripts/ui/coin_counter_hud.gd")
const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

var _test_failures := 0
var _test_count := 0

func _assert(condition: bool, message: String) -> void:
	_test_count += 1
	if condition:
		print("  [PASS] %s" % message)
	else:
		_test_failures += 1
		printerr("  [FAIL] %s" % message)

func _init() -> void:
	print("==================================================")
	print("=== Running Coin Counter HUD QA Test Suite ===")
	print("==================================================")

	# Mock SaveManager
	var sm = root.get_node_or_null("SaveManager")
	if sm == null:
		var sm_script := GDScript.new()
		sm_script.source_code = """
extends Node
signal coins_changed(new_balance: int)
var _coins: int = 0
func get_coins() -> int:
	return _coins
func set_coins(val: int) -> void:
	_coins = val
	coins_changed.emit(_coins)
func apply_defaults(_defaults: Dictionary) -> void:
	pass
func get_bool(_k: String, fb: bool = false) -> bool:
	return fb
"""
		sm_script.reload()
		sm = Node.new()
		sm.set_script(sm_script)
		sm.name = "SaveManager"
		root.add_child(sm)

	# Mock AudioManager
	var am = root.get_node_or_null("AudioManager")
	if am == null:
		var am_script := GDScript.new()
		am_script.source_code = """
extends Node
const SFX_UI := "ui_click"
var play_count: int = 0
func play(_sfx_name: String) -> void:
	play_count += 1
"""
		am_script.reload()
		am = Node.new()
		am.set_script(am_script)
		am.name = "AudioManager"
		root.add_child(am)

	# Mock GameController
	var gc = root.get_node_or_null("GameController")
	if gc == null:
		var gc_script := GDScript.new()
		gc_script.source_code = """
extends Node
var current_level_number: int = 1
func has_level(n: int) -> bool: return n <= 2
"""
		gc_script.reload()
		gc = Node.new()
		gc.set_script(gc_script)
		gc.name = "GameController"
		root.add_child(gc)

	test_number_formatting()
	test_component_instantiation_and_texture()
	test_balance_loading_and_updates(sm)
	test_responsive_sizing()
	test_plus_button_hitbox_and_modal(sm, am)
	test_zero_inflation_rule(sm)
	test_gameplay_vs_victory_single_counter(gc)

	print("==================================================")
	print("QA Test Results: %d / %d Passed (%d Failed)" % [_test_count - _test_failures, _test_count, _test_failures])
	print("==================================================")

	# Ensure 0 balance and clean exit
	sm.set_coins(0)
	if _test_failures == 0:
		quit(0)
	else:
		quit(1)

func test_number_formatting() -> void:
	print("\n--- Test Suite 1: Coin Formatting ---")
	_assert(CoinCounterHUDClass.format_coins(0) == "0", "0 coins formats as '0'")
	_assert(CoinCounterHUDClass.format_coins(7) == "7", "7 coins formats as '7'")
	_assert(CoinCounterHUDClass.format_coins(50) == "50", "50 coins formats as '50'")
	_assert(CoinCounterHUDClass.format_coins(250) == "250", "250 coins formats as '250'")
	_assert(CoinCounterHUDClass.format_coins(500) == "500", "500 coins formats as '500'")
	_assert(CoinCounterHUDClass.format_coins(1000) == "1,000", "1000 coins formats as '1,000'")
	_assert(CoinCounterHUDClass.format_coins(1250) == "1,250", "1250 coins formats as '1,250'")
	_assert(CoinCounterHUDClass.format_coins(100000) == "100,000", "100000 coins formats as '100,000'")

func test_component_instantiation_and_texture() -> void:
	print("\n--- Test Suite 2: Component Instantiation & Texture ---")
	var counter = CoinCounterHUDClass.new()
	root.add_child(counter)
	counter._ready()
	_assert(counter.texture_rect != null, "TextureRect exists")
	_assert(counter.texture_rect.texture != null, "Texture is successfully loaded")
	_assert(counter.texture_rect.texture.resource_path.ends_with("coin_counter_blank_plus.png"), "Texture points to exact requested PNG")
	_assert(counter.balance_label != null, "Balance Label exists")
	_assert(counter.plus_button != null, "Plus Button exists")
	_assert(counter.coin_target_node != null, "Coin Target Marker exists")
	counter.queue_free()

func test_balance_loading_and_updates(sm: Node) -> void:
	print("\n--- Test Suite 3: Balance Loading & Signal Reactivity ---")
	sm.set_coins(0)
	var counter = CoinCounterHUDClass.new()
	root.add_child(counter)
	counter.set_save_manager(sm)
	counter._ready()
	_assert(counter.balance_label.text == "0", "Initial balance correctly reads 0 from SaveManager")

	sm.set_coins(50)
	_assert(counter.balance_label.text == "50", "Dynamic update: updates to '50' on coins_changed")

	sm.set_coins(1250)
	_assert(counter.balance_label.text == "1,250", "Dynamic update: updates to '1,250' on coins_changed")

	# Test rolling display without modifying save balance
	counter.set_displayed_balance(300)
	_assert(counter.balance_label.text == "300", "set_displayed_balance displays temporary rolling value '300'")
	_assert(sm.get_coins() == 1250, "SaveManager balance remains intact (1250)")

	counter.reset_to_save_manager_balance()
	_assert(counter.balance_label.text == "1,250", "reset_to_save_manager_balance restores authoritative value '1,250'")

	counter.queue_free()

func test_responsive_sizing() -> void:
	print("\n--- Test Suite 4: Responsive Sizing & Proportions ---")
	var counter = CoinCounterHUDClass.new()
	root.add_child(counter)
	counter._ready()

	# Test compact mobile size: width 128, height 32
	counter.size = Vector2(128, 32)
	counter._update_dimensions()
	_assert(counter.size.x == 128.0 and counter.size.y == 32.0, "Sleek compact size 128x32 accepted")
	_assert(counter.plus_button.size.x >= 44.0 and counter.plus_button.size.y >= 44.0, "Touch target on plus button preserves minimum 44x44 touch size even at 32px height")

	# Test target marker position is on left side
	var target_pos = counter.get_coin_target_global_pos()
	_assert(target_pos.x < counter.global_position.x + counter.size.x * 0.4, "Flying coin target marker is located inside the left gold coin area")

	counter.queue_free()

func test_plus_button_hitbox_and_modal(sm: Node, am: Node) -> void:
	print("\n--- Test Suite 5: Plus Button Interaction & Earn Coins Modal ---")
	var counter = CoinCounterHUDClass.new()
	root.add_child(counter)
	counter.set_save_manager(sm)
	counter.set_audio_manager(am)
	counter._ready()

	var state := {"signal_emitted": false}
	counter.plus_pressed.connect(func(): state["signal_emitted"] = true)

	counter._on_plus_button_pressed()
	_assert(state["signal_emitted"], "plus_pressed signal emitted when plus button is tapped")

	var popup = root.get_node_or_null("EarnCoinsPopup")
	if popup == null:
		popup = counter.get_node_or_null("EarnCoinsPopup")
	_assert(popup != null, "EarnCoinsPopup modal appeared in scene tree")

	if popup != null:
		var scrim = popup.get_node_or_null("Scrim")
		_assert(scrim != null and scrim.mouse_filter == Control.MOUSE_FILTER_STOP, "Modal has scrim blocking gameplay input")
		var card = popup.get_node_or_null("CenterContainer/Card")
		_assert(card != null, "Modal card container exists")

		# Close popup
		counter._close_popup(popup)

	counter.queue_free()

func test_zero_inflation_rule(sm: Node) -> void:
	print("\n--- Test Suite 6: Zero Inflation Guarantee ---")
	sm.set_coins(0)
	var initial_coins: int = sm.get_coins()

	var counter = CoinCounterHUDClass.new()
	root.add_child(counter)
	counter.set_save_manager(sm)
	counter._ready()

	# Open and close popup repeatedly
	for i in range(5):
		counter._on_plus_button_pressed()
		var p = root.get_node_or_null("EarnCoinsPopup")
		if p == null:
			p = counter.get_node_or_null("EarnCoinsPopup")
		if p != null:
			counter._close_popup(p)

	_assert(sm.get_coins() == initial_coins, "Tapping plus button 5 times causes ZERO coin inflation (balance remains %d)" % initial_coins)
	counter.queue_free()

func test_gameplay_vs_victory_single_counter(gc: Node) -> void:
	print("\n--- Test Suite 7: Single Counter in Gameplay vs Victory ---")
	gc.current_level_number = 1
	var lvl = CarJamLevelScene.instantiate()
	root.add_child(lvl)
	if not lvl.is_node_ready():
		lvl._ready()

	_assert(lvl.gameplay_coin_counter != null, "gameplay_coin_counter initialized in level HUD")
	_assert(lvl.victory_coin_counter != null, "victory_coin_counter initialized in result overlay")
	_assert(lvl.gameplay_coin_counter.visible == false, "gameplay_coin_counter is hidden during active puzzle play to prevent track occlusion")
	_assert(lvl.victory_coin_counter.visible == false, "victory_coin_counter is hidden during gameplay")

	# Trigger victory celebration
	lvl._start_victory_celebration(0, 50)
	_assert(lvl.gameplay_coin_counter.visible == false, "gameplay_coin_counter remains hidden when victory celebration begins")
	_assert(lvl.victory_coin_counter.visible == true, "victory_coin_counter becomes visible for victory celebration")

	lvl.queue_free()
