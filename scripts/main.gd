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

var _logo_wrapper: Control
var _logo_rect: TextureRect
var _logo_tween: Tween
var _play_btn: TextureButton


func _ready() -> void:
	_build_ui()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_update_layout)
	_update_layout()
	_play_logo_entrance_animation()


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.name = "HomeRoot"
	add_child(root)

	# A. Full portrait 3D isometric town background
	var bg := TextureRect.new()
	bg.name = "Background3D"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = load("res://assets/home_bg_retina.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	# Subtle ambient lighting overlay for high-contrast UI readability
	var over_grad := Gradient.new()
	over_grad.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(0.04, 0.08, 0.16, 0.22)])
	var over_tex := GradientTexture2D.new()
	over_tex.gradient = over_grad
	over_tex.fill_from = Vector2(0.5, 0.6)
	over_tex.fill_to = Vector2(0.5, 1.0)
	var over_tr := TextureRect.new()
	over_tr.name = "BottomVignette"
	over_tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_tr.texture = over_tex
	over_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	over_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(over_tr)

	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	# B. Premium 3D Game Title Logo ("BUS FEVER PARTY!")
	_logo_wrapper = Control.new()
	_logo_wrapper.name = "TitleLogoWrapper"
	_logo_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_logo_wrapper)

	_logo_rect = TextureRect.new()
	_logo_rect.name = "LogoTexture"
	_logo_rect.texture = load("res://assets/ui/logo/bus_fever_party_logo.png")
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_wrapper.add_child(_logo_rect)

	# Specular traveling glint shader
	var shine_mat := ShaderMaterial.new()
	shine_mat.shader = load("res://assets/shaders/logo_shine.gdshader")
	shine_mat.set_shader_parameter("shine_progress", -1.0)
	_logo_rect.material = shine_mat

	# C. Top-right Settings button (Glossy Blue SVG)
	var settings_btn := TextureButton.new()
	settings_btn.texture_normal = load("res://assets/ui/buttons/settings_gear_normal.svg")
	settings_btn.texture_pressed = load("res://assets/ui/buttons/settings_gear_pressed.svg")
	settings_btn.ignore_texture_size = true
	settings_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	settings_btn.anchor_left = 1.0
	settings_btn.anchor_right = 1.0
	settings_btn.anchor_top = 0.0
	settings_btn.anchor_bottom = 0.0
	settings_btn.offset_left = -88.0
	settings_btn.offset_right = -24.0
	settings_btn.offset_top = 28.0
	settings_btn.offset_bottom = 92.0
	settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_btn.pivot_offset = Vector2(32, 32)
	
	settings_btn.button_down.connect(func():
		var tw = settings_btn.create_tween()
		tw.tween_property(settings_btn, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	settings_btn.button_up.connect(func():
		var tw = settings_btn.create_tween()
		tw.tween_property(settings_btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
	)
	
	settings_btn.pressed.connect(_on_settings_pressed)
	hud.add_child(settings_btn)
	# D. Bottom-center Play button (Glossy 3D Candy Orange Button)
	# D. Bottom-center Play button (Glossy 3D Candy Orange Button)
	_play_btn = TextureButton.new()
	_play_btn.name = "PlayButton"
	_play_btn.texture_normal = load("res://assets/ui/buttons/play_orange_normal.png")
	_play_btn.texture_pressed = load("res://assets/ui/buttons/play_orange_pressed.png")
	_play_btn.ignore_texture_size = true
	_play_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_play_btn.button_down.connect(func():
		var tw = _play_btn.create_tween()
		tw.tween_property(_play_btn, "scale", Vector2(0.95, 0.95), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	
	_play_btn.button_up.connect(func():
		var tw = _play_btn.create_tween()
		tw.tween_property(_play_btn, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD)
	)
	
	_play_btn.pressed.connect(func():
		if _play_btn.disabled: return
		_play_btn.disabled = true
		_on_play_pressed()
	)
	hud.add_child(_play_btn)


func _on_play_pressed() -> void:
	AudioManager.play(AudioManager.SFX_UI)
	GameController.start_level(GameController.current_level_number)


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
	wrapper.custom_minimum_size = Vector2(280, 250)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(wrapper)

	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("fcf8ef")
	ps.border_width_bottom = 4
	ps.border_color = Color("e0d2b8")
	ps.set_corner_radius_all(24)
	ps.shadow_color = Color(0,0,0,0.3)
	ps.shadow_size = 9
	ps.shadow_offset = Vector2(0, 6)
	_settings_panel.add_theme_stylebox_override("panel", ps)
	wrapper.add_child(_settings_panel)
	
	# Subtle gloss Panel OVER the settings panel
	var pop_gloss = Panel.new()
	pop_gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_gloss.anchor_bottom = 0.5
	pop_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pg_style = StyleBoxFlat.new()
	pg_style.bg_color = Color(1, 1, 1, 0.18) # Clean subtle gloss, does not wash out title
	pg_style.corner_radius_top_left = 24
	pg_style.corner_radius_top_right = 24
	pop_gloss.add_theme_stylebox_override("panel", pg_style)
	wrapper.add_child(pop_gloss)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_settings_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("4a2810")) # High contrast warm brown (WCAG AAA)
	vbox.add_child(title)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color("d4c3ad")
	vbox.add_child(line)

	var toggles := VBoxContainer.new()
	toggles.add_theme_constant_override("separation", 10)
	vbox.add_child(toggles)

	toggles.add_child(_create_custom_toggle("Sound", "res://assets/ui/icons/sound.svg", SettingsManager.sfx_enabled(), func(on):
		SettingsManager.set_sfx(on)))
	toggles.add_child(_create_custom_toggle("Music", "res://assets/ui/icons/music.svg", SettingsManager.music_enabled(), func(on):
		SettingsManager.set_music(on)
		if on:
			AudioManager.play_music()
		else:
			AudioManager.stop_music()))
	toggles.add_child(_create_custom_toggle("Vibration", "res://assets/ui/icons/vibration.svg", SettingsManager.haptics_enabled(), func(on):
		SettingsManager.set_haptics(on)))

	# --- Professional Vector Close Button (44x44 minimum touch target) ---
	var close_btn := _create_close_button(func():
		AudioManager.play(AudioManager.SFX_UI)
		_settings_overlay.queue_free()
	)
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.anchor_top = 0.0
	close_btn.anchor_bottom = 0.0
	close_btn.offset_left = -22.0
	close_btn.offset_top = -14.0
	close_btn.offset_right = 22.0
	close_btn.offset_bottom = 30.0
	wrapper.add_child(close_btn)

	add_child(_settings_overlay)


func _create_custom_toggle(text: String, icon_path: String, is_on: bool, on_toggle: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(230, 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.size = Vector2(24, 24)
	icon.ignore_texture_size = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color("5c3d2e")) # High contrast chocolate brown (WCAG AAA)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	# Procedural 3D toggle pill (no PNG — sharp at any resolution)
	const PILL_W := 52.0
	const PILL_H := 30.0
	const KNOB := 21.0
	const PAD := 5.0

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
	knob_style.border_width_bottom = 2
	knob_style.border_color = Color("e5e7eb")
	knob_style.shadow_color = Color(0, 0, 0, 0.20)
	knob_style.shadow_size = 3
	knob_style.shadow_offset = Vector2(0, 1)
	knob.add_theme_stylebox_override("panel", knob_style)
	inside.add_child(knob)

	# Invisible full-pill click target
	var hit := Button.new()
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.offset_left = -10
	hit.offset_top = -10
	hit.offset_right = 10
	hit.offset_bottom = 10
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


func _create_close_button(on_close: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(44, 44)
	btn.size = Vector2(44, 44)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color("ef4444")
	c_style.set_corner_radius_all(22)
	c_style.shadow_color = Color(0, 0, 0, 0.35)
	c_style.shadow_size = 5
	c_style.shadow_offset = Vector2(0, 3)
	c_style.border_width_bottom = 3
	c_style.border_color = Color("b91c1c")
	btn.add_theme_stylebox_override("normal", c_style)
	
	var c_hover = c_style.duplicate()
	c_hover.bg_color = Color("f87171")
	btn.add_theme_stylebox_override("hover", c_hover)
	
	var c_pressed = c_style.duplicate()
	c_pressed.bg_color = Color("dc2626")
	c_pressed.shadow_size = 1
	c_pressed.shadow_offset = Vector2(0, 1)
	btn.add_theme_stylebox_override("pressed", c_pressed)
	
	var cg = Panel.new()
	cg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cg.anchor_bottom = 0.5
	cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cgs = StyleBoxFlat.new()
	cgs.bg_color = Color(1, 1, 1, 0.35)
	cgs.corner_radius_top_left = 22
	cgs.corner_radius_top_right = 22
	cg.add_theme_stylebox_override("panel", cgs)
	btn.add_child(cg)
	
	var icon = TextureRect.new()
	icon.texture = load("res://assets/ui/icons/close.svg")
	icon.ignore_texture_size = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	icon.size = Vector2(18, 18)
	icon.position = Vector2(13, 12)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	
	btn.pivot_offset = Vector2(22, 22)
	btn.button_down.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	btn.button_up.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD)
	)
	btn.pressed.connect(func():
		on_close.call()
	)
	return btn

func _exit_tree() -> void:
	if _logo_tween != null and _logo_tween.is_valid():
		_logo_tween.kill()

func _update_layout(override_vp_size: Vector2 = Vector2.ZERO) -> void:
	if _logo_wrapper == null or not is_instance_valid(_logo_wrapper):
		return
	var vp := get_viewport()
	var vp_size: Vector2 = override_vp_size if override_vp_size != Vector2.ZERO else (vp.get_visible_rect().size if vp != null else Vector2(720, 1280))
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(720, 1280)

	# Aspect ratio of the master 3D logo
	var logo_aspect: float = 1036.0 / 711.0
	if _logo_rect != null and is_instance_valid(_logo_rect) and _logo_rect.texture != null:
		var tex_size: Vector2 = _logo_rect.texture.get_size()
		if tex_size.y > 0.0:
			logo_aspect = tex_size.x / tex_size.y

	# Responsive width: fit up to 90% of screen, capped at 680px
	var max_w: float = minf(vp_size.x * 0.90, 680.0)
	var logo_w: float = max_w
	var logo_h: float = logo_w / logo_aspect

	# Responsive 3D Orange Play Button sizing & position
	var btn_w: float = minf(vp_size.x * 0.68, 350.0)
	var btn_h: float = btn_w * (600.0 / 1122.0) # aspect ~0.5348
	var btn_y: float = (vp_size.y * 0.84) - (btn_h * 0.5)
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.size = Vector2(btn_w, btn_h)
		_play_btn.position = Vector2((vp_size.x - btn_w) * 0.5, btn_y)
		_play_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)

	# Height constraints: Settings button at top (~85px), Play button at bottom
	var top_clearance: float = 85.0
	var btm_clearance: float = btn_y - 20.0
	var available_h: float = maxf(100.0, btm_clearance - top_clearance)

	# If logo height exceeds 60% of available vertical height, scale down proportionately
	if logo_h > available_h * 0.60:
		logo_h = available_h * 0.60
		logo_w = logo_h * logo_aspect

	# Perfectly center both horizontally and vertically in the screen space between top and Play button
	var logo_x: float = (vp_size.x - logo_w) * 0.5
	var logo_y: float = top_clearance + (available_h - logo_h) * 0.50

	_logo_wrapper.position = Vector2(logo_x, logo_y)
	_logo_wrapper.size = Vector2(logo_w, logo_h)
	_logo_wrapper.pivot_offset = Vector2(logo_w * 0.5, logo_h * 0.5)

	if _logo_rect != null and is_instance_valid(_logo_rect):
		_logo_rect.position = Vector2.ZERO
		_logo_rect.size = Vector2(logo_w, logo_h)

func _play_logo_entrance_animation() -> void:
	if _logo_wrapper == null or not is_instance_valid(_logo_wrapper):
		return
	if _logo_tween != null and _logo_tween.is_valid():
		_logo_tween.kill()

	# Keep logo completely fixed, stable, and static — NO zooming, booming, or pulsing
	_logo_wrapper.scale = Vector2.ONE
	_logo_wrapper.modulate.a = 1.0

	# Optional single soft specular sheen sweep across the letters
	if _logo_rect != null and is_instance_valid(_logo_rect) and _logo_rect.material is ShaderMaterial:
		var mat := _logo_rect.material as ShaderMaterial
		mat.set_shader_parameter("shine_progress", -0.5)
		var shine_tw = create_tween()
		shine_tw.tween_interval(0.35)
		shine_tw.tween_method(
			func(v: float): mat.set_shader_parameter("shine_progress", v),
			-0.5, 1.5, 0.70
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shine_tw.tween_callback(func():
			if is_instance_valid(mat):
				mat.set_shader_parameter("shine_progress", -1.0)
		)


