import re

with open("scripts/main.gd", "r") as f:
    code = f.read()

# Settings Button Fix: Remove clip_children, use normal shadow, use dome for gloss
pattern_settings = r"\t# --- Premium 2D Glossy Settings button ---.*?\thud\.add_child\(settings_btn\)"
replacement_settings = """	# --- Premium 2D Glossy Settings button ---
	var settings_btn := Button.new()
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.anchor_top = 0.0
	settings_btn.anchor_bottom = 0.0
	settings_btn.offset_left = -84.0
	settings_btn.offset_right = -12.0
	settings_btn.offset_top = 12.0
	settings_btn.offset_bottom = 84.0
	settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	# NO clip_children to fix shadow bug
	
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color("3b82f6")
	sb_style.corner_radius_all = 36
	sb_style.shadow_color = Color(0, 0, 0, 0.3)
	sb_style.shadow_size = 8
	sb_style.shadow_offset = Vector2(0, 4)
	settings_btn.add_theme_stylebox_override("normal", sb_style)
	
	var sb_hover = sb_style.duplicate()
	sb_hover.bg_color = Color("60a5fa")
	settings_btn.add_theme_stylebox_override("hover", sb_hover)
	
	var sb_pressed = sb_style.duplicate()
	sb_pressed.bg_color = Color("2563eb")
	sb_pressed.shadow_size = 2
	sb_pressed.shadow_offset = Vector2(0, 1)
	settings_btn.add_theme_stylebox_override("pressed", sb_pressed)
	
	var s_gloss = Panel.new()
	s_gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	s_gloss.anchor_bottom = 0.5
	s_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sg_style = StyleBoxFlat.new()
	sg_style.bg_color = Color(1, 1, 1, 0.25)
	sg_style.corner_radius_top_left = 36
	sg_style.corner_radius_top_right = 36
	s_gloss.add_theme_stylebox_override("panel", sg_style)
	settings_btn.add_child(s_gloss)
	
	var s_text = Label.new()
	s_text.text = "⚙"
	s_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	s_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls_s = LabelSettings.new()
	ls_s.font_size = 48
	ls_s.font_color = Color.WHITE
	s_text.label_settings = ls_s
	settings_btn.add_child(s_text)
	
	settings_btn.pressed.connect(_on_settings_pressed)
	hud.add_child(settings_btn)"""

code = re.sub(pattern_settings, replacement_settings, code, flags=re.DOTALL)

# Play Button Fix: Separate shadow panel behind, button has NO shadow but clips children
pattern_play = r"\t# --- Premium 2D Glossy Play Button ---.*?\thud\.add_child\(play_btn\)"
replacement_play = """	# --- Premium 2D Glossy Play Button ---
	# Separate shadow panel behind to avoid clip_children shadow bugs
	var play_shadow = Panel.new()
	play_shadow.anchor_left = 0.5
	play_shadow.anchor_right = 0.5
	play_shadow.anchor_top = 0.82
	play_shadow.anchor_bottom = 0.82
	play_shadow.offset_left = -140
	play_shadow.offset_right = 140
	play_shadow.offset_top = -100
	play_shadow.offset_bottom = 0
	play_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_sb = StyleBoxFlat.new()
	shadow_sb.bg_color = Color("22c55e")
	shadow_sb.corner_radius_all = 50
	shadow_sb.shadow_color = Color(0, 0, 0, 0.3)
	shadow_sb.shadow_size = 12
	shadow_sb.shadow_offset = Vector2(0, 6)
	play_shadow.add_theme_stylebox_override("panel", shadow_sb)
	hud.add_child(play_shadow)

	var play_btn := Button.new()
	play_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	play_btn.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	play_shadow.add_child(play_btn)
	
	# Actual button has no shadow because clip_children breaks it
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color("22c55e")
	p_style.corner_radius_all = 50
	play_btn.add_theme_stylebox_override("normal", p_style)
	
	var p_hover = p_style.duplicate()
	p_hover.bg_color = Color("4ade80")
	play_btn.add_theme_stylebox_override("hover", p_hover)
	
	var p_pressed = p_style.duplicate()
	p_pressed.bg_color = Color("16a34a")
	play_btn.add_theme_stylebox_override("pressed", p_pressed)
	
	var p_gloss = Panel.new()
	p_gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p_gloss.anchor_bottom = 0.45
	p_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pg_style = StyleBoxFlat.new()
	pg_style.bg_color = Color(1, 1, 1, 0.25)
	p_gloss.add_theme_stylebox_override("panel", pg_style)
	play_btn.add_child(p_gloss)
	
	var shine = ColorRect.new()
	shine.color = Color(1, 1, 1, 0.4)
	shine.rotation_degrees = 25
	shine.size = Vector2(30, 200)
	shine.position = Vector2(-100, -50)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_btn.add_child(shine)
	
	var tween = play_btn.create_tween().set_loops()
	tween.tween_property(shine, "position:x", 350.0, 1.5).from(-100.0).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(1.5)
	
	var p_text = Label.new()
	p_text.text = "Play"
	p_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls_play = LabelSettings.new()
	ls_play.font_size = 60
	ls_play.font_color = Color.WHITE
	ls_play.shadow_size = 6
	ls_play.shadow_color = Color(0, 0, 0, 0.4)
	ls_play.shadow_offset = Vector2(0, 3)
	p_text.label_settings = ls_play
	p_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_btn.add_child(p_text)
	
	play_btn.button_down.connect(func():
		shadow_sb.shadow_size = 2
		shadow_sb.shadow_offset = Vector2(0, 2)
		play_btn.position.y += 4
	)
	play_btn.button_up.connect(func():
		shadow_sb.shadow_size = 12
		shadow_sb.shadow_offset = Vector2(0, 6)
		play_btn.position.y -= 4
	)
	play_btn.pressed.connect(_on_play_pressed)"""

code = re.sub(pattern_play, replacement_play, code, flags=re.DOTALL)

with open("scripts/main.gd", "w") as f:
    f.write(code)
print("Updated Main UI Shadows")
