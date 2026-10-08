import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """func _cell_to_board_local(c: Vector2i, b_size: Vector2i) -> Vector2:
	var lx = float(c.x) - float(b_size.x - 1) / 2.0
	var ly = float(c.y) - float(b_size.y - 1) / 2.0
	
	return Vector2(lx * CELL_SIZE, ly * CELL_SIZE)
"""

code = re.sub(r'func _cell_to_board_local\(c: Vector2i, b_size: Vector2i\) -> Vector2:\n\tvar lx = float\(c\.x\) - float\(b_size\.x - 1\) / 2\.0\n\tvar ly = float\(c\.y\) - float\(b_size\.y - 1\) / 2\.0\n\t\n\tvar tile_w = 80\.0\n\tvar tile_h = 46\.0\n\t\n\tvar ix = \(lx - ly\) \* \(tile_w / 2\.0\)\n\tvar iy = \(lx \+ ly\) \* \(tile_h / 2\.0\)\n\t\n\treturn Vector2\(ix, iy\)\n', replacement, code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed _cell_to_board_local")
