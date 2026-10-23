class_name BusMotionPlan
extends RefCounted

## Deterministic Bus Motion Plan for Reference-Accurate Bus Release to Parking Flow.
## Computes exact geometric puzzle clearance from the trailing footprint extent along
## the authoritative forward direction, ensures 100% straight Stage A escape, and
## provides smooth outer perimeter routing to the reserved parking bay.

var vehicle_id: int = -1
var session_token: int = 0
var slot_id: int = -1

# Transforms and headings
var start_pos: Vector2 = Vector2.ZERO
var start_rot: float = 0.0
var start_scale: Vector2 = Vector2.ONE
var forward_direction: int = 0 # CarJamVehicleData.Direction
var forward_vector_board: Vector2 = Vector2.ZERO
var forward_vector_world: Vector2 = Vector2.ZERO
var front_native: Vector2 = Vector2(0, -1)

# Footprint and occupied geometry
var anchor: Vector2i = Vector2i.ZERO
var footprint: Array[Vector2i] = []
var occupied_cells: Array[Vector2i] = []
var swept_corridor: Array[Vector2i] = []

# Geometric clearance calculations
var trailing_extent_cells: float = 0.0
var clear_distance_cells: float = 0.0
var clear_distance_world: float = 0.0
var board_clear_point: Vector2 = Vector2.ZERO
var clear_t: float = 0.3

# Transit waypoints & parking approach
var transit_waypoints: Array[Vector2] = []
var approach_corridor_pos: Vector2 = Vector2.ZERO
var final_slot_pos: Vector2 = Vector2.ZERO
var final_slot_rot: float = 0.0
var final_rot_target: float = 0.0
var final_scale: Vector2 = Vector2.ONE

# Baked Bezier Spline
var curve: Curve2D = null
var total_curve_length: float = 0.0
var duration: float = 0.80

## Computes a deterministic, geometrically authoritative motion plan.
static func compute_motion_plan(
	v_id: int,
	v_token: int,
	s_id: int,
	v_start_pos: Vector2,
	v_start_rot: float,
	v_start_scale: Vector2,
	v_direction: int,
	v_anchor: Vector2i,
	v_footprint: Array[Vector2i],
	board_size: Vector2i,
	cell_size: float,
	board_transform: Transform2D,
	corridor_cells: Array[Vector2i],
	target_slot_pos: Vector2,
	target_slot_rot: float,
	target_scale: Vector2,
	viewport_safe_bounds: Rect2 = Rect2(-200.0, -600.0, 400.0, 1200.0),
	safety_margin_cells: float = 0.35,
	duration_mult: float = 1.0
) -> BusMotionPlan:
	var plan := BusMotionPlan.new()
	plan.vehicle_id = v_id
	plan.session_token = v_token
	plan.slot_id = s_id
	plan.start_pos = v_start_pos
	plan.start_rot = v_start_rot
	plan.start_scale = v_start_scale
	plan.forward_direction = v_direction
	plan.anchor = v_anchor
	plan.footprint = v_footprint
	plan.swept_corridor = corridor_cells
	plan.final_slot_pos = target_slot_pos
	plan.final_slot_rot = target_slot_rot
	plan.final_scale = target_scale
	plan.duration = 0.80 * duration_mult

	# 1. Native front vector and final rotation target
	match v_direction:
		CarJamVehicleData.Direction.DOWN:
			plan.front_native = Vector2(0, 1)
			plan.final_rot_target = PI + target_slot_rot
		CarJamVehicleData.Direction.UP:
			plan.front_native = Vector2(0, -1)
			plan.final_rot_target = 0.0 + target_slot_rot
		CarJamVehicleData.Direction.LEFT:
			plan.front_native = Vector2(-1, 0)
			plan.final_rot_target = PI / 2.0 + target_slot_rot
		CarJamVehicleData.Direction.RIGHT:
			plan.front_native = Vector2(1, 0)
			plan.final_rot_target = -PI / 2.0 + target_slot_rot

	# 2. Derive occupied cells
	plan.occupied_cells.clear()
	for offset in v_footprint:
		plan.occupied_cells.append(v_anchor + offset)
	if plan.occupied_cells.is_empty():
		plan.occupied_cells.append(v_anchor)

	# 3. Authoritative directional unit vectors
	var dir_grid: Vector2i = CarJamVehicleData.dir_to_vector(v_direction)
	plan.forward_vector_board = Vector2(dir_grid)
	var world_disp_unit: Vector2 = board_transform.basis_xform(Vector2(dir_grid))
	if world_disp_unit.length_squared() < 0.0001:
		world_disp_unit = Vector2(0, -1)
	plan.forward_vector_world = world_disp_unit.normalized()

	# 4. Compute trailing extent along forward direction
	# The bus is clear only when its trailing physical edge has crossed the board boundary.
	match v_direction:
		CarJamVehicleData.Direction.UP:
			var max_y: int = plan.occupied_cells[0].y
			for c in plan.occupied_cells:
				if c.y > max_y:
					max_y = c.y
			plan.trailing_extent_cells = float(max_y)
			plan.clear_distance_cells = (plan.trailing_extent_cells + 1.0) + safety_margin_cells
		CarJamVehicleData.Direction.DOWN:
			var min_y: int = plan.occupied_cells[0].y
			for c in plan.occupied_cells:
				if c.y < min_y:
					min_y = c.y
			plan.trailing_extent_cells = float(min_y)
			plan.clear_distance_cells = (float(board_size.y) - plan.trailing_extent_cells) + safety_margin_cells
		CarJamVehicleData.Direction.LEFT:
			var max_x: int = plan.occupied_cells[0].x
			for c in plan.occupied_cells:
				if c.x > max_x:
					max_x = c.x
			plan.trailing_extent_cells = float(max_x)
			plan.clear_distance_cells = (plan.trailing_extent_cells + 1.0) + safety_margin_cells
		CarJamVehicleData.Direction.RIGHT:
			var min_x: int = plan.occupied_cells[0].x
			for c in plan.occupied_cells:
				if c.x < min_x:
					min_x = c.x
			plan.trailing_extent_cells = float(min_x)
			plan.clear_distance_cells = (float(board_size.x) - plan.trailing_extent_cells) + safety_margin_cells

	# 5. Transform board clearance vector into world space
	var disp_local := Vector2(dir_grid) * (plan.clear_distance_cells * cell_size)
	var disp_world := board_transform.basis_xform(disp_local)
	plan.board_clear_point = v_start_pos + disp_world
	plan.clear_distance_world = disp_world.length()

	# 6. Approach corridor waypoint (directly along bay entry axis)
	var approach_offset := Vector2(0.0, ParkingSlotView.SLOT_HEIGHT + 16.0).rotated(target_slot_rot)
	plan.approach_corridor_pos = target_slot_pos + approach_offset

	# 7. Construct transit waypoints
	var pts: Array[Vector2] = []
	pts.append(v_start_pos)
	pts.append(plan.board_clear_point)

	var safe_min_x: float = viewport_safe_bounds.position.x
	var safe_max_x: float = viewport_safe_bounds.position.x + viewport_safe_bounds.size.x
	var safe_min_y: float = viewport_safe_bounds.position.y
	var safe_max_y: float = viewport_safe_bounds.position.y + viewport_safe_bounds.size.y

	# Symmetrical perimeter highways around puzzle board
	var hw_left_x: float = safe_min_x + 42.0
	var hw_right_x: float = safe_max_x - 42.0
	var road_y: float = plan.approach_corridor_pos.y
	var bottom_y: float = clampf(plan.board_clear_point.y + 40.0, plan.board_clear_point.y + 20.0, safe_max_y - 25.0)

	var fwd := plan.forward_vector_world
	if fwd.y < -0.2 and absf(fwd.y) >= absf(fwd.x):
		# Exiting UP towards parking: curve directly to approach corridor
		pts.append(plan.approach_corridor_pos)
	elif fwd.x > 0.2 and absf(fwd.x) >= absf(fwd.y):
		# Exiting RIGHT: follow right clearance highway up to roadway
		var right_x: float = clampf(plan.board_clear_point.x, hw_right_x, safe_max_x - 20.0)
		pts.append(Vector2(right_x, plan.board_clear_point.y))
		pts.append(Vector2(right_x, road_y))
		pts.append(plan.approach_corridor_pos)
	elif fwd.x < -0.2 and absf(fwd.x) >= absf(fwd.y):
		# Exiting LEFT: follow left clearance highway up to roadway
		var left_x: float = clampf(plan.board_clear_point.x, safe_min_x + 20.0, hw_left_x)
		pts.append(Vector2(left_x, plan.board_clear_point.y))
		pts.append(Vector2(left_x, road_y))
		pts.append(plan.approach_corridor_pos)
	elif fwd.y > 0.2:
		# Exiting DOWN: route around bottom corner towards the side of its exit
		var side_x: float = hw_left_x if plan.board_clear_point.x <= 0.0 else hw_right_x
		pts.append(Vector2(plan.board_clear_point.x, bottom_y))
		pts.append(Vector2(side_x, bottom_y))
		pts.append(Vector2(side_x, road_y))
		pts.append(plan.approach_corridor_pos)
	else:
		var side_x: float = hw_left_x if plan.board_clear_point.x <= 0.0 else hw_right_x
		pts.append(Vector2(side_x, plan.board_clear_point.y))
		pts.append(Vector2(side_x, road_y))
		pts.append(plan.approach_corridor_pos)

	pts.append(target_slot_pos)
	plan.transit_waypoints = pts

	# 8. Build baked Bezier Curve2D with 100% straight Stage A escape
	plan.curve = Curve2D.new()
	var exit_seg_len: float = v_start_pos.distance_to(plan.board_clear_point)
	var in_tangent := Vector2(0.0, 32.0).rotated(target_slot_rot)

	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		var in_tan := Vector2.ZERO
		var out_tan := Vector2.ZERO
		if i == 0:
			# Stage A Start: strictly along forward_vector_world
			out_tan = plan.forward_vector_world * (exit_seg_len * 0.4)
		elif i == 1:
			# Stage A End: in_tan strictly collinear with forward_vector_world ensures 100% straight line
			in_tan = -plan.forward_vector_world * (exit_seg_len * 0.4)
			if pts.size() > 2:
				var next_d := (pts[2] - pts[1]).normalized()
				out_tan = next_d * minf(50.0, pts[1].distance_to(pts[2]) * 0.35)
		elif i == pts.size() - 1:
			in_tan = in_tangent
		else:
			var prev_p: Vector2 = pts[i - 1]
			var next_p: Vector2 = pts[i + 1]
			var seg_d: Vector2 = (next_p - prev_p).normalized() * minf(50.0, prev_p.distance_to(p) * 0.35)
			in_tan = -seg_d
			out_tan = seg_d
		plan.curve.add_point(p, in_tan, out_tan)

	# 9. Compute baked length and clearance progress fraction clear_t
	plan.total_curve_length = plan.curve.get_baked_length()
	var stage_a_offset: float = plan.curve.get_closest_offset(plan.board_clear_point)
	if plan.total_curve_length > 0.0:
		plan.clear_t = clampf(stage_a_offset / plan.total_curve_length, 0.05, 0.85)
	else:
		plan.clear_t = 0.3

	return plan

## Oriented Bounding Box for exact 2D continuous collision checking (SAT theorem).
class BusOBB extends RefCounted:
	var center: Vector2 = Vector2.ZERO
	var axis_fwd: Vector2 = Vector2(0, -1)
	var axis_lat: Vector2 = Vector2(1, 0)
	var half_length: float = 43.5
	var half_width: float = 20.5

	static func create(pos: Vector2, rot: float, front_native: Vector2, hl: float, hw: float, margin: float = 0.0) -> BusOBB:
		var obb := BusOBB.new()
		obb.center = pos
		obb.half_length = hl + margin
		obb.half_width = hw + margin
		obb.axis_fwd = front_native.rotated(rot).normalized()
		obb.axis_lat = Vector2(-obb.axis_fwd.y, obb.axis_fwd.x)
		return obb

	static func from_view_in_world(v: Node2D, world_node: Node2D, margin: float = 0.0) -> BusOBB:
		var obb := BusOBB.new()
		obb.center = world_node.to_local(v.global_position) if world_node != null else v.position
		var rot: float = v.global_rotation - (world_node.global_rotation if world_node != null else 0.0)
		var v_dir: int = v.get("vehicle_dir") if v.get("vehicle_dir") != null else CarJamVehicleData.Direction.UP
		var front_native := Vector2(0, -1)
		match v_dir:
			CarJamVehicleData.Direction.DOWN: front_native = Vector2(0, 1)
			CarJamVehicleData.Direction.UP: front_native = Vector2(0, -1)
			CarJamVehicleData.Direction.LEFT: front_native = Vector2(-1, 0)
			CarJamVehicleData.Direction.RIGHT: front_native = Vector2(1, 0)
		
		var s: Vector2 = v.scale
		obb.half_length = (102.0 * s.y * 0.5) + margin
		obb.half_width = (48.0 * s.x * 0.5) + margin
		obb.axis_fwd = front_native.rotated(rot).normalized()
		obb.axis_lat = Vector2(-obb.axis_fwd.y, obb.axis_fwd.x)
		return obb

	static func from_node(v: Node2D, margin: float = 0.0) -> BusOBB:
		var obb := BusOBB.new()
		obb.center = v.position
		var rot: float = v.rotation
		var v_dir: int = v.get("vehicle_dir") if v.get("vehicle_dir") != null else CarJamVehicleData.Direction.UP
		var front_native := Vector2(0, -1)
		match v_dir:
			CarJamVehicleData.Direction.DOWN: front_native = Vector2(0, 1)
			CarJamVehicleData.Direction.UP: front_native = Vector2(0, -1)
			CarJamVehicleData.Direction.LEFT: front_native = Vector2(-1, 0)
			CarJamVehicleData.Direction.RIGHT: front_native = Vector2(1, 0)
		
		var s: Vector2 = v.scale
		obb.half_length = (102.0 * s.y * 0.5) + margin
		obb.half_width = (48.0 * s.x * 0.5) + margin
		obb.axis_fwd = front_native.rotated(rot).normalized()
		obb.axis_lat = Vector2(-obb.axis_fwd.y, obb.axis_fwd.x)
		return obb

	func intersects(other: BusOBB) -> bool:
		var d := other.center - center
		var axes := [axis_fwd, axis_lat, other.axis_fwd, other.axis_lat]
		for a in axes:
			var r_a := half_length * absf(axis_fwd.dot(a)) + half_width * absf(axis_lat.dot(a))
			var r_b := other.half_length * absf(other.axis_fwd.dot(a)) + other.half_width * absf(other.axis_lat.dot(a))
			if absf(d.dot(a)) > (r_a + r_b):
				return false
		return true

	func distance_to_center(other: BusOBB) -> float:
		return center.distance_to(other.center)

