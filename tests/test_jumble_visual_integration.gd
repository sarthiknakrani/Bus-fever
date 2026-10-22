extends SceneTree

const ARTIFACT_DIR := "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827"
const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("\n=======================================================")
	print("=== JUMBLE COLOR ALTERNATIVE VISUAL INTEGRATION TEST ===")
	print("=======================================================\n")

	var win_size := Vector2i(540, 960)
	var vp := SubViewport.new()
	vp.size = win_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var gc = root.get_node_or_null("GameController")
	if gc == null:
		gc = load("res://scripts/autoload/game_controller.gd").new()
		gc.name = "GameController"
		root.add_child(gc)
	gc.current_level_number = 1

	var lvl: CarJamLevel = CarJamLevelScene.instantiate()
	lvl.enable_entrance_parade = false
	vp.add_child(lvl)
	if not lvl.is_node_ready():
		lvl._ready()

	if lvl.camera_2d != null:
		lvl.camera_2d.enabled = true
		lvl.camera_2d.make_current()
	lvl._update_layout(Vector2(win_size))

	# Wait a few frames for layout
	for f in 15:
		await process_frame
		lvl._process(1.0 / 60.0)

	var ctrl: CarJamController = lvl.controller
	assert(ctrl != null, "Controller must exist")
	assert(ctrl.is_jumble_available(), "Jumble booster must start available")

	# Snapshot pre-jumble colors
	var pre_colors: Dictionary = {}
	var pre_views: Dictionary = {}
	for vid in ctrl.vehicles:
		var v = ctrl.vehicles[vid]
		if v.state == VehicleModel.VehicleState.ON_BOARD:
			pre_colors[vid] = v.color_id
			var vv = lvl.vehicle_views.get(vid, null)
			assert(vv != null, "VehicleView for bus %d must exist" % vid)
			pre_views[vid] = vv.vehicle_color_id

	print("[Test 1] Pre-jumble bus colors:")
	for vid in pre_colors:
		print("  Bus %d: Model=%s, View=%s" % [vid, pre_colors[vid], pre_views[vid]])

	# Save pre-jumble screenshot
	var img_pre = vp.get_texture().get_image()
	if img_pre != null:
		img_pre.save_png(ARTIFACT_DIR + "/jumble_before_colors.png")
		print("  [SAVED] jumble_before_colors.png")

	# Press Jumble button
	print("\n[Test 2] Pressing Jumble button...")
	lvl._on_jumble_button_pressed()

	for f in 20:
		await process_frame
		lvl._process(1.0 / 60.0)

	# Verify post-jumble state
	var post_colors: Dictionary = {}
	var post_views: Dictionary = {}
	var all_alternative: bool = true
	var existing_colors := ["red", "blue", "yellow"]

	for vid in pre_colors:
		var v = ctrl.vehicles[vid]
		var vv = lvl.vehicle_views[vid]
		post_colors[vid] = v.color_id
		post_views[vid] = vv.vehicle_color_id
		assert(post_colors[vid] == post_views[vid], "View color must match model color for bus %d" % vid)
		assert(existing_colors.has(post_colors[vid]), "Bus %d color '%s' must be an existing color" % [vid, post_colors[vid]])
		if post_colors[vid] == pre_colors[vid]:
			all_alternative = false
		print("  Bus %d: Was %s -> Now %s (Alternative: %s)" % [
			vid, pre_colors[vid], post_colors[vid], str(post_colors[vid] != pre_colors[vid])
		])

	assert(all_alternative, "EVERY SINGLE bus must change to an alternative color")
	print("  [PASS] All buses changed to alternative colors with zero new colors added!\n")

	# Save post-jumble screenshot
	var img_post = vp.get_texture().get_image()
	if img_post != null:
		img_post.save_png(ARTIFACT_DIR + "/jumble_after_colors.png")
		print("  [SAVED] jumble_after_colors.png")

	# Verify single-use
	print("[Test 3] Verifying single-use constraint...")
	assert(not ctrl.is_jumble_available(), "Jumble must be marked consumed")
	lvl._on_jumble_button_pressed()
	# Color must remain unchanged
	for vid in pre_colors:
		assert(ctrl.vehicles[vid].color_id == post_colors[vid], "Bus %d color must not change on second press" % vid)
	print("  [PASS] Single-use constraint verified\n")

	# Verify boarding continues seamlessly with newly assigned colors
	print("[Test 4] Dispatching jumbled bus into parking bay...")
	# Find unblocked bus
	var disp_vid: int = -1
	for vid in pre_colors:
		var v = ctrl.vehicles[vid]
		if ctrl.board.check_swept_escape(v)["can_escape"]:
			disp_vid = vid
			break
	assert(disp_vid != -1, "Must find an unblocked bus to dispatch")
	var disp_color = ctrl.vehicles[disp_vid].color_id
	print("  Dispatching bus %d (new color: %s)..." % [disp_vid, disp_color])
	var ok_disp = ctrl.tap_vehicle(disp_vid)
	assert(ok_disp, "Dispatch must succeed")

	# Step frames to let bus arrive and circulating passengers board
	var boarded := false
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await process_frame
		lvl._process(1.0 / 60.0)
		if ctrl.vehicles[disp_vid].passenger_occupancy > 0:
			boarded = true
			break

	print("  Bus %d occupancy: %d / %d" % [disp_vid, ctrl.vehicles[disp_vid].passenger_occupancy, ctrl.vehicles[disp_vid].capacity])
	assert(boarded, "Matching circulating passengers must board the newly jumbled bus")
	print("  [PASS] Boarding works seamlessly with newly jumbled bus color!\n")

	print("=======================================================")
	print("=== ALL JUMBLE COLOR TESTS PASSED! ===")
	print("=======================================================\n")
	quit(0)
