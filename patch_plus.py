import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# Update the paths to the icon
content = content.replace('"icon": "res://assets/btn_vip.png"', '"icon": "res://assets/ui/gameplay_buttons/icon_vip.png"')
content = content.replace('"icon": "res://assets/btn_arrange.png"', '"icon": "res://assets/ui/gameplay_buttons/icon_arrange.png"')
content = content.replace('"icon": "res://assets/btn_jumble.png"', '"icon": "res://assets/ui/gameplay_buttons/icon_jumble.png"')


# Replace plus badge styling
plus_old = r'''		plus\.add_theme_font_size_override\("font_size", 14\)
		plus\.add_theme_color_override\("font_color", Color\("ffffff"\)\)
		plus\.add_theme_color_override\("font_outline_color", Color\("064e3b"\)\)
		plus\.add_theme_constant_override\("outline_size", 4\)
		
		var p_style = StyleBoxFlat\.new\(\)
		p_style\.bg_color = Color\("22c55e"\)
		p_style\.corner_radius_top_left = 12
		p_style\.corner_radius_top_right = 12
		p_style\.corner_radius_bottom_left = 12
		p_style\.corner_radius_bottom_right = 12
		p_style\.border_width_bottom = 3
		p_style\.border_color = Color\("14532d"\)
		p_style\.border_blend = false
		p_style\.shadow_color = Color\(0, 0, 0, 0\.5\)
		p_style\.shadow_size = 2
		p_style\.shadow_offset = Vector2\(0, 2\)
		plus\.add_theme_stylebox_override\("normal", p_style\)
		
		plus\.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus\.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus\.size = Vector2\(24, 24\)
		plus\.position = Vector2\(36, -6\)'''

plus_new = r'''		plus.add_theme_font_size_override("font_size", 11)
		plus.add_theme_color_override("font_color", Color("ffffff"))
		plus.add_theme_color_override("font_outline_color", Color("064e3b"))
		plus.add_theme_constant_override("outline_size", 3)
		
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("22c55e")
		p_style.corner_radius_top_left = 9
		p_style.corner_radius_top_right = 9
		p_style.corner_radius_bottom_left = 9
		p_style.corner_radius_bottom_right = 9
		p_style.border_width_bottom = 2
		p_style.border_color = Color("14532d")
		p_style.border_blend = false
		p_style.shadow_color = Color(0, 0, 0, 0.5)
		p_style.shadow_size = 1
		p_style.shadow_offset = Vector2(0, 1)
		plus.add_theme_stylebox_override("normal", p_style)
		
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.size = Vector2(18, 18)
		plus.position = Vector2(40, -4)'''

content = re.sub(plus_old, plus_new, content)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)
print("Updated badge and paths")
