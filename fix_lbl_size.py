import re

with open("scripts/ui/button_3d.gd", "r") as f:
    content = f.read()

old_lbl = r'''		label_3d = Label3D\.new\(\)
		label_3d\.text = text
		label_3d\.font_size = 64 if icon_path == "" else 32
		label_3d\.outline_size = 8
		label_3d\.position = Vector3\(0, 0, face_z\)'''

new_lbl = r'''		label_3d = Label3D.new()
		label_3d.text = text
		label_3d.pixel_size = 1.0
		# If the button is 80 units high, a 36-unit font is nicely proportioned (about 45% of height)
		# For pause buttons (56 high), 24 is nicely proportioned.
		label_3d.font_size = int(size_2d.y * 0.45) if icon_path == "" else int(size_2d.y * 0.25)
		label_3d.outline_size = max(2, int(label_3d.font_size * 0.2))
		label_3d.position = Vector3(0, 0, face_z)
		label_3d.modulate = Color("ffffff")
		
		# User requested "dark-blue extrusion/shadow" for Home Play, "dark green" for Pause Play, "dark orange" for Home
		var outline_col = Color("1e3a8a") # default dark blue
		if "22c55e" in base_color.to_html(): outline_col = Color("064e3b") # dark green
		if "f97316" in base_color.to_html(): outline_col = Color("7c2d12") # dark orange/brown
		label_3d.outline_modulate = outline_col'''

content = re.sub(old_lbl, new_lbl, content)

with open("scripts/ui/button_3d.gd", "w") as f:
    f.write(content)

print("Fixed Label3D sizing and colors")
