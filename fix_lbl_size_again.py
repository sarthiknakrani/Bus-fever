import re

with open("scripts/ui/button_3d.gd", "r") as f:
    content = f.read()

old_lbl = r'''		label_3d\.font_size = int\(size_2d\.y \* 0\.45\) if icon_path == "" else int\(size_2d\.y \* 0\.25\)'''
new_lbl = r'''		label_3d.font_size = int(size_2d.y * 0.35) if icon_path == "" else int(size_2d.y * 0.20)'''

content = re.sub(old_lbl, new_lbl, content)

with open("scripts/ui/button_3d.gd", "w") as f:
    f.write(content)

print("Fixed Label3D sizing again")
