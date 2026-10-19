
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	print("Simulating 600 frames of gameplay and checking for ANY overlaps (<28px)...")
	var max_frames = 600
	var total_overlaps = 0
	
	for f in range(max_frames):
		await process_frame
		
		# Tap unblocked vehicle if slot free
		if f % 30 == 0:
			for vid in node.controller.vehicles:
				var v = node.controller.vehicles[vid]
				if v.state == VehicleModel.VehicleState.ON_BOARD:
					var esc = node.controller.board.check_swept_escape(v)
					if esc["can_escape"]:
						node._on_vehicle_tapped(vid)
						break
						
		# Check overlap between all active circulating and feeder passenger views
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
						if total_overlaps <= 5:
							print("Frame %d OVERLAP: %s %d vs %s %d | dist = %.1f px" % [f, p1["type"], p1["id"], p2["type"], p2["id"], d])
							
	print("Long simulation complete across %d frames. Total overlaps: %d" % [max_frames, total_overlaps])
	quit()
