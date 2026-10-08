import re

with open("scripts/gameplay/parking_manager.gd", "r") as f:
    code = f.read()

replacement = """
func find_available_slot() -> int:
	for s in _slots:
		if s.slot_id < 4 and s.is_available():
			return s.slot_id
	return -1
"""
code = re.sub(r'func find_available_slot\(\) -> int:[\s\S]*?\treturn -1', replacement.strip('\n'), code)

with open("scripts/gameplay/parking_manager.gd", "w") as f:
    f.write(code)

print("Patched parking_manager.gd to only use first 4 slots")
