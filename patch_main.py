import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

# Find the start of _build_ui()
start_build = content.find("func _build_ui() -> void:")
# Find the start of _show_settings_overlay()
start_settings = content.find("func _show_settings_overlay() -> void:")

if start_build != -1 and start_settings != -1:
    new_build_ui = """func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.name = "HomeRoot"
	add_child(root)

	# A. Full portrait background (Clean soft white/light-grey)
	var bg := ColorRect.new()
	bg.color = Color("f8fafc")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# B. Outer frame (Thin, dark-grey rounded outline)
	var frame_margin = MarginContainer.new()
	frame_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_margin.add_theme_constant_override("margin_top", 12)
	frame_margin.add_theme_constant_override("margin_bottom", 12)
	frame_margin.add_theme_constant_override("margin_left", 12)
	frame_margin.add_theme_constant_override("margin_right", 12)
	frame_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame_margin)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_sb = StyleBoxFlat.new()
	frame_sb.bg_color = Color.TRANSPARENT
	frame_sb.border_width_left = 6
	frame_sb.border_width_right = 6
	frame_sb.border_width_top = 6
	frame_sb.border_width_bottom = 6
	frame_sb.border_color = Color("334155")
	frame_sb.set_corner_radius_all(24)
	frame_sb.shadow_color = Color(0, 0, 0, 0.05)
	frame_sb.shadow_size = 12
	frame.add_theme_stylebox_override("panel", frame_sb)
	frame_margin.add_child(frame)

	# SafeArea for buttons
	var safe := MarginContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_top", 40)
	safe.add_theme_constant_override("margin_bottom", 40)
	safe.add_theme_constant_override("margin_left", 40)
	safe.add_theme_constant_override("margin_right", 40)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)

	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(hud)

	# C. Top-right Settings button (Small rounded-square, light-grey surface, dark-grey outline)
	var settings_btn := Button.new()
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.anchor_top = 0.0
	settings_btn.anchor_bottom = 0.0
	settings_btn.offset_left = -64.0
	settings_btn.offset_right = 0.0
	settings_btn.offset_top = 0.0
	settings_btn.offset_bottom = 64.0
	settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var sb_set = StyleBoxFlat.new()
	sb_set.bg_color = Color("e2e8f0")
	sb_set.border_width_left = 3
	sb_set.border_width_right = 3
	sb_set.border_width_top = 3
	sb_set.border_width_bottom = 3
	sb_set.border_color = Color("475569")
	sb_set.set_corner_radius_all(14)
	sb_set.shadow_color = Color(0, 0, 0, 0.15)
	sb_set.shadow_size = 6
	sb_set.shadow_offset = Vector2(0, 4)
	settings_btn.add_theme_stylebox_override("normal", sb_set)
	
	var sb_set_hover = sb_set.duplicate()
	sb_set_hover.bg_color = Color("cbd5e1")
	settings_btn.add_theme_stylebox_override("hover", sb_set_hover)
	
	var sb_set_pressed = sb_set.duplicate()
	sb_set_pressed.bg_color = Color("94a3b8")
	sb_set_pressed.shadow_size = 1
	sb_set_pressed.shadow_offset = Vector2(0, 1)
	settings_btn.add_theme_stylebox_override("pressed", sb_set_pressed)
	
	var s_hl = Panel.new()
	s_hl.set_anchors_preset(Control.PRESET_FULL_RECT)
	s_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shls = StyleBoxFlat.new()
	shls.bg_color = Color.TRANSPARENT
	shls.border_width_top = 4
	shls.border_color = Color(1, 1, 1, 0.8)
	shls.set_corner_radius_all(12)
	s_hl.add_theme_stylebox_override("panel", shls)
	settings_btn.add_child(s_hl)

	settings_btn.pressed.connect(_on_settings_pressed)
	hud.add_child(settings_btn)

	# D. Bottom-center Play button (Wide, horizontally oriented rounded rectangle)
	var play_btn := Button.new()
	play_btn.anchor_left = 0.5
	play_btn.anchor_right = 0.5
	play_btn.anchor_top = 0.85
	play_btn.anchor_bottom = 0.85
	play_btn.offset_left = -160.0
	play_btn.offset_right = 160.0
	play_btn.offset_top = -80.0
	play_btn.offset_bottom = 0.0
	play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var pb_style = StyleBoxFlat.new()
	pb_style.bg_color = Color("e2e8f0")
	pb_style.border_width_left = 4
	pb_style.border_width_right = 4
	pb_style.border_width_top = 4
	pb_style.border_width_bottom = 4
	pb_style.border_color = Color("475569")
	pb_style.set_corner_radius_all(24)
	pb_style.shadow_color = Color(0, 0, 0, 0.2)
	pb_style.shadow_size = 8
	pb_style.shadow_offset = Vector2(0, 6)
	play_btn.add_theme_stylebox_override("normal", pb_style)
	
	var pb_hover = pb_style.duplicate()
	pb_hover.bg_color = Color("cbd5e1")
	play_btn.add_theme_stylebox_override("hover", pb_hover)
	
	var pb_pressed = pb_style.duplicate()
	pb_pressed.bg_color = Color("94a3b8")
	pb_pressed.shadow_size = 2
	pb_pressed.shadow_offset = Vector2(0, 2)
	play_btn.add_theme_stylebox_override("pressed", pb_pressed)
	
	var p_hl = Panel.new()
	p_hl.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var phls = StyleBoxFlat.new()
	phls.bg_color = Color.TRANSPARENT
	phls.border_width_top = 4
	phls.border_color = Color(1, 1, 1, 0.8)
	phls.set_corner_radius_all(20)
	p_hl.add_theme_stylebox_override("panel", phls)
	play_btn.add_child(p_hl)
	
	play_btn.pressed.connect(_on_play_pressed)
	hud.add_child(play_btn)


func _on_play_pressed() -> void:
	AudioManager.play(AudioManager.SFX_UI)
	SceneManager.change_scene("res://scenes/car_jam_level.tscn")


func _on_settings_pressed() -> void:
	AudioManager.play(AudioManager.SFX_UI)
	_show_settings_overlay()


"""
    
    new_content = content[:start_build] + new_build_ui + content[start_settings:]
    with open("scripts/main.gd", "w") as f:
        f.write(new_content)
    print("Successfully patched main.gd")
else:
    print("Could not find insertion points")

