import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

content = content.replace('SceneManager.change_scene("res://scenes/car_jam_level.tscn")', 'GameController.start_level(1)')

with open("scripts/main.gd", "w") as f:
    f.write(content)

print("Fixed SceneManager to GameController")
