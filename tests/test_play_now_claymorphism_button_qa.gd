extends SceneTree

const CoinCounterHUDClass := preload("res://scripts/ui/coin_counter_hud.gd")
const MainScene := preload("res://scenes/main.tscn")

var _failures := 0
var _tests := 0

func _assert(cond: bool, msg: String) -> void:
	_tests += 1
	if cond:
		print("  [PASS] %s" % msg)
	else:
		_failures += 1
		printerr("  [FAIL] %s" % msg)

func _init() -> void:
	print("==========================================================")
	print("=== Running QA: 'PLAY NOW!' Button Claymorphism Suite ===")
	print("==========================================================")

	call_deferred("_run_qa")

func _run_qa() -> void:
	# Mock SaveManager
	var sm = root.get_node_or_null("SaveManager")
	if sm == null:
		var sm_script := GDScript.new()
		sm_script.source_code = """
extends Node
signal coins_changed(new_balance: int)
var _coins: int = 100
func get_coins() -> int: return _coins
func set_coins(v: int) -> void: _coins = v; coins_changed.emit(_coins)
func apply_defaults(_d: Dictionary) -> void: pass
func get_bool(_k: String, fb: bool = false) -> bool: return fb
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
var play_count: int = 0
func play(_s: String) -> void: play_count += 1
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
var started_level: int = 0
func start_level(n: int) -> void: started_level = n
"""
		gc_script.reload()
		gc = Node.new()
		gc.set_script(gc_script)
		gc.name = "GameController"
		root.add_child(gc)

	await test_play_now_button_orange_claymorphism()
	await test_got_it_button_green_claymorphism()
	await test_home_screen_integration_and_click()

	for i in range(10):
		await process_frame

	print("==========================================================")
	print("QA Result: %d / %d Passed (%d Failed)" % [_tests - _failures, _tests, _failures])
	print("==========================================================")
	if _failures == 0:
		quit(0)
	else:
		quit(1)

func test_play_now_button_orange_claymorphism() -> void:
	print("\n--- 1. Testing 'PLAY NOW!' Orange Claymorphism Button ---")
	var hud := CoinCounterHUDClass.new()
	root.add_child(hud)
	hud._ready()

	var state := {"callback_invoked": false}
	hud.set_custom_action("PLAY NOW!", func(): state["callback_invoked"] = true)
	hud.show_earn_coins_popup()

	var popup = root.get_node_or_null("EarnCoinsPopup")
	_assert(popup != null, "EarnCoinsPopup opened in scene")
	if popup == null:
		hud.queue_free()
		return

	var act_btn: Button = null
	for b in popup.find_children("*", "Button", true, false):
		if b.text == "PLAY NOW!":
			act_btn = b
			break

	_assert(act_btn != null, "'PLAY NOW!' button exists in popup")
	if act_btn != null:
		# Check stylebox overrides: normal, hover, pressed, hover_pressed, focus, disabled
		var normal_style = act_btn.get_theme_stylebox("normal")
		var hover_style = act_btn.get_theme_stylebox("hover")
		var pressed_style = act_btn.get_theme_stylebox("pressed")
		var focus_style = act_btn.get_theme_stylebox("focus")
		var disabled_style = act_btn.get_theme_stylebox("disabled")

		_assert(normal_style is StyleBoxFlat, "normal style is StyleBoxFlat")
		_assert(hover_style is StyleBoxFlat, "hover style is overridden with StyleBoxFlat (NEVER default grey)")
		_assert(pressed_style is StyleBoxFlat, "pressed style is StyleBoxFlat")
		_assert(focus_style is StyleBoxEmpty, "focus style is StyleBoxEmpty (no blue/grey focus border)")
		_assert(disabled_style is StyleBoxFlat, "disabled style is StyleBoxFlat")

		var sbf_normal := normal_style as StyleBoxFlat
		_assert(sbf_normal.bg_color.is_equal_approx(Color("fb923c")), "Face color is vibrant clay orange (#fb923c)")
		_assert(sbf_normal.border_color.is_equal_approx(Color("c2410c")), "Bottom 3D rim is rich clay orange lip (#c2410c)")
		_assert(sbf_normal.border_width_bottom >= 4, "3D bottom lip thickness >= 4px")
		_assert(sbf_normal.corner_radius_top_left >= 20, "Rounded pillowed corners >= 20px")
		_assert(sbf_normal.shadow_size >= 10, "Warm ambient drop shadow size >= 10px")

		var sbf_hover := hover_style as StyleBoxFlat
		_assert(sbf_hover.bg_color.is_equal_approx(Color("fdba74")), "Hover face color is soft bright clay highlight (#fdba74)")

		# Check gloss panel child
		var has_gloss := false
		for c in act_btn.get_children():
			if c is Panel:
				has_gloss = true
				break
		_assert(has_gloss, "'PLAY NOW!' button has specular gloss highlight overlay")

		# Check typography outline
		_assert(act_btn.get_theme_color("font_color") == Color.WHITE, "Font color is crisp white")
		_assert(act_btn.get_theme_color("font_outline_color").is_equal_approx(Color("7c2d12")), "Font outline is dark clay orange (#7c2d12)")
		_assert(act_btn.get_theme_constant("outline_size") >= 4, "Font outline size >= 4")

		# Check button click callback
		act_btn.emit_signal("pressed")
		_assert(state["callback_invoked"], "Clicking 'PLAY NOW!' button triggers custom action callback")

	popup.queue_free()
	hud.queue_free()
	for i in range(5):
		await process_frame

func test_got_it_button_green_claymorphism() -> void:
	print("\n--- 2. Testing Default 'GOT IT!' Green Claymorphism Button ---")
	var hud := CoinCounterHUDClass.new()
	root.add_child(hud)
	hud._ready()

	hud.show_earn_coins_popup()
	var popup = root.get_node_or_null("EarnCoinsPopup")
	_assert(popup != null, "EarnCoinsPopup opened with default 'GOT IT!' action")
	if popup == null:
		hud.queue_free()
		return

	var act_btn: Button = null
	for b in popup.find_children("*", "Button", true, false):
		if b.text == "GOT IT!":
			act_btn = b
			break

	_assert(act_btn != null, "'GOT IT!' button exists in popup")
	if act_btn != null:
		var normal_style = act_btn.get_theme_stylebox("normal") as StyleBoxFlat
		_assert(normal_style != null, "'GOT IT!' button has normal StyleBoxFlat")
		if normal_style != null:
			_assert(normal_style.bg_color.is_equal_approx(Color("22c55e")), "'GOT IT!' button uses vibrant green (#22c55e)")
			_assert(normal_style.border_color.is_equal_approx(Color("15803d")), "'GOT IT!' button uses dark green rim (#15803d)")

		var hover_style = act_btn.get_theme_stylebox("hover") as StyleBoxFlat
		_assert(hover_style != null and hover_style.bg_color.is_equal_approx(Color("4ade80")), "'GOT IT!' hover is bright green (#4ade80)")

	popup.queue_free()
	hud.queue_free()
	for i in range(5):
		await process_frame

func test_home_screen_integration_and_click() -> void:
	print("\n--- 3. Testing Home Screen Integration & Click Stability ---")
	var main = MainScene.instantiate()
	root.add_child(main)
	main._ready()

	var coin_hud = main.find_child("CoinCounterHUD", true, false)
	_assert(coin_hud != null, "CoinCounterHUD on Home screen exists")
	if coin_hud != null and coin_hud.has_method("show_earn_coins_popup"):
		coin_hud.show_earn_coins_popup()
		var popup = root.find_child("EarnCoinsPopup", true, false)
		_assert(popup != null, "EarnCoinsPopup opened on Home screen")
		if popup != null:
			var act_btn: Button = null
			for b in popup.find_children("*", "Button", true, false):
				if b.text == "PLAY NOW!":
					act_btn = b
					break
			_assert(act_btn != null, "Home screen popup action button is 'PLAY NOW!'")
			if act_btn != null:
				var init_pos := act_btn.position
				act_btn.emit_signal("button_down")
				act_btn.emit_signal("button_up")
				_assert(act_btn.position == init_pos, "'PLAY NOW!' button did not suffer position displacement on click")
			popup.queue_free()

	main.queue_free()
	for i in range(5):
		await process_frame
