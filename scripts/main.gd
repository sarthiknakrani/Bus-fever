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

var _bg_rect: TextureRect
var _sunbeam: TextureRect
var _clouds: Array[TextureRect] = []
var _cloud_speeds: Array[float] = []
var _cloud_base_y: Array[float] = []
var _confetti: CPUParticles2D
var _sparkle_1: TextureRect
var _sparkle_2: TextureRect
var _settings_btn: TextureButton

var _logo_wrapper: Control
var _logo_rect: TextureRect
var _logo_tween: Tween
var _play_btn: TextureButton

var _anim_time: float = 0.0
var _base_logo_pos: Vector2 = Vector2.ZERO
var _base_logo_size: Vector2 = Vector2.ZERO
var _base_play_pos: Vector2 = Vector2.ZERO
var _base_play_size: Vector2 = Vector2.ZERO
var _is_play_pressed: bool = false
var _sheen_timer: float = 0.0
var _gear_timer: float = 0.0


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

	# A. Full portrait 3D isometric town background with subtle breathing parallax
	_bg_rect = TextureRect.new()
	_bg_rect.name = "Background3D"
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.texture = load("res://assets/home_bg_retina.jpg")
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bg_rect)

	# B. Sky Atmospheric Effects: Sunbeam and drifting fluffy cartoon clouds
	_sunbeam = TextureRect.new()
	_sunbeam.name = "SunbeamGlow"
	_sunbeam.texture = load("res://assets/ui/fx/sunbeam.svg")
	_sunbeam.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sunbeam.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sunbeam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sunbeam.modulate = Color(1.0, 0.98, 0.85, 0.22)
	root.add_child(_sunbeam)

	_clouds.clear()
	_cloud_speeds.clear()
	_cloud_base_y.clear()

	var cloud_defs = [
		{"tex": "res://assets/ui/fx/cloud_1.svg", "speed": 12.0, "y": 25.0, "w": 180.0, "h": 90.0, "alpha": 0.65},
		{"tex": "res://assets/ui/fx/cloud_2.svg", "speed": 18.0, "y": 65.0, "w": 220.0, "h": 102.0, "alpha": 0.55},
		{"tex": "res://assets/ui/fx/cloud_1.svg", "speed": 8.0,  "y": 110.0, "w": 150.0, "h": 75.0,  "alpha": 0.45}
	]

	for i in range(cloud_defs.size()):
		var c_data = cloud_defs[i]
		var c_node := TextureRect.new()
		c_node.name = "Cloud_%d" % i
		c_node.texture = load(c_data["tex"])
		c_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c_node.custom_minimum_size = Vector2(c_data["w"], c_data["h"])
		c_node.size = Vector2(c_data["w"], c_data["h"])
		c_node.modulate = Color(1.0, 1.0, 1.0, c_data["alpha"])
		c_node.position = Vector2(float(i * 260) - 100.0, c_data["y"])
		root.add_child(c_node)
		_clouds.append(c_node)
		_cloud_speeds.append(c_data["speed"])
		_cloud_base_y.append(c_data["y"])

	# C. Festive Party Confetti Ambient Particles
	_confetti = CPUParticles2D.new()
	_confetti.name = "PartyConfetti"
	_confetti.emitting = true
	_confetti.amount = 24
	_confetti.lifetime = 6.5
	_confetti.preprocess = 3.5
	_confetti.texture = load("res://assets/ui/fx/confetti.svg")
	_confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_confetti.emission_rect_extents = Vector2(400, 10)
	_confetti.direction = Vector2(0, 1)
	_confetti.spread = 22.0
	_confetti.gravity = Vector2(0, 22)
	_confetti.initial_velocity_min = 18.0
	_confetti.initial_velocity_max = 38.0
	_confetti.angular_velocity_min = -60.0
	_confetti.angular_velocity_max = 60.0
	_confetti.scale_amount_min = 0.45
	_confetti.scale_amount_max = 0.85
	
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color("f43f5e"), # Strawberry pink
		Color("f59e0b"), # Amber yellow
		Color("10b981"), # Green
		Color("06b6d4"), # Cyan
		Color("ec4899")  # Magenta
	])
	_confetti.color_ramp = grad
	root.add_child(_confetti)

	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	# D. Premium 3D Game Title Logo ("BUS FEVER PARTY!")
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

	# Twinkling 3D Star Sparkles on the logo
	_sparkle_1 = TextureRect.new()
	_sparkle_1.name = "LogoSparkleExclamation"
	_sparkle_1.texture = load("res://assets/ui/icons/sparkle.svg")
	_sparkle_1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sparkle_1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sparkle_1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkle_1.size = Vector2(38, 38)
	_sparkle_1.pivot_offset = Vector2(19, 19)
	_logo_wrapper.add_child(_sparkle_1)

	_sparkle_2 = TextureRect.new()
	_sparkle_2.name = "LogoSparkleBus"
	_sparkle_2.texture = load("res://assets/ui/icons/sparkle.svg")
	_sparkle_2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sparkle_2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sparkle_2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkle_2.size = Vector2(30, 30)
	_sparkle_2.pivot_offset = Vector2(15, 15)
	_logo_wrapper.add_child(_sparkle_2)

	# E. Top-right Settings button (Glossy Blue SVG)
	_settings_btn = TextureButton.new()
	_settings_btn.name = "settings_btn"
	_settings_btn.texture_normal = load("res://assets/ui/buttons/settings_gear_normal.svg")
	_settings_btn.texture_pressed = load("res://assets/ui/buttons/settings_gear_pressed.svg")
	_settings_btn.ignore_texture_size = true
	_settings_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_settings_btn.anchor_left = 1.0
	_settings_btn.anchor_right = 1.0
	_settings_btn.anchor_top = 0.0
	_settings_btn.anchor_bottom = 0.0
	_settings_btn.offset_left = -88.0
	_settings_btn.offset_right = -24.0
	_settings_btn.offset_top = 28.0
	_settings_btn.offset_bottom = 92.0
	_settings_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_btn.pivot_offset = Vector2(32, 32)
	
	_settings_btn.button_down.connect(func():
		var tw = _settings_btn.create_tween()
		tw.tween_property(_settings_btn, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	_settings_btn.button_up.connect(func():
		var tw = _settings_btn.create_tween()
		tw.tween_property(_settings_btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
	)
	_settings_btn.pressed.connect(_on_settings_pressed)
	hud.add_child(_settings_btn)

	# F. Bottom-center Play button (Glossy 3D Candy Orange Button)
	_play_btn = TextureButton.new()
	_play_btn.name = "PlayButton"
	_play_btn.texture_normal = load("res://assets/ui/buttons/play_orange_normal.png")
	_play_btn.texture_pressed = load("res://assets/ui/buttons/play_orange_pressed.png")
	_play_btn.ignore_texture_size = true
	_play_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_play_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_play_btn.button_down.connect(func():
		_is_play_pressed = true
		var tw = _play_btn.create_tween()
		tw.tween_property(_play_btn, "scale", Vector2(0.92, 0.92), 0.06).set_trans(Tween.TRANS_QUAD)
	)
	
	_play_btn.button_up.connect(func():
		var tw = _play_btn.create_tween()
		tw.tween_property(_play_btn, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_play_btn, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func(): _is_play_pressed = false)
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
	var logo_aspect: float = 732.0 / 664.0
	if _logo_rect != null and is_instance_valid(_logo_rect) and _logo_rect.texture != null:
		var tex_size: Vector2 = _logo_rect.texture.get_size()
		if tex_size.y > 0.0:
			logo_aspect = tex_size.x / tex_size.y

	# Compact 3D Orange Play Button: 44% width, capped at 260px, elevated higher up (81% height)
	var btn_w: float = minf(vp_size.x * 0.44, 260.0)
	var btn_h: float = btn_w * (590.0 / 1160.0) # aspect ~0.5086
	var btn_y: float = (vp_size.y * 0.81) - (btn_h * 0.5)
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.size = Vector2(btn_w, btn_h)
		_play_btn.position = Vector2((vp_size.x - btn_w) * 0.5, btn_y)
		_play_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)

	# Sky / Cloud Zone constraints:
	# Top clearance below Settings button
	var top_clearance: float = 65.0
	# Background skyline horizon starts at ~0.3706 of screen height (clock tower / palm trees).
	# Max cloud bottom is 0.355 of screen height to guarantee the logo stays 100% in the clouds
	# and NEVER overlaps background town buildings, clock tower, or palm trees below.
	var max_cloud_bottom: float = vp_size.y * 0.355
	var cloud_zone_h: float = maxf(120.0, max_cloud_bottom - top_clearance)

	# Responsive width: prominently enlarged to fill cloud area (up to 75% width, max 540px)
	var max_w: float = minf(vp_size.x * 0.75, 540.0)
	var logo_w: float = max_w
	var logo_h: float = logo_w / logo_aspect

	# Ensure logo fits strictly within the cloud zone with 8% vertical cushion
	var max_cloud_h: float = cloud_zone_h * 0.92
	if logo_h > max_cloud_h:
		logo_h = max_cloud_h
		logo_w = logo_h * logo_aspect

	# Perfectly center horizontally and vertically within the open cloud/sky zone
	var logo_x: float = (vp_size.x - logo_w) * 0.5
	var logo_y: float = top_clearance + (cloud_zone_h - logo_h) * 0.45

	_base_logo_pos = Vector2(logo_x, logo_y)
	_base_logo_size = Vector2(logo_w, logo_h)
	_base_play_pos = Vector2((vp_size.x - btn_w) * 0.5, btn_y)
	_base_play_size = Vector2(btn_w, btn_h)

	_logo_wrapper.position = Vector2(logo_x, logo_y)
	_logo_wrapper.size = Vector2(logo_w, logo_h)
	_logo_wrapper.pivot_offset = Vector2(logo_w * 0.5, logo_h * 0.5)

	if _logo_rect != null and is_instance_valid(_logo_rect):
		_logo_rect.position = Vector2.ZERO
		_logo_rect.size = Vector2(logo_w, logo_h)

	# Position twinkling star sparkles on the candy logo
	if _sparkle_1 != null and is_instance_valid(_sparkle_1):
		_sparkle_1.position = Vector2(logo_w * 0.88 - 19.0, logo_h * 0.66 - 19.0)
	if _sparkle_2 != null and is_instance_valid(_sparkle_2):
		_sparkle_2.position = Vector2(logo_w * 0.14 - 15.0, logo_h * 0.10 - 15.0)

	# Position sunbeam atmospheric glow in top sky corner
	if _sunbeam != null and is_instance_valid(_sunbeam):
		_sunbeam.position = Vector2(-20.0, -20.0)
		_sunbeam.size = Vector2(vp_size.x * 0.75, vp_size.y * 0.45)

	# Position party confetti emitter across top width
	if _confetti != null and is_instance_valid(_confetti):
		_confetti.position = Vector2(vp_size.x * 0.5, -20.0)
		_confetti.emission_rect_extents = Vector2(vp_size.x * 0.55, 10.0)


func _process(delta: float) -> void:
	_anim_time += delta
	var vp := get_viewport()
	var vp_size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(720, 1280)

	# 1. Subtle 3D ambient camera breathing on background (handheld organic feel)
	if _bg_rect != null and is_instance_valid(_bg_rect):
		var bg_offset := Vector2(sin(_anim_time * 0.45) * 6.0, cos(_anim_time * 0.35) * 4.0)
		_bg_rect.position = bg_offset - Vector2(12.0, 12.0)
		_bg_rect.size = vp_size + Vector2(24.0, 24.0)

	# 2. Atmospheric Sunbeam pulse
	if _sunbeam != null and is_instance_valid(_sunbeam):
		_sunbeam.modulate.a = 0.22 + sin(_anim_time * 1.2) * 0.08

	# 3. Drifting Fluffy Cartoon Clouds across the sky
	for i in range(_clouds.size()):
		var c := _clouds[i]
		if c != null and is_instance_valid(c):
			c.position.x += _cloud_speeds[i] * delta
			c.position.y = _cloud_base_y[i] + sin(_anim_time * 1.5 + float(i) * 2.1) * 3.0
			if c.position.x > vp_size.x + 60.0:
				c.position.x = -c.size.x - 60.0

	# 4. Floating 3D Title Logo Bobbing & Gentle Sway
	if _logo_wrapper != null and is_instance_valid(_logo_wrapper):
		var bob_y := sin(_anim_time * 2.0) * 5.5
		var rot_sway := sin(_anim_time * 1.3) * 0.016
		var breathe := 1.0 + sin(_anim_time * 2.2) * 0.02
		_logo_wrapper.position = _base_logo_pos + Vector2(0.0, bob_y)
		_logo_wrapper.rotation = rot_sway
		_logo_wrapper.scale = Vector2(breathe, breathe)

	# 5. Twinkling Golden Star Sparkles on the Logo
	if _sparkle_1 != null and is_instance_valid(_sparkle_1):
		var sp1_t := fmod(_anim_time * 1.6, 3.2)
		var a1 := sin(sp1_t * PI) if sp1_t < 1.0 else 0.0
		a1 = maxf(0.0, a1)
		_sparkle_1.scale = Vector2.ONE * (a1 * 0.95)
		_sparkle_1.rotation += delta * 1.8
		_sparkle_1.modulate.a = a1

	if _sparkle_2 != null and is_instance_valid(_sparkle_2):
		var sp2_t := fmod(_anim_time * 1.6 + 1.6, 3.2)
		var a2 := sin(sp2_t * PI) if sp2_t < 1.0 else 0.0
		a2 = maxf(0.0, a2)
		_sparkle_2.scale = Vector2.ONE * (a2 * 0.85)
		_sparkle_2.rotation -= delta * 1.5
		_sparkle_2.modulate.a = a2

	# 6. Play Button Breathing CTA Pulse
	if _play_btn != null and is_instance_valid(_play_btn) and not _is_play_pressed:
		var btn_pulse := 1.0 + sin(_anim_time * 2.8) * 0.038
		_play_btn.scale = Vector2(btn_pulse, btn_pulse)

	# 7. Periodic Specular Light Sheen sweep across candy logo (every 3.5s)
	_sheen_timer += delta
	if _sheen_timer >= 3.5:
		_sheen_timer = 0.0
		_trigger_specular_sheen()

	# 8. Settings Button Gear subtle wiggle (every 6.0s)
	_gear_timer += delta
	if _gear_timer >= 6.0:
		_gear_timer = 0.0
		_trigger_gear_wiggle()


func _trigger_specular_sheen() -> void:
	if _logo_rect != null and is_instance_valid(_logo_rect) and _logo_rect.material is ShaderMaterial:
		var mat := _logo_rect.material as ShaderMaterial
		var tw = create_tween()
		tw.tween_method(
			func(v: float): mat.set_shader_parameter("shine_progress", v),
			-0.5, 1.5, 0.75
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			if is_instance_valid(mat):
				mat.set_shader_parameter("shine_progress", -1.0)
		)


func _trigger_gear_wiggle() -> void:
	if _settings_btn != null and is_instance_valid(_settings_btn):
		var tw = create_tween()
		tw.tween_property(_settings_btn, "rotation_degrees", 15.0, 0.15).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_settings_btn, "rotation_degrees", -10.0, 0.15).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_settings_btn, "rotation_degrees", 0.0, 0.12).set_trans(Tween.TRANS_SINE)


func _play_logo_entrance_animation() -> void:
	if _logo_wrapper == null or not is_instance_valid(_logo_wrapper):
		return
	if _logo_tween != null and _logo_tween.is_valid():
		_logo_tween.kill()

	# Juicy dynamic entrance: scales up from 0.7 with bouncy overshoot
	_logo_wrapper.scale = Vector2(0.7, 0.7)
	_logo_wrapper.modulate.a = 0.0

	_logo_tween = create_tween().set_parallel(true)
	_logo_tween.tween_property(_logo_wrapper, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_logo_tween.tween_property(_logo_wrapper, "modulate:a", 1.0, 0.40).set_trans(Tween.TRANS_SINE)

	# Trigger initial specular sheen glint
	_logo_tween.chain().tween_callback(_trigger_specular_sheen)



