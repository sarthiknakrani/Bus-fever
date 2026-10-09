import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

pattern = r"\tvar bg := ColorRect\.new\(\)\n\tbg\.color = Color\(\"87CEEB\"\).*?\n\tbg\.set_anchors_preset\(Control\.PRESET_FULL_RECT\)\n\tbg_layer\.add_child\(bg\)"

replacement = """	var bg := ColorRect.new()
	bg.color = Color("87CEEB") # Sharp sky blue
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg)"""

code = re.sub(pattern, replacement, code, flags=re.DOTALL)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)
print("Fixed mouse_filter on background!")
