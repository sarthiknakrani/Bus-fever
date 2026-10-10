extends Node

const SimpleStyle := preload("res://scripts/ui/style_helpers.gd")

# ---------- 3D-style helpers ----------
# A simple "extruded" label: one dark offset duplicate beneath the front label
# gives the text a clean, raised look without stacked shadows / gloss.

const BG_COLOR := Color("cfe8ff")
const PLAY_FRONT := Color("4ade80")
const PLAY_BACK := Color("15803d")

var _settings_overlay: Control
var _settings_panel: PanelContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
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

	# Scrim
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(center)

	# Wrapper Control so the close button can anchor freely OUTSIDE the
	# PanelContainer (PanelContainer forces child layout and ignores anchors).
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(340, 380)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(wrapper)

	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("fcf8ef")
	ps.border_width_bottom = 6
	ps.border_color = Color("e0d2b8")
	ps.set_corner_radius_all(32)
	ps.shadow_color = Color(0,0,0,0.3)
	ps.shadow_size = 12
	ps.shadow_offset = Vector2(0, 8)
	_settings_panel.add_theme_stylebox_override("panel", ps)
	# REMOVED clip_children because it breaks the shadow and layout!
	wrapper.add_child(_settings_panel)
	
	# Add the gloss Panel OVER the settings panel as a sibling so it doesn't break PanelContainer layout
	var pop_gloss = Panel.new()
	pop_gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_gloss.anchor_bottom = 0.5
	pop_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pg_style = StyleBoxFlat.new()
	pg_style.bg_color = Color(1, 1, 1, 0.4)
	pg_style.corner_radius_top_left = 32
	pg_style.corner_radius_top_right = 32
	pop_gloss.add_theme_stylebox_override("panel", pg_style)
	wrapper.add_child(pop_gloss)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	_settings_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("9e7655"))
	vbox.add_child(title)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color("c4b29c")
	vbox.add_child(line)

	var toggles := VBoxContainer.new()
	toggles.add_theme_constant_override("separation", 12)
	vbox.add_child(toggles)

	toggles.add_child(_create_custom_toggle("Sound", "🔊", SettingsManager.sfx_enabled(), func(on):
		SettingsManager.set_sfx(on)))
	toggles.add_child(_create_custom_toggle("Music", "🎵", SettingsManager.music_enabled(), func(on):
		SettingsManager.set_music(on)
		if on:
			AudioManager.play_music()
		else:
			AudioManager.stop_music()))
	toggles.add_child(_create_custom_toggle("Vibration", "📳", SettingsManager.haptics_enabled(), func(on):
		SettingsManager.set_haptics(on)))

	# --- Premium 2D Glossy Close button ---
	var close_btn := Button.new()
	close_btn.text = "✖"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.anchor_top = 0.0
	close_btn.anchor_bottom = 0.0
	close_btn.offset_left = -24.0
	close_btn.offset_top = -16.0
	close_btn.offset_right = 24.0
	close_btn.offset_bottom = 32.0
	# NO clip_children to prevent shadow bug
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color("ef4444")
	c_style.set_corner_radius_all(24)
	c_style.shadow_color = Color(0, 0, 0, 0.3)
	c_style.shadow_size = 6
	c_style.shadow_offset = Vector2(0, 4)
	close_btn.add_theme_stylebox_override("normal", c_style)
	
	var c_hover = c_style.duplicate()
	c_hover.bg_color = Color("f87171")
	close_btn.add_theme_stylebox_override("hover", c_hover)
	
	var c_pressed = c_style.duplicate()
	c_pressed.bg_color = Color("dc2626")
	c_pressed.shadow_size = 0
	c_pressed.shadow_offset = Vector2(0,0)
	close_btn.add_theme_stylebox_override("pressed", c_pressed)
	
	var cg = Panel.new()
	cg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cg.anchor_bottom = 0.5
	cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cgs = StyleBoxFlat.new()
	cgs.bg_color = Color(1, 1, 1, 0.3)
	cgs.corner_radius_top_left = 24
	cgs.corner_radius_top_right = 24
	cg.add_theme_stylebox_override("panel", cgs)
	close_btn.add_child(cg)
	
	close_btn.pressed.connect(func():
		AudioManager.play(AudioManager.SFX_UI)
		_settings_overlay.queue_free()
	)
	wrapper.add_child(close_btn)

	add_child(_settings_overlay)


func _create_custom_toggle(text: String, icon_text: String, is_on: bool, on_toggle: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(280, 48)

	var icon := Label.new()
	icon.text = icon_text
	icon.add_theme_font_size_override("font_size", 16)
	icon.add_theme_color_override("font_color", Color("9e7655"))
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)
	row.add_child(spacer)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color("9e7655"))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	# Procedural 3D toggle pill (no PNG — sharp at any resolution)
	const PILL_W := 70.0
	const PILL_H := 40.0
	const KNOB := 28.0
	const PAD := 7.0

	var pill := Panel.new()
	pill.custom_minimum_size = Vector2(PILL_W, PILL_H)
	pill.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color("22c55e") if is_on else Color("d1d5db")
	pill_style.set_corner_radius_all(int(PILL_H / 2))
	pill.add_theme_stylebox_override("panel", pill_style)
	
	var t_gloss = Panel.new()
	t_gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t_gloss.anchor_bottom = 0.5
	t_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tg_style = StyleBoxFlat.new()
	tg_style.bg_color = Color(1, 1, 1, 0.4)
	t_gloss.add_theme_stylebox_override("panel", tg_style)
	pill.add_child(t_gloss)
	
	# Shine animation for toggles that are ON
	if is_on:
		var shine = ColorRect.new()
		shine.color = Color(1, 1, 1, 0.5)
		shine.rotation_degrees = 25
		shine.size = Vector2(10, 100)
		shine.position = Vector2(-50, -20)
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(shine)
		var tw = pill.create_tween().set_loops()
		tw.tween_property(shine, "position:x", 100.0, 1.2).from(-50.0).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(1.0)

	# Inside-pill container so the knob can be positioned freely
	var inside := Control.new()
	inside.set_anchors_preset(Control.PRESET_FULL_RECT)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(inside)

	var knob := Panel.new()
	knob.custom_minimum_size = Vector2(KNOB, KNOB)
	knob.position = Vector2(
		(PILL_W - KNOB - PAD) if is_on else PAD,
		(PILL_H - KNOB) / 2.0
	)
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color.WHITE
	knob_style.set_corner_radius_all(int(KNOB / 2))
	knob_style.border_width_bottom = 3
	knob_style.border_color = Color("e5e7eb")
	knob_style.shadow_color = Color(0, 0, 0, 0.20)
	knob_style.shadow_size = 4
	knob_style.shadow_offset = Vector2(0, 2)
	knob.add_theme_stylebox_override("panel", knob_style)
	inside.add_child(knob)

	# Invisible full-pill click target
	var hit := Button.new()
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.modulate = Color(1, 1, 1, 0.01)
	pill.add_child(hit)

	var state := {"on": is_on}
	hit.pressed.connect(func():
		AudioManager.play(AudioManager.SFX_UI)
		state["on"] = not state["on"]
		var on = state["on"]
		pill_style.bg_color = Color("22c55e") if on else Color("9ca3af")
		pill_style.border_color = Color("14532d") if on else Color("4b5563")
		knob.position.x = (PILL_W - KNOB - PAD) if on else PAD
		on_toggle.call(on)
	)

	var wrap := CenterContainer.new()
	wrap.add_child(pill)
	row.add_child(wrap)
	return row
