extends SceneTree

const Level1Scene = preload("res://scenes/level1.tscn")

func _init():
	call_deferred("_run")

func _run():
	print("\n--- TESTING CONTINUOUS SPATIAL FEEDER ADMISSION ---")
	var gc = root.get_node_or_null("GameController")
	if gc:
		gc.current_level_number = 1

	var lvl: CarJamLevel = Level1Scene.instantiate()
	root.add_child(lvl)
	await process_frame

	var dt := 1.0 / 60.0
	var sim_time := 0.0
	var win_fired := false
	lvl.level_completed.connect(func():
		win_fired = true
		print("[EVENT] level_completed fired at sim_time = %.2f" % sim_time)
	)

	while sim_time < 20.0 and not win_fired:
		# Periodically tap vehicles
		for vid in [2, 3, 6, 5, 1, 4]:
			if lvl.controller.vehicles.has(vid):
				var v = lvl.controller.vehicles[vid]
				if v.state == VehicleModel.VehicleState.ON_BOARD and lvl.controller.parking.find_available_slot() != -1:
					var ok = lvl.controller.tap_vehicle(vid)
					if ok:
						print("[SIM %.2fs] Tapped Vehicle %d (%s)" % [sim_time, vid, v.color_id])

		lvl._process(dt)
		await process_frame
		sim_time += dt

	print("\nEnd of sim at %.2fs. Win fired: %s" % [sim_time, win_fired])
	print("Authoritative passengers remaining unboarded:")
	var unboarded := 0
	for pid in lvl.controller.authoritative_passengers:
		var p = lvl.controller.authoritative_passengers[pid]
		if p.state != "BOARDED":
			unboarded += 1
	print("  Unboarded count: ", unboarded)
	print("Queue remaining: ", lvl.controller.queue.get_remaining_total())
	print("Controller state: ", lvl.controller.state)

	lvl.queue_free()
	quit()
