with open("scripts/gameplay/plaza_environment.gd", "r") as f:
    code = f.read()
code = code.replace("Vector2(-150, 0)", "Vector2(-170, 0)")
code = code.replace("Vector2(150, 0)", "Vector2(170, 0)")
with open("scripts/gameplay/plaza_environment.gd", "w") as f:
    f.write(code)
