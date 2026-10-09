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

	# 3D Background
	var bg := ColorRect.new()
	bg.color = Color("87CEEB") # Level 1 Sky Blue Color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# SafeArea
	var safe := MarginContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_top", 60)
	safe.add_theme_constant_override("margin_bottom", 60)
	safe.add_theme_constant_override("margin_left", 24)
	safe.add_theme_constant_override("margin_right", 24)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)

	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(hud)

	# --- Premium 2D Glossy Settings button ---
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
	settings_btn.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color("3b82f6")
	sb_style.corner_radius_top_left = 36
	sb_style.corner_radius_top_right = 36
	sb_style.corner_radius_bottom_left = 36
	sb_style.corner_radius_bottom_right = 36
	sb_style.shadow_color = Color(0, 0, 0, 0.3)
	sb_style.shadow_size = 8
	sb_style.shadow_offset = Vector2(0, 4)
	settings_btn.add_theme_stylebox_override("normal", sb_style)
	
	var sb_hover = sb_style.duplicate()
	sb_hover.bg_color = Color("60a5fa")
	settings_btn.add_theme_stylebox_override("hover", sb_hover)
	
	var sb_pressed = sb_style.duplicate()
	sb_pressed.bg_color = Color("2563eb")
	settings_btn.add_theme_stylebox_override("pressed", sb_pressed)
	
	var s_gloss = Panel.new()
	s_gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	s_gloss.anchor_bottom = 0.5
	s_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sg_style = StyleBoxFlat.new()
	sg_style.bg_color = Color(1, 1, 1, 0.25)
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
	hud.add_child(settings_btn)

	# --- Premium 3D Procedural Logo ---
	var logo_container = VBoxContainer.new()
	logo_container.anchor_left = 0.5
	logo_container.anchor_right = 0.5
	logo_container.anchor_top = 0.08
	logo_container.anchor_bottom = 0.08
	logo_container.offset_left = -175
	logo_container.offset_right = 175
	logo_container.offset_top = 0
	logo_container.offset_bottom = 260
	logo_container.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_container.add_theme_constant_override("separation", 0)
	
	var bus_box = Control.new()
	bus_box.custom_minimum_size = Vector2(0, 130)
	bus_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_container.add_child(bus_box)
	
	var bus_shadow = Label.new()
	bus_shadow.text = "BUS"
	bus_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bus_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ls_shadow = LabelSettings.new()
	ls_shadow.font_size = 110
	ls_shadow.font_color = Color("b45309") # Dark orange
	ls_shadow.outline_size = 28
	ls_shadow.outline_color = Color("b45309")
	ls_shadow.shadow_size = 12
	ls_shadow.shadow_color = Color(0, 0, 0, 0.4)
	ls_shadow.shadow_offset = Vector2(0, 16)
	bus_shadow.label_settings = ls_shadow
	bus_shadow.position.y += 12
	bus_box.add_child(bus_shadow)
	
	var bus_front = Label.new()
	bus_front.text = "BUS"
	bus_front.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bus_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ls_front = LabelSettings.new()
	ls_front.font_size = 110
	ls_front.font_color = Color("f59e0b") # Yellow/Gold
	ls_front.outline_size = 18
	ls_front.outline_color = Color.WHITE
	bus_front.label_settings = ls_front
	bus_box.add_child(bus_front)
	
	var fever_box = Control.new()
	fever_box.custom_minimum_size = Vector2(0, 90)
	fever_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_container.add_child(fever_box)
	
	var fp_shadow = Label.new()
	fp_shadow.text = "FEVER PARTY!"
	fp_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fp_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ls_fps = LabelSettings.new()
	ls_fps.font_size = 62
	ls_fps.font_color = Color("0284c7") # Dark Blue
	ls_fps.outline_size = 22
	ls_fps.outline_color = Color("0284c7")
	ls_fps.shadow_size = 12
	ls_fps.shadow_color = Color(0, 0, 0, 0.4)
	ls_fps.shadow_offset = Vector2(0, 10)
	fp_shadow.label_settings = ls_fps
	fp_shadow.position.y += 8
	fever_box.add_child(fp_shadow)
	
	var fp_front = Label.new()
	fp_front.text = "FEVER PARTY!"
	fp_front.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fp_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ls_fpf = LabelSettings.new()
	ls_fpf.font_size = 62
	ls_fpf.font_color = Color("38bdf8") # Light Blue
	ls_fpf.outline_size = 14
	ls_fpf.outline_color = Color.WHITE
	fp_front.label_settings = ls_fpf
	fever_box.add_child(fp_front)
	
	hud.add_child(logo_container)

	# --- Premium 2D Glossy Play Button ---
	var play_btn := Button.new()
	play_btn.anchor_left = 0.5
	play_btn.anchor_right = 0.5
	play_btn.anchor_top = 0.82
	play_btn.anchor_bottom = 0.82
	play_btn.offset_left = -140
	play_btn.offset_right = 140
	play_btn.offset_top = -100
	play_btn.offset_bottom = 0
	play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	play_btn.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color("22c55e")
	p_style.corner_radius_top_left = 50
	p_style.corner_radius_top_right = 50
	p_style.corner_radius_bottom_left = 50
	p_style.corner_radius_bottom_right = 50
	p_style.shadow_color = Color(0, 0, 0, 0.3)
	p_style.shadow_size = 12
	p_style.shadow_offset = Vector2(0, 6)
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
	play_btn.add_child(p_text)
	
	play_btn.pressed.connect(_on_play_pressed)
	hud.add_child(play_btn)

func _on_play_pressed() -> void:
	AudioManager.play(AudioManager.SFX_UI)
	GameController.start_level(1)


func _on_settings_pressed() -> void:
	AudioManager.play(AudioManager.SFX_UI)
	_show_settings_overlay()


# ---------- helpers ----------

# Build a 3D-extruded StyleBoxFlat: solid top color, thick colored bottom
# "lip" via border_width_bottom for the extrusion. Optional text_padding_y
# shrinks height on press. (Moved to scripts/ui/style_helpers.gd)


# Drop a single offset shadow label behind a front label. The shadow label
# is added as a *sibling* under `parent` (not inside) so it can be offset
# freely without affecting the front label's layout.
func _add_extruded_title(parent: Control, text: String,
		front: Color, shadow: Color,
		anchor_lt: Vector2, anchor_rb: Vector2,
		font_size: int, shadow_offset: Vector2) -> Control:
	# Use a fixed-size container so the shadow sits behind without affecting layout
	var holder := Control.new()
	holder.anchor_left = anchor_lt.x
	holder.anchor_top = anchor_lt.y
	holder.anchor_right = anchor_rb.x
	holder.anchor_bottom = anchor_rb.y
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)

	var back := Label.new()
	back.text = text
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.position = shadow_offset
	var ls_back := LabelSettings.new()
	ls_back.font_size = font_size
	ls_back.font_color = shadow
	back.label_settings = ls_back
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)

	var front_lbl := Label.new()
	front_lbl.text = text
	front_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	front_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	front_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ls_front := LabelSettings.new()
	ls_front.font_size = font_size
	ls_front.font_color = front
	front_lbl.label_settings = ls_front
	front_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(front_lbl)
	return holder


# ---------- settings overlay ----------

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
	ps.corner_radius_all = 32
	ps.shadow_color = Color(0,0,0,0.3)
	ps.shadow_size = 12
	ps.shadow_offset = Vector2(0, 8)
	_settings_panel.add_theme_stylebox_override("panel", ps)
	_settings_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	wrapper.add_child(_settings_panel)
	
	var pop_gloss = Panel.new()
	pop_gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pop_gloss.anchor_bottom = 0.5
	pop_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pg_style = StyleBoxFlat.new()
	pg_style.bg_color = Color(1, 1, 1, 0.4)
	pop_gloss.add_theme_stylebox_override("panel", pg_style)
	_settings_panel.add_child(pop_gloss)

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
	title.add_theme_font_size_override("font_size", 28)
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
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.custom_minimum_size = Vector2(48, 48)
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.anchor_top = 0.0
	close_btn.anchor_bottom = 0.0
	close_btn.offset_left = -24.0
	close_btn.offset_top = -16.0
	close_btn.offset_right = 24.0
	close_btn.offset_bottom = 32.0
	close_btn.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color("ef4444")
	c_style.corner_radius_all = 24
	c_style.shadow_color = Color(0, 0, 0, 0.3)
	c_style.shadow_size = 6
	c_style.shadow_offset = Vector2(0, 4)
	close_btn.add_theme_stylebox_override("normal", c_style)
	
	var c_hover = c_style.duplicate()
	c_hover.bg_color = Color("f87171")
	close_btn.add_theme_stylebox_override("hover", c_hover)
	
	var c_pressed = c_style.duplicate()
	c_pressed.bg_color = Color("dc2626")
	close_btn.add_theme_stylebox_override("pressed", c_pressed)
	
	var cg = Panel.new()
	cg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cg.anchor_bottom = 0.5
	cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cgs = StyleBoxFlat.new()
	cgs.bg_color = Color(1, 1, 1, 0.3)
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
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", Color("9e7655"))
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)
	row.add_child(spacer)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
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
