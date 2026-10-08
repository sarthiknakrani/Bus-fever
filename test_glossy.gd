extends SceneTree
func _init():
    var style = StyleBoxFlat.new()
    style.border_width_top = 10
    style.border_color = Color(1, 1, 1, 0.5)
    style.border_blend = true
    print("Supports border_blend: ", style.border_blend)
    quit()
