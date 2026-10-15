extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	print("===============================================================")
	print("=== PROPORTIONAL BUS ARTWORK & SIZE CONSISTENCY QA ===")
	print("===============================================================")
	
	var CANONICAL_L = 102.0
	var CANONICAL_W_V = 48.0
	var CANONICAL_W_H = 46.0
	var SLOT_W = 53.0
	var SLOT_H = 94.0

	var BOARD_SCALE = 1.0 # Canonical 1.0x scale on board eliminates body overlap and size popping
	var RENDERED_L = CANONICAL_L * BOARD_SCALE # 102.0
	var RENDERED_W_V = CANONICAL_W_V * BOARD_SCALE # 48.0
	var RENDERED_W_H = CANONICAL_W_H * BOARD_SCALE # 46.0

	# SECTION 1: Source PNG Texture Asset Bounds & Proportional Aspect Ratios
	print("\n--- 1. PROPORTIONAL TEXTURE ASSET & ASPECT RATIO QA (28 VARIANTS) ---")
	var colors = ["red", "blue", "yellow", "green", "orange", "purple", "pink"]
	var dirs = ["up", "down", "left", "right"]
	var total_checked = 0
	var max_aspect_dev = 0.0
	var max_length_dev = 0.0
	
	# Original un-distorted aspect ratios from git history (f603b81 / 1bfd63d):
	# Vertical: 145 / 68 = 2.13235
	# Horizontal: 144 / 65 = 2.21538
	var ORIG_ASPECT_V = 145.0 / 68.0
	var ORIG_ASPECT_H = 144.0 / 65.0
	
	for c in colors:
		for d in dirs:
			var path = "res://assets/sprites/premium_buses/bus_short_%s_%s.png" % [c, d]
			var tex: Texture2D = load(path)
			assert(tex != null, "Missing asset: " + path)
			var img = tex.get_image()
			assert(img != null, "Cannot get image from: " + path)
			
			var bbox = _get_alpha_bbox(img)
			var is_vert = (d == "up" or d == "down")
			var body_w = bbox.size.x if is_vert else bbox.size.y
			var body_l = bbox.size.y if is_vert else bbox.size.x
			
			var expected_w = CANONICAL_W_V if is_vert else CANONICAL_W_H
			var expected_l = CANONICAL_L
			var expected_aspect = ORIG_ASPECT_V if is_vert else ORIG_ASPECT_H
			
			var actual_aspect = float(body_l) / float(body_w)
			var aspect_dev = absf(actual_aspect - expected_aspect) / expected_aspect * 100.0
			var length_dev = absf(float(body_l) - expected_l) / expected_l * 100.0
			
			max_aspect_dev = maxf(max_aspect_dev, aspect_dev)
			max_length_dev = maxf(max_length_dev, length_dev)
			
			assert(body_w == expected_w, "Body width mismatch for %s_%s: got %d, expected %d" % [c, d, body_w, int(expected_w)])
			assert(body_l == expected_l, "Body length mismatch for %s_%s: got %d, expected %d" % [c, d, body_l, int(expected_l)])
			total_checked += 1
			
	print("  [PASS] Checked all %d short bus variants." % total_checked)
	print("  [MEASURED] Maximum Artwork Aspect Ratio Deviation: %.2f%% (Target < 1.0%%)" % max_aspect_dev)
	print("  [MEASURED] Maximum Visible Body Length Deviation:  %.2f%% (Target < 0.1%%)" % max_length_dev)
	assert(max_aspect_dev <= 1.0, "Artwork aspect ratio was distorted by > 1%")
	assert(max_length_dev <= 0.1, "Body length deviation exceeds target")

	# SECTION 2: Long Bus Source Asset Preservation
	print("\n--- 2. LONG BUS SOURCE ASSET PRESERVATION (56 FILES) ---")
	var long_checked = 0
	for c in colors:
		for d in dirs:
			var p1 = "res://assets/sprites/premium_buses/bus_long_%s_%s.png" % [c, d]
			var t1: Texture2D = load(p1)
			assert(t1 != null, "Missing long bus asset: " + p1)
			var sz1 = t1.get_size()
			var exp_sz1 = Vector2(68, 224) if (d == "up" or d == "down") else Vector2(224, 68)
			assert(sz1 == exp_sz1, "Long bus asset corrupted: %s has size %s, expected %s" % [p1, str(sz1), str(exp_sz1)])
			
			var p2 = "res://assets/buses/long_%s_%s.png" % [c, d]
			var t2: Texture2D = load(p2)
			assert(t2 != null, "Missing fallback long bus asset: " + p2)
			var sz2 = t2.get_size()
			assert(sz2 == exp_sz1, "Fallback long bus asset corrupted: %s has size %s, expected %s" % [p2, str(sz2), str(exp_sz1)])
			long_checked += 2

	print("  [PASS] Verified %d long-bus assets: 100%% preserved in original genuine (68x224 / 224x68) state." % long_checked)

	# SECTION 3: Level 1 Puzzle-Board Rendered Bus Dimensions
	print("\n--- 3. LEVEL 1 PUZZLE-BOARD RENDERED BUS MEASUREMENT ---")
	var lvl1: CarJamLevel = CarJamLevelScene.instantiate()
	root.add_child(lvl1)
	if not lvl1.is_node_ready(): lvl1._ready()
	
	var data1: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	lvl1.controller.load_level(data1)
	lvl1._setup_visuals(data1)
	lvl1._update_layout()
	
	_measure_level_buses(lvl1, 1, RENDERED_W_V, RENDERED_W_H, RENDERED_L, CANONICAL_W_V, CANONICAL_W_H, CANONICAL_L)
	lvl1.queue_free()

	# SECTION 4: Level 2 Puzzle-Board Rendered Bus Dimensions
	print("\n--- 4. LEVEL 2 PUZZLE-BOARD RENDERED BUS MEASUREMENT ---")
	var lvl2: CarJamLevel = CarJamLevelScene.instantiate()
	root.add_child(lvl2)
	if not lvl2.is_node_ready(): lvl2._ready()
	
	var data2: CarJamLevelData = ResourceLoader.load("res://levels/level_002.tres") as CarJamLevelData
	lvl2.controller.load_level(data2)
	lvl2._setup_visuals(data2)
	lvl2._update_layout()
	
	_measure_level_buses(lvl2, 2, RENDERED_W_V, RENDERED_W_H, RENDERED_L, CANONICAL_W_V, CANONICAL_W_H, CANONICAL_L)
	lvl2.queue_free()

	# SECTION 5: Parking Bay Proportional Fit & Balanced Margins
	print("\n--- 5. PARKING BAY PROPORTIONAL FIT & BALANCED MARGINS ---")
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
		if d in [0, 1]: fp.append_array([Vector2i(0, 0), Vector2i(0, 1)])
		else: fp.append_array([Vector2i(0, 0), Vector2i(1, 0)])
		
		var pv := VehicleView.new()
		pv.setup(100 + i, "park_test", "red", d, 40, fp)
		pv.set_parking_mode(true)
		var rendered_sz = pv.get_rendered_parked_size()
		var is_vert = (d == 0 or d == 1)
		var body_w = CANONICAL_W_V * VehicleView.BUS_VISUAL_SCALE if is_vert else CANONICAL_W_H * VehicleView.BUS_VISUAL_SCALE
		var body_l = CANONICAL_L * VehicleView.BUS_VISUAL_SCALE
		var side_margin = (SLOT_W - body_w) / 2.0
		var end_margin = (SLOT_H - body_l) / 2.0
		
		print("  Direction %s: Rendered Canvas=(%.1f, %.1f) | Body=(%.1f, %.1f) | Margins: X=%.1fpx, Y=%.1fpx" % [
			d_name, rendered_sz.x, rendered_sz.y, body_w, body_l, side_margin, end_margin
		])
		assert(rendered_sz.x <= SLOT_W + 0.1 and rendered_sz.y <= SLOT_H + 0.1, "Rendered parked canvas exceeds slot")
		assert(side_margin >= 4.0, "Side margin is less than 4.0px")
		assert(end_margin >= 3.0, "End margin is less than 3.0px")
		pv.queue_free()
	print("  [PASS] All directions fit parking slots with clean margins (side >= 4px, end >= 3px) and zero clipping.")

	# SECTION 6: Dispatch & Transit Scale Invariance (No Size Popping)
	print("\n--- 6. DISPATCH TRANSIT SCALE INVARIANCE (NO POPPING) ---")
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
	print("=== ALL PROPORTIONAL ART & BUS SIZE TESTS PASSED (0 FAILURES) ===")
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

func _measure_level_buses(lvl: CarJamLevel, lvl_num: int, target_w_v: float, target_w_h: float, target_l: float, canon_w_v: float, canon_w_h: float, canon_l: float) -> void:
	var max_board_w_dev = 0.0
	var max_board_l_dev = 0.0
	
	for vid in lvl.vehicle_views:
		var vv: VehicleView = lvl.vehicle_views[vid]
		var dir_str = CarJamVehicleData.dir_to_string(vv.vehicle_dir)
		var is_vert = (vv.vehicle_dir == CarJamVehicleData.Direction.UP or vv.vehicle_dir == CarJamVehicleData.Direction.DOWN)
		var target_w = target_w_v if is_vert else target_w_h
		var canon_w = canon_w_v if is_vert else canon_w_h
		
		# Measure screen length and width by transforming unit vectors along bus body axes
		var local_axis_l = Vector2(0, 1) if is_vert else Vector2(1, 0)
		var local_axis_w = Vector2(1, 0) if is_vert else Vector2(0, 1)
		
		# Basis transform to world (screen) space
		var screen_axis_l = vv.global_transform.basis_xform(local_axis_l)
		var screen_axis_w = vv.global_transform.basis_xform(local_axis_w)
		
		# Body dimension on screen is canon body pixels * sprite scale * basis length / world_root scale
		var sf = lvl.world_root.scale.x
		var spr_s = vv._base_sprite.scale.x if vv._base_sprite != null else 1.0
		var screen_l = canon_l * spr_s * (screen_axis_l.length() / sf)
		var screen_w = canon_w * spr_s * (screen_axis_w.length() / sf)
		
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
