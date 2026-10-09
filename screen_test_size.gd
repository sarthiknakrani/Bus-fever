extends SceneTree
func _init():
    # Use standard modern mobile portrait aspect (e.g. 1080x2400)
    DisplayServer.window_set_size(Vector2i(1080, 2400))
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    call_deferred("snap")
func snap():
    await create_timer(1.0).timeout
    quit()
