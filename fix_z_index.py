import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

# Make platform render strictly behind the board_root
code = code.replace("platform_bg.name = \"PlatformBackground\"", "platform_bg.name = \"PlatformBackground\"\n\tplatform_bg.z_index = -5")

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)
print("Fixed z_index of platform!")
