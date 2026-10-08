import re
import os

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    code = f.read()

hud_restart_replacement = """
	var btn_restart := TextureButton.new()
	btn_restart.texture_normal = load("res://assets/btn_back.png")
	btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	btn_restart.custom_minimum_size = Vector2(77, 81)
	btn_restart.button_down.connect(func(): btn_restart.position.y += 4)
	btn_restart.button_up.connect(func(): btn_restart.position.y -= 4)
	btn_restart.pressed.connect(_on_restart_pressed)
	top_bar.add_child(btn_restart)
"""
code = re.sub(r'\tvar btn_restart := Button\.new\(\)[\s\S]*?top_bar\.add_child\(btn_restart\)', hud_restart_replacement.strip('\n'), code, count=1)

hud_pause_replacement = """
	var btn_pause := TextureButton.new()
	btn_pause.texture_normal = load("res://assets/btn_pause.png")
	btn_pause.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	btn_pause.custom_minimum_size = Vector2(80, 81)
	btn_pause.button_down.connect(func(): btn_pause.position.y += 4)
	btn_pause.button_up.connect(func(): btn_pause.position.y -= 4)
	btn_pause.anchor_left = 1.0
	btn_pause.offset_left = -80.0
	btn_pause.pressed.connect(_on_pause_pressed)
	top_bar.add_child(btn_pause)
"""
code = re.sub(r'\tvar btn_pause := Button\.new\(\)[\s\S]*?top_bar\.add_child\(btn_pause\)', hud_pause_replacement.strip('\n'), code, count=1)

booster_replacement = """
	for b_name in ["VIP", "Arrange", "Jumble"]:
		var tex_name = "btn_vip.png" if b_name == "VIP" else ("btn_arrange.png" if b_name == "Arrange" else "btn_jumble.png")
		var btn := TextureButton.new()
		btn.texture_normal = load("res://assets/" + tex_name)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
		btn.custom_minimum_size = Vector2(130, 142)
		btn.disabled = true
		b_hbox.add_child(btn)
"""
code = re.sub(r'\tfor b_name in \["VIP", "Arrange", "Jumble"\]:[\s\S]*?b_hbox\.add_child\(vbox\)', booster_replacement.strip('\n'), code, count=1)

result_btn_home_replacement = """
	# Action Buttons (Home and Restart)
	var r_btn_home := TextureButton.new()
	r_btn_home.texture_normal = load("res://assets/btn_home.png")
	r_btn_home.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	r_btn_home.custom_minimum_size = Vector2(264, 118)
	r_btn_home.button_down.connect(func(): r_btn_home.position.y += 8)
	r_btn_home.button_up.connect(func(): r_btn_home.position.y -= 8)
	r_btn_home.pressed.connect(_on_home_pressed)
	
	var r_home_center = CenterContainer.new()
	r_home_center.custom_minimum_size = Vector2(270, 120)
	var rhc_wrap = Control.new()
	rhc_wrap.custom_minimum_size = r_btn_home.custom_minimum_size
	rhc_wrap.add_child(r_btn_home)
	r_home_center.add_child(rhc_wrap)
	r_vbox.add_child(r_home_center)
"""
code = re.sub(r'\t# Action Buttons \(Home and Restart\)[\s\S]*?r_vbox\.add_child\(r_home_center\)', result_btn_home_replacement.strip('\n'), code, count=1)

result_btn_restart_replacement = """
	result_btn = TextureButton.new()
	result_btn.texture_normal = load("res://assets/btn_restart.png")
	result_btn.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	result_btn.custom_minimum_size = Vector2(296, 102)
	result_btn.button_down.connect(func(): result_btn.position.y += 8)
	result_btn.button_up.connect(func(): result_btn.position.y -= 8)
	result_btn.pressed.connect(_on_restart_pressed)
	
	var r_restart_center = CenterContainer.new()
	r_restart_center.custom_minimum_size = Vector2(300, 110)
	var rrc_wrap = Control.new()
	rrc_wrap.custom_minimum_size = result_btn.custom_minimum_size
	rrc_wrap.add_child(result_btn)
	r_restart_center.add_child(rrc_wrap)
	r_vbox.add_child(r_restart_center)
"""
code = re.sub(r'\tresult_btn = Button\.new\(\)[\s\S]*?r_vbox\.add_child\(r_restart_center\)', result_btn_restart_replacement.strip('\n'), code, count=1)

pause_btn_home_replacement = """
	# Action Buttons
	var p_btn_home := TextureButton.new()
	p_btn_home.texture_normal = load("res://assets/btn_home.png")
	p_btn_home.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	p_btn_home.custom_minimum_size = Vector2(264, 118)
	p_btn_home.button_down.connect(func(): p_btn_home.position.y += 8)
	p_btn_home.button_up.connect(func(): p_btn_home.position.y -= 8)
	p_btn_home.pressed.connect(_on_home_pressed)
	
	var home_center = CenterContainer.new()
	home_center.custom_minimum_size = Vector2(270, 120)
	var hc_wrap = Control.new()
	hc_wrap.custom_minimum_size = p_btn_home.custom_minimum_size
	hc_wrap.add_child(p_btn_home)
	home_center.add_child(hc_wrap)
	pb_vbox.add_child(home_center)
"""
code = re.sub(r'\t# Action Buttons\n\tvar p_btn_home := Button\.new\(\)[\s\S]*?pb_vbox\.add_child\(home_center\)', pause_btn_home_replacement.strip('\n'), code, count=1)

pause_btn_restart_replacement = """
	var p_btn_restart := TextureButton.new()
	p_btn_restart.texture_normal = load("res://assets/btn_restart.png")
	p_btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	p_btn_restart.custom_minimum_size = Vector2(296, 102)
	p_btn_restart.button_down.connect(func(): p_btn_restart.position.y += 8)
	p_btn_restart.button_up.connect(func(): p_btn_restart.position.y -= 8)
	p_btn_restart.pressed.connect(_on_restart_pressed)
	
	var restart_center = CenterContainer.new()
	restart_center.custom_minimum_size = Vector2(300, 110)
	var rc_wrap = Control.new()
	rc_wrap.custom_minimum_size = p_btn_restart.custom_minimum_size
	rc_wrap.add_child(p_btn_restart)
	restart_center.add_child(rc_wrap)
	pb_vbox.add_child(restart_center)
"""
code = re.sub(r'\tvar p_btn_restart := Button\.new\(\)[\s\S]*?pb_vbox\.add_child\(restart_center\)', pause_btn_restart_replacement.strip('\n'), code, count=1)


with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(code)

print("Patched car_jam_level.gd")
