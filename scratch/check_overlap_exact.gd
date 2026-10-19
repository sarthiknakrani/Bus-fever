
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	var pc = node.passenger_track.curve
	var track_len = pc.get_baked_length()
	var fc = node.feeder_track.curve
	var f_len = fc.get_baked_length()
	
	var loop_pts = []
	for r in range(44):
		var prog = fmod(node._platform_start_prog - float(r) * 26.0 + track_len * 10.0, track_len)
		var p_info = node._get_curve_point_and_normal(pc, prog, true)
		for lane in 4:
			loop_pts.append(node._calc_lane_pos(p_info["pos"], p_info["normal"], lane))
			
	var feeder_pts = []
	var feeder_stop_pos = f_len - 208.0
	for j in range(16):
		var prog = feeder_stop_pos - float(j) * 26.0
		var f_info = node._get_curve_point_and_normal(fc, prog, false)
		for lane in 4:
			feeder_pts.append(node._calc_lane_pos(f_info["pos"], f_info["normal"], lane))
			
	var min_dist = 9999.0
	var overlap_count = 0
	for lp in loop_pts:
		for fp in feeder_pts:
			var d = lp.distance_to(fp)
			if d < min_dist: min_dist = d
			if d < 30.0:
				overlap_count += 1
				
	print("OVERLAP CHECK: min_dist between Loop and Feeder = %.2f px | Overlaps (<30px): %d" % [min_dist, overlap_count])
	quit()
