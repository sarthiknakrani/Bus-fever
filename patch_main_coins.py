import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

replacement = """
	# Coin Counter
	var coin_rect := TextureRect.new()
	coin_rect.texture = load("res://assets/coin_counter_empty.png")
	coin_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_rect.custom_minimum_size = Vector2(220, 75)
	
	coin_rect.anchor_left = 0.0
	coin_rect.anchor_top = 0.0
	coin_rect.offset_left = 24.0
	coin_rect.offset_top = 28.0
	
	# Add dynamic label on top of the empty pill
	var coin_lbl := Label.new()
	# The user asked for "00" instead of "0" when coins are 0
	coin_lbl.text = "%02d" % SaveManager.get_coins()
	coin_lbl.add_theme_font_size_override("font_size", 36)
	coin_lbl.add_theme_color_override("font_color", Color("1d4ed8")) # dark blue matching the original
	coin_lbl.anchor_right = 1.0
	coin_lbl.anchor_bottom = 1.0
	# Shift right to align within the white pill part
	coin_lbl.offset_left = 60
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_rect.add_child(coin_lbl)
	
	root.add_child(coin_rect)
"""

code = re.sub(r'\t# Coin Counter[\s\S]*?root\.add_child\(coin_rect\)', replacement.strip('\n'), code, count=1)

with open("scripts/main.gd", "w") as f:
    f.write(code)

print("Patched main.gd coins.")
