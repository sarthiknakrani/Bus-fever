import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

content = content.replace("GameController.go_home()", "GameController.goto_scene(\"res://scenes/main.tscn\")")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("Fixed Home button crash")
