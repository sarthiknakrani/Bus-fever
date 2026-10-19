extends SceneTree

const Level1ConfigClass = preload("res://scripts/data/level1_config.gd")
const BusGridControllerClass = preload("res://scripts/gameplay/bus_grid_controller.gd")
const PassengerSplineQueueClass = preload("res://scripts/gameplay/passenger_spline_queue.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n=======================================================")
	print("=== QA: LEVEL 1 AUTHORITATIVE SIMULATION TEST ===")
	print("=======================================================")

	var config = Level1ConfigClass.new()
	var root_node := Node2D.new()
	root.add_child(root_node)

	var parking_layer := Node2D.new()
	var bus_layer := Node2D.new()
	var vfx_layer := Node2D.new()
	root_node.add_child(parking_layer)
	root_node.add_child(bus_layer)
	root_node.add_child(vfx_layer)

	var bus_ctrl = BusGridControllerClass.new()
	root_node.add_child(bus_ctrl)
	bus_ctrl.setup(config, bus_layer, parking_layer, vfx_layer)

	var spline_queue = PassengerSplineQueueClass.new()
	root_node.add_child(spline_queue)

	# Build Curve2D from normalized points
	var curve := Curve2D.new()
	var ref_sz: Vector2 = config.reference_size
	for pt in config.spline_normalized_points:
		curve.add_point(Vector2(pt.x * ref_sz.x, pt.y * ref_sz.y))

	spline_queue.setup(
		curve,
		config.passenger_batches,
		ref_sz,
		config.row_stride,
		config.queue_speed,
		config.spawn_interval
	)
	spline_queue.get_parked_slots_callable = Callable(bus_ctrl, "get_parked_slots_data")

	print("[INIT] Queue initialized with %d rows (%d passengers)" % [
		spline_queue.get_remaining_rows_count(),
		spline_queue.get_remaining_passengers_count()
	])
	assert(spline_queue.get_remaining_rows_count() == 60, "Must be exactly 60 rows")
	assert(spline_queue.get_remaining_passengers_count() == 240, "Must be exactly 240 passengers")

	# Test 1: Verify initial blocking states
	print("\n--- Test 1: Initial Blocking Checks ---")
	assert(bus_ctrl._get_blocker_for_bus(bus_ctrl.buses[1]) == -1, "Bus 1 must be unblocked")
	assert(bus_ctrl._get_blocker_for_bus(bus_ctrl.buses[2]) == -1, "Bus 2 must be unblocked")
	assert(bus_ctrl._get_blocker_for_bus(bus_ctrl.buses[3]) == 1, "Bus 3 must be blocked by Bus 1")
	assert(bus_ctrl._get_blocker_for_bus(bus_ctrl.buses[4]) == -1, "Bus 4 must be unblocked")
	assert(bus_ctrl._get_blocker_for_bus(bus_ctrl.buses[5]) == 4, "Bus 5 must be blocked by Bus 4")
	assert(bus_ctrl._get_blocker_for_bus(bus_ctrl.buses[6]) == 4, "Bus 6 must be blocked by Bus 4")
	print("[PASS] All initial blocking states match specification exactly!")

	# Simulate gameplay by tapping buses in solve order:
	# Tap order: 1 (Blue) -> 2 (Yellow) -> 4 (Blue) -> 3 (Yellow) -> 5 (Red) -> 6 (Red)
	var win_state := {"reached": false}
	bus_ctrl.all_buses_departed.connect(func():
		print("\n[EVENT] All 6 buses have completed boarding and departed!")
		win_state["reached"] = true
	)

	var dt := 1.0 / 60.0
	var sim_time := 0.0

	# 1. Tap Bus 1 (Blue) immediately
	var t1 = bus_ctrl.tap_bus(1)
	assert(t1, "Bus 1 tap must succeed")
	print("[TAP] Bus 1 (Blue) tapped -> Slot 1")

	# 2. Tap Bus 2 (Yellow)
	var t2 = bus_ctrl.tap_bus(2)
	assert(t2, "Bus 2 tap must succeed")
	print("[TAP] Bus 2 (Yellow) tapped -> Slot 2")

	# 3. Tap Bus 4 (Blue)
	var t4 = bus_ctrl.tap_bus(4)
	assert(t4, "Bus 4 tap must succeed")
	print("[TAP] Bus 4 (Blue) tapped -> Slot 3")

	# Run simulation and dynamically tap unblocked buses as blockers depart/dispatch
	var tapped_3 := false
	var tapped_5 := false
	var tapped_6 := false

	while sim_time < 45.0 and not win_state["reached"]:
		# Process systems
		spline_queue._process(dt)
		
		# Check if Bus 3 can be tapped (once Bus 1 is dispatched/parked)
		if not tapped_3 and bus_ctrl._get_blocker_for_bus(bus_ctrl.buses[3]) == -1:
			if bus_ctrl.tap_bus(3):
				tapped_3 = true
				print("[TAP] Bus 3 (Yellow) unblocked and tapped!")

		# Check if Bus 5 and 6 can be tapped (once Bus 4 is dispatched/parked)
		if not tapped_5 and bus_ctrl._get_blocker_for_bus(bus_ctrl.buses[5]) == -1:
			if bus_ctrl.tap_bus(5):
				tapped_5 = true
				print("[TAP] Bus 5 (Red) unblocked and tapped!")

		if not tapped_6 and bus_ctrl._get_blocker_for_bus(bus_ctrl.buses[6]) == -1:
			if bus_ctrl.tap_bus(6):
				tapped_6 = true
				print("[TAP] Bus 6 (Red) unblocked and tapped!")

		await process_frame
		sim_time += dt

	print("\nSimulated time: %.2fs" % sim_time)
	print("Remaining rows: ", spline_queue.get_remaining_rows_count())
	print("Remaining passengers: ", spline_queue.get_remaining_passengers_count())

	assert(win_state["reached"], "Level 1 must cleanly reach win state!")
	assert(spline_queue.get_remaining_rows_count() == 0, "All rows must be cleared!")
	assert(spline_queue.get_remaining_passengers_count() == 0, "All passengers must be boarded!")
	print("\n=======================================================")
	print("=== ALL 6 SPECIFICATION TESTS PASSED PERFECTLY! ===")
	print("=======================================================\n")
	root_node.queue_free()
	quit()
