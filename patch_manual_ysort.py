import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# Let's find the end of _process and add manual y-sorting
# _process ends after passenger logic. Let's just put it at the very end.
pattern = r'(func _process\(delta: float\) -> void:.*?)(^\s*func)'
match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
if match:
    process_block = match.group(1)
    
    ysort_code = """	
	# Isometric manual Y-sorting for buses based on global screen Y
	if vehicle_layer != null:
		var views = []
		for i in vehicle_layer.get_child_count():
			var c = vehicle_layer.get_child(i)
			if c is VehicleView:
				views.append(c)
		views.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
		for i in range(views.size()):
			if views[i].get_index() != i:
				vehicle_layer.move_child(views[i], i)
"""
    
    new_process_block = process_block + ysort_code + "\n"
    content = content.replace(process_block, new_process_block)
    print("Injected manual Y-sort in _process.")
else:
    print("Could not find _process.")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)
