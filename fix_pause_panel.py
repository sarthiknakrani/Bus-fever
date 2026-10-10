import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

content = content.replace('p_panel.custom_minimum_size = Vector2(300, 360)', 'p_panel.custom_minimum_size = Vector2(300, 180)')

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("Fixed pause panel height")
