import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

if "const Button3D" not in content:
    content = content.replace("extends Node2D", "extends Node2D\n\nconst Button3D = preload(\"res://scripts/ui/button_3d.gd\")")

# Patch boosters loop
old_booster = r'''		var btn := TextureButton\.new\(\)
		btn\.texture_normal = load\("res://assets/ui/gameplay_buttons/base_booster_normal\.svg"\)
		btn\.texture_pressed = load\("res://assets/ui/gameplay_buttons/base_booster_pressed\.svg"\)
		btn\.ignore_texture_size = true
		btn\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED
		btn\.set_anchors_preset\(Control\.PRESET_FULL_RECT\)
		
		# Add the illustration PNG on top
		var icon_rect = TextureRect\.new\(\)
		icon_rect\.texture = load\(b_info\["icon"\]\)
		icon_rect\.ignore_texture_size = true
		icon_rect\.stretch_mode = TextureRect\.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect\.set_anchors_preset\(Control\.PRESET_FULL_RECT\)
		icon_rect\.mouse_filter = Control\.MOUSE_FILTER_IGNORE
		# slight padding inside the SVG base
		icon_rect\.offset_left = 10
		icon_rect\.offset_right = -10
		icon_rect\.offset_top = 8
		icon_rect\.offset_bottom = -14
		btn\.add_child\(icon_rect\)
		
		# Premium glossy pressed effect
		btn\.button_down\.connect\(func\(\):
			var tw = btn\.create_tween\(\)
			tw\.tween_property\(btn, "position:y", 4\.0, 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
			tw\.parallel\(\)\.tween_property\(btn, "modulate", Color\(0\.85, 0\.85, 0\.85\), 0\.05\)
		\)
		btn\.button_up\.connect\(func\(\):
			var tw = btn\.create_tween\(\)
			tw\.tween_property\(btn, "position:y", 0\.0, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
			tw\.parallel\(\)\.tween_property\(btn, "modulate", Color\.WHITE, 0\.1\)
		\)
		
		btn_container\.add_child\(btn\)
		
		# Add a premium 3D green '\+' circle badge
		var plus := Label\.new\(\)
		plus\.text = "✚"
		plus\.add_theme_font_size_override\("font_size", 11\)
		plus\.add_theme_color_override\("font_color", Color\("ffffff"\)\)
		plus\.add_theme_color_override\("font_outline_color", Color\("064e3b"\)\)
		plus\.add_theme_constant_override\("outline_size", 3\)
		
		var p_style = StyleBoxFlat\.new\(\)
		p_style\.bg_color = Color\("22c55e"\)
		p_style\.corner_radius_top_left = 9
		p_style\.corner_radius_top_right = 9
		p_style\.corner_radius_bottom_left = 9
		p_style\.corner_radius_bottom_right = 9
		p_style\.border_width_bottom = 2
		p_style\.border_color = Color\("14532d"\)
		p_style\.border_blend = false
		p_style\.shadow_color = Color\(0, 0, 0, 0\.5\)
		p_style\.shadow_size = 1
		p_style\.shadow_offset = Vector2\(0, 1\)
		plus\.add_theme_stylebox_override\("normal", p_style\)
		
		plus\.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus\.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus\.size = Vector2\(18, 18\)
		plus\.position = Vector2\(40, -4\)
		btn_container\.add_child\(plus\)'''

new_booster = r'''		var btn := Button3D.new()
		btn.setup_3d("res://assets/models/btn_56x56.obj", Color("3b82f6"), b_info["icon"], "", Vector2(56, 56), true, 10.0)
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		btn_container.add_child(btn)'''

content = re.sub(old_booster, new_booster, content)

# Pause button (top right)
old_pause = r'''	var btn_pause := TextureButton\.new\(\)
	btn_pause\.texture_normal = load\("res://assets/ui/gameplay_buttons/pause_normal\.svg"\)
	btn_pause\.texture_pressed = load\("res://assets/ui/gameplay_buttons/pause_pressed\.svg"\)
	btn_pause\.ignore_texture_size = true
	btn_pause\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED
	btn_pause\.custom_minimum_size = Vector2\(50, 50\)
	btn_pause\.anchor_left = 1\.0
	btn_pause\.offset_left = -50\.0
	var bp_orig_y = btn_pause\.position\.y
	btn_pause\.button_down\.connect\(func\(\):
		var tw = btn_pause\.create_tween\(\)
		tw\.tween_property\(btn_pause, "position:y", bp_orig_y \+ 4\.0, 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(btn_pause, "modulate", Color\(0\.85, 0\.85, 0\.85\), 0\.05\)
	\)
	btn_pause\.button_up\.connect\(func\(\):
		var tw = btn_pause\.create_tween\(\)
		tw\.tween_property\(btn_pause, "position:y", bp_orig_y, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(btn_pause, "modulate", Color\.WHITE, 0\.1\)
	\)'''

new_pause = r'''	var btn_pause := Button3D.new()
	btn_pause.setup_3d("res://assets/models/btn_50x50.obj", Color("3b82f6"), "res://assets/ui/gameplay_buttons/pause_normal.svg", "", Vector2(50, 50), false, 8.0)
	btn_pause.anchor_left = 1.0
	btn_pause.offset_left = -50.0'''
content = re.sub(old_pause, new_pause, content)

# Pause Popup modifications
# "Remove: Restart option from this popup. Paused heading. Terms of Service and Privacy Policy footer."
# "Keep ONLY: 1. Play — glossy GREEN 3D button, resumes current game. 2. Home — glossy ORANGE 3D button, returns to Home."
old_pause_menu = r'''	var p_title := Label\.new\(\)
	p_title\.text = "Paused"
	p_title\.add_theme_font_size_override\("font_size", 28\)
	p_title\.add_theme_color_override\("font_color", Color\("334155"\)\)
	p_title\.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_vbox\.add_child\(p_title\)

	var p_spacer1 := Control\.new\(\)
	p_spacer1\.custom_minimum_size = Vector2\(0, 16\)
	pb_vbox\.add_child\(p_spacer1\)

	var p_btn_resume := TextureButton\.new\(\)
	p_btn_resume\.texture_normal = load\("res://assets/btn_play\.png"\)
	p_btn_resume\.ignore_texture_size = true
	p_btn_resume\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED
	p_btn_resume\.custom_minimum_size = Vector2\(180, 56\)
	p_btn_resume\.button_down\.connect\(func\(\):
		var tw = p_btn_resume\.create_tween\(\)
		tw\.tween_property\(p_btn_resume, "position:y", 4\.0, 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(p_btn_resume, "modulate", Color\(0\.85, 0\.85, 0\.85\), 0\.05\)
	\)
	p_btn_resume\.button_up\.connect\(func\(\):
		var tw = p_btn_resume\.create_tween\(\)
		tw\.tween_property\(p_btn_resume, "position:y", 0\.0, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(p_btn_resume, "modulate", Color\.WHITE, 0\.1\)
	\)
	p_btn_resume\.pressed\.connect\(_on_resume_pressed\)
	pb_vbox\.add_child\(p_btn_resume\)
	
	var p_btn_restart := TextureButton\.new\(\)
	p_btn_restart\.texture_normal = load\("res://assets/btn_restart\.png"\)
	p_btn_restart\.ignore_texture_size = true
	p_btn_restart\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED
	p_btn_restart\.custom_minimum_size = Vector2\(180, 56\)
	p_btn_restart\.button_down\.connect\(func\(\):
		var tw = p_btn_restart\.create_tween\(\)
		tw\.tween_property\(p_btn_restart, "position:y", 4\.0, 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(p_btn_restart, "modulate", Color\(0\.85, 0\.85, 0\.85\), 0\.05\)
	\)
	p_btn_restart\.button_up\.connect\(func\(\):
		var tw = p_btn_restart\.create_tween\(\)
		tw\.tween_property\(p_btn_restart, "position:y", 0\.0, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(p_btn_restart, "modulate", Color\.WHITE, 0\.1\)
	\)
	p_btn_restart\.pressed\.connect\(_on_restart_pressed\)
	pb_vbox\.add_child\(p_btn_restart\)
	
	var p_btn_home := TextureButton\.new\(\)
	p_btn_home\.texture_normal = load\("res://assets/btn_home\.png"\)
	p_btn_home\.ignore_texture_size = true
	p_btn_home\.stretch_mode = TextureButton\.STRETCH_KEEP_ASPECT_CENTERED
	p_btn_home\.custom_minimum_size = Vector2\(180, 56\)
	p_btn_home\.button_down\.connect\(func\(\):
		var tw = p_btn_home\.create_tween\(\)
		tw\.tween_property\(p_btn_home, "position:y", 4\.0, 0\.05\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(p_btn_home, "modulate", Color\(0\.85, 0\.85, 0\.85\), 0\.05\)
	\)
	p_btn_home\.button_up\.connect\(func\(\):
		var tw = p_btn_home\.create_tween\(\)
		tw\.tween_property\(p_btn_home, "position:y", 0\.0, 0\.1\)\.set_trans\(Tween\.TRANS_QUAD\)
		tw\.parallel\(\)\.tween_property\(p_btn_home, "modulate", Color\.WHITE, 0\.1\)
	\)
	p_btn_home\.pressed\.connect\(func\(\):
		get_tree\(\)\.paused = false
		if GameController: GameController\.go_home\(\)
	\)
	pb_vbox\.add_child\(p_btn_home\)
	
	var p_spacer2 := Control\.new\(\)
	p_spacer2\.custom_minimum_size = Vector2\(0, 4\)
	pb_vbox\.add_child\(p_spacer2\)
	
	var p_footer := Label\.new\(\)
	p_footer\.text = "Terms of Service  &  Privacy Policy"
	p_footer\.add_theme_font_size_override\("font_size", 13\)
	p_footer\.add_theme_color_override\("font_color", Color\("3b82f6"\)\)
	p_footer\.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_vbox\.add_child\(p_footer\)'''

new_pause_menu = r'''	var p_btn_resume := Button3D.new()
	p_btn_resume.setup_3d("res://assets/models/btn_180x56.obj", Color("22c55e"), "", "Play", Vector2(180, 56), false, 12.0)
	p_btn_resume.pressed.connect(_on_resume_pressed)
	pb_vbox.add_child(p_btn_resume)
	
	var p_btn_home := Button3D.new()
	p_btn_home.setup_3d("res://assets/models/btn_180x56.obj", Color("f97316"), "", "Home", Vector2(180, 56), false, 12.0)
	p_btn_home.pressed.connect(func():
		get_tree().paused = false
		if GameController: GameController.go_home()
	)
	pb_vbox.add_child(p_btn_home)'''
content = re.sub(old_pause_menu, new_pause_menu, content)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("car_jam_level.gd patched for 3D buttons.")
