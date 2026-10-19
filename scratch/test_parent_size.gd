extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TESTING PARENT CONTROL SIZE AND CLICKS ---")
	
	# Main Node
	var main = Node.new()
	root.add_child(main)

	# Parent Control with default size (0, 0)
	var parent_ctrl = Control.new()
	parent_ctrl.name = "ParentCtrl"
	# Not setting size!
	main.add_child(parent_ctrl)

	# Child Button at (100, 100) with size (100, 50)
	var btn = Button.new()
	btn.position = Vector2(100, 100)
	btn.size = Vector2(100, 50)
	btn.text = "Click Me"
	parent_ctrl.add_child(btn)

	await process_frame
	await process_frame

	print("Parent size: ", parent_ctrl.size, " rect: ", parent_ctrl.get_global_rect())
	print("Btn size: ", btn.size, " rect: ", btn.get_global_rect())

	# In Godot, does Control._has_point require parent to contain the point?
	# Or what does Viewport._gui_find_control do?
	# In Godot source code:
	# Viewport checks controls recursively.
	# But does a parent Control reject points if the point is outside parent rect?!
	# Let's test with Button.has_point and parent.has_point:
	var click_pt = Vector2(120, 120)
	print("Parent has_point(120, 120): ", parent_ctrl.has_point(parent_ctrl.to_local(click_pt)))
	print("Btn has_point(120, 120): ", btn.has_point(btn.to_local(click_pt)))

	quit(0)
