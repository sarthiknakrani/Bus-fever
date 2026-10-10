import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

content = content.replace('gc.start_level(1)', 'gc.start_level(gc.current_level_number)')

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("Restart patched")
