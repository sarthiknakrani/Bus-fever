import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

replacement = """
	# Procedural Coin Counter Button
	var coin_btn := Button.new()
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color("eef2ff") # very light blue/white
	c_style.border_width_bottom = 6
	c_style.border_color = Color("d1d5db") # gray shadow
	c_style.corner_radius_top_left = 30
	c_style.corner_radius_top_right = 30
	c_style.corner_radius_bottom_left = 30
	c_style.corner_radius_bottom_right = 30
	c_style.shadow_color = Color(0, 0, 0, 0.2)
	c_style.shadow_size = 4
	c_style.shadow_offset = Vector2(0, 4)
	
	var cp_style = c_style.duplicate()
	cp_style.border_width_bottom = 2
	cp_style.shadow_offset = Vector2(0, 2)
	cp_style.content_margin_top = 4

	coin_btn.add_theme_stylebox_override("normal", c_style)
	coin_btn.add_theme_stylebox_override("hover", c_style)
	coin_btn.add_theme_stylebox_override("pressed", cp_style)
	coin_btn.add_theme_stylebox_override("focus", c_style)
	
	coin_btn.custom_minimum_size = Vector2(160, 60) # Only the pill part
	coin_btn.anchor_left = 0.0
	coin_btn.anchor_top = 0.0
	coin_btn.offset_left = 60.0
	coin_btn.offset_top = 40.0
	
	coin_btn.pressed.connect(_on_coins_pressed)
	
	# Add the dynamic text label INSIDE the button (shifted right)
	var coin_lbl := Label.new()
	coin_lbl.text = "%02d" % SaveManager.get_coins()
	coin_lbl.add_theme_font_size_override("font_size", 32)
	coin_lbl.add_theme_color_override("font_color", Color("1e3a8a"))
	coin_lbl.anchor_right = 1.0
	coin_lbl.anchor_bottom = 1.0
	coin_lbl.offset_left = 30
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_btn.add_child(coin_lbl)
	
	root.add_child(coin_btn)
	
	# Add the pure coin icon overlapping the left side!
	# We make it ignore mouse so clicks go to the button.
	var coin_icon = TextureRect.new()
	coin_icon.texture = load("res://assets/pure_coin.png")
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.custom_minimum_size = Vector2(90, 100)
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_icon.position = Vector2(-40, -20)
	coin_btn.add_child(coin_icon)
"""

code = re.sub(r'\t# Coin Counter Button[\s\S]*?root\.add_child\(coin_rect\)', replacement.strip('\n'), code, count=1)

with open("scripts/main.gd", "w") as f:
    f.write(code)

print("Patched main.gd with procedural coin.")
