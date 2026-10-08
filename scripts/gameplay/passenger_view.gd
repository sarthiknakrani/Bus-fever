extends Node2D
class_name PassengerView

## Chibi 2D Passenger Visual Node.
## Renders stylized casual character with hoodie, jeans, sneakers, anime eyes, and cap.

var color_id: String = "blue"
var passenger_color: Color = Color("3b82f6")

func setup(p_col_id: String) -> void:
	color_id = p_col_id
	passenger_color = CarJamVehicleData.color_to_rgb(p_col_id)
	queue_redraw()

func _draw() -> void:
	# 1. Ground shadow
	draw_ellipse(Vector2(0, 13), 9.0, 3.5, Color(0, 0, 0, 0.28))

	# 2. Sneakers
	draw_circle(Vector2(-4, 11), 3.0, Color.WHITE)
	draw_circle(Vector2(4, 11), 3.0, Color.WHITE)

	# 3. Denim Pants
	draw_rect(Rect2(-5, 4, 10, 7), Color("1e293b"), true)

	# 4. Color Hoodie / Torso
	draw_rect(Rect2(-7, -4, 14, 9), passenger_color, true, -1, true)
	draw_circle(Vector2(0, -4), 2.8, Color.WHITE) # Collar

	# 5. Head (Skin tone)
	var skin_col := Color("fed7aa")
	draw_circle(Vector2(0, -11), 8.5, skin_col)

	# 6. Anime Eyes & Specular Highlights
	draw_circle(Vector2(-3, -11), 1.5, Color("0f172a"))
	draw_circle(Vector2(3, -11), 1.5, Color("0f172a"))
	draw_circle(Vector2(-2.5, -11.5), 0.5, Color.WHITE)
	draw_circle(Vector2(3.5, -11.5), 0.5, Color.WHITE)

	# Blush
	draw_circle(Vector2(-5, -8.5), 1.8, Color("fb7185"))
	draw_circle(Vector2(5, -8.5), 1.8, Color("fb7185"))

	# 7. Cap with Visor Brim
	var cap_col := passenger_color.darkened(0.20)
	draw_arc(Vector2(0, -11), 8.5, PI, 0.0, 16, cap_col, 3.5)
	draw_rect(Rect2(-6, -13, 12, 2.5), cap_col.darkened(0.15), true)
