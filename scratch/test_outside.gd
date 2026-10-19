extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TEST: CHILD OUTSIDE PARENT RECT ---")
	var parent_ctrl = Control.new()
	parent_ctrl.size = Vector2(300, 300)
	root.add_child(parent_ctrl)

	var btn = Button.new()
	btn.position = Vector2(50, 500) # OUTSIDE parent (300, 300)!
	btn.size = Vector2(100, 50)
	btn.text = "Click"
	parent_ctrl.add_child(btn)

	await process_frame
	await process_frame

	print("Parent rect: ", parent_ctrl.get_global_rect())
	print("Btn rect: ", btn.get_global_rect())

	# In Godot's Viewport hit test:
	# Viewport._gui_find_control(pos):
	# Does it check if parent.has_point(pos)?
	# Let's test with a simulated click at (75, 525)
	# In Godot 4, Viewport._gui_find_control_at_pos starts from root.
	# For each Control:
	# If clip_contents is false, does it recurse into children even if pos is outside parent?
	quit(0)
