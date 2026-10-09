import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# Shrink the depth from 7 to 4, and pressed from 3 to 2
code = code.replace("Color(\"1e3a8a\"), 14, 7, 4", "Color(\"1e3a8a\"), 12, 4, 2")
code = code.replace("Color(\"1e3a8a\"), 14, 3, 2, 4", "Color(\"1e3a8a\"), 12, 2, 1, 2")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)
print("Updated button depths!")
