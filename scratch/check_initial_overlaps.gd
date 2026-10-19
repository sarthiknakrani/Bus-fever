
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	print("Checking INITIAL overlaps at t = 0:")
	var overlap_count = 0
	for cr in node._circulating_rows:
		for cp in cr.passengers:
			var c_pos = cp["view"].position
			for fr in node._feeder_rows:
				for fp in fr.passengers:
					var f_pos = fp["view"].position
					var d = c_pos.distance_to(f_pos)
					if d < 32.0:
						overlap_count += 1
						print("INITIAL OVERLAP! Circ row prog %.1f (lane %d) at %s vs Feeder row prog %.1f (lane %d) at %s | dist = %.1f px" % [
							cr.progress, cp["lane"], c_pos, fr.progress, fp["lane"], f_pos, d
						])
	print("Total initial overlapping pairs: %d" % overlap_count)
	quit()
