import re

with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    code = f.read()

arrow_code = """	
	# Draw directional arrow on top face
	var arrow_dir = Vector2.ZERO
	if vehicle_dir == CarJamVehicleData.Direction.UP:
		arrow_dir = Vector2(0, -1)
	elif vehicle_dir == CarJamVehicleData.Direction.DOWN:
		arrow_dir = Vector2(0, 1)
	elif vehicle_dir == CarJamVehicleData.Direction.LEFT:
		arrow_dir = Vector2(-1, 0)
	elif vehicle_dir == CarJamVehicleData.Direction.RIGHT:
		arrow_dir = Vector2(1, 0)
		
	# Center of roof
	var roof_center = (r0 + r2) / 2.0
	
	# Compute arrow tip in grid space, then project
	var arrow_len = 0.35
	var arrow_tip_g = arrow_dir * arrow_len
	var arrow_back_g = -arrow_dir * (arrow_len * 0.5)
	var arrow_left_g = arrow_back_g + Vector2(arrow_dir.y, -arrow_dir.x) * 0.2
	var arrow_right_g = arrow_back_g + Vector2(-arrow_dir.y, arrow_dir.x) * 0.2
	
	var a_tip = roof_center + to_iso(arrow_tip_g.x, arrow_tip_g.y)
	var a_left = roof_center + to_iso(arrow_left_g.x, arrow_left_g.y)
	var a_right = roof_center + to_iso(arrow_right_g.x, arrow_right_g.y)
	
	draw_colored_polygon(PackedVector2Array([a_tip, a_right, a_left]), Color(1,1,1,0.8))
"""

code = code.replace("	draw_line(g1, r1, oc, 2.0)\n", "	draw_line(g1, r1, oc, 2.0)\n" + arrow_code)

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(code)

print("Added arrow")
