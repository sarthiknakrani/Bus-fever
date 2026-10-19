
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	var pc = node.passenger_track.curve
	var track_len = pc.get_baked_length()
	var merge_pt: Vector2 = pc.sample_baked(node._merge_prog)
	
	# Test the properly spaced feeder curve
	var test_f_curve = Curve2D.new()
	test_f_curve.add_point(Vector2(370, -520), Vector2.ZERO, Vector2(0, 120))
	test_f_curve.add_point(Vector2(365, -110), Vector2(10, -60), Vector2(-10, 60))
	test_f_curve.add_point(Vector2(350, 15), Vector2(15, -45), Vector2(-25, 45))
	test_f_curve.add_point(merge_pt, Vector2(30, -28), Vector2.ZERO)
	
	node.feeder_track.curve = test_f_curve
	var f_len = test_f_curve.get_baked_length()
	node.feeder_stop_pos = f_len - 140.0
	
	# Re-position feeder rows according to new curve
	for j in range(node._feeder_rows.size()):
		var f_row = node._feeder_rows[j]
		var prog = (f_len - 140.0) - float(j) * node.ROW_SPACING
		f_row.progress = prog
		var f_pt_info = node._get_curve_point_and_normal(test_f_curve, prog, false)
		for p in f_row.passengers:
			if is_instance_valid(p.get("view")):
				p["view"].position = node._calc_lane_pos(f_pt_info["pos"], f_pt_info["normal"], p["lane"])
				
	print("Testing with new feeder curve across 120 frames:")
	var total_overlaps = 0
	for frame in range(120):
		await process_frame
		for cr in node._circulating_rows:
			for cp in cr.passengers:
				if not is_instance_valid(cp.get("view")): continue
				var c_pos = cp["view"].position
				for fr in node._feeder_rows:
					for fp in fr.passengers:
						if not is_instance_valid(fp.get("view")): continue
						var f_pos = fp["view"].position
						var d = c_pos.distance_to(f_pos)
						if d < 32.0:
							total_overlaps += 1
							print("Frame %d OVERLAP: dist = %.1f px" % [frame, d])
							
	print("Simulation complete. Total overlaps detected: %d" % total_overlaps)
	quit()
