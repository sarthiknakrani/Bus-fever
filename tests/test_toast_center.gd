extends SceneTree

var CarJamLevelScene = preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("==========================================")
	print("=== TOAST SCREEN-CENTER VERIFICATION ===")
	print("==========================================")
	
	var passed = 0
	var failed = 0
	
	var level: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(level)
	if not level.is_node_ready():
		level._ready()
	
	await create_timer(0.1).timeout
	
	# TEST 1: Hierarchy and Node Placement
	print("\n--- TEST 1: Toast Node Hierarchy & Layering ---")
	if level._toast_container != null and is_instance_valid(level._toast_container):
		var p = level._toast_container.get_parent()
		if p == level.hud:
			print("  [PASS] _toast_container is a direct child of HUD (CanvasLayer)")
			passed += 1
		else:
			print("  [FAIL] _toast_container parent is: ", p.name if p else "null")
			failed += 1
			
		if level._toast_container is CenterContainer:
			print("  [PASS] _toast_container is CenterContainer")
			passed += 1
		else:
			print("  [FAIL] _toast_container is not CenterContainer")
			failed += 1
			
		if level._toast_container.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			print("  [PASS] _toast_container mouse_filter is MOUSE_FILTER_IGNORE")
			passed += 1
		else:
			print("  [FAIL] _toast_container blocks input!")
			failed += 1
	else:
		print("  [FAIL] _toast_container is null!")
		failed += 3
		
	# TEST 2: Anchors and Offsets
	print("\n--- TEST 2: Anchors Preset & Offsets ---")
	var tc = level._toast_container
	if tc:
		var is_full_rect = (
			tc.anchor_left == 0.0 and
			tc.anchor_top == 0.0 and
			tc.anchor_right == 1.0 and
			tc.anchor_bottom == 1.0 and
			tc.offset_left == 0.0 and
			tc.offset_top == 0.0 and
			tc.offset_right == 0.0 and
			tc.offset_bottom == 0.0
		)
		if is_full_rect:
			print("  [PASS] ToastContainer has PRESET_FULL_RECT with zero offsets (no top offsets)")
			passed += 1
		else:
			print("  [FAIL] ToastContainer anchors/offsets not full-rect: ", 
				[tc.anchor_left, tc.anchor_top, tc.anchor_right, tc.anchor_bottom],
				[tc.offset_left, tc.offset_top, tc.offset_right, tc.offset_bottom])
			failed += 1
			
	# TEST 3: Center alignment across 3 standard viewports
	print("\n--- TEST 3: Visual Center Alignment Across Resolutions ---")
	var resolutions = [
		Vector2i(720, 1280),
		Vector2i(1080, 1920),
		Vector2i(390, 844)
	]
	
	for res in resolutions:
		DisplayServer.window_set_size(res)
		root.size = res
		await create_timer(0.05).timeout
		level._update_layout()
		
		# Reset debounce & trigger toast
		level._last_toast_time = -999.0
		level._show_parking_full_toast()
		await create_timer(0.05).timeout
		
		var vp = level.get_viewport()
		var vis_rect = vp.get_visible_rect()
		var panel = level._toast_panel
		var panel_rect = panel.get_global_rect()
		var logical_center = panel_rect.get_center()
		var expected_logical_center = vis_rect.size / 2.0
		
		var delta_logical = (logical_center - expected_logical_center).abs()
		
		# Screen space calculation
		var screen_scale = Vector2(float(res.x) / vis_rect.size.x, float(res.y) / vis_rect.size.y)
		var screen_center = logical_center * screen_scale
		var expected_screen_center = Vector2(res) / 2.0
		var delta_screen = (screen_center - expected_screen_center).abs()
		
		print("  Resolution: %dx%d" % [res.x, res.y])
		print("    Visible rect: %s, Logical center: %s, Expected: %s (diff: %s)" % [
			vis_rect.size, logical_center, expected_logical_center, delta_logical
		])
		print("    Screen center: %s, Expected: %s (diff: %s)" % [
			screen_center, expected_screen_center, delta_screen
		])
		
		if delta_logical.x <= 1.0 and delta_logical.y <= 1.0 and delta_screen.x <= 1.0 and delta_screen.y <= 1.0:
			print("    [PASS] Popup is at exact visual center (+/- 1px)")
			passed += 1
		else:
			print("    [FAIL] Center error exceeds 1px!")
			failed += 1
			
	# TEST 4: Pivot Stability (No Drift During Scale Animation)
	print("\n--- TEST 4: Pivot Stability During Scale ---")
	var p = level._toast_panel
	var half_size = p.size / 2.0
	var pivot_diff = (p.pivot_offset - half_size).abs()
	print("  Panel size: ", p.size)
	print("  Pivot offset: ", p.pivot_offset, " (Expected: ", half_size, ")")
	if pivot_diff.x <= 0.1 and pivot_diff.y <= 0.1:
		print("  [PASS] Pivot is centered on panel (zero drifting during scale tween)")
		passed += 1
	else:
		print("  [FAIL] Pivot offset not centered on panel: diff = ", pivot_diff)
		failed += 1
		
	print("\n==========================================")
	print("SUMMARY: %d passed, %d failed" % [passed, failed])
	print("==========================================")
	
	level.queue_free()
	if failed > 0:
		quit(1)
	else:
		quit(0)
