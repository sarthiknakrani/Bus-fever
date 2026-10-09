with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()
code = code.replace("top_bar.offset_bottom = 64.0", "top_bar.offset_bottom = 68.0")
with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)
print("Fixed top_bar height!")
