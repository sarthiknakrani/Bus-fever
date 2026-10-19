extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	get_root().size = Vector2i(720, 1280)

	var scene = load("res://scenes/level1.tscn")
	var lvl: CarJamLevel = scene.instantiate()
	root.add_child(lvl)

	await create_timer(0.4).timeout
	print("[WIN FLOW] Level loaded! Starting taps...")

	# Step 1: Tap Bus 2 (Blue) -> unblocks Bus 1 and Bus 4
	var t2 = lvl.controller.tap_vehicle(2)
	print("Tap Bus 2 (Blue):", t2)
	assert(t2, "Bus 2 must dispatch")

	await create_timer(0.7).timeout

	# Step 2: Tap Bus 1 (Yellow) -> now unblocked!
	var t1 = lvl.controller.tap_vehicle(1)
	print("Tap Bus 1 (Yellow):", t1)
	assert(t1, "Bus 1 must dispatch")

	# Wait for Yellow to board Bus 1 and Bus 1 to depart
	var v1 = lvl.controller.vehicles[1]
	var v2 = lvl.controller.vehicles[2]
	var timeout := 0
	while v1.state != VehicleModel.VehicleState.COMPLETED and timeout < 600:
		lvl._process(1.0 / 60.0)
		await process_frame
		timeout += 1

	print("Bus 1 occupancy:", v1.passenger_occupancy, " state:", v1.state)
	assert(v1.passenger_occupancy == 40, "Bus 1 must have 40 passengers")

	# Wait for Blue to board Bus 2 and Bus 2 to depart
	timeout = 0
	while v2.state != VehicleModel.VehicleState.COMPLETED and timeout < 600:
		lvl._process(1.0 / 60.0)
		await process_frame
		timeout += 1

	print("Bus 2 occupancy:", v2.passenger_occupancy, " state:", v2.state)
	assert(v2.passenger_occupancy == 40, "Bus 2 must have 40 passengers")

	# Step 3: Tap Bus 5 (Blue) -> unblocks Bus 3 and Bus 6
	var t5 = lvl.controller.tap_vehicle(5)
	print("Tap Bus 5 (Blue):", t5)
	assert(t5, "Bus 5 must dispatch")

	await create_timer(0.7).timeout

	# Step 4: Tap Bus 3 (Red)
	var t3 = lvl.controller.tap_vehicle(3)
	print("Tap Bus 3 (Red):", t3)
	assert(t3, "Bus 3 must dispatch")

	var v3 = lvl.controller.vehicles[3]
	var v5 = lvl.controller.vehicles[5]
	timeout = 0
	while v3.state != VehicleModel.VehicleState.COMPLETED and timeout < 600:
		lvl._process(1.0 / 60.0)
		await process_frame
		timeout += 1

	print("Bus 3 occupancy:", v3.passenger_occupancy, " state:", v3.state)
	assert(v3.passenger_occupancy == 40, "Bus 3 must have 40 passengers")

	# Step 5: Tap Bus 6 (Red)
	var t6 = lvl.controller.tap_vehicle(6)
	print("Tap Bus 6 (Red):", t6)
	assert(t6, "Bus 6 must dispatch")

	var v6 = lvl.controller.vehicles[6]
	timeout = 0
	while v6.state != VehicleModel.VehicleState.COMPLETED and timeout < 600:
		lvl._process(1.0 / 60.0)
		await process_frame
		timeout += 1

	print("Bus 6 occupancy:", v6.passenger_occupancy, " state:", v6.state)
	assert(v6.passenger_occupancy == 40, "Bus 6 must have 40 passengers")

	# Wait for Blue to board Bus 5
	timeout = 0
	while v5.state != VehicleModel.VehicleState.COMPLETED and timeout < 600:
		lvl._process(1.0 / 60.0)
		await process_frame
		timeout += 1

	print("Bus 5 occupancy:", v5.passenger_occupancy, " state:", v5.state)
	assert(v5.passenger_occupancy == 40, "Bus 5 must have 40 passengers")

	# Step 6: Tap Bus 4 (Yellow)
	var t4 = lvl.controller.tap_vehicle(4)
	print("Tap Bus 4 (Yellow):", t4)
	assert(t4, "Bus 4 must dispatch")

	var v4 = lvl.controller.vehicles[4]
	timeout = 0
	while v4.state != VehicleModel.VehicleState.COMPLETED and timeout < 600:
		lvl._process(1.0 / 60.0)
		await process_frame
		timeout += 1

	print("Bus 4 occupancy:", v4.passenger_occupancy, " state:", v4.state)
	assert(v4.passenger_occupancy == 40, "Bus 4 must have 40 passengers")

	# Wait for level completed
	await create_timer(1.0).timeout
	print("[WIN FLOW] All 6 buses boarded and departed successfully!")
	print("Controller state:", lvl.controller.state)

	var img = get_root().get_texture().get_image()
	if img != null:
		img.save_png("scratch/flawless_win_screen.png")
		print("Saved scratch/flawless_win_screen.png")

	lvl.queue_free()
	quit()
