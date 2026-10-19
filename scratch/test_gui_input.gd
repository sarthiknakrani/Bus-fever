extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TEST 1: HUD mouse_filter=IGNORE vs PASS ---")
	var scn = load("res://scenes/main.tscn")
	var inst = scn.instantiate()
	root.add_child(inst)
	await process_frame

	var play_btn: TextureButton = inst.get_node_or_null("HomeRoot/HUD/PlayButton")
	var hud: Control = inst.get_node_or_null("HomeRoot/HUD")
	var root_ctrl: Control = inst.get_node_or_null("HomeRoot")

	print("Initial: hud.mouse_filter = ", hud.mouse_filter)
	print("Initial: root_ctrl.mouse_filter = ", root_ctrl.mouse_filter)

	# In Godot, how does Viewport handle mouse button clicks?
	# In sub-viewports or root viewport without mouse movement, Viewport needs mouse motion or gui_input!
	var play_center = play_btn.get_global_rect().get_center()

	# Let's test direct gui_input
	var click_ev = InputEventMouseButton.new()
	click_ev.position = play_btn.size / 2.0
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true

	var received_gui_input := false
	play_btn.gui_input.connect(func(ev):
		print("play_btn received gui_input: ", ev)
		received_gui_input = true
	)

	play_btn.pressed.connect(func():
		print("play_btn PRESSED signal fired!")
	)

	print("Directly calling play_btn._gui_input...")
	play_btn.gui_input.emit(click_ev)

	# Now let's test sending mouse motion then click via Viewport
	print("Sending Viewport mouse motion + click...")
	var motion = InputEventMouseMotion.new()
	motion.position = play_center
	motion.global_position = play_center
	root.push_input(motion)
	await process_frame

	var hovered = root.gui_get_hovered_control()
	print("Hovered control at ", play_center, " is: ", hovered)

	# What if hud.mouse_filter = MOUSE_FILTER_PASS?
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	root.push_input(motion)
	await process_frame
	print("With hud=PASS, hovered control is: ", root.gui_get_hovered_control())

	# What if hud.mouse_filter = MOUSE_FILTER_IGNORE?
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.push_input(motion)
	await process_frame
	print("With hud=IGNORE, hovered control is: ", root.gui_get_hovered_control())

	quit(0)
