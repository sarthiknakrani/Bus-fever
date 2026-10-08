import re

with open("scripts/main.gd", "r") as f:
    main_code = f.read()

# Replace the TextureRect in main.gd with a GradientTexture2D ColorRect
bg_replacement = """	var bg := TextureRect.new()
	var grad_tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.add_point(0.0, Color("e0f2fe")) # Light sky blue at top
	grad.add_point(0.5, Color("bae6fd")) # Mid sky blue
	grad.add_point(1.0, Color("7dd3fc")) # Richer blue at bottom
	grad_tex.gradient = grad
	grad_tex.fill_to = Vector2(0, 1)
	grad_tex.fill_from = Vector2(0, 0)
	bg.texture = grad_tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)"""

main_code = re.sub(r'\tvar bg := TextureRect\.new\(\)[\s\S]*?root\.add_child\(bg\)', bg_replacement.strip('\n'), main_code)

with open("scripts/main.gd", "w") as f:
    f.write(main_code)

print("Patched main.gd background")

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    level_code = f.read()

bg2_replacement = """	# World Background
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
	# We want this at the very back of the hierarchy, so insert at world_root index 0
	world_root.add_child(bg)
	world_root.move_child(bg, 0)
"""

# Insert right after `world_root = Node2D.new()` in `_build_scene_hierarchy`
level_code = re.sub(r'\tworld_root\.name = "WorldRoot"\n\tadd_child\(world_root\)', '\tworld_root.name = "WorldRoot"\n\tadd_child(world_root)\n\n' + bg2_replacement, level_code)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(level_code)

print("Patched car_jam_level.gd background")
