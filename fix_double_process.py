import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# Remove the old _process
old_process = """func _process(delta: float) -> void:
	_anim_clock += delta
	# Subtle breathing bounce for queue passengers
	for i in passenger_views.size():
		var pv: PassengerView = passenger_views[i]
		if is_instance_valid(pv):
			pv.position.y = pv.get_meta("base_y", pv.position.y) + sin(_anim_clock * 4.5 + float(i) * 0.45) * 2.0"""

code = code.replace(old_process, "")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed double _process")
