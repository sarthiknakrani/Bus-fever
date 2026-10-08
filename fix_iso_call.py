import re

with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    code = f.read()

code = code.replace("to_iso(", "to_iso.call(")

with open("scripts/gameplay/vehicle_view.gd", "w") as f:
    f.write(code)

print("Fixed to_iso.call")
