import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

content = content.replace('"res://assets/ui/buttons/settings_gear_normal.svg"', '"res://assets/ui/buttons/icon_settings.svg"')

with open("scripts/main.gd", "w") as f:
    f.write(content)

print("Fixed settings gear icon path in main.gd")
