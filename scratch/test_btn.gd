extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ctrl = Control.new()
	ctrl.size = Vector2(500, 500)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ctrl)

	var btn = Button.new()
	btn.position = Vector2(50, 50)
	btn.size = Vector2(100, 50)
	btn.text = "TEST"
	ctrl.add_child(btn)

	var clicked := false
	btn.pressed.connect(func():
		print("Button pressed!")
		clicked = true
	)

	# Simulate button press
	btn.emit_signal("pressed")
	print("Direct emit clicked? ", clicked)

	quit(0)
