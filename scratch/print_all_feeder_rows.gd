
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	for j in range(node._feeder_rows.size()):
		var fr = node._feeder_rows[j]
		var ids = []
		for p in fr.passengers: ids.append(p["id"])
		print("feeder row %d: prog = %.2f, ids = %s" % [j, fr.progress, ids])
	quit()
