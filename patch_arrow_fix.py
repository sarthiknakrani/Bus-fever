import re

with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    content = f.read()

bad_snippet = """	func _setup_capacity_badge() -> void:
		if _badge_node != null: return
			var arrow_draw := Node2D.new()
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
		add_child(arrow_draw)
	_badge_node = Node2D.new()"""

good_snippet = """func _setup_capacity_badge() -> void:
	if _badge_node != null: return
	
	var arrow_draw := Node2D.new()
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
	add_child(arrow_draw)
	
	_badge_node = Node2D.new()"""

# We'll use regex or replace to fix the indentation
# Let's find the exact string to replace. I'll just find line 151 and replace the block
lines = content.split('\n')
for i, line in enumerate(lines):
    if "func _setup_capacity_badge() -> void:" in line:
        start_idx = i
        break

for i in range(start_idx, len(lines)):
    if "_badge_node = Node2D.new()" in lines[i]:
        end_idx = i
        break

lines = lines[:start_idx] + good_snippet.split('\n') + lines[end_idx+1:]
content = '\n'.join(lines)

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(content)
print("Indentation fixed.")
