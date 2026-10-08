import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

bg_code = """	# World Background
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	var bg := TextureRect.new()
	var grad_tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.add_point(0.0, Color("e0f2fe"))
	grad.add_point(0.5, Color("bae6fd"))
	grad.add_point(1.0, Color("7dd3fc"))
	grad_tex.gradient = grad
	grad_tex.fill_to = Vector2(0, 1)
	grad_tex.fill_from = Vector2(0, 0)
	bg.texture = grad_tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	add_child(bg_layer)
"""

# Replace the incorrect TextureRect injection
code = re.sub(r'\t# World Background[\s\S]*?world_root\.move_child\(bg, 0\)', bg_code.strip('\n'), code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Fixed level background")
