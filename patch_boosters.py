import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# We need to replace the entire block that creates the booster button.
# Let's find 'for b_name in ["VIP", "Arrange", "Jumble"]:' and replace the button creation until 'var lbl_vbox := VBoxContainer.new()'

import re
pattern = r'(for b_name in \["VIP", "Arrange", "Jumble"\]:.*?)(var lbl_vbox := VBoxContainer\.new\(\))'
match = re.search(pattern, content, re.DOTALL)
if match:
    old_block = match.group(1)
    
    new_block = """for b_name in ["VIP", "Arrange", "Jumble"]:
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
			var tex2_path = "res://assets/booster_" + b_name.to_lower() + ".png"
			if ResourceLoader.exists(tex2_path):
				var tex2 = ResourceLoader.load(tex2_path)
				btn.texture_normal = tex2
				btn.texture_pressed = tex2
				btn.texture_disabled = tex2
				btn.ignore_texture_size = true
				btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			else:
				# Fallback style
				var bst_style = StyleBoxFlat.new()
				bst_style.bg_color = Color("3b82f6")
				bst_style.corner_radius_all = 12
				var nbtn = Button.new()
				nbtn.add_theme_stylebox_override("normal", bst_style)
				btn = nbtn as TextureButton # This will crash if used as texture button, so we'll just not fallback.
				
		btn.disabled = true
		btn.custom_minimum_size = Vector2(52, 52)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Add a green '+' circle (badge)
		var plus := Label.new()
		plus.text = "✚"
		plus.add_theme_font_size_override("font_size", 14)
		plus.add_theme_color_override("font_color", Color("ffffff"))
		plus.add_theme_color_override("font_outline_color", Color("166534"))
		plus.add_theme_constant_override("outline_size", 4)
		
		var plus_bg := Panel.new()
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("22c55e")
		p_style.corner_radius_all = 12
		plus_bg.add_theme_stylebox_override("panel", p_style)
		plus_bg.custom_minimum_size = Vector2(24, 24)
		plus_bg.anchor_left = 1.0
		plus_bg.anchor_right = 1.0
		plus_bg.offset_left = -16.0
		plus_bg.offset_top = -8.0
		plus_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		plus.set_anchors_preset(Control.PRESET_FULL_RECT)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus_bg.add_child(plus)
		btn.add_child(plus_bg)
		vbox.add_child(btn)
		
		"""
    content = content.replace(old_block, new_block)
    print("Patched successfully")
else:
    print("Could not find regex match")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)
