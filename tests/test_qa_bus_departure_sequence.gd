extends SceneTree

const CarJamLevelScene = preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run_qa")

func _run_qa() -> void:
	print("\n=======================================================")
	print("=== QA VERIFICATION: BUS REVERSE & ROAD DEPARTURE ===")
	print("=======================================================\n")

	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	vp.add_child(lvl)
	if not lvl.is_node_ready():
		lvl._ready()

	if lvl.camera_2d != null:
		lvl.camera_2d.enabled = true
		lvl.camera_2d.make_current()

	lvl._update_layout(Vector2(720, 1280))
	await create_timer(0.3).timeout

	var ctrl = lvl.controller
	var l_data = ctrl.level_data
	print("[QA] Loaded level %d with %d vehicles and %d slots" % [
		l_data.level_id, ctrl.vehicles.size(), ctrl.parking.get_slot_count()
	])

	# 1. Tap an unblocked vehicle to dispatch to parking
	var target_vid = -1
	for vid in ctrl.vehicles:
		var v = ctrl.vehicles[vid]
		if v.can_dispatch() and ctrl.board.check_swept_escape(v)["can_escape"]:
			target_vid = vid
			break

	assert(target_vid != -1, "Must find dispatchable vehicle")
	print("[QA] Tapping vehicle %d to dispatch..." % target_vid)
	var ok = ctrl.tap_vehicle(target_vid)
	assert(ok, "Failed to tap vehicle")

	# Wait for bus arrival in slot (0.80s + settle)
	await create_timer(0.95).timeout

	var v_model = ctrl.vehicles[target_vid]
	var assigned_slot = v_model.reserved_slot
	var vv: VehicleView = lvl.vehicle_views[target_vid]
	print("[QA] Bus %d arrived in slot %d at position %s, rot=%.2f deg" % [
		target_vid, assigned_slot, str(vv.position), rad_to_deg(vv.rotation)
	])

	# Capture Snapshot 1: Parked in slot
	var img = vp.get_texture().get_image()
	if img != null:
		img.save_png("qa_departure_1_parked.png")
		print("[QA] Saved: qa_departure_1_parked.png")

	# 2. Fill the bus to full capacity to trigger departure
	print("[QA] Filling bus %d to full capacity (%d passengers)..." % [target_vid, v_model.capacity])
	var initial_slot_pos = lvl._get_slot_world_pos(assigned_slot)
	var road_y = lvl.departure_road_y

	# Track trajectory during departure
	var positions: Array[Vector2] = []
	var rotations: Array[float] = []
	var timestamps: Array[float] = []

	var t_start = Time.get_ticks_msec() / 1000.0

	# Fill bus and trigger departure
	v_model.passenger_occupancy = v_model.capacity
	ctrl.vehicle_filled.emit(target_vid, assigned_slot)

	# Monitor departure animation over time
	var snap2_taken := false
	var snap3_taken := false
	var snap4_taken := false

	while true:
		await create_timer(0.04).timeout
		var t_now = Time.get_ticks_msec() / 1000.0
		var elapsed = t_now - t_start

		if is_instance_valid(vv) and vv.visible:
			var p = vv.position
			var r = vv.rotation
			positions.append(p)
			rotations.append(r)
			timestamps.append(elapsed)

			# Verify coordinate health: bus must NEVER move upward into the board/track!
			# In world_root coordinates, Y decreases upward. So p.y must never be significantly
			# higher (more negative) than initial_slot_pos.y!
			if p.y < initial_slot_pos.y - 20.0:
				printerr("[FAIL] Bus Y jumped upward: %.1f vs slot Y %.1f" % [p.y, initial_slot_pos.y])
				quit(1)
				return

			# Snapshot 2: Reversing backward out of slot (~0.18s)
			if elapsed >= 0.16 and elapsed <= 0.28 and not snap2_taken:
				snap2_taken = true
				var im2 = vp.get_texture().get_image()
				if im2 != null:
					im2.save_png("qa_departure_2_reversing.png")
					print("[QA] Saved: qa_departure_2_reversing.png at %.3fs (Pos: %s)" % [elapsed, str(p)])

			# Snapshot 3: Turning onto the grey roadway (~0.38s)
			if elapsed >= 0.35 and elapsed <= 0.48 and not snap3_taken:
				snap3_taken = true
				var im3 = vp.get_texture().get_image()
				if im3 != null:
					im3.save_png("qa_departure_3_roadway_turn.png")
					print("[QA] Saved: qa_departure_3_roadway_turn.png at %.3fs (Pos: %s, Rot: %.1f deg)" % [
						elapsed, str(p), rad_to_deg(r)
					])

			# Snapshot 4: Driving forward along the grey road towards right exit (~0.60s)
			if elapsed >= 0.55 and elapsed <= 0.70 and not snap4_taken:
				snap4_taken = true
				var im4 = vp.get_texture().get_image()
				if im4 != null:
					im4.save_png("qa_departure_4_roadway_forward.png")
					print("[QA] Saved: qa_departure_4_roadway_forward.png at %.3fs (Pos: %s)" % [elapsed, str(p)])

		if elapsed > 1.05:
			break

	# Snapshot 5: Departure complete, slot released
	var im5 = vp.get_texture().get_image()
	if im5 != null:
		im5.save_png("qa_departure_5_departed.png")
		print("[QA] Saved: qa_departure_5_departed.png")

	# Evaluate trajectory physics
	print("\n--- TRAJECTORY EVALUATION ---")
	print("Recorded %d trajectory samples." % positions.size())
	assert(positions.size() > 10, "Too few trajectory samples recorded")

	var p_start = positions.front()
	var p_end = positions.back()

	print("Start Pos: %s | End Pos: %s | Target Road Y: %.1f" % [str(p_start), str(p_end), road_y])

	# 1. Reverse check: bus moved DOWNWARDS (+Y) along bay axis from slot to road
	var max_y = -99999.0
	for p in positions:
		if p.y > max_y:
			max_y = p.y
	print("Max Y reached: %.1f (Expected road Y ~%.1f)" % [max_y, road_y])
	assert(absf(max_y - road_y) <= 15.0, "Bus did not reach grey road Y centerline!")
	print("  [PASS] Bus reached grey road centerline (within ±15px of %.1f)" % road_y)

	# 2. Forward exit check: bus drove horizontally along +X off the screen
	assert(p_end.x > 360.0, "Bus did not reach right screen border (+360px)")
	print("  [PASS] Bus drove past right screen edge to X=%.1f" % p_end.x)

	# 3. Roadway alignment check: while driving forward, bus Y stayed strictly on the grey road
	var roadway_samples = 0
	for i in range(positions.size()):
		var p = positions[i]
		if p.x > p_start.x + 100.0:
			roadway_samples += 1
			assert(absf(p.y - road_y) <= 5.0, "Bus Y deviated from grey road during forward drive: %.1f vs %.1f" % [p.y, road_y])
	assert(roadway_samples > 3, "Not enough roadway samples")
	print("  [PASS] Bus Y stayed strictly on grey road centerline across %d forward drive frames" % roadway_samples)

	# 4. Final slot release check
	var slot_state = ctrl.parking.get_slot(assigned_slot).state
	assert(slot_state == CarJamParkingManager.SlotState.FREE, "Slot was not freed after departure")
	print("  [PASS] Slot %d successfully freed back to FREE" % assigned_slot)

	print("\n=======================================================")
	print("=== ALL DEPARTURE CHECKS PASSED WITH ZERO ERRORS ===")
	print("=======================================================\n")
	quit(0)
