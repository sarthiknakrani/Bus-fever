import re

with open("scripts/main.gd", "r") as f:
    main_code = f.read()

coin_code = """
	# Coin Counter
	var coin_rect := TextureRect.new()
	coin_rect.texture = preload("res://assets/coin_counter.png")
	coin_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_rect.custom_minimum_size = Vector2(220, 75)
	
	coin_rect.anchor_left = 0.0
	coin_rect.anchor_top = 0.0
	coin_rect.offset_left = 24.0
	coin_rect.offset_top = 28.0
	root.add_child(coin_rect)

	# Top right settings button
"""

main_code = main_code.replace("\t# Top right settings button\n", coin_code)

with open("scripts/main.gd", "w") as f:
    f.write(main_code)

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    level_code = f.read()

booster_icon_code = """
		var btn := Button.new()
		btn.add_theme_stylebox_override("normal", bst_style)
		btn.add_theme_stylebox_override("hover", bst_style)
		btn.add_theme_stylebox_override("pressed", bst_pressed)
		btn.add_theme_stylebox_override("disabled", bst_style) # they are locked, but look the same
		btn.disabled = true
		btn.custom_minimum_size = Vector2(100, 100)
		
		var icon_name = "icon_car.png" if b_name == "VIP" else ("icon_bus.png" if b_name == "Arrange" else "icon_ball.png")
		var icon_rect = TextureRect.new()
		icon_rect.texture = load("res://assets/" + icon_name)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 12
		icon_rect.offset_right = -12
		icon_rect.offset_top = 12
		icon_rect.offset_bottom = -12
		btn.add_child(icon_rect)
"""
level_code = re.sub(r'\t\tvar btn := Button\.new\(\)[\s\S]*?btn\.custom_minimum_size = Vector2\(100, 100\)', booster_icon_code.strip('\n'), level_code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(level_code)

print("Patched UI!")
