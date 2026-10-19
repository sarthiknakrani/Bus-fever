
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	print("Simulating runtime frames and checking for ANY overlaps (<30px) between all passengers...")
	var max_frames = 180
	var total_overlaps = 0
	
	# Tap vehicle 1 (Blue) to start boarding
	if node.controller.vehicles.has(1):
		node._on_vehicle_tapped(1)
		
	for f in range(max_frames):
		await process_frame
		
		# Tap next bus when slot available
		if f == 60 and node.controller.vehicles.has(2):
			node._on_vehicle_tapped(2)
		if f == 120 and node.controller.vehicles.has(4):
			node._on_vehicle_tapped(4)
			
		# Check overlap between all active passenger views
		var views = []
		for cr in node._circulating_rows:
			for cp in cr.passengers:
				if is_instance_valid(cp.get("view")):
					views.append({"pos": cp["view"].position, "id": cp["id"], "type": "circ"})
		for fr in node._feeder_rows:
			for fp in fr.passengers:
				if is_instance_valid(fp.get("view")):
					views.append({"pos": fp["view"].position, "id": fp["id"], "type": "feed"})
					
		for i in range(views.size()):
			var p1 = views[i]
			for j in range(i + 1, views.size()):
				var p2 = views[j]
				if p1["type"] != p2["type"]:
					var d = p1["pos"].distance_to(p2["pos"])
					if d < 28.0:
						total_overlaps += 1
						print("Frame %d OVERLAP: %s %d vs %s %d | dist = %.1f px" % [f, p1["type"], p1["id"], p2["type"], p2["id"], d])
						
	print("Runtime simulation complete across %d frames. Total overlaps: %d" % [max_frames, total_overlaps])
	quit()
