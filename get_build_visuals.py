with open("scripts/gameplay/vehicle_view.gd", "r") as f:
    in_build = False
    for line in f:
        if "func _build_visuals()" in line:
            in_build = True
        if in_build:
            print(line.rstrip())
            if "func " in line and "func _build_visuals" not in line:
                break
