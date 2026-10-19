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

# Snug geometry constants: tight fit to larger 4-across passengers (100px total passenger span)
const ROAD_HALF_WIDTH: float = 53.0
const GATEWAY_HALF_WIDTH: float = 55.0

# Authoritative 3D reference colors
const COLOR_ROAD := Color("727382") # Refined slate grey
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
	var plat_y: float = r_outer + 20.0 # 188.0 in track-local coordinates
	
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
	# 4. ROAD SURFACE POLYGONS
	# -----------------------------------------------------------------
	var top_poly = PackedVector2Array()
	top_poly.append(Vector2(-straight_x - r_outer, 0.0))
	for i in range(1, n_arc / 2):
		var ang = PI + (float(i) / float(n_arc / 2)) * (PI / 2.0)
		top_poly.append(c_left + Vector2(cos(ang), sin(ang)) * r_outer)
	top_poly.append(Vector2(-straight_x, -r_outer))
	top_poly.append(Vector2(straight_x, -r_outer))
	for i in range(1, steps_to_inner):
		var ang = -PI / 2.0 + (float(i) / float(steps_to_inner)) * (inner_meet_ang - (-PI / 2.0))
		top_poly.append(c_right + Vector2(cos(ang), sin(ang)) * r_outer)

	if inner_meet_idx >= 0 and outer_meet_idx >= 0:
		top_poly.append(inner_meet_pt)
		for i in range(inner_meet_idx - 1, -1, -1):
			top_poly.append(f_inner[i])
		top_poly.append(f_outer[0])
		for i in range(1, outer_meet_idx):
			top_poly.append(f_outer[i])
		top_poly.append(outer_meet_pt)
		if outer_meet_ang < 0.0:
			var steps_to_zero = max(1, int(abs(outer_meet_ang) / (PI / float(n_arc))))
			for i in range(1, steps_to_zero):
				var ang = outer_meet_ang + (float(i) / float(steps_to_zero)) * (0.0 - outer_meet_ang)
				top_poly.append(c_right + Vector2(cos(ang), sin(ang)) * r_outer)
		top_poly.append(Vector2(straight_x + r_outer, 0.0))
	else:
		top_poly.append(Vector2(straight_x + r_outer, 0.0))

	top_poly.append(Vector2(straight_x_inner + r_inner_scaled, 0.0))
	for i in range(1, n_arc / 2):
		var ang = 0.0 - (float(i) / float(n_arc / 2)) * (PI / 2.0)
		top_poly.append(c_right_inner + Vector2(cos(ang), sin(ang)) * r_inner_scaled)
	top_poly.append(Vector2(straight_x_inner, -r_inner_scaled))
	top_poly.append(Vector2(-straight_x_inner, -r_inner_scaled))
	for i in range(1, n_arc / 2):
		var ang = -PI / 2.0 - (float(i) / float(n_arc / 2)) * (PI / 2.0)
		top_poly.append(c_left_inner + Vector2(cos(ang), sin(ang)) * r_inner_scaled)
	top_poly.append(Vector2(-straight_x_inner - r_inner_scaled, 0.0))

	# Bottom half polygon
	var btm_poly = PackedVector2Array()
	var start_btm_ang: float = maxf(0.0, outer_meet_ang if outer_meet_idx >= 0 else 0.0)
	steps_from_outer = max(1, int(abs(PI / 2.0 - start_btm_ang) / (PI / float(n_arc))))
	btm_poly.append(c_right + Vector2(cos(start_btm_ang), sin(start_btm_ang)) * r_outer)

	for i in range(1, steps_from_outer):
		var ang = start_btm_ang + (float(i) / float(steps_from_outer)) * (PI / 2.0 - start_btm_ang)
		btm_poly.append(c_right + Vector2(cos(ang), sin(ang)) * r_outer)
	btm_poly.append(Vector2(straight_x, r_outer))
	btm_poly.append(Vector2(x_gate, r_outer))
	btm_poly.append(Vector2(x_gate, plat_y + 25.0))
	btm_poly.append(Vector2(-x_gate, plat_y + 25.0))
	btm_poly.append(Vector2(-x_gate, r_outer))
	btm_poly.append(Vector2(-straight_x, r_outer))
	for i in range(1, n_arc / 2):
		var ang = PI / 2.0 + (float(i) / float(n_arc / 2)) * (PI / 2.0)
		btm_poly.append(c_left + Vector2(cos(ang), sin(ang)) * r_outer)
	btm_poly.append(Vector2(-straight_x - r_outer, 0.0))
	btm_poly.append(Vector2(-straight_x_inner - r_inner_scaled, 0.0))
	for i in range(1, n_arc / 2):
		var ang = PI - (float(i) / float(n_arc / 2)) * (PI / 2.0)
		btm_poly.append(c_left_inner + Vector2(cos(ang), sin(ang)) * r_inner_scaled)
	btm_poly.append(Vector2(-straight_x_inner, r_inner_scaled))
	btm_poly.append(Vector2(straight_x_inner, r_inner_scaled))
	for i in range(1, n_arc / 2):
		var ang = PI / 2.0 - (float(i) / float(n_arc / 2)) * (PI / 2.0)
		btm_poly.append(c_right_inner + Vector2(cos(ang), sin(ang)) * r_inner_scaled)
	btm_poly.append(Vector2(straight_x_inner + r_inner_scaled, 0.0))

	# -----------------------------------------------------------------
	# 5. DRAWING PIPELINE (2.5D SHADOWS, ROAD, PROMINENT THICK 3D CURB WALLS)
	# -----------------------------------------------------------------
	# Step A: 2.5D Drop shadows onto surrounding garden lawn
	var shadow_offset := Vector2(0, 5.0)
	var s_left = PackedVector2Array()
	for pt in curb_left: s_left.append(pt + shadow_offset)
	var s_right = PackedVector2Array()
	for pt in curb_right: s_right.append(pt + shadow_offset)

	draw_polyline(s_left, COLOR_SHADOW, 9.0, true)
	draw_polyline(s_right, COLOR_SHADOW, 9.0, true)

	# Step B: Grey road surface
	var clean_top = Geometry2D.merge_polygons(top_poly, PackedVector2Array())
	for p in clean_top:
		draw_colored_polygon(p, COLOR_ROAD)

	var clean_btm = Geometry2D.merge_polygons(btm_poly, PackedVector2Array())
	for p in clean_btm:
		draw_colored_polygon(p, COLOR_ROAD)

	# Step C: Ambient occlusion shadow along inner & outer road edges
	draw_polyline(curb_left, COLOR_ROAD_SHADOW, 4.0, true)
	draw_polyline(curb_right, COLOR_ROAD_SHADOW, 4.0, true)
	draw_polyline(curb_inner, COLOR_ROAD_SHADOW, 3.5, true)

	# Step D: Faint 4-lane guide markings (subtle dashed guidelines)
	_draw_lane_guidelines(straight_x, r_center, c_left, c_right)

	# Step E: Raised 3D Curb Walls (Vertical Extrusion dy = 3.5px)
	var wall_dy := Vector2(0, 3.5)
	var w_left = PackedVector2Array()
	for pt in curb_left: w_left.append(pt + wall_dy)
	var w_right = PackedVector2Array()
	for pt in curb_right: w_right.append(pt + wall_dy)

	draw_polyline(w_left, COLOR_CURB_FACE, 7.5, true)
	draw_polyline(w_right, COLOR_CURB_FACE, 7.5, true)

	# Inner retaining curb wall (bottom half visible to 2.5D camera)
	var w_inner = PackedVector2Array()
	for pt in curb_inner:
		if pt.y >= -10.0:
			w_inner.append(pt + wall_dy)
	if w_inner.size() >= 2:
		draw_polyline(w_inner, COLOR_CURB_FACE, 7.5, true)

	# Step F: PROMINENT THICK 3D WHITE & BEVEL CURBS (4.2px white rim, 6.5px bevel)
	draw_polyline(curb_left, COLOR_CURB_BEVEL, 6.5, true)
	draw_polyline(curb_left, COLOR_CURB_HIGHLIGHT, 4.2, true)

	draw_polyline(curb_right, COLOR_CURB_BEVEL, 6.5, true)
	draw_polyline(curb_right, COLOR_CURB_HIGHLIGHT, 4.2, true)

	draw_polyline(curb_inner, COLOR_CURB_BEVEL, 6.5, true)
	draw_polyline(curb_inner, COLOR_CURB_HIGHLIGHT, 4.2, true)

	# Step G: 3D Gateway Endcap Bollards at (-x_gate, plat_y) and (x_gate, plat_y)
	_draw_gateway_bollard(Vector2(-x_gate, plat_y))
	_draw_gateway_bollard(Vector2(x_gate, plat_y))

func _draw_lane_guidelines(straight_x: float, r_center: float, c_l: Vector2, c_r: Vector2) -> void:
	# Offsets for 3 lane divider boundaries between the 4 lanes (-26, 0, +26)
	var lane_divs = [-26.0, 0.0, 26.0]
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
