extends Node2D
class_name CarJamTrackRenderer

## Authoritative Reference 2.5D Grey Track Renderer
## Recreates the exact 3D track geometry, snug passenger fit with zero blank space,
## prominent thick 3D extruded curbs, 2.5D gateway bollards, and 4-lane guide markings.

var curve: Curve2D
var feeder_curve: Curve2D
var plat_top_local: float = 245.0

## Animated shoreline water time accumulator
var _water_time: float = 0.0

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

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_water_time += delta
	queue_redraw()

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

	# Step C: 100% Solid, seamless grey road surface with true empty inner lagoon hole
	# Split into left and right seamless simple ribbons meeting at x=0 so the center hole is TRULY EMPTY!
	# This lets the real, continuous 3D Caribbean ocean background show right through seamlessly.
	var road_left := PackedVector2Array()
	road_left.append(Vector2(0.0, -r_outer))
	road_left.append(Vector2(-straight_x, -r_outer))
	for i in range(1, n_arc):
		var ang = -PI / 2.0 - (float(i) / float(n_arc)) * PI
		road_left.append(c_left + Vector2(cos(ang), sin(ang)) * r_outer)
	road_left.append(Vector2(-straight_x, r_outer))
	road_left.append(Vector2(-x_gate, r_outer))
	road_left.append(Vector2(-x_gate, plat_y + 1.0))
	road_left.append(Vector2(0.0, plat_y + 1.0))
	road_left.append(Vector2(0.0, r_inner))
	road_left.append(Vector2(-straight_x, r_inner))
	for i in range(1, n_arc):
		var ang = PI / 2.0 + (float(i) / float(n_arc)) * PI
		road_left.append(c_left + Vector2(cos(ang), sin(ang)) * r_inner)
	road_left.append(Vector2(-straight_x, -r_inner))
	road_left.append(Vector2(0.0, -r_inner))

	var road_right := PackedVector2Array()
	road_right.append(Vector2(0.0, -r_outer))
	road_right.append(Vector2(straight_x, -r_outer))
	for i in range(1, steps_to_inner):
		var ang = -PI / 2.0 + (float(i) / float(steps_to_inner)) * (inner_meet_ang - (-PI / 2.0))
		road_right.append(c_right + Vector2(cos(ang), sin(ang)) * r_outer)
	if inner_meet_idx >= 0:
		road_right.append(inner_meet_pt)
		for i in range(inner_meet_idx - 1, -1, -1):
			road_right.append(f_inner[i])
	if not f_outer.is_empty():
		road_right.append(f_outer[0])
	if outer_meet_idx >= 0:
		for i in range(1, outer_meet_idx):
			road_right.append(f_outer[i])
		road_right.append(outer_meet_pt)
	for i in range(1, steps_from_outer):
		var ang = outer_meet_ang + (float(i) / float(steps_from_outer)) * (PI / 2.0 - outer_meet_ang)
		road_right.append(c_right + Vector2(cos(ang), sin(ang)) * r_outer)
	road_right.append(Vector2(straight_x, r_outer))
	road_right.append(Vector2(x_gate, r_outer))
	road_right.append(Vector2(x_gate, plat_y + 1.0))
	road_right.append(Vector2(0.0, plat_y + 1.0))
	road_right.append(Vector2(0.0, r_inner))
	road_right.append(Vector2(straight_x, r_inner))
	for i in range(1, n_arc):
		var ang = PI / 2.0 - (float(i) / float(n_arc)) * PI
		road_right.append(c_right + Vector2(cos(ang), sin(ang)) * r_inner)
	road_right.append(Vector2(straight_x, -r_inner))
	road_right.append(Vector2(0.0, -r_inner))

	draw_colored_polygon(road_left, COLOR_ROAD)
	draw_colored_polygon(road_right, COLOR_ROAD)

	# Step D: 3D Road Camber & Lighting (Crowned asphalt center ribbon + gutter ambient occlusion)
	_draw_road_camber(straight_x, r_center, c_left, c_right, n_arc)
	# Ambient occlusion gutter shadows where road meets inner and outer curbs
	draw_polyline(curb_left, Color(0.08, 0.09, 0.12, 0.38), 6.0, true)
	draw_polyline(curb_right, Color(0.08, 0.09, 0.12, 0.38), 6.0, true)
	draw_polyline(curb_inner, Color(0.08, 0.09, 0.12, 0.38), 6.0, true)

	# Step E: 3D Inner Retaining Wall (Drops 10.0px downward into the inner lagoon on northern rim y <= 15.0)
	const INNER_WALL_H: float = 10.0
	_draw_wall_quad_strip_tapered(curb_inner, INNER_WALL_H, COLOR_WALL_INNER, false, -15.0, 20.0)
	# Inner drop shadow cast by the northern deck onto the lagoon water
	_draw_wall_base_shadow_tapered(curb_inner, INNER_WALL_H, Color(0.01, 0.08, 0.20, 0.38), 6.0, false, -15.0, 20.0)

	# Step F: Faint 4-lane guide markings (subtle dashed guidelines)
	_draw_lane_guidelines(straight_x, r_center, c_left, c_right)

	# Step G: 3D Zebra Crosswalk at Gateway Throat (Connecting loop to parking apron across 1.5X width)
	_draw_gateway_crosswalk(x_gate, r_outer, plat_y)

	# Step H: Shoreline Embankment, Rocks & Animated Water Lapping at gateway flanks
	# Drawn before curbs so the pristine white curb rim stays crisp and cleanly bounded
	_draw_shoreline_rocks_and_water(x_gate, r_outer, plat_y)

	# Step I: PROMINENT THICK 3D WHITE & BEVELED METALLIC/CONCRETE CURBS
	# Multi-tier beveled curb: dark crease base, stone bevel chamfer, pure white crown, specular glint
	_draw_3d_curb(curb_left)
	_draw_3d_curb(curb_right)
	_draw_3d_curb(curb_inner)

	# Step J: 3D Gateway Endcap Bollards at (-x_gate, plat_y) and (x_gate, plat_y)
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

## ─────────────────────────────────────────────────────────────────────────────
## Step H — 3D Coastal Shoreline ("Kinaro"), Chiseled Boulders & Real Ocean Water
## Authentic 2.5D casual game shoreline:
## - Crystal-clear ocean water flowing seamlessly between pier & platform
## - Solid 3D stone pier corner foundations at the gateway throat
## - Artistically chiseled 3D coastal boulders with faceted triangulation & moss
## - Submerged rock foundations visible through translucent tropical water
## - Dynamic animated lapping foam collars, expanding ripples & sun sparkles
## ─────────────────────────────────────────────────────────────────────────────
func _draw_shoreline_rocks_and_water(x_gate: float, r_outer: float, plat_y: float) -> void:
	# 1. 3D Pier Embankment / Quay Corner Foundation at the gateway flanks
	_draw_quay_embankment(x_gate, r_outer, plat_y)

	# 2. Curated 3D Coastal Rock Formations resting in the open water cove
	# Format: [pos, radius, phase_seed, has_moss, is_skerry]
	var rock_clusters: Array = [
		# Left Coastal Formation (Spans naturally across the water cove)
		[Vector2(-x_gate - 14.0, r_outer + 18.0), 10.5, 0.0, false, false], # Corner anchor stone
		[Vector2(-x_gate - 48.0, r_outer + 15.0), 16.5, 1.2, true,  false], # Majestic Hero Boulder
		[Vector2(-x_gate - 88.0, r_outer + 10.0), 13.5, 2.5, false, false], # Outer coastal bluff
		[Vector2(-x_gate - 32.0, r_outer + 25.0),  8.0, 3.8, false, true],  # Low reef skerry

		# Right Coastal Formation (Balanced companion reef on feeder side)
		[Vector2(x_gate + 14.0,  r_outer + 18.0), 10.5, 0.6, false, false], # Corner anchor stone
		[Vector2(x_gate + 48.0,  r_outer + 15.0), 16.5, 1.8, true,  false], # Majestic Hero Boulder
		[Vector2(x_gate + 88.0,  r_outer + 10.0), 13.5, 3.1, false, false], # Outer coastal bluff
		[Vector2(x_gate + 32.0,  r_outer + 25.0),  8.0, 0.4, false, true],  # Low reef skerry
	]

	# 3. Expanding water ripples from rock bases
	_draw_animated_rock_ripples(rock_clusters)

	# 4. Draw artistically chiseled 3D coastal boulders (using robust pure triangles)
	for rdef in rock_clusters:
		_draw_chiseled_3d_rock(rdef[0], rdef[1], rdef[2], rdef[3], rdef[4])

	# 5. Dynamic animated water foam collars lapping around each rock
	for rdef in rock_clusters:
		_draw_rock_water_foam(rdef[0], rdef[1], rdef[2], rdef[4])

	# 6. Channel wave breakers: gentle animated foam wave crests washing through channel
	_draw_channel_wave_crests(x_gate, r_outer, plat_y)

	# 7. Sparkling diamond sun glints on the shoreline water
	_draw_shoreline_glints(x_gate, r_outer, plat_y)

## Draws the solid 3D stone pier embankment corner foundations at gateway flanks.
func _draw_quay_embankment(x_gate: float, r_outer: float, plat_y: float) -> void:
	for side in [-1, 1]:
		var s := float(side)
		# 1. Vertical Pier Quoin / Embankment Foundation Wall at crosswalk throat edge
		var pier_wall := PackedVector2Array([
			Vector2(s * x_gate, r_outer),
			Vector2(s * (x_gate + 10.0), r_outer),
			Vector2(s * (x_gate + 10.0), plat_y),
			Vector2(s * x_gate, plat_y)
		])
		draw_colored_polygon(pier_wall, Color("343a48"))

		# 2. Pier stone coping highlight edge
		draw_line(Vector2(s * (x_gate + 10.0), r_outer), Vector2(s * (x_gate + 10.0), plat_y), Color("909cb0"), 2.0)

		# 3. Translucent shallow turquoise water fringe along the pier base
		var wash_pts := PackedVector2Array([
			Vector2(s * (x_gate + 8.0), r_outer + 8.0),
			Vector2(s * (x_gate + 110.0), r_outer + 8.0),
			Vector2(s * (x_gate + 110.0), r_outer + 18.0),
			Vector2(s * (x_gate + 8.0), plat_y - 2.0)
		])
		draw_colored_polygon(wash_pts, Color(0.18, 0.85, 0.95, 0.18))

## Draws a prominent, artistically faceted 3D coastal boulder in 2.5D perspective using robust triangles.
func _draw_chiseled_3d_rock(center: Vector2, rad: float, phase: float, has_moss: bool, is_skerry: bool) -> void:
	# 1. Soft deep-water contact shadow
	var shadow_pts := PackedVector2Array()
	for i in 14:
		var a = float(i) / 13.0 * TAU
		shadow_pts.append(center + Vector2(cos(a) * rad * 1.15 + rad * 0.18, sin(a) * rad * 0.52 + rad * 0.32))
	draw_colored_polygon(shadow_pts, Color(0.01, 0.05, 0.16, 0.45))

	# 2. Submerged rock foundation visible through clear tropical ocean
	var sub_pts := PackedVector2Array()
	for i in 12:
		var a = float(i) / 11.0 * PI
		sub_pts.append(center + Vector2(cos(a) * rad * 1.05, sin(a) * rad * 0.62 + rad * 0.18))
	draw_colored_polygon(sub_pts, Color(0.10, 0.58, 0.74, 0.75))

	# 3. Chiseled 3D Rock Facets:
	var v_apex    := center + Vector2(-rad * 0.22, -rad * 0.38) # Sunlit high crest
	var v_top     := center + Vector2(rad * 0.12,  -rad * 0.48) # Top peak
	var v_r_top   := center + Vector2(rad * 0.68,  -rad * 0.25) # Upper-right corner
	var v_r_mid   := center + Vector2(rad * 0.92,   rad * 0.08) # Right flank
	var v_r_bot   := center + Vector2(rad * 0.65,   rad * 0.48) # Lower-right base
	var v_bot_mid := center + Vector2(rad * 0.05,   rad * 0.58) # Bottom waterline center
	var v_l_bot   := center + Vector2(-rad * 0.68,  rad * 0.42) # Lower-left base
	var v_l_mid   := center + Vector2(-rad * 0.88,  rad * 0.05) # Left flank
	var v_l_top   := center + Vector2(-rad * 0.65, -rad * 0.22) # Upper-left shoulder

	if is_skerry:
		# Low wet skerry: robust triangles with clear wet stone sheen
		draw_colored_polygon(PackedVector2Array([center, v_l_bot, v_bot_mid]), Color("3a485a"))
		draw_colored_polygon(PackedVector2Array([center, v_bot_mid, v_r_mid]), Color("323e4e"))
		draw_colored_polygon(PackedVector2Array([center, v_r_mid, v_top]), Color("4a5c70"))
		draw_colored_polygon(PackedVector2Array([center, v_top, v_l_top]), Color("7e96b0"))
		draw_colored_polygon(PackedVector2Array([center, v_l_top, v_l_bot]), Color("5c7086"))
		draw_line(v_l_top, v_top, Color(1.0, 1.0, 1.0, 0.85), 1.6)
		return

	# Facet Group 1: Right Shadow Face (Facing away from tropical sun)
	draw_colored_polygon(PackedVector2Array([center, v_top, v_r_top]), Color("384656"))
	draw_colored_polygon(PackedVector2Array([center, v_r_top, v_r_mid]), Color("303c4c"))
	draw_colored_polygon(PackedVector2Array([center, v_r_mid, v_r_bot]), Color("283240"))
	draw_colored_polygon(PackedVector2Array([center, v_r_bot, v_bot_mid]), Color("2e3846"))

	# Facet Group 2: Left Mid Face (Glancing sunlit facet)
	draw_colored_polygon(PackedVector2Array([center, v_bot_mid, v_l_bot]), Color("52647a"))
	draw_colored_polygon(PackedVector2Array([center, v_l_bot, v_l_mid]), Color("60748c"))
	draw_colored_polygon(PackedVector2Array([v_apex, v_l_mid, v_l_top]), Color("788fa8"))

	# Facet Group 3: Sunlit Upper Plane
	draw_colored_polygon(PackedVector2Array([v_apex, v_l_top, v_top]), Color("9cb4cc"))
	draw_colored_polygon(PackedVector2Array([v_apex, v_top, center]), Color("8aa2ba"))
	draw_colored_polygon(PackedVector2Array([v_apex, center, v_l_mid]), Color("7288a0"))

	# Facet Group 4: Warm Sunny Crown Ridge
	var crown_p1 := v_apex + Vector2(-rad * 0.18, -rad * 0.12)
	var crown_p2 := v_apex + Vector2(rad * 0.14, -rad * 0.08)
	var crown_p3 := v_apex + Vector2(rad * 0.02, rad * 0.14)
	draw_colored_polygon(PackedVector2Array([v_apex, crown_p1, crown_p3]), Color("d4e4f4"))
	draw_colored_polygon(PackedVector2Array([v_apex, crown_p3, crown_p2]), Color("b8d0e6"))

	# Optional lush tropical moss cap (pure triangles)
	if has_moss:
		var m1 := v_apex + Vector2(-rad * 0.22, -rad * 0.15)
		var m2 := v_apex + Vector2(rad * 0.16, -rad * 0.10)
		var m3 := v_apex + Vector2(0.0, rad * 0.10)
		draw_colored_polygon(PackedVector2Array([v_apex, m1, m3]), Color(0.38, 0.72, 0.32, 0.90))
		draw_colored_polygon(PackedVector2Array([v_apex, m3, m2]), Color(0.52, 0.88, 0.42, 0.90))
		draw_line(m1, m2, Color(0.75, 0.98, 0.60, 0.95), 1.8)

	# Specular sunlight ridge line
	draw_line(v_l_top, v_apex, Color(1.0, 1.0, 1.0, 0.95), 2.0)
	draw_line(v_apex, v_top, Color(1.0, 1.0, 1.0, 0.85), 1.6)

## Draws realistic animated water foam collars hugging each boulder.
func _draw_rock_water_foam(center: Vector2, rad: float, phase: float, is_skerry: bool) -> void:
	var foam_pulse := sin(_water_time * 2.2 + phase) * 0.35 + 0.50
	var foam_col := Color(0.92, 0.98, 1.0, foam_pulse * (0.75 if is_skerry else 0.60))
	var foam_r := rad * (1.30 if is_skerry else 1.22)

	# Crescent foam arc hugging the water surface line
	var arc_pts := PackedVector2Array()
	var n_arc_pts := 16
	for i in range(n_arc_pts):
		var ang: float = float(i) / float(n_arc_pts - 1) * PI
		arc_pts.append(center + Vector2(cos(ang) * foam_r, sin(ang) * foam_r * 0.60 + rad * 0.15))
	if arc_pts.size() >= 2:
		draw_polyline(arc_pts, foam_col, 2.2, true)

	# Faint secondary outer foam ring
	var outer_alpha := foam_pulse * 0.30
	var outer_pts := PackedVector2Array()
	var outer_r := rad * 1.45
	for i in range(12):
		var ang: float = (float(i) / 11.0) * PI
		outer_pts.append(center + Vector2(cos(ang) * outer_r, sin(ang) * outer_r * 0.55 + rad * 0.20))
	if outer_pts.size() >= 2:
		draw_polyline(outer_pts, Color(0.80, 0.94, 1.0, outer_alpha), 1.4, true)

## Draws concentric animated water ripples expanding from rock bases.
func _draw_animated_rock_ripples(rocks: Array) -> void:
	for rdef in rocks:
		var rpos: Vector2 = rdef[0]
		var rsize: float  = rdef[1]
		var rphase: float = rdef[2]
		for ri in 2:
			var t := fmod(_water_time * 0.80 + rphase + float(ri) * 0.50, 1.0)
			var rip_r := rsize * (1.15 + t * 0.95)
			var rip_alpha := (1.0 - t) * 0.32
			_draw_ellipse_outline(rpos + Vector2(0.0, rsize * 0.20), Vector2(rip_r, rip_r * 0.55), Color(0.75, 0.94, 1.0, rip_alpha), 1.2)

## Draws gentle animated foam wave crests washing through the water channel.
func _draw_channel_wave_crests(x_gate: float, r_outer: float, plat_y: float) -> void:
	for side in [-1, 1]:
		var s := float(side)
		for wi in 2:
			var t_cycle: float = fmod(_water_time * 0.65 + float(wi) * 0.50, 1.8) / 1.8
			var wave_alpha: float = sin(t_cycle * PI) * 0.45
			var wave_y: float = r_outer + 12.0 + t_cycle * 18.0
			var start_x: float = s * (x_gate + 8.0)
			var wave_len: float = 75.0 - float(wi) * 10.0

			var pts := PackedVector2Array()
			for k in 14:
				var frac: float = float(k) / 13.0
				var wx: float = start_x + s * frac * wave_len
				var wy: float = wave_y + sin(frac * PI * 1.5 + _water_time * 1.8) * 2.8
				pts.append(Vector2(wx, wy))
			if pts.size() >= 2:
				draw_polyline(pts, Color(0.85, 0.96, 1.0, wave_alpha), 1.8, true)

## Draws sparkling sun glints in the shoreline water near the rocks.
func _draw_shoreline_glints(x_gate: float, r_outer: float, plat_y: float) -> void:
	var glints := [
		[Vector2(-x_gate - 20.0, r_outer + 32.0), 0.0],
		[Vector2(-x_gate - 52.0, r_outer + 30.0), 1.6],
		[Vector2(-x_gate - 95.0, r_outer + 24.0), 2.8],
		[Vector2(x_gate + 20.0,  r_outer + 32.0), 0.8],
		[Vector2(x_gate + 52.0,  r_outer + 30.0), 2.2],
		[Vector2(x_gate + 95.0,  r_outer + 24.0), 3.4],
	]
	for g in glints:
		var gpos: Vector2 = g[0]
		var gphase: float = g[1]
		var glint_alpha: float = maxf(0.0, sin(_water_time * 3.4 + gphase))
		if glint_alpha > 0.25:
			var sz: float = 2.6 * glint_alpha
			var col := Color(1.0, 1.0, 1.0, glint_alpha * 0.85)
			draw_line(gpos - Vector2(sz, 0), gpos + Vector2(sz, 0), col, 1.2)
			draw_line(gpos - Vector2(0, sz), gpos + Vector2(0, sz), col, 1.2)

func _draw_ellipse_outline(center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a = float(i) / 16.0 * TAU
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(pts, color, width, true)
