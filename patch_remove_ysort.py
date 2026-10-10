import re
with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

content = content.replace("vehicle_layer.y_sort_enabled = true", "")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)
print("Removed y_sort_enabled.")
