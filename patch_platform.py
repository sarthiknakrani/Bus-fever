import re

with open("scripts/gameplay/board_view.gd", "r") as f:
    board_code = f.read()

# Erase the drawing code from board_view.gd to remove the diamond visual boundary
board_code = re.sub(r"func _draw\(\) -> void:.*", "func _draw() -> void:\n\tpass\n", board_code, flags=re.DOTALL)

with open("scripts/gameplay/board_view.gd", "w") as f:
    f.write(board_code)


with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    level_code = f.read()

# Add platform_bg variable
if "var platform_bg: PlatformView" not in level_code:
    level_code = level_code.replace("var board_bg: BoardView", "var board_bg: BoardView\nvar platform_bg: PlatformView")

# Add PlatformView to the scene hierarchy
build_scene = """	platform_bg = PlatformView.new()
	platform_bg.name = "PlatformBackground"
	world_root.add_child(platform_bg)

	board_bg = BoardView.new()"""
level_code = level_code.replace("	board_bg = BoardView.new()", build_scene)

# Update platform layout in _update_layout
layout_patch = """	# Puzzle board in the lower middle area
	if board_root != null:
		board_root.position = Vector2(0, board_y)
		
	if platform_bg != null:
		platform_bg.position = Vector2(0, board_y)
		platform_bg.setup(board_pixel_w + 160.0, board_pixel_h + 240.0)"""

level_code = level_code.replace("	# Puzzle board in the lower middle area\n	if board_root != null:\n		board_root.position = Vector2(0, board_y)", layout_patch)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(level_code)

print("Patched platform drawing!")
