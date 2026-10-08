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

	var tw := vehicle_node.create_tween().set_parallel(false)

	# 1. Drive along escape corridor until clearing the board
	tw.tween_property(vehicle_node, "position", exit_pos, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 2. Smooth curved arc into the assigned parking slot
	var mid_y: float = (exit_pos.y + slot_pos.y) / 2.0
	var mid_pos := Vector2(slot_pos.x * 0.7 + exit_pos.x * 0.3, mid_y)
	
	# Determine target rotation and scale to fit the slot
	var target_scale = Vector2(0.65, 0.65) # Shrink to fit parking
	if vehicle_node.vehicle_capacity > 4:
		target_scale = Vector2(0.5, 0.5) # Large buses shrink more

	var p_tw = vehicle_node.create_tween().set_parallel(true)
	p_tw.tween_property(vehicle_node, "position", mid_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# We use rotation to visually align, but we must account for its current logical direction
	# A horizontal bus needs to rotate to look vertical
	var cur_dir = vehicle_node.vehicle_dir
	var rot_target = 0.0
	if cur_dir == 1: rot_target = -PI/2.0 # Right -> Up
	elif cur_dir == 2: rot_target = PI # Down -> Up (maybe we want them all facing up or down?)
	elif cur_dir == 3: rot_target = PI/2.0 # Left -> Up
	
	p_tw.tween_property(vehicle_node, "rotation", rot_target, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	p_tw.tween_property(vehicle_node, "scale", target_scale, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	p_tw.chain().tween_property(vehicle_node, "position", slot_pos, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# 3. Settle and switch to parking mode (show 3D capacity badge)
	p_tw.chain().tween_callback(func():
		if is_instance_valid(vehicle_node):
			vehicle_node.set_parking_mode(true)
		controller.on_vehicle_arrived_at_slot(vehicle_id, slot_id, token)
	)

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

	# Drive straight off-screen to the right from current parked position
	var exit_target := vehicle_node.position + Vector2(750.0, 0.0)
	var tw := vehicle_node.create_tween().set_parallel(true)

	# Brief departure acceleration
	tw.tween_property(vehicle_node, "position", exit_target, 0.40).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# Also rotate to face right when departing!
	var cur_rot = vehicle_node.rotation
	tw.tween_property(vehicle_node, "rotation", cur_rot + PI/2.0, 0.2)
	
	tw.chain().tween_callback(func():
		if is_instance_valid(vehicle_node):
			vehicle_node.visible = false
		controller.on_vehicle_departed_from_slot(vehicle_id, slot_id, token)
	)
