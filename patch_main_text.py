import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

pattern = r'\s*# D\. Bottom-center Play button \(Glossy Blue 3D SVG\).*?hud\.add_child\(play_btn\)'
match = re.search(pattern, content, re.MULTILINE | re.DOTALL)

if not match:
    print("Could not find Play button section in main.gd")
    exit(1)

new_play_btn = """	# D. Bottom-center Play button (Glossy Blue 3D SVG)
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
	
	# Add Godot Label for "Play" text because Godot SVG importer ignores <text> tags
	var p_lbl = Label.new()
	p_lbl.text = "Play"
	p_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Shift it up slightly so it centers perfectly on the raised glossy face, not the shadow
	p_lbl.offset_top = -6.0
	p_lbl.offset_bottom = -6.0
	
	var ls_play = LabelSettings.new()
	ls_play.font_size = 46
	ls_play.font_color = Color.WHITE
	ls_play.outline_size = 6
	ls_play.outline_color = Color("1e3a8a")
	ls_play.shadow_size = 4
	ls_play.shadow_color = Color(0, 0, 0, 0.4)
	ls_play.shadow_offset = Vector2(0, 3)
	p_lbl.label_settings = ls_play
	
	play_btn.add_child(p_lbl)
	
	play_btn.button_down.connect(func():
		var tw = play_btn.create_tween()
		tw.set_parallel(true)
		tw.tween_property(play_btn, "scale", Vector2(0.96, 0.96), 0.05).set_trans(Tween.TRANS_QUAD)
		# The SVG face moves down visually, so we must move the Label down to match it
		tw.tween_property(p_lbl, "position:y", -1.0, 0.05).set_trans(Tween.TRANS_QUAD)
	)
	
	play_btn.button_up.connect(func():
		var tw = play_btn.create_tween()
		tw.set_parallel(true)
		tw.tween_property(play_btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(p_lbl, "position:y", -6.0, 0.1).set_trans(Tween.TRANS_QUAD)
	)
	
	play_btn.pressed.connect(func():
		if play_btn.disabled: return
		play_btn.disabled = true
		_on_play_pressed()
	)
	hud.add_child(play_btn)"""

content = content[:match.start()] + "\n" + new_play_btn + content[match.end():]

with open("scripts/main.gd", "w") as f:
    f.write(content)
print("main.gd patched with label")
