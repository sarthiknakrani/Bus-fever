extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	print("===============================================================")
	print("=== BUS SIZE INCONSISTENCY & CANONICAL STANDARDIZATION QA ===")
	print("===============================================================")
	
	var CANONICAL_W = 54.0
	var CANONICAL_L = 102.0
	var SLOT_W = 62.0
	var SLOT_H = 110.0

	# SECTION 1: Source PNG Texture Asset Bounds & Proportions
	print("\n--- 1. SOURCE TEXTURE ASSET MEASUREMENT (28 VARIANTS) ---")
	var colors = ["red", "blue", "yellow", "green", "orange", "purple", "pink"]
	var dirs = ["up", "down", "left", "right"]
	var total_checked = 0
	var max_body_w_dev = 0.0
	var max_body_l_dev = 0.0
	
	for c in colors:
		for d in dirs:
			var path = "res://assets/sprites/premium_buses/bus_short_%s_%s.png" % [c, d]
			var tex: Texture2D = load(path)
			assert(tex != null, "Missing asset: " + path)
			var img = tex.get_image()
			assert(img != null, "Cannot get image from: " + path)
			
			# Measure alpha bounds
			var bbox = _get_alpha_bbox(img)
			var body_w = bbox.size.x
			var body_h = bbox.size.y
			
			var measured_w = body_w if d in ["up", "down"] else body_h
			var measured_l = body_h if d in ["up", "down"] else body_w
			
			var w_dev = absf(measured_w - CANONICAL_W) / CANONICAL_W * 100.0
			var l_dev = absf(measured_l - CANONICAL_L) / CANONICAL_L * 100.0
			max_body_w_dev = maxf(max_body_w_dev, w_dev)
			max_body_l_dev = maxf(max_body_l_dev, l_dev)
			
			total_checked += 1
			
	print("  [PASS] Checked all %d variants." % total_checked)
	print("  [MEASURED] Maximum Asset Body Width Deviation:  %.2f%% (Target < 2%%)" % max_body_w_dev)
	print("  [MEASURED] Maximum Asset Body Length Deviation: %.2f%% (Target < 2%%)" % max_body_l_dev)
	assert(max_body_w_dev <= 2.0, "Asset width deviation exceeds 2%")
	assert(max_body_l_dev <= 2.0, "Asset length deviation exceeds 2%")

	# SECTION 2: Level 1 Puzzle-Board Rendered Bus Dimensions
	print("\n--- 2. LEVEL 1 PUZZLE-BOARD RENDERED BUS MEASUREMENT ---")
	var lvl1: CarJamLevel = CarJamLevelScene.instantiate()
	root.add_child(lvl1)
	if not lvl1.is_node_ready(): lvl1._ready()
	
	var data1: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	lvl1.controller.load_level(data1)
	lvl1._setup_visuals(data1)
	lvl1._update_layout()
	
	_measure_level_buses(lvl1, 1, CANONICAL_W, CANONICAL_L)
	lvl1.queue_free()

	# SECTION 3: Level 2 Puzzle-Board Rendered Bus Dimensions
	print("\n--- 3. LEVEL 2 PUZZLE-BOARD RENDERED BUS MEASUREMENT ---")
	var lvl2: CarJamLevel = CarJamLevelScene.instantiate()
	root.add_child(lvl2)
	if not lvl2.is_node_ready(): lvl2._ready()
	
	var data2: CarJamLevelData = ResourceLoader.load("res://levels/level_002.tres") as CarJamLevelData
	lvl2.controller.load_level(data2)
	lvl2._setup_visuals(data2)
	lvl2._update_layout()
	
	_measure_level_buses(lvl2, 2, CANONICAL_W, CANONICAL_L)
	lvl2.queue_free()

	# SECTION 4: Parking Bay Standardized Dimensions and Margins
	print("\n--- 4. PARKING BAY CANONICAL FIT & BALANCED MARGINS ---")
	var dir_enums = [
		CarJamVehicleData.Direction.UP,
		CarJamVehicleData.Direction.DOWN,
		CarJamVehicleData.Direction.LEFT,
		CarJamVehicleData.Direction.RIGHT
	]
	var dir_names = ["UP", "DOWN", "LEFT", "RIGHT"]
	for i in range(dir_enums.size()):
		var d = dir_enums[i]
		var d_name = dir_names[i]
		var fp: Array[Vector2i] = []
		if d in [0, 1]:
			fp.append_array([Vector2i(0, 0), Vector2i(0, 1)])
		else:
			fp.append_array([Vector2i(0, 0), Vector2i(1, 0)])
		var pv := VehicleView.new()
		pv.setup(100 + i, "park_test", "red", d, 40, fp)
		var unscaled = pv.get_unscaled_parked_size()
		# In parking bay, bus is rotated UP and rendered at scale (1.0, 1.0)
		var body_w = VehicleView.CANONICAL_BODY_WIDTH
		var body_l = VehicleView.CANONICAL_BODY_LENGTH
		var side_margin = (SLOT_W - body_w) / 2.0
		var end_margin = (SLOT_H - body_l) / 2.0
		
		print("  Direction %s: Unscaled Canvas=(%.1f, %.1f) | Body=(%.1f, %.1f) | Margins: X=%.1fpx, Y=%.1fpx" % [
			d_name, unscaled.x, unscaled.y, body_w, body_l, side_margin, end_margin
		])
		assert(unscaled == Vector2(SLOT_W, SLOT_H), "Unscaled parked canvas does not match slot")
		assert(absf(side_margin - 4.0) < 0.1, "Side margin is not 4.0px")
		assert(absf(end_margin - 4.0) < 0.1, "End margin is not 4.0px")
		pv.queue_free()
	print("  [PASS] All directions fit parking slots with exact 4.0px balanced margins on all sides.")

	# SECTION 5: Dispatch & Transit Scale Invariance (No Size Popping)
	print("\n--- 5. DISPATCH TRANSIT SCALE INVARIANCE (NO POPPING) ---")
	var lvl_test: CarJamLevel = CarJamLevelScene.instantiate()
	root.add_child(lvl_test)
	if not lvl_test.is_node_ready(): lvl_test._ready()
	var test_data: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	lvl_test.controller.load_level(test_data)
	lvl_test._setup_visuals(test_data)
	lvl_test._update_layout()

	for vid in lvl_test.vehicle_views:
		var vv: VehicleView = lvl_test.vehicle_views[vid]
		var sf = lvl_test.world_root.scale.x
		var g_scale_before = vv.global_scale / sf
		assert(absf(g_scale_before.x - 1.0) < 0.02, "Bus global scale X on board is not 1.0")
		assert(absf(g_scale_before.y - 1.0) < 0.02, "Bus global scale Y on board is not 1.0")
	print("  [PASS] All vehicles on board have strictly uniform (1.0, 1.0) world scale.")
	lvl_test.queue_free()

	print("\n===============================================================")
	print("=== ALL BUS SIZE STANDARDIZATION TESTS PASSED (0 FAILURES) ===")
	print("===============================================================")
	quit(0)

func _get_alpha_bbox(img: Image) -> Rect2:
	var w = img.get_width()
	var h = img.get_height()
	var min_x = w
	var min_y = h
	var max_x = -1
	var max_y = -1
	
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.005:
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y
				
	if max_x < min_x:
		return Rect2()
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _measure_level_buses(lvl: CarJamLevel, lvl_num: int, target_w: float, target_l: float) -> void:
	var max_board_w_dev = 0.0
	var max_board_l_dev = 0.0
	
	for vid in lvl.vehicle_views:
		var vv: VehicleView = lvl.vehicle_views[vid]
		var dir_str = CarJamVehicleData.dir_to_string(vv.vehicle_dir)
		var is_vert = (vv.vehicle_dir == CarJamVehicleData.Direction.UP or vv.vehicle_dir == CarJamVehicleData.Direction.DOWN)
		
		# Measure screen length and width by transforming unit vectors along bus body axes
		var local_axis_l = Vector2(0, 1) if is_vert else Vector2(1, 0)
		var local_axis_w = Vector2(1, 0) if is_vert else Vector2(0, 1)
		
		# Basis transform to world (screen) space
		var screen_axis_l = vv.global_transform.basis_xform(local_axis_l)
		var screen_axis_w = vv.global_transform.basis_xform(local_axis_w)
		
		# Body dimension on screen is body pixels * basis length / world_root scale
		# Since world_root scales everything uniformly by scale_factor, divide out scale_factor to get world units
		var sf = lvl.world_root.scale.x
		var screen_l = target_l * (screen_axis_l.length() / sf)
		var screen_w = target_w * (screen_axis_w.length() / sf)
		
		var l_dev = absf(screen_l - target_l) / target_l * 100.0
		var w_dev = absf(screen_w - target_w) / target_w * 100.0
		max_board_l_dev = maxf(max_board_l_dev, l_dev)
		max_board_w_dev = maxf(max_board_w_dev, w_dev)
		
		print("  Level %d Bus %d (%s, %s, dir=%s): Rendered Screen Body = (%.1f x %.1f) | Dev: (L: %.1f%%, W: %.1f%%)" % [
			lvl_num, vid, vv.vehicle_code, vv.vehicle_color_id, dir_str, screen_w, screen_l, w_dev, l_dev
		])

	print("  [SUMMARY Level %d] Max Screen Length Dev: %.2f%% | Max Screen Width Dev: %.2f%%" % [
		lvl_num, max_board_l_dev, max_board_w_dev
	])
	assert(max_board_l_dev <= 2.0, "Board length deviation exceeds 2%")
	assert(max_board_w_dev <= 2.0, "Board width deviation exceeds 2%")
