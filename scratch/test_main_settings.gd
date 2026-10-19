extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var resolutions = [
		Vector2i(390, 844),
		Vector2i(720, 1280),
		Vector2i(810, 1746),
		Vector2i(1080, 1920)
	]
	
	for res in resolutions:
		print("\n--- Testing Resolution: %dx%d ---" % [res.x, res.y])
		root.get_viewport().size = res
		var scn = load("res://scenes/main.tscn")
		var main = scn.instantiate()
		root.add_child(main)
		
		await process_frame
		await process_frame
		
		# Press settings button
		var s_btn: TextureButton = main.get_node("HomeRoot/HUD/settings_btn")
		s_btn.emit_signal("pressed")
		
		await process_frame
		await process_frame
		
		var overlay = main.get_node_or_null("HomeRoot/HUD/SettingsOverlay")
		assert(overlay != null, "Overlay must exist!")
		
		var center: CenterContainer
		for c in overlay.get_children():
			if c is CenterContainer:
				center = c
				break
		assert(center != null, "CenterContainer must exist!")
		
		var wrapper: Control = center.get_child(0) as Control
		var panel: Control
		for c in wrapper.get_children():
			if c is PanelContainer:
				panel = c
				break
		assert(panel != null, "PanelContainer must exist!")
		
		var vp_rect = Rect2(Vector2.ZERO, overlay.size)
		var wrapper_rect = Rect2(wrapper.position, wrapper.size)
		
		print("Canvas size: %s | Wrapper rect: %s" % [overlay.size, wrapper_rect])
		print("Is wrapper centered and fully inside viewport? ", vp_rect.encloses(wrapper_rect))
		assert(vp_rect.encloses(wrapper_rect), "Settings dialog must be fully visible within viewport!")
		
		var expected_center_x = (overlay.size.x - wrapper.size.x) * 0.5
		var expected_center_y = (overlay.size.y - wrapper.size.y) * 0.5
		print("Diff from canvas center: (%.1f, %.1f)" % [abs(wrapper.position.x - expected_center_x), abs(wrapper.position.y - expected_center_y)])
		assert(abs(wrapper.position.x - expected_center_x) <= 2.0, "Must be centered on X")
		assert(abs(wrapper.position.y - expected_center_y) <= 2.0, "Must be centered on Y")
		
		# Test Close Button
		var close_btn: Button
		for c in wrapper.get_children():
			if c is Button:
				close_btn = c
				break
		assert(close_btn != null, "Close button must exist!")
		close_btn.emit_signal("pressed")
		await process_frame
		await process_frame
		assert(main.get_node_or_null("HomeRoot/HUD/SettingsOverlay") == null, "Overlay must close on close_btn press!")
		print("[PASS] Resolution %dx%d: Centered perfectly and closed cleanly!" % [res.x, res.y])
		
		main.queue_free()
		await process_frame
		await process_frame
	
	print("\n==============================================")
	print("=== ALL SETTINGS MODAL QA TESTS PASSED OK ===")
	print("==============================================")
	quit()
