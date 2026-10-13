extends Node2D
class_name ParkingStripView

# Visual palette matching track_renderer.gd
const COLOR_ROAD := Color("767786") # Muted slate grey (#767786)
const COLOR_CURB_HIGHLIGHT := Color("f8fafc") # Near-white crisp highlight
const COLOR_CURB_BEVEL := Color("a5abc2") # Cool slate bevel shadow
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.12) # Soft contact shadow

var strip_top_y: float = 0.0
var strip_bottom_y: float = 0.0
var strip_width: float = 0.0
var is_active: bool = false

func draw_parking_strip(top_y: float, bottom_y: float, w: float) -> void:
	strip_top_y = minf(top_y, bottom_y)
	strip_bottom_y = maxf(top_y, bottom_y)
	strip_width = maxf(0.0, w)
	is_active = (strip_width > 0.0 and strip_bottom_y > strip_top_y)
	queue_redraw()

func setup(top_y: float, bottom_y: float, w: float) -> void:
	draw_parking_strip(top_y, bottom_y, w)

func _draw() -> void:
	if not is_active:
		return

	var w: float = strip_width
	var hw: float = w / 2.0
	var top_y: float = strip_top_y
	var btm_y: float = strip_bottom_y
	var h: float = btm_y - top_y
	if h <= 0.0 or w <= 0.0:
		return

	var r: float = minf(6.0, h / 2.0)

	# 1. Soft drop shadow below the strip on the lavender playfield
	var shadow_rect := Rect2(-hw, top_y + 2.0, w, h + 2.0)
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = COLOR_SHADOW
	shadow_style.set_corner_radius_all(int(r))
	draw_style_box(shadow_style, shadow_rect)

	# 2. Main grey road surface with rounded corners
	var road_rect := Rect2(-hw, top_y, w, h)
	var road_style := StyleBoxFlat.new()
	road_style.bg_color = COLOR_ROAD
	road_style.set_corner_radius_all(int(r))
	draw_style_box(road_style, road_rect)

	# 3. Top curb treatment (matching track_renderer.gd)
	var top_curb := PackedVector2Array()
	var arc_steps: int = 5
	for i in range(arc_steps):
		var ang = PI + (float(i) / float(arc_steps - 1)) * (PI * 0.5)
		top_curb.append(Vector2(-hw + r + cos(ang) * r, top_y + r + sin(ang) * r))
	for i in range(arc_steps):
		var ang = 1.5 * PI + (float(i) / float(arc_steps - 1)) * (PI * 0.5)
		top_curb.append(Vector2(hw - r + cos(ang) * r, top_y + r + sin(ang) * r))

	draw_polyline(top_curb, COLOR_CURB_BEVEL, 3.5, true)
	draw_polyline(top_curb, COLOR_CURB_HIGHLIGHT, 2.0, true)

	# 4. Bottom curb treatment (mirror)
	var btm_curb := PackedVector2Array()
	for i in range(arc_steps):
		var ang = PI - (float(i) / float(arc_steps - 1)) * (PI * 0.5)
		btm_curb.append(Vector2(-hw + r + cos(ang) * r, btm_y - r + sin(ang) * r))
	for i in range(arc_steps):
		var ang = 0.5 * PI - (float(i) / float(arc_steps - 1)) * (PI * 0.5)
		btm_curb.append(Vector2(hw - r + cos(ang) * r, btm_y - r + sin(ang) * r))

	# Contact shadow directly under bottom curb
	var btm_shadow := PackedVector2Array()
	for pt in btm_curb:
		btm_shadow.append(pt + Vector2(0.0, 2.0))
	draw_polyline(btm_shadow, COLOR_SHADOW, 4.0, true)

	draw_polyline(btm_curb, COLOR_CURB_BEVEL, 3.5, true)
	draw_polyline(btm_curb, COLOR_CURB_HIGHLIGHT, 2.0, true)

	# 5. Side edges bevel to cleanly close corners
	if btm_y - r > top_y + r:
		draw_line(Vector2(-hw, top_y + r), Vector2(-hw, btm_y - r), COLOR_CURB_BEVEL, 2.0)
		draw_line(Vector2(hw, top_y + r), Vector2(hw, btm_y - r), COLOR_CURB_BEVEL, 2.0)
