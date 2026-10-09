import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

code = code.replace("var platform_bg: PlatformView", "var platform_bg: Node2D")
code = code.replace("PlatformView.new()", "load(\"res://scripts/gameplay/platform_view.gd\").new()")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)
print("Fixed class reference!")
