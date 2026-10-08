import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """	# Keep world centered at (0,0) which is where the Camera2D looks
	# We can scale up slightly since the board is ~500px wide
	scale_factor = clampf(vp_size.x / 600.0, 0.5, 2.0)
	world_root.scale = Vector2(scale_factor, scale_factor)
	world_root.position = Vector2.ZERO

	var half_h = (vp_size.y / 2.0) / scale_factor
	
	# Distribute elements vertically to fill portrait screen nicely
	if passenger_track_root != null:
		passenger_track_root.position = Vector2(0, -half_h + 350)
		
	if parking_root != null:
		parking_root.position = Vector2(0, -half_h + 650)
		
	if board_root != null:
		board_root.position = Vector2(0, -half_h + 1050)
"""

code = re.sub(r'\t# Keep world centered at \(0,0\).*?\t\tif board_root != null:\n\t\t\tboard_root\.position = Vector2\(0, 160\)\n\t\n\t\t# Passenger track right above the parking\n\t\tif passenger_track_root != null:\n\t\t\tpassenger_track_root\.position = Vector2\(0, -420\)', replacement, code, flags=re.DOTALL)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed layout")
