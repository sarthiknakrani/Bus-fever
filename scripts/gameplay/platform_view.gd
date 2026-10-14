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
var p_straight_x: float = 155.0

# Authoritative source-of-truth track grey matching passenger track & connector
const COLOR_TRACK_GREY := Color("767786")
const COLOR_ROAD := Color("767786")
const COLOR_CURB_HIGHLIGHT := Color("f8fafc")
const COLOR_CURB_BEVEL := Color("a5abc2")
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.12)
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
	var orig_h := get_original_band_height()
	if orig_h > 0.0:
		# 200% height: final height = 2.0 * original_height, extending downward only
		return p_partition_y + (orig_h * 2.0)
	elif p_separator_y > -9000.0:
		return maxf(p_separator_y, p_partition_y)
	return p_partition_y

func get_current_band_height() -> float:
	return get_band_bottom_y() - p_partition_y

func _draw() -> void:
	var color_track_grey := COLOR_ROAD
	var color_playfield := COLOR_PLAYFIELD
	var curb_highlight := COLOR_CURB_HIGHLIGHT
	var curb_bevel := COLOR_CURB_BEVEL
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

	# 2. Unified station road platform (#767786)
	var top_connect_y: float = p_track_bottom_y if p_track_bottom_y > -9000.0 else p_top
	# 1px overlap upwards to eliminate any subpixel raster gap with TrackRenderer
	var top_y: float = top_connect_y - 1.0

	var straight_x: float = p_straight_x # 155.0
	var shoulder_bottom_y: float = (p_parking_y + (p_parking_h * 0.25)) if p_parking_y > -9000.0 else (top_y + (plat_btm - top_y) * 0.5)

	# Ensure shoulder_bottom_y is strictly between top_y and plat_btm
	shoulder_bottom_y = clampf(shoulder_bottom_y, top_y + 10.0, plat_btm - 10.0)

	var segments: int = 16

	# Quadratic Bezier for right shoulder: P0=(straight_x, top_y), P1=(hw, top_y), P2=(hw, shoulder_bottom_y)
	var p0_r := Vector2(straight_x, top_y)
	var p1_r := Vector2(hw, top_y)
	var p2_r := Vector2(hw, shoulder_bottom_y)
	var right_shoulder := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var omt: float = 1.0 - t
		right_shoulder.append(omt * omt * p0_r + 2.0 * omt * t * p1_r + t * t * p2_r)

	# Quadratic Bezier for left shoulder: P0=(-straight_x, top_y), P1=(-hw, top_y), P2=(-hw, shoulder_bottom_y)
	var p0_l := Vector2(-straight_x, top_y)
	var p1_l := Vector2(-hw, top_y)
	var p2_l := Vector2(-hw, shoulder_bottom_y)
	var left_shoulder := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var omt: float = 1.0 - t
		left_shoulder.append(omt * omt * p0_l + 2.0 * omt * t * p1_l + t * t * p2_l)

	# Build unified station polygon
	var station_poly := PackedVector2Array()
	station_poly.append(Vector2(-straight_x, top_y))
	station_poly.append(Vector2(straight_x, top_y))
	for i in range(1, segments + 1):
		station_poly.append(right_shoulder[i])
	station_poly.append(Vector2(fill_hw, shoulder_bottom_y))
	station_poly.append(Vector2(fill_hw, plat_btm))
	station_poly.append(Vector2(-fill_hw, plat_btm))
	station_poly.append(Vector2(-fill_hw, shoulder_bottom_y))
	for i in range(segments, 0, -1):
		station_poly.append(left_shoulder[i])

	draw_colored_polygon(station_poly, color_track_grey)

	# 3. Bottom divider curb along plat_btm (separator_y)
	var btm_left := Vector2(-fill_hw, plat_btm)
	var btm_right := Vector2(fill_hw, plat_btm)

	# Drop shadow onto lower lavender playfield (4–6 px height)
	draw_line(btm_left + Vector2(0.0, 3.0), btm_right + Vector2(0.0, 3.0), color_shadow, 5.0)
	# Curb bevel & crisp highlight
	draw_line(btm_left, btm_right, curb_bevel, 3.5)
	draw_line(btm_left, btm_right, curb_highlight, 2.0)

	# 4. Top curved shoulders: 2-layer curb (bevel 3.5 px + highlight 2.0 px)
	draw_polyline(left_shoulder, curb_bevel, 3.5, true)
	draw_polyline(left_shoulder, curb_highlight, 2.0, true)

	draw_polyline(right_shoulder, curb_bevel, 3.5, true)
	draw_polyline(right_shoulder, curb_highlight, 2.0, true)

func draw_parking_strip(_top_y: float, _bottom_y: float, _w: float) -> void:
	pass
