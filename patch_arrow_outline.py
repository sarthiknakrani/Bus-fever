import re

with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    content = f.read()

old_block = """		var shadow_pts = PackedVector2Array()
		for p in pts:
			shadow_pts.append(p + Vector2(0, 3))
		arrow_draw.draw_polygon(shadow_pts, PackedColorArray([Color(0,0,0,0.5)]))
		arrow_draw.draw_polygon(pts, PackedColorArray([col]))"""

new_block = """		var shadow_pts = PackedVector2Array()
		for p in pts:
			shadow_pts.append(p + Vector2(0, 4))
		arrow_draw.draw_polygon(shadow_pts, PackedColorArray([Color(0,0,0,0.4)]))
		arrow_draw.draw_polygon(pts, PackedColorArray([col]))
		
		# Add a thick, crisp outline so the white arrow is highly visible against yellow buses
		var outline_pts = PackedVector2Array([p1, p2, p3, p4, p5, p6, p7, p1])
		arrow_draw.draw_polyline(outline_pts, Color(0, 0, 0, 0.75), 3.0, true)"""

if old_block in content:
    content = content.replace(old_block, new_block)
    print("Successfully patched arrow outline.")
else:
    print("Could not find the block to replace.")

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(content)
