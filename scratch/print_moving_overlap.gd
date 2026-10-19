
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	for fr in node._feeder_rows:
		for p in fr.passengers:
			if p["id"] == 179:
				print("feed 179: progress = ", fr.progress, " lane = ", p["lane"], " pos = ", p["view"].position)
	for cr in node._circulating_rows:
		for p in cr.passengers:
			if p["id"] in [48, 52, 56]:
				print("circ %d: progress = %f lane = %d pos = %s" % [p["id"], cr.progress, p["lane"], p["view"].position])
	quit()
