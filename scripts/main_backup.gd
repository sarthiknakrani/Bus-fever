extends Node

var _settings_overlay: Control

func _ready() -> void:
	_build_ui()

func _load_external_tex(path: String) -> Texture2D:
	var img = Image.load_from_file(path)
	if img:
		return ImageTexture.create_from_image(img)
	return null

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.name = "UIRoot"
	add_child(root)

	# 1. Background image / decorative scene
	var bg := TextureRect.new()
	bg.texture = _load_external_tex("res://assets/bg_clean.png")
	if bg.texture == null:
		var grad_tex := GradientTexture2D.new()
		var grad := Gradient.new()
		grad.add_point(0.0, Color("79cffc"))
		grad.add_point(1.0, Color("4da6ff"))
		grad_tex.gradient = grad
		grad_tex.fill_to = Vector2(0, 1)
		bg.texture = grad_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# 2. Logo Area
	var logo := TextureRect.new()
	logo.texture = _load_external_tex("res://assets/logo_clean.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchor_left = 0.05
	logo.anchor_right = 0.95
	logo.anchor_top = 0.05
	logo.anchor_bottom = 0.35
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)

	# 3. Coin Container
	var coin_container = Control.new()
	coin_container.offset_left = 20
	coin_container.offset_top = 60
	coin_container.custom_minimum_size = Vector2(250, 100)
	root.add_child(coin_container)
	
	var coin_panel := Panel.new()
	var cp_style := StyleBoxFlat.new()
	cp_style.bg_color = Color.WHITE
	cp_style.corner_radius_top_left = 30
	cp_style.corner_radius_top_right = 30
	cp_style.corner_radius_bottom_left = 30
	cp_style.corner_radius_bottom_right = 30
	cp_style.shadow_color = Color(0, 0, 0, 0.2)
	cp_style.shadow_size = 4
	coin_panel.add_theme_stylebox_override("panel", cp_style)
	coin_panel.offset_left = 20.0
	coin_panel.offset_top = 0.0
	coin_panel.offset_right = 180.0
	coin_panel.offset_bottom = 60.0
	coin_container.add_child(coin_panel)

	var coin_lbl := Label.new()
	var coins_val = SaveManager.get_value("coins", 0) if SaveManager.has_method("get_value") else 250
	coin_lbl.text = str(coins_val)
	coin_lbl.add_theme_color_override("font_color", Color.BLACK)
	coin_lbl.add_theme_font_size_override("font_size", 32)
	coin_lbl.anchor_right = 1.0
	coin_lbl.anchor_bottom = 1.0
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_panel.add_child(coin_lbl)

	var ci_style := StyleBoxFlat.new()
	ci_style.bg_color = Color("ffca28") # Gold
	ci_style.border_width_bottom = 4
	ci_style.border_color = Color("ffb300")
	ci_style.corner_radius_top_left = 40
	ci_style.corner_radius_top_right = 40
	ci_style.corner_radius_bottom_left = 40
	ci_style.corner_radius_bottom_right = 40
	var c_icon_panel = Panel.new()
	c_icon_panel.add_theme_stylebox_override("panel", ci_style)
	c_icon_panel.offset_left = 0.0
	c_icon_panel.offset_top = -10.0
	c_icon_panel.offset_right = 80.0
	c_icon_panel.offset_bottom = 70.0
	c_icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var dl = Label.new()
	dl.text = "$"
	dl.add_theme_font_size_override("font_size", 42)
	dl.add_theme_color_override("font_color", Color.WHITE)
	dl.set_anchors_preset(Control.PRESET_FULL_RECT)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c_icon_panel.add_child(dl)
	coin_container.add_child(c_icon_panel)
	
	var p_btn = Button.new()
	var pb_style = StyleBoxFlat.new()
	pb_style.bg_color = Color("32cd32")
	pb_style.corner_radius_top_left = 30; pb_style.corner_radius_top_right = 30
	pb_style.corner_radius_bottom_left = 30; pb_style.corner_radius_bottom_right = 30
	pb_style.border_width_bottom = 4; pb_style.border_color = Color("228b22")
	p_btn.add_theme_stylebox_override("normal", pb_style)
	var pb_hover = pb_style.duplicate()
	pb_hover.bg_color = Color("3cb371")
	p_btn.add_theme_stylebox_override("hover", pb_hover)
	var pb_press = pb_style.duplicate()
	pb_press.border_width_bottom = 0
	pb_press.content_margin_top = 4
	p_btn.add_theme_stylebox_override("pressed", pb_press)
	
	p_btn.text = "+"
	p_btn.add_theme_font_size_override("font_size", 32)
	p_btn.add_theme_color_override("font_color", Color.WHITE)
	p_btn.offset_left = 160.0
	p_btn.offset_top = 10.0
	p_btn.offset_right = 200.0
	p_btn.offset_bottom = 50.0
	coin_container.add_child(p_btn)

	# 4. Settings Button Slot
	var settings_btn := Button.new()
	settings_btn.text = "⚙"
	settings_btn.add_theme_font_size_override("font_size", 48)
	settings_btn.add_theme_color_override("font_color", Color.WHITE)
	var s_style = StyleBoxFlat.new()
	s_style.bg_color = Color("1e88e5")
	s_style.border_width_bottom = 6
	s_style.border_color = Color("1565c0")
	s_style.corner_radius_top_left = 24
	s_style.corner_radius_top_right = 24
	s_style.corner_radius_bottom_left = 24
	s_style.corner_radius_bottom_right = 24
	s_style.shadow_color = Color(0, 0, 0, 0.2)
	s_style.shadow_size = 4
	settings_btn.add_theme_stylebox_override("normal", s_style)
	
	var s_hover = s_style.duplicate()
	s_hover.bg_color = Color("42a5f5")
	settings_btn.add_theme_stylebox_override("hover", s_hover)
	
	var s_pressed = s_style.duplicate()
	s_pressed.border_width_bottom = 2
	s_pressed.content_margin_top = 4
	settings_btn.add_theme_stylebox_override("pressed", s_pressed)
	
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.offset_left = -110.0
	settings_btn.offset_top = 60.0
	settings_btn.offset_right = -30.0
	settings_btn.offset_bottom = 140.0
	settings_btn.pressed.connect(_on_settings_pressed)
	settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(settings_btn)

	# 5. Play Button Slot
	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.add_theme_font_size_override("font_size", 84)
	play_btn.add_theme_color_override("font_color", Color.WHITE)
	play_btn.add_theme_color_override("font_outline_color", Color("006400"))
	play_btn.add_theme_constant_override("outline_size", 12)
	
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color("32cd32")
	p_style.border_width_bottom = 16
	p_style.border_color = Color("228b22")
	p_style.border_width_top = 8
	p_style.border_color = Color("ffffff")
	p_style.corner_radius_top_left = 64
	p_style.corner_radius_top_right = 64
	p_style.corner_radius_bottom_left = 64
	p_style.corner_radius_bottom_right = 64
	p_style.shadow_color = Color(0, 0, 0, 0.25)
	p_style.shadow_size = 12
	play_btn.add_theme_stylebox_override("normal", p_style)
	
	var p_hover = p_style.duplicate()
	p_hover.bg_color = Color("3cb371")
	play_btn.add_theme_stylebox_override("hover", p_hover)
	
	var p_pressed = p_style.duplicate()
	p_pressed.border_width_bottom = 4
	p_pressed.border_width_top = 4
	p_pressed.content_margin_top = 8
	play_btn.add_theme_stylebox_override("pressed", p_pressed)

	play_btn.anchor_left = 0.5
	play_btn.anchor_top = 1.0
	play_btn.anchor_right = 0.5
	play_btn.anchor_bottom = 1.0
	var btn_width = 460
	play_btn.offset_left = -btn_width / 2.0
	play_btn.offset_top = -340.0
	play_btn.offset_right = btn_width / 2.0
	play_btn.offset_bottom = -180.0
	play_btn.pressed.connect(_on_play_pressed)
	play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(play_btn)

func _on_play_pressed() -> void:
	AudioManager.play(AudioManager.SFX_UI)
	GameController.start_level(1)

func _on_settings_pressed() -> void:
	AudioManager.play(AudioManager.SFX_UI)
	_show_settings_overlay()

func _show_settings_overlay() -> void:
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()

	_settings_overlay = Control.new()
	_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var overlay_bg := ColorRect.new()
	overlay_bg.color = Color(0, 0, 0, 0.6)
	overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(overlay_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(center)
	
	var main_box := Control.new()
	main_box.custom_minimum_size = Vector2(560, 560)
	center.add_child(main_box)

	var panel_bg := Panel.new()
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("f5e6d3")
	ps.corner_radius_top_left = 32
	ps.corner_radius_top_right = 32
	ps.corner_radius_bottom_left = 32
	ps.corner_radius_bottom_right = 32
	panel_bg.add_theme_stylebox_override("panel", ps)
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_box.add_child(panel_bg)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("5c3a21"))
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 30
	main_box.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 42)
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color("ff4500")
	c_style.corner_radius_top_left = 40
	c_style.corner_radius_top_right = 40
	c_style.corner_radius_bottom_left = 40
	c_style.corner_radius_bottom_right = 40
	close_btn.add_theme_stylebox_override("normal", c_style)
		
	close_btn.anchor_left = 1.0
	close_btn.offset_left = -40
	close_btn.offset_top = -20
	close_btn.offset_right = 40
	close_btn.offset_bottom = 60
	close_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SFX_UI)
		_settings_overlay.queue_free()
	)
	main_box.add_child(close_btn)

	var toggles_vbox := VBoxContainer.new()
	toggles_vbox.anchor_left = 0.5
	toggles_vbox.anchor_top = 0.5
	toggles_vbox.anchor_right = 0.5
	toggles_vbox.anchor_bottom = 0.5
	toggles_vbox.offset_left = -220
	toggles_vbox.offset_top = -120
	toggles_vbox.offset_right = 220
	toggles_vbox.offset_bottom = 220
	toggles_vbox.add_theme_constant_override("separation", 16)
	toggles_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_child(toggles_vbox)

	var sfx_row = _create_custom_toggle("Sound", SettingsManager.sfx_enabled(), func(on):
		SettingsManager.set_sfx(on)
	)
	toggles_vbox.add_child(sfx_row)
	
	var music_row = _create_custom_toggle("Music", SettingsManager.music_enabled(), func(on):
		SettingsManager.set_music(on)
		if on: AudioManager.play_music()
		else: AudioManager.stop_music()
	)
	toggles_vbox.add_child(music_row)
	
	var vib_row = _create_custom_toggle("Vibration", SettingsManager.haptics_enabled(), func(on):
		SettingsManager.set_haptics(on)
	)
	toggles_vbox.add_child(vib_row)

	add_child(_settings_overlay)

func _create_custom_toggle(text: String, is_on: bool, on_toggle: Callable) -> Control:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(440, 90)
	
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color("5c3a21"))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	
	var toggle_btn = CheckButton.new()
	toggle_btn.button_pressed = is_on
	toggle_btn.toggled.connect(func(toggled_on):
		AudioManager.play(AudioManager.SFX_UI)
		on_toggle.call(toggled_on)
	)
	row.add_child(toggle_btn)
		
	return row
