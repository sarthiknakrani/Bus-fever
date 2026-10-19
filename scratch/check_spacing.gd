
extends SceneTree

func _init():
	var gc = root.get_node_or_null("GameController")
	if gc != null: gc.current_level_number = 1
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await create_timer(0.2).timeout
	var img = get_root().get_texture().get_image()
	if img != null:
		img.save_png("scratch/current_passenger_spacing.png")
		print("SAVED scratch/current_passenger_spacing.png")
	quit()
