extends Node2D
class_name PlazaEnvironment

## 3D Garden Lawn Island (Inside Passenger Oval Loop)
## Clean, stylized 3D green garden island without clutter or oversized props.
## Features contoured lawn bedding, subtle manicured lawn striping, and clean cartoon green shrub accents.

var _island_draw_node: Node2D

func _ready() -> void:
	z_index = -3
	visible = true
	_build_garden_accents()

func _build_garden_accents() -> void:
	for c in get_children():
		c.queue_free()

	_island_draw_node = Node2D.new()
	_island_draw_node.name = "IslandLawnBed"
	_island_draw_node.draw.connect(_on_draw_island)
	add_child(_island_draw_node)

func _on_draw_island() -> void:
	var sx: float = 105.0
	var r: float = 62.0
	var cl := Vector2(-sx, 0.0)
	var cr := Vector2(sx, 0.0)
	var n_arc := 32

	var island_pts := PackedVector2Array()
	island_pts.append(Vector2(sx, -r))
	island_pts.append(Vector2(-sx, -r))
	for i in range(1, n_arc):
		var a = -PI / 2.0 - (float(i) / float(n_arc)) * PI
		island_pts.append(cl + Vector2(cos(a), sin(a)) * r)
	island_pts.append(Vector2(-sx, r))
	island_pts.append(Vector2(sx, r))
	for i in range(1, n_arc):
		var a = PI / 2.0 - (float(i) / float(n_arc)) * PI
		island_pts.append(cr + Vector2(cos(a), sin(a)) * r)

	# 1. Base vibrant clean lawn fill (#60ac39) matching lush garden
	_island_draw_node.draw_colored_polygon(island_pts, Color("60ac39"))

func _draw_neat_shrub(center: Vector2, rad: float) -> void:
	# Ground shadow
	_island_draw_node.draw_circle(center + Vector2(0, rad * 0.45), rad * 0.9, Color(0.04, 0.12, 0.04, 0.20))
	# Dark base
	_island_draw_node.draw_circle(center, rad * 0.95, Color("326210"))
	# Main foliage
	_island_draw_node.draw_circle(center + Vector2(-1, -rad * 0.15), rad * 0.85, Color("4e9018"))
	# Sunlit highlight
	_island_draw_node.draw_circle(center + Vector2(-rad * 0.2, -rad * 0.3), rad * 0.55, Color("7ecc2e"))
