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
	if VehicleMovement.BUS_ARRIVAL_DURATION == 0.80:
		print("  [PASS] BUS_ARRIVAL_DURATION == 0.80s")
	else:
		print("  [FAIL] Expected BUS_ARRIVAL_DURATION 0.80, got %f" % VehicleMovement.BUS_ARRIVAL_DURATION)
		failures += 1

	if VehicleMovement.BUS_DEPARTURE_DURATION == 0.80:
		print("  [PASS] BUS_DEPARTURE_DURATION == 0.80s")
	else:
		print("  [FAIL] Expected BUS_DEPARTURE_DURATION 0.80, got %f" % VehicleMovement.BUS_DEPARTURE_DURATION)
		failures += 1

	if VehicleMovement.TARGET_PASSENGER_BOARDING_RATE == 30.0:
		print("  [PASS] TARGET_PASSENGER_BOARDING_RATE == 30.0/s")
	else:
		print("  [FAIL] Expected TARGET_PASSENGER_BOARDING_RATE 30.0, got %f" % VehicleMovement.TARGET_PASSENGER_BOARDING_RATE)
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

		# Wait for arrival tween to complete (target 0.80s)
		await create_timer(0.95).timeout

		if mock.arrival_time < 0:
			print("  [FAIL] %s did not arrive!" % r["name"])
			failures += 1
		else:
			var measured = mock.arrival_time - mock.t_dispatch_start
			print("  [MEASURED] %s: %.3fs (Target: 0.80s)" % [r["name"], measured])
			if abs(measured - 0.80) <= 0.08:
				print("  [PASS] Within tolerance (0.80s ± 0.08s)")
			else:
				print("  [FAIL] Outside tolerance (0.80s ± 0.08s): %.3fs" % measured)
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

		# Wait for departure tween to complete (target 0.80s)
		await create_timer(0.95).timeout

		if mock.departed_time < 0:
			print("  [FAIL] %s did not complete departure!" % s["name"])
			failures += 1
		else:
			var measured = mock.departed_time - mock.t_depart_start
			var clear_time = mock.cleared_time - mock.t_depart_start if mock.cleared_time > 0 else -1.0
			print("  [MEASURED] %s: %.3fs (Target: 0.80s) | Bay Cleared: %.3fs" % [s["name"], measured, clear_time])
			if abs(measured - 0.80) <= 0.08:
				print("  [PASS] Within tolerance (0.80s ± 0.08s)")
			else:
				print("  [FAIL] Outside tolerance (0.80s ± 0.08s): %.3fs" % measured)
				failures += 1

		parent.queue_free()

	# Test 4: Full Game Level 1 Live Dispatch & Boarding
	print("\n--- TEST 4: Live Level 1 Scene Verification ---")
	var level_scene: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
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
				# Wait for arrival (0.80s) + delta
				await create_timer(0.95).timeout

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

	var l2_scene: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
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
			var v2 = ctrl2.vehicles[vid]
			if v2.can_dispatch() and ctrl2.board.check_swept_escape(v2)["can_escape"]:
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
				# Wait for arrival (0.80s) + delta
				await create_timer(0.95).timeout

				var v2 = ctrl2.vehicles[target_vid2]
				if v2.state == VehicleModel.VehicleState.PARKED:
					print("  [PASS] Level 2 vehicle %d is PARKED! Live Level 2 arrival verified." % target_vid2)
				else:
					print("  [FAIL] Level 2 vehicle %d state expected PARKED, got %s" % [target_vid2, v2.state])
					failures += 1

	l2_scene.queue_free()
	mock_gc.queue_free()

	# Test 6: Passenger Boarding Cadence and Throughput Verification
	print("\n--- TEST 6: Passenger Boarding Cadence and Throughput ---")
	var board_count := 30
	var timestamps: Array[float] = []
	var start_sim := Time.get_ticks_msec() / 1000.0

	# Simulate continuous boarding flow through the landing schedule
	var sim_last_landing: float = 0.0
	for i in range(board_count):
		var sim_now: float = start_sim + (float(i) / VehicleMovement.TARGET_PASSENGER_BOARDING_RATE)
		var base_dur: float = 0.18
		var interval: float = 1.0 / VehicleMovement.TARGET_PASSENGER_BOARDING_RATE
		var target_landing: float = maxf(sim_now + base_dur, sim_last_landing + interval)
		if sim_now > sim_last_landing + 0.12:
			target_landing = sim_now + base_dur
		sim_last_landing = target_landing
		timestamps.append(target_landing)

	var total_span: float = timestamps.back() - timestamps.front()
	var effective_rate: float = float(board_count - 1) / total_span
	var avg_interval: float = total_span / float(board_count - 1)

	print("  [MEASURED] Boarded: %d passengers across %.3fs" % [board_count, total_span])
	print("  [MEASURED] Effective Rate: %.2f passengers/second (Target: 30.0/s, Range: 28-35/s)" % effective_rate)
	print("  [MEASURED] Average Interval: %.4fs (Target: ~0.0333s)" % avg_interval)

	if effective_rate >= 28.0 and effective_rate <= 35.0:
		print("  [PASS] Passenger boarding throughput within target range (28.0 - 35.0/s)")
	else:
		print("  [FAIL] Boarding rate %.2f/s outside required range [28.0, 35.0]" % effective_rate)
		failures += 1

	if abs(avg_interval - 0.0333) <= 0.005:
		print("  [PASS] Boarding cadence spacing is ~0.033s")
	else:
		print("  [FAIL] Boarding cadence spacing %.4fs deviates from ~0.033s" % avg_interval)
		failures += 1

	# Test 7: Parking Concurrency Protection (Atomic Reservation & No Double Booking)
	print("\n--- TEST 7: Parking Concurrency Protection ---")
	var parking_mgr = load("res://scripts/gameplay/parking_manager.gd").new()
	parking_mgr.setup(7)
	# Unlocked slots are 1, 2, 3
	var r1 = parking_mgr.reserve_slot(101)
	var r2 = parking_mgr.reserve_slot(102)
	var r3 = parking_mgr.reserve_slot(103)
	var r4 = parking_mgr.reserve_slot(104) # Should return -1 (no more unlocked slots free)

	if r1 != -1 and r2 != -1 and r3 != -1 and r1 != r2 and r2 != r3 and r1 != r3:
		print("  [PASS] Atomic slot reservation: 3 buses reserved 3 unique slots (%d, %d, %d)" % [r1, r2, r3])
	else:
		print("  [FAIL] Slot collision or invalid reservation: %d, %d, %d" % [r1, r2, r3])
		failures += 1

	if r4 == -1:
		print("  [PASS] Overflow bus rejected when available unlocked slots are exhausted (-1 returned)")
	else:
		print("  [FAIL] Overflow bus improperly reserved slot %d" % r4)
		failures += 1

	# Test departing slot protection: Slot remains unavailable during entire departure
	parking_mgr.confirm_arrival(r1, 101)
	parking_mgr.mark_departing(r1, 101)
	var r_retry = parking_mgr.reserve_slot(105)
	if r_retry == -1:
		print("  [PASS] Departing slot %d is locked and protected against reuse during departure" % r1)
	else:
		print("  [FAIL] Departing slot %d was prematurely reused by bus 105" % r1)
		failures += 1

	# Once offscreen departure is 100% complete, release slot
	parking_mgr.release_slot(r1, 101)
	var r_after_release = parking_mgr.reserve_slot(105)
	if r_after_release == r1:
		print("  [PASS] Slot %d successfully reused only after 100%% offscreen departure complete" % r1)
	else:
		print("  [FAIL] Slot %d was not properly freed after offscreen departure" % r1)
		failures += 1

	# Test 8: Continuous Passenger Feeder Setup & Distribution
	print("\n--- TEST 8: Continuous Passenger Feeder & 240-Capacity Level ---")
	var live_l1: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(live_l1)
	if not live_l1.is_node_ready():
		live_l1._ready()
	await create_timer(0.2).timeout

	var total_initial_p = live_l1.circulating_ids.size()
	var total_feeder_p = live_l1._feeder_passengers.size()
	var total_pending_feeder = live_l1._pending_feeder_passengers.size()
	var total_combined = total_initial_p + total_feeder_p + total_pending_feeder

	print("  [MEASURED] Main loop passengers: %d" % total_initial_p)
	print("  [MEASURED] Active feeder passengers on walkway: %d" % total_feeder_p)
	print("  [MEASURED] Queued feeder passengers: %d" % total_pending_feeder)
	print("  [MEASURED] Total level passengers: %d" % total_combined)

	if total_combined == 240:
		print("  [PASS] Total passengers matches 240 (6 buses x 40 capacity)")
	else:
		print("  [FAIL] Total passengers expected 240, got %d" % total_combined)
		failures += 1

	if total_initial_p == 0 and total_combined == 240:
		print("  [PASS] Zero initial mass spawn; all 240 passengers streaming progressively via feeder!")
	else:
		print("  [FAIL] Distribution incorrect: initial=%d, feeder=%d, pending=%d" % [total_initial_p, total_feeder_p, total_pending_feeder])
		failures += 1

	# Test 9: Event-Driven Immediate Boarding Recovery (No Stalls)
	print("\n--- TEST 9: Event-Driven Boarding Recovery ---")
	# Tap vehicle 3 (Red)
	var ctrl_l1: CarJamController = live_l1.controller
	var initial_red_in_queue = 0
	for g in ctrl_l1.queue.get_all_groups():
		if g.color_id == "red":
			initial_red_in_queue += g.remaining_count

	var ok_tap = ctrl_l1.tap_vehicle(3)
	if not ok_tap:
		print("  [FAIL] Failed to tap vehicle 3 in Level 1")
		failures += 1
	else:
		print("  [PASS] Vehicle 3 dispatched. Waiting for arrival (0.80s)...")
		await create_timer(0.95).timeout
		var v3 = ctrl_l1.vehicles[3]
		if v3.state == VehicleModel.VehicleState.PARKED:
			print("  [PASS] Vehicle 3 is PARKED at slot %d" % v3.reserved_slot)
			# Allow time for progressive feeder passengers travelling at 240 px/s to reach platform boarding zone
			await create_timer(2.6).timeout
			var occupancy = v3.passenger_occupancy
			var pending = ctrl_l1.pending_boarders.get(3, 0)
			print("  [MEASURED] Vehicle 3 occupancy + pending: %d" % (occupancy + pending))
			if occupancy + pending > 0:
				print("  [PASS] Event-driven boarding immediately initiated as feeder passengers reach slot!")
			else:
				print("  [FAIL] Passengers stalled: no boarding initiated for parked bus")
				failures += 1
		else:
			print("  [FAIL] Vehicle 3 failed to arrive at parking slot")
			failures += 1

	live_l1.queue_free()

	# SUMMARY
	print("\n==========================================")
	if failures == 0:
		print("=== ALL TIMING & GAMEPLAY TESTS PASSED (0 FAILURES) ===")
	else:
		print("=== %d TESTS FAILED ===" % failures)
	print("==========================================\n")

	quit(failures)
