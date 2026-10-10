import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

content = content.replace('GameController.start_level(1)', 'GameController.start_level(GameController.current_level_number)')

with open("scripts/main.gd", "w") as f:
    f.write(content)

print("Main patched")
