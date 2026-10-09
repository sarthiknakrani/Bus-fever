import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

# Replace corner_radius_all = XX with set_corner_radius_all(XX)
code = re.sub(r"(\w+)\.corner_radius_all\s*=\s*(\d+)", r"\1.set_corner_radius_all(\2)", code)

with open("scripts/main.gd", "w") as f:
    f.write(code)
print("Fixed corner_radius_all")
