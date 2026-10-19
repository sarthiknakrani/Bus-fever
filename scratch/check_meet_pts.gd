
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	var tr = node.passenger_track_bg.get_node("TrackRenderer")
	print("inner_meet_idx: ", tr.inner_meet_idx, " pt: ", tr.inner_meet_pt, " ang: ", tr.inner_meet_ang)
	print("outer_meet_idx: ", tr.outer_meet_idx, " pt: ", tr.outer_meet_pt, " ang: ", tr.outer_meet_ang)
	quit()
