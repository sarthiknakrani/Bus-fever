import re

# 1. Update BoardView to draw Cartesian
code_board = """extends Node2D
class_name BoardView

const CELL_SIZE: float = 78.0
var board_size: Vector2i = Vector2i(7, 7)

func setup(size: Vector2i) -> void:
	board_size = size
	queue_redraw()

func _draw() -> void:
	var total_w = float(board_size.x) * CELL_SIZE
	var total_h = float(board_size.y) * CELL_SIZE
	
	var rect = Rect2(-total_w/2.0, -total_h/2.0, total_w, total_h)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("e2e8f0") # Light attractive board surface
	style.set_corner_radius_all(12)
	style.border_width_bottom = 8
	style.border_color = Color("cbd5e1")
	draw_style_box(style, rect)
	
	# Grid lines
	for y in range(1, board_size.y):
		var py = -total_h/2.0 + y * CELL_SIZE
		draw_line(Vector2(-total_w/2.0, py), Vector2(total_w/2.0, py), Color("f1f5f9"), 4.0)
	for x in range(1, board_size.x):
		var px = -total_w/2.0 + x * CELL_SIZE
		draw_line(Vector2(px, -total_h/2.0), Vector2(px, total_h/2.0), Color("f1f5f9"), 4.0)
"""
with open("scripts/gameplay/board_view.gd", "w") as f:
    f.write(code_board)

# 2. Add Isometric Transform to board_root in car_jam_level.gd
with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    lvl_code = f.read()

replacement = """	# 1.1 BoardRoot
	board_root = Node2D.new()
	board_root.name = "BoardRoot"
	board_root.rotation = deg_to_rad(45)
	board_root.scale = Vector2(1.0, 0.6) # Isometric-ish tilt
"""
lvl_code = re.sub(r'\t# 1\.1 BoardRoot\n\tboard_root = Node2D\.new\(\)\n\tboard_root\.name = "BoardRoot"\n', replacement, lvl_code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(lvl_code)

print("Applied Cartesian BoardView + parent Transform")
