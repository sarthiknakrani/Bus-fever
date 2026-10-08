import re

with open("scripts/gameplay/vehicle_movement.gd", "r") as f:
    code = f.read()

dep_logic = """
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
"""

code = re.sub(r'\t# Hide capacity badge[\s\S]*?token\)\n\t\)', dep_logic.strip('\n'), code)

with open("scripts/gameplay/vehicle_movement.gd", "w") as f:
    f.write(code)

print("Patched animate_departure")
