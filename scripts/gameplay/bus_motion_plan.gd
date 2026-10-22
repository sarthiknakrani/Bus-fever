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

	# Perimeter highway around puzzle board if exiting downwards or sideways
	if plan.forward_vector_world.y > 0.2:
		# Exiting DOWN: route around bottom corner towards target slot side
		var bottom_y: float = clampf(plan.board_clear_point.y + 40.0, plan.board_clear_point.y, safe_max_y - 20.0)
		var side_x: float = (safe_min_x + 38.0) if target_slot_pos.x <= 0.0 else (safe_max_x - 38.0)
		pts.append(Vector2(plan.board_clear_point.x, bottom_y))
		pts.append(Vector2(side_x, bottom_y))
		pts.append(Vector2(side_x, plan.approach_corridor_pos.y))
	elif plan.forward_vector_world.x < -0.2:
		# Exiting LEFT: follow left highway up to corridor
		var side_x: float = clampf(minf(plan.board_clear_point.x - 20.0, -180.0), safe_min_x + 38.0, -80.0)
		pts.append(Vector2(side_x, plan.board_clear_point.y))
		pts.append(Vector2(side_x, plan.approach_corridor_pos.y))
	elif plan.forward_vector_world.x > 0.2:
		# Exiting RIGHT: follow right highway up to corridor
		var side_x: float = clampf(maxf(plan.board_clear_point.x + 20.0, 180.0), 80.0, safe_max_x - 38.0)
		pts.append(Vector2(side_x, plan.board_clear_point.y))
		pts.append(Vector2(side_x, plan.approach_corridor_pos.y))

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
