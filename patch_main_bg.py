import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

# Replace bg
bg_replacement = """	# Full-screen background image
	var bg := TextureRect.new()
	bg.texture = load("res://assets/home_bg_clean.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
"""
code = re.sub(r'	# Full-screen background[\s\S]*?root\.add_child\(bg\)', bg_replacement.strip('\n'), code)

# Replace title
title_replacement = """	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.text = "[center][color=#f97316][b]Bus[/b][/color]\\n[color=#3b82f6][b]Fever Party![/b][/color][/center]"
	title.add_theme_font_size_override("normal_font_size", 64)
	title.add_theme_font_size_override("bold_font_size", 64)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color("1e293b"))
	title.add_theme_constant_override("outline_size", 12)
	title.custom_minimum_size = Vector2(0, 160)
	title.clip_contents = false
	title_box.add_child(title)"""

code = re.sub(r'	var title := Label\.new\(\)[\s\S]*?title_box\.add_child\(title\)', title_replacement.strip('\n'), code)

with open("scripts/main.gd", "w") as f:
    f.write(code)

print("Patched main.gd with background and title.")
