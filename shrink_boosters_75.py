import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# Shrink Extruded Style Depth and Radius
code = code.replace('SimpleStyle.make_extruded_style(\n\t\tColor("38bdf8"), Color("1e3a8a"), 22, 10, 0)', 
                    'SimpleStyle.make_extruded_style(\n\t\tColor("38bdf8"), Color("1e3a8a"), 16, 7, 0)')
code = code.replace('SimpleStyle.make_extruded_style(\n\t\tColor("38bdf8"), Color("1e3a8a"), 22, 5, 6, 5)', 
                    'SimpleStyle.make_extruded_style(\n\t\tColor("38bdf8"), Color("1e3a8a"), 16, 3, 4, 3)')

# Fallbacks if regex slightly misses indentation
code = code.replace(', 22, 10, 0)', ', 16, 7, 0)')
code = code.replace(', 22, 5, 6, 5)', ', 16, 3, 4, 3)')

# Shrink minimum size
code = code.replace('btn.custom_minimum_size = Vector2(70, 70)', 'btn.custom_minimum_size = Vector2(52, 52)')

# Shrink Plus Badge Font and bounds
code = code.replace('plus.add_theme_font_size_override("font_size", 18)', 'plus.add_theme_font_size_override("font_size", 14)')
code = code.replace('plus.size = Vector2(28, 28)', 'plus.size = Vector2(21, 21)')
code = code.replace('plus.position = Vector2(56, -8)', 'plus.position = Vector2(41, -6)')

# Shrink Plus Badge Corner Radius
code = code.replace('p_style.corner_radius_top_left = 20', 'p_style.corner_radius_top_left = 12')
code = code.replace('p_style.corner_radius_top_right = 20', 'p_style.corner_radius_top_right = 12')
code = code.replace('p_style.corner_radius_bottom_left = 20', 'p_style.corner_radius_bottom_left = 12')
code = code.replace('p_style.corner_radius_bottom_right = 20', 'p_style.corner_radius_bottom_right = 12')

# Shrink Label Font
code = code.replace('lbl.add_theme_font_size_override("font_size", 20)', 'lbl.add_theme_font_size_override("font_size", 15)')
code = code.replace('lbl.add_theme_constant_override("outline_size", 6)', 'lbl.add_theme_constant_override("outline_size", 4)')

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Boosters shrunk to ~75%!")
