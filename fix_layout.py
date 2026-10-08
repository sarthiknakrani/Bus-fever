import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """	scale_factor = clampf(vp_size.x / 600.0, 0.5, 2.0)
	
	# Keep world centered at (0,0) which is where the Camera2D looks
	world_root.scale = Vector2(scale_factor, scale_factor)
	world_root.position = Vector2.ZERO

	var half_h = (vp_size.y / 2.0) / scale_factor

	# Parking between passenger track and board
	if parking_root != null:
		parking_root.position = Vector2(0, -half_h + 650)

	# Board below parking
	if board_root != null:
		board_root.position = Vector2(0, -half_h + 1050)

	# Passenger track right above the parking
	if passenger_track_root != null:
		passenger_track_root.position = Vector2(0, -half_h + 350)
"""

# Find the block from "var gameplay_height" to the end of passenger_track_root setup
code = re.sub(r'\tvar gameplay_height = 1100\.0.*?passenger_track_root\.position = Vector2\(0, -420\)', replacement, code, flags=re.DOTALL)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed layout")
