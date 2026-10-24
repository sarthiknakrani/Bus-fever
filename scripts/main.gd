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

	# B. Premium 3D Game Title Logo ("BUS PARTY" - static)
	_logo_wrapper = Control.new()
	_logo_wrapper.name = "TitleLogoWrapper"
	_logo_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ctrl.add_child(_logo_wrapper)

	_logo_rect = TextureRect.new()
	_logo_rect.name = "LogoTexture"
	_logo_rect.texture = load("res://assets/ui/logo/bus_party_logo.png")
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

	# C. Top-right Settings button (Genuine Claymorphic 3D Gear Icon)
	_settings_btn = ClayStyle.create_clay_texture_button("res://assets/ui/clay_textless/icon_settings_blue.png", Vector2(50, 50), 0.95)
	_settings_btn.name = "settings_btn"
	_settings_btn.pressed.connect(_on_settings_pressed)
	_hud_ctrl.add_child(_settings_btn)

	# D. Bottom-center Play button (Textless Orange Button with Dynamic Styled Text)
	_play_btn = ClayStyle.create_text_button("res://assets/ui/clay_textless/button_orange_large_blank.png", "PLAY", Vector2.ZERO, 32, false, 0.95)
	_play_btn.name = "PlayButton"
	_play_btn.pressed.connect(_on_play_pressed)
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

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Wrapper Control so the close button can anchor freely OUTSIDE the PanelContainer
	var wrapper := Control.new()
	wrapper.name = "ModalWrapper"
	wrapper.custom_minimum_size = Vector2(300, 270)
	wrapper.size = Vector2(300, 270)
	wrapper.pivot_offset = Vector2(150, 135)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(wrapper)

	var close_overlay = func():
		_play_sfx("ui_click")
		if _settings_overlay != null and is_instance_valid(_settings_overlay):
			if is_instance_valid(wrapper):
				var tw := wrapper.create_tween()
				tw.set_parallel(true)
				tw.tween_property(wrapper, "scale", Vector2(0.85, 0.85), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.tween_property(wrapper, "modulate:a", 0.0, 0.12)
				tw.chain().tween_callback(func():
					if _settings_overlay != null and is_instance_valid(_settings_overlay):
						_settings_overlay.queue_free()
						_settings_overlay = null
				)
			else:
				_settings_overlay.queue_free()
				_settings_overlay = null

	# Scrim tap dismiss
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_overlay.call()
	)
	_settings_overlay.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.move_child(scrim, 0) # Place scrim behind center container

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
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 22)
	_settings_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var header_rect := ClayStyle.create_banner_header("SETTINGS", "res://assets/ui/clay_textless/banner_navy_gold_compact_blank.png", Vector2(190, 44), 26)
	header_rect.name = "SettingsHeader"
	header_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(header_rect)

	var toggles := VBoxContainer.new()
	toggles.name = "TogglesVBox"
	toggles.add_theme_constant_override("separation", 12)
	vbox.add_child(toggles)

	var sm_mgr = _get_settings_manager()
	var sfx_on: bool = sm_mgr.sfx_enabled() if sm_mgr and sm_mgr.has_method("sfx_enabled") else true
	var music_on: bool = sm_mgr.music_enabled() if sm_mgr and sm_mgr.has_method("music_enabled") else true
	var haptics_on: bool = sm_mgr.haptics_enabled() if sm_mgr and sm_mgr.has_method("haptics_enabled") else true

	toggles.add_child(_create_custom_toggle("Sound", "res://assets/ui/clay_textless/icon_sound_cream.png", sfx_on, func(on):
		var s = _get_settings_manager()
		if s and s.has_method("set_sfx"): s.set_sfx(on)))
	toggles.add_child(_create_custom_toggle("Music", "res://assets/ui/clay_textless/icon_music_cream.png", music_on, func(on):
		var s = _get_settings_manager()
		if s and s.has_method("set_music"): s.set_music(on)
		var am = get_tree().root.get_node_or_null("AudioManager") if is_inside_tree() and get_tree() and get_tree().root else null
		if am:
			if on and am.has_method("play_music"):
				am.play_music()
			elif not on and am.has_method("stop_music"):
				am.stop_music()))
	toggles.add_child(_create_custom_toggle("Vibration", "res://assets/ui/clay_textless/icon_vibration_cream.png", haptics_on, func(on):
		var s = _get_settings_manager()
		if s and s.has_method("set_haptics"): s.set_haptics(on)))

	# --- Claymorphic Close Button ---
	var close_btn := _create_close_button(close_overlay)
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

	# Silky smooth entrance pop-in
	wrapper.scale = Vector2(0.85, 0.85)
	wrapper.modulate.a = 0.0
	var etw := wrapper.create_tween()
	etw.set_parallel(true)
	etw.tween_property(wrapper, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	etw.tween_property(wrapper, "modulate:a", 1.0, 0.16)


func _create_custom_toggle(text: String, icon_path: String, is_on: bool, on_toggle: Callable) -> Control:
	var row_wrapper := Control.new()
	row_wrapper.custom_minimum_size = Vector2(240, 44)
	row_wrapper.size = Vector2(240, 44)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_wrapper.add_child(row)

	var icon := TextureRect.new()
	if ResourceLoader.exists(icon_path):
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
	ClayStyle.apply_label_style(lbl, 16, Color("4a2810"), Color.TRANSPARENT, 0, Color.TRANSPARENT, Vector2.ZERO, false)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	# Genuine Claymorphic ON/OFF toggle texture button
	var toggle_btn := TextureButton.new()
	toggle_btn.ignore_texture_size = true
	toggle_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	toggle_btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	toggle_btn.custom_minimum_size = Vector2(56, 36)
	toggle_btn.size = Vector2(56, 36)
	toggle_btn.pivot_offset = Vector2(28, 18)
	toggle_btn.texture_normal = load("res://assets/ui/clay_textless/toggle_on_green.png" if is_on else "res://assets/ui/clay_textless/toggle_off_grey.png")
	toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_btn.focus_mode = Control.FOCUS_NONE
	ClayStyle.apply_clay_squish(toggle_btn, 2.0, 0.95)

	var state := {"on": is_on}
	toggle_btn.pressed.connect(func():
		_play_sfx("ui_click")
		state["on"] = not state["on"]
		toggle_btn.texture_normal = load("res://assets/ui/clay_textless/toggle_on_green.png" if state["on"] else "res://assets/ui/clay_textless/toggle_off_grey.png")
		on_toggle.call(state["on"])
	)
	row.add_child(toggle_btn)

	return row_wrapper


func _create_close_button(on_close: Callable) -> Control:
	var btn := ClayStyle.create_clay_texture_button("res://assets/ui/clay_textless/icon_close_red.png", Vector2(40, 40), 0.95)
	btn.pressed.connect(on_close)
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

	var s_w: float = 52.0
	var s_h: float = s_w * (305.0 / 310.0)

	# Responsive Coin Counter sizing: scaled proportionally to viewport width (452x151 aspect)
	var c_h: float = clampf(vp_size.x * 0.088, 30.0, 38.0)
	var c_w: float = c_h * (452.0 / 151.0)
	if _coin_counter != null and is_instance_valid(_coin_counter):
		_coin_counter.custom_minimum_size = Vector2(c_w, c_h)
		_coin_counter.size = Vector2(c_w, c_h)
		# Vertically center-aligned with the settings button
		var c_y: float = safe_top + (s_h - c_h) * 0.5
		_coin_counter.position = Vector2(20.0, c_y)

	# Top-right Settings button (explicit positioning matching visual button)
	if _settings_btn != null and is_instance_valid(_settings_btn):
		_settings_btn.size = Vector2(s_w, s_h)
		_settings_btn.position = Vector2(vp_size.x - s_w - 24.0, safe_top)
		_settings_btn.pivot_offset = Vector2(s_w * 0.5, s_h * 0.5)
		_settings_btn.rotation = 0.0

	# 3D Orange Play Button (735x268 textless claymorphic artwork)
	var btn_w: float = minf(vp_size.x * 0.62, 310.0)
	var btn_h: float = btn_w * (268.0 / 735.0)
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
