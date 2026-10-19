extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	var root_ctrl = Control.new()
	root_ctrl.size = Vector2(390, 844)
	root.add_child(root_ctrl)
	
	# What happens with PRESET_FULL_RECT?
	var overlay = Control.new()
	overlay.size = Vector2(390, 844)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(overlay)
	
	var center = CenterContainer.new()
	center.size = Vector2(390, 844)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(280, 250)
	center.add_child(wrapper)
	
	await process_frame
	await process_frame
	
	print("Root size: ", root_ctrl.size)
	print("Overlay size: ", overlay.size)
	print("Center size: ", center.size)
	print("Wrapper global pos: ", wrapper.global_position)
	print("Is wrapper inside 390x844 rect? ", Rect2(Vector2.ZERO, Vector2(390, 844)).encloses(Rect2(wrapper.global_position, wrapper.size)))
	
	quit()
