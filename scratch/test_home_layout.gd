extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scn = load("res://scenes/main.tscn")
	var inst = scn.instantiate()
	root.add_child(inst)
	root.get_viewport().size = Vector2i(390, 844)
	
	await process_frame
	await process_frame
	await process_frame

	var home_root: Control = inst.get_node("HomeRoot")
	var hud: Control = inst.get_node("HomeRoot/HUD")
	var s_btn: TextureButton = inst.get_node("HomeRoot/HUD/settings_btn")
	var p_btn: TextureButton = inst.get_node("HomeRoot/HUD/PlayButton")
	var logo: Control = inst.get_node("HomeRoot/HUD/TitleLogoWrapper")

	print("Viewport size: ", root.get_viewport().size)
	print("HomeRoot size: ", home_root.size, " mouse_filter: ", home_root.mouse_filter)
	print("HUD size: ", hud.size, " mouse_filter: ", hud.mouse_filter)
	print("Settings btn size: ", s_btn.size, " pos: ", s_btn.position, " mouse_filter: ", s_btn.mouse_filter)
	print("Play btn size: ", p_btn.size, " pos: ", p_btn.position, " mouse_filter: ", p_btn.mouse_filter)
	print("Logo size: ", logo.size, " pos: ", logo.position)

	# Verify settings button press
	print("Testing Settings button press...")
	s_btn.emit_signal("pressed")
	await process_frame
	var overlay = inst.get_node_or_null("SettingsOverlay")
	print("SettingsOverlay opened? ", overlay != null)
	if overlay:
		print("SettingsOverlay size: ", overlay.size)

	# Verify play button press
	print("Testing Play button press...")
	p_btn.emit_signal("pressed")
	await process_frame
	await process_frame
	var gc = root.get_node_or_null("GameController")
	if gc:
		print("Scene path after play: ", gc.current_scene_path())

	quit(0)
