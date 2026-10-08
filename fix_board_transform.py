import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

replacement = """	# 1.1 BoardRoot
	board_root = Node2D.new()
	board_root.name = "BoardRoot"
	
	board_root.position = Vector2(0, BOARD_Y)
"""

code = re.sub(r'\t# 1\.1 BoardRoot\n\tboard_root = Node2D\.new\(\)\n\tboard_root\.name = "BoardRoot"\n\t\n\t# Apply isometric transform to board\n\tvar iso_transform = Transform2D\(Vector2\(1\.0, 0\.5\), Vector2\(-1\.0, 0\.5\), Vector2\(0,0\)\)\n\tboard_root\.transform = iso_transform\n\tboard_root\.position = Vector2\(0, BOARD_Y\)\n', replacement, code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed board transform")
