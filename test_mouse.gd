extends SceneTree
func _init():
    var tr = TextureRect.new()
    print("TextureRect filter: ", tr.mouse_filter)
    var cr = ColorRect.new()
    print("ColorRect filter: ", cr.mouse_filter)
    quit()
