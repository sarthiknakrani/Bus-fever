import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# 1. Shrink boosters and remove images
# btn.custom_minimum_size = Vector2(100, 100) -> Vector2(70, 70)
code = code.replace("btn.custom_minimum_size = Vector2(100, 100)", "btn.custom_minimum_size = Vector2(70, 70)")

# Remove icon rect logic
icon_logic = """		# Clean icon
		var icon_name = "icon_car_clean.png" if b_name == "VIP" else ("icon_bus_clean.png" if b_name == "Arrange" else "icon_ball_clean.png")
		var icon_rect = TextureRect.new()
		icon_rect.texture = load("res://assets/" + icon_name)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		# slightly smaller to fit in the box nicely
		icon_rect.offset_left = 12
		icon_rect.offset_right = -12
		icon_rect.offset_top = 12
		icon_rect.offset_bottom = -16
		btn.add_child(icon_rect)"""
code = code.replace(icon_logic, "")


# 2. Fix board_y centering
old_board_y = "var board_y = parking_y + (parking_h / 2.0) + gap + (board_pixel_h / 2.0)"
new_board_y = """var bottom_ui_top_y = half_h - (240.0 / scale_factor)
	var parking_bottom_y = parking_y + (parking_h / 2.0)
	var board_y = (parking_bottom_y + bottom_ui_top_y) / 2.0"""
code = code.replace(old_board_y, new_board_y)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed layout and boosters!")
