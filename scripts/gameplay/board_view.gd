extends Node2D
class_name BoardView

var board_size: Vector2i = Vector2i(7, 7)
const CELL_SIZE: float = 78.0

func setup(p_size: Vector2i) -> void:
	board_size = p_size
	queue_redraw()

func _draw() -> void:
	var total_w = float(board_size.x) * CELL_SIZE
	var total_h = float(board_size.y) * CELL_SIZE
	
	var rect = Rect2(-total_w/2.0, -total_h/2.0, total_w, total_h)
	
	# Draw prominent concrete base/border
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = Color("f1f5f9") # Very light concrete
	base_style.set_corner_radius_all(24)
	base_style.shadow_color = Color(0,0,0,0.15)
	base_style.shadow_size = 12
	base_style.shadow_offset = Vector2(0, 16)
	
	# The base is slightly larger than the grid to act as a rim
	draw_style_box(base_style, rect.grow(16))
	
	# Draw main asphalt area
	var asphalt = StyleBoxFlat.new()
	asphalt.bg_color = Color("64748b") # Asphalt tone
	asphalt.set_corner_radius_all(12)
	draw_style_box(asphalt, rect.grow(2))
	
	var grid_col := Color("cbd5e1", 0.4)
	var line_width := 2.0
	
	# Draw Grid Lines
	for x in range(board_size.x + 1):
		var px = -total_w/2.0 + float(x) * CELL_SIZE
		draw_line(Vector2(px, -total_h/2.0), Vector2(px, total_h/2.0), grid_col, line_width)
		
	for y in range(board_size.y + 1):
		var py = -total_h/2.0 + float(y) * CELL_SIZE
		draw_line(Vector2(-total_w/2.0, py), Vector2(total_w/2.0, py), grid_col, line_width)
