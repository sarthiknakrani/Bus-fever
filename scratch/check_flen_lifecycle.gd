
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	# Before add_child
	print("feeder_track before add_child: ", node.feeder_track)
	root.add_child(node)
	print("feeder_track length immediately after add_child: ", node.feeder_track.curve.get_baked_length())
	quit()
