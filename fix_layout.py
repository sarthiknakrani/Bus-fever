import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

layout = """	# Parking between passenger track and board
	if parking_root != null:
		parking_root.position = Vector2(0, -200)

	# Board below parking
	if board_root != null:
		board_root.position = Vector2(0, 160)

	# Passenger track right above the parking
	if passenger_track_root != null:
		passenger_track_root.position = Vector2(0, -420)"""

code = re.sub(r'\t# Board exactly in the middle of the screen[\s\S]*?passenger_track_root\.position = Vector2\(0, -380\)', layout.strip('\n'), code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed layout order")
