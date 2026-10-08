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
	slot_id: int
) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return
		
	var target_scale = Vector2(0.65, 0.65)
	if vehicle_node.vehicle_capacity > 4:
		target_scale = Vector2(0.5, 0.5)

	var tw := vehicle_node.create_tween()
	tw.set_parallel(true)

	# Total duration: 0.0865 + 0.1265 = 0.213s
	# Phase 1: Drive out of board (0.0865s)
	tw.tween_property(vehicle_node, "position", exit_pos, 0.0865).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Phase 2: Arc to slot (0.1265s)
	# Stagger X and Y easing to create a natural curve!
	tw.tween_property(vehicle_node, "position:x", slot_pos.x, 0.1265).set_delay(0.0865).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(vehicle_node, "position:y", slot_pos.y, 0.1265).set_delay(0.0865).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Calculate driving angle for natural orientation
	var drive_dir = (slot_pos - exit_pos).angle()
	
	# Determine final parking orientation to ensure bus sits horizontally
	var cur_dir = vehicle_node.vehicle_dir
	var rot_target = 0.0
	# If bus is vertically drawn (UP or DOWN), we must rotate it 90 degrees to lay flat in parking
	if cur_dir == 2: rot_target = PI/2.0
	elif cur_dir == 3: rot_target = -PI/2.0
	# LEFT (1) can be 0.0 or PI, let's keep it 0.0 so it faces right like the others
	
	# Rotate to drive direction early, then tween to horizontal parking orientation at the end
	tw.tween_property(vehicle_node, "rotation", drive_dir, 0.06).set_delay(0.0865).set_trans(Tween.TRANS_SINE)
	tw.tween_property(vehicle_node, "rotation", rot_target, 0.0665).set_delay(0.0865 + 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Scale down smoothly
	tw.tween_property(vehicle_node, "scale", target_scale, 0.1265).set_delay(0.0865).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# Phase 3: Settle bounce (done via a subtle scale pop, without adding time, just embedded in the callback or chained)
	var lambda_func = func(v_node, t_scale, ctrl, v_id, s_id, tok):
		if is_instance_valid(v_node):
			v_node.set_parking_mode(true)
			# Settle bounce using a quick local tween
			var settle_tw = v_node.create_tween()
			settle_tw.tween_property(v_node, "scale", t_scale * 1.05, 0.05).set_trans(Tween.TRANS_SINE)
			settle_tw.tween_property(v_node, "scale", t_scale, 0.05).set_trans(Tween.TRANS_BOUNCE)
		ctrl.on_vehicle_arrived_at_slot(v_id, s_id, tok)
	
	tw.chain().tween_callback(lambda_func.bind(vehicle_node, target_scale, controller, vehicle_id, slot_id, token))

static func animate_departure(
	vehicle_node: Node2D,
	slot_pos: Vector2,
	token: int,
	controller: Node,
	vehicle_id: int,
	slot_id: int
) -> void:
	if vehicle_node == null or not is_instance_valid(vehicle_node):
		return

	# Hide capacity badge
	vehicle_node.set_parking_mode(false)

	var exit_target := vehicle_node.position + Vector2(750.0, 0.0)
	var tw := vehicle_node.create_tween().set_parallel(true)

	# Total duration: 0.1335s
	# Smooth acceleration forward
	tw.tween_property(vehicle_node, "position", exit_target, 0.1335).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# Fast, readable departure rotation
	var cur_rot = vehicle_node.rotation
	tw.tween_property(vehicle_node, "rotation", cur_rot + deg_to_rad(10), 0.1335).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	var lambda_func2 = func(v_node, ctrl, v_id, s_id, tok):
		if is_instance_valid(v_node):
			v_node.visible = false
		ctrl.on_vehicle_departed_from_slot(v_id, s_id, tok)
		
	tw.chain().tween_callback(lambda_func2.bind(vehicle_node, controller, vehicle_id, slot_id, token))
