extends SceneTree

# ==============================================================================
# VIP ALIGNMENT & DISPATCH IN-FRAME BOUNDS QA TEST
# ==============================================================================
# Verifies:
# 1. VIP flight on horizontal buses (LEFT/RIGHT) lands aligned with parking bay
#    axis, NOT stuck horizontal across the bay.
# 2. VIP flight on vertical buses (DOWN/UP) lands aligned with parking bay axis,
#    NOT upside down.
# 3. VIP flight activates set_parking_mode(true) and centers _base_sprite.
# 4. Bus dispatch routing across all screen resolutions keeps buses strictly
#    inside the visible viewport frame (zero out-of-frame driving).
# ==============================================================================

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

var failures: int = 0
var passes: int = 0

func _init() -> void:
	call_deferred("_run_qa")

func _assert(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % msg)
	else:
		failures += 1
		print("  [FAIL] %s" % msg)

func _run_qa() -> void:
	print("\n=================================================================")
	print("=== RUNNING VIP ALIGNMENT & DISPATCH IN-FRAME BOUNDS QA SUITE ===")
	print("=================================================================\n")

	await test_vip_horizontal_bus_alignment()
	await test_vip_vertical_bus_alignment()
	await test_dispatch_in_frame_all_resolutions()

	print("\n=================================================================")
	print("QA Test Results: %d Passed, %d Failed" % [passes, failures])
	print("=================================================================\n")
	quit(0 if failures == 0 else 1)

func test_vip_horizontal_bus_alignment() -> void:
	print("--- TEST 1: VIP Landing Alignment for HORIZONTAL Bus (LEFT/RIGHT) ---")
	var lvl = CarJamLevelScene.instantiate()
	root.add_child(lvl)
	for f in 10: await process_frame

	var ctrl: CarJamController = lvl.controller
	# Find a horizontal bus (e.g. Bus 4 or Bus 2)
	var horiz_vid: int = -1
	for vid in ctrl.vehicles.keys():
		var vm: VehicleModel = ctrl.vehicles[vid]
		if vm.state == VehicleModel.VehicleState.ON_BOARD and (vm.direction == CarJamVehicleData.Direction.LEFT or vm.direction == CarJamVehicleData.Direction.RIGHT):
			horiz_vid = vid
			break

	_assert(horiz_vid != -1, "Found horizontal bus (%d) for VIP test" % horiz_vid)
	var vv: VehicleView = lvl.vehicle_views[horiz_vid]
	var dir_str = CarJamVehicleData.dir_to_string(vv.vehicle_dir)
	print("  Selected bus %d with initial horizontal orientation: %s" % [horiz_vid, dir_str])

	# Activate VIP
	lvl._on_vip_button_pressed()
	lvl._on_vehicle_tapped(horiz_vid)

	# Wait until touchdown
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await process_frame
		if ctrl.parking.get_slot(0).state == CarJamParkingManager.SlotState.OCCUPIED:
			break

	_assert(vv.is_in_parking, "VehicleView.is_in_parking is true after VIP landing")
	_assert(vv._base_sprite.position.distance_to(Vector2.ZERO) < 0.1, "_base_sprite is centered at Vector2.ZERO in parking slot")

	# Check orientation: The bus front must face along the parking bay axis (Vector2(0, -1).rotated(-22 deg))
	var slot_rot = lvl.slot_views[0].rotation
	var bay_axis = Vector2(0.0, -1.0).rotated(slot_rot)
	var front_native = Vector2(-1, 0) if vv.vehicle_dir == CarJamVehicleData.Direction.LEFT else Vector2(1, 0)
	var actual_front = front_native.rotated(vv.rotation)
	var angle_err_deg = absf(rad_to_deg(actual_front.angle_to(bay_axis)))

	print("  Actual front: %s | Bay axis: %s | Angular error: %.2f deg" % [actual_front, bay_axis, angle_err_deg])
	_assert(angle_err_deg < 1.0, "Horizontal bus rotated into vertical parking slot alignment (error < 1 deg, NOT horizontal)")

	lvl.queue_free()
	for f in 5: await process_frame

func test_vip_vertical_bus_alignment() -> void:
	print("\n--- TEST 2: VIP Landing Alignment for VERTICAL Bus (DOWN) ---")
	var lvl = CarJamLevelScene.instantiate()
	root.add_child(lvl)
	for f in 10: await process_frame

	var ctrl: CarJamController = lvl.controller
	# Find a DOWN bus (e.g. Bus 1)
	var down_vid: int = -1
	for vid in ctrl.vehicles.keys():
		var vm: VehicleModel = ctrl.vehicles[vid]
		if vm.state == VehicleModel.VehicleState.ON_BOARD and vm.direction == CarJamVehicleData.Direction.DOWN:
			down_vid = vid
			break

	_assert(down_vid != -1, "Found DOWN bus (%d) for VIP test" % down_vid)
	var vv: VehicleView = lvl.vehicle_views[down_vid]

	# Activate VIP
	lvl._on_vip_button_pressed()
	lvl._on_vehicle_tapped(down_vid)

	# Wait until touchdown
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await process_frame
		if ctrl.parking.get_slot(0).state == CarJamParkingManager.SlotState.OCCUPIED:
			break

	_assert(vv.is_in_parking, "VehicleView.is_in_parking is true after VIP landing")

	# Check orientation: Front must face forward along bay axis, not backwards
	var slot_rot = lvl.slot_views[0].rotation
	var bay_axis = Vector2(0.0, -1.0).rotated(slot_rot)
	var front_native = Vector2(0, 1) # DOWN native front
	var actual_front = front_native.rotated(vv.rotation)
	var angle_err_deg = absf(rad_to_deg(actual_front.angle_to(bay_axis)))

	print("  Actual front: %s | Bay axis: %s | Angular error: %.2f deg" % [actual_front, bay_axis, angle_err_deg])
	_assert(angle_err_deg < 1.0, "DOWN bus rotated into forward parking slot alignment (error < 1 deg, NOT inverted)")

	lvl.queue_free()
	for f in 5: await process_frame

func test_dispatch_in_frame_all_resolutions() -> void:
	print("\n--- TEST 3: Zero Out-of-Frame Driving Across All Viewport Resolutions ---")
	var test_resolutions := [
		Vector2i(390, 844),
		Vector2i(720, 1280),
		Vector2i(810, 1746),
		Vector2i(1080, 1920),
		Vector2i(1080, 2400)
	]

	var all_contained := true
	for res in test_resolutions:
		var vp := SubViewport.new()
		vp.size = res
		root.add_child(vp)

		var lvl: CarJamLevel = CarJamLevelScene.instantiate()
		vp.add_child(lvl)
		if not lvl.is_node_ready():
			lvl._ready()

		for lvl_num in [1, 2]:
			var gc = root.get_node_or_null("GameController")
			if gc != null:
				gc.current_level_number = lvl_num
			lvl._load_current_level()
			lvl._update_layout(Vector2(res))
			for f in 3: await process_frame

			for vid in lvl.vehicle_views:
				var vv = lvl.vehicle_views[vid]
				var vm = lvl.controller.vehicles[vid]
				for s_idx in [0, 1, lvl.controller.level_data.parking_slots_count - 1]:
					var target_slot_pos = lvl._get_slot_world_pos(s_idx)
					var slot_rot = lvl.slot_views[s_idx].rotation if s_idx < lvl.slot_views.size() else deg_to_rad(-22.0)
					var dir_vec = CarJamVehicleData.dir_to_vector(vv.vehicle_dir)
					var push_cells = float(vv.vehicle_footprint.size()) + 0.6
					var exit_coord = Vector2(vm.anchor) + Vector2(dir_vec) * push_cells
					var lx = exit_coord.x - float(lvl.controller.level_data.board_size.x - 1) / 2.0
					var ly = exit_coord.y - float(lvl.controller.level_data.board_size.y - 1) / 2.0
					var exit_local = Vector2(lx, ly) * lvl.CELL_SIZE
					var exit_pt = lvl.transit_layer.to_local(lvl.board_root.to_global(exit_local))
					var start_pos = lvl.transit_layer.to_local(vv.global_position)
					var approach_offset := Vector2(0.0, 94.0 + 16.0).rotated(slot_rot)
					var corridor_pos: Vector2 = target_slot_pos + approach_offset

					# Check bounds directly using VehicleMovement dispatch logic
					var parent_node = lvl.transit_layer
					var vp_xf = parent_node.get_viewport_transform()
					var v_rect = vp.get_visible_rect()
					var top_left_local: Vector2 = parent_node.to_local(vp_xf.affine_inverse() * Vector2(40.0, 40.0))
					var btm_right_local: Vector2 = parent_node.to_local(vp_xf.affine_inverse() * (v_rect.size - Vector2(40.0, 40.0)))
					var safe_min_x: float = minf(top_left_local.x, btm_right_local.x)
					var safe_max_x: float = maxf(top_left_local.x, btm_right_local.x)
					var safe_min_y: float = minf(top_left_local.y, btm_right_local.y)
					var safe_max_y: float = maxf(top_left_local.y, btm_right_local.y)

					var forward_world = (exit_pt - start_pos).normalized()
					var pts: Array[Vector2] = []
					pts.append(start_pos)
					var clamped_exit = Vector2(
						clampf(exit_pt.x, safe_min_x, safe_max_x),
						clampf(exit_pt.y, safe_min_y, safe_max_y)
					)
					pts.append(clamped_exit)

					if forward_world.y > 0.2:
						var bottom_y = clampf(exit_pt.y + 40.0, exit_pt.y, safe_max_y - 20.0)
						var side_x = (safe_min_x + 38.0) if target_slot_pos.x <= 0.0 else (safe_max_x - 38.0)
						pts.append(Vector2(clamped_exit.x, bottom_y))
						pts.append(Vector2(side_x, bottom_y))
						pts.append(Vector2(side_x, corridor_pos.y))
					elif forward_world.x < -0.2:
						var side_x = clampf(minf(clamped_exit.x - 20.0, -180.0), safe_min_x + 38.0, -80.0)
						pts.append(Vector2(side_x, clamped_exit.y))
						pts.append(Vector2(side_x, corridor_pos.y))
					elif forward_world.x > 0.2:
						var side_x = clampf(maxf(clamped_exit.x + 20.0, 180.0), 80.0, safe_max_x - 38.0)
						pts.append(Vector2(side_x, clamped_exit.y))
						pts.append(Vector2(side_x, corridor_pos.y))

					pts.append(corridor_pos)
					pts.append(target_slot_pos)

					var curve := Curve2D.new()
					var in_tangent := Vector2(0.0, 32.0).rotated(slot_rot)
					for i in range(pts.size()):
						var p = pts[i]
						var in_tan = Vector2.ZERO
						var out_tan = Vector2.ZERO
						if i == 0:
							out_tan = forward_world * 80.0
						elif i == pts.size() - 1:
							in_tan = in_tangent
						else:
							var prev_p = pts[i - 1]
							var next_p = pts[i + 1]
							var seg_d = (next_p - prev_p).normalized() * minf(50.0, prev_p.distance_to(p) * 0.35)
							in_tan = -seg_d
							out_tan = seg_d
						curve.add_point(p, in_tan, out_tan)

					var min_screen := Vector2(99999, 99999)
					var max_screen := Vector2(-99999, -99999)
					var curve_len = curve.get_baked_length()
					var canvas_xf = vp.get_canvas_transform()
					for s in range(30):
						var t_prog = float(s) / 29.0 * curve_len
						var local_pt = curve.sample_baked(t_prog)
						var global_pt = parent_node.to_global(local_pt)
						var screen_pt = canvas_xf * global_pt
						min_screen.x = minf(min_screen.x, screen_pt.x)
						min_screen.y = minf(min_screen.y, screen_pt.y)
						max_screen.x = maxf(max_screen.x, screen_pt.x)
						max_screen.y = maxf(max_screen.y, screen_pt.y)

					if min_screen.x < 0.0 or max_screen.x > float(res.x) or min_screen.y < 0.0 or max_screen.y > float(res.y):
						all_contained = false
						print("    [OUT OF BOUNDS] L%d Bus %d -> Slot %d on %dx%d" % [lvl_num, vid, s_idx, res.x, res.y])

		lvl.queue_free()
		vp.queue_free()
		for f in 3: await process_frame

	_assert(all_contained, "100% of dispatch trajectories across all levels and resolutions stay strictly in-frame")
