extends SceneTree
func _init():
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    call_deferred("do_click", main)
func do_click(main):
    var btn = main.get_node("HomeRoot/SafeArea/Control/Button") # No, it's added to hud. We have to find it.
    # Find settings button
    for c in main.get_children():
        pass
