extends RefCounted
class_name VehicleMovement

## Handles smooth 2D visual tweening for vehicle dispatch and departure.
## Separated from authoritative simulation logic for clean restart safety and testability.

static func animate_dispatch(
	vehicle_node: Node2D,
	start_pos: Vector2,
	exit_pos: Vector2,
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

	# Create sequential tween for strict orthogonal movement
	var tw := vehicle_node.create_tween()
	var t_board_exit = 0.65 * duration_mult
	
	# Phase 1: Drive straight out of board (along original puzzle arrow)
	# Extend exit_pos slightly to guarantee full visual clearance of board before curving
	var out_dir = (exit_pos - start_pos).normalized()
	var safe_exit_pos = exit_pos + (out_dir * 30.0)
	
	tw.tween_property(vehicle_node, "position", safe_exit_pos, t_board_exit).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Phase 2: Smooth continuous curve to parking bay
	var curve = Curve2D.new()
	# Start point: safe_exit_pos. Out handle extends along the travel direction.
	curve.add_point(safe_exit_pos, Vector2.ZERO, out_dir * 180.0)
	
	# End point: slot_pos. In handle pulls from directly below (buses park UP).
	var in_handle = Vector2(0, 180.0)
	curve.add_point(slot_pos, in_handle, Vector2.ZERO)
	
	var total_transit = 1.3 * duration_mult
	var start_scale = vehicle_node.scale
	
	# Derive the actual native physical front vector based on the sprite
	var front_native = Vector2(0, -1)
	match vehicle_node.vehicle_dir:
		CarJamVehicleData.Direction.DOWN: front_native = Vector2(0, 1)
		CarJamVehicleData.Direction.UP: front_native = Vector2(0, -1)
		CarJamVehicleData.Direction.LEFT: front_native = Vector2(-1, 0)
		CarJamVehicleData.Direction.RIGHT: front_native = Vector2(1, 0)
	
	# Calculate exact final rotation to face UP (0, -1)
	var final_rot_target = 0.0
	match vehicle_node.vehicle_dir:
		CarJamVehicleData.Direction.DOWN: final_rot_target = PI
		CarJamVehicleData.Direction.UP: final_rot_target = 0.0
		CarJamVehicleData.Direction.LEFT: final_rot_target = PI/2.0
		CarJamVehicleData.Direction.RIGHT: final_rot_target = -PI/2.0
	
	var curve_callable = Callable(VehicleMovement, "_update_curve").bind(curve, vehicle_node, target_scale, start_scale, true, front_native, true, final_rot_target)
	tw.tween_method(curve_callable, 0.0, 1.0, total_transit).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var lambda_func = func(v_node, t_scale, ctrl, v_id, s_id, tok):
		if is_instance_valid(v_node):
			v_node.set_parking_mode(true)
			
			# QA LOGGING: Mandatory parking arrival check
			var dir_str = CarJamVehicleData.dir_to_string(v_node.vehicle_dir)
			var front_vec = front_native.rotated(v_node.rotation)
			var bay_axis = Vector2(0, -1) # Bay faces UP
			var ang_diff = rad_to_deg(front_vec.angle_to(bay_axis))
			
			# We can approximate bounds center alignment (position is slot_pos)
			var bounds_diff = v_node.global_position.distance_to(slot_pos)
			
			print("[QA] ARRIVAL | Bus %d (Orig Dir: %s) -> Slot %d" % [v_id, dir_str, s_id])
			print("      | Front Vector: (%.2f, %.2f) | Bay Axis: (0, -1)" % [front_vec.x, front_vec.y])
			print("      | Angular Error: %.1f deg | Center Error: %.1f px" % [ang_diff, bounds_diff])
			
			v_node.z_index = 10 # Normal parking z-index
			var settle_tw = v_node.create_tween()
			settle_tw.tween_property(v_node, "scale", t_scale * 1.05, 0.15).set_trans(Tween.TRANS_SINE)
			settle_tw.tween_property(v_node, "scale", t_scale, 0.15).set_trans(Tween.TRANS_BOUNCE)
		ctrl.on_vehicle_arrived_at_slot(v_id, s_id, tok)
	
	tw.chain().tween_callback(lambda_func.bind(vehicle_node, target_scale, controller, vehicle_id, slot_id, token))


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
	
	var tw = vehicle_node.create_tween()
	
	# 1. Reverse maneuver (Straight backward)
	print("[QA %d] Bus %d reverse started." % [Time.get_ticks_msec(), vehicle_id])
	var reverse_pos = vehicle_node.position + Vector2(0, 220.0) # Move far down, completely outside the parking slots
	tw.tween_property(vehicle_node, "position", reverse_pos, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	var lambda_clear = func(ctrl, v_id, s_id, tok):
		ctrl.on_vehicle_cleared_slot(v_id, s_id, tok)
	tw.tween_callback(lambda_clear.bind(controller, vehicle_id, slot_id, token))
	
	# 2 & 3. Smooth forward curve to exit screen right, staying OUTSIDE the parking container
	var curve = Curve2D.new()
	var vp_rect = vehicle_node.get_viewport_rect()
	var global_right_x = (vp_rect.size.x / 2.0) + 350.0 
	var exit_global = Vector2(global_right_x, 0)
	var exit_local = vehicle_node.get_parent().get_global_transform().affine_inverse() * exit_global
	
	# The bus drives RIGHT, maintaining its lowered Y position
	# Final target Y is higher than reverse_pos, creating a natural C-curve forward sweep.
	# reverse_pos is +220. We exit at +120. The parking slots end around +60.
	# This keeps the entire exit path safely below the locked slot cards!
	var final_target = Vector2(exit_local.x, reverse_pos.y - 100.0)
	
	# Start point: at reverse_pos (facing UP initially before it begins curving).
	# We want it to turn right. The out handle pulls it UP to initiate forward driving.
	curve.add_point(reverse_pos, Vector2.ZERO, Vector2(0, -120.0))
	# End point: far right, approaching horizontally from left
	curve.add_point(final_target, Vector2(-150.0, 0), Vector2.ZERO)
	
	var start_scale = vehicle_node.scale
	var front_native = Vector2(0, -1)
	match vehicle_node.vehicle_dir:
		CarJamVehicleData.Direction.DOWN: front_native = Vector2(0, 1)
		CarJamVehicleData.Direction.UP: front_native = Vector2(0, -1)
		CarJamVehicleData.Direction.LEFT: front_native = Vector2(-1, 0)
		CarJamVehicleData.Direction.RIGHT: front_native = Vector2(1, 0)
		
	var curve_callable = Callable(VehicleMovement, "_update_curve").bind(curve, vehicle_node, start_scale, start_scale, true, front_native)
	
	# Total exit time 1.5s
	tw.tween_method(curve_callable, 0.0, 1.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var lambda_func2 = func(v_node, ctrl, v_id, s_id, tok):
		if is_instance_valid(v_node):
			v_node.visible = false
		ctrl.on_vehicle_departed_from_slot(v_id, s_id, tok)
		
	tw.tween_callback(lambda_func2.bind(vehicle_node, controller, vehicle_id, slot_id, token))


static func _update_curve(t: float, curve: Curve2D, v_node: Node2D, target_scale: Vector2, start_scale: Vector2, drive_forward: bool, front_native: Vector2, force_final_rot: bool = false, final_rot_target: float = 0.0) -> void:
	if not is_instance_valid(v_node): return
	var total_len = curve.get_baked_length()
	var offset = t * total_len
	var pos = curve.sample_baked(offset)
	v_node.position = pos
	
	# Sample slightly ahead for tangent (rotation)
	var offset_ahead = min(total_len, offset + 2.0)
	var pos_ahead = curve.sample_baked(offset_ahead)
	
	var curve_rot = v_node.rotation
	if pos.distance_to(pos_ahead) > 0.1:
		var dir = (pos_ahead - pos).normalized()
		if not drive_forward:
			dir = -dir
		curve_rot = dir.angle() - front_native.angle()
	
	if force_final_rot and t > 0.8:
		# Smoothly blend into the final vertical alignment during the last 20%
		var blend = (t - 0.8) / 0.2
		# Use lerp_angle to avoid spinning the wrong way
		v_node.rotation = lerp_angle(curve_rot, final_rot_target, blend)
	else:
		v_node.rotation = curve_rot
		
	v_node.scale = start_scale.lerp(target_scale, t)
