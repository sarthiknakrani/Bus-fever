import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

bad_block = """	for b_name in ["VIP", "Arrange", "Jumble"]:
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)

		var btn := TextureButton.new()
		var tex_path = "res://assets/btn_" + b_name.to_lower() + ".png"
		if ResourceLoader.exists(tex_path):
			var tex = ResourceLoader.load(tex_path)
			btn.texture_normal = tex
			btn.texture_pressed = tex
			btn.texture_disabled = tex
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		else:
			# fallback
			pass
			
		btn.disabled = true
		btn.custom_minimum_size = Vector2(72, 72)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Add a green '+' circle
		var plus := Label.new()
		plus.text = "✚"
		plus.add_theme_font_size_override("font_size", 14)
		plus.add_theme_color_override("font_color", Color("ffffff"))
		plus.add_theme_color_override("font_outline_color", Color("166534"))
		plus.add_theme_constant_override("outline_size", 4)
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("22c55e")
		p_style.corner_radius_top_left = 12
		p_style.corner_radius_top_right = 12
		p_style.corner_radius_bottom_left = 12
		p_style.corner_radius_bottom_right = 12
		p_style.border_width_bottom = 2
		p_style.border_color = Color("16a34a")
		plus.add_theme_stylebox_override("normal", p_style)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.size = Vector2(24, 24)
		plus.position = Vector2(55, -6)
		btn.add_child(plus)
		
		vbox.add_child(btn)"""

good_block = """	for b_name in ["VIP", "Arrange", "Jumble"]:
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)

		# Base button uses procedural style to remain crisp and clean
		var btn := Button.new()
		btn.add_theme_stylebox_override("normal", bst_style)
		btn.add_theme_stylebox_override("hover", bst_style)
		btn.add_theme_stylebox_override("pressed", bst_pressed)
		btn.add_theme_stylebox_override("disabled", bst_style)
		btn.disabled = true
		btn.custom_minimum_size = Vector2(52, 52)
		

		
		# Add a green '+' circle
		var plus := Label.new()
		plus.text = "✚"
		plus.add_theme_font_size_override("font_size", 14)
		plus.add_theme_color_override("font_color", Color("ffffff"))
		plus.add_theme_color_override("font_outline_color", Color("166534"))
		plus.add_theme_constant_override("outline_size", 4)
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("22c55e")
		p_style.corner_radius_top_left = 12
		p_style.corner_radius_top_right = 12
		p_style.corner_radius_bottom_left = 12
		p_style.corner_radius_bottom_right = 12
		p_style.border_width_bottom = 2
		p_style.border_color = Color("16a34a")
		plus.add_theme_stylebox_override("normal", p_style)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.size = Vector2(21, 21)
		plus.position = Vector2(41, -6)
		btn.add_child(plus)
		
		vbox.add_child(btn)"""

if bad_block in content:
    content = content.replace(bad_block, good_block)
    print("Successfully reverted boosters.")
else:
    print("Could not find bad block!")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

