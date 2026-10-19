extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	var scn = load("res://scenes/main.tscn")
	var inst = scn.instantiate()
	root.add_child(inst)
	
	print("--- VIEWPORT STATS ---")
	var vp = inst.get_viewport()
	print("vp.size: ", vp.size)
	print("vp.get_visible_rect(): ", vp.get_visible_rect())
	print("vp.get_camera_2d(): ", vp.get_camera_2d())
	print("vp.canvas_transform: ", vp.canvas_transform)
	print("vp.global_canvas_transform: ", vp.global_canvas_transform)
	
	var home_root = inst.get_node("HomeRoot")
	print("HomeRoot pos: ", home_root.position, " size: ", home_root.size)
	
	inst._show_settings_overlay()
	var overlay = inst.get_node("SettingsOverlay")
	print("Overlay pos: ", overlay.position, " size: ", overlay.size)
	for c in overlay.get_children():
		print("  child: ", c.name, " pos: ", c.position, " size: ", c.size, " global_pos: ", (c as Control).global_position)
		if c is CenterContainer:
			for cc in c.get_children():
				print("    wrapper pos: ", cc.position, " size: ", cc.size, " global_pos: ", (cc as Control).global_position)
				for ccc in cc.get_children():
					print("      panel pos: ", ccc.position, " size: ", ccc.size, " global_pos: ", (ccc as Control).global_position)
	
	quit()
