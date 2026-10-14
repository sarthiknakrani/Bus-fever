extends Node2D

class_name PlazaEnvironment

## Tasteful Garden Environment
## Renders lush greenery and garden accents flanking the passenger oval.

func _ready() -> void:
	visible = true
	set_process(false)
	set_physics_process(false)
	_build_garden_accents()

func _build_garden_accents() -> void:
	# Clear existing children if any
	for c in get_children():
		c.queue_free()

	# Upper-left garden corner (outside oval left apex and top straight)
	var left_tex = ResourceLoader.load("res://assets/sprites/premium_plaza/garden_left.png") as Texture2D
	if left_tex:
		var garden_l = Sprite2D.new()
		garden_l.name = "GardenLeft"
		garden_l.texture = left_tex
		garden_l.scale = Vector2(0.28, 0.28)
		garden_l.position = Vector2(-265, -210)
		garden_l.z_index = -3
		add_child(garden_l)

