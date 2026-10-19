extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	var root_ctrl = Control.new()
	root_ctrl.size = Vector2(390, 844)
	root.add_child(root_ctrl)
	
	# Proper Godot 4 way:
	var overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var scrim = ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(280, 250)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(wrapper)
	
	var panel = PanelContainer.new()
	wrapper.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	await process_frame
	await process_frame
	
	print("Root size: ", root_ctrl.size)
	print("Overlay size: ", overlay.size)
	print("Center size: ", center.size)
	print("Wrapper global pos: ", wrapper.global_position)
	print("Wrapper size: ", wrapper.size)
	print("Panel global pos: ", panel.global_position)
	print("Panel size: ", panel.size)
	print("Is wrapper inside 390x844 rect? ", Rect2(Vector2.ZERO, Vector2(390, 844)).encloses(Rect2(wrapper.global_position, wrapper.size)))
	
	quit()
