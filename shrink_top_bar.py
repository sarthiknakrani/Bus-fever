import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# Shrink top bar height slightly
code = code.replace("top_bar.offset_bottom = 90.0", "top_bar.offset_bottom = 64.0")

# Shrink restart button
code = code.replace('btn_restart.add_theme_font_size_override("font_size", 36)', 'btn_restart.add_theme_font_size_override("font_size", 24)')
code = code.replace('btn_restart.custom_minimum_size = Vector2(60, 60)', 'btn_restart.custom_minimum_size = Vector2(44, 44)')

# Shrink Level 1 text (making it much smaller proportionally)
code = code.replace('level_title_label.add_theme_font_size_override("font_size", 48)', 'level_title_label.add_theme_font_size_override("font_size", 30)')
code = code.replace('level_title_label.add_theme_constant_override("outline_size", 8)', 'level_title_label.add_theme_constant_override("outline_size", 6)')

# Shrink pause button
code = code.replace('btn_pause.add_theme_font_size_override("font_size", 28)', 'btn_pause.add_theme_font_size_override("font_size", 18)')
code = code.replace('btn_pause.custom_minimum_size = Vector2(60, 60)', 'btn_pause.custom_minimum_size = Vector2(44, 44)')
code = code.replace('btn_pause.offset_left = -76.0', 'btn_pause.offset_left = -44.0')

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)
print("Updated top bar sizes!")
