import re

with open("scripts/ui/button_3d.gd", "r") as f:
    content = f.read()

old_face_z = r'''	var face_z = custom_depth / 2.0 \+ 1.0'''
new_face_z = r'''	var face_z = mesh.get_aabb().position.z + mesh.get_aabb().size.z + 1.0'''

content = re.sub(old_face_z, new_face_z, content)

with open("scripts/ui/button_3d.gd", "w") as f:
    f.write(content)

print("Fixed face_z using mesh AABB")
