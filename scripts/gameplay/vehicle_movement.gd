extends RefCounted
class_name VehicleMovement

## Centrally defined animation timing constants (seconds)
const BUS_ARRIVAL_DURATION: float = 0.80
const BUS_DEPARTURE_DURATION: float = 0.80
const TARGET_PASSENGER_BOARDING_RATE: float = 30.0

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
	duration_mult: float = 1.0,
	slot_rotation: float = 0.0
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
	# Stage C: From the corridor waypoint, drive into the bay along its
	#          aligned parking axis (matching slot_rotation).
	# Stage D: Settle exactly on slot_pos with final rotation matching slot.
	# -----------------------------------------------------------------
	var tw := vehicle_node.create_tween()

	# -------------------------------------------------------------------------
	# BOARD-TO-PARKING ROUTING (Zero-Overlap Perimeter Clearance)
	#
	# Stage A: Drive along puzzle arrow to clear the board footprint.
	# Stage B: If exiting to the side or down, follow outer perimeter corridor
	#          around the board so the bus NEVER cuts across other buses.
	# Stage C: Enter top approach corridor below the assigned parking bay.
	# Stage D: Settle exactly on slot_pos with final rotation matching slot.
	# -------------------------------------------------------------------------
	var forward_world: Vector2 = (_legacy_exit_pos - start_pos)
	if forward_world.length_squared() < 0.0001:
		forward_world = Vector2(0, -1)
	forward_world = forward_world.normalized()

	var exit_dist: float = start_pos.distance_to(_legacy_exit_pos)
	var exit_point: Vector2 = _legacy_exit_pos if exit_dist >= 40.0 else start_pos + forward_world * 140.0

	# Keep strictly inside screen frame (zero out-of-bounds driving):
	# Board buses occupy X in [-100, 100], Y in [560, 810].
	# Bypass at X = -165.0 / +165.0 clears all board buses while staying 100% inside frame.
	var half_frame_w: float = 175.0
	var vp = vehicle_node.get_viewport()
	if vp != null:
		var v_size = vp.get_visible_rect().size
		if v_size.x > 100.0:
			half_frame_w = maxf(160.0, v_size.x * 0.5 - 32.0)

	var BYPASS_LEFT_X: float = -half_frame_w
	var BYPASS_RIGHT_X: float = half_frame_w
	var BYPASS_BOTTOM_Y: float = 855.0
	var CORRIDOR_TOP_Y: float = corridor_pos.y

	var pts: Array[Vector2] = []
	pts.append(start_pos)
	pts.append(exit_point)

	if exit_point.y > 540.0:
		# Exited to side or bottom; navigate around board perimeter
		if forward_world.y > 0.4 or exit_point.y >= 880.0:
			# Exited DOWN: turn around bottom corner towards target slot side
			var side_x = BYPASS_LEFT_X if slot_pos.x <= 0.0 else BYPASS_RIGHT_X
			pts.append(Vector2(exit_point.x, maxf(exit_point.y, BYPASS_BOTTOM_Y)))
			pts.append(Vector2(side_x, maxf(exit_point.y, BYPASS_BOTTOM_Y)))
			pts.append(Vector2(side_x, CORRIDOR_TOP_Y))
		elif forward_world.x < -0.1 or exit_point.x <= 0.0:
			# Exited LEFT: follow left highway up to top corridor
			pts.append(Vector2(minf(exit_point.x, BYPASS_LEFT_X), exit_point.y))
			pts.append(Vector2(minf(exit_point.x, BYPASS_LEFT_X), CORRIDOR_TOP_Y))
		else:
			# Exited RIGHT: follow right highway up to top corridor
			pts.append(Vector2(maxf(exit_point.x, BYPASS_RIGHT_X), exit_point.y))
			pts.append(Vector2(maxf(exit_point.x, BYPASS_RIGHT_X), CORRIDOR_TOP_Y))

	pts.append(corridor_pos)
	pts.append(slot_pos)

	var in_tangent := Vector2(0.0, 32.0).rotated(slot_rotation)
	var curve := Curve2D.new()
	for i in range(pts.size()):
		var p = pts[i]
		var in_tan = Vector2.ZERO
		var out_tan = Vector2.ZERO
		if i == 0:
			out_tan = forward_world * 80.0
		elif i == pts.size() - 1:
			in_tan = in_tangent
		else:
			var prev_p = pts[i - 1]
			var next_p = pts[i + 1]
			var seg_d = (next_p - prev_p).normalized() * minf(50.0, prev_p.distance_to(p) * 0.35)
			in_tan = -seg_d
			out_tan = seg_d
		curve.add_point(p, in_tan, out_tan)

	# Derive front vector (the bus sprite's "front" in its NATIVE puzzle orientation).
	var v_dir: int = vehicle_node.get("vehicle_dir") if vehicle_node.get("vehicle_dir") != null else CarJamVehicleData.Direction.UP
	var front_native := Vector2(0, -1)
	match v_dir:
		CarJamVehicleData.Direction.DOWN: front_native = Vector2(0, 1)
		CarJamVehicleData.Direction.UP: front_native = Vector2(0, -1)
		CarJamVehicleData.Direction.LEFT: front_native = Vector2(-1, 0)
		CarJamVehicleData.Direction.RIGHT: front_native = Vector2(1, 0)

	# Final rotation the bus should be in when parked aligned with slot_rotation.
	var final_rot_target := slot_rotation
	match v_dir:
		CarJamVehicleData.Direction.DOWN: final_rot_target = PI + slot_rotation
		CarJamVehicleData.Direction.UP: final_rot_target = 0.0 + slot_rotation
		CarJamVehicleData.Direction.LEFT: final_rot_target = PI / 2.0 + slot_rotation
		CarJamVehicleData.Direction.RIGHT: final_rot_target = -PI / 2.0 + slot_rotation

	var start_scale: Vector2 = vehicle_node.scale
	var duration: float = BUS_ARRIVAL_DURATION * duration_mult
	var t_dispatch_start: float = Time.get_ticks_msec() / 1000.0
	print("[QA] Bus %d ARRIVAL START at %.3f (Target: %.2fs)" % [vehicle_id, t_dispatch_start, duration])

	var curve_callable := Callable(
		VehicleMovement, "_update_curve"
	).bind(
		curve,
		vehicle_node,
		target_scale,
		start_scale,
		true,            # drive_forward
		front_native,
		true,            # force_final_rot
		final_rot_target
	)
	tw.tween_method(curve_callable, 0.0, 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Smoothly transition _base_sprite from board anchor offset & board scale to centered parking
	if vehicle_node.get("_base_sprite") != null and vehicle_node._base_sprite != null:
		var spr: Sprite2D = vehicle_node._base_sprite
		var tw_spr := vehicle_node.create_tween()
		tw_spr.set_parallel(true)
		tw_spr.tween_property(spr, "position", Vector2.ZERO, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_spr.tween_property(spr, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


	var lambda_func := func(v_node, t_scale, ctrl, v_id, s_id, tok, t_start_sec):
		var t_arrival_end: float = Time.get_ticks_msec() / 1000.0
		print("[QA] Bus %d ARRIVAL COMPLETE at %.3f (Actual: %.3fs | Target: %.2fs)" % [
			v_id, t_arrival_end, t_arrival_end - t_start_sec, BUS_ARRIVAL_DURATION * duration_mult
		])
		if is_instance_valid(v_node):
			if v_node.has_method("set_parking_mode"):
				v_node.set_parking_mode(true)

			# QA arrival check
			var dir_str: String = CarJamVehicleData.dir_to_string(v_dir)
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
			v_node.rotation = final_rot_target
			v_node.position = slot_pos
			v_node.scale = t_scale
			if v_node.get("_base_sprite") != null and v_node._base_sprite != null:
				v_node._base_sprite.position = Vector2.ZERO
				v_node._base_sprite.scale = Vector2.ONE
		ctrl.on_vehicle_arrived_at_slot(v_id, s_id, tok)

	tw.tween_callback(lambda_func.bind(
		vehicle_node, target_scale, controller, vehicle_id, slot_id, token, t_dispatch_start
	))


static func animate_departure(
	vehicle_node: Node2D,
	slot_pos: Vector2,
	token: int,
	controller: Node,
	vehicle_id: int,
	slot_id: int,
	duration_mult: float = 1.0,
	slot_rotation: float = 0.0,
	target_road_y: float = 0.0
) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return

	if vehicle_node.has_method("set_parking_mode"):
		vehicle_node.set_parking_mode(false)
	vehicle_node.z_index = 200 # Ensure it renders above parking slots and grey platform apron

	var t_dep_start: float = Time.get_ticks_msec() / 1000.0
	var total_duration: float = BUS_DEPARTURE_DURATION * duration_mult
	print("[QA] Bus %d DEPARTURE START at %.3f (Target: %.2fs)" % [vehicle_id, t_dep_start, total_duration])

	# 1. Native orientation
	var v_dir: int = vehicle_node.get("vehicle_dir") if vehicle_node.get("vehicle_dir") != null else CarJamVehicleData.Direction.UP
	var front_native := Vector2(0, -1)
	match v_dir:
		CarJamVehicleData.Direction.DOWN: front_native = Vector2(0, 1)
		CarJamVehicleData.Direction.UP: front_native = Vector2(0, -1)
		CarJamVehicleData.Direction.LEFT: front_native = Vector2(-1, 0)
		CarJamVehicleData.Direction.RIGHT: front_native = Vector2(1, 0)

	var start_pos: Vector2 = vehicle_node.position
	# Fallback if slot_pos is provided and vehicle was not yet positioned
	if start_pos.distance_squared_to(Vector2.ZERO) < 1.0 and slot_pos.length_squared() > 1.0:
		start_pos = slot_pos
		vehicle_node.position = slot_pos

	var parked_rot: float = vehicle_node.rotation
	# When driving forward along the grey road towards screen-right (+X):
	var rot_target: float = Vector2(1.0, 0.0).angle() - front_native.angle()

	var bay_reverse: Vector2 = Vector2(0.0, 1.0).rotated(slot_rotation)

	# Determine grey road centerline Y
	var road_y: float = target_road_y
	if is_zero_approx(road_y):
		road_y = start_pos.y + 110.0

	# Reverse position: bus moves straight backward along the bay's longitudinal axis
	# until its center sits cleanly on the grey roadway centerline
	var dy: float = road_y - start_pos.y
	var cos_rot: float = cos(slot_rotation)
	var reverse_dist: float = (dy / cos_rot) if absf(cos_rot) > 0.01 else dy
	var reverse_pos: Vector2 = start_pos + bay_reverse * reverse_dist
	reverse_pos.y = road_y

	# Calculate offscreen exit target X past the right border of viewport
	var vp_width: float = 720.0
	if vehicle_node.is_inside_tree() and vehicle_node.get_viewport() != null:
		var vp_rect = vehicle_node.get_viewport().get_visible_rect()
		if vp_rect.size.x > 0.0:
			vp_width = vp_rect.size.x

	var parent_node = vehicle_node.get_parent()
	var global_right_x: float = (vp_width / 2.0) + 400.0
	var exit_global := Vector2(global_right_x, 0.0)
	var exit_local: Vector2 = parent_node.get_global_transform().affine_inverse() * exit_global if parent_node != null else exit_global
	var exit_x: float = maxf(exit_local.x, reverse_pos.x + 350.0)
	var exit_pos := Vector2(exit_x, road_y)

	# Intermediate position where the bus completes turning onto the horizontal grey roadway
	var turn_end_pos := Vector2(minf(reverse_pos.x + 70.0, exit_x - 100.0), road_y)

	# Timing allocation (total = total_duration)
	# Phase 1 (Reverse straight out of slot): 35% of total time
	# Phase 2 (Turn onto grey road): 25% of total time
	# Phase 3 (Drive forward to off-screen exit): 40% of total time
	var t_reverse: float = total_duration * 0.35
	var t_turn: float = total_duration * 0.25
	var t_drive: float = total_duration - t_reverse - t_turn

	var bay_cleared := false
	var lambda_clear := func():
		if not bay_cleared and is_instance_valid(controller):
			bay_cleared = true
			var t_c: float = Time.get_ticks_msec() / 1000.0
			print("[QA] Bus %d BAY CLEARED at %.3f (After: %.3fs)" % [vehicle_id, t_c, t_c - t_dep_start])
			controller.on_vehicle_cleared_slot(vehicle_id, slot_id, token)

	var tw := vehicle_node.create_tween()

	# Phase 1: Reversing backward along bay axis out of slot onto grey road
	tw.tween_property(vehicle_node, "position", reverse_pos, t_reverse) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# At end of reverse, bay is 100% physically cleared
	tw.tween_callback(lambda_clear)

	# Phase 2: Smooth turn onto the horizontal grey roadway
	var turn_method := func(p: float):
		if not is_instance_valid(vehicle_node):
			return
		vehicle_node.position = reverse_pos.lerp(turn_end_pos, p)
		vehicle_node.rotation = lerp_angle(parked_rot, rot_target, p)

	tw.tween_method(turn_method, 0.0, 1.0, t_turn) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Phase 3: Driving forward along grey roadway to complete off-screen exit
	var drive_method := func(p: float):
		if not is_instance_valid(vehicle_node):
			return
		vehicle_node.position = turn_end_pos.lerp(exit_pos, p)
		vehicle_node.rotation = rot_target

	tw.tween_method(drive_method, 0.0, 1.0, t_drive) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Phase 4: Final exit completed off-screen
	tw.tween_callback(func():
		var t_dep_end: float = Time.get_ticks_msec() / 1000.0
		print("[QA] Bus %d DEPARTURE COMPLETE at %.3f (Actual: %.3fs | Target: %.2fs)" % [
			vehicle_id, t_dep_end, t_dep_end - t_dep_start, total_duration
		])
		if is_instance_valid(vehicle_node):
			vehicle_node.visible = false
			if vehicle_node.get_parent() != null:
				vehicle_node.get_parent().remove_child(vehicle_node)
			vehicle_node.queue_free()
		if is_instance_valid(controller):
			controller.on_vehicle_departed_from_slot(vehicle_id, slot_id, token)
	)

static func _update_curve(t: float, curve: Curve2D, v_node: Node2D, target_scale: Vector2, start_scale: Vector2, drive_forward: bool, front_native: Vector2, force_final_rot: bool = false, final_rot_target: float = 0.0) -> void:
	if not is_instance_valid(v_node): return
	var total_len: float = curve.get_baked_length()
	var offset: float = t * total_len
	var pos: Vector2 = curve.sample_baked(offset)
	v_node.position = pos

	# Central difference for robust, jitter-free tangent calculation
	var offset_back: float = maxf(0.0, offset - 2.0)
	var offset_ahead: float = minf(total_len, offset + 2.0)
	var pos_back: Vector2 = curve.sample_baked(offset_back)
	var pos_ahead: Vector2 = curve.sample_baked(offset_ahead)

	if pos_back.distance_to(pos_ahead) > 0.01:
		var dir := (pos_ahead - pos_back).normalized()
		if not drive_forward:
			dir = -dir
		var tangent_rot: float = dir.angle() - front_native.angle()
		# In final 25% of the curve approach into the parking bay, smoothly blend directly to final_rot_target
		if force_final_rot and t > 0.75:
			var blend: float = clampf((t - 0.75) / 0.25, 0.0, 1.0)
			v_node.rotation = lerp_angle(tangent_rot, final_rot_target, blend)
		else:
			v_node.rotation = tangent_rot

	v_node.scale = start_scale.lerp(target_scale, t)

## Feature C: VIP Flight Dispatch Animation.
## Lifts any selected bus into the air from its board position, arcs over all board
## obstacles with altitude scaling and dynamic banking, and touches down in VIP Slot 0.
static func animate_vip_flight(
	vehicle_node: Node2D,
	start_pos: Vector2,
	slot_pos: Vector2,
	token: int,
	controller: Node,
	vehicle_id: int,
	target_scale: Vector2,
	duration_mult: float = 1.0,
	slot_rotation: float = 0.0,
	on_land_callback: Callable = Callable()
) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return

	var start_rot: float = vehicle_node.rotation
	var start_scale: Vector2 = vehicle_node.scale
	var duration: float = 0.95 * duration_mult

	# Quadratic Bezier apex: high in the air above start and slot
	var mid_x: float = (start_pos.x + slot_pos.x) * 0.5
	var apex_y: float = minf(start_pos.y, slot_pos.y) - 220.0
	var p1 := Vector2(mid_x, apex_y)

	# Dynamic lateral bank direction
	var lateral_dx: float = slot_pos.x - start_pos.x
	var bank_sign: float = signf(lateral_dx) if absf(lateral_dx) > 10.0 else 0.0
	var max_bank_angle: float = deg_to_rad(14.0) * bank_sign

	# Spawn ground shadow node under the bus in transit_layer
	var parent_node = vehicle_node.get_parent()
	var shadow_node: Node2D = null
	if parent_node != null:
		shadow_node = Node2D.new()
		shadow_node.name = "VIPFlightShadow_%d" % vehicle_id
		shadow_node.z_index = 50
		parent_node.add_child(shadow_node)
		var shadow_draw := func():
			if not is_instance_valid(shadow_node): return
			shadow_node.draw_colored_polygon(
				PackedVector2Array([
					Vector2(-26, -14), Vector2(0, -18), Vector2(26, -14),
					Vector2(32, 0), Vector2(26, 14), Vector2(0, 18),
					Vector2(-26, 14), Vector2(-32, 0)
				]),
				Color(0, 0, 0, 0.35)
			)
		shadow_node.draw.connect(shadow_draw)
		shadow_node.queue_redraw()

	var flight_method := func(p: float):
		if not is_instance_valid(vehicle_node):
			if shadow_node != null and is_instance_valid(shadow_node):
				shadow_node.queue_free()
			return

		# Quadratic Bezier position: (1-p)^2 * P0 + 2(1-p)p * P1 + p^2 * P2
		var u: float = 1.0 - p
		var current_pos: Vector2 = u * u * start_pos + 2.0 * u * p * p1 + p * p * slot_pos
		vehicle_node.position = current_pos

		# 3D altitude curve: sin(p * PI) reaches 1.0 at peak
		var alt: float = sin(p * PI)

		# Scale swells up by +36% at peak altitude (feel of rising toward camera)
		var base_scale: Vector2 = start_scale.lerp(target_scale, p)
		vehicle_node.scale = base_scale * (1.0 + 0.36 * alt)

		# Smooth rotation blend + dynamic banking tilt
		var base_rot: float = lerp_angle(start_rot, slot_rotation, p)
		var bank: float = max_bank_angle * sin(p * PI)
		vehicle_node.rotation = base_rot + bank

		# Update ground shadow (follows ground directly under bus)
		if shadow_node != null and is_instance_valid(shadow_node):
			shadow_node.position = start_pos.lerp(slot_pos, p)
			var shadow_scale: float = (1.0 + 0.25 * alt)
			shadow_node.scale = Vector2(shadow_scale, shadow_scale * 0.6)
			shadow_node.modulate.a = clampf(0.35 - 0.15 * alt, 0.12, 0.35)

	var tw := vehicle_node.create_tween()
	tw.tween_method(flight_method, 0.0, 1.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Touchdown Impact Bounce & Finalization
	tw.tween_callback(func():
		if shadow_node != null and is_instance_valid(shadow_node):
			shadow_node.queue_free()

		if not is_instance_valid(vehicle_node):
			return

		vehicle_node.position = slot_pos
		vehicle_node.rotation = slot_rotation

		if on_land_callback.is_valid():
			on_land_callback.call()

		# Squash & stretch landing impact
		var bounce_tw := vehicle_node.create_tween()
		bounce_tw.tween_property(vehicle_node, "scale", target_scale * Vector2(1.14, 0.86), 0.07).set_trans(Tween.TRANS_QUAD)
		bounce_tw.tween_property(vehicle_node, "scale", target_scale * Vector2(0.96, 1.04), 0.07).set_trans(Tween.TRANS_QUAD)
		bounce_tw.tween_property(vehicle_node, "scale", target_scale, 0.06).set_trans(Tween.TRANS_QUAD)

		bounce_tw.tween_callback(func():
			if is_instance_valid(controller):
				controller.on_vehicle_arrived_at_slot(vehicle_id, 0, token)
		)
	)
