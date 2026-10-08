import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

booster_replacement = """
	for b_name in ["VIP", "Arrange", "Jumble"]:
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		
		# Base button uses procedural style to remain crisp and clean
		var btn := Button.new()
		btn.add_theme_stylebox_override("normal", bst_style)
		btn.add_theme_stylebox_override("hover", bst_style)
		btn.add_theme_stylebox_override("pressed", bst_pressed)
		btn.add_theme_stylebox_override("disabled", bst_style)
		btn.disabled = true
		btn.custom_minimum_size = Vector2(100, 100)
		
		# Clean icon
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
		btn.add_child(icon_rect)
		
		# Add a green '+' circle
		var plus := Label.new()
		plus.text = "✚"
		plus.add_theme_font_size_override("font_size", 18)
		plus.add_theme_color_override("font_color", Color("ffffff"))
		plus.add_theme_color_override("font_outline_color", Color("166534"))
		plus.add_theme_constant_override("outline_size", 4)
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("22c55e")
		p_style.corner_radius_top_left = 20
		p_style.corner_radius_top_right = 20
		p_style.corner_radius_bottom_left = 20
		p_style.corner_radius_bottom_right = 20
		p_style.border_width_bottom = 2
		p_style.border_color = Color("16a34a")
		plus.add_theme_stylebox_override("normal", p_style)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.size = Vector2(28, 28)
		plus.position = Vector2(80, -8)
		btn.add_child(plus)
		
		vbox.add_child(btn)
		
		var lbl = Label.new()
		lbl.text = b_name
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color("ffffff"))
		lbl.add_theme_color_override("font_outline_color", Color("1e293b"))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)
		
		b_hbox.add_child(vbox)
"""
code = re.sub(r'\tfor b_name in \["VIP", "Arrange", "Jumble"\]:[\s\S]*?b_hbox\.add_child\(btn\)', booster_replacement.strip('\n'), code, count=1)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Patched Boosters.")
