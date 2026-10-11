extends SceneTree

const VehicleMovement := preload("res://scripts/gameplay/vehicle_movement.gd")
const CarJamVehicleData := preload("res://data/vehicle_data.gd")
const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

var failures: int = 0

class MockBus extends Node2D:
	var vehicle_dir: int = 0
	func set_parking_mode(_m: bool) -> void:
		pass

class MockController extends Node:
	var arrival_time: float = -1.0
	var cleared_time: float = -1.0
	var departed_time: float = -1.0
	var t_dispatch_start: float = 0.0
	var t_depart_start: float = 0.0

	func on_vehicle_arrived_at_slot(_vid: int, _sid: int, _tok: int) -> void:
		arrival_time = Time.get_ticks_msec() / 1000.0

	func on_vehicle_cleared_slot(_vid: int, _sid: int, _tok: int) -> void:
		cleared_time = Time.get_ticks_msec() / 1000.0

	func on_vehicle_departed_from_slot(_vid: int, _sid: int, _tok: int) -> void:
		departed_time = Time.get_ticks_msec() / 1000.0


func _init() -> void:
	_run_all_timing_tests()


func _run_all_timing_tests() -> void:
	print("\n==========================================")
	print("=== BUS ANIMATION TIMING VERIFICATION ===")
	print("==========================================\n")

	# Warmup to allow Godot background engine init / disk I/O to settle
	await create_timer(0.3).timeout

	# Test 1: Verify Constants
	print("--- TEST 1: Timing Constants ---")
	if VehicleMovement.BUS_ARRIVAL_DURATION == 1.0:
		print("  [PASS] BUS_ARRIVAL_DURATION == 1.00s")
	else:
		print("  [FAIL] Expected BUS_ARRIVAL_DURATION 1.0, got %f" % VehicleMovement.BUS_ARRIVAL_DURATION)
		failures += 1

	if VehicleMovement.BUS_DEPARTURE_DURATION == 0.9:
		print("  [PASS] BUS_DEPARTURE_DURATION == 0.90s")
	else:
		print("  [FAIL] Expected BUS_DEPARTURE_DURATION 0.9, got %f" % VehicleMovement.BUS_DEPARTURE_DURATION)
		failures += 1

	# Test 2: Direct Arrival Tween Measurement across different routes
	print("\n--- TEST 2: Direct Arrival Movement Across Slots ---")
	var routes = [
		{"name": "Straight down route (Slot 0)", "start": Vector2(-150, 750), "exit": Vector2(-150, 650), "corridor": Vector2(-152, 505), "slot": Vector2(-152, 405), "dir": CarJamVehicleData.Direction.DOWN},
		{"name": "Left turn route (Slot 2)", "start": Vector2(60, 715), "exit": Vector2(-55, 598), "corridor": Vector2(-76, 505), "slot": Vector2(-76, 405), "dir": CarJamVehicleData.Direction.LEFT},
		{"name": "Right turn route (Slot 3)", "start": Vector2(-28, 692), "exit": Vector2(88, 808), "corridor": Vector2(0, 505), "slot": Vector2(0, 405), "dir": CarJamVehicleData.Direction.RIGHT},
		{"name": "Long U-turn route (Slot 4)", "start": Vector2(100, 850), "exit": Vector2(100, 700), "corridor": Vector2(152, 505), "slot": Vector2(152, 405), "dir": CarJamVehicleData.Direction.UP},
	]

	for r in routes:
		var parent = Node2D.new()
		root.add_child(parent)

		var bus = MockBus.new()
		bus.vehicle_dir = r["dir"]
		parent.add_child(bus)

		var mock = MockController.new()
		parent.add_child(mock)

		mock.t_dispatch_start = Time.get_ticks_msec() / 1000.0
		VehicleMovement.animate_dispatch(
			bus,
			r["start"],
			r["exit"],
			r["corridor"],
			r["slot"],
			1,
			mock,
			1,
			0,
			Vector2.ONE
		)

		# Wait for arrival tween to complete (target 1.00s)
		await create_timer(1.15).timeout

		if mock.arrival_time < 0:
			print("  [FAIL] %s did not arrive!" % r["name"])
			failures += 1
		else:
			var measured = mock.arrival_time - mock.t_dispatch_start
			print("  [MEASURED] %s: %.3fs (Target: 1.00s)" % [r["name"], measured])
			if abs(measured - 1.0) <= 0.08:
				print("  [PASS] Within tolerance (±0.08s)")
			else:
				print("  [FAIL] Outside tolerance (1.00s ± 0.08s): %.3fs" % measured)
				failures += 1

		parent.queue_free()

	# Test 3: Direct Departure Movement Across Slots
	print("\n--- TEST 3: Direct Departure Movement Across Slots ---")
	var dep_slots = [
		{"name": "Slot 0 (Far Left)", "slot_pos": Vector2(-152, 405)},
		{"name": "Slot 2 (Center)", "slot_pos": Vector2(0, 405)},
		{"name": "Slot 4 (Far Right)", "slot_pos": Vector2(152, 405)},
	]

	for s in dep_slots:
		var parent = Node2D.new()
		root.add_child(parent)

		var bus = MockBus.new()
		bus.position = s["slot_pos"]
		bus.vehicle_dir = CarJamVehicleData.Direction.UP
		parent.add_child(bus)

		var mock = MockController.new()
		parent.add_child(mock)

		mock.t_depart_start = Time.get_ticks_msec() / 1000.0
		VehicleMovement.animate_departure(
			bus,
			s["slot_pos"],
			1,
			mock,
			1,
			0
		)

		# Wait for departure tween to complete (target 0.90s)
		await create_timer(1.05).timeout

		if mock.departed_time < 0:
			print("  [FAIL] %s did not complete departure!" % s["name"])
			failures += 1
		else:
			var measured = mock.departed_time - mock.t_depart_start
			var clear_time = mock.cleared_time - mock.t_depart_start if mock.cleared_time > 0 else -1.0
			print("  [MEASURED] %s: %.3fs (Target: 0.90s) | Bay Cleared: %.3fs" % [s["name"], measured, clear_time])
			if abs(measured - 0.9) <= 0.08:
				print("  [PASS] Within tolerance (±0.08s)")
			else:
				print("  [FAIL] Outside tolerance (0.90s ± 0.08s): %.3fs" % measured)
				failures += 1

		parent.queue_free()

	# Test 4: Full Game Level 1 Live Dispatch & Boarding
	print("\n--- TEST 4: Live Level 1 Scene Verification ---")
	var level_scene = CarJamLevelScene.instantiate()
	root.add_child(level_scene)
	if not level_scene.is_node_ready():
		level_scene._ready()

	await create_timer(0.2).timeout

	var ctrl: CarJamController = level_scene.controller
	if ctrl == null:
		print("  [FAIL] Controller null in level scene")
		failures += 1
	else:
		print("  [PASS] Level 1 loaded, vehicles: %d, slots: %d" % [
			ctrl.vehicles.size(), ctrl.parking.get_slot_count()
		])

		var target_vid = -1
		for vid in ctrl.vehicles:
			var v = ctrl.vehicles[vid]
			if v.can_dispatch() and ctrl.board.check_swept_escape(v)["can_escape"]:
				target_vid = vid
				break

		if target_vid == -1:
			print("  [FAIL] No dispatchable vehicle found in Level 1")
			failures += 1
		else:
			var t_live_tap = Time.get_ticks_msec() / 1000.0
			var ok = ctrl.tap_vehicle(target_vid)
			if not ok:
				print("  [FAIL] Could not tap vehicle %d" % target_vid)
				failures += 1
			else:
				print("  [PASS] Vehicle %d dispatched at %.3fs" % [target_vid, t_live_tap])
				# Wait for arrival (1.00s) + small delta
				await create_timer(1.15).timeout

				var v = ctrl.vehicles[target_vid]
				if v.state == VehicleModel.VehicleState.PARKED:
					print("  [PASS] Vehicle %d is PARKED! Live Level 1 arrival verified." % target_vid)
				else:
					print("  [FAIL] Vehicle %d state expected PARKED, got %s" % [target_vid, v.state])
					failures += 1

	level_scene.queue_free()

	# Test 5: Live Level 2 Scene Verification
	print("\n--- TEST 5: Live Level 2 Scene Verification ---")
	var mock_gc = Node.new()
	mock_gc.name = "GameController"
	mock_gc.set("current_level_number", 2)
	root.add_child(mock_gc)

	var l2_scene = CarJamLevelScene.instantiate()
	root.add_child(l2_scene)
	if not l2_scene.is_node_ready():
		l2_scene._ready()

	await create_timer(0.2).timeout

	var ctrl2: CarJamController = l2_scene.controller
	if ctrl2 == null:
		print("  [FAIL] Controller null in Level 2 scene")
		failures += 1
	else:
		print("  [PASS] Level 2 loaded, vehicles: %d, slots: %d" % [
			ctrl2.vehicles.size(), ctrl2.parking.get_slot_count()
		])

		var target_vid2 = -1
		for vid in ctrl2.vehicles:
			var v = ctrl2.vehicles[vid]
			if v.can_dispatch() and ctrl2.board.check_swept_escape(v)["can_escape"]:
				target_vid2 = vid
				break

		if target_vid2 == -1:
			print("  [FAIL] No dispatchable vehicle found in Level 2")
			failures += 1
		else:
			var t_live_tap2 = Time.get_ticks_msec() / 1000.0
			var ok2 = ctrl2.tap_vehicle(target_vid2)
			if not ok2:
				print("  [FAIL] Could not tap vehicle %d in Level 2" % target_vid2)
				failures += 1
			else:
				print("  [PASS] Level 2 vehicle %d dispatched at %.3fs" % [target_vid2, t_live_tap2])
				# Wait for arrival (1.00s) + small delta
				await create_timer(1.15).timeout

				var v2 = ctrl2.vehicles[target_vid2]
				if v2.state == VehicleModel.VehicleState.PARKED:
					print("  [PASS] Level 2 vehicle %d is PARKED! Live Level 2 arrival verified." % target_vid2)
				else:
					print("  [FAIL] Level 2 vehicle %d state expected PARKED, got %s" % [target_vid2, v2.state])
					failures += 1

	l2_scene.queue_free()
	mock_gc.queue_free()

	# SUMMARY
	print("\n==========================================")
	if failures == 0:
		print("=== ALL TIMING TESTS PASSED (0 FAILURES) ===")
	else:
		print("=== %d TIMING TESTS FAILED ===" % failures)
	print("==========================================\n")

	quit(failures)
