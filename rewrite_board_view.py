import re

with open("scripts/gameplay/board_view.gd", "r") as f:
    code = f.read()

draw_iso = """func _draw() -> void:
	var tile_w = 80.0
	var tile_h = 46.0
	var thickness = 10.0
	
	var total_w = float(board_size.x)
	var total_h = float(board_size.y)
	
	# Draw base pad
	var pad_pts = PackedVector2Array()
	# The logical bounding box goes from 0 to board_size
	# but we center it.
	
	for y in board_size.y:
		for x in board_size.x:
			var lx = float(x) - (total_w - 1.0) / 2.0
			var ly = float(y) - (total_h - 1.0) / 2.0
			
			var ix = (lx - ly) * (tile_w / 2.0)
			var iy = (lx + ly) * (tile_h / 2.0)
			
			var p_top = Vector2(ix, iy - tile_h/2.0)
			var p_right = Vector2(ix + tile_w/2.0, iy)
			var p_bottom = Vector2(ix, iy + tile_h/2.0)
			var p_left = Vector2(ix - tile_w/2.0, iy)
			
			draw_colored_polygon(PackedVector2Array([p_top, p_right, p_bottom, p_left]), Color("1e293b"))
			
			# Draw outlines
			draw_line(p_top, p_right, Color("334155"), 2.0)
			draw_line(p_right, p_bottom, Color("334155"), 2.0)
			draw_line(p_bottom, p_left, Color("334155"), 2.0)
			draw_line(p_left, p_top, Color("334155"), 2.0)
"""

code = re.sub(r'func _draw\(\) -> void:[\s\S]*?(?=$)', draw_iso, code)

with open("scripts/gameplay/board_view.gd", "w") as f:
    f.write(code)

print("Rewrote BoardView for isometric")
