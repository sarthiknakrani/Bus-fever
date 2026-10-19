extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TESTING COMPLETE INPUT FLOW FOR SETTINGS & PLAY BUTTONS ---")
	var scn = load("res://scenes/main.tscn")
	var inst = scn.instantiate()
	root.add_child(inst)
	root.get_viewport().size = Vector2i(390, 844)

	await process_frame
	await process_frame

	var s_btn: TextureButton = inst.get_node("HomeRoot/HUD/settings_btn")
	var p_btn: TextureButton = inst.get_node("HomeRoot/HUD/PlayButton")

	# Test 1: Touch Screen input on Settings Button
	print("Test 1: Simulating Touch on Settings button...")
	var touch_s := InputEventScreenTouch.new()
	touch_s.position = s_btn.get_global_rect().get_center()
	touch_s.pressed = true
	s_btn.gui_input.emit(touch_s)
	touch_s.pressed = false
	s_btn.gui_input.emit(touch_s)
	await process_frame

	var overlay = inst.get_node_or_null("SettingsOverlay")
	assert(overlay != null, "SettingsOverlay should open on touch!")
	print("  [PASS] Settings opened successfully via touch input.")

	# Close settings overlay
	overlay.queue_free()
	await process_frame

	# Test 2: Touch Screen input on Play Button
	print("Test 2: Simulating Touch on Play button...")
	var touch_p := InputEventScreenTouch.new()
	touch_p.position = p_btn.get_global_rect().get_center()
	touch_p.pressed = true
	p_btn.gui_input.emit(touch_p)
	touch_p.pressed = false
	p_btn.gui_input.emit(touch_p)
	await process_frame
	await process_frame

	var gc = root.get_node_or_null("GameController")
	assert(gc != null and gc.current_scene_path() == "res://scenes/level1.tscn", "Should transition to level1!")
	print("  [PASS] Play button transitioned to level 1 successfully via touch input.")

	print("=== ALL INPUT TESTS PASSED! ===")
	quit(0)
