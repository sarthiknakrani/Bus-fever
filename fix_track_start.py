import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """	passenger_track.curve = curve
	passenger_visuals.add_child(passenger_track)
	track_time = curve.get_baked_length() * 0.25"""

code = code.replace("	passenger_track.curve = curve\n	passenger_visuals.add_child(passenger_track)", replacement)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed track start position")
