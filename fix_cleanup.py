import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

cleanup = """	for c in boarding_effects.get_children():
		c.queue_free()
	for c in transit_layer.get_children():
		c.queue_free()
"""

# Insert right after `vehicle_views.clear()`
code = re.sub(r'vehicle_views\.clear\(\)', 'vehicle_views.clear()\n' + cleanup, code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed visual cleanup on restart")
