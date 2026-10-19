
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	var tr = node.passenger_track_bg.get_node("TrackRenderer")
	var fc = node.feeder_track.curve
	var f_len = fc.get_baked_length()
	print("inner_meet_pt: ", tr.inner_meet_pt, " outer_meet_pt: ", tr.outer_meet_pt)
	for d in [180.0, 195.0, 208.0, 215.0]:
		var pt = fc.sample_baked(f_len - d)
		print("d = %.1f: pt = %s" % [d, pt])
	quit()
