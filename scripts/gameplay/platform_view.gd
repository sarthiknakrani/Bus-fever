extends Node2D
class_name PlatformView

var p_top: float = -500.0
var p_bottom: float = 2000.0
var p_width: float = 2000.0
var p_partition_y: float = 0.0
var p_separator_y: float = -9999.0
var p_deck_w: float = 580.0

var p_visible_w: float = 0.0

# Authoritative source-of-truth track grey matching passenger track & connector
const COLOR_TRACK_GREY := Color("767786")
const COLOR_PLAYFIELD := Color("d2d5e4") # Swatch 1 light lavender playfield

func setup_full(top_y: float, bottom_y: float, w: float, partition_y: float, separator_y: float = -9999.0, deck_w: float = 580.0, visible_w: float = 0.0) -> void:
	p_top = top_y
	p_bottom = bottom_y
	p_width = w
	p_partition_y = partition_y
	p_separator_y = separator_y
	p_deck_w = deck_w
	p_visible_w = visible_w if visible_w > 0.0 else (w - 200.0 if w > 200.0 else w)
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
	# Lower bus-playfield polygon in Swatch 1 light lavender (#D2D5E4)
	# Flared grey platform trapezoid, curbs, and ParkingBase removed — slots sit directly on lavender playfield
	var color_playfield := COLOR_PLAYFIELD
	var hw: float = p_width / 2.0
	var top_y: float = minf(p_top, get_band_bottom_y())

	if p_bottom > top_y:
		var playfield_poly := PackedVector2Array([
			Vector2(-hw, top_y),
			Vector2(hw, top_y),
			Vector2(hw, p_bottom),
			Vector2(-hw, p_bottom)
		])
		draw_colored_polygon(playfield_poly, color_playfield)

func draw_parking_strip(_top_y: float, _bottom_y: float, _w: float) -> void:
	# Handled by ParkingStrip node (kept for PlatformView API compatibility)
	pass

