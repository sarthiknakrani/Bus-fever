import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """func _fill_passenger_track() -> void:
	if passenger_track == null: return
"""

code = code.replace("func _fill_passenger_track() -> void:\n", replacement)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed null crash")
