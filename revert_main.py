import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

# 1. Remove Button3D import if it exists
content = re.sub(r'const Button3D = preload\("res://scripts/ui/button_3d\.gd"\)\n*', '', content)

# 2. Revert settings_btn
old_settings = r'''	var settings_btn := Button3D\.new\(\)
	settings_btn\.setup_3d\("res://assets/models/btn_64x64\.obj", Color\("3b82f6"\), "res://assets/ui/buttons/icon_settings\.svg", "", Vector2\(64, 64\), false, 12\.0\)
	settings_btn\.anchor_left = 1\.0
	settings_btn\.anchor_right = 1\.0
	settings_btn\.anchor_top = 0\.0
	settings_btn\.anchor_bottom = 0\.0
	settings_btn\.offset_left = -64\.0
	settings_btn\.offset_right = 0\.0
	settings_btn\.offset_top = 0\.0
	settings_btn\.offset_bottom = 64\.0
	settings_btn\.mouse_filter = Control\.MOUSE_FILTER_STOP'''

new_settings = r'''	var settings_btn := TextureButton.new()
	settings_btn.texture_normal = load("res://assets/ui/buttons/settings_gear_normal.svg")
	settings_btn.texture_pressed = load("res://assets/ui/buttons/settings_gear_pressed.svg")
	settings_btn.ignore_texture_size = true
	settings_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.anchor_top = 0.0
	settings_btn.anchor_bottom = 0.0
	settings_btn.offset_left = -64.0
	settings_btn.offset_right = 0.0
	settings_btn.offset_top = 0.0
	settings_btn.offset_bottom = 64.0
	settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_btn.pivot_offset = Vector2(32, 32)
	
	settings_btn.button_down.connect(func():
		var tw = settings_btn.create_tween()
		tw.tween_property(settings_btn, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	settings_btn.button_up.connect(func():
		var tw = settings_btn.create_tween()
		tw.tween_property(settings_btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
	)'''

content = re.sub(old_settings, new_settings, content)

# 3. Revert play_btn
old_play = r'''	# D\. Bottom-center Play button \(Premium 3D Model\)
	var play_btn := Button3D\.new\(\)
	play_btn\.setup_3d\("res://assets/models/btn_320x80\.obj", Color\("3b82f6"\), "", "Play", Vector2\(320, 80\), false, 20\.0\)
	play_btn\.anchor_left = 0\.5
	play_btn\.anchor_right = 0\.5
	play_btn\.anchor_top = 0\.85
	play_btn\.anchor_bottom = 0\.85
	play_btn\.offset_left = -160\.0
	play_btn\.offset_right = 160\.0
	play_btn\.offset_top = -80\.0
	play_btn\.offset_bottom = 0\.0
	play_btn\.mouse_filter = Control\.MOUSE_FILTER_STOP'''

new_play = r'''	# D. Bottom-center Play button (Glossy Blue 2D SVG)
	var play_btn := TextureButton.new()
	play_btn.texture_normal = load("res://assets/ui/buttons/play_normal.svg")
	play_btn.texture_pressed = load("res://assets/ui/buttons/play_pressed.svg")
	play_btn.ignore_texture_size = true
	play_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	play_btn.anchor_left = 0.5
	play_btn.anchor_right = 0.5
	play_btn.anchor_top = 0.85
	play_btn.anchor_bottom = 0.85
	play_btn.offset_left = -160.0
	play_btn.offset_right = 160.0
	play_btn.offset_top = -80.0
	play_btn.offset_bottom = 0.0
	play_btn.pivot_offset = Vector2(160, 40)
	play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var p_lbl = Label.new()
	p_lbl.text = "Play"
	p_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_lbl.offset_top = -6.0
	p_lbl.offset_bottom = -6.0
	
	var ls_play = LabelSettings.new()
	ls_play.font_size = 42
	ls_play.font_color = Color("f8fafc")
	ls_play.outline_size = 12
	ls_play.outline_color = Color("1e3a8a")
	p_lbl.label_settings = ls_play
	
	play_btn.add_child(p_lbl)
	
	play_btn.button_down.connect(func():
		var tw = play_btn.create_tween()
		tw.set_parallel(true)
		tw.tween_property(play_btn, "scale", Vector2(0.96, 0.96), 0.05).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(p_lbl, "position:y", -1.0, 0.05).set_trans(Tween.TRANS_QUAD)
	)
	
	play_btn.button_up.connect(func():
		var tw = play_btn.create_tween()
		tw.set_parallel(true)
		tw.tween_property(play_btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(p_lbl, "position:y", -6.0, 0.1).set_trans(Tween.TRANS_QUAD)
	)'''

content = re.sub(old_play, new_play, content)

with open("scripts/main.gd", "w") as f:
    f.write(content)

print("Reverted main.gd 3D to 2D")
