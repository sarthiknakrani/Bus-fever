extends Node2D
class_name PlatformView

var p_top: float = -500.0
var p_bottom: float = 2000.0
var p_width: float = 2000.0
var p_partition_y: float = 0.0
var p_separator_y: float = -9999.0
var p_deck_w: float = 580.0

func setup_full(top_y: float, bottom_y: float, w: float, partition_y: float, separator_y: float = -9999.0, deck_w: float = 580.0) -> void:
	p_top = top_y
	p_bottom = bottom_y
	p_width = w
	p_partition_y = partition_y
	p_separator_y = separator_y
	p_deck_w = deck_w
	queue_redraw()

func _draw() -> void:
	# 1. Authoritative base grey material matching passenger road (#767786)
	var base_grey := Color("767786")
	var curb_highlight := Color("f8fafc")
	var curb_shadow := Color("a5abc2")
	var curb_deep := Color("545564")

	var hill_w: float = p_deck_w
	var slope_w: float = 75.0
	var gy: float = p_partition_y
	var hw: float = p_width / 2.0
	var sep_y: float = p_separator_y

	# 2. Continuous grey polygon (raised platform deck, sloped sides, and full-width floor)
	var points = PackedVector2Array([
		Vector2(-hw, p_bottom),
		Vector2(-hw, gy),
		Vector2(-hill_w / 2.0 - slope_w, gy),
		Vector2(-hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0 + slope_w, gy),
		Vector2(hw, gy),
		Vector2(hw, p_bottom)
	])
	draw_colored_polygon(points, base_grey)

	# 4. Clean 3D curb outlining the platform perimeter and connecting seamlessly with the horizon floor
	var top_edge = PackedVector2Array([
		Vector2(-hw, gy),
		Vector2(-hill_w / 2.0 - slope_w, gy),
		Vector2(-hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0 + slope_w, gy),
		Vector2(hw, gy)
	])

	# Draw 3D curb bevel along the entire continuous perimeter
	draw_polyline(top_edge, curb_shadow, 4.0, true)
	draw_polyline(top_edge, curb_deep, 2.5, true)
	draw_polyline(top_edge, curb_highlight, 1.5, true)

	# 5. Authoritative Road Divider / Separator line (exact vertical center on sep_y)
	if sep_y > -9000.0:
		draw_rect(Rect2(-hw, sep_y - 3.25, p_width, 2.5), curb_shadow)
		draw_rect(Rect2(-hw, sep_y - 0.75, p_width, 2.0), curb_deep)
		draw_rect(Rect2(-hw, sep_y + 1.25, p_width, 2.0), curb_highlight)
