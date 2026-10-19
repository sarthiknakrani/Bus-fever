
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	var pc = node.passenger_track.curve
	var track_len = pc.get_baked_length()
	var merge_pt: Vector2 = pc.sample_baked(node._merge_prog)
	
	var test_f_curve = Curve2D.new()
	test_f_curve.add_point(Vector2(358, -520), Vector2.ZERO, Vector2(0, 120))
	test_f_curve.add_point(Vector2(348, -110), Vector2(10, -60), Vector2(-10, 60))
	test_f_curve.add_point(Vector2(315, 20), Vector2(20, -40), Vector2(-25, 35))
	test_f_curve.add_point(merge_pt, Vector2(30, -28), Vector2.ZERO)
	
	var tr = node.passenger_track_bg.get_node("TrackRenderer")
	tr.feeder_curve = test_f_curve
	tr.compute_intersections()
	print("inner_meet_ang: ", tr.inner_meet_ang)
	print("outer_meet_ang: ", tr.outer_meet_ang)
	
	var f_len = test_f_curve.get_baked_length()
	var feeder_stop = f_len - 150.0
	
	# Check distance between loop and feeder at feeder_stop
	var min_dist_all = 9999.0
	for prog_f in range(int(feeder_stop - 200), int(feeder_stop + 1), 30):
		var f_info = node._get_curve_point_and_normal(test_f_curve, float(prog_f), false)
		for f_lane in 4:
			var f_pos = node._calc_lane_pos(f_info["pos"], f_info["normal"], f_lane)
			for loop_prog in range(0, int(track_len), 4):
				var p_info = node._get_curve_point_and_normal(pc, float(loop_prog), true)
				for p_lane in 4:
					var p_pos = node._calc_lane_pos(p_info["pos"], p_info["normal"], p_lane)
					var d = f_pos.distance_to(p_pos)
					if d < min_dist_all:
						min_dist_all = d
	print("Min distance across all lanes: %.1f px" % min_dist_all)
	print("Has overlaps (< 30px): %s" % (min_dist_all < 30.0))
	quit()
