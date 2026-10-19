
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	
	var fc = node.feeder_track.curve
	var pc = node.passenger_track.curve
	var f_len = fc.get_baked_length()
	var track_len = pc.get_baked_length()
	
	var loop_pts = []
	for loop_prog in range(0, int(track_len), 2):
		var p_info = node._get_curve_point_and_normal(pc, float(loop_prog), true)
		for lane in 4:
			loop_pts.append(node._calc_lane_pos(p_info["pos"], p_info["normal"], lane))
			
	print("Checking live feeder curve clearance across distances:")
	for dist_from_end in range(200, 260, 5):
		var s = f_len - float(dist_from_end)
		var f_pt_info = node._get_curve_point_and_normal(fc, s, false)
		var min_d = 9999.0
		for f_lane in 4:
			var f_pos = node._calc_lane_pos(f_pt_info["pos"], f_pt_info["normal"], f_lane)
			for lp in loop_pts:
				var d = f_pos.distance_to(lp)
				if d < min_d: min_d = d
		print("dist_from_end: %d | pos: %s | min_d: %.2f px | overlap (<30px): %s" % [
			dist_from_end, f_pt_info["pos"], min_d, min_d < 30.0
		])
	quit()
