import re
import os

with open("scripts/main.gd", "r") as f:
    main_code = f.read()

# Replace Play Button
play_btn_replacement = """
	# Primary Play Button
	var play_btn := TextureButton.new()
	play_btn.texture_normal = load("res://assets/btn_play.png")
	play_btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	play_btn.custom_minimum_size = Vector2(298, 175)
	
	play_btn.button_down.connect(func():
		play_btn.position.y += 8
	)
	play_btn.button_up.connect(func():
		play_btn.position.y -= 8
	)
	play_btn.pressed.connect(_on_play_pressed)
	
	var play_center = CenterContainer.new()
	play_center.custom_minimum_size = Vector2(300, 180)
	var wrap = Control.new()
	wrap.custom_minimum_size = play_btn.custom_minimum_size
	wrap.add_child(play_btn)
	play_center.add_child(wrap)
	vbox.add_child(play_center)
"""
main_code = re.sub(r'\t# Primary Play Button[\s\S]*?vbox\.add_child\(play_center\)', play_btn_replacement.strip('\n'), main_code)

# Replace Settings Button
settings_btn_replacement = """
	# Top right settings button
	var settings_btn := TextureButton.new()
	settings_btn.texture_normal = load("res://assets/btn_settings.png")
	settings_btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	settings_btn.custom_minimum_size = Vector2(77, 81)
	
	settings_btn.button_down.connect(func():
		settings_btn.position.y += 4
	)
	settings_btn.button_up.connect(func():
		settings_btn.position.y -= 4
	)
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_top = 0.0
	settings_btn.anchor_right = 1.0
	settings_btn.anchor_bottom = 0.0
	settings_btn.offset_left = -100.0
	settings_btn.offset_top = 28.0
	settings_btn.offset_right = -23.0
	settings_btn.offset_bottom = 109.0
	settings_btn.pressed.connect(_on_settings_pressed)
	root.add_child(settings_btn)
"""
main_code = re.sub(r'\t# Top right settings button[\s\S]*?root\.add_child\(settings_btn\)', settings_btn_replacement.strip('\n'), main_code)

# Custom Toggle
toggle_replacement = """
	# Toggle container (New Reference style: green on, brown off)
	var toggle_bg = TextureRect.new()
	toggle_bg.texture = load("res://assets/toggle_on.png") if is_on else load("res://assets/toggle_off.png")
	toggle_bg.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	toggle_bg.custom_minimum_size = Vector2(107, 75)
	
	var btn = Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	toggle_bg.add_child(btn)
	
	var state_dict = {"on": is_on}
	btn.pressed.connect(func():
		AudioManager.play(AudioManager.SFX_UI)
		state_dict["on"] = not state_dict["on"]
		var current_on = state_dict["on"]
		toggle_bg.texture = load("res://assets/toggle_on.png") if current_on else load("res://assets/toggle_off.png")
		on_toggle.call(current_on)
	)
	
	var toggle_center = CenterContainer.new()
	toggle_center.add_child(toggle_bg)
	row.add_child(toggle_center)
"""
main_code = re.sub(r'\t# Toggle container \(New Reference style: green on, brown off\)[\s\S]*?row\.add_child\(toggle_center\)', toggle_replacement.strip('\n'), main_code)

with open("scripts/main.gd", "w") as f:
    f.write(main_code)

print("Patched main.gd")
