import re

with open("scripts/gameplay/passenger_view.gd", "r") as f:
    code = f.read()

replacement = """func _draw() -> void:
	# 1. Ground shadow
	draw_ellipse(Vector2(0, 22), 16.0, 6.0, Color(0, 0, 0, 0.28))

	# 2. Sneakers
	draw_circle(Vector2(-7, 18), 5.0, Color.WHITE)
	draw_circle(Vector2(7, 18), 5.0, Color.WHITE)

	# 3. Denim Pants
	draw_rect(Rect2(-8, 6, 16, 12), Color("1e293b"), true)

	# 4. Body (Shirt)
	draw_rect(Rect2(-10, -10, 20, 18), _color, true)
	
	# Shirt collar/details
	draw_circle(Vector2(0, -9), 4.0, _color.lightened(0.2))

	# 5. Head
	var head_c = Color("ffedd5") # Skin tone
	draw_circle(Vector2(0, -18), 9.0, head_c)
	
	# Hair (simple colored cap or hair blob)
	draw_ellipse(Vector2(0, -22), 9.5, 6.0, _color.darkened(0.4))
"""

code = re.sub(r'func _draw\(\) -> void:.*?draw_ellipse\(Vector2\(0, -13\), 5\.5, 3\.5, _color\.darkened\(0\.4\)\)', replacement, code, flags=re.DOTALL)

with open("scripts/gameplay/passenger_view.gd", "w") as f:
    f.write(code)

print("Scaled up passengers")
