extends Node2D
class_name PlatformView

var p_top: float = -500.0
var p_bottom: float = 2000.0
var p_width: float = 2000.0
var p_partition_y: float = 0.0

func setup_full(top_y: float, bottom_y: float, w: float, partition_y: float) -> void:
    p_top = top_y
    p_bottom = bottom_y
    p_width = w
    p_partition_y = partition_y
    queue_redraw()

func _draw() -> void:
    var bg_color = Color("d1d5e6") # Lavender-grey
    
    # Large rectangle aligned to screen
    var rect = Rect2(-p_width/2.0, p_top, p_width, p_bottom - p_top)
    
    var surface = StyleBoxFlat.new()
    surface.bg_color = bg_color
    
    # Rounded top corners (behind parking or passengers)
    surface.corner_radius_top_left = 60
    surface.corner_radius_top_right = 60
    # Add a slight border at the very top for depth
    surface.border_width_top = 8
    surface.border_color = Color("ffffff", 0.6)
    
    draw_style_box(surface, rect)
    
    # ----------------------------------------------------
    # PARTITION / CURB BETWEEN PARKING AND BUSES
    # ----------------------------------------------------
    var gy = p_partition_y
    # Groove shadow
    draw_rect(Rect2(-p_width/2.0, gy, p_width, 6), Color("a5abc2"))
    # Groove deepest point
    draw_rect(Rect2(-p_width/2.0, gy + 6, p_width, 4), Color("959caf"))
    # Groove highlight (curb edge)
    draw_rect(Rect2(-p_width/2.0, gy + 10, p_width, 4), Color("ffffff", 0.8))
