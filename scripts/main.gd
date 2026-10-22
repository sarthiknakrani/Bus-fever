extends Node

# ---------- 3D-style helpers ----------
# A simple "extruded" label: one dark offset duplicate beneath the front label
# gives the text a clean, raised look without stacked shadows / gloss.

const BG_COLOR := Color("cfe8ff")
const PLAY_FRONT := Color("4ade80")
const PLAY_BACK := Color("15803d")

const ClayStyle := preload("res://scripts/ui/style_helpers.gd")
const CoinCounterHUDClass := preload("res://scripts/ui/coin_counter_hud.gd")

var _root_ctrl: Control
var _hud_ctrl: Control
var _settings_overlay: Control
var _settings_panel: PanelContainer

var _bg_rect: TextureRect
var _settings_btn: TextureButton
var _coin_counter: Control
var _logo_wrapper: Control
var _logo_rect: TextureRect
var _logo_tween: Tween
var _logo_shine_tween: Tween
var _play_btn: TextureButton
var _is_transitioning: bool = false


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

	_root_ctrl = Control.new()
	_root_ctrl.name = "HomeRoot"
	_root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_ctrl)

	# A. Full portrait 3D isometric town background (static)
	_bg_rect = TextureRect.new()
	_bg_rect.name = "Background3D"
	_bg_rect.texture = load("res://assets/home_bg_retina.jpg")
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_bg_rect)

	_hud_ctrl = Control.new()
	_hud_ctrl.name = "HUD"
	_hud_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_hud_ctrl)

	# B. Premium 3D Game Title Logo ("BUS FEVER PARTY!" - static)
	_logo_wrapper = Control.new()
	_logo_wrapper.name = "TitleLogoWrapper"
	_logo_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ctrl.add_child(_logo_wrapper)

	_logo_rect = TextureRect.new()
	_logo_rect.name = "LogoTexture"
	_logo_rect.texture = load("res://assets/ui/logo/bus_fever_party_logo.png")
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shine_mat := ShaderMaterial.new()
	shine_mat.shader = load("res://assets/shaders/logo_gloss_shine.gdshader")
	shine_mat.set_shader_parameter("cycle_duration", 3.2)
	shine_mat.set_shader_parameter("sweep_duration", 1.8)
	shine_mat.set_shader_parameter("shine_width", 0.035)
	shine_mat.set_shader_parameter("shine_softness", 0.018)
	shine_mat.set_shader_parameter("secondary_width", 0.012)
	shine_mat.set_shader_parameter("secondary_offset", 0.045)
	shine_mat.set_shader_parameter("secondary_alpha", 0.35)
	shine_mat.set_shader_parameter("use_time_cycle", true)
	_logo_rect.material = shine_mat

	_logo_wrapper.add_child(_logo_rect)

	# C. Top-right Settings button (Glossy Blue SVG - static)
	_settings_btn = TextureButton.new()
	_settings_btn.name = "settings_btn"
	_settings_btn.texture_normal = load("res://assets/ui/buttons/settings_gear_normal.svg")
	_settings_btn.texture_pressed = load("res://assets/ui/buttons/settings_gear_pressed.svg")
	_settings_btn.ignore_texture_size = true
	_settings_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_btn.focus_mode = Control.FOCUS_NONE
	_settings_btn.pressed.connect(_on_settings_pressed)
	ClayStyle.apply_clay_squish(_settings_btn, 3.0, 0.91)
	_hud_ctrl.add_child(_settings_btn)

	# D. Bottom-center Play button (Glossy 3D Candy Orange Button - static)
	_play_btn = TextureButton.new()
	_play_btn.name = "PlayButton"
	_play_btn.texture_normal = load("res://assets/ui/buttons/play_orange_normal.png")
	_play_btn.texture_pressed = load("res://assets/ui/buttons/play_orange_pressed.png")
	_play_btn.ignore_texture_size = true
	_play_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_play_btn.focus_mode = Control.FOCUS_NONE
	_play_btn.pressed.connect(_on_play_pressed)
	ClayStyle.apply_clay_squish(_play_btn, 4.0, 0.93)
	_hud_ctrl.add_child(_play_btn)

	# E. Top-left Premium Coin Counter HUD
	_coin_counter = CoinCounterHUDClass.new()
	_coin_counter.name = "CoinCounterHUD"
	_coin_counter.set_custom_action("PLAY NOW!", _on_play_pressed)
	_hud_ctrl.add_child(_coin_counter)


func _play_sfx(sfx_name: String = "ui_click") -> void:
	var am = get_tree().root.get_node_or_null("AudioManager") if is_inside_tree() and get_tree() and get_tree().root else null
	if am != null and am.has_method("play"):
		am.play(sfx_name)

func _get_game_controller() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("GameController")
	return null

func _get_settings_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("SettingsManager")
	return null

func _on_play_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	if _logo_shine_tween != null and _logo_shine_tween.is_valid():
		_logo_shine_tween.kill()
	_play_sfx("ui_click")
	var gc := _get_game_controller()
	if gc != null and gc.has_method("start_level"):
		gc.start_level(gc.get("current_level_number") if "current_level_number" in gc else 1)
	# Safety re-arm if transition takes a moment or is cancelled
	var t := get_tree()
	if t != null:
		t.create_timer(1.5).timeout.connect(func():
			_is_transitioning = false
		)


func _on_settings_pressed() -> void:
	_play_sfx("ui_click")
	_show_settings_overlay()


func _show_settings_overlay() -> void:
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
		_settings_overlay = null

	_settings_overlay = Control.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_ctrl.add_child(_settings_overlay)
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Scrim
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim_state := {"pressed": false}
	scrim.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch:
			if event.pressed:
				scrim_state["pressed"] = true
			elif scrim_state["pressed"]:
				_play_sfx("ui_click")
				if _settings_overlay != null and is_instance_valid(_settings_overlay):
					_settings_overlay.queue_free()
					_settings_overlay = null
	)
	_settings_overlay.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Wrapper Control so the close button can anchor freely OUTSIDE the
	# PanelContainer (PanelContainer forces child layout and ignores anchors).
	var wrapper := Control.new()
	wrapper.name = "ModalWrapper"
	wrapper.custom_minimum_size = Vector2(280, 250)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(wrapper)

	_settings_panel = PanelContainer.new()
	_settings_panel.name = "PanelContainer"
	var ps := ClayStyle.create_clay_panel(Color("fffdf7"), Color("e6d8c3"), 28, 6, 22, 8, Color(0, 0, 0, 0.25))
	_settings_panel.add_theme_stylebox_override("panel", ps)
	wrapper.add_child(_settings_panel)
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Subtle clay gloss Panel OVER the settings panel
	var pop_gloss := Panel.new()
	pop_gloss.name = "GlossPanel"
	pop_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pg_style := ClayStyle.create_clay_highlight_style(28, 0.22)
	pop_gloss.add_theme_stylebox_override("panel", pg_style)
	wrapper.add_child(pop_gloss)
	pop_gloss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pop_gloss.anchor_bottom = 0.5
	pop_gloss.offset_bottom = 0.0

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_settings_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.name = "SettingsTitle"
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("4a2810")) # High contrast warm brown (WCAG AAA)
	vbox.add_child(title)

	var line := ColorRect.new()
	line.name = "DividerLine"
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color("d4c3ad")
	vbox.add_child(line)

	var toggles := VBoxContainer.new()
	toggles.name = "TogglesVBox"
	toggles.add_theme_constant_override("separation", 10)
	vbox.add_child(toggles)

	var sm_mgr = _get_settings_manager()
	var sfx_on: bool = sm_mgr.sfx_enabled() if sm_mgr and sm_mgr.has_method("sfx_enabled") else true
	var music_on: bool = sm_mgr.music_enabled() if sm_mgr and sm_mgr.has_method("music_enabled") else true
	var haptics_on: bool = sm_mgr.haptics_enabled() if sm_mgr and sm_mgr.has_method("haptics_enabled") else true

	toggles.add_child(_create_custom_toggle("Sound", "res://assets/ui/icons/sound.svg", sfx_on, func(on):
		var s = _get_settings_manager()
		if s and s.has_method("set_sfx"): s.set_sfx(on)))
	toggles.add_child(_create_custom_toggle("Music", "res://assets/ui/icons/music.svg", music_on, func(on):
		var s = _get_settings_manager()
		if s and s.has_method("set_music"): s.set_music(on)
		var am = get_tree().root.get_node_or_null("AudioManager") if is_inside_tree() and get_tree() and get_tree().root else null
		if am:
			if on and am.has_method("play_music"):
				am.play_music()
			elif not on and am.has_method("stop_music"):
				am.stop_music()))
	toggles.add_child(_create_custom_toggle("Vibration", "res://assets/ui/icons/vibration.svg", haptics_on, func(on):
		var s = _get_settings_manager()
		if s and s.has_method("set_haptics"): s.set_haptics(on)))

	# --- Professional Vector Close Button (44x44 minimum touch target) ---
	var close_btn := _create_close_button(func():
		_play_sfx("ui_click")
		if _settings_overlay != null and is_instance_valid(_settings_overlay):
			_settings_overlay.queue_free()
			_settings_overlay = null
	)
	close_btn.name = "CloseButton"
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.anchor_top = 0.0
	close_btn.anchor_bottom = 0.0
	close_btn.offset_left = -22.0
	close_btn.offset_top = -14.0
	close_btn.offset_right = 22.0
	close_btn.offset_bottom = 30.0
	wrapper.add_child(close_btn)


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

	# Procedural Clay toggle pill
	const PILL_W := 54.0
	const PILL_H := 32.0
	const KNOB := 22.0
	const PAD := 5.0

	var pill := Panel.new()
	pill.custom_minimum_size = Vector2(PILL_W, PILL_H)
	pill.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var pill_style := ClayStyle.create_clay_pill(
		Color("22c55e") if is_on else Color("cbd5e1"),
		Color("15803d") if is_on else Color("94a3b8"),
		3, 8, 2, 0.16
	)
	pill.add_theme_stylebox_override("panel", pill_style)
	
	var t_gloss := Panel.new()
	t_gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t_gloss.anchor_bottom = 0.48
	t_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tg_style := ClayStyle.create_clay_highlight_style(int(PILL_H / 2), 0.32)
	t_gloss.add_theme_stylebox_override("panel", tg_style)
	pill.add_child(t_gloss)
	
	# Shine animation for toggles that are ON
	if is_on:
		var shine = ColorRect.new()
		shine.color = Color(1, 1, 1, 0.4)
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
	var knob_style := ClayStyle.create_clay_button_style(Color("ffffff"), Color("cbd5e1"), int(KNOB / 2), 3, 5, 2, 0.22)
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
	var toggle_fn = func():
		_play_sfx("ui_click")
		state["on"] = not state["on"]
		var on: bool = state["on"]
		pill_style.bg_color = Color("22c55e") if on else Color("cbd5e1")
		pill_style.border_color = Color("15803d") if on else Color("94a3b8")
		var target_x: float = (PILL_W - KNOB - PAD) if on else PAD
		var ktw := knob.create_tween()
		ktw.tween_property(knob, "position:x", target_x, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		on_toggle.call(on)

	hit.pressed.connect(toggle_fn)
	hit.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and not event.pressed:
			toggle_fn.call()
	)

	var pill_center := CenterContainer.new()
	pill_center.add_child(pill)
	row.add_child(pill_center)
	return row


func _create_close_button(on_close: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(44, 44)
	btn.size = Vector2(44, 44)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	
	var c_style := ClayStyle.create_clay_button_style(Color("ef4444"), Color("b91c1c"), 22, 4, 10, 4, 0.25)
	btn.add_theme_stylebox_override("normal", c_style)
	
	var c_hover := c_style.duplicate()
	c_hover.bg_color = Color("f87171")
	btn.add_theme_stylebox_override("hover", c_hover)
	
	var c_pressed := c_style.duplicate()
	c_pressed.bg_color = Color("dc2626")
	c_pressed.border_width_bottom = 2
	c_pressed.shadow_size = 4
	c_pressed.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("pressed", c_pressed)
	
	var cg := Panel.new()
	cg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cg.anchor_bottom = 0.5
	cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cgs := ClayStyle.create_clay_highlight_style(22, 0.35)
	cg.add_theme_stylebox_override("panel", cgs)
	btn.add_child(cg)
	
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/icons/close.svg")
	icon.ignore_texture_size = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	icon.size = Vector2(18, 18)
	icon.position = Vector2(13, 11)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	
	btn.pivot_offset = Vector2(22, 22)
	ClayStyle.apply_clay_squish(btn, 2.5, 0.90)
	btn.pressed.connect(on_close)
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch and not event.pressed:
			on_close.call()
	)
	return btn

func _exit_tree() -> void:
	if _logo_tween != null and _logo_tween.is_valid():
		_logo_tween.kill()
	if _logo_shine_tween != null and _logo_shine_tween.is_valid():
		_logo_shine_tween.kill()

func _update_layout(override_vp_size: Vector2 = Vector2.ZERO) -> void:
	if _logo_wrapper == null or not is_instance_valid(_logo_wrapper):
		return
	var vp := get_viewport()
	var vp_size: Vector2 = override_vp_size if override_vp_size != Vector2.ZERO else (vp.get_visible_rect().size if vp != null else Vector2(720, 1280))
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(720, 1280)

	# root/hud/bg_rect use PRESET_FULL_RECT anchors — no manual size needed

	# Aspect ratio of the master 3D logo
	var logo_aspect: float = 732.0 / 664.0
	if _logo_rect != null and is_instance_valid(_logo_rect) and _logo_rect.texture != null:
		var tex_size: Vector2 = _logo_rect.texture.get_size()
		if tex_size.y > 0.0:
			logo_aspect = tex_size.x / tex_size.y

	# Top safe area calculation for header controls
	var safe_top: float = 28.0
	if DisplayServer.has_method("get_display_safe_area"):
		var safe_rect = DisplayServer.get_display_safe_area()
		if safe_rect.position.y > 0:
			safe_top = maxf(28.0, safe_rect.position.y + 6.0)

	var s_size: float = 64.0

	# Responsive Coin Counter sizing: scaled proportionally to viewport width
	var c_h: float = clampf(vp_size.x * 0.082, 28.0, 36.0)
	var c_w: float = c_h * 4.0
	if _coin_counter != null and is_instance_valid(_coin_counter):
		_coin_counter.custom_minimum_size = Vector2(c_w, c_h)
		_coin_counter.size = Vector2(c_w, c_h)
		# Vertically center-aligned with the settings button
		var c_y: float = safe_top + (s_size - c_h) * 0.5
		_coin_counter.position = Vector2(20.0, c_y)

	# Top-right Settings button (explicit positioning matching visual button)
	if _settings_btn != null and is_instance_valid(_settings_btn):
		_settings_btn.size = Vector2(s_size, s_size)
		_settings_btn.position = Vector2(vp_size.x - s_size - 24.0, safe_top)
		_settings_btn.pivot_offset = Vector2(s_size * 0.5, s_size * 0.5)
		_settings_btn.rotation = 0.0

	# Compact 3D Orange Play Button: 48% width, capped at 280px, elevated higher up (81% height)
	var btn_w: float = minf(vp_size.x * 0.48, 280.0)
	var btn_h: float = btn_w * (590.0 / 1160.0) # aspect ~0.5086
	var btn_y: float = (vp_size.y * 0.81) - (btn_h * 0.5)
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.size = Vector2(btn_w, btn_h)
		_play_btn.position = Vector2((vp_size.x - btn_w) * 0.5, btn_y)
		_play_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)
		_play_btn.scale = Vector2.ONE
		_play_btn.rotation = 0.0

	# Sky / Cloud Zone constraints:
	# Top clearance ensures comfortable headroom below status bar / bezel and settings button (bottom at ~92px)
	var top_clearance: float = maxf(140.0, vp_size.y * 0.18)
	# Skyline starts at ~43.5% of height (palm trees, clock tower, colorful rooftops)
	var skyline_top: float = vp_size.y * 0.435
	var available_sky_h: float = maxf(120.0, skyline_top - top_clearance)

	# Responsive width: comfortably fills cloud area without stretching across screen edge
	var max_w: float = minf(vp_size.x * 0.70, 460.0)
	var logo_w: float = max_w
	var logo_h: float = logo_w / logo_aspect

	# Fit within available sky zone so it never overlaps the town buildings or palm trees
	var max_logo_h: float = available_sky_h * 0.82
	if logo_h > max_logo_h:
		logo_h = max_logo_h
		logo_w = logo_h * logo_aspect

	# Horizontally centered, shifted distinctly lower down into the sky zone (user requested: aur thoda niche kar)
	var logo_x: float = (vp_size.x - logo_w) * 0.5
	var logo_y: float = top_clearance + (available_sky_h - logo_h) * 0.82

	_logo_wrapper.position = Vector2(logo_x, logo_y)
	_logo_wrapper.size = Vector2(logo_w, logo_h)
	_logo_wrapper.pivot_offset = Vector2(logo_w * 0.5, logo_h * 0.5)
	_logo_wrapper.scale = Vector2.ONE
	_logo_wrapper.rotation = 0.0
	_logo_wrapper.modulate.a = 1.0

	if _logo_rect != null and is_instance_valid(_logo_rect):
		_logo_rect.position = Vector2.ZERO
		_logo_rect.size = Vector2(logo_w, logo_h)
		_logo_rect.pivot_offset = Vector2(logo_w * 0.5, logo_h * 0.5)
		_logo_rect.scale = Vector2.ONE


func _play_logo_entrance_animation() -> void:
	if _logo_wrapper != null and is_instance_valid(_logo_wrapper):
		_logo_wrapper.scale = Vector2.ONE
		_logo_wrapper.rotation = 0.0
		_logo_wrapper.modulate.a = 1.0
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.scale = Vector2.ONE
		_play_btn.rotation = 0.0
	if _settings_btn != null and is_instance_valid(_settings_btn):
		_settings_btn.rotation = 0.0

	_start_logo_shine_animation()


func _start_logo_shine_animation() -> void:
	if _logo_rect == null or not is_instance_valid(_logo_rect):
		return
	var sm := _logo_rect.material as ShaderMaterial
	if sm == null:
		return

	# Hardware GPU-accelerated specular sweep via built-in TIME (smooth 60/120fps, zero lag)
	sm.set_shader_parameter("use_time_cycle", true)
	sm.set_shader_parameter("cycle_duration", 3.2)
	sm.set_shader_parameter("sweep_duration", 1.8)
	sm.set_shader_parameter("shine_width", 0.035)
	sm.set_shader_parameter("shine_softness", 0.018)
	sm.set_shader_parameter("secondary_width", 0.012)
	sm.set_shader_parameter("secondary_offset", 0.045)
	sm.set_shader_parameter("secondary_alpha", 0.35)
