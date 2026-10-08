import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

func = """func _cell_to_board_local(c: Vector2i, b_size: Vector2i) -> Vector2:
	var lx = float(c.x) - float(b_size.x - 1) / 2.0
	var ly = float(c.y) - float(b_size.y - 1) / 2.0
	
	var tile_w = 80.0
	var tile_h = 46.0
	
	var ix = (lx - ly) * (tile_w / 2.0)
	var iy = (lx + ly) * (tile_h / 2.0)
	
	return Vector2(ix, iy)
"""

code = re.sub(r'func _cell_to_board_local[\s\S]*?return Vector2\(wx, wy\)', func.strip('\n'), code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed cell to board local")
