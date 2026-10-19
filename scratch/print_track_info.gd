
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	print("Track len: ", node.passenger_track.curve.get_baked_length())
	print("_merge_prog: ", node._merge_prog)
	print("Platform start: ", node._platform_start_prog)
	print("Platform end: ", node._platform_end_prog)
	quit()
