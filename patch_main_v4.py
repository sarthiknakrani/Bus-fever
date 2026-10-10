import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

# Find the start of _build_ui()
start_build = content.find("func _build_ui() -> void:")
# Find the start of _on_play_pressed()
start_play = content.find("func _on_play_pressed() -> void:")

# We want to remove _add_extruded_title completely.
# Let's see if _add_extruded_title exists after start_play.
start_add_extruded = content.find("func _add_extruded_title(", start_play)

if start_build != -1 and start_play != -1:
    new_build_ui = """func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.name = "HomeRoot"
	add_child(root)

	# A. Full portrait background (Sky-blue gradient)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color("8BD3F1"), Color("DAF3FC")])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_to = Vector2(0, 1)
	grad_tex.fill_from = Vector2(0, 0)
	bg.texture = grad_tex
	bg.ignore_texture_size = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# B. Outer frame - cleanly matching the actual screen edge, no inner margin strips
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_sb = StyleBoxFlat.new()
	frame_sb.bg_color = Color.TRANSPARENT
	frame_sb.border_width_left = 6
	frame_sb.border_width_right = 6
	frame_sb.border_width_top = 6
	frame_sb.border_width_bottom = 6
	frame_sb.border_color = Color("94a3b8")
	frame.add_theme_stylebox_override("panel", frame_sb)
	root.add_child(frame)

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

	# C. Top-right Settings button (clean, sharper, blue)
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
	sb_set.bg_color = Color("3b82f6")
	sb_set.set_corner_radius_all(10) # Sharper corners
	sb_set.shadow_color = Color(0, 0, 0, 0.2)
	sb_set.shadow_size = 4
	sb_set.shadow_offset = Vector2(0, 4)
	settings_btn.add_theme_stylebox_override("normal", sb_set)
	
	var sb_set_hover = sb_set.duplicate()
	sb_set_hover.bg_color = Color("60a5fa")
	settings_btn.add_theme_stylebox_override("hover", sb_set_hover)
	
	var sb_set_pressed = sb_set.duplicate()
	sb_set_pressed.bg_color = Color("1d4ed8")
	sb_set_pressed.shadow_size = 0
	sb_set_pressed.shadow_offset = Vector2(0, 0)
	settings_btn.add_theme_stylebox_override("pressed", sb_set_pressed)

	var s_icon = Label.new()
	s_icon.text = "⚙"
	s_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	s_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls_s = LabelSettings.new()
	ls_s.font_size = 40
	ls_s.font_color = Color.WHITE
	s_icon.label_settings = ls_s
	settings_btn.add_child(s_icon)

	settings_btn.pressed.connect(_on_settings_pressed)
	hud.add_child(settings_btn)

	# D. Bottom-center Play button (clean, sharper, green)
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
	pb_style.bg_color = Color("22c55e")
	pb_style.set_corner_radius_all(12) # Sharper corners
	pb_style.shadow_color = Color(0, 0, 0, 0.2)
	pb_style.shadow_size = 6
	pb_style.shadow_offset = Vector2(0, 6)
	play_btn.add_theme_stylebox_override("normal", pb_style)
	
	var pb_hover = pb_style.duplicate()
	pb_hover.bg_color = Color("4ade80")
	play_btn.add_theme_stylebox_override("hover", pb_hover)
	
	var pb_pressed = pb_style.duplicate()
	pb_pressed.bg_color = Color("15803d")
	pb_pressed.shadow_size = 0
	pb_pressed.shadow_offset = Vector2(0, 0)
	play_btn.add_theme_stylebox_override("pressed", pb_pressed)
	
	var p_lbl = Label.new()
	p_lbl.text = "Play"
	p_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls_play = LabelSettings.new()
	ls_play.font_size = 46
	ls_play.font_color = Color.WHITE
	p_lbl.label_settings = ls_play
	play_btn.add_child(p_lbl)
	
	play_btn.pressed.connect(_on_play_pressed)
	hud.add_child(play_btn)


"""
    
    # We will slice content to start_build, add new_build_ui, then content from start_play.
    # But we also need to remove _add_extruded_title if it exists at the end of the file.
    
    # So we take the part from start_play up to start_add_extruded (if found).
    if start_add_extruded != -1:
        end_content = content[start_play:start_add_extruded]
    else:
        end_content = content[start_play:]
        
    new_content = content[:start_build] + new_build_ui + end_content
    with open("scripts/main.gd", "w") as f:
        f.write(new_content)
    print("Successfully patched main.gd with clean layout")
else:
    print("Could not find insertion points")

