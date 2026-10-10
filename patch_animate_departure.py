import re

with open("scripts/gameplay/vehicle_movement.gd", "r") as f:
    content = f.read()

pattern = r'(static func animate_departure.*?\n\)\s*->\s*void:\n).*?(?=\nstatic func |\Z)'
match = re.search(pattern, content, re.MULTILINE | re.DOTALL)

if match:
    header = match.group(1)
    
    new_body = """	if vehicle_node == null or not is_instance_valid(vehicle_node):
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
"""
    new_content = content[:match.start()] + header + new_body + content[match.end():]
    with open("scripts/gameplay/vehicle_movement.gd", "w") as f:
        f.write(new_content)
    print("Patched animate_departure")
else:
    print("Could not find animate_departure block")
