import re

for file in ["scripts/main.gd", "scripts/gameplay/car_jam_level.gd"]:
    with open(file, "r") as f:
        c = f.read()
    
    # move const Button3D AFTER class_name
    c = c.replace('extends Node2D\n\nconst Button3D = preload("res://scripts/ui/button_3d.gd")\nclass_name ', 'extends Node2D\nclass_name ')
    
    match = re.search(r'class_name \w+', c)
    if match:
        c = c.replace(match.group(0), match.group(0) + '\n\nconst Button3D = preload("res://scripts/ui/button_3d.gd")')
    elif "const Button3D" not in c:
        c = c.replace("extends Node2D", "extends Node2D\n\nconst Button3D = preload(\"res://scripts/ui/button_3d.gd\")")
        
    with open(file, "w") as f:
        f.write(c)

print("Fixed class_name order")
