import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """	for p in active_passengers:
		if is_instance_valid(p["view"]): p["view"].queue_free()
		if is_instance_valid(p["follower"]): p["follower"].queue_free()
	active_passengers.clear()
	if is_instance_valid(passenger_track):
		passenger_track.queue_free()
		passenger_track = null"""

code = re.sub(r'\tfor p in passenger_views:[\s\S]*?passenger_views\.clear\(\)', replacement, code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed passenger_views usages")
