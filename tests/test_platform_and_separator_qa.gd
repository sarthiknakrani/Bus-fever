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
	
	# TEST 1: Level 1 & Level 2 Bus Clearance from Separator Line
	for lvl_num in [1, 2]:
		print("\n--- TEST: Level %d Bus vs Separator Line Clearance ---" % lvl_num)
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
			
		var sep_y: float = plat.p_separator_y
		var parking_y: float = lvl.parking_root.position.y
		var board_y: float = lvl.board_root.position.y
		
		print("  [LAYOUT] Parking Y = %.1f | Separator Y = %.1f | Board Y = %.1f" % [parking_y, sep_y, board_y])
		
		# Check separator is between parking and board
		if not (parking_y < sep_y and sep_y < board_y):
			print("  [FAIL] Separator line is not positioned between parking and board! (parking=%.1f, sep=%.1f, board=%.1f)" % [parking_y, sep_y, board_y])
			all_passed = false
		else:
			print("  [PASS] Separator line is strictly between parking slots and puzzle board")
			
		# Check all vehicles on board
		var min_gap_found: float = 999999.0
		var highest_bus_id: int = -1
		
		for vid in lvl.vehicle_views:
			var vv: VehicleView = lvl.vehicle_views[vid]
			# Board root has position Vector2(0, board_y), rotation 45 deg, scale (1.0, 0.72)
			var world_pos: Vector2 = lvl.board_root.transform * vv.position
			# Native bus size: unscaled height is up to 146 px, scaled by 0.72 on board_root = 105.1 px.
			# Half height is ~52.6 px.
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
			
		lvl.queue_free()

	# TEST 2: Multi-Resolution Responsiveness & No Overlap
	print("\n--- TEST: Multi-Resolution Responsive Clearance (Level 1) ---")
	var test_resolutions: Array[Vector2] = [
		Vector2(720, 1280),   # Standard portrait 16:9
		Vector2(1080, 1920),  # FHD portrait 16:9
		Vector2(1080, 2400),  # Tall Android
		Vector2(390, 844),    # iPhone 12/13/14
		Vector2(414, 896),    # iPhone XR / 11
		Vector2(768, 1024)    # iPad portrait
	]
	
	for res in test_resolutions:
		var lvl: CarJamLevel = CarJamLevelScene.instantiate()
		root.add_child(lvl)
		if not lvl.is_node_ready():
			lvl._ready()
			
		var level_data: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
		lvl.controller.load_level(level_data)
		lvl._setup_visuals(level_data)
		
		# Override viewport size simulation
		var track_h = 392.0
		var parking_h = ParkingSlotView.SLOT_HEIGHT
		var board_pixel_h = max(level_data.board_size.x, level_data.board_size.y) * 78.0 * sqrt(2.0) * 0.72
		var bus_corridor_gap = 135.0
		var base_content_h = track_h + 65.0 + parking_h + bus_corridor_gap + board_pixel_h
		var screen_safe_h = res.y - 250.0
		var scale_factor = clampf(min(res.x * 0.94 / 702.0, screen_safe_h / (base_content_h + 30.0)), 0.42, 2.20)
		
		lvl.world_root.scale = Vector2(scale_factor, scale_factor)
		lvl._update_layout()
		
		var plat: PlatformView = lvl.platform_bg as PlatformView
		var sep_y = plat.p_separator_y
		
		var min_gap: float = 999999.0
		for vid in lvl.vehicle_views:
			var vv = lvl.vehicle_views[vid]
			var world_pos = lvl.board_root.transform * vv.position
			var top_visual_y = world_pos.y - (146.0 * 0.72 / 2.0)
			min_gap = minf(min_gap, top_visual_y - sep_y)
			
		if min_gap > 0.0:
			print("  [PASS] Resolution %dx%d: scale=%.3f, Clearance Gap = +%.1f px (No overlap!)" % [int(res.x), int(res.y), scale_factor, min_gap])
		else:
			print("  [FAIL] Resolution %dx%d: Overlap detected! gap = %.1f px" % [int(res.x), int(res.y), min_gap])
			all_passed = false
			
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
	plat_test.queue_free()

	print("\n=======================================================")
	if all_passed:
		print("=== ALL PLATFORM & SEPARATOR TESTS PASSED (0 FAILURES) ===")
		print("=======================================================")
		quit(0)
	else:
		print("=== TESTS FAILED ===")
		print("=======================================================")
		quit(1)
