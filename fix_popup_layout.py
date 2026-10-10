import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

content = content.replace('p_panel.custom_minimum_size = Vector2(300, 180)', 'p_panel.custom_minimum_size = Vector2(280, 150)')
content = content.replace('pb_vbox.add_theme_constant_override("separation", 16)', 'pb_vbox.add_theme_constant_override("separation", 12)')

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("Fixed pause popup layout")
