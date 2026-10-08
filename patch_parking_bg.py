import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """
	# Draw a slanted grey background behind all slots
	var bg = Polygon2D.new()
	bg.color = Color("8c92a1") # Light grey like the reference
	var bg_shear = 12.0
	var bg_w = total_span + 120.0
	var bg_h = 100.0
	var p1 = Vector2(-bg_w/2 + bg_shear, -bg_h/2)
	var p2 = Vector2(bg_w/2 + bg_shear, -bg_h/2)
	var p3 = Vector2(bg_w/2 - bg_shear, bg_h/2)
	var p4 = Vector2(-bg_w/2 - bg_shear, bg_h/2)
	bg.polygon = PackedVector2Array([p1, p2, p3, p4])
	parking_slots_node.add_child(bg)

	for i in c:
"""

code = re.sub(r'\tfor i in c:\n\t\tvar slot_view := ParkingSlotView\.new\(\)', replacement.strip('\n') + '\n\t\tvar slot_view := ParkingSlotView.new()', code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Patched parking background")
