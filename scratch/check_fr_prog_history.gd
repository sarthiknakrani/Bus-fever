
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	for f in range(65):
		await process_frame
		for fr in node._feeder_rows:
			for p in fr.passengers:
				if p["id"] == 179:
					if f in [0, 10, 30, 50, 60, 64]:
						print("Frame %d | prog = %.2f | pos = %s" % [f, fr.progress, p["view"].position])
	quit()
