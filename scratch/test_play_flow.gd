extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Instantiating main.tscn...")
	var scn = load("res://scenes/main.tscn")
	var inst = scn.instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame
	print("Pressing play button...")
	inst._on_play_pressed()
	await process_frame
	await process_frame
	var gc = root.get_node_or_null("GameController")
	if gc:
		print("Current scene after play press: ", gc.current_scene_path())
	for i in range(60):
		await process_frame
	print("Successfully ran 60 frames of gameplay!")
	quit(0)
