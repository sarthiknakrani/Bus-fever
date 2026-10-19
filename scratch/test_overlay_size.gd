extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scn = load("res://scenes/main.tscn")
	var inst = scn.instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame

	print("Calling _show_settings_overlay()...")
	inst._show_settings_overlay()
	await process_frame

	var overlay: Control = inst.get_node_or_null("@Control@2") # or find by type
	for c in inst.get_children():
		if c != inst.get_node("HomeRoot"):
			overlay = c
			break

	print("Overlay found: ", overlay)
	if overlay:
		print("Overlay size: ", overlay.size)
		print("Overlay rect: ", overlay.get_global_rect())
		print("Overlay visible: ", overlay.is_visible_in_tree())
		for child in overlay.get_children():
			print("  Child: ", child.name, " (", child.get_class(), ") rect=", child.get_global_rect() if child is Control else "")

	quit(0)
