
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	var pc = node.passenger_track.curve
	var track_len = pc.get_baked_length()
	var merge_pt: Vector2 = pc.sample_baked(node._merge_prog)
	
	# Test new feeder curve with Point 2 shifted out to avoid right-arc overlap
	var test_f_curve = Curve2D.new()
	test_f_curve.add_point(Vector2(350, -520), Vector2.ZERO, Vector2(0, 120))
	test_f_curve.add_point(Vector2(345, -110), Vector2(10, -60), Vector2(-10, 60))
	test_f_curve.add_point(Vector2(335, 15), Vector2(15, -45), Vector2(-20, 45))
	test_f_curve.add_point(merge_pt, Vector2(30, -28), Vector2.ZERO)
	
	var f_len = test_f_curve.get_baked_length()
	print("New Feeder len: ", f_len)
	
	# Sample loop track along its entire length across all 4 lanes
	var loop_pts = []
	for loop_prog in range(0, int(track_len), 3):
		var p_info = node._get_curve_point_and_normal(pc, float(loop_prog), true)
		for lane in 4:
			loop_pts.append(node._calc_lane_pos(p_info["pos"], p_info["normal"], lane))
			
	print("Checking new feeder positions for distance to loop:")
	for dist_from_end in range(50, 150, 5):
		var s = f_len - dist_from_end
		var f_pt_info = node._get_curve_point_and_normal(test_f_curve, s, false)
		var min_d = 9999.0
		for f_lane in 4:
			var f_pos = node._calc_lane_pos(f_pt_info["pos"], f_pt_info["normal"], f_lane)
			for lp in loop_pts:
				var d = f_pos.distance_to(lp)
				if d < min_d:
					min_d = d
		print("dist_from_end: %3d | min_dist_to_loop = %5.1f px | overlaps (<32px): %s" % [
			dist_from_end, min_d, min_d < 32.0
		])
	quit()
