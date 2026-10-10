import re
with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    content = f.read()

content = content.replace("Color(0, 0, 0, 0.75), 3.0", "Color.BLACK, 5.0")

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(content)
print("Arrow outline made bolder.")
