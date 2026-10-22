class_name BusCollisionGeometry
extends RefCounted

## Separating Axis Theorem (SAT) & Geometric Collision Engine for Oriented Buses.
## Provides exact physical collision detection for rotated rectangular vehicles,
## configurable clearance spacing, swept escape corridors, and convex polygon checks.

## Canonical bus visual and collision dimensions (pixels)
const DEFAULT_BUS_LENGTH: float = 86.0  # Longitudinal extent (along heading)
const DEFAULT_BUS_WIDTH: float = 42.0   # Transverse extent (across heading)
const DEFAULT_MIN_CLEARANCE: float = 5.0 # Minimum physical gap between adjacent buses

## Returns the 4 ordered vertices of an oriented bounding box (OBB).
static func get_obb_vertices(pos: Vector2, heading_rad: float, length: float, width: float, margin: float = 0.0) -> PackedVector2Array:
	var half_l := (length * 0.5) + margin
	var half_w := (width * 0.5) + margin
	var forward := Vector2(cos(heading_rad), sin(heading_rad))
	var right := Vector2(-forward.y, forward.x)

	var v0 := pos + (forward * half_l) - (right * half_w) # Front-Left
	var v1 := pos + (forward * half_l) + (right * half_w) # Front-Right
	var v2 := pos - (forward * half_l) + (right * half_w) # Rear-Right
	var v3 := pos - (forward * half_l) - (right * half_w) # Rear-Left

	return PackedVector2Array([v0, v1, v2, v3])

## Tests if two oriented bounding boxes overlap or violate minimum clearance using 2D SAT.
static func test_obb_overlap(
	pos_a: Vector2, rot_a: float, len_a: float, width_a: float,
	pos_b: Vector2, rot_b: float, len_b: float, width_b: float,
	clearance: float = 0.0
) -> bool:
	var axes_a := [
		Vector2(cos(rot_a), sin(rot_a)),
		Vector2(-sin(rot_a), cos(rot_a))
	]
	var axes_b := [
		Vector2(cos(rot_b), sin(rot_b)),
		Vector2(-sin(rot_b), cos(rot_b))
	]

	var all_axes := [axes_a[0], axes_a[1], axes_b[0], axes_b[1]]
	var delta := pos_b - pos_a

	for axis in all_axes:
		var u: Vector2 = axis.normalized()
		# Radius A
		var r_a: float = absf(u.dot(axes_a[0])) * (len_a * 0.5) + absf(u.dot(axes_a[1])) * (width_a * 0.5)
		# Radius B
		var r_b: float = absf(u.dot(axes_b[0])) * (len_b * 0.5) + absf(u.dot(axes_b[1])) * (width_b * 0.5)
		# Distance along axis
		var dist: float = absf(delta.dot(u))

		if dist > (r_a + r_b + clearance):
			# Separating axis found: NO overlap!
			return false

	# No separating axis exists: Overlap detected!
	return true

## Tests if two convex polygons overlap using SAT.
static func test_polygon_overlap(poly_a: PackedVector2Array, poly_b: PackedVector2Array, clearance: float = 0.0) -> bool:
	if poly_a.size() < 3 or poly_b.size() < 3:
		return false

	var polys: Array[PackedVector2Array] = [poly_a, poly_b]
	for poly in polys:
		var count: int = poly.size()
		for i in range(count):
			var p1: Vector2 = poly[i]
			var p2: Vector2 = poly[(i + 1) % count]
			var edge: Vector2 = p2 - p1
			if edge.length_squared() < 0.0001:
				continue
			var normal := Vector2(-edge.y, edge.x).normalized()

			# Project poly_a
			var min_a := INF
			var max_a := -INF
			for pt in poly_a:
				var proj := pt.dot(normal)
				min_a = minf(min_a, proj)
				max_a = maxf(max_a, proj)

			# Project poly_b
			var min_b := INF
			var max_b := -INF
			for pt in poly_b:
				var proj := pt.dot(normal)
				min_b = minf(min_b, proj)
				max_b = maxf(max_b, proj)

			if (min_a > max_b + clearance) or (min_b > max_a + clearance):
				return false

	return true

## Computes the swept convex polygon of a bus moving along its escape vector.
static func compute_swept_polygon(
	start_pos: Vector2,
	heading_rad: float,
	length: float,
	width: float,
	escape_dir: Vector2,
	escape_distance: float
) -> PackedVector2Array:
	var v_start := get_obb_vertices(start_pos, heading_rad, length, width)
	var end_pos := start_pos + (escape_dir.normalized() * escape_distance)
	var v_end := get_obb_vertices(end_pos, heading_rad, length, width)

	var all_pts: PackedVector2Array = []
	all_pts.append_array(v_start)
	all_pts.append_array(v_end)

	return Geometry2D.convex_hull(all_pts)

## Checks whether a candidate position is strictly inside a playable boundary polygon.
static func is_obb_inside_bounds(
	pos: Vector2, heading_rad: float, length: float, width: float,
	boundary_poly: PackedVector2Array
) -> bool:
	if boundary_poly.size() < 3:
		return true

	var vertices := get_obb_vertices(pos, heading_rad, length, width)
	for v in vertices:
		if not Geometry2D.is_point_in_polygon(v, boundary_poly):
			return false
	return true
