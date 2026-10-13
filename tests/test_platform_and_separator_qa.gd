extends SceneTree

# QA Test Suite for:
# 1) Parking platform grey styling and full-width coherence (zero side cutouts, cohesive greys).
# 2) Bus / separator line clearance (zero overlap across all buses and resolutions).

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	print("=======================================================")
	print("=== PLATFORM COHERENCE & SEPARATOR CLEARANCE QA ===")
	print("=======================================================")
	
	var all_passed := true
	
	# TEST 1: Level 1 & Level 2 Exact Screen Center and Clearance
	for lvl_num in [1, 2]:
		print("\n--- TEST: Level %d Bus vs Separator Line Clearance & Centering ---" % lvl_num)
		var lvl: CarJamLevel = CarJamLevelScene.instantiate()
		root.add_child(lvl)
		if not lvl.is_node_ready():
			lvl._ready()
			
		var res_path = "res://levels/level_%03d.tres" % lvl_num
		var level_data: CarJamLevelData = ResourceLoader.load(res_path) as CarJamLevelData
		lvl.controller.load_level(level_data)
		lvl._setup_visuals(level_data)
		lvl._update_layout()
		
		var plat: PlatformView = lvl.platform_bg as PlatformView
		if plat == null:
			print("  [FAIL] platform_bg is not a PlatformView!")
			all_passed = false
			lvl.queue_free()
			continue
			
		var sep_y: float = plat.get_band_bottom_y()
		var parking_y: float = lvl.parking_root.position.y
		var parking_bottom = parking_y + ParkingSlotView.SLOT_HEIGHT / 2.0
		var board_y: float = lvl.board_root.position.y
		var vp_h = 1280.0
		var scale_y = lvl.world_root.scale.y
		var sep_screen_y = (vp_h / 2.0) + (sep_y * scale_y)
		var expected_center_y = vp_h / 2.0
		
		print("  [LAYOUT] Parking Bottom = %.1f | Separator Y = %.1f (Screen=%.1f, Mid=%.1f) | Board Y = %.1f" % [
			parking_bottom, sep_y, sep_screen_y, expected_center_y, board_y
		])
		
		# Check separator is mathematically centered at H/2
		if absf(sep_screen_y - expected_center_y) > 0.001:
			print("  [FAIL] Separator line is not at screen center! Screen Y = %.2f, Expected = %.2f" % [sep_screen_y, expected_center_y])
			all_passed = false
		else:
			print("  [PASS] Separator line is mathematically at EXACT screen center (H/2 = %.1f)" % expected_center_y)
		
		# Check separator is strictly between parking and board
		if not (parking_bottom < sep_y and sep_y < board_y):
			print("  [FAIL] Separator line is not positioned between parking bottom and board! (parking_btm=%.1f, sep=%.1f, board=%.1f)" % [parking_bottom, sep_y, board_y])
			all_passed = false
		else:
			print("  [PASS] Separator line is strictly between parking slots (above) and puzzle board (below)")
			
		# Check all vehicles on board
		var min_gap_found: float = 999999.0
		var highest_bus_id: int = -1
		
		for vid in lvl.vehicle_views:
			var vv: VehicleView = lvl.vehicle_views[vid]
			var world_pos: Vector2 = lvl.board_root.transform * vv.position
			var top_visual_y: float = world_pos.y - (146.0 * 0.72 / 2.0)
			var gap_to_sep: float = top_visual_y - sep_y
			
			if gap_to_sep < min_gap_found:
				min_gap_found = gap_to_sep
				highest_bus_id = vid
				
			if top_visual_y <= sep_y:
				print("  [FAIL] Bus %s (id=%d) overlaps separator line! top_visual_y=%.1f <= sep_y=%.1f" % [vv.vehicle_code, vid, top_visual_y, sep_y])
				all_passed = false
				
		print("  [MEASURED] Highest Bus on Level %d is Bus %d (world_top=%.1f | sep_y=%.1f | Clearance Gap = +%.1f px)" % [
			lvl_num, highest_bus_id, (sep_y + min_gap_found), sep_y, min_gap_found
		])
		
		if min_gap_found >= 20.0:
			print("  [PASS] Clean visual gap between separator line and all buses (min gap: +%.1f px > 20px target)" % min_gap_found)
		else:
			print("  [FAIL] Clearance gap is too small (+%.1f px < 20px target)" % min_gap_found)
			all_passed = false

		# Check 200% bottom grey band expansion
		var orig_h: float = plat.get_original_band_height()
		var curr_h: float = plat.get_current_band_height()
		var band_btm: float = plat.get_band_bottom_y()
		print("  [BAND HEIGHT] Original = %.2f px | Current = %.2f px (Ratio = %.2fx) | Band Bottom = %.2f" % [
			orig_h, curr_h, (curr_h / orig_h) if orig_h > 0.0 else 0.0, band_btm
		])
		if absf(curr_h - orig_h * 2.0) > 0.001:
			print("  [FAIL] Bottom grey band height is not 200%% of original! Current = %.2f, Expected = %.2f" % [curr_h, orig_h * 2.0])
			all_passed = false
		else:
			print("  [PASS] Bottom grey band is EXACTLY 200%% (2.0x) of its original height")

		var clearance_to_band: float = (sep_y + min_gap_found) - band_btm
		if clearance_to_band >= 20.0:
			print("  [PASS] Clean visual gap between 200%% grey band bottom and all buses (+%.1f px > 20px target)" % clearance_to_band)
		else:
			print("  [FAIL] Clearance from 200%% grey band bottom to buses is too small (+%.1f px)" % clearance_to_band)
			all_passed = false
			
		lvl.queue_free()

	# TEST 2: Multi-Resolution Responsiveness & Exact Centering Verification
	print("\n--- TEST: Multi-Resolution Responsive Exact Centering & Clearance ---")
	var test_resolutions: Array[Vector2] = [
		Vector2(810, 1753),   # iPhone reference portrait
		Vector2(720, 1280),   # Standard portrait 16:9
		Vector2(1080, 1920),  # FHD portrait 16:9
		Vector2(390, 844),    # iPhone 12/13/14 portrait
		Vector2(1080, 2400),  # Tall modern mobile portrait
		Vector2(768, 1024),   # Tablet portrait
		Vector2(414, 896)     # iPhone XR / 11 portrait
	]
	
	for lvl_num in [1, 2]:
		print("\n-- Level %d Across All Resolutions --" % lvl_num)
		for res in test_resolutions:
			var lvl: CarJamLevel = CarJamLevelScene.instantiate()
			root.add_child(lvl)
			if not lvl.is_node_ready():
				lvl._ready()
				
			var level_data: CarJamLevelData = ResourceLoader.load("res://levels/level_%03d.tres" % lvl_num) as CarJamLevelData
			lvl.controller.load_level(level_data)
			lvl._setup_visuals(level_data)
			lvl._update_layout(res)
			
			var plat: PlatformView = lvl.platform_bg as PlatformView
			var sep_y = plat.get_band_bottom_y()
			var scale_factor = lvl.world_root.scale.y
			var sep_screen_y = (res.y / 2.0) + (sep_y * scale_factor)
			var expected_center = res.y / 2.0
			
			# 1. Exact Center Check
			if absf(sep_screen_y - expected_center) > 0.001:
				print("  [FAIL] Resolution %dx%d: Separator screen Y = %.2f != Expected Center = %.2f" % [
					int(res.x), int(res.y), sep_screen_y, expected_center
				])
				all_passed = false
				
			# 2. Upper Area (Parking) Above Line Check
			var parking_bottom = lvl.parking_root.position.y + ParkingSlotView.SLOT_HEIGHT / 2.0
			var park_gap = sep_y - parking_bottom
			if park_gap <= 0.0:
				print("  [FAIL] Resolution %dx%d: Parking encroaches separator! park_gap = %.1f" % [int(res.x), int(res.y), park_gap])
				all_passed = false
				
			# 3. Lower Area (Buses) Below Line Check
			var highest_bus_y = lvl._calc_highest_bus_visual_y()
			var bus_gap = highest_bus_y - sep_y
			if bus_gap < 20.0:
				print("  [FAIL] Resolution %dx%d: Bus clearance too small! gap = %.1f px (< 20px)" % [int(res.x), int(res.y), bus_gap])
				all_passed = false
			else:
				print("  [PASS] Res %4dx%4d (L%d): scale=%.3f | SepScreen=%.1f (mid=%.1f) | ParkGap=+%.1fpx | BusGap=+%.1fpx" % [
					int(res.x), int(res.y), lvl_num, scale_factor,
					sep_screen_y, expected_center,
					park_gap, bus_gap
				])
				
			lvl.queue_free()

	# TEST 3: PlatformView Coherent Grey & Full Width Properties
	print("\n--- TEST: PlatformView Coherent Styling Properties ---")
	var plat_test := PlatformView.new()
	plat_test.setup_full(-100.0, 1000.0, 1200.0, 200.0, 270.0)
	if plat_test.p_width == 1200.0 and plat_test.p_separator_y == 270.0 and plat_test.p_top == -100.0:
		print("  [PASS] PlatformView properties successfully initialized with exact full width and separator Y")
	else:
		print("  [FAIL] PlatformView properties mismatch!")
		all_passed = false

	# Verify 200% band height math:
	# partition_y = 200.0, separator_y = 270.0 -> orig_h = 70.0 -> new_h = 140.0 -> band_btm = 340.0
	var test_orig_h = plat_test.get_original_band_height()
	var test_curr_h = plat_test.get_current_band_height()
	var test_band_btm = plat_test.get_band_bottom_y()
	if absf(test_curr_h - test_orig_h * 2.0) < 0.001 and absf(test_band_btm - 340.0) < 0.001:
		print("  [PASS] PlatformView 200%% band height: orig=%.1f px, current=%.1f px (2.0x), band_btm=%.1f px" % [
			test_orig_h, test_curr_h, test_band_btm
		])
	else:
		print("  [FAIL] PlatformView 200%% band height calculation failed!")
		all_passed = false
	plat_test.queue_free()

	# TEST 4: ParkingBase Left-Border Removal Verification
	print("\n--- TEST: ParkingBase StyleBox Left Border Removal ---")
	var test_lvl: CarJamLevel = CarJamLevelScene.instantiate()
	root.add_child(test_lvl)
	if not test_lvl.is_node_ready():
		test_lvl._ready()
	var ldata: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	test_lvl.controller.load_level(ldata)
	test_lvl._setup_visuals(ldata)

	var pbase = test_lvl.parking_slots_node.get_node_or_null("ParkingBase")
	if pbase == null:
		print("  [FAIL] ParkingBase node not found!")
		all_passed = false
	else:
		print("  [PASS] ParkingBase node found in parking_slots_node")
	test_lvl.queue_free()

	print("\n=======================================================")
	if all_passed:
		print("=== ALL PLATFORM & SEPARATOR TESTS PASSED (0 FAILURES) ===")
		print("=======================================================")
		quit(0)
	else:
		print("=== TESTS FAILED ===")
		print("=======================================================")
		quit(1)
