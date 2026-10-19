extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Testing button click propagation...")
	var scn = load("res://scenes/main.tscn")
	var inst = scn.instantiate()
	root.add_child(inst)
	
	for f in 5:
		await process_frame

	var play_btn: TextureButton = inst.get_node("HomeRoot/HUD/PlayButton")
	var settings_btn: TextureButton = inst.get_node("HomeRoot/HUD/settings_btn")

	var play_pressed := false
	play_btn.pressed.connect(func():
		print("Play pressed!")
		play_pressed = true
	)

	var settings_pressed := false
	settings_btn.pressed.connect(func():
		print("Settings pressed!")
		settings_pressed = true
	)

	print("Play button global rect: ", play_btn.get_global_rect())
	print("Settings button global rect: ", settings_btn.get_global_rect())

	# In Godot, sending input to Viewport:
	# If we use SubViewport or test with Window:
	# Let's check how TextureButton responds to InputEventScreenTouch / InputEventMouseButton
	var touch = InputEventScreenTouch.new()
	touch.position = play_btn.get_global_rect().get_center()
	touch.pressed = true
	root.get_viewport().push_input(touch)
	await process_frame
	
	touch.pressed = false
	root.get_viewport().push_input(touch)
	await process_frame

	print("Touch test on play: play_pressed=", play_pressed)

	quit(0)
