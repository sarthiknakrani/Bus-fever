extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n=== TESTING INTERACTIVE SETTINGS BEHAVIOR ===")
	root.get_viewport().size = Vector2i(810, 1746)
	var scn = load("res://scenes/main.tscn")
	var main = scn.instantiate()
	root.add_child(main)
	
	await process_frame
	await process_frame
	
	var s_btn: TextureButton = main.get_node("HomeRoot/HUD/settings_btn")
	
	# Test 1: Open Settings via button press
	s_btn.emit_signal("pressed")
	await process_frame
	await process_frame
	
	var overlay = main.get_node_or_null("HomeRoot/HUD/SettingsOverlay")
	assert(overlay != null, "Overlay must open on pressed!")
	print("[PASS] Settings overlay opened")
	
	# Find toggles
	var center = overlay.get_node("CenterContainer")
	var wrapper = center.get_node("ModalWrapper")
	var panel = wrapper.get_node("PanelContainer")
	var margin = panel.get_node("MarginContainer")
	var vbox = margin.get_node("MainVBox")
	var toggles = vbox.get_node("TogglesVBox")
	
	print("Toggles count: ", toggles.get_child_count())
	assert(toggles.get_child_count() == 3, "Must have 3 toggles (Sound, Music, Vibration)")
	
	# Test toggling Sound
	var sound_row = toggles.get_child(0)
	var sound_pill_center = sound_row.get_child(3)
	var sound_pill = sound_pill_center.get_child(0)
	var sound_hit_btn: Button
	for c in sound_pill.get_children():
		if c is Button:
			sound_hit_btn = c
			break
	assert(sound_hit_btn != null, "Sound toggle button found")
	
	var sm = root.get_node("/root/SettingsManager")
	var initial_sfx = sm.sfx_enabled()
	sound_hit_btn.emit_signal("pressed")
	assert(sm.sfx_enabled() == not initial_sfx, "Sound toggle flipped setting")
	print("[PASS] Sound toggle works (new state: %s)" % sm.sfx_enabled())
	
	# Test Scrim dismissal
	var scrim: ColorRect = overlay.get_node("Scrim")
	# Stray release without press should NOT close scrim
	var stray_release = InputEventMouseButton.new()
	stray_release.button_index = MOUSE_BUTTON_LEFT
	stray_release.pressed = false
	scrim.gui_input.emit(stray_release)
	await process_frame
	assert(main.get_node_or_null("HomeRoot/HUD/SettingsOverlay") != null, "Stray release must NOT close overlay")
	print("[PASS] Guarded against stray release closure")
	
	# Full press + release on scrim SHOULD close it
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	scrim.gui_input.emit(press)
	
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	scrim.gui_input.emit(release)
	
	await process_frame
	await process_frame
	assert(main.get_node_or_null("HomeRoot/HUD/SettingsOverlay") == null, "Press+Release on scrim closed overlay")
	print("[PASS] Full press+release on scrim successfully closed overlay")
	
	# Re-open and close with Close button
	s_btn.emit_signal("pressed")
	await process_frame
	await process_frame
	overlay = main.get_node_or_null("HomeRoot/HUD/SettingsOverlay")
	assert(overlay != null, "Re-opened overlay successfully")
	
	var re_wrapper = overlay.get_node("CenterContainer/ModalWrapper")
	var close_btn: Button = re_wrapper.get_node("CloseButton")
	assert(close_btn != null, "Close button found")
	close_btn.emit_signal("pressed")
	await process_frame
	await process_frame
	assert(main.get_node_or_null("HomeRoot/HUD/SettingsOverlay") == null, "Close button closed overlay")
	print("[PASS] Close button successfully closed overlay")
	
	print("\n=======================================================")
	print("=== ALL INTERACTIVE SETTINGS TESTS PASSED (0 ERRORS) ===")
	print("=======================================================")
	quit()
