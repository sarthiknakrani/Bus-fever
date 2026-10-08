import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

replacement = """
	# Coin Counter Button
	var coin_rect := TextureButton.new()
	coin_rect.texture_normal = load("res://assets/coin_counter_empty.png")
	coin_rect.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	coin_rect.custom_minimum_size = Vector2(220, 75)
	
	coin_rect.button_down.connect(func(): coin_rect.position.y += 4)
	coin_rect.button_up.connect(func(): coin_rect.position.y -= 4)
	coin_rect.pressed.connect(_on_coins_pressed)
	
	coin_rect.anchor_left = 0.0
	coin_rect.anchor_top = 0.0
	coin_rect.offset_left = 24.0
	coin_rect.offset_top = 28.0
	
	# Add dynamic label on top of the empty pill
	var coin_lbl := Label.new()
	coin_lbl.text = "%02d" % SaveManager.get_coins()
	coin_lbl.add_theme_font_size_override("font_size", 36)
	coin_lbl.add_theme_color_override("font_color", Color("1d4ed8"))
	coin_lbl.anchor_right = 1.0
	coin_lbl.anchor_bottom = 1.0
	coin_lbl.offset_left = 60
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_rect.add_child(coin_lbl)
	
	root.add_child(coin_rect)
"""

code = re.sub(r'\t# Coin Counter[\s\S]*?root\.add_child\(coin_rect\)', replacement.strip('\n'), code, count=1)

# Add _on_coins_pressed function at the end
if "func _on_coins_pressed" not in code:
    code += """
func _on_coins_pressed() -> void:
	AudioManager.play(AudioManager.SFX_UI)
	print("Coins button clicked! Shop coming soon.")
"""

with open("scripts/main.gd", "w") as f:
    f.write(code)

print("Patched main.gd coin button.")
