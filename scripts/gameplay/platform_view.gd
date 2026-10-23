extends Node2D
class_name PlatformView

var p_top: float = -500.0
var p_bottom: float = 2000.0
var p_width: float = 2000.0
var p_partition_y: float = 0.0
var p_separator_y: float = -9999.0
var p_deck_w: float = 580.0
var p_visible_w: float = 0.0

var p_track_bottom_y: float = -9999.0
var p_parking_y: float = -9999.0
var p_parking_h: float = 94.0
var p_straight_x: float = 105.0

const GATEWAY_HALF_WIDTH: float = 67.5 # 1.5X width matching track_renderer gateway

# Authoritative source-of-truth track grey matching passenger track & connector
const COLOR_TRACK_GREY := Color("727382")
const COLOR_ROAD := Color("727382")
const COLOR_CURB_FACE := Color("4b4d5a") # Vertical 3D curb wall face
const COLOR_CURB_HIGHLIGHT := Color("ffffff")
const COLOR_CURB_BEVEL := Color("a5abc2")
const COLOR_CURB_BEVEL_OUTER := Color("868ba0")
const COLOR_SHADOW := Color(0.04, 0.10, 0.04, 0.22)
const COLOR_PLAYFIELD := Color("d2d5e4") # Swatch 1 light lavender playfield

func setup_full(
	top_y: float,
	bottom_y: float,
	w: float,
	partition_y: float,
	separator_y: float = -9999.0,
	deck_w: float = 580.0,
	visible_w: float = 0.0,
	track_bottom_y: float = -9999.0,
	parking_y: float = -9999.0,
	parking_h: float = 94.0
) -> void:
	p_top = top_y
	p_bottom = bottom_y
	p_width = w
	p_partition_y = partition_y
	p_separator_y = separator_y
	p_deck_w = deck_w
	p_visible_w = visible_w if visible_w > 0.0 else (w - 200.0 if w > 200.0 else w)
	p_track_bottom_y = track_bottom_y
	p_parking_y = parking_y
	p_parking_h = parking_h
	queue_redraw()

func setup_station(
	track_bottom_y: float,
	parking_y: float,
	parking_h: float,
	separator_y: float,
	viewport_w: float,
	bottom_y: float,
	partition_y: float = 0.0,
	straight_x: float = 155.0
) -> void:
	p_track_bottom_y = track_bottom_y
	p_parking_y = parking_y
	p_parking_h = parking_h
	p_separator_y = separator_y
	p_partition_y = partition_y
	p_visible_w = viewport_w
	p_width = viewport_w + 200.0
	p_bottom = bottom_y
	p_top = track_bottom_y
	p_straight_x = straight_x
	queue_redraw()

func get_original_band_height() -> float:
	if p_separator_y > -9000.0:
		return maxf(0.0, p_separator_y - p_partition_y)
	return 0.0

func get_band_bottom_y() -> float:
	if p_separator_y > -9000.0:
		return maxf(p_separator_y, p_partition_y)
	return p_partition_y

func get_current_band_height() -> float:
	return get_band_bottom_y() - p_partition_y

func _draw() -> void:
	var color_track_grey := COLOR_ROAD
	var color_playfield := COLOR_PLAYFIELD
	var curb_highlight := COLOR_CURB_HIGHLIGHT
	var curb_bevel := COLOR_CURB_BEVEL
	var curb_bevel_outer := COLOR_CURB_BEVEL_OUTER
	var color_shadow := COLOR_SHADOW

	var plat_btm: float = get_band_bottom_y()
	var hw: float = (p_visible_w / 2.0) if p_visible_w > 0.0 else (p_width / 2.0)
	var fill_hw: float = hw + 10.0 # slight extra margin to guarantee full edge coverage

	# 1. Lower bus-playfield polygon in Swatch 1 light lavender (#D2D5E4) below divider
	if p_bottom > plat_btm:
		var playfield_poly := PackedVector2Array([
			Vector2(-fill_hw, plat_btm),
			Vector2(fill_hw, plat_btm),
			Vector2(fill_hw, p_bottom),
			Vector2(-fill_hw, p_bottom)
		])
		draw_colored_polygon(playfield_poly, color_playfield)

	# 2. Flared Trapezoidal Parking Platform with flat top edge and rounded shoulder corners
	var top_connect_y: float = p_track_bottom_y if p_track_bottom_y > -9000.0 else p_top
	var top_y: float = top_connect_y

	var gate_hw: float = GATEWAY_HALF_WIDTH # 95.0
	var top_shoulder_x: float = hw * 0.76
	var shoulder_bottom_y: float = (p_parking_y + (p_parking_h * 0.35)) if p_parking_y > -9000.0 else (top_y + (plat_btm - top_y) * 0.5)
	shoulder_bottom_y = clampf(shoulder_bottom_y, top_y + 15.0, plat_btm - 10.0)

	var segs: int = 8
	# Right shoulder corner arc (corner_radius = 24.0, 8 segments)
	# Connects flat top edge at (top_shoulder_x - 12.0, top_y) to straight diagonal wall at (top_shoulder_x, top_y + 12.0)
	var p0_r := Vector2(top_shoulder_x - 12.0, top_y)
	var p1_r := Vector2(top_shoulder_x, top_y)
	var p2_r := Vector2(top_shoulder_x, top_y + 12.0)
	var right_corner := PackedVector2Array()
	for i in range(1, segs + 1):
		var t: float = float(i) / float(segs)
		var omt: float = 1.0 - t
		right_corner.append(omt * omt * p0_r + 2.0 * omt * t * p1_r + t * t * p2_r)

	# Left shoulder corner arc
	var p0_l := Vector2(-top_shoulder_x + 12.0, top_y)
	var p1_l := Vector2(-top_shoulder_x, top_y)
	var p2_l := Vector2(-top_shoulder_x, top_y + 12.0)
	var left_corner := PackedVector2Array()
	for i in range(1, segs + 1):
		var t: float = float(i) / float(segs)
		var omt: float = 1.0 - t
		left_corner.append(omt * omt * p0_l + 2.0 * omt * t * p1_l + t * t * p2_l)

	# Build station polygon (seamlessly welded into gateway throat)
	var station_poly := PackedVector2Array()
	station_poly.append(Vector2(-gate_hw, top_y - 25.0))
	station_poly.append(Vector2(gate_hw, top_y - 25.0))
	station_poly.append(Vector2(gate_hw, top_y))
	station_poly.append(Vector2(top_shoulder_x - 12.0, top_y))
	for pt in right_corner:
		station_poly.append(pt)
	station_poly.append(Vector2(fill_hw, shoulder_bottom_y))
	station_poly.append(Vector2(fill_hw, plat_btm))
	station_poly.append(Vector2(-fill_hw, plat_btm))
	station_poly.append(Vector2(-fill_hw, shoulder_bottom_y))
	for i in range(left_corner.size() - 1, -1, -1):
		station_poly.append(left_corner[i])
	station_poly.append(Vector2(-top_shoulder_x + 12.0, top_y))
	station_poly.append(Vector2(-gate_hw, top_y))

	draw_colored_polygon(station_poly, color_track_grey)

	# 3. Bottom divider curb along plat_btm (separator_y)
	var btm_left := Vector2(-fill_hw, plat_btm)
	var btm_right := Vector2(fill_hw, plat_btm)

	# Deep 2.5D drop shadow onto lower lavender playfield (6–8 px height)
	draw_line(btm_left + Vector2(0.0, 4.0), btm_right + Vector2(0.0, 4.0), color_shadow, 8.0)
	# 3D step face
	draw_line(btm_left + Vector2(0.0, 2.0), btm_right + Vector2(0.0, 2.0), COLOR_CURB_FACE, 5.5)
	# Curb bevel & crisp highlight
	draw_line(btm_left, btm_right, curb_bevel, 5.0)
	draw_line(btm_left, btm_right, curb_highlight, 3.2)

	# 4. 3D outer curbs along flat top edges, rounded corners, and diagonal side walls
	var right_curb := PackedVector2Array()
	right_curb.append(Vector2(gate_hw, top_y))
	right_curb.append(Vector2(top_shoulder_x - 12.0, top_y))
	for pt in right_corner:
		right_curb.append(pt)
	right_curb.append(Vector2(fill_hw, shoulder_bottom_y))

	var left_curb := PackedVector2Array()
	left_curb.append(Vector2(-gate_hw, top_y))
	left_curb.append(Vector2(-top_shoulder_x + 12.0, top_y))
	for pt in left_corner:
		left_curb.append(pt)
	left_curb.append(Vector2(-fill_hw, shoulder_bottom_y))

	# Drop shadows onto surrounding lawn
	var shadow_dy := Vector2(0.0, 5.0)
	var s_right := PackedVector2Array()
	for pt in right_curb: s_right.append(pt + shadow_dy)
	var s_left := PackedVector2Array()
	for pt in left_curb: s_left.append(pt + shadow_dy)
	draw_polyline(s_right, color_shadow, 9.0, true)
	draw_polyline(s_left, color_shadow, 9.0, true)

	# 3D Raised curb wall faces (extruded downwards by 3.5px)
	var wall_dy := Vector2(0.0, 3.5)
	var w_right := PackedVector2Array()
	for pt in right_curb: w_right.append(pt + wall_dy)
	var w_left := PackedVector2Array()
	for pt in left_curb: w_left.append(pt + wall_dy)
	draw_polyline(w_right, COLOR_CURB_FACE, 7.5, true)
	draw_polyline(w_left, COLOR_CURB_FACE, 7.5, true)

	# PROMINENT THICK 3D WHITE & BEVEL CURBS (4.2px white rim, 6.5px bevel)
	draw_polyline(right_curb, curb_bevel, 6.5, true)
	draw_polyline(right_curb, curb_highlight, 4.2, true)

	draw_polyline(left_curb, curb_bevel, 6.5, true)
	draw_polyline(left_curb, curb_highlight, 4.2, true)

func draw_parking_strip(_top_y: float, _bottom_y: float, _w: float) -> void:
	pass
