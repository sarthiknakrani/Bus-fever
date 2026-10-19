extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TEST: Full Scene Transition Cycle ---")
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await process_frame
	print("Scene: ", current_scene.name)
	
	var gc = root.get_node("GameController")
	print("Starting Level 1...")
	gc.start_level(1)
	await process_frame
	await process_frame
	await process_frame
	print("Scene: ", current_scene.name)
	
	print("Simulating 60 frames in Level 1...")
	for i in range(60):
		await process_frame
		
	print("Going back to Home...")
	gc.goto_scene("res://scenes/main.tscn")
	await process_frame
	await process_frame
	await process_frame
	print("Scene: ", current_scene.name)
	
	print("Starting Level 2...")
	gc.start_level(2)
	await process_frame
	await process_frame
	await process_frame
	print("Scene: ", current_scene.name)
	
	print("Simulating 60 frames in Level 2...")
	for i in range(60):
		await process_frame
		
	print("Cycle completed successfully without crashes!")
	quit(0)
