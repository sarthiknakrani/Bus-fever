
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	var fc = node.feeder_track.curve
	var pc = node.passenger_track.curve
	var f_len = fc.get_baked_length()
	var track_len = pc.get_baked_length()
	
	# Sample loop track along right arc (progs from 1000 to 1142, and 0 to 100)
	var loop_pts = []
	for p in range(0, int(track_len), 2):
		var p_info = node._get_curve_point_and_normal(pc, float(p), true)
		for l in 4:
			loop_pts.append(node._calc_lane_pos(p_info["pos"], p_info["normal"], l))
			
	print("Checking EXACT dist_from_end for clearance >= 34.0px:")
	for d in range(200, 270, 5):
		var s = f_len - float(d)
		var f_info = node._get_curve_point_and_normal(fc, s, false)
		var min_d = 9999.0
		for fl in 4:
			var f_pos = node._calc_lane_pos(f_info["pos"], f_info["normal"], fl)
			for lp in loop_pts:
				var dist = f_pos.distance_to(lp)
				if dist < min_d: min_d = dist
		print("d = %d | s = %.2f | min_dist = %.2f px | SAFE (>=34px): %s" % [d, s, min_d, min_d >= 34.0])
	quit()
