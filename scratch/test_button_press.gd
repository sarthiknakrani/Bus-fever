extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scn = load("res://scenes/main.tscn")
	var inst = scn.instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame

	var play_btn: TextureButton = inst.get_node_or_null("HomeRoot/HUD/PlayButton")
	var settings_btn: TextureButton = inst.get_node_or_null("HomeRoot/HUD/settings_btn")

	print("play_btn rect: ", play_btn.get_global_rect())
	print("play_btn mouse_filter: ", play_btn.mouse_filter)
	print("play_btn disabled: ", play_btn.disabled)
	print("play_btn focus_mode: ", play_btn.focus_mode)
	print("play_btn visible: ", play_btn.visible)
	print("play_btn tree visible: ", play_btn.is_visible_in_tree())

	# Connect pressed
	var p_pressed = false
	play_btn.pressed.connect(func():
		print("PRESSED EVENT CAUGHT!")
		p_pressed = true
	)

	# Let's send an InputEventMouseButton directly to play_btn._gui_input
	var ev1 = InputEventMouseButton.new()
	ev1.button_index = MOUSE_BUTTON_LEFT
	ev1.pressed = true
	ev1.position = play_btn.size / 2.0
	play_btn._gui_input(ev1)

	var ev2 = InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = false
	ev2.position = play_btn.size / 2.0
	play_btn._gui_input(ev2)

	print("After direct _gui_input, pressed fired? ", p_pressed)

	quit(0)
