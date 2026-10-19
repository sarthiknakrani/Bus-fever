extends SceneTree

func _init() -> void:
	call_deferred("_diag")

func _diag() -> void:
	var gc = root.get_node_or_null("GameController")
	if gc != null: gc.current_level_number = 1
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	
	# Tap all unblocked vehicles
	await create_timer(0.5).timeout
	for step in range(6):
		for vid in node.controller.vehicles:
			var v = node.controller.vehicles[vid]
			if v.state == VehicleModel.VehicleState.ON_BOARD:
				var esc = node.controller.board.check_swept_escape(v)
				if esc["can_escape"]:
					node._on_vehicle_tapped(vid)
					await create_timer(0.6).timeout
					break
	
	await create_timer(5.0).timeout
	
	print("\n=== DIAGNOSTIC AT T=8.0s ===")
	print("_oval_freed_capacity: ", node._oval_freed_capacity)
	print("_lead_feeder_committed: ", node._lead_feeder_committed)
	print("Circulating rows count: ", node._circulating_rows.size())
	for i in range(node._circulating_rows.size()):
		var r = node._circulating_rows[i]
		var cols = []
		for p in r.passengers: cols.append(p["color_id"])
		print("  Circ Row %d: prog=%.1f, speed=%.1f, cols=%s" % [i, r.progress, r.current_speed, str(cols)])
		
	print("Feeder rows count: ", node._feeder_rows.size())
	for j in range(mini(5, node._feeder_rows.size())):
		var r = node._feeder_rows[j]
		var cols = []
		for p in r.passengers: cols.append(p["color_id"])
		print("  Feeder Row %d: prog=%.1f, cols=%s" % [j, r.progress, str(cols)])
		
	print("Parking Slots:")
	for s_idx in node.slot_boarding_points:
		var trig = node.slot_boarding_points[s_idx]
		var s = node.controller.parking.get_slot(s_idx)
		var v_info = "EMPTY"
		if s != null and s.vehicle_id != -1:
			var v = node.controller.vehicles.get(s.vehicle_id)
			v_info = "v%d (%s) occ=%d/%d" % [v.id, v.color_id, v.passenger_occupancy, v.capacity]
		print("  Slot %d: trig=%.1f, %s" % [s_idx, trig, v_info])
		
	print("Platform range: %.1f to %.1f" % [node._platform_start_prog, node._platform_end_prog])
	quit()
