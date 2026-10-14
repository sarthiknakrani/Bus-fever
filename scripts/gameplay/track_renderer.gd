extends Node2D
class_name CarJamTrackRenderer

## Authoritative Reference Grey Track Renderer
## Recreates the exact track geometry, proportions, gateway opening,
## feeder merge, and thin crisp curbs from the primary reference video.

var curve: Curve2D
var feeder_curve: Curve2D
var plat_top_local: float = 245.0

# Authoritative geometry constants
const ROAD_HALF_WIDTH: float = 62.0
const GATEWAY_HALF_WIDTH: float = 95.0 # ±95px gateway throat opening

# Authoritative reference colors
const COLOR_ROAD := Color("767786") # Muted slate grey matching reference (#767786 / #747584)
const COLOR_CURB_HIGHLIGHT := Color("f8fafc") # Thin crisp near-white highlight
const COLOR_CURB_BEVEL := Color("a5abc2") # Subtle cool slate bevel shadow
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.12) # Soft contact shadow
const COLOR_GARDEN := Color("69a827") # Lush vibrant garden green matching plaza artwork

func _draw() -> void:
	if curve == null:
		return

	# Oval dimensions derived from authoritative curve geometry
	# Centerline: left arc center (-105, 0), right arc center (105, 0), radius R=115
	var straight_x: float = 105.0
	var r_center: float = 115.0
	var c_left := Vector2(-straight_x, 0.0)
	var c_right := Vector2(straight_x, 0.0)
	var r_outer: float = r_center + ROAD_HALF_WIDTH # 177.0
	var r_inner: float = r_center - ROAD_HALF_WIDTH # 53.0
	var w: float = ROAD_HALF_WIDTH
	var x_gate: float = GATEWAY_HALF_WIDTH
	var plat_y: float = r_outer + 20.0 # 197.0 in track-local coordinates

	# Scaled inner opening: 70% area reduction (30% remaining empty center area)
	# Original area A0 = 4*105*53 + pi*53^2 = 31084.73 sq px
	# Target area = 31084.73 * 0.30 = 9325.42 sq px
	# Scale factor s = sqrt(0.30) = 0.5477225575
	const SCALE_INNER: float = 0.5477225575
	var straight_x_inner: float = straight_x * SCALE_INNER # 57.51087
	var r_inner_scaled: float = r_inner * SCALE_INNER # 29.02930
	var c_left_inner := Vector2(-straight_x_inner, 0.0)
	var c_right_inner := Vector2(straight_x_inner, 0.0)

	var n_arc: int = 48

	# -----------------------------------------------------------------
	# 1. FEEDER ROAD BOUNDARIES & INTERSECTIONS
	# -----------------------------------------------------------------
	var f_outer: Array[Vector2] = []
	var f_inner: Array[Vector2] = []

	var inner_meet_idx: int = -1
	var inner_meet_pt := Vector2.ZERO
	var outer_meet_idx: int = -1
	var outer_meet_pt := Vector2.ZERO

	if feeder_curve != null:
		var f_pts = feeder_curve.get_baked_points()
		for i in range(f_pts.size()):
			var pt = f_pts[i]
			var t: Vector2
			if i < f_pts.size() - 1:
				t = (f_pts[i + 1] - pt).normalized()
			else:
				t = (pt - f_pts[i - 1]).normalized()
			var n = Vector2(-t.y, t.x) # Normal pointing towards oval center
			f_outer.append(pt - n * w)
			f_inner.append(pt + n * w)

		# Find where feeder inner boundary intersects the oval outer boundary
		for i in range(f_inner.size()):
			if f_inner[i].distance_to(c_right) <= r_outer:
				inner_meet_idx = i
				inner_meet_pt = f_inner[i]
				break

		# Find where feeder outer boundary intersects the oval outer boundary
		for i in range(f_outer.size()):
			if f_outer[i].distance_to(c_right) <= r_outer:
				outer_meet_idx = i
				outer_meet_pt = f_outer[i]
				break

	var inner_meet_ang: float = (inner_meet_pt - c_right).angle() if inner_meet_idx >= 0 else -0.65
	var outer_meet_ang: float = (outer_meet_pt - c_right).angle() if outer_meet_idx >= 0 else 0.09

	# -----------------------------------------------------------------
	# 2. INNER HOLE RACETRACK CURB (Exposes green garden background)
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
	curb_inner.append(Vector2(straight_x_inner, -r_inner_scaled)) # Closed

	# Inner hole top-arch 3D depth bevel lip (casts downward inside the hole)
	var inner_top_lip = PackedVector2Array()
	for i in range(1, n_arc / 2):
		var ang = 0.0 - (float(i) / float(n_arc / 2)) * (PI / 2.0)
		inner_top_lip.append(c_right_inner + Vector2(cos(ang), sin(ang)) * r_inner_scaled + Vector2(0, 3.5))
	inner_top_lip.append(Vector2(straight_x_inner, -r_inner_scaled + 3.5))
	inner_top_lip.append(Vector2(-straight_x_inner, -r_inner_scaled + 3.5))
	for i in range(1, n_arc / 2):
		var ang = -PI / 2.0 - (float(i) / float(n_arc / 2)) * (PI / 2.0)
		inner_top_lip.append(c_left_inner + Vector2(cos(ang), sin(ang)) * r_inner_scaled + Vector2(0, 3.5))

	# Inner hole top-arch shadow (casts downward onto green garden)
	var s_inner_top = PackedVector2Array()
	for i in range(1, n_arc / 2):
		var ang = -PI + (float(i) / float(n_arc / 2)) * (PI / 2.0)
		s_inner_top.append(c_left_inner + Vector2(cos(ang), sin(ang)) * r_inner_scaled + Vector2(0, 2.5))
	s_inner_top.append(Vector2(-straight_x_inner, -r_inner_scaled + 2.5))
	s_inner_top.append(Vector2(straight_x_inner, -r_inner_scaled + 2.5))
	for i in range(1, n_arc / 2):
		var ang = -PI / 2.0 + (float(i) / float(n_arc / 2)) * (PI / 2.0)
		s_inner_top.append(c_right_inner + Vector2(cos(ang), sin(ang)) * r_inner_scaled + Vector2(0, 2.5))

	# -----------------------------------------------------------------
	# 3. OUTER CURBS (Left side & Right side, with Gateway throat opening)
	# -----------------------------------------------------------------
	var steps_to_inner = max(1, int(abs(inner_meet_ang - (-PI / 2.0)) / (PI / float(n_arc))))

	# Left outer curb: from gateway throat (-x_gate, plat_y) up to (-x_gate, r_outer), then out to (-straight_x, r_outer), around to feeder inner
	var curb_left = PackedVector2Array()
	curb_left.append(Vector2(-x_gate, plat_y))
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

	# Right outer curb: from feeder outer down around right arc, through (straight_x, r_outer), into (x_gate, r_outer), down 90 deg to (x_gate, plat_y)
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
	curb_right.append(Vector2(x_gate, plat_y))

	# -----------------------------------------------------------------
	# 4. ROAD SURFACE POLYGONS (Top & Bottom halves, perfectly seamless)
	# -----------------------------------------------------------------
	# Top half polygon (y <= 0)
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

	if inner_meet_idx >= 0:
		top_poly.append(inner_meet_pt)
		for i in range(inner_meet_idx - 1, -1, -1):
			top_poly.append(f_inner[i])
		top_poly.append(f_outer[0])
		for i in range(1, outer_meet_idx):
			top_poly.append(f_outer[i])
		top_poly.append(outer_meet_pt)
	else:
		top_poly.append(Vector2(straight_x + r_outer, 0.0))

	# Midline transition across right road arm to right inner hole boundary
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

	# Bottom half polygon (y >= 0, includes connecting gateway throat into parking platform)
	var btm_poly = PackedVector2Array()
	if outer_meet_idx >= 0:
		btm_poly.append(outer_meet_pt)
	else:
		btm_poly.append(Vector2(straight_x + r_outer, 0.0))

	for i in range(1, steps_from_outer):
		var ang = outer_meet_ang + (float(i) / float(steps_from_outer)) * (PI / 2.0 - outer_meet_ang)
		btm_poly.append(c_right + Vector2(cos(ang), sin(ang)) * r_outer)
	btm_poly.append(Vector2(straight_x, r_outer))
	btm_poly.append(Vector2(x_gate, r_outer))
	btm_poly.append(Vector2(x_gate, plat_y + 4.0))
	btm_poly.append(Vector2(-x_gate, plat_y + 4.0))
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
	# 5. DRAWING PIPELINE
	# -----------------------------------------------------------------
	# Step A: Drop shadows onto background
	var shadow_offset = Vector2(0, 3)
	var s_left = PackedVector2Array()
	for pt in curb_left: s_left.append(pt + shadow_offset)
	var s_right = PackedVector2Array()
	for pt in curb_right: s_right.append(pt + shadow_offset)

	draw_polyline(s_left, COLOR_SHADOW, 5.0, true)
	draw_polyline(s_right, COLOR_SHADOW, 5.0, true)

	# Step B1: Green garden background in central opening (30% remaining area)
	draw_colored_polygon(curb_inner, COLOR_GARDEN)

	# Step B2: Unified grey road surface
	draw_colored_polygon(top_poly, COLOR_ROAD)
	draw_colored_polygon(btm_poly, COLOR_ROAD)

	# Step C: Inner hole 3D vertical depth bevel lip & soft shadow onto garden
	if s_inner_top.size() >= 2:
		draw_polyline(s_inner_top, Color(0.0, 0.0, 0.0, 0.12), 3.0, true)
	draw_polyline(inner_top_lip, Color("949ab1"), 4.5, true)

	# Step D: Curbs with bevel & crisp highlight (3.0px total appearance)
	draw_polyline(curb_left, COLOR_CURB_BEVEL, 3.5, true)
	draw_polyline(curb_left, COLOR_CURB_HIGHLIGHT, 2.0, true)

	draw_polyline(curb_right, COLOR_CURB_BEVEL, 3.5, true)
	draw_polyline(curb_right, COLOR_CURB_HIGHLIGHT, 2.0, true)

	draw_polyline(curb_inner, COLOR_CURB_BEVEL, 3.5, true)
	draw_polyline(curb_inner, COLOR_CURB_HIGHLIGHT, 2.0, true)
