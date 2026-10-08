import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """func _init_passenger_track() -> void:
	passenger_track = Path2D.new()
	var curve = Curve2D.new()
	# Create a large wide curved track across the top
	var rx = 300.0
	var ry = 100.0
	var pts = 40
	# An open curve or wide oval
	for i in range(pts + 1):
		var t = float(i) / pts * PI * 2.0
		curve.add_point(Vector2(cos(t)*rx, sin(t)*ry))
	passenger_track.curve = curve
	passenger_visuals.add_child(passenger_track)
	track_time = curve.get_baked_length() * 0.25

	_fill_passenger_track()"""

code = re.sub(r'func _init_passenger_track\(\) -> void:.*?_fill_passenger_track\(\)', replacement, code, flags=re.DOTALL)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed passenger track size")
