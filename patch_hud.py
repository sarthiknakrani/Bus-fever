import re

with open("scripts/gameplay/car_jam_level.gd", "r") as f:
    content = f.read()

pattern = r'func _build_hud\(\) -> void:.*?(?=func _update_layout\(\) -> void:)'
match = re.search(pattern, content, re.MULTILINE | re.DOTALL)

if not match:
    print("Could not find _build_hud")
    exit(1)

new_hud = """func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	safe_area_root = Control.new()
	safe_area_root.name = "SafeAreaRoot"
	safe_area_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(safe_area_root)

	# TopBar: Level 1, Restart, Pause
	top_bar = Control.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 20.0
	top_bar.offset_right = -20.0
	top_bar.offset_top = 24.0
	top_bar.offset_bottom = 68.0
	safe_area_root.add_child(top_bar)

	# Restart (Premium TextureButton)
	var btn_restart := TextureButton.new()
	btn_restart.texture_normal = load("res://assets/btn_restart.png")
	btn_restart.ignore_texture_size = true
	btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_restart.custom_minimum_size = Vector2(50, 50)
	btn_restart.button_down.connect(func():
		var tw = btn_restart.create_tween()
		tw.tween_property(btn_restart, "position:y", 4.0, 0.05).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(btn_restart, "modulate", Color(0.85, 0.85, 0.85), 0.05)
	)
	btn_restart.button_up.connect(func():
		var tw = btn_restart.create_tween()
		tw.tween_property(btn_restart, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(btn_restart, "modulate", Color.WHITE, 0.1)
	)
	btn_restart.pressed.connect(_on_restart_pressed)
	top_bar.add_child(btn_restart)

	level_title_label = Label.new()
	level_title_label.text = "Level " + str(GameController.current_level_number if GameController else 1)
	level_title_label.add_theme_font_size_override("font_size", 30)
	level_title_label.add_theme_color_override("font_color", Color("ffffff"))
	level_title_label.add_theme_color_override("font_outline_color", Color("1e293b"))
	level_title_label.add_theme_constant_override("outline_size", 6)
	level_title_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.5))
	level_title_label.add_theme_constant_override("shadow_offset_y", 4)
	level_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_title_label.anchor_left = 0.25
	level_title_label.anchor_right = 0.75
	level_title_label.anchor_top = 0.0
	level_title_label.anchor_bottom = 1.0
	top_bar.add_child(level_title_label)

	var btn_pause := TextureButton.new()
	btn_pause.texture_normal = load("res://assets/btn_pause.png")
	btn_pause.ignore_texture_size = true
	btn_pause.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_pause.custom_minimum_size = Vector2(50, 50)
	btn_pause.anchor_left = 1.0
	btn_pause.offset_left = -50.0
	var bp_orig_y = btn_pause.position.y
	btn_pause.button_down.connect(func():
		var tw = btn_pause.create_tween()
		tw.tween_property(btn_pause, "position:y", bp_orig_y + 4.0, 0.05).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(btn_pause, "modulate", Color(0.85, 0.85, 0.85), 0.05)
	)
	btn_pause.button_up.connect(func():
		var tw = btn_pause.create_tween()
		tw.tween_property(btn_pause, "position:y", bp_orig_y, 0.1).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(btn_pause, "modulate", Color.WHITE, 0.1)
	)
	btn_pause.pressed.connect(_on_pause_pressed)
	top_bar.add_child(btn_pause)

	# BoosterBar (VIP, Arrange, Jumble) with original Premium 3D PNGs
	booster_bar = Control.new()
	booster_bar.name = "BoosterBar"
	booster_bar.anchor_left = 0.0
	booster_bar.anchor_right = 1.0
	booster_bar.anchor_top = 1.0
	booster_bar.anchor_bottom = 1.0
	booster_bar.offset_left = 20.0
	booster_bar.offset_right = -20.0
	booster_bar.offset_top = -90.0
	booster_bar.offset_bottom = -10.0
	safe_area_root.add_child(booster_bar)

	var b_hbox := HBoxContainer.new()
	b_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	b_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	b_hbox.add_theme_constant_override("separation", 24)
	booster_bar.add_child(b_hbox)

	var boosters = [
		{"name": "VIP", "icon": "res://assets/btn_vip.png"},
		{"name": "Arrange", "icon": "res://assets/btn_arrange.png"},
		{"name": "Jumble", "icon": "res://assets/btn_jumble.png"}
	]

	for b_info in boosters:
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)

		var btn_container = Control.new()
		btn_container.custom_minimum_size = Vector2(56, 56)

		var btn := TextureButton.new()
		btn.texture_normal = load(b_info["icon"])
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# Premium glossy pressed effect
		btn.button_down.connect(func():
			var tw = btn.create_tween()
			tw.tween_property(btn, "position:y", 4.0, 0.05).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(btn, "modulate", Color(0.85, 0.85, 0.85), 0.05)
		)
		btn.button_up.connect(func():
			var tw = btn.create_tween()
			tw.tween_property(btn, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(btn, "modulate", Color.WHITE, 0.1)
		)
		
		btn_container.add_child(btn)

		# Add a premium 3D green '+' circle badge
		var plus := Label.new()
		plus.text = "✚"
		plus.add_theme_font_size_override("font_size", 14)
		plus.add_theme_color_override("font_color", Color("ffffff"))
		plus.add_theme_color_override("font_outline_color", Color("064e3b"))
		plus.add_theme_constant_override("outline_size", 4)
		
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("22c55e")
		p_style.corner_radius_top_left = 12
		p_style.corner_radius_top_right = 12
		p_style.corner_radius_bottom_left = 12
		p_style.corner_radius_bottom_right = 12
		p_style.border_width_bottom = 3
		p_style.border_color = Color("14532d")
		p_style.border_blend = false
		p_style.shadow_color = Color(0, 0, 0, 0.5)
		p_style.shadow_size = 2
		p_style.shadow_offset = Vector2(0, 2)
		plus.add_theme_stylebox_override("normal", p_style)
		
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.size = Vector2(24, 24)
		plus.position = Vector2(36, -6)
		btn_container.add_child(plus)
		
		vbox.add_child(btn_container)
		
		var lbl = Label.new()
		lbl.text = b_info["name"]
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color("ffffff"))
		lbl.add_theme_color_override("font_outline_color", Color("1e293b"))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)
		
		b_hbox.add_child(vbox)

	# PauseOverlay
	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(pause_overlay)

	var p_bg := ColorRect.new()
	p_bg.color = Color(0, 0, 0, 0.7)
	p_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(p_bg)

	var p_center := CenterContainer.new()
	p_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(p_center)

	var p_panel := PanelContainer.new()
	p_panel.custom_minimum_size = Vector2(300, 360)
	var p_style_panel = StyleBoxFlat.new()
	p_style_panel.bg_color = Color("f8fafc")
	p_style_panel.corner_radius_top_left = 24
	p_style_panel.corner_radius_top_right = 24
	p_style_panel.corner_radius_bottom_left = 24
	p_style_panel.corner_radius_bottom_right = 24
	p_style_panel.shadow_color = Color(0,0,0,0.2)
	p_style_panel.shadow_size = 16
	p_style_panel.border_width_bottom = 8
	p_style_panel.border_color = Color("cbd5e1")
	p_panel.add_theme_stylebox_override("panel", p_style_panel)
	p_center.add_child(p_panel)

	var pb_vbox := VBoxContainer.new()
	pb_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pb_vbox.add_theme_constant_override("separation", 16)
	p_panel.add_child(pb_vbox)

	var p_title := Label.new()
	p_title.text = "Paused"
	p_title.add_theme_font_size_override("font_size", 28)
	p_title.add_theme_color_override("font_color", Color("334155"))
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_vbox.add_child(p_title)

	var p_spacer1 := Control.new()
	p_spacer1.custom_minimum_size = Vector2(0, 16)
	pb_vbox.add_child(p_spacer1)

	var p_btn_resume := TextureButton.new()
	p_btn_resume.texture_normal = load("res://assets/btn_play.png")
	p_btn_resume.ignore_texture_size = true
	p_btn_resume.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	p_btn_resume.custom_minimum_size = Vector2(180, 56)
	p_btn_resume.button_down.connect(func():
		var tw = p_btn_resume.create_tween()
		tw.tween_property(p_btn_resume, "position:y", 4.0, 0.05).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(p_btn_resume, "modulate", Color(0.85, 0.85, 0.85), 0.05)
	)
	p_btn_resume.button_up.connect(func():
		var tw = p_btn_resume.create_tween()
		tw.tween_property(p_btn_resume, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(p_btn_resume, "modulate", Color.WHITE, 0.1)
	)
	p_btn_resume.pressed.connect(_on_resume_pressed)
	pb_vbox.add_child(p_btn_resume)
	
	var p_btn_restart := TextureButton.new()
	p_btn_restart.texture_normal = load("res://assets/btn_restart.png")
	p_btn_restart.ignore_texture_size = true
	p_btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	p_btn_restart.custom_minimum_size = Vector2(180, 56)
	p_btn_restart.button_down.connect(func():
		var tw = p_btn_restart.create_tween()
		tw.tween_property(p_btn_restart, "position:y", 4.0, 0.05).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(p_btn_restart, "modulate", Color(0.85, 0.85, 0.85), 0.05)
	)
	p_btn_restart.button_up.connect(func():
		var tw = p_btn_restart.create_tween()
		tw.tween_property(p_btn_restart, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(p_btn_restart, "modulate", Color.WHITE, 0.1)
	)
	p_btn_restart.pressed.connect(_on_restart_pressed)
	pb_vbox.add_child(p_btn_restart)
	
	var p_btn_home := TextureButton.new()
	p_btn_home.texture_normal = load("res://assets/btn_home.png")
	p_btn_home.ignore_texture_size = true
	p_btn_home.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	p_btn_home.custom_minimum_size = Vector2(180, 56)
	p_btn_home.button_down.connect(func():
		var tw = p_btn_home.create_tween()
		tw.tween_property(p_btn_home, "position:y", 4.0, 0.05).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(p_btn_home, "modulate", Color(0.85, 0.85, 0.85), 0.05)
	)
	p_btn_home.button_up.connect(func():
		var tw = p_btn_home.create_tween()
		tw.tween_property(p_btn_home, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(p_btn_home, "modulate", Color.WHITE, 0.1)
	)
	p_btn_home.pressed.connect(func():
		get_tree().paused = false
		if GameController: GameController.go_home()
	)
	pb_vbox.add_child(p_btn_home)
	
	var p_spacer2 := Control.new()
	p_spacer2.custom_minimum_size = Vector2(0, 4)
	pb_vbox.add_child(p_spacer2)
	
	var p_footer := Label.new()
	p_footer.text = "Terms of Service  &  Privacy Policy"
	p_footer.add_theme_font_size_override("font_size", 13)
	p_footer.add_theme_color_override("font_color", Color("3b82f6"))
	p_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_vbox.add_child(p_footer)

	# ResultOverlay
	result_overlay = Control.new()
	result_overlay.name = "ResultOverlay"
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	result_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(result_overlay)

	var res_bg := ColorRect.new()
	res_bg.color = Color(0, 0, 0, 0.8)
	res_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(res_bg)
	
	var res_center := CenterContainer.new()
	res_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(res_center)
	
	var res_panel := PanelContainer.new()
	res_panel.custom_minimum_size = Vector2(300, 360)
	res_panel.add_theme_stylebox_override("panel", p_style_panel)
	res_center.add_child(res_panel)
	
	var res_vbox := VBoxContainer.new()
	res_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	res_vbox.add_theme_constant_override("separation", 20)
	res_panel.add_child(res_vbox)
	
	result_title_label = Label.new()
	result_title_label.text = "Level Cleared!"
	result_title_label.add_theme_font_size_override("font_size", 32)
	result_title_label.add_theme_color_override("font_color", Color("334155"))
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_vbox.add_child(result_title_label)
	
	# Home and Restart logic
	var res_btn_restart := TextureButton.new()
	res_btn_restart.texture_normal = load("res://assets/btn_restart.png")
	res_btn_restart.ignore_texture_size = true
	res_btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	res_btn_restart.custom_minimum_size = Vector2(200, 56)
	res_btn_restart.button_down.connect(func():
		var tw = res_btn_restart.create_tween()
		tw.tween_property(res_btn_restart, "position:y", 4.0, 0.05).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(res_btn_restart, "modulate", Color(0.85, 0.85, 0.85), 0.05)
	)
	res_btn_restart.button_up.connect(func():
		var tw = res_btn_restart.create_tween()
		tw.tween_property(res_btn_restart, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(res_btn_restart, "modulate", Color.WHITE, 0.1)
	)
	res_btn_restart.pressed.connect(_on_restart_pressed)
	res_vbox.add_child(res_btn_restart)
	
	var res_btn_home := TextureButton.new()
	res_btn_home.texture_normal = load("res://assets/btn_home.png")
	res_btn_home.ignore_texture_size = true
	res_btn_home.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	res_btn_home.custom_minimum_size = Vector2(200, 56)
	res_btn_home.button_down.connect(func():
		var tw = res_btn_home.create_tween()
		tw.tween_property(res_btn_home, "position:y", 4.0, 0.05).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(res_btn_home, "modulate", Color(0.85, 0.85, 0.85), 0.05)
	)
	res_btn_home.button_up.connect(func():
		var tw = res_btn_home.create_tween()
		tw.tween_property(res_btn_home, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(res_btn_home, "modulate", Color.WHITE, 0.1)
	)
	res_btn_home.pressed.connect(func():
		get_tree().paused = false
		if GameController: GameController.go_home()
	)
	res_vbox.add_child(res_btn_home)
"""

content = content[:match.start()] + new_hud + "\n" + content[match.end():]

with open("scripts/gameplay/car_jam_level.gd", "w") as f:
    f.write(content)
