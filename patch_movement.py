import re

with open("scripts/gameplay/vehicle_movement.gd", "r") as f:
    code = f.read()

replacement = """static func animate_dispatch(
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

	var mid_y: float = (exit_pos.y + slot_pos.y) / 2.0
	var mid_pos := Vector2(slot_pos.x * 0.7 + exit_pos.x * 0.3, mid_y)
	
	var target_scale = Vector2(0.65, 0.65)
	if vehicle_node.vehicle_capacity > 4:
		target_scale = Vector2(0.5, 0.5)
		
	var cur_dir = vehicle_node.vehicle_dir
	var rot_target = 0.0
	if cur_dir == 1: rot_target = -PI/2.0
	elif cur_dir == 2: rot_target = PI
	elif cur_dir == 3: rot_target = PI/2.0

	var tw := vehicle_node.create_tween().set_parallel(false)

	# 1. Drive along escape corridor
	tw.tween_property(vehicle_node, "position", exit_pos, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 2. Parallel group for arc to mid_pos, scale and rotation
	tw.tween_property(vehicle_node, "position", mid_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(vehicle_node, "rotation", rot_target, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(vehicle_node, "scale", target_scale, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# 3. Final approach to slot
	tw.tween_property(vehicle_node, "position", slot_pos, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	# 4. Callback
	tw.tween_callback(func():
		if is_instance_valid(vehicle_node):
			vehicle_node.set_parking_mode(true)
		controller.on_vehicle_arrived_at_slot(vehicle_id, slot_id, token)
	)
"""

code = re.sub(r'static func animate_dispatch\([\s\S]*?controller.on_vehicle_arrived_at_slot\(vehicle_id, slot_id, token\)\n\t\)', replacement, code)

with open("scripts/gameplay/vehicle_movement.gd", "w") as f:
    f.write(code)

print("Patched vehicle movement")
