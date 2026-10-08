import re

with open("scripts/gameplay/car_jam_controller.gd", "r") as f:
    code = f.read()

replacement = """	# Failure / Softlock check:
	# If parking is full (no free slots) AND no parked vehicle matches the head of queue:
	if parking.is_full():
		var head_color := queue.get_head_color()
		var matching_parked := false
		for i in parking.get_slot_count():
			var slot := parking.get_slot(i)
			if slot != null and slot.vehicle_id != -1:
				var v: VehicleModel = vehicles.get(slot.vehicle_id, null)
				if v != null:
					# If a vehicle is FULL, it is about to depart and free a slot. Not a softlock!
					if v.state == VehicleModel.VehicleState.FULL:
						matching_parked = true
						break
					if v.color_id == head_color and v.remaining_capacity() > 0:
						matching_parked = true
						break
"""

code = re.sub(r'\t# Failure / Softlock check:\n\t# If parking is full \(no free slots\) AND no parked vehicle matches the head of queue:\n\tif parking\.is_full\(\):\n\t\tvar head_color := queue\.get_head_color\(\)\n\t\tvar matching_parked := false\n\t\tfor i in parking\.get_slot_count\(\):\n\t\t\tvar slot := parking\.get_slot\(i\)\n\t\t\tif slot != null and slot\.vehicle_id != -1:\n\t\t\t\tvar v: VehicleModel = vehicles\.get\(slot\.vehicle_id, null\)\n\t\t\t\tif v != null and v\.color_id == head_color and v\.remaining_capacity\(\) > 0:\n\t\t\t\t\tmatching_parked = true\n\t\t\t\t\tbreak\n', replacement, code)

with open("scripts/gameplay/car_jam_controller.gd", "w") as f:
    f.write(code)

print("Fixed softlock check")
