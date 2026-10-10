import re

with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    content = f.read()

# I will add an arrow_draw Node2D that uses _draw()
# I'll inject it inside _build_visuals() around line 150 where badge is created.

arrow_block = """	var arrow_draw := Node2D.new()
	arrow_draw.draw.connect(func():
		var ci = arrow_draw.get_canvas_item()
		var p1 = Vector2(0, -22)
		var p2 = Vector2(-12, -4)
		var p3 = Vector2(-4, -4)
		var p4 = Vector2(-4, 18)
		var p5 = Vector2(4, 18)
		var p6 = Vector2(4, -4)
		var p7 = Vector2(12, -4)
		var pts = PackedVector2Array([p1, p2, p3, p4, p5, p6, p7])
		var col = Color.WHITE
		# shadow
		var shadow_pts = PackedVector2Array()
		for p in pts:
			shadow_pts.append(p + Vector2(0, 3))
		arrow_draw.draw_polygon(shadow_pts, PackedColorArray([Color(0,0,0,0.5)]))
		arrow_draw.draw_polygon(pts, PackedColorArray([col]))
	)
	
	# The arrow should point in the forward direction.
	# We want it drawn on top of everything.
	_v_root.add_child(arrow_draw)
"""

# Let's see if we can insert it right before _badge_node is created
if "_badge_node = Node2D.new()" in content:
    content = content.replace("_badge_node = Node2D.new()", arrow_block + "\n\t_badge_node = Node2D.new()")
    print("Arrow block injected.")
else:
    print("Could not find _badge_node creation.")

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(content)

