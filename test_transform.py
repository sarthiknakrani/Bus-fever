import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

board_iso = """	board_root = Node2D.new()
	board_root.name = "BoardRoot"
	
	# Apply isometric transform to board
	var iso_transform = Transform2D(Vector2(1.0, 0.5), Vector2(-1.0, 0.5), Vector2(0,0))
	board_root.transform = iso_transform
"""

code = re.sub(r'\tboard_root = Node2D\.new\(\)[\s\S]*?board_root\.name = "BoardRoot"', board_iso.strip('\n'), code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Applied iso transform to board")
