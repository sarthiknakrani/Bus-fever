extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TEST TEXTURE BUTTON WITH parse_input_event ---")
	var root_ctrl = Control.new()
	root_ctrl.size = Vector2(390, 844)
	root.add_child(root_ctrl)

	var btn = TextureButton.new()
	btn.position = Vector2(100, 100)
	btn.size = Vector2(100, 50)
	btn.texture_normal = load("res://assets/ui/buttons/settings_gear_normal.svg")
	root_ctrl.add_child(btn)

	await process_frame
	await process_frame

	var pressed := false
	btn.pressed.connect(func():
		print("Btn clicked via parse_input_event!")
		pressed = true
	)

	var ev_down = InputEventMouseButton.new()
	ev_down.position = Vector2(120, 120)
	ev_down.global_position = Vector2(120, 120)
	ev_down.button_index = MOUSE_BUTTON_LEFT
	ev_down.pressed = true
	Input.parse_input_event(ev_down)

	await process_frame

	var ev_up = InputEventMouseButton.new()
	ev_up.position = Vector2(120, 120)
	ev_up.global_position = Vector2(120, 120)
	ev_up.button_index = MOUSE_BUTTON_LEFT
	ev_up.pressed = false
	Input.parse_input_event(ev_up)

	await process_frame

	print("Result with parse_input_event: pressed=", pressed)
	quit(0)
