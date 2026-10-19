
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	DisplayServer.window_set_size(Vector2i(720, 1280))
	get_root().size = Vector2i(720, 1280)
	await process_frame
	await process_frame
	var img = get_root().get_texture().get_image()
	img.save_png("scratch/current_passenger_spacing.png")
	print("Saved scratch/current_passenger_spacing.png")
	quit()
