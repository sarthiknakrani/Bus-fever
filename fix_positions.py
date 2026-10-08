import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """	# Parking between passenger track and board
	if parking_root != null:
		parking_root.position = Vector2(0, -half_h + 520)

	# Board below parking
	if board_root != null:
		board_root.position = Vector2(0, -half_h + 860)

	# Passenger track right above the parking
	if passenger_track_root != null:
		passenger_track_root.position = Vector2(0, -half_h + 280)
"""

code = re.sub(r'\t# Parking between passenger track and board.*?-half_h \+ 350\)', replacement, code, flags=re.DOTALL)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Tightened layout positions")
