import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

# We need to remove the p_lbl section and the button_down / button_up logic because Button3D handles it!
# Wait, the patch_main_3d.py didn't remove the p_lbl code from main.gd.
# Let's cleanly replace the entire block of code that sets up play_btn.

old_block = r'''	var play_btn := Button3D\.new\(\)
	play_btn\.setup_3d\("res://assets/models/btn_320x80\.obj", Color\("3b82f6"\), "", "Play", Vector2\(320, 80\), false, 20\.0\)
	play_btn\.anchor_left = 0\.5
	play_btn\.anchor_right = 0\.5
	play_btn\.anchor_top = 0\.85
	play_btn\.anchor_bottom = 0\.85
	play_btn\.offset_left = -160\.0
	play_btn\.offset_right = 160\.0
	play_btn\.offset_top = -80\.0
	play_btn\.offset_bottom = 0\.0
	play_btn\.mouse_filter = Control\.MOUSE_FILTER_STOP
	
	# Add Godot Label for "Play" text because Godot SVG importer ignores <text> tags
	var p_lbl = Label\.new\(\)
	p_lbl\.text = "Play"
	p_lbl\.set_anchors_preset\(Control\.PRESET_FULL_RECT\)
	p_lbl\.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl\.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_lbl\.mouse_filter = Control\.MOUSE_FILTER_IGNORE
	# Shift it up slightly so it centers perfectly on the raised glossy face, not the shadow
	p_lbl\.offset_top = -6\.0
	p_lbl\.offset_bottom = -6\.0
	
	var ls_play = LabelSettings\.new\(\)
	ls_play\.font_size = 52
	ls_play\.font_color = Color\("f8fafc"\) # Very light grey / white
	ls_play\.outline_size = 16
	ls_play\.outline_color = Color\("1e3a8a"\) # Dark blue outline
	ls_play\.shadow_size = 0 # Sharp extrusion
	ls_play\.shadow_color = Color\("0f172a"\) # Almost black/navy for bottom extrusion depth
	ls_play\.shadow_offset = Vector2\(0, 6\)
	p_lbl\.label_settings = ls_play
	
	play_btn\.add_child\(p_lbl\)
	
	play_btn\.button_down\.connect\(func\(\):
		var tw = play_btn\.create_tween\(\)
		tw\.set_parallel\(true\)
		tw\.tween_property\(play_btn, "scale", Vector2\(0\.96, 0\.96\), 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
		# The SVG face moves down visually, so we must move the Label down to match it
		tw\.tween_property\(p_lbl, "position:y", -1\.0, 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
	\)
	
	play_btn\.button_up\.connect\(func\(\):
		var tw = play_btn\.create_tween\(\)
		tw\.set_parallel\(true\)
		tw\.tween_property\(play_btn, "scale", Vector2\.ONE, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.tween_property\(p_lbl, "position:y", -6\.0, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
	\)
	
	play_btn\.pressed\.connect\(_on_play_pressed\)
	hud\.add_child\(play_btn\)'''

new_block = r'''	var play_btn := Button3D.new()
	play_btn.setup_3d("res://assets/models/btn_320x80.obj", Color("3b82f6"), "", "Play", Vector2(320, 80), false, 20.0)
	play_btn.anchor_left = 0.5
	play_btn.anchor_right = 0.5
	play_btn.anchor_top = 0.85
	play_btn.anchor_bottom = 0.85
	play_btn.offset_left = -160.0
	play_btn.offset_right = 160.0
	play_btn.offset_top = -80.0
	play_btn.offset_bottom = 0.0
	play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	play_btn.pressed.connect(_on_play_pressed)
	hud.add_child(play_btn)'''

content = re.sub(old_block, new_block, content)

with open("scripts/main.gd", "w") as f:
    f.write(content)
print("Removed old 2D play label and tweens")
