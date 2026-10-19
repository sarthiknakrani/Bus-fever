
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	for f in range(70):
		await process_frame
		if f in [60, 64, 68, 72]:
			var c_pos = Vector2.ZERO
			var f_pos = Vector2.ZERO
			for cr in node._circulating_rows:
				for p in cr.passengers:
					if p["id"] == 48: c_pos = p["view"].position
			for fr in node._feeder_rows:
				for p in fr.passengers:
					if p["id"] == 179: f_pos = p["view"].position
			print("Frame %d | circ 48: %s | feed 179: %s | dist = %.1f" % [f, c_pos, f_pos, c_pos.distance_to(f_pos)])
	quit()
