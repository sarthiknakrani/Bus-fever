import re

with open("scripts/ui/button_3d.gd", "r") as f:
    content = f.read()

# Add own_world_3d = true
if "viewport.own_world_3d = true" not in content:
    content = content.replace("viewport.transparent_bg = true", "viewport.transparent_bg = true\n\tviewport.own_world_3d = true")

with open("scripts/ui/button_3d.gd", "w") as f:
    f.write(content)

print("Fixed own_world_3d")
