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
	# 1. Authoritative materials matching passenger track & reference curbs
	var color_track_grey := COLOR_TRACK_GREY
	var color_playfield := COLOR_PLAYFIELD
	var curb_highlight := Color("f8fafc")
	var curb_shadow := Color("a5abc2")
	var curb_deep := Color("545564")

	var hill_w: float = p_deck_w
	var top_hw: float = hill_w / 2.0
	var hw: float = p_width / 2.0
	var visible_hw: float = (p_visible_w / 2.0) if p_visible_w > 0.0 else hw
	var plat_btm: float = get_band_bottom_y()

	# Flare slope matching user's red guide lines (~0.95 outward slant)
	var flare_slope: float = 0.95
	var y_edge: float = p_top + (visible_hw - top_hw) / flare_slope

	# 2. Continuous platform polygon in authoritative track grey (#767786)
	# Extends outward to red guide line boundaries and fills full width down to plat_btm
	var poly_pts := PackedVector2Array()
	if y_edge < plat_btm:
		poly_pts.append(Vector2(-hw, plat_btm))
		poly_pts.append(Vector2(-visible_hw, plat_btm))
		poly_pts.append(Vector2(-visible_hw, y_edge))
		poly_pts.append(Vector2(-top_hw, p_top))
		poly_pts.append(Vector2(top_hw, p_top))
		poly_pts.append(Vector2(visible_hw, y_edge))
		poly_pts.append(Vector2(visible_hw, plat_btm))
		poly_pts.append(Vector2(hw, plat_btm))
	else:
		var btm_w = minf(visible_hw, top_hw + flare_slope * (plat_btm - p_top))
		poly_pts.append(Vector2(-btm_w, plat_btm))
		poly_pts.append(Vector2(-top_hw, p_top))
		poly_pts.append(Vector2(top_hw, p_top))
		poly_pts.append(Vector2(btm_w, plat_btm))
	draw_colored_polygon(poly_pts, color_track_grey)

	# 3. Lower bus-playfield polygon in Swatch 1 light lavender (#D2D5E4) below platform
	if p_bottom > plat_btm:
		var playfield_poly = PackedVector2Array([
			Vector2(-hw, plat_btm),
			Vector2(hw, plat_btm),
			Vector2(hw, p_bottom),
			Vector2(-hw, p_bottom)
		])
		draw_colored_polygon(playfield_poly, color_playfield)

	# 4. Clean 3D curb outlining platform perimeter along diagonal shoulders with open central gateway
	var x_gate: float = 110.0
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()

	if y_edge < plat_btm:
		left_edge.append(Vector2(-visible_hw, y_edge))
		left_edge.append(Vector2(-top_hw, p_top))
		left_edge.append(Vector2(-x_gate, p_top))

		right_edge.append(Vector2(x_gate, p_top))
		right_edge.append(Vector2(top_hw, p_top))
		right_edge.append(Vector2(visible_hw, y_edge))
	else:
		var btm_w = minf(visible_hw, top_hw + flare_slope * (plat_btm - p_top))
		left_edge.append(Vector2(-btm_w, plat_btm))
		left_edge.append(Vector2(-top_hw, p_top))
		left_edge.append(Vector2(-x_gate, p_top))

		right_edge.append(Vector2(x_gate, p_top))
		right_edge.append(Vector2(top_hw, p_top))
		right_edge.append(Vector2(btm_w, plat_btm))

	for edge in [left_edge, right_edge]:
		draw_polyline(edge, curb_shadow, 4.0, true)
		draw_polyline(edge, curb_deep, 2.5, true)
		draw_polyline(edge, curb_highlight, 1.5, true)

	# 5. Soft divider / separator style termination along bottom edge of grey platform
	# Eliminates sharp abrupt color cutoff transitioning into Swatch 1 light lavender playfield
	var btm_left := Vector2(-hw, plat_btm)
	var btm_right := Vector2(hw, plat_btm)

	# Drop shadow onto playfield
	draw_line(btm_left + Vector2(0, 2.0), btm_right + Vector2(0, 2.0), Color(0.0, 0.0, 0.0, 0.08), 3.5)
	# Soft divider bevel border
	draw_line(btm_left, btm_right, curb_shadow, 2.5)
	# Deep shadow groove
	draw_line(btm_left - Vector2(0, 1.0), btm_right - Vector2(0, 1.0), curb_deep, 1.8)
	# Highlight line
	draw_line(btm_left - Vector2(0, 2.2), btm_right - Vector2(0, 2.2), curb_highlight, 1.2)
