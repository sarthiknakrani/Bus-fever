extends Node2D
class_name CarJamTrackRenderer

## Authoritative Reference 2.5D Grey Track Renderer
## Recreates the exact 3D track geometry, snug passenger fit with zero blank space,
## prominent thick 3D extruded curbs, 2.5D gateway bollards, and 4-lane guide markings.

var curve: Curve2D
var feeder_curve: Curve2D
var plat_top_local: float = 245.0

var inner_meet_idx: int = -1
var inner_meet_pt := Vector2.ZERO
var outer_meet_idx: int = -1
var outer_meet_pt := Vector2.ZERO
var inner_meet_ang: float = -0.65
var outer_meet_ang: float = 0.09

# Snug geometry constants: tight fit to 4-across passengers (76.5px total passenger span)
const ROAD_HALF_WIDTH: float = 43.0
const GATEWAY_HALF_WIDTH: float = 67.5 # 1.5X width (was 45.0) for spacious crosswalk path

const COLOR_ROAD := Color("767786") # Authoritative road grey matching PlatformView
const COLOR_ROAD_SHADOW := Color("5d5e6c") # Ambient occlusion inner shadow
const COLOR_CURB_FACE := Color("4b4d5a") # Vertical 3D curb wall face
const COLOR_CURB_BEVEL := Color("a5abc2") # Curb bevel transition
const COLOR_CURB_HIGHLIGHT := Color("ffffff") # Thick pristine white metallic top rim
const COLOR_SHADOW := Color(0.04, 0.10, 0.04, 0.22) # Soft contact shadow onto lawn
const COLOR_LANE_MARKING := Color(1.0, 1.0, 1.0, 0.12) # Faint 4-lane guide dashes

func compute_intersections(f_outer: Array[Vector2] = [], f_inner: Array[Vector2] = []) -> void:
	if curve == null or feeder_curve == null:
		return
	var straight_x: float = 105.0
	var r_center: float = 115.0
	var c_right := Vector2(straight_x, 0.0)
	var r_outer: float = r_center + ROAD_HALF_WIDTH
	var w: float = ROAD_HALF_WIDTH

	if f_outer.is_empty() or f_inner.is_empty():
		f_outer.clear()
		f_inner.clear()
		var f_pts = feeder_curve.get_baked_points()
		for i in range(f_pts.size()):
			var pt = f_pts[i]
			var t: Vector2
			if i < f_pts.size() - 1:
				t = (f_pts[i + 1] - pt).normalized()
			else:
				t = (pt - f_pts[i - 1]).normalized()
			var n = Vector2(-t.y, t.x)
			f_outer.append(pt - n * w)
			f_inner.append(pt + n * w)

	inner_meet_idx = -1
	inner_meet_pt = Vector2.ZERO
	for i in range(1, f_inner.size()):
		var d_prev = f_inner[i - 1].distance_to(c_right)
		var d_curr = f_inner[i].distance_to(c_right)
		if (d_prev > r_outer and d_curr <= r_outer) or (d_prev <= r_outer and d_curr > r_outer):
			inner_meet_idx = i
			var pA = f_inner[i - 1]
			var pB = f_inner[i]
			var dAB = pB - pA
			var vA = pA - c_right
			var a_quad = dAB.dot(dAB)
			var b_quad = 2.0 * vA.dot(dAB)
			var c_quad = vA.dot(vA) - r_outer * r_outer
			var disc = b_quad * b_quad - 4.0 * a_quad * c_quad
			if disc >= 0.0 and a_quad > 0.0001:
				var t_val = (-b_quad - sqrt(disc)) / (2.0 * a_quad)
				if t_val < 0.0 or t_val > 1.0:
					t_val = (-b_quad + sqrt(disc)) / (2.0 * a_quad)
				inner_meet_pt = pA + dAB * clampf(t_val, 0.0, 1.0)
			else:
				inner_meet_pt = pB
			break

	outer_meet_idx = -1
	outer_meet_pt = Vector2.ZERO
	for i in range(1, f_outer.size()):
		var d_prev = f_outer[i - 1].distance_to(c_right)
		var d_curr = f_outer[i].distance_to(c_right)
		if (d_prev > r_outer and d_curr <= r_outer) or (d_prev <= r_outer and d_curr > r_outer):
			outer_meet_idx = i
			var pA = f_outer[i - 1]
			var pB = f_outer[i]
			var dAB = pB - pA
			var vA = pA - c_right
			var a_quad = dAB.dot(dAB)
			var b_quad = 2.0 * vA.dot(dAB)
			var c_quad = vA.dot(vA) - r_outer * r_outer
			var disc = b_quad * b_quad - 4.0 * a_quad * c_quad
			if disc >= 0.0 and a_quad > 0.0001:
				var t_val = (-b_quad - sqrt(disc)) / (2.0 * a_quad)
				if t_val < 0.0 or t_val > 1.0:
					t_val = (-b_quad + sqrt(disc)) / (2.0 * a_quad)
				outer_meet_pt = pA + dAB * clampf(t_val, 0.0, 1.0)
			else:
				outer_meet_pt = pB
			break

	inner_meet_ang = (inner_meet_pt - c_right).angle() if inner_meet_idx >= 0 else -0.65
	outer_meet_ang = (outer_meet_pt - c_right).angle() if outer_meet_idx >= 0 else 0.09

func _draw() -> void:
	if curve == null:
		return

	# Snug 4-across track geometry
	var straight_x: float = 105.0
	var r_center: float = 115.0
	var c_left := Vector2(-straight_x, 0.0)
	var c_right := Vector2(straight_x, 0.0)
	var r_outer: float = r_center + ROAD_HALF_WIDTH # 168.0
	var r_inner: float = r_center - ROAD_HALF_WIDTH # 62.0
	var w: float = ROAD_HALF_WIDTH
	var x_gate: float = GATEWAY_HALF_WIDTH
	var plat_y: float = 196.0 # Connects seamlessly to platform apron at W2 waypoint
	
	var straight_x_inner: float = straight_x
	var r_inner_scaled: float = r_inner
	var c_left_inner := c_left
	var c_right_inner := c_right

	var n_arc: int = 48

	# -----------------------------------------------------------------
	# 1. FEEDER ROAD BOUNDARIES & INTERSECTIONS
	# -----------------------------------------------------------------
	var f_outer: Array[Vector2] = []
	var f_inner: Array[Vector2] = []

	if feeder_curve != null:
		var f_pts = feeder_curve.get_baked_points()
		for i in range(f_pts.size()):
			var pt = f_pts[i]
			var t: Vector2
			if i < f_pts.size() - 1:
				t = (f_pts[i + 1] - pt).normalized()
			else:
				t = (pt - f_pts[i - 1]).normalized()
			var n = Vector2(-t.y, t.x)
			f_outer.append(pt - n * w)
			f_inner.append(pt + n * w)
		compute_intersections(f_outer, f_inner)

	# -----------------------------------------------------------------
	# 2. INNER HOLE RACETRACK CURB (Exposes inner 3D garden island)
	# -----------------------------------------------------------------
	var curb_inner = PackedVector2Array()
	curb_inner.append(Vector2(straight_x_inner, -r_inner_scaled))
	curb_inner.append(Vector2(-straight_x_inner, -r_inner_scaled))
	for i in range(1, n_arc):
		var ang = -PI / 2.0 - (float(i) / float(n_arc)) * PI
		curb_inner.append(c_left_inner + Vector2(cos(ang), sin(ang)) * r_inner_scaled)
	curb_inner.append(Vector2(-straight_x_inner, r_inner_scaled))
	curb_inner.append(Vector2(straight_x_inner, r_inner_scaled))
	for i in range(1, n_arc):
		var ang = PI / 2.0 - (float(i) / float(n_arc)) * PI
		curb_inner.append(c_right_inner + Vector2(cos(ang), sin(ang)) * r_inner_scaled)
	curb_inner.append(Vector2(straight_x_inner, -r_inner_scaled))

	# -----------------------------------------------------------------
	# 3. OUTER CURBS (Left side & Right side, with Gateway throat opening)
	# -----------------------------------------------------------------
	var steps_to_inner = max(1, int(abs(inner_meet_ang - (-PI / 2.0)) / (PI / float(n_arc))))

	# Left outer curb
	var curb_left = PackedVector2Array()
	curb_left.append(Vector2(-x_gate, plat_y + 1.0))
	curb_left.append(Vector2(-x_gate, r_outer))
	curb_left.append(Vector2(-straight_x, r_outer))
	for i in range(1, n_arc):
		var ang = PI / 2.0 + (float(i) / float(n_arc)) * PI
		curb_left.append(c_left + Vector2(cos(ang), sin(ang)) * r_outer)
	curb_left.append(Vector2(-straight_x, -r_outer))
	curb_left.append(Vector2(straight_x, -r_outer))
	for i in range(1, steps_to_inner):
		var ang = -PI / 2.0 + (float(i) / float(steps_to_inner)) * (inner_meet_ang - (-PI / 2.0))
		curb_left.append(c_right + Vector2(cos(ang), sin(ang)) * r_outer)

	if inner_meet_idx >= 0:
		curb_left.append(inner_meet_pt)
		for i in range(inner_meet_idx - 1, -1, -1):
			curb_left.append(f_inner[i])

	# Right outer curb
	var steps_from_outer = max(1, int(abs(PI / 2.0 - outer_meet_ang) / (PI / float(n_arc))))
	var curb_right = PackedVector2Array()

	if outer_meet_idx >= 0:
		for i in range(outer_meet_idx):
			curb_right.append(f_outer[i])
		curb_right.append(outer_meet_pt)

	for i in range(1, steps_from_outer):
		var ang = outer_meet_ang + (float(i) / float(steps_from_outer)) * (PI / 2.0 - outer_meet_ang)
		curb_right.append(c_right + Vector2(cos(ang), sin(ang)) * r_outer)
	curb_right.append(Vector2(straight_x, r_outer))
	curb_right.append(Vector2(x_gate, r_outer))
	curb_right.append(Vector2(x_gate, plat_y + 1.0))

	# -----------------------------------------------------------------
	# 4. ROAD SURFACE POLYGONS (100% UNIFIED, SEAMLESS, ZERO GAPS)
	# -----------------------------------------------------------------
	# Build complete seamless outer boundary tracing both oval and feeder
	var outer_road := PackedVector2Array()
	# Start at gateway left
	outer_road.append(Vector2(-x_gate, plat_y + 1.0))
	outer_road.append(Vector2(-x_gate, r_outer))
	outer_road.append(Vector2(-straight_x, r_outer))
	# Left arc
	for i in range(1, n_arc):
		var ang = PI / 2.0 + (float(i) / float(n_arc)) * PI
		outer_road.append(c_left + Vector2(cos(ang), sin(ang)) * r_outer)
	# Top straight
	outer_road.append(Vector2(-straight_x, -r_outer))
	outer_road.append(Vector2(straight_x, -r_outer))
	# Top right arc to inner meet
	for i in range(1, steps_to_inner):
		var ang = -PI / 2.0 + (float(i) / float(steps_to_inner)) * (inner_meet_ang - (-PI / 2.0))
		outer_road.append(c_right + Vector2(cos(ang), sin(ang)) * r_outer)
	if inner_meet_idx >= 0:
		outer_road.append(inner_meet_pt)
		for i in range(inner_meet_idx - 1, -1, -1):
			outer_road.append(f_inner[i])
	if not f_outer.is_empty():
		outer_road.append(f_outer[0])
	if outer_meet_idx >= 0:
		for i in range(1, outer_meet_idx):
			outer_road.append(f_outer[i])
		outer_road.append(outer_meet_pt)
	for i in range(1, steps_from_outer):
		var ang = outer_meet_ang + (float(i) / float(steps_from_outer)) * (PI / 2.0 - outer_meet_ang)
		outer_road.append(c_right + Vector2(cos(ang), sin(ang)) * r_outer)
	outer_road.append(Vector2(straight_x, r_outer))
	outer_road.append(Vector2(x_gate, r_outer))
	outer_road.append(Vector2(x_gate, plat_y + 1.0))

	# -----------------------------------------------------------------
	# 5. DRAWING PIPELINE (TRUE 3D DEPTH, VERTICAL RETAINING WALLS, ROAD CAMBER, 3D CURBS)
	# -----------------------------------------------------------------
	# Step A: Dual-layer 2.5D Drop shadows onto surrounding garden lawn
	var shadow_offset_deep := Vector2(0, 14.0)
	var shadow_offset_near := Vector2(0, 7.0)
	var s_left_deep = PackedVector2Array()
	var s_left_near = PackedVector2Array()
	for pt in curb_left:
		s_left_deep.append(pt + shadow_offset_deep)
		s_left_near.append(pt + shadow_offset_near)
	var s_right_deep = PackedVector2Array()
	var s_right_near = PackedVector2Array()
	for pt in curb_right:
		s_right_deep.append(pt + shadow_offset_deep)
		s_right_near.append(pt + shadow_offset_near)

	# Deep volumetric ambient shadow + crisp contact shadow onto lawn
	draw_polyline(s_left_deep, Color(0.01, 0.05, 0.01, 0.35), 24.0, true)
	draw_polyline(s_right_deep, Color(0.01, 0.05, 0.01, 0.35), 24.0, true)
	draw_polyline(s_left_near, Color(0.01, 0.04, 0.01, 0.55), 12.0, true)
	draw_polyline(s_right_near, Color(0.01, 0.04, 0.01, 0.55), 12.0, true)

	# Step B: Solid 3D Vertical Concrete Retaining Walls (Deck Extrusion H = 12.0px)
	# These physical vertical quads connect the top road deck to the ground on south-facing edges
	const WALL_H: float = 12.0
	const COLOR_WALL_LEFT := Color("343746") # South-west facing concrete wall (receives glancing light)
	const COLOR_WALL_RIGHT := Color("292b36") # South-east facing concrete wall (in directional shade)
	const COLOR_WALL_INNER := Color("1c1e26") # Inner courtyard retaining wall (deep pit shadow)
	const COLOR_WALL_SHADOW := Color(0.01, 0.05, 0.01, 0.45)

	# Left outer wall: visible where y >= -10.0 with smooth height taper towards apex
	_draw_wall_quad_strip_tapered(curb_left, WALL_H, COLOR_WALL_LEFT, true, -10.0, 25.0)

	# Right outer wall: visible from outer meet pt down to gateway throat
	_draw_wall_quad_strip_tapered(curb_right, WALL_H, COLOR_WALL_RIGHT, true, -5.0, 25.0)

	# Crisp ground contact shadow at the base of the outer vertical walls
	_draw_wall_base_shadow_tapered(curb_left, WALL_H, COLOR_WALL_SHADOW, 5.0, true, -10.0, 25.0)
	_draw_wall_base_shadow_tapered(curb_right, WALL_H, COLOR_WALL_SHADOW, 5.0, true, -5.0, 25.0)

	# Step C: 100% Solid, seamless grey road surface (zero gaps / zero green seams)
	# Draw solid outer road surface covering track & feeder seamlessly
	draw_colored_polygon(outer_road, COLOR_ROAD)

	# Step D: 3D Road Camber & Lighting (Crowned asphalt center ribbon + gutter ambient occlusion)
	_draw_road_camber(straight_x, r_center, c_left, c_right, n_arc)
	# Ambient occlusion gutter shadows where road meets inner and outer curbs
	draw_polyline(curb_left, Color(0.08, 0.09, 0.12, 0.38), 6.0, true)
	draw_polyline(curb_right, Color(0.08, 0.09, 0.12, 0.38), 6.0, true)
	draw_polyline(curb_inner, Color(0.08, 0.09, 0.12, 0.38), 6.0, true)

	# Step E: Terraced Sunken Central Garden Courtyard (Deep 3D perspective inside inner hole)
	# 1. Base sunken courtyard fill
	const COLOR_SUNKEN_BASE := Color("488828")
	draw_colored_polygon(curb_inner, COLOR_SUNKEN_BASE)

	# 2. Inset sunken lawn island
	var curb_inner_inset = PackedVector2Array()
	var r_inset = r_inner_scaled - 5.0
	curb_inner_inset.append(Vector2(straight_x_inner, -r_inset))
	curb_inner_inset.append(Vector2(-straight_x_inner, -r_inset))
	for i in range(1, n_arc):
		var ang = -PI / 2.0 - (float(i) / float(n_arc)) * PI
		curb_inner_inset.append(c_left_inner + Vector2(cos(ang), sin(ang)) * r_inset)
	curb_inner_inset.append(Vector2(-straight_x_inner, r_inset))
	curb_inner_inset.append(Vector2(straight_x_inner, r_inset))
	for i in range(1, n_arc):
		var ang = PI / 2.0 - (float(i) / float(n_arc)) * PI
		curb_inner_inset.append(c_right_inner + Vector2(cos(ang), sin(ang)) * r_inset)
	curb_inner_inset.append(Vector2(straight_x_inner, -r_inset))
	const COLOR_CENTRAL_LAWN := Color("62b03f")
	draw_colored_polygon(curb_inner_inset, COLOR_CENTRAL_LAWN)

	# 3. Inner Vertical Retaining Wall (Drops 10.0px downward into the sunken garden on northern rim y <= 15.0)
	const INNER_WALL_H: float = 10.0
	_draw_wall_quad_strip_tapered(curb_inner, INNER_WALL_H, COLOR_WALL_INNER, false, -15.0, 20.0)
	# Inner drop shadow cast by the northern deck onto the sunken courtyard lawn
	_draw_wall_base_shadow_tapered(curb_inner, INNER_WALL_H, Color(0.01, 0.05, 0.01, 0.52), 6.0, false, -15.0, 20.0)

	# Step F: Faint 4-lane guide markings (subtle dashed guidelines)
	_draw_lane_guidelines(straight_x, r_center, c_left, c_right)

	# Step G: 3D Zebra Crosswalk at Gateway Throat (Connecting loop to parking apron across 1.5X width)
	_draw_gateway_crosswalk(x_gate, r_outer, plat_y)

	# Step H: PROMINENT THICK 3D WHITE & BEVELED METALLIC/CONCRETE CURBS
	# Multi-tier beveled curb: dark crease base, stone bevel chamfer, pure white crown, specular glint
	_draw_3d_curb(curb_left)
	_draw_3d_curb(curb_right)
	_draw_3d_curb(curb_inner)

	# Step I: 3D Gateway Endcap Bollards at (-x_gate, plat_y) and (x_gate, plat_y)
	_draw_gateway_bollard(Vector2(-x_gate, plat_y))
	_draw_gateway_bollard(Vector2(x_gate, plat_y))

func _draw_wall_quad_strip_tapered(pts: PackedVector2Array, max_h: float, col: Color, south_facing: bool, y_min: float, y_ramp: float) -> void:
	if pts.size() < 2:
		return
	for i in range(pts.size() - 1):
		var p1 = pts[i]
		var p2 = pts[i + 1]
		var h1 = _calc_taper_h(p1.y, max_h, south_facing, y_min, y_ramp)
		var h2 = _calc_taper_h(p2.y, max_h, south_facing, y_min, y_ramp)
		if h1 <= 0.01 and h2 <= 0.01:
			continue
		var quad := PackedVector2Array([
			p1,
			p2,
			p2 + Vector2(0.0, h2),
			p1 + Vector2(0.0, h1)
		])
		draw_colored_polygon(quad, col)

func _draw_wall_base_shadow_tapered(pts: PackedVector2Array, max_h: float, col: Color, width: float, south_facing: bool, y_min: float, y_ramp: float) -> void:
	if pts.size() < 2:
		return
	for i in range(pts.size() - 1):
		var p1 = pts[i]
		var p2 = pts[i + 1]
		var h1 = _calc_taper_h(p1.y, max_h, south_facing, y_min, y_ramp)
		var h2 = _calc_taper_h(p2.y, max_h, south_facing, y_min, y_ramp)
		if h1 <= 0.5 and h2 <= 0.5:
			continue
		draw_line(p1 + Vector2(0.0, h1), p2 + Vector2(0.0, h2), col, width)

func _calc_taper_h(y: float, max_h: float, south_facing: bool, y_min: float, y_ramp: float) -> float:
	if south_facing:
		# Visible on southern side (y >= y_min)
		if y <= y_min:
			return 0.0
		var ramp_end = y_min + y_ramp
		if y >= ramp_end:
			return max_h
		return max_h * ((y - y_min) / y_ramp)
	else:
		# Inner hole wall: visible on northern side (y <= y_min + y_ramp)
		if y <= y_min:
			return max_h
		var ramp_end = y_min + y_ramp
		if y >= ramp_end:
			return 0.0
		return max_h * (1.0 - ((y - y_min) / y_ramp))

func _draw_road_camber(straight_x: float, r_center: float, c_l: Vector2, c_r: Vector2, n_arc: int) -> void:
	var c_pts := PackedVector2Array()
	c_pts.append(Vector2(straight_x, -r_center))
	c_pts.append(Vector2(-straight_x, -r_center))
	for i in range(1, n_arc):
		var ang = -PI / 2.0 - (float(i) / float(n_arc)) * PI
		c_pts.append(c_l + Vector2(cos(ang), sin(ang)) * r_center)
	c_pts.append(Vector2(-straight_x, r_center))
	c_pts.append(Vector2(straight_x, r_center))
	for i in range(1, n_arc):
		var ang = PI / 2.0 - (float(i) / float(n_arc)) * PI
		c_pts.append(c_r + Vector2(cos(ang), sin(ang)) * r_center)
	c_pts.append(Vector2(straight_x, -r_center))

	# Road camber crown highlight (broad soft glow + narrow sheen)
	draw_polyline(c_pts, Color(1.0, 1.0, 1.0, 0.09), 32.0, true)
	draw_polyline(c_pts, Color(1.0, 1.0, 1.0, 0.07), 16.0, true)
	draw_polyline(c_pts, Color(1.0, 1.0, 1.0, 0.05), 6.0, true)

func _draw_gateway_crosswalk(x_gate: float, r_outer: float, plat_y: float) -> void:
	# 7 white 3D zebra crosswalk bars spanning across 1.5X gateway width (135px)
	var num_bars := 7
	var bar_w := 9.0
	var bar_top_y := r_outer - 4.0
	var bar_bot_y := plat_y - 2.0
	var bar_h := bar_bot_y - bar_top_y
	var span := (x_gate - 14.0) * 2.0
	var step := span / float(num_bars - 1)
	var start_x := -x_gate + 14.0

	for i in range(num_bars):
		var bx = start_x + float(i) * step
		var bar_rect := Rect2(bx - bar_w / 2.0, bar_top_y, bar_w, bar_h)
		# 3D drop shadow
		draw_rect(Rect2(bx - bar_w / 2.0, bar_top_y + 2.5, bar_w, bar_h), Color(0.10, 0.11, 0.14, 0.35))
		# Main white paint bar
		draw_rect(bar_rect, Color(0.96, 0.97, 1.0, 0.90))
		# Top edge sunlit glint
		draw_rect(Rect2(bx - bar_w / 2.0 + 1.0, bar_top_y, bar_w - 2.0, 3.0), Color(1.0, 1.0, 1.0, 0.95))

func _draw_3d_curb(pts: PackedVector2Array) -> void:
	if pts.size() < 2:
		return
	# Layer 1: Dark outer crease / bottom lip
	draw_polyline(pts, Color("454858"), 8.0, true)
	# Layer 2: Stone bevel chamfer
	draw_polyline(pts, Color("9ea4bc"), 5.5, true)
	# Layer 3: Pristine white metallic top crown
	draw_polyline(pts, Color.WHITE, 3.6, true)
	# Layer 4: Specular highlight glint
	draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.95), 1.5, true)

func _draw_lane_guidelines(straight_x: float, r_center: float, c_l: Vector2, c_r: Vector2) -> void:
	# Offsets for 3 lane divider boundaries between the 4 lanes (-17.5, 0, +17.5)
	var lane_divs = [-17.5, 0.0, 17.5]
	for l_off in lane_divs:
		var r_div: float = r_center + l_off
		var pts = PackedVector2Array()
		pts.append(Vector2(straight_x, -r_div))
		pts.append(Vector2(-straight_x, -r_div))
		for i in range(1, 24):
			var ang = -PI / 2.0 - (float(i) / 24.0) * PI
			pts.append(c_l + Vector2(cos(ang), sin(ang)) * r_div)
		pts.append(Vector2(-straight_x, r_div))
		pts.append(Vector2(straight_x, r_div))
		for i in range(1, 16):
			var ang = PI / 2.0 - (float(i) / 24.0) * PI
			pts.append(c_r + Vector2(cos(ang), sin(ang)) * r_div)
		_draw_dashed_path(pts, COLOR_LANE_MARKING, 1.8, 9.0, 11.0)

func _draw_dashed_path(pts: PackedVector2Array, col: Color, width: float, dash_len: float, gap_len: float) -> void:
	if pts.size() < 2: return
	var is_drawing := true
	var curr_rem := dash_len
	
	for i in range(pts.size() - 1):
		var p1 = pts[i]
		var p2 = pts[i + 1]
		var seg_len = p1.distance_to(p2)
		if seg_len < 0.01: continue
		var seg_dir = (p2 - p1) / seg_len
		var walked: float = 0.0
		
		while walked < seg_len:
			var step = minf(curr_rem, seg_len - walked)
			var start_pt = p1 + seg_dir * walked
			var end_pt = p1 + seg_dir * (walked + step)
			if is_drawing:
				draw_line(start_pt, end_pt, col, width)
			walked += step
			curr_rem -= step
			if curr_rem <= 0.001:
				is_drawing = not is_drawing
				curr_rem = dash_len if is_drawing else gap_len

func _draw_gateway_bollard(pos: Vector2) -> void:
	# 3D cylindrical stone post with shadow and thick white top rim
	_draw_custom_ellipse(pos + Vector2(0, 3.5), Vector2(7.0, 3.5), Color(0.0, 0.0, 0.0, 0.28))
	draw_rect(Rect2(pos.x - 5.5, pos.y - 8.0, 11.0, 9.0), Color("4b4d5a"))
	draw_rect(Rect2(pos.x - 4.5, pos.y - 8.0, 9.0, 9.0), Color("818698"))
	draw_line(Vector2(pos.x - 2.0, pos.y - 8.0), Vector2(pos.x - 2.0, pos.y + 1.0), Color("a5abc2"), 2.0)
	_draw_custom_ellipse(pos + Vector2(0, -8.0), Vector2(6.0, 3.0), Color("e2e8f0"))
	_draw_custom_ellipse(pos + Vector2(0, -8.0), Vector2(4.5, 2.2), Color("ffffff"))

func _draw_custom_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a = float(i) / 16.0 * TAU
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
