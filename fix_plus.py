import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

code = code.replace("plus.position = Vector2(80, -8)", "plus.position = Vector2(56, -8)")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed plus icon position!")
