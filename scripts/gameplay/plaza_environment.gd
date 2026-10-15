extends Node2D
class_name PlazaEnvironment

## Tasteful Stylized Garden Environment
## Zero photo stickers, zero floating thumbnails.
## Clean, lightweight vector accents for the garden/park area.

func _ready() -> void:
	visible = true
	set_process(false)
	set_physics_process(false)
	_build_garden_accents()

func _build_garden_accents() -> void:
	# Clean any old nodes
	for c in get_children():
		c.queue_free()

	# Completely removed garden_left.png sticker.
	# The stylized park lawn and perimeter cartoon hedges are rendered
	# procedurally by GardenBackgroundView behind the track.
