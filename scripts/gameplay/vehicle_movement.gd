extends RefCounted
class_name VehicleMovement

## Handles smooth 2D visual tweening for vehicle dispatch and departure.
## Separated from authoritative simulation logic for clean restart safety and testability.

static func animate_dispatch(
	vehicle_node: Node2D,
	start_pos: Vector2,
	_legacy_exit_pos: Vector2,
	corridor_pos: Vector2,
	slot_pos: Vector2,
	token: int,
	controller: Node,
	vehicle_id: int,
	slot_id: int,
	target_scale: Vector2,
	duration_mult: float = 1.0
) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return

	vehicle_node.z_index = 100 + slot_id

	# -----------------------------------------------------------------
	# BOARD-TO-PARKING DRIVING SEQUENCE
	#
	# Stage A: Drive STRAIGHT along the puzzle arrow direction (in world
	#          space, after the board's 45-deg rotation) to clear the
	#          puzzle footprint. Front follows forward direction.
	# Stage B: Curve through the explicit corridor waypoint, sitting
	#          BELOW the parking strip, until the bus is directly under
	#          its target slot. The turn is gradual, not a snap.
	# Stage C: From the corridor waypoint, drive STRAIGHT VERTICALLY UP
	#          into the bay. Front faces passengers.
	# Stage D: Settle exactly on slot_pos, no further rotation.
	#
	# Implemented as a 4-point Curve2D driven by a single tween_method
	# that updates BOTH position and rotation. No competing tweens, no
	# forced rotation blend — the curve geometry itself produces three
	# distinct phases (drive, turn, dock) with smooth tangents between
	# them.
	# -----------------------------------------------------------------
	var tw := vehicle_node.create_tween()

	# Puzzle-arrow direction expressed in world space (after the
	# 45-degree board rotation + 0.6 Y-scale). This is the direction
	# the bus drives along in Stage A. Passed in by the caller as
	# _legacy_exit_pos so this static function never depends on
	# board_root transform.
	var forward_world: Vector2 = (_legacy_exit_pos - start_pos)
	if forward_world.length_squared() < 0.0001:
		forward_world = Vector2(0, -1)
	forward_world = forward_world.normalized()

	# -------------------------------------------------------------------------
	# 4-point cubic Bézier chain:
	#
	#   P0 = bus on the board (start)
	#   P1 = 130 px ALONG the puzzle arrow past P0 (Stage A exit)
	#   P2 = corridor waypoint, BELOW the parking strip and under slot
	#   P3 = slot center (final destination, tangent = vertical UP)
	#
	# Tangent strategy:
	#   - Segment P0 -> P1: both endpoints tangent to forward_world so
	#     this segment is essentially a straight line along the puzzle
	#     arrow (bus drives the way the puzzle intended).
	#   - Segment P1 -> P2: enter at forward_world, leave at forward_world
	#     so the bus continues straight until the corridor. Tangent
	#     transition to vertical happens in segment P2 -> P3.
	#   - Segment P2 -> P3: enter at vertical UP, leave at vertical UP
	#     so this segment is a straight vertical dock into the bay.
	# -------------------------------------------------------------------------
	var P1: Vector2 = start_pos + forward_world * 130.0
	# corridor_pos is the waypoint supplied by the caller; if it is too
	# close to start_pos (degenerate), fall back to a synthetic corridor.
	var P2: Vector2 = corridor_pos
	if P2.distance_to(start_pos) < 80.0:
		# Caller did not supply a corridor we trust — synthesize one
		# directly under the slot, well clear of the parking rect.
		P2 = Vector2(slot_pos.x, slot_pos.y + 100.0)

	var curve := Curve2D.new()
	# P0 - bus on the board; out tangent = puzzle direction.
	curve.add_point(start_pos, Vector2.ZERO, forward_world * 120.0)
	# P1 - driven-out waypoint; smooth continuation of puzzle direction.
	curve.add_point(P1, -forward_world * 100.0, forward_world * 100.0)
	# P2 - corridor below parking strip; in tangent = vertical UP, out
	# tangent = vertical UP, so segment P2->P3 is straight.
	curve.add_point(P2, Vector2(0.0, 100.0), Vector2(0.0, -100.0))
	# P3 - slot center; in tangent = vertical UP, so the bus enters the
	# bay driving straight up with its front facing passengers.
	curve.add_point(slot_pos, Vector2(0.0, 130.0), Vector2.ZERO)

	# Derive front vector (the bus sprite's "front" in its NATIVE puzzle orientation).
	var front_native := Vector2(0, -1)
	match vehicle_node.vehicle_dir:
		CarJamVehicleData.Direction.DOWN: front_native = Vector2(0, 1)
		CarJamVehicleData.Direction.UP: front_native = Vector2(0, -1)
		CarJamVehicleData.Direction.LEFT: front_native = Vector2(-1, 0)
		CarJamVehicleData.Direction.RIGHT: front_native = Vector2(1, 0)

	# Final rotation the bus should be in when parked vertical-front-UP.
	# When the tangent at curve end is (0, -1), the rotation that aligns
	# front_native onto (0, -1) is exactly this:
	var final_rot_target := 0.0
	match vehicle_node.vehicle_dir:
		CarJamVehicleData.Direction.DOWN: final_rot_target = PI
		CarJamVehicleData.Direction.UP: final_rot_target = 0.0
		CarJamVehicleData.Direction.LEFT: final_rot_target = PI / 2.0
		CarJamVehicleData.Direction.RIGHT: final_rot_target = -PI / 2.0

	var start_scale: Vector2 = vehicle_node.scale
	var duration: float = 1.55 * duration_mult

	var curve_callable := Callable(
		VehicleMovement, "_update_curve"
	).bind(
		curve,
		vehicle_node,
		target_scale,
		start_scale,
		true,            # drive_forward
		front_native,
		false,           # force_final_rot  (curve geometry handles this)
		final_rot_target
	)
	tw.tween_method(curve_callable, 0.0, 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var lambda_func := func(v_node, t_scale, ctrl, v_id, s_id, tok):
		if is_instance_valid(v_node):
			v_node.set_parking_mode(true)

			# QA arrival check
			var dir_str: String = CarJamVehicleData.dir_to_string(v_node.vehicle_dir)
			var front_vec: Vector2 = front_native.rotated(v_node.rotation)
			var bay_axis: Vector2 = Vector2(0, -1)
			var ang_diff: float = rad_to_deg(front_vec.angle_to(bay_axis))
			var center_err: float = v_node.global_position.distance_to(slot_pos)

			print("[QA] ARRIVAL | Bus %d (Orig Dir: %s) -> Slot %d" %
				[v_id, dir_str, s_id])
			print("      | Front: (%.2f, %.2f) | BayAxis: (0,-1)" %
				[front_vec.x, front_vec.y])
			print("      | Angular err: %.1f deg | Center err: %.1f px" %
				[ang_diff, center_err])

			v_node.z_index = 10
			# Settle bounce — ONLY touches scale. Position and rotation
			# must remain frozen at slot_pos / final_rot_target from here on.
			var settle_tw: Tween = v_node.create_tween()
			settle_tw.tween_property(v_node, "scale", t_scale * 1.05, 0.12) \
				.set_trans(Tween.TRANS_SINE)
			settle_tw.tween_property(v_node, "scale", t_scale, 0.18) \
				.set_trans(Tween.TRANS_BOUNCE)
			# Snap rotation to target so it never drifts from frame
			# quantization noise during the settle.
			v_node.rotation = final_rot_target
		ctrl.on_vehicle_arrived_at_slot(v_id, s_id, tok)

	tw.tween_callback(lambda_func.bind(
		vehicle_node, target_scale, controller, vehicle_id, slot_id, token
	))


static func animate_departure(
	vehicle_node: Node2D,
	slot_pos: Vector2,
	token: int,
	controller: Node,
	vehicle_id: int,
	slot_id: int,
	duration_mult: float = 1.0
) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return

	vehicle_node.set_parking_mode(false)
	vehicle_node.z_index = 200 # Ensure it renders above other elements while exiting
	
	print("[QA %d] Bus %d reverse started." % [Time.get_ticks_msec(), vehicle_id])
	
	var dep = VehicleDepartureController.new()
	dep.vehicle = vehicle_node
	dep.controller = controller
	dep.vehicle_id = vehicle_id
	dep.slot_id = slot_id
	dep.token = token
	dep.slot_pos = slot_pos
	dep.reverse_target_y = slot_pos.y + 195.0
	
	var curve = Curve2D.new()
	var vp_rect = vehicle_node.get_viewport_rect()
	var global_right_x = (vp_rect.size.x / 2.0) + 400.0 
	var exit_global = Vector2(global_right_x, 0)
	var exit_local = vehicle_node.get_parent().get_global_transform().affine_inverse() * exit_global
	
	var final_target = Vector2(exit_local.x, dep.reverse_target_y - 15.0)
	var start_pos = Vector2(slot_pos.x, dep.reverse_target_y)
	
	curve.add_point(start_pos, Vector2.ZERO, Vector2(0, -60.0))
	curve.add_point(final_target, Vector2(-160.0, 0), Vector2.ZERO)
	
	dep.curve = curve
	dep.curve_len = curve.get_baked_length()
	
	var front_native = Vector2(0, -1)
	match vehicle_node.vehicle_dir:
		CarJamVehicleData.Direction.DOWN: front_native = Vector2(0, 1)
		CarJamVehicleData.Direction.UP: front_native = Vector2(0, -1)
		CarJamVehicleData.Direction.LEFT: front_native = Vector2(-1, 0)
		CarJamVehicleData.Direction.RIGHT: front_native = Vector2(1, 0)
	dep.front_native = front_native
	
	vehicle_node.add_child(dep)

static func _update_curve(t: float, curve: Curve2D, v_node: Node2D, target_scale: Vector2, start_scale: Vector2, drive_forward: bool, front_native: Vector2, _force_final_rot: bool = false, _final_rot_target: float = 0.0) -> void:
	if not is_instance_valid(v_node): return
	var total_len = curve.get_baked_length()
	var offset = t * total_len
	var pos = curve.sample_baked(offset)
	v_node.position = pos

	# Sample slightly ahead for tangent-based rotation
	var offset_ahead = min(total_len, offset + 2.0)
	var pos_ahead = curve.sample_baked(offset_ahead)

	if pos.distance_to(pos_ahead) > 0.1:
		var dir = (pos_ahead - pos).normalized()
		if not drive_forward:
			dir = -dir
		v_node.rotation = dir.angle() - front_native.angle()

	v_node.scale = start_scale.lerp(target_scale, t)
