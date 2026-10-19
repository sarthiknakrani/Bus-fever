
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	var pc = node.passenger_track.curve
	var fc = node.feeder_track.curve
	var track_len = pc.get_baked_length()
	var f_len = fc.get_baked_length()
	var merge_prog = node._merge_prog
	
	print("Track len: ", track_len)
	print("Feeder len: ", f_len)
	print("Merge prog on track: ", merge_prog)
	
	# The Exit Gate is at bottom center: x = 0, y = 115
	var gate_prog = pc.get_closest_offset(Vector2(0, 115))
	print("Gate prog on track: ", gate_prog)
	quit()
