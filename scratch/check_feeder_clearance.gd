
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	var fc = node.feeder_track.curve
	var pc = node.passenger_track.curve
	var f_len = fc.get_baked_length()
	var road_w = 53.0 # half width
	
	# Check distance from each point on feeder centerline to passenger track centerline
	for dist_from_end in range(0, 120, 5):
		var s = f_len - dist_from_end
		var f_pt = fc.sample_baked(s)
		var p_offset = pc.get_closest_offset(f_pt)
		var p_pt = pc.sample_baked(p_offset)
		var dist_to_track_center = f_pt.distance_to(p_pt)
		print("dist_from_end: %3d | f_pos: %s | dist_to_center: %5.1f | in_oval: %s" % [
			dist_from_end, f_pt, dist_to_track_center, dist_to_track_center < (road_w * 2.0)
		])
	quit()
