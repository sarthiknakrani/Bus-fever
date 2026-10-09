extends SceneTree
func _init():
    var main = load("res://scenes/level1.tscn").instantiate()
    root.add_child(main)
    call_deferred("snap", main)
func snap(main):
    var cam = main.camera_2d
    print("Camera pos: ", cam.global_position)
    print("Camera anchor mode: ", cam.anchor_mode)
    print("Screen size: ", get_root().get_visible_rect())
    quit()
