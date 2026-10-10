import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

# 1. Remove Button3D import
content = re.sub(r'const Button3D = preload\("res://scripts/ui/button_3d\.gd"\)\n*', '', content)

# 2. Revert topbar restart
old_restart = r'''	# Restart \(Premium Button3D\)
	var btn_restart := Button3D\.new\(\)
	btn_restart\.setup_3d\("res://assets/models/btn_50x50\.obj", Color\("3b82f6"\), "res://assets/ui/gameplay_buttons/icon_restart\.svg", "", Vector2\(50, 50\), false, 8\.0\)'''
new_restart = r'''	var btn_restart := TextureButton.new()
	btn_restart.texture_normal = load("res://assets/ui/gameplay_buttons/restart_normal.svg")
	btn_restart.texture_pressed = load("res://assets/ui/gameplay_buttons/restart_pressed.svg")
	btn_restart.ignore_texture_size = true
	btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_restart.custom_minimum_size = Vector2(50, 50)
	btn_restart.button_down.connect(func():
		var tw = btn_restart.create_tween()
		tw.tween_property(btn_restart, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	btn_restart.button_up.connect(func():
		var tw = btn_restart.create_tween()
		tw.tween_property(btn_restart, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
	)
	btn_restart.pivot_offset = Vector2(25, 25)'''
content = re.sub(old_restart, new_restart, content)

# 3. Revert topbar pause
old_pause = r'''	var btn_pause := Button3D\.new\(\)
	btn_pause\.setup_3d\("res://assets/models/btn_50x50\.obj", Color\("3b82f6"\), "res://assets/ui/gameplay_buttons/icon_pause\.svg", "", Vector2\(50, 50\), false, 8\.0\)'''
new_pause = r'''	var btn_pause := TextureButton.new()
	btn_pause.texture_normal = load("res://assets/ui/gameplay_buttons/pause_normal.svg")
	btn_pause.texture_pressed = load("res://assets/ui/gameplay_buttons/pause_pressed.svg")
	btn_pause.ignore_texture_size = true
	btn_pause.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_pause.custom_minimum_size = Vector2(50, 50)
	btn_pause.button_down.connect(func():
		var tw = btn_pause.create_tween()
		tw.tween_property(btn_pause, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	btn_pause.button_up.connect(func():
		var tw = btn_pause.create_tween()
		tw.tween_property(btn_pause, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
	)
	btn_pause.pivot_offset = Vector2(25, 25)'''
content = re.sub(old_pause, new_pause, content)

# 4. Revert pause popup buttons
old_p_resume = r'''	var p_btn_resume := Button3D\.new\(\)
	p_btn_resume\.setup_3d\("res://assets/models/btn_180x56\.obj", Color\("22c55e"\), "", "Play", Vector2\(180, 56\), false, 12\.0\)'''
new_p_resume = r'''	var p_btn_resume := TextureButton.new()
	p_btn_resume.texture_normal = load("res://assets/btn_play.png")
	p_btn_resume.ignore_texture_size = true
	p_btn_resume.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	p_btn_resume.custom_minimum_size = Vector2(180, 56)
	p_btn_resume.button_down.connect(func():
		var tw = p_btn_resume.create_tween()
		tw.tween_property(p_btn_resume, "scale", Vector2(0.9, 0.9), 0.05)
	)
	p_btn_resume.button_up.connect(func():
		var tw = p_btn_resume.create_tween()
		tw.tween_property(p_btn_resume, "scale", Vector2.ONE, 0.1)
	)
	p_btn_resume.pivot_offset = Vector2(90, 28)'''
content = re.sub(old_p_resume, new_p_resume, content)

old_p_home = r'''	var p_btn_home := Button3D\.new\(\)
	p_btn_home\.setup_3d\("res://assets/models/btn_180x56\.obj", Color\("f97316"\), "", "Home", Vector2\(180, 56\), false, 12\.0\)'''
new_p_home = r'''	var p_btn_home := TextureButton.new()
	p_btn_home.texture_normal = load("res://assets/btn_home.png")
	p_btn_home.ignore_texture_size = true
	p_btn_home.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	p_btn_home.custom_minimum_size = Vector2(180, 56)
	p_btn_home.button_down.connect(func():
		var tw = p_btn_home.create_tween()
		tw.tween_property(p_btn_home, "scale", Vector2(0.9, 0.9), 0.05)
	)
	p_btn_home.button_up.connect(func():
		var tw = p_btn_home.create_tween()
		tw.tween_property(p_btn_home, "scale", Vector2.ONE, 0.1)
	)
	p_btn_home.pivot_offset = Vector2(90, 28)'''
content = re.sub(old_p_home, new_p_home, content)

# 5. Revert Level Clear popup buttons
old_res_restart = r'''	var res_btn_restart := Button3D\.new\(\)
	res_btn_restart\.setup_3d\("res://assets/models/btn_180x56\.obj", Color\("22c55e"\), "", "Restart", Vector2\(180, 56\), false, 12\.0\)'''
new_res_restart = r'''	var res_btn_restart := TextureButton.new()
	res_btn_restart.texture_normal = load("res://assets/btn_restart.png")
	res_btn_restart.ignore_texture_size = true
	res_btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	res_btn_restart.custom_minimum_size = Vector2(180, 56)
	res_btn_restart.button_down.connect(func():
		var tw = res_btn_restart.create_tween()
		tw.tween_property(res_btn_restart, "scale", Vector2(0.9, 0.9), 0.05)
	)
	res_btn_restart.button_up.connect(func():
		var tw = res_btn_restart.create_tween()
		tw.tween_property(res_btn_restart, "scale", Vector2.ONE, 0.1)
	)
	res_btn_restart.pivot_offset = Vector2(90, 28)'''
content = re.sub(old_res_restart, new_res_restart, content)

old_res_home = r'''	var res_btn_home := Button3D\.new\(\)
	res_btn_home\.setup_3d\("res://assets/models/btn_180x56\.obj", Color\("f97316"\), "", "Home", Vector2\(180, 56\), false, 12\.0\)'''
new_res_home = r'''	var res_btn_home := TextureButton.new()
	res_btn_home.texture_normal = load("res://assets/btn_home.png")
	res_btn_home.ignore_texture_size = true
	res_btn_home.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	res_btn_home.custom_minimum_size = Vector2(180, 56)
	res_btn_home.button_down.connect(func():
		var tw = res_btn_home.create_tween()
		tw.tween_property(res_btn_home, "scale", Vector2(0.9, 0.9), 0.05)
	)
	res_btn_home.button_up.connect(func():
		var tw = res_btn_home.create_tween()
		tw.tween_property(res_btn_home, "scale", Vector2.ONE, 0.1)
	)
	res_btn_home.pivot_offset = Vector2(90, 28)'''
content = re.sub(old_res_home, new_res_home, content)

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)

print("Reverted car_jam_level.gd 3D to 2D")
