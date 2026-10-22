extends SceneTree

const CarJamLevelScene = preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run_qa")

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		printerr("[FAIL] %s" % msg)
		quit(1)
	else:
		print("  [PASS] %s" % msg)

func _run_qa() -> void:
	print("\n=================================================================")
	print("=== QA VERIFICATION: SERIALIZED BUS DEPARTURE QUEUE ===")
	print("=================================================================\n")

	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	vp.add_child(lvl)
	if not lvl.is_node_ready():
		lvl._ready()

	lvl._update_layout(Vector2(720, 1280))
	await create_timer(0.3).timeout

	var ctrl = lvl.controller
	_assert(ctrl != null, "Controller initialized")

	# Find 2 dispatchable vehicles
	var dispatchable: Array[int] = []
	for vid in ctrl.vehicles:
		var v = ctrl.vehicles[vid]
		if v.can_dispatch() and ctrl.board.check_swept_escape(v)["can_escape"]:
			dispatchable.append(vid)
			if dispatchable.size() >= 2:
				break

	_assert(dispatchable.size() >= 2, "Found at least 2 dispatchable buses for test")

	var vid_a = dispatchable[0]
	var vid_b = dispatchable[1]

	print("[QA] Dispatching Bus A (%d)..." % vid_a)
	ctrl.tap_vehicle(vid_a)
	await create_timer(0.95).timeout

	print("[QA] Dispatching Bus B (%d)..." % vid_b)
	ctrl.tap_vehicle(vid_b)
	await create_timer(0.95).timeout

	var vm_a = ctrl.vehicles[vid_a]
	var vm_b = ctrl.vehicles[vid_b]
	var slot_a = vm_a.reserved_slot
	var slot_b = vm_b.reserved_slot
	var vv_a: VehicleView = lvl.vehicle_views[vid_a]
	var vv_b: VehicleView = lvl.vehicle_views[vid_b]

	_assert(slot_a != -1 and slot_b != -1 and slot_a != slot_b, "Buses parked in separate bays")

	print("[QA] Bus A in slot %d, Bus B in slot %d" % [slot_a, slot_b])

	# Trigger departure of Bus A
	print("[QA] Filling Bus A (%d)..." % vid_a)
	lvl._on_vehicle_filled(vid_a, slot_a)
	_assert(lvl._is_bus_departing, "Bus A departure started immediately (_is_bus_departing == true)")
	_assert(lvl._departure_queue.is_empty(), "Departure queue is initially empty")

	# Immediately trigger departure of Bus B while Bus A is departing
	print("[QA] Immediately filling Bus B (%d) while Bus A is in transit..." % vid_b)
	lvl._on_vehicle_filled(vid_b, slot_b)
	_assert(lvl._departure_queue.size() == 1, "Bus B departure successfully queued (_departure_queue.size() == 1)")
	_assert(lvl._departure_queue[0]["vehicle_id"] == vid_b, "Bus B is front of departure queue")

	# Sample frames to verify that Bus B remains parked while Bus A departs
	var road_y = lvl.departure_road_y
	var overlap_count := 0
	var bus_b_moved_prematurely := false
	var initial_b_pos = vv_b.position

	var t_start = Time.get_ticks_msec() / 1000.0
	while true:
		await create_timer(0.04).timeout
		var elapsed = (Time.get_ticks_msec() / 1000.0) - t_start

		# While Bus A is departing (first 0.70s):
		if elapsed < 0.70:
			if is_instance_valid(vv_b):
				if vv_b.position.distance_to(initial_b_pos) > 5.0:
					bus_b_moved_prematurely = true

			# Count how many buses are on the departure roadway
			var buses_on_road := 0
			if is_instance_valid(vv_a) and absf(vv_a.position.y - road_y) < 25.0:
				buses_on_road += 1
			if is_instance_valid(vv_b) and absf(vv_b.position.y - road_y) < 25.0:
				buses_on_road += 1
			if buses_on_road > 1:
				overlap_count += 1

		if elapsed > 1.80:
			break

	_assert(not bus_b_moved_prematurely, "Bus B remained safely stationary in its bay while Bus A departed")
	_assert(overlap_count == 0, "Zero simultaneous buses on departure roadway (100% collision prevention)")
	_assert(lvl._departure_queue.is_empty(), "Bus B successfully dequeued and finished its departure")

	# Check both slots freed
	var state_a = ctrl.parking.get_slot(slot_a).state
	var state_b = ctrl.parking.get_slot(slot_b).state
	_assert(state_a == CarJamParkingManager.SlotState.FREE, "Slot A freed after departure")
	_assert(state_b == CarJamParkingManager.SlotState.FREE, "Slot B freed after departure")

	print("\n=================================================================")
	print("=== ALL DEPARTURE QUEUE SERIALIZATION TESTS PASSED ===")
	print("=================================================================\n")
	quit(0)
