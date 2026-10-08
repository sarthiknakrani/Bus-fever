extends SceneTree
func _init():
    var style = StyleBoxFlat.new()
    style.bg_color = Color("22c55e")
    style.border_width_left = 6
    style.border_width_top = 6
    style.border_width_right = 6
    style.border_width_bottom = 6
    style.border_color = Color.WHITE
    style.corner_radius_top_left = 32
    style.corner_radius_top_right = 32
    style.corner_radius_bottom_left = 32
    style.corner_radius_bottom_right = 32
    style.shadow_color = Color("16a34a") # dark green
    style.shadow_size = 1
    style.shadow_offset = Vector2(0, 16)
    
    print("Style created.")
    quit()
