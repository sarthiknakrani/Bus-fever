
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	var pc = node.passenger_track.curve
	var tr = node.passenger_track_bg.get_node("TrackRenderer")
	var p_inner = pc.get_closest_offset(tr.inner_meet_pt)
	var p_merge = node._merge_prog
	print("inner_meet_pt loop prog: ", p_inner)
	print("merge_prog: ", p_merge)
	var d = p_merge - p_inner
	if d < 0: d += pc.get_baked_length()
	print("Distance along loop from inner_meet to merge_prog: ", d)
	quit()
