extends SceneTree
func _init():
    DisplayServer.window_set_size(Vector2i(1080, 2400))
    var main = load("res://scenes/level1.tscn")
    change_scene_to_packed(main)
    call_deferred("snap")
func snap():
    await create_timer(1.0).timeout
    var img = get_root().get_texture().get_image()
    img.save_png("test_mac.png")
    print("Saved test_mac.png")
    quit()
