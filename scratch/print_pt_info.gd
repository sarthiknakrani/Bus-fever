
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	var fc = node.feeder_track.curve
	print("f_len: ", fc.get_baked_length())
	print("sample at 469.80: ", fc.sample_baked(469.80))
	var pt_info = node._get_curve_point_and_normal(fc, 469.80, false)
	print("pt_info at 469.80: ", pt_info["pos"])
	for lane in 4:
		print("lane %d: %s" % [lane, node._calc_lane_pos(pt_info["pos"], pt_info["normal"], lane)])
	quit()
