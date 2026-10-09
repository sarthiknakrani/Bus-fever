extends SceneTree
func _init():
    DisplayServer.window_set_size(Vector2i(1080, 1920))
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    call_deferred("snap")
func snap():
    await create_timer(1.5).timeout
    var img = get_root().get_texture().get_image()
    img.save_png("test_mac.png")
    print("Saved test_mac.png")
    quit()
