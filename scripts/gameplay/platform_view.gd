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
	var curb_color = Color("ffffff", 0.8)
	var shadow_color = Color("a5abc2")
	var deep_color = Color("959caf")

	var hill_w = 540.0
	var slope_w = 80.0
	var gy = p_partition_y

	var points = PackedVector2Array([
		Vector2(-p_width/2.0, p_bottom),
		Vector2(-p_width/2.0, gy),
		Vector2(-hill_w/2.0 - slope_w, gy),
		Vector2(-hill_w/2.0, p_top),
		Vector2(hill_w/2.0, p_top),
		Vector2(hill_w/2.0 + slope_w, gy),
		Vector2(p_width/2.0, gy),
		Vector2(p_width/2.0, p_bottom)
	])

	# Fill the platform
	draw_colored_polygon(points, bg_color)
	
	# Draw the 3D curb along the top edge
	var top_edge = PackedVector2Array([
		Vector2(-p_width/2.0, gy),
		Vector2(-hill_w/2.0 - slope_w, gy),
		Vector2(-hill_w/2.0, p_top),
		Vector2(hill_w/2.0, p_top),
		Vector2(hill_w/2.0 + slope_w, gy),
		Vector2(p_width/2.0, gy)
	])
	
	# To draw a thick line, we draw polylines multiple times with offsets
	for offset_y in range(0, 10):
		var color = deep_color
		if offset_y < 2: color = curb_color
		elif offset_y < 6: color = shadow_color
		
		var offset_pts = PackedVector2Array()
		for pt in top_edge:
			offset_pts.append(pt + Vector2(0, offset_y))
			
		draw_polyline(offset_pts, color, 2.0, true)
		
	# Draw a straight partition line separating parking from the board
	# This creates that "shelf" look from the wireframe
	draw_rect(Rect2(-p_width/2.0, gy, p_width, 4), shadow_color)
	draw_rect(Rect2(-p_width/2.0, gy + 4, p_width, 2), deep_color)

