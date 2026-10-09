import re

with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    code = f.read()

shadow_logic = """
	var shadow_drawer = Node2D.new()
	shadow_drawer.z_index = -1 # Behind bus body
	shadow_drawer.draw.connect(func():
		var ci = shadow_drawer.get_canvas_item()
		var shadow_style = StyleBoxFlat.new()
		shadow_style.bg_color = Color(0, 0, 0, 0.25)
		shadow_style.set_corner_radius_all(30)
		
		var w = bounds_max.x - bounds_min.x
		var h = bounds_max.y - bounds_min.y
		# Soft blur not available in standard StyleBoxFlat without 4.x anti-aliasing but transparent black works great
		var rect = Rect2(bounds_min.x + 4, bounds_min.y + 12, w, h)
		shadow_style.draw(ci, rect)
	)
	add_child(shadow_drawer)

	# 5. Create hit area and collision shape
"""

code = code.replace("\t# 5. Create hit area and collision shape", shadow_logic)

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(code)

print("Added bus shadows!")
