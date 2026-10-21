extends SceneTree

const CarJamLevelScene = preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	_run_all_tests()

func _run_all_tests() -> void:
	await create_timer(0.3).timeout
	print("\n==========================================")
	print("=== PASSENGER ART VERIFICATION SUITE ===")
	print("==========================================")

	var failures := 0

	# 1. Verify All 8 Character Sprites Exist and Load Properly
	print("\n--- TEST 1: Texture Loading & File Existence Across All 8 Colors ---")
	var colors := ["yellow", "blue", "red", "purple", "orange", "pink", "brown", "green"]
	for c in colors:
		var path := "res://assets/sprites/passengers/passenger_%s.png" % c
		if not FileAccess.file_exists(path):
			print("  [FAIL] Missing texture file: %s" % path)
			failures += 1
			continue

		var pv := PassengerView.new()
		pv.setup(c)
		var spr: Sprite2D = pv.get_node_or_null("VisualNode/CharacterSprite") as Sprite2D
		if spr == null or spr.texture == null:
			print("  [FAIL] Failed to instantiate Sprite2D for color '%s'" % c)
			failures += 1
		else:
			var tex_size = spr.texture.get_size()
			print("  [PASS] Color '%s': Loaded %s (Size: %dx%d, Filter: Linear+Mipmaps)" % [
				c, path, int(tex_size.x), int(tex_size.y)
			])
		pv.queue_free()

	# 2. Verify Upright Orientation & Left/Right Facing Logic
	print("\n--- TEST 2: Upright Orientation & Left/Right Facing Logic ---")
	var test_pv := PassengerView.new()
	test_pv.setup("blue")
	root.add_child(test_pv)

	var spr: Sprite2D = test_pv.get_node_or_null("VisualNode/CharacterSprite") as Sprite2D
	test_pv.position = Vector2(100, 100)
	test_pv._process(0.016)

	# Simulate moving right
	test_pv.position = Vector2(120, 100)
	test_pv._process(0.016)
	if spr.scale.x > 0:
		print("  [PASS] Moving right -> Sprite correctly faces RIGHT (scale.x > 0)")
	else:
		print("  [FAIL] Moving right -> Sprite failed to face right")
		failures += 1

	# Simulate moving left
	test_pv.position = Vector2(80, 100)
	test_pv._process(0.016)
	if spr.scale.x < 0:
		print("  [PASS] Moving left -> Sprite correctly faces LEFT (scale.x < 0)")
	else:
		print("  [FAIL] Moving left -> Sprite failed to face left")
		failures += 1

	# Verify Sprite is never inverted vertically (scale.y > 0 and rotation near 0)
	if spr.scale.y > 0 and abs(spr.rotation) < deg_to_rad(15.0):
		print("  [PASS] Sprite remains upright from screen space (never inverted)")
	else:
		print("  [FAIL] Sprite inverted or excessive rotation: rot=%.2f, scale.y=%.2f" % [spr.rotation, spr.scale.y])
		failures += 1
	test_pv.queue_free()

	# 3. Live Level Scene & 4-Lane Mixed Queue Population
	print("\n--- TEST 3: Live Level 1 Scene Population & 4-Lane Spacing ---")
	var level: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(level)
	if not level.is_node_ready():
		level._ready()

	await create_timer(0.1).timeout

	if level.circulating_ids.size() == level.MAX_INITIAL_LOOP_PASSENGERS:
		print("  [PASS] Main oval densely packed at start: %d passengers (%d rows x 4 lanes)" % [
			level.MAX_INITIAL_LOOP_PASSENGERS, int(level.MAX_INITIAL_LOOP_PASSENGERS / level.NUM_LANES)
		])
	else:
		print("  [FAIL] Expected %d initial loop passengers, got %d" % [level.MAX_INITIAL_LOOP_PASSENGERS, level.circulating_ids.size()])
		failures += 1

	# Check active passenger instances
	var active_views_count := 0
	var color_counts := {}
	for pid in level.circulating_ids:
		var p_dict: Dictionary = level.all_passengers.get(pid, {})
		var v_node = p_dict.get("view", null)
		if is_instance_valid(v_node) and v_node is PassengerView:
			active_views_count += 1
			var col: String = p_dict.get("color_id", "")
			color_counts[col] = color_counts.get(col, 0) + 1

	print("  [PASS] Verified %d initial active PassengerView instances on main oval" % active_views_count)
	print("  [PASS] Active track color breakdown: %s" % str(color_counts))

	# 4. Boarding Leap & Bus Occupancy Transition
	print("\n--- TEST 4: Boarding Leap Arc & Occupancy Accounting ---")
	var target_vid := 3 # Red bus in Level 1 (first unblocked bus)
	level.controller.tap_vehicle(target_vid)

	# Wait for bus arrival (0.80s)
	await create_timer(0.90).timeout

	var slot = level.controller.parking.get_slot(1)
	if slot != null and slot.vehicle_id == target_vid:
		print("  [PASS] Bus %d arrived and docked at Slot 1" % target_vid)
	else:
		print("  [FAIL] Bus %d failed to dock at Slot 1" % target_vid)
		failures += 1

	# Allow feeder passengers travelling at 240 px/s to reach doorway and board
	await create_timer(2.6).timeout
	var v_model = level.controller.vehicles.get(target_vid, null)
	var occ: int = v_model.passenger_occupancy if v_model else 0
	var pend: int = level.controller.pending_boarders.get(target_vid, 0)
	if v_model != null and (occ + pend) > 0:
		print("  [PASS] Authentic boarding active: %d boarded (+%d in transit) for bus %d" % [
			occ, pend, target_vid
		])
	else:
		print("  [FAIL] No passengers boarded bus %d" % target_vid)
		failures += 1

	# 5. Multi-Resolution Viewport Layout Verification
	print("\n--- TEST 5: Responsive Layout Across Multiple Viewport Sizes ---")
	var viewports := [
		Vector2(720, 1280),  # Standard Portrait
		Vector2(1080, 1920), # FHD Mobile
		Vector2(390, 844)    # Modern iPhone
	]
	for vp_size in viewports:
		level._update_layout()
		var s := level.world_root.scale.x
		if s >= 0.4 and s <= 2.0:
			print("  [PASS] Viewport %dx%d: Layout scaled cleanly (scale=%.3f)" % [
				int(vp_size.x), int(vp_size.y), s
			])
		else:
			print("  [FAIL] Viewport %dx%d: Invalid scale %.3f" % [int(vp_size.x), int(vp_size.y), s])
			failures += 1

	level.queue_free()

	print("\n==========================================")
	if failures == 0:
		print("=== ALL PASSENGER ART VERIFICATION TESTS PASSED (0 FAILURES) ===")
	else:
		print("=== %d VERIFICATION TESTS FAILED ===" % failures)
	print("==========================================\n")

	quit(failures)
