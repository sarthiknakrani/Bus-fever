import re

with open("scripts/gameplay/parking_manager.gd", "r") as f:
    code = f.read()

replacement = """
func get_available_slot_count() -> int:
	var count := 0
	for s in _slots:
		if s.slot_id < 4 and s.is_available():
			count += 1
	return count
"""
code = re.sub(r'func get_available_slot_count\(\) -> int:[\s\S]*?\treturn count', replacement.strip('\n'), code)

with open("scripts/gameplay/parking_manager.gd", "w") as f:
    f.write(code)

print("Patched parking_manager.gd available count")
