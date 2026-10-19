
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	var tr = node.passenger_track_bg.get_node("TrackRenderer")
	print("inner_meet_idx: ", tr.inner_meet_idx)
	print("inner_meet_pt: ", tr.inner_meet_pt)
	print("inner_meet_ang: ", tr.inner_meet_ang)
	print("outer_meet_idx: ", tr.outer_meet_idx)
	print("outer_meet_pt: ", tr.outer_meet_pt)
	print("outer_meet_ang: ", tr.outer_meet_ang)
	quit()
