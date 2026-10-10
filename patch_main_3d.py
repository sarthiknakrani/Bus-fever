import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

# Make sure Button3D is preloaded if not already
if "const Button3D" not in content:
    content = content.replace("extends Node2D", "extends Node2D\n\nconst Button3D = preload(\"res://scripts/ui/button_3d.gd\")")

# Patch settings_btn
old_settings = r'''	var settings_btn := TextureButton\.new\(\)
	settings_btn\.texture_normal = load\("res://assets/ui/buttons/settings_gear_normal\.svg"\)
	settings_btn\.texture_pressed = load\("res://assets/ui/buttons/settings_gear_pressed\.svg"\)
	settings_btn\.ignore_texture_size = true
	settings_btn\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED
	settings_btn\.anchor_left = 1\.0
	settings_btn\.anchor_right = 1\.0
	settings_btn\.anchor_top = 0\.0
	settings_btn\.anchor_bottom = 0\.0
	settings_btn\.offset_left = -64\.0
	settings_btn\.offset_right = 0\.0
	settings_btn\.offset_top = 0\.0
	settings_btn\.offset_bottom = 64\.0
	settings_btn\.pivot_offset = Vector2\(32, 32\)
	settings_btn\.mouse_filter = Control\.MOUSE_FILTER_STOP
	
	settings_btn\.button_down\.connect\(func\(\):
		var tw = settings_btn\.create_tween\(\)
		tw\.tween_property\(settings_btn, "scale", Vector2\(0\.92, 0\.92\), 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
	\)
	
	settings_btn\.button_up\.connect\(func\(\):
		var tw = settings_btn\.create_tween\(\)
		tw\.tween_property\(settings_btn, "scale", Vector2\.ONE, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
	\)'''

new_settings = r'''	var settings_btn := Button3D.new()
	settings_btn.setup_3d("res://assets/models/btn_64x64.obj", Color("3b82f6"), "res://assets/ui/buttons/settings_gear_normal.svg", "", Vector2(64, 64), false, 12.0)
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.anchor_top = 0.0
	settings_btn.anchor_bottom = 0.0
	settings_btn.offset_left = -64.0
	settings_btn.offset_right = 0.0
	settings_btn.offset_top = 0.0
	settings_btn.offset_bottom = 64.0
	settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP'''

content = re.sub(old_settings, new_settings, content)

# Patch play_btn
old_play = r'''	var play_btn := TextureButton\.new\(\)
	play_btn\.texture_normal = load\("res://assets/ui/buttons/play_normal\.svg"\)
	play_btn\.texture_pressed = load\("res://assets/ui/buttons/play_pressed\.svg"\)
	play_btn\.ignore_texture_size = true
	play_btn\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED
	play_btn\.anchor_left = 0\.5
	play_btn\.anchor_right = 0\.5
	play_btn\.anchor_top = 0\.85
	play_btn\.anchor_bottom = 0\.85
	play_btn\.offset_left = -160\.0
	play_btn\.offset_right = 160\.0
	play_btn\.offset_top = -80\.0
	play_btn\.offset_bottom = 0\.0
	play_btn\.pivot_offset = Vector2\(160, 40\)
	play_btn\.mouse_filter = Control\.MOUSE_FILTER_STOP
	
	# Add Godot Label for "Play" text because Godot SVG importer ignores <text> tags
	var p_lbl = Label\.new\(\)
	p_lbl\.text = "Play"
	p_lbl\.set_anchors_preset\(Control\.PRESET_FULL_RECT\)
	p_lbl\.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl\.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_lbl\.add_theme_font_size_override\("font_size", 38\)
	p_lbl\.add_theme_color_override\("font_color", Color\("ffffff"\)\)
	p_lbl\.add_theme_color_override\("font_outline_color", Color\("1e3a8a"\)\)
	p_lbl\.add_theme_constant_override\("outline_size", 16\)
	p_lbl\.add_theme_color_override\("font_shadow_color", Color\("1e3a8a"\)\)
	p_lbl\.add_theme_constant_override\("shadow_outline_size", 6\)
	p_lbl\.add_theme_constant_override\("shadow_offset_y", 4\)
	p_lbl\.mouse_filter = Control\.MOUSE_FILTER_IGNORE
	play_btn\.add_child\(p_lbl\)
	
	play_btn\.button_down\.connect\(func\(\):
		var tw = play_btn\.create_tween\(\)
		tw\.tween_property\(play_btn, "scale", Vector2\(0\.92, 0\.92\), 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
	\)
	
	play_btn\.button_up\.connect\(func\(\):
		var tw = play_btn\.create_tween\(\)
		tw\.tween_property\(play_btn, "scale", Vector2\.ONE, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
	\)'''

new_play = r'''	var play_btn := Button3D.new()
	play_btn.setup_3d("res://assets/models/btn_320x80.obj", Color("3b82f6"), "", "Play", Vector2(320, 80), false, 20.0)
	play_btn.anchor_left = 0.5
	play_btn.anchor_right = 0.5
	play_btn.anchor_top = 0.85
	play_btn.anchor_bottom = 0.85
	play_btn.offset_left = -160.0
	play_btn.offset_right = 160.0
	play_btn.offset_top = -80.0
	play_btn.offset_bottom = 0.0
	play_btn.mouse_filter = Control.MOUSE_FILTER_STOP'''

content = re.sub(old_play, new_play, content)

with open("scripts/main.gd", "w") as f:
    f.write(content)

print("main.gd patched for 3D buttons.")
