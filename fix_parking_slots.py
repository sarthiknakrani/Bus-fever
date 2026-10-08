import re

with open("scripts/gameplay/parking_manager.gd", "r") as f:
    code = f.read()

replacement = """class ParkingSlot:
	var slot_id: int = 0
	var state: int = SlotState.EMPTY
	var vehicle_id: int = -1
	var is_unlocked: bool = false

	func _init(id: int) -> void:
		slot_id = id
		state = SlotState.EMPTY
		vehicle_id = -1
		# Default unlock rule: Slot 0 is VIP (locked), Slots 1-3 are normal (unlocked), Slots 4+ are locked
		if id >= 1 and id <= 3:
			is_unlocked = true
		else:
			is_unlocked = false

	func is_available() -> bool:
		return state == SlotState.EMPTY and is_unlocked
"""

code = re.sub(r'class ParkingSlot:[\s\S]*?func is_available\(\) -> bool:\n\t\treturn state == SlotState\.EMPTY', replacement, code)

code = code.replace("if s.slot_id < 4 and s.is_available():", "if s.is_available():")

with open("scripts/gameplay/parking_manager.gd", "w") as f:
    f.write(code)

print("Fixed parking manager")
