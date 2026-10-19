extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TESTING MOUSE_FILTER_IGNORE ON PARENT ---")
	
	var parent_stop = Control.new()
	parent_stop.name = "HomeRoot"
	parent_stop.size = Vector2(400, 400)
	parent_stop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(parent_stop)

	var child_ignore = Control.new()
	child_ignore.name = "HUD"
	child_ignore.size = Vector2(400, 400)
	child_ignore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_stop.add_child(child_ignore)

	var btn = TextureButton.new()
	btn.name = "PlayButton"
	btn.position = Vector2(100, 100)
	btn.size = Vector2(100, 50)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	child_ignore.add_child(btn)

	await process_frame
	await process_frame

	var hit_c = _find_control_at(parent_stop, Vector2(120, 120))
	print("Control at (120, 120): ", hit_c.get_name() if hit_c else "null")

	quit(0)

func _find_control_at(c: Control, pt: Vector2) -> Control:
	if not c.is_visible_in_tree():
		return null
	if not c.get_global_rect().has_point(pt):
		return null
	for i in range(c.get_child_count() - 1, -1, -1):
		var child = c.get_child(i)
		if child is Control:
			var res = _find_control_at(child, pt)
			if res != null:
				return res
	if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return c
	return null
