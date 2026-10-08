import re

with open("scripts/gameplay/vehicle_movement.gd", "r") as f:
    code = f.read()

replacement = """	var cur_dir = vehicle_node.vehicle_dir
	var rot_target = 0.0
	if cur_dir == 1: rot_target = 0.0
	elif cur_dir == 2: rot_target = PI/2.0
	elif cur_dir == 3: rot_target = -PI/2.0
"""

code = re.sub(r'\tvar cur_dir = vehicle_node\.vehicle_dir\n\tvar rot_target = 0\.0\n\tif cur_dir == 1: rot_target = -PI/2\.0\n\telif cur_dir == 2: rot_target = PI\n\telif cur_dir == 3: rot_target = PI/2\.0\n', replacement, code)

with open("scripts/gameplay/vehicle_movement.gd", "w") as f:
    f.write(code)

print("Fixed rotation targets")
