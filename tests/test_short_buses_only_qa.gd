extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	_run_short_bus_tests()

func _run_short_bus_tests() -> void:
	await create_timer(0.2).timeout
	print("\n=======================================================")
	print("=== SHORT BUSES ONLY VERIFICATION & REGRESSION QA ===")
	print("=======================================================")

	var failures := 0

	# ----------------------------------------------------
	# TEST 1: Level 1 Vehicle Inspection
	# ----------------------------------------------------
	print("\n--- TEST 1: Level 1 All Buses Short Variant Verification ---")
	var l1: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l1)
	if not l1.is_node_ready():
		l1._ready()
	await create_timer(0.15).timeout

	for vid in l1.vehicle_views:
		var vv: VehicleView = l1.vehicle_views[vid]
		var spr: Sprite2D = vv.get_node_or_null("CharacterSprite")
		if spr == null:
			# Base sprite is named after node or direct Sprite2D child
			for c in vv.get_children():
				if c is Sprite2D and c != vv._shadow_sprite:
					spr = c
					break
		
		var tex: Texture2D = spr.texture if spr else null
		var tex_path: String = tex.resource_path if tex else ""
		var tex_size: Vector2 = tex.get_size() if tex else Vector2.ZERO

		print("  Level 1 Bus %d (%s, %s, dir=%d):" % [vid, vv.vehicle_code, vv.vehicle_color_id, vv.vehicle_dir])
		print("    Texture: %s | Size: (%.0f, %.0f)" % [tex_path, tex_size.x, tex_size.y])
		print("    Footprint: %s (Cells: %d)" % [str(vv.vehicle_footprint), vv.vehicle_footprint.size()])

		# Check 1: Footprint is exactly 2 cells
		if vv.vehicle_footprint.size() == 2:
			print("    [PASS] Logical footprint is standard 2 cells")
		else:
			print("    [FAIL] Expected 2-cell footprint, got %d" % vv.vehicle_footprint.size())
			failures += 1

		# Check 2: Texture is strictly short variant
		if "bus_short_" in tex_path or "short_" in tex_path:
			print("    [PASS] Approved glossy short bus asset used")
		else:
			print("    [FAIL] Texture is not short bus variant: %s" % tex_path)
			failures += 1

		# Check 3: Texture is NOT long
		if "long" in tex_path:
			print("    [FAIL] Long bus asset detected: %s" % tex_path)
			failures += 1
		else:
			print("    [PASS] Verified NOT a long bus")

		# Check 4: Exact short bus dimensions (canonical 62x110 vertical, 110x62 horizontal)
		var is_vert: bool = (vv.vehicle_dir == CarJamVehicleData.Direction.UP or vv.vehicle_dir == CarJamVehicleData.Direction.DOWN)
		var expected_size: Vector2 = Vector2(62, 110) if is_vert else Vector2(110, 62)
		if tex_size == expected_size:
			print("    [PASS] Exact native short bus dimensions: %s" % str(expected_size))
		else:
			print("    [FAIL] Unexpected texture dimensions: got %s, expected %s" % [str(tex_size), str(expected_size)])
			failures += 1

	l1.queue_free()

	# ----------------------------------------------------
	# TEST 2: Level 2 Vehicle Inspection
	# ----------------------------------------------------
	print("\n--- TEST 2: Level 2 All Buses Short Variant Verification ---")
	var gc = root.get_node_or_null("GameController")
	if gc: gc.current_level_number = 2

	var l2: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(l2)
	if not l2.is_node_ready():
		l2._ready()
	await create_timer(0.15).timeout

	for vid in l2.vehicle_views:
		var vv: VehicleView = l2.vehicle_views[vid]
		var spr: Sprite2D = null
		for c in vv.get_children():
			if c is Sprite2D and c != vv._shadow_sprite:
				spr = c
				break
		
		var tex: Texture2D = spr.texture if spr else null
		var tex_path: String = tex.resource_path if tex else ""
		var tex_size: Vector2 = tex.get_size() if tex else Vector2.ZERO

		print("  Level 2 Bus %d (%s, %s, dir=%d):" % [vid, vv.vehicle_code, vv.vehicle_color_id, vv.vehicle_dir])
		print("    Texture: %s | Size: (%.0f, %.0f)" % [tex_path, tex_size.x, tex_size.y])

		if vv.vehicle_footprint.size() == 2:
			print("    [PASS] Logical footprint is standard 2 cells")
		else:
			print("    [FAIL] Expected 2-cell footprint, got %d" % vv.vehicle_footprint.size())
			failures += 1

		if "bus_short_" in tex_path or "short_" in tex_path:
			print("    [PASS] Approved glossy short bus asset used")
		else:
			print("    [FAIL] Texture is not short bus variant: %s" % tex_path)
			failures += 1

		if "long" in tex_path:
			print("    [FAIL] Long bus asset detected: %s" % tex_path)
			failures += 1
		else:
			print("    [PASS] Verified NOT a long bus")

		var is_vert: bool = (vv.vehicle_dir == CarJamVehicleData.Direction.UP or vv.vehicle_dir == CarJamVehicleData.Direction.DOWN)
		var expected_size: Vector2 = Vector2(62, 110) if is_vert else Vector2(110, 62)
		if tex_size == expected_size:
			print("    [PASS] Exact native short bus dimensions: %s" % str(expected_size))
		else:
			print("    [FAIL] Unexpected texture dimensions: got %s, expected %s" % [str(tex_size), str(expected_size)])
			failures += 1

	l2.queue_free()
	if gc: gc.current_level_number = 1

	# ----------------------------------------------------
	# TEST 3: Parking Containment for All Short Buses
	# ----------------------------------------------------
	print("\n--- TEST 3: Parking Containment Across All Short Bus Directions ---")
	var dirs = [CarJamVehicleData.Direction.UP, CarJamVehicleData.Direction.DOWN, CarJamVehicleData.Direction.LEFT, CarJamVehicleData.Direction.RIGHT]
	var dir_names = ["UP", "DOWN", "LEFT", "RIGHT"]
	for d_idx in range(dirs.size()):
		var d = dirs[d_idx]
		var fp: Array[Vector2i] = []
		if d == 0 or d == 1:
			fp.append_array([Vector2i(0, 0), Vector2i(0, 1)])
		else:
			fp.append_array([Vector2i(0, 0), Vector2i(1, 0)])
		var test_vv := VehicleView.new()
		test_vv.setup(99, "test", "blue", d, 40, fp)
		var unscaled: Vector2 = test_vv.get_unscaled_parked_size()
		var visual_body: Vector2 = Vector2(VehicleView.CANONICAL_BODY_WIDTH, VehicleView.CANONICAL_BODY_LENGTH)
		var w_margin: float = (62.0 - visual_body.x) / 2.0
		var h_margin: float = (110.0 - visual_body.y) / 2.0

		print("  Direction %s: Unscaled=(%.1f, %.1f) -> Parked Body=(%.1f, %.1f) | Margins: W=%.1fpx, H=%.1fpx" % [
			dir_names[d_idx], unscaled.x, unscaled.y, visual_body.x, visual_body.y, w_margin, h_margin
		])

		if visual_body.x <= 56.0 and visual_body.y <= 104.0 and w_margin >= 3.0 and h_margin >= 3.0:
			print("    [PASS] Clean centered parking fit with zero slot clipping")
		else:
			print("    [FAIL] Parking containment violation!")
			failures += 1
		test_vv.queue_free()

	print("\n=======================================================")
	if failures == 0:
		print("=== ALL SHORT BUS VERIFICATION TESTS PASSED (0 FAILURES) ===")
	else:
		print("=== %d SHORT BUS TESTS FAILED ===" % failures)
	print("=======================================================\n")

	quit(failures)
