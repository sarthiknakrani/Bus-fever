with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()
code = code.replace("p_close.offset_top = -22.0", "p_close.offset_top = 8.0")
with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)
