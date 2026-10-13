extends Node2D
class_name PlatformView

var p_top: float = -500.0
var p_bottom: float = 2000.0
var p_width: float = 2000.0
var p_partition_y: float = 0.0
var p_separator_y: float = -9999.0
var p_deck_w: float = 580.0

# Authoritative source-of-truth track grey matching passenger track & connector
const COLOR_TRACK_GREY := Color("767786")
const COLOR_PLAYFIELD := Color("d2d5e4") # Swatch 1 light lavender playfield

func setup_full(top_y: float, bottom_y: float, w: float, partition_y: float, separator_y: float = -9999.0, deck_w: float = 580.0) -> void:
	p_top = top_y
	p_bottom = bottom_y
	p_width = w
	p_partition_y = partition_y
	p_separator_y = separator_y
	p_deck_w = deck_w
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
	# 1. Authoritative materials matching passenger track & reference curbs
	var color_track_grey := COLOR_TRACK_GREY
	var color_playfield := COLOR_PLAYFIELD
	var curb_highlight := Color("f8fafc")
	var curb_shadow := Color("a5abc2")
	var curb_deep := Color("545564")

	var hill_w: float = p_deck_w
	var slope_w: float = 75.0
	var gy: float = p_partition_y
	var hw: float = p_width / 2.0
	var sep_y: float = p_separator_y
	var band_btm: float = get_band_bottom_y()

	# 2. Continuous platform & separator polygon in authoritative track grey (#767786)
	# Fills the raised platform deck, left/right slanted shoulders, and horizontal band down to separator line
	var platform_poly = PackedVector2Array([
		Vector2(-hw, band_btm),
		Vector2(-hw, gy),
		Vector2(-hill_w / 2.0 - slope_w, gy),
		Vector2(-hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0 + slope_w, gy),
		Vector2(hw, gy),
		Vector2(hw, band_btm)
	])
	draw_colored_polygon(platform_poly, color_track_grey)

	# 3. Lower bus-playfield polygon in Swatch 1 light lavender (#D2D5E4) below separator line
	if p_bottom > band_btm:
		var playfield_poly = PackedVector2Array([
			Vector2(-hw, band_btm),
			Vector2(hw, band_btm),
			Vector2(hw, p_bottom),
			Vector2(-hw, p_bottom)
		])
		draw_colored_polygon(playfield_poly, color_playfield)

	# 4. Clean 3D curb outlining the platform perimeter with open central gateway for seamless road flow
	var x_gate: float = 110.0
	var left_edge = PackedVector2Array([
		Vector2(-hill_w / 2.0 - slope_w, gy),
		Vector2(-hill_w / 2.0, p_top),
		Vector2(-x_gate, p_top)
	])
	var right_edge = PackedVector2Array([
		Vector2(x_gate, p_top),
		Vector2(hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0 + slope_w, gy)
	])

	for edge in [left_edge, right_edge]:
		draw_polyline(edge, curb_shadow, 4.0, true)
		draw_polyline(edge, curb_deep, 2.5, true)
		draw_polyline(edge, curb_highlight, 1.5, true)
