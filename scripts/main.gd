extends Node

## Home / Main Menu Scene — "Bus Fever Party!".
## Vibrant casual mobile aesthetic with Level Select, Star Ratings,
## and Settings. Fully responsive across all mobile portrait screen ratios.

const LevelRegistryScript := preload("res://resources/level_registry.gd")

var _level_select_overlay: Control
var _settings_overlay: Control

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Root full-screen container
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Full-screen background image
	var bg := TextureRect.new()
	var grad_tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.add_point(0.0, Color("e0f2fe")) # Light sky blue at top
	grad.add_point(0.5, Color("bae6fd")) # Mid sky blue
	grad.add_point(1.0, Color("7dd3fc")) # Richer blue at bottom
	grad_tex.gradient = grad
	grad_tex.fill_to = Vector2(0, 1)
	grad_tex.fill_from = Vector2(0, 0)
	bg.texture = grad_tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)


	# Upper section: Game Title & Subtitle
	var title_box := VBoxContainer.new()
	title_box.anchor_left = 0.0
	title_box.anchor_right = 1.0
	title_box.anchor_top = 0.10
	title_box.anchor_bottom = 0.36
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 12)
	root.add_child(title_box)

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.text = "[center][color=#f97316][b]Bus[/b][/color]
[color=#3b82f6][b]Fever Party![/b][/color][/center]"
	title.add_theme_font_size_override("normal_font_size", 64)
	title.add_theme_font_size_override("bold_font_size", 64)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color("1e293b"))
	title.add_theme_constant_override("outline_size", 12)
	title.custom_minimum_size = Vector2(0, 160)
	title.clip_contents = false
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Clear the Traffic • Match the Passengers"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("a8c0dc"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(subtitle)





	# Lower section: Action Buttons centered
	var btn_center := CenterContainer.new()
	btn_center.anchor_left = 0.0
	btn_center.anchor_right = 1.0
	btn_center.anchor_top = 0.60
	btn_center.anchor_bottom = 0.94
	root.add_child(btn_center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(440, 260)
	vbox.add_theme_constant_override("separation", 18)
	btn_center.add_child(vbox)

	# Primary Play Button
	var play_btn := TextureButton.new()
	play_btn.texture_normal = load("res://assets/btn_play.png")
	play_btn.stretch_mode = TextureButton.STRETCH_SCALE
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


	# Procedural Coin Counter Button
	var coin_btn := Button.new()
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color("eef2ff") # very light blue/white
	c_style.border_width_bottom = 6
	c_style.border_color = Color("d1d5db") # gray shadow
	c_style.corner_radius_top_left = 30
	c_style.corner_radius_top_right = 30
	c_style.corner_radius_bottom_left = 30
	c_style.corner_radius_bottom_right = 30
	c_style.shadow_color = Color(0, 0, 0, 0.2)
	c_style.shadow_size = 4
	c_style.shadow_offset = Vector2(0, 4)
	
	var cp_style = c_style.duplicate()
	cp_style.border_width_bottom = 2
	cp_style.shadow_offset = Vector2(0, 2)
	cp_style.content_margin_top = 4

	coin_btn.add_theme_stylebox_override("normal", c_style)
	coin_btn.add_theme_stylebox_override("hover", c_style)
	coin_btn.add_theme_stylebox_override("pressed", cp_style)
	coin_btn.add_theme_stylebox_override("focus", c_style)
	
	coin_btn.custom_minimum_size = Vector2(160, 60) # Only the pill part
	coin_btn.anchor_left = 0.0
	coin_btn.anchor_top = 0.0
	coin_btn.offset_left = 60.0
	coin_btn.offset_top = 40.0
	
	coin_btn.pressed.connect(_on_coins_pressed)
	
	# Add the dynamic text label INSIDE the button (shifted right)
	var coin_lbl := Label.new()
	coin_lbl.text = "%02d" % SaveManager.get_coins()
	coin_lbl.add_theme_font_size_override("font_size", 32)
	coin_lbl.add_theme_color_override("font_color", Color("1e3a8a"))
	coin_lbl.anchor_right = 1.0
	coin_lbl.anchor_bottom = 1.0
	coin_lbl.offset_left = 30
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_btn.add_child(coin_lbl)
	
	root.add_child(coin_btn)
	
	# Add the pure coin icon overlapping the left side!
	# We make it ignore mouse so clicks go to the button.
	var coin_icon = TextureRect.new()
	coin_icon.texture = load("res://assets/pure_coin.png")
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.custom_minimum_size = Vector2(90, 100)
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_icon.position = Vector2(-40, -20)
	coin_btn.add_child(coin_icon)

	# Top right settings button
	var settings_btn := TextureButton.new()
	settings_btn.texture_normal = load("res://assets/btn_settings.png")
	settings_btn.stretch_mode = TextureButton.STRETCH_SCALE
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

	# Full dark translucent background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(center)
	
	# Main Container to allow absolute positioning of Close button relative to panel
	var main_box := Control.new()
	main_box.custom_minimum_size = Vector2(460, 480)
	center.add_child(main_box)

	# Outer Beige Panel
	var panel := PanelContainer.new()
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color("fcf8ef")
	p_style.border_width_bottom = 6
	p_style.border_width_right = 2
	p_style.border_width_left = 2
	p_style.border_color = Color("e0d2b8")
	p_style.corner_radius_top_left = 32
	p_style.corner_radius_top_right = 32
	p_style.corner_radius_bottom_left = 32
	p_style.corner_radius_bottom_right = 32
	p_style.shadow_color = Color(0, 0, 0, 0.15)
	p_style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", p_style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_box.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("9e7655"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Dashed line (simulated with thin solid line for Godot UI simplicity)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color("c4b29c")
	vbox.add_child(line)

	# Inner Panel for Toggles
	var inner_panel := PanelContainer.new()
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color("f0ecd8")
	inner_style.corner_radius_top_left = 24
	inner_style.corner_radius_top_right = 24
	inner_style.corner_radius_bottom_left = 24
	inner_style.corner_radius_bottom_right = 24
	inner_panel.add_theme_stylebox_override("panel", inner_style)
	vbox.add_child(inner_panel)
	
	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 24)
	inner_margin.add_theme_constant_override("margin_right", 24)
	inner_margin.add_theme_constant_override("margin_top", 24)
	inner_margin.add_theme_constant_override("margin_bottom", 24)
	inner_panel.add_child(inner_margin)
	
	var toggles_vbox := VBoxContainer.new()
	toggles_vbox.add_theme_constant_override("separation", 16)
	inner_margin.add_child(toggles_vbox)

	# Toggles
	var sfx_row = _create_custom_toggle("Sound", "🔊", SettingsManager.sfx_enabled(), func(on):
		SettingsManager.set_sfx(on)
	)
	toggles_vbox.add_child(sfx_row)
	
	var music_row = _create_custom_toggle("Music", "🎵", SettingsManager.music_enabled(), func(on):
		SettingsManager.set_music(on)
		if on:
			AudioManager.play_music()
		else:
			AudioManager.stop_music()
	)
	toggles_vbox.add_child(music_row)

	var haptic_row = _create_custom_toggle("Vibration", "📳", SettingsManager.haptics_enabled(), func(on):
		SettingsManager.set_haptics(on)
	)
	toggles_vbox.add_child(haptic_row)

	# Close Button (Orange Circle, Top Right) matching the new reference!
	var close_btn := Button.new()
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color("f97316") # orange
	close_style.border_width_bottom = 6
	close_style.border_color = Color("c2410c") # dark orange
	close_style.corner_radius_top_left = 32
	close_style.corner_radius_top_right = 32
	close_style.corner_radius_bottom_left = 32
	close_style.corner_radius_bottom_right = 32
	close_style.shadow_color = Color(0, 0, 0, 0.2)
	close_style.shadow_size = 4
	close_btn.add_theme_stylebox_override("normal", close_style)
	
	var c_hover = close_style.duplicate()
	c_hover.bg_color = Color("fb923c")
	close_btn.add_theme_stylebox_override("hover", c_hover)
	
	var c_pressed = close_style.duplicate()
	c_pressed.border_width_bottom = 2
	c_pressed.content_margin_top = 4
	close_btn.add_theme_stylebox_override("pressed", c_pressed)
	
	close_btn.text = "✖"
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.add_theme_color_override("font_color", Color("ffffff"))
	close_btn.add_theme_color_override("font_outline_color", Color("c2410c"))
	close_btn.add_theme_constant_override("outline_size", 4)
	close_btn.custom_minimum_size = Vector2(56, 56)
	
	# Position top right overlapping edge
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.offset_left = -32.0
	close_btn.offset_top = -16.0
	close_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SFX_UI)
		_settings_overlay.queue_free()
	)
	main_box.add_child(close_btn)

	add_child(_settings_overlay)

func _create_custom_toggle(text: String, icon_text: String, is_on: bool, on_toggle: Callable) -> Control:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(340, 60)
	
	var icon_lbl = Label.new()
	icon_lbl.text = icon_text
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.add_theme_color_override("font_color", Color("9e7655"))
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_lbl)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(16, 0)
	row.add_child(spacer1)
	
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color("9e7655"))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	
	# Toggle container (New Reference style: green on, brown off)
	var toggle_bg = TextureRect.new()
	toggle_bg.texture = load("res://assets/toggle_on.png") if is_on else load("res://assets/toggle_off.png")
	toggle_bg.stretch_mode = TextureRect.STRETCH_SCALE
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
	
	return row
func _on_coins_pressed() -> void:
	AudioManager.play(AudioManager.SFX_UI)
	print("Coins button clicked! Shop coming soon.")
