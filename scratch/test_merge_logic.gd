
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	var track_len = node.passenger_track.curve.get_baked_length()
	var fc = node.feeder_track.curve
	var f_len = fc.get_baked_length()
	var merge_prog = node._merge_prog
	
	print("Track len: ", track_len)
	print("Feeder len: ", f_len)
	print("Merge prog: ", merge_prog)
	print("feeder_stop_pos for 208: ", f_len - 208.0)
	quit()
