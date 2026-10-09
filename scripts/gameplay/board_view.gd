extends Node2D
class_name BoardView

var board_size: Vector2i = Vector2i(7, 7)
const CELL_SIZE: float = 78.0

func setup(p_size: Vector2i) -> void:
	board_size = p_size
	queue_redraw()

func _draw() -> void:
	pass
