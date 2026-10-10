import re

with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    content = f.read()

# I will find where I inserted arrow_draw and modify it.
start = '	var arrow_draw := Node2D.new()'
end = '	_v_root.add_child(arrow_draw)'
if start in content and end in content:
    pre = content.split(start)[0]
    post = content.split(end)[1]
    
    new_arrow = """	var arrow_draw := Node2D.new()
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
	
	if vehicle_dir == CarJamVehicleData.Direction.UP:
		arrow_draw.rotation = 0
	elif vehicle_dir == CarJamVehicleData.Direction.DOWN:
		arrow_draw.rotation = PI
	elif vehicle_dir == CarJamVehicleData.Direction.LEFT:
		arrow_draw.rotation = -PI / 2.0
	elif vehicle_dir == CarJamVehicleData.Direction.RIGHT:
		arrow_draw.rotation = PI / 2.0
		
	# Add it to self, because there is no _v_root in the current vehicle_view.gd!
	add_child(arrow_draw)"""
    
    content = pre + new_arrow + post
    print("Arrow block updated.")
else:
    print("Could not find previous arrow block.")

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(content)
