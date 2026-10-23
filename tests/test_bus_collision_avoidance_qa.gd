extends SceneTree

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
	print("=== RUNNING BUS MOVEMENT COLLISION AVOIDANCE & SMOKE QA SUITE ===")
	print("=================================================================\n")

	await test_rapid_multiple_dispatches_no_collision()
	await test_exhaust_smoke_lifecycle()
	await test_single_bus_smooth_arrival()
	await test_level_2_rapid_dispatches_no_collision()

	print("\n=================================================================")
	print("QA Test Results: %d Passed, %d Failed" % [passes, failures])
	print("=================================================================\n")
	quit(0 if failures == 0 else 1)

func test_rapid_multiple_dispatches_no_collision() -> void:
	print("--- TEST 1: Rapid Multiple Bus Releases Zero Body Overlap ---")
	var lvl = CarJamLevelScene.instantiate()
	root.add_child(lvl)
	for f in 10: await process_frame

	var ctrl: CarJamController = lvl.controller
	# In Level 1, buses 4 (LEFT), 3 (RIGHT), and 5 (DOWN) can escape initially.
	# Tap all three in rapid succession (< 0.1s apart)
	print("  Rapidly tapping Bus 4, Bus 3, Bus 5...")
	lvl._on_vehicle_tapped(4)
	await process_frame
	for f in 4: await process_frame
	lvl._on_vehicle_tapped(3)
	await process_frame
	for f in 4: await process_frame
	lvl._on_vehicle_tapped(5)

	var vv4: VehicleView = lvl.vehicle_views[4]
	var vv3: VehicleView = lvl.vehicle_views[3]
	var vv5: VehicleView = lvl.vehicle_views[5]

	var min_center_dist_4_3: float = 9999.0
	var min_center_dist_4_5: float = 9999.0
	var min_center_dist_3_5: float = 9999.0
	var any_obb_overlap_found: bool = false

	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await process_frame
		var obb4 = BusMotionPlan.BusOBB.from_view_in_world(vv4, lvl.world_root, 0.0)
		var obb3 = BusMotionPlan.BusOBB.from_view_in_world(vv3, lvl.world_root, 0.0)
		var obb5 = BusMotionPlan.BusOBB.from_view_in_world(vv5, lvl.world_root, 0.0)

		var p4: Vector2 = lvl.world_root.to_local(vv4.global_position)
		var p3: Vector2 = lvl.world_root.to_local(vv3.global_position)
		var p5: Vector2 = lvl.world_root.to_local(vv5.global_position)

		var d43 = p4.distance_to(p3)
		var d45 = p4.distance_to(p5)
		var d35 = p3.distance_to(p5)

		min_center_dist_4_3 = minf(min_center_dist_4_3, d43)
		min_center_dist_4_5 = minf(min_center_dist_4_5, d45)
		min_center_dist_3_5 = minf(min_center_dist_3_5, d35)

		# Check body intersections (zero overlap allowed)
		if obb4.intersects(obb3):
			any_obb_overlap_found = true
			print("  [ERROR] OBB overlap between Bus 4 and Bus 3! d=%.1f" % d43)
		if obb4.intersects(obb5):
			any_obb_overlap_found = true
			print("  [ERROR] OBB overlap between Bus 4 and Bus 5! d=%.1f" % d45)
		if obb3.intersects(obb5):
			any_obb_overlap_found = true
			print("  [ERROR] OBB overlap between Bus 3 and Bus 5! d=%.1f" % d35)

		if vv4.is_in_parking and vv3.is_in_parking and vv5.is_in_parking:
			break

	print("  Min center distances: 4-3: %.1f px | 4-5: %.1f px | 3-5: %.1f px" % [
		min_center_dist_4_3, min_center_dist_4_5, min_center_dist_3_5
	])
	print("  Parking status: vv4=%s, vv3=%s, vv5=%s" % [vv4.is_in_parking, vv3.is_in_parking, vv5.is_in_parking])

	_assert(not any_obb_overlap_found, "Zero OBB body intersections across all animation frames during rapid release")
	_assert(min_center_dist_4_3 >= 48.0, "Bus 4 and 3 maintained safe clearance throughout (min dist %.1f px >= 48px)" % min_center_dist_4_3)
	_assert(min_center_dist_4_5 >= 48.0, "Bus 4 and 5 maintained safe clearance throughout (min dist %.1f px >= 48px)" % min_center_dist_4_5)
	_assert(min_center_dist_3_5 >= 48.0, "Bus 3 and 5 maintained safe clearance throughout (min dist %.1f px >= 48px)" % min_center_dist_3_5)
	_assert(vv4.is_in_parking and vv3.is_in_parking and vv5.is_in_parking, "All three buses successfully reached their parking bays")

	lvl.queue_free()
	for f in 5: await process_frame

func test_exhaust_smoke_lifecycle() -> void:
	print("\n--- TEST 2: Exhaust Smoke Lifecycle (Moving vs Parked vs Departing) ---")
	var lvl = CarJamLevelScene.instantiate()
	root.add_child(lvl)
	for f in 10: await process_frame

	var ctrl: CarJamController = lvl.controller
	var vv4: VehicleView = lvl.vehicle_views[4]

	_assert(vv4._exhaust_smoke != null, "Exhaust smoke emitter node exists on VehicleView")
	_assert(not vv4._exhaust_smoke.emitting, "Smoke is not emitting while stationary on board")

	lvl._on_vehicle_tapped(4)
	for f in 3: await process_frame
	_assert(vv4._exhaust_smoke.emitting, "Smoke starts emitting immediately while bus is in transit")

	# Wait until bus parks
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000:
		await process_frame
		if vv4.is_in_parking:
			break

	_assert(vv4.is_in_parking, "Bus 4 reached parking slot")
	_assert(not vv4._exhaust_smoke.emitting, "Smoke stops emitting once bus is parked")

	lvl.queue_free()
	for f in 5: await process_frame

func test_single_bus_smooth_arrival() -> void:
	print("\n--- TEST 3: Single Bus Smooth Arrival Duration & Precision ---")
	var lvl = CarJamLevelScene.instantiate()
	root.add_child(lvl)
	for f in 10: await process_frame

	var vv3: VehicleView = lvl.vehicle_views[3]
	var t_start = Time.get_ticks_msec() / 1000.0
	lvl._on_vehicle_tapped(3)

	while Time.get_ticks_msec() / 1000.0 - t_start < 2.0:
		await process_frame
		if vv3.is_in_parking:
			break

	var elapsed = (Time.get_ticks_msec() / 1000.0) - t_start
	print("  Single bus arrival elapsed: %.3fs" % elapsed)
	_assert(elapsed <= 1.2, "Single bus arrival took approximately 0.8s - 1.0s (measured %.2fs)" % elapsed)

	var slot_rot = lvl.slot_views[vv3.get_parent().get_index()].rotation if vv3.get_parent() != null and vv3.get_parent() is ParkingSlotView else deg_to_rad(-22.0)
	var bay_axis = Vector2(0.0, -1.0).rotated(slot_rot)
	var actual_front = Vector2(1, 0).rotated(vv3.rotation) # Bus 3 is RIGHT
	var ang_err = absf(rad_to_deg(actual_front.angle_to(bay_axis)))
	_assert(ang_err < 1.0, "Bus parked precisely with bay axis (angular error %.2f deg < 1.0 deg)" % ang_err)

	lvl.queue_free()
	for f in 5: await process_frame

func test_level_2_rapid_dispatches_no_collision() -> void:
	print("\n--- TEST 4: Level 2 Rapid Dispatches Zero Body Overlap ---")
	var lvl = CarJamLevelScene.instantiate()
	root.add_child(lvl)
	for f in 10: await process_frame

	var lvl2 = load("res://levels/level_002.tres") as CarJamLevelData
	lvl.controller.load_level(lvl2)
	lvl._setup_visuals(lvl2)
	for f in 10: await process_frame

	var escapable: Array[int] = []
	for vid in lvl.controller.vehicles.keys():
		var vm: VehicleModel = lvl.controller.vehicles[vid]
		if lvl.controller.board.check_swept_escape(vm).get("can_escape", false):
			escapable.append(vid)

	print("  Level 2 initially escapable buses: %s" % str(escapable))
	_assert(escapable.size() >= 2, "Level 2 has at least 2 escapable buses")

	var tapped_vids: Array[int] = []
	for i in mini(3, escapable.size()):
		var vid = escapable[i]
		tapped_vids.append(vid)
		lvl._on_vehicle_tapped(vid)
		await process_frame
		for f in 4: await process_frame

	var any_overlap: bool = false
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await process_frame
		for i in tapped_vids.size():
			for j in range(i + 1, tapped_vids.size()):
				var v_a = lvl.vehicle_views[tapped_vids[i]]
				var v_b = lvl.vehicle_views[tapped_vids[j]]
				var obb_a = BusMotionPlan.BusOBB.from_view_in_world(v_a, lvl.world_root, 0.0)
				var obb_b = BusMotionPlan.BusOBB.from_view_in_world(v_b, lvl.world_root, 0.0)
				if obb_a.intersects(obb_b):
					any_overlap = true
					print("  [ERROR] Level 2 OBB overlap between Bus %d and %d!" % [tapped_vids[i], tapped_vids[j]])

		var all_parked: bool = true
		for vid in tapped_vids:
			if not lvl.vehicle_views[vid].is_in_parking:
				all_parked = false
				break
		if all_parked:
			break

	_assert(not any_overlap, "Level 2: Zero OBB body intersections during rapid releases")
	var all_in_parking: bool = true
	for vid in tapped_vids:
		if not lvl.vehicle_views[vid].is_in_parking:
			all_in_parking = false
	_assert(all_in_parking, "Level 2: All rapidly dispatched buses reached their parking bays")

	lvl.queue_free()
	for f in 5: await process_frame
