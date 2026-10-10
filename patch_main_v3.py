import re

with open("scripts/main.gd", "r") as f:
    content = f.read()

# Find the start of _build_ui()
start_build = content.find("func _build_ui() -> void:")
# Find the start of _on_play_pressed()
start_play = content.find("func _on_play_pressed() -> void:")

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

	# B. Outer frame
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
	frame_sb.border_color = Color("94a3b8")
	frame_sb.set_corner_radius_all(24)
	frame_sb.shadow_color = Color(0, 0, 0, 0.15)
	frame_sb.shadow_size = 12
	frame.add_theme_stylebox_override("panel", frame_sb)
	frame_margin.add_child(frame)

	# TITLE: BUS FEVER PARTY!
	var title_vbox = VBoxContainer.new()
	title_vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_vbox.anchor_bottom = 0.55
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_vbox.add_theme_constant_override("separation", -10)
	root.add_child(title_vbox)

	var bus_hold = Control.new()
	bus_hold.custom_minimum_size = Vector2(0, 120)
	title_vbox.add_child(bus_hold)
	_add_extruded_title(bus_hold, "BUS", Color("f59e0b"), Color("b45309"), Vector2.ZERO, Vector2(1,1), 90, Vector2(0, 12))

	var fever_hold = Control.new()
	fever_hold.custom_minimum_size = Vector2(0, 120)
	title_vbox.add_child(fever_hold)
	_add_extruded_title(fever_hold, "FEVER PARTY!", Color("3b82f6"), Color("1d4ed8"), Vector2.ZERO, Vector2(1,1), 76, Vector2(0, 10))

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

	# C. Top-right Settings button (Glossy BLUE 3D square, white gear)
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
	sb_set.border_width_left = 3
	sb_set.border_width_right = 3
	sb_set.border_width_top = 3
	sb_set.border_width_bottom = 3
	sb_set.border_color = Color.WHITE
	sb_set.set_corner_radius_all(16)
	sb_set.shadow_color = Color(0, 0, 0, 0.25)
	sb_set.shadow_size = 6
	sb_set.shadow_offset = Vector2(0, 5)
	settings_btn.add_theme_stylebox_override("normal", sb_set)
	
	var sb_set_hover = sb_set.duplicate()
	sb_set_hover.bg_color = Color("60a5fa")
	settings_btn.add_theme_stylebox_override("hover", sb_set_hover)
	
	var sb_set_pressed = sb_set.duplicate()
	sb_set_pressed.bg_color = Color("1d4ed8")
	sb_set_pressed.shadow_size = 1
	sb_set_pressed.shadow_offset = Vector2(0, 1)
	settings_btn.add_theme_stylebox_override("pressed", sb_set_pressed)
	
	var s_hl = Panel.new()
	s_hl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	s_hl.anchor_bottom = 0.5
	s_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shls = StyleBoxFlat.new()
	shls.bg_color = Color(1, 1, 1, 0.25)
	shls.corner_radius_top_left = 16
	shls.corner_radius_top_right = 16
	s_hl.add_theme_stylebox_override("panel", shls)
	settings_btn.add_child(s_hl)

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

	# D. Bottom-center Play button (Glossy GREEN 3D button)
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
	pb_style.border_width_left = 4
	pb_style.border_width_right = 4
	pb_style.border_width_top = 4
	pb_style.border_width_bottom = 4
	pb_style.border_color = Color.WHITE
	pb_style.set_corner_radius_all(32)
	pb_style.shadow_color = Color(0, 0, 0, 0.3)
	pb_style.shadow_size = 10
	pb_style.shadow_offset = Vector2(0, 8)
	play_btn.add_theme_stylebox_override("normal", pb_style)
	
	var pb_hover = pb_style.duplicate()
	pb_hover.bg_color = Color("4ade80")
	play_btn.add_theme_stylebox_override("hover", pb_hover)
	
	var pb_pressed = pb_style.duplicate()
	pb_pressed.bg_color = Color("15803d")
	pb_pressed.shadow_size = 2
	pb_pressed.shadow_offset = Vector2(0, 2)
	play_btn.add_theme_stylebox_override("pressed", pb_pressed)
	
	var p_hl = Panel.new()
	p_hl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p_hl.anchor_bottom = 0.45
	p_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var phls = StyleBoxFlat.new()
	phls.bg_color = Color(1, 1, 1, 0.25)
	phls.corner_radius_top_left = 32
	phls.corner_radius_top_right = 32
	p_hl.add_theme_stylebox_override("panel", phls)
	play_btn.add_child(p_hl)
	
	var p_lbl = Label.new()
	p_lbl.text = "Play"
	p_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls_play = LabelSettings.new()
	ls_play.font_size = 46
	ls_play.font_color = Color.WHITE
	ls_play.shadow_size = 4
	ls_play.shadow_color = Color(0, 0, 0, 0.3)
	p_lbl.label_settings = ls_play
	play_btn.add_child(p_lbl)
	
	play_btn.pressed.connect(_on_play_pressed)
	hud.add_child(play_btn)

func _add_extruded_title(parent: Control, text: String,
		front: Color, shadow: Color,
		anchor_lt: Vector2, anchor_rb: Vector2,
		font_size: int, shadow_offset: Vector2) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(holder)

	var ls_back = LabelSettings.new()
	ls_back.font_size = font_size
	ls_back.font_color = shadow
	# White thick outline
	ls_back.outline_size = 24
	ls_back.outline_color = Color.WHITE

	var back_lbl = Label.new()
	back_lbl.text = text
	back_lbl.label_settings = ls_back
	back_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back_lbl.position += shadow_offset
	holder.add_child(back_lbl)

	var ls_front = LabelSettings.new()
	ls_front.font_size = font_size
	ls_front.font_color = front
	ls_front.outline_size = 8
	ls_front.outline_color = Color.WHITE

	var front_lbl = Label.new()
	front_lbl.text = text
	front_lbl.label_settings = ls_front
	front_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	front_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	front_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(front_lbl)
	
	return holder

"""
    
    new_content = content[:start_build] + new_build_ui + content[start_play:]
    with open("scripts/main.gd", "w") as f:
        f.write(new_content)
    print("Successfully patched main.gd with vibrant UI")
else:
    print("Could not find insertion points")

