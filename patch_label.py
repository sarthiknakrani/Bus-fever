import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

old_label_code = """	var ls_play = LabelSettings.new()
	ls_play.font_size = 46
	ls_play.font_color = Color.WHITE
	ls_play.outline_size = 6
	ls_play.outline_color = Color("1e3a8a")
	ls_play.shadow_size = 4
	ls_play.shadow_color = Color(0, 0, 0, 0.4)
	ls_play.shadow_offset = Vector2(0, 3)
	p_lbl.label_settings = ls_play"""

new_label_code = """	var ls_play = LabelSettings.new()
	ls_play.font_size = 52
	ls_play.font_color = Color("f8fafc") # Very light grey / white
	ls_play.outline_size = 16
	ls_play.outline_color = Color("1e3a8a") # Dark blue outline
	ls_play.shadow_size = 0 # Sharp extrusion
	ls_play.shadow_color = Color("0f172a") # Almost black/navy for bottom extrusion depth
	ls_play.shadow_offset = Vector2(0, 6)
	p_lbl.label_settings = ls_play"""

if old_label_code in content:
    content = content.replace(old_label_code, new_label_code)
    with open("scripts/main.gd", "w") as f:
        f.write(content)
    print("Label settings patched successfully.")
else:
    print("Could not find the exact old label code to replace.")
