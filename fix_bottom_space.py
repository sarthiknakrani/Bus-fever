import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# Fix booster_bar offsets
code = code.replace('booster_bar.offset_top = -160.0', 'booster_bar.offset_top = -90.0')
code = code.replace('booster_bar.offset_bottom = -20.0', 'booster_bar.offset_bottom = -10.0')

# Fix layout reservation space
code = code.replace('var bottom_ui_top_y = half_h - (240.0 / scale_factor)', 'var bottom_ui_top_y = half_h - (120.0 / scale_factor)')

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Bottom space reduced!")
