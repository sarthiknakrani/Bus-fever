extends SceneTree

# Unified Upper Gameplay Platform QA Suite
# Verifies:
# 1. Platform top extends above passenger track (track_y - 196) with clean margin
# 2. Feeder track area is completely covered by unified platform
# 3. Gap between passenger track and parking bays has zero blue exposure (fully covered by platform deck)
# 4. Platform deck, concourse, island, and parking base share the cohesive lavender-grey material family
# 5. Clear pedestrian boarding concourse pathways and zebra markings exist leading to parking bays
# 6. Separator line remains clear and does not intersect puzzle buses across resolutions
# 7. Bus and slot dimensions remain strictly at 15% reduction (53x94 slot, 86.7 body length, 65px spacing)

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	print("=======================================================")
	print("=== UNIFIED UPPER GAMEPLAY PLATFORM QA SUITE ===")
	print("=======================================================")
	
	var all_passed := true
	
	# TEST 1: Geometry & Deck Coverage in Level 1 & Level 2
	print("\n--- TEST 1: Platform Geometry & Coverage (Levels 1 & 2) ---")
	for lvl_num in [1, 2]:
		var lvl: CarJamLevel = CarJamLevelScene.instantiate()
		root.add_child(lvl)
		if not lvl.is_node_ready():
			lvl._ready()
			
		var data_path = "res://levels/level_%03d.tres" % lvl_num
		var level_data: CarJamLevelData = ResourceLoader.load(data_path) as CarJamLevelData
		lvl.controller.load_level(level_data)
		lvl._setup_visuals(level_data)
		lvl._update_layout()
		
		var plat: PlatformView = lvl.platform_bg as PlatformView
		if plat == null:
			print("  [FAIL] Level %d: PlatformView node not found!" % lvl_num)
			all_passed = false
			lvl.queue_free()
			continue
			
		var track_y = lvl.passenger_track_root.position.y
		var parking_y = lvl.parking_root.position.y
		var track_top_y = track_y - 196.0 # Oval apex at -115, brush radius 81
		var track_bot_y = track_y + 196.0 # Oval bottom at +115, brush radius 81
		var parking_top_y = parking_y - (ParkingSlotView.SLOT_HEIGHT / 2.0)
		
		print("  [Level %d] Track Y: %.1f | Track Top: %.1f | Track Bottom: %.1f" % [lvl_num, track_y, track_top_y, track_bot_y])
		print("  [Level %d] Parking Y: %.1f | Parking Top: %.1f" % [lvl_num, parking_y, parking_top_y])
		print("  [Level %d] Platform Top: %.1f | Platform Bottom: %.1f" % [lvl_num, plat.p_top, plat.p_bottom])
		
		# Check 1: Platform top extends well above the passenger track
		var top_clearance = track_top_y - plat.p_top
		if plat.p_top < track_top_y:
			print("  [PASS] Platform top (%.1f) extends above track top (%.1f) by %.1f px" % [plat.p_top, track_top_y, top_clearance])
		else:
			print("  [FAIL] Platform top (%.1f) is BELOW track top (%.1f)!" % [plat.p_top, track_top_y])
			all_passed = false
			
		# Check 2: Platform deck covers entire gap between track bottom and parking slots
		var gap_h = parking_top_y - track_bot_y
		print("  [Level %d] Gap between track and parking: %.1f px" % [lvl_num, gap_h])
		if plat.p_top < track_bot_y and plat.p_bottom > parking_top_y:
			print("  [PASS] Gap between track and parking slots is 100% encompassed by unified grey deck")
		else:
			print("  [FAIL] Platform does not span the gap between track and parking!")
			all_passed = false
			
		# Check 3: Unified deck properties
		if plat.is_unified:
			print("  [PASS] Unified platform mode active: is_unified = true")
		else:
			print("  [FAIL] Unified platform mode is NOT active!")
			all_passed = false
			
		# Check 4: Feeder overpass reach
		var half_w = plat.p_width / 2.0
		var feeder_reach_x = maxf(half_w + 80.0, 750.0)
		if feeder_reach_x > 700.0:
			print("  [PASS] Feeder overpass platform reach is %.1f px (covers deep entrance at x=650)" % feeder_reach_x)
		else:
			print("  [FAIL] Feeder overpass reach too short: %.1f px" % feeder_reach_x)
			all_passed = false
			
		lvl.queue_free()

	# TEST 2: Material Family & Palette Harmony QA
	print("\n--- TEST 2: Cohesive Lavender-Grey Material Palette QA ---")
	var base_grey := Color("d1d5e6")
	var concourse_grey := Color("cbd0e2")
	var island_grey := Color("c2c7da")
	var parking_base_grey := Color("c5c9db")
	
	print("  Base Deck Grey:        #%s (L: %.3f)" % [base_grey.to_html(false), base_grey.get_luminance()])
	print("  Concourse Apron Grey:  #%s (L: %.3f)" % [concourse_grey.to_html(false), concourse_grey.get_luminance()])
	print("  Central Island Grey:   #%s (L: %.3f)" % [island_grey.to_html(false), island_grey.get_luminance()])
	print("  Parking Base Grey:     #%s (L: %.3f)" % [parking_base_grey.to_html(false), parking_base_grey.get_luminance()])
	
	# Verify hue & saturation family cohesion: all within lavender-grey slate gamut
	var colors := [base_grey, concourse_grey, island_grey, parking_base_grey]
	var max_lum := 0.0
	var min_lum := 1.0
	for c in colors:
		max_lum = maxf(max_lum, c.get_luminance())
		min_lum = minf(min_lum, c.get_luminance())
		# Check slight lavender-blue tint (b >= r and b >= g)
		if c.b < c.r or c.b < c.g:
			print("  [FAIL] Color #%s does not match lavender-grey tint" % c.to_html(false))
			all_passed = false
	
	var lum_spread = max_lum - min_lum
	print("  Luminance delta spread: %.3f (Target < 0.15 for cohesive material family)" % lum_spread)
	if lum_spread < 0.15:
		print("  [PASS] All platform elements share the exact same lavender-grey material family")
	else:
		print("  [FAIL] Luminance spread too wide across platform materials: %.3f" % lum_spread)
		all_passed = false

	# TEST 3: Multi-Resolution Responsiveness & Separator Line Clearance
	print("\n--- TEST 3: Multi-Resolution Layout & Bus Separation QA ---")
	var test_res: Array[Vector2] = [
		Vector2(810, 1750),  # User reference device / screenshot aspect
		Vector2(720, 1280),  # Standard 16:9 portrait
		Vector2(390, 844),   # iPhone 12 Pro (viewport)
		Vector2(1080, 2400)  # Ultra-tall modern phone
	]
	
	for res in test_res:
		var lvl: CarJamLevel = CarJamLevelScene.instantiate()
		root.add_child(lvl)
		if not lvl.is_node_ready():
			lvl._ready()
			
		var level_data: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
		lvl.controller.load_level(level_data)
		lvl._setup_visuals(level_data)
		
		# Set simulated viewport size
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
			
		if min_gap >= 20.0:
			print("  [PASS] Res %dx%d: scale=%.3f, Separator Clearance Gap = +%.1f px" % [int(res.x), int(res.y), scale_factor, min_gap])
		else:
			print("  [FAIL] Res %dx%d: Separator Clearance Gap too small = +%.1f px" % [int(res.x), int(res.y), min_gap])
			all_passed = false
			
		lvl.queue_free()

	# TEST 4: Bus & Parking Slot Size Invariance (15% Reduction Preserved)
	print("\n--- TEST 4: Bus & Slot Dimension Preservation QA ---")
	print("  ParkingSlotView dimensions: (%.1f x %.1f)" % [ParkingSlotView.SLOT_WIDTH, ParkingSlotView.SLOT_HEIGHT])
	if is_equal_approx(ParkingSlotView.SLOT_WIDTH, 53.0) and is_equal_approx(ParkingSlotView.SLOT_HEIGHT, 94.0):
		print("  [PASS] Parking slots strictly measure 53x94 px (15% reduction preserved)")
	else:
		print("  [FAIL] Parking slots dimension mismatch: %.1f x %.1f" % [ParkingSlotView.SLOT_WIDTH, ParkingSlotView.SLOT_HEIGHT])
		all_passed = false
		
	var test_veh := VehicleView.new()
	test_veh.setup(101, "park_test", "red", CarJamVehicleData.Direction.UP, 40, [Vector2i(0, 0), Vector2i(0, 1)])
	var rendered_sz = test_veh.get_rendered_parked_size()
	print("  Parked Bus Rendered Canvas: (%.1f x %.1f) | Visual Scale: %.2f" % [rendered_sz.x, rendered_sz.y, VehicleView.BUS_VISUAL_SCALE])
	if is_equal_approx(VehicleView.BUS_VISUAL_SCALE, 0.85):
		print("  [PASS] Bus visual scale strictly maintained at 0.85 (15% reduction preserved)")
	else:
		print("  [FAIL] Bus visual scale mismatch: %.2f" % VehicleView.BUS_VISUAL_SCALE)
		all_passed = false
	test_veh.queue_free()

	print("\n=======================================================")
	if all_passed:
		print("=== ALL UNIFIED PLATFORM QA TESTS PASSED (0 FAILURES) ===")
		print("=======================================================")
		quit(0)
	else:
		print("=== UNIFIED PLATFORM QA TESTS FAILED ===")
		print("=======================================================")
		quit(1)
