extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_viewport().size = Vector2i(810, 1746)
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	
	await process_frame
	await process_frame
	
	print("Pressing settings button...")
	var s_btn: TextureButton = main.get_node("HomeRoot/HUD/settings_btn")
	s_btn.emit_signal("pressed")
	
	await process_frame
	await process_frame
	
	var overlay = main.get_node_or_null("SettingsOverlay")
	print("Overlay found: ", overlay != null)
	if overlay:
		_dump_tree(overlay, 0)
	
	var img = root.get_viewport().get_texture().get_image()
	img.save_png("scratch/settings_inspect.png")
	print("Saved scratch/settings_inspect.png")
	
	quit()

func _dump_tree(node: Node, depth: int):
	var indent = "  ".repeat(depth)
	var ctrl = node as Control
	if ctrl:
		print("%s%s (%s): global_pos=%s, size=%s, min_size=%s, visible=%s, z_index=%s, mouse_filter=%s, modulate=%s" % [
			indent, ctrl.name, ctrl.get_class(), ctrl.global_position, ctrl.size, ctrl.custom_minimum_size, ctrl.visible, ctrl.z_index, ctrl.mouse_filter, ctrl.modulate
		])
	else:
		print("%s%s (%s)" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_dump_tree(child, depth + 1)
