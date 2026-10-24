extends Node

## Rebuilt Home Screen Controller for "Bus Party"
## Strictly constructed using independent artwork assets and Godot nodes.

const BG_COLOR := Color("cfe8ff")
const ClayStyle := preload("res://scripts/ui/style_helpers.gd")
const CoinCounterHUDClass := preload("res://scripts/ui/coin_counter_hud.gd")

# Root & Container References
var _home_screen: Control
var _bg_sky: Control
var _sky_gradient: TextureRect
var _clouds: Control

var _bg_town: Control
var _ocean: TextureRect
var _coastal_buildings: TextureRect
var _palm_trees: TextureRect
var _town_decorations: TextureRect

var _midground_road: Control
var _road_surface: TextureRect
var _road_markings: TextureRect
var _parking_lines: TextureRect
var _pavement: TextureRect

var _dec_left_fg: Control
var _left_leaves: TextureRect
var _left_flowers: TextureRect

var _dec_right_fg: Control
var _right_leaves: TextureRect
var _right_flowers: TextureRect

var _logo_ctrl: Control
var _logo_rect: TextureRect

var _coin_bar: Control
var _coin_icon: TextureRect
var _coin_label: Label
var _plus_btn: TextureButton

var _settings_btn: TextureButton

var _bus_group: Control
var _bus_red: TextureRect
var _bus_yellow: TextureRect
var _bus_blue: TextureRect

var _play_btn: TextureButton
var _play_label: Label

var _settings_overlay: Control
var _settings_panel: PanelContainer

var _is_transitioning: bool = false
var _idle_time: float = 0.0


func _ready() -> void:
	if DisplayServer.has_method("set_icon"):
		var icon_tex = load("res://icon.png")
		if icon_tex != null and icon_tex is Texture2D:
			DisplayServer.set_icon(icon_tex.get_image())
	_build_ui()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_on_viewport_size_changed)
	_update_layout()


func _process(delta: float) -> void:
	_idle_time += delta
	# Subtle synchronized idle breathing / suspension hover for showcase buses
	if _bus_group != null and is_instance_valid(_bus_group):
		var hover_y: float = sin(_idle_time * 2.2) * 1.8
		if _bus_red != null and is_instance_valid(_bus_red):
			_bus_red.position.y = _bus_red_base_y + hover_y
		if _bus_yellow != null and is_instance_valid(_bus_yellow):
			_bus_yellow.position.y = _bus_yellow_base_y + hover_y * 0.95
		if _bus_blue != null and is_instance_valid(_bus_blue):
			_bus_blue.position.y = _bus_blue_base_y + hover_y * 1.05


var _bus_red_base_y: float = 0.0
var _bus_yellow_base_y: float = 0.0
var _bus_blue_base_y: float = 0.0


func _on_viewport_size_changed() -> void:
	_update_layout()


# ==============================================================================
# 1. HIERARCHY CONSTRUCTION (MATCHING STRICT SPECIFICATION)
# ==============================================================================
func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	# Root: HomeScreen
	_home_screen = Control.new()
	_home_screen.name = "HomeScreen"
	_home_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_home_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_home_screen)

	# -------------------------------------------------------------
	# A. BackgroundSky
	# -------------------------------------------------------------
	_bg_sky = Control.new()
	_bg_sky.name = "BackgroundSky"
	_bg_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_screen.add_child(_bg_sky)

	_sky_gradient = TextureRect.new()
	_sky_gradient.name = "SkyGradient"
	_sky_gradient.texture = load("res://assets/home/sky_gradient.png")
	_sky_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky_gradient.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sky_gradient.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_sky.add_child(_sky_gradient)

	_clouds = Control.new()
	_clouds.name = "Clouds"
	_clouds.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_sky.add_child(_clouds)

	# -------------------------------------------------------------
	# B. BackgroundTown
	# -------------------------------------------------------------
	_bg_town = Control.new()
	_bg_town.name = "BackgroundTown"
	_bg_town.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_town.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_screen.add_child(_bg_town)

	_ocean = TextureRect.new()
	_ocean.name = "Ocean"
	_ocean.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_town.add_child(_ocean)

	# Master seaside town artwork (Ocean, CoastalBuildings, PalmTrees, TownDecorations)
	_coastal_buildings = TextureRect.new()
	_coastal_buildings.name = "CoastalBuildings"
	_coastal_buildings.texture = load("res://assets/home/coastal_town_empty_road.png")
	_coastal_buildings.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coastal_buildings.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_coastal_buildings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coastal_buildings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_town.add_child(_coastal_buildings)

	_palm_trees = TextureRect.new()
	_palm_trees.name = "PalmTrees"
	_palm_trees.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_town.add_child(_palm_trees)

	_town_decorations = TextureRect.new()
	_town_decorations.name = "TownDecorations"
	_town_decorations.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_town.add_child(_town_decorations)

	# -------------------------------------------------------------
	# C. MidgroundRoad
	# -------------------------------------------------------------
	_midground_road = Control.new()
	_midground_road.name = "MidgroundRoad"
	_midground_road.set_anchors_preset(Control.PRESET_FULL_RECT)
	_midground_road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_screen.add_child(_midground_road)

	_road_surface = TextureRect.new()
	_road_surface.name = "RoadSurface"
	_road_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_midground_road.add_child(_road_surface)

	_road_markings = TextureRect.new()
	_road_markings.name = "RoadMarkings"
	_road_markings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_midground_road.add_child(_road_markings)

	_parking_lines = TextureRect.new()
	_parking_lines.name = "ParkingLines"
	_parking_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_midground_road.add_child(_parking_lines)

	_pavement = TextureRect.new()
	_pavement.name = "Pavement"
	_pavement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_midground_road.add_child(_pavement)

	# -------------------------------------------------------------
	# D. Decorative Foreground Foliage (Framing Lower Corners)
	# -------------------------------------------------------------
	_dec_left_fg = Control.new()
	_dec_left_fg.name = "DecorativeLeftForeground"
	_dec_left_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dec_left_fg.z_index = 2
	_home_screen.add_child(_dec_left_fg)

	_left_leaves = TextureRect.new()
	_left_leaves.name = "Leaves"
	_left_leaves.texture = load("res://assets/home/foliage_left.png")
	_left_leaves.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_left_leaves.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_left_leaves.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_left_leaves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dec_left_fg.add_child(_left_leaves)

	_left_flowers = TextureRect.new()
	_left_flowers.name = "Flowers"
	_left_flowers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dec_left_fg.add_child(_left_flowers)

	_dec_right_fg = Control.new()
	_dec_right_fg.name = "DecorativeRightForeground"
	_dec_right_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dec_right_fg.z_index = 2
	_home_screen.add_child(_dec_right_fg)

	_right_leaves = TextureRect.new()
	_right_leaves.name = "Leaves"
	_right_leaves.texture = load("res://assets/home/foliage_right.png")
	_right_leaves.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right_leaves.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_right_leaves.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_right_leaves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dec_right_fg.add_child(_right_leaves)

	_right_flowers = TextureRect.new()
	_right_flowers.name = "Flowers"
	_right_flowers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dec_right_fg.add_child(_right_flowers)

	# -------------------------------------------------------------
	# E. Logo (BUS PARTY 3D Badge)
	# -------------------------------------------------------------
	_logo_ctrl = Control.new()
	_logo_ctrl.name = "Logo"
	_logo_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_ctrl.z_index = 2
	_home_screen.add_child(_logo_ctrl)

	_logo_rect = TextureRect.new()
	_logo_rect.name = "BusPartyLogo"
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
	_logo_ctrl.add_child(_logo_rect)

	# -------------------------------------------------------------
	# F. CoinBar (Separate CoinIcon, CoinLabel, PlusButton)
	# -------------------------------------------------------------
	_coin_bar = TextureRect.new()
	_coin_bar.name = "CoinBar"
	_coin_bar.texture = load("res://assets/ui/clay_textless/counter_navy_coin_plus_wide_blank.png")
	_coin_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coin_bar.stretch_mode = TextureRect.STRETCH_SCALE
	_coin_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_bar.z_index = 3
	_home_screen.add_child(_coin_bar)

	_coin_icon = TextureRect.new()
	_coin_icon.name = "CoinIcon"
	_coin_icon.texture = load("res://assets/ui/clay_textless/icon_coin_gold.png")
	_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_bar.add_child(_coin_icon)

	_coin_label = Label.new()
	_coin_label.name = "CoinLabel"
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/Fredoka-Bold.ttf")
	ls.font_size = 20
	ls.font_color = Color("fff8e8")
	ls.outline_size = 3
	ls.outline_color = Color("1a1828")
	ls.shadow_size = 2
	ls.shadow_color = Color(0, 0, 0, 0.4)
	ls.shadow_offset = Vector2(0, 2)
	_coin_label.label_settings = ls
	_coin_bar.add_child(_coin_label)

	_plus_btn = TextureButton.new()
	_plus_btn.name = "PlusButton"
	_plus_btn.texture_normal = load("res://assets/ui/clay_textless/icon_plus_green.png")
	_plus_btn.ignore_texture_size = true
	_plus_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_plus_btn.pressed.connect(_on_play_pressed)
	_coin_bar.add_child(_plus_btn)

	_update_coin_display()
	var sm := _get_save_manager()
	if sm != null and sm.has_signal("coins_changed"):
		sm.coins_changed.connect(func(_new_bal): _update_coin_display())

	# -------------------------------------------------------------
	# G. SettingsButton
	# -------------------------------------------------------------
	_settings_btn = ClayStyle.create_clay_texture_button("res://assets/ui/clay_textless/icon_settings_blue.png", Vector2(50, 50), 0.95)
	_settings_btn.name = "SettingsButton"
	_settings_btn.pressed.connect(_on_settings_pressed)
	_settings_btn.z_index = 3
	_home_screen.add_child(_settings_btn)

	# -------------------------------------------------------------
	# H. BusGroup (Three Showcase Buses with Contact Shadows)
	# -------------------------------------------------------------
	_bus_group = Control.new()
	_bus_group.name = "BusGroup"
	_bus_group.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bus_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bus_group.z_index = 1
	_home_screen.add_child(_bus_group)

	_bus_red = TextureRect.new()
	_bus_red.name = "BusRed"
	_bus_red.texture = load("res://assets/home/bus_red.png")
	_bus_red.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bus_red.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bus_red.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_bus_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bus_group.add_child(_bus_red)

	_bus_yellow = TextureRect.new()
	_bus_yellow.name = "BusYellow"
	_bus_yellow.texture = load("res://assets/home/bus_yellow.png")
	_bus_yellow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bus_yellow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bus_yellow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_bus_yellow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bus_group.add_child(_bus_yellow)

	_bus_blue = TextureRect.new()
	_bus_blue.name = "BusBlue"
	_bus_blue.texture = load("res://assets/home/bus_blue.png")
	_bus_blue.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bus_blue.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bus_blue.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_bus_blue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bus_group.add_child(_bus_blue)

	# -------------------------------------------------------------
	# I. PlayButton & PlayLabel (Dynamic Fredoka Typography)
	# -------------------------------------------------------------
	_play_btn = TextureButton.new()
	_play_btn.name = "PlayButton"
	_play_btn.texture_normal = load("res://assets/ui/clay_textless/button_orange_large_blank.png")
	_play_btn.ignore_texture_size = true
	_play_btn.stretch_mode = TextureButton.STRETCH_SCALE
	_play_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS

	# Press scale animation
	_play_btn.button_down.connect(func():
		var tw := _play_btn.create_tween()
		tw.tween_property(_play_btn, "scale", Vector2(0.95, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	_play_btn.button_up.connect(func():
		var tw := _play_btn.create_tween()
		tw.tween_property(_play_btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	_play_btn.pressed.connect(_on_play_pressed)
	_play_btn.z_index = 3
	_home_screen.add_child(_play_btn)

	_play_label = Label.new()
	_play_label.name = "PlayLabel"
	_play_label.text = "Play"
	_play_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_play_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_label.offset_top = -2.0
	_play_label.offset_bottom = -2.0

	var pls := LabelSettings.new()
	pls.font = load("res://assets/fonts/Fredoka-Bold.ttf")
	pls.font_size = 36
	pls.font_color = Color("fff8e8") # Crisp cream white
	pls.outline_size = 6
	pls.outline_color = Color("6b351b") # Deep dark warm brown
	pls.shadow_size = 4
	pls.shadow_color = Color(0.2, 0.08, 0.03, 0.5)
	pls.shadow_offset = Vector2(0, 3)
	_play_label.label_settings = pls
	_play_btn.add_child(_play_label)


func _update_coin_display() -> void:
	if _coin_label != null and is_instance_valid(_coin_label):
		var bal: int = 100
		var sm := _get_save_manager()
		if sm != null and sm.has_method("get_coins"):
			bal = sm.get_coins()
		_coin_label.text = str(bal)


func _get_save_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("SaveManager")
	return null


func _get_game_controller() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("GameController")
	return null


func _get_settings_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("SettingsManager")
	return null


func _play_sfx(sfx_name: String = "ui_click") -> void:
	var am = get_tree().root.get_node_or_null("AudioManager") if is_inside_tree() and get_tree() and get_tree().root else null
	if am != null and am.has_method("play"):
		am.play(sfx_name)


func _on_play_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_sfx("ui_click")
	var gc := _get_game_controller()
	if gc != null and gc.has_method("start_level"):
		gc.start_level(gc.get("current_level_number") if "current_level_number" in gc else 1)
	var t := get_tree()
	if t != null:
		t.create_timer(1.5).timeout.connect(func():
			_is_transitioning = false
		)


func _on_settings_pressed() -> void:
	_play_sfx("ui_click")
	_show_settings_overlay()


# ==============================================================================
# 2. RESPONSIVE LAYOUT ENGINE (ADAPTS TO 390x844, 720x1280, 810x1746)
# ==============================================================================
func _update_layout(override_vp_size: Vector2 = Vector2.ZERO) -> void:
	if _home_screen == null or not is_instance_valid(_home_screen):
		return
	var vp := get_viewport()
	var vp_size: Vector2 = override_vp_size if override_vp_size != Vector2.ZERO else (vp.get_visible_rect().size if vp != null else Vector2(720, 1280))
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(720, 1280)

	var safe_top: float = 28.0
	if DisplayServer.has_method("get_display_safe_area"):
		var safe_rect = DisplayServer.get_display_safe_area()
		if safe_rect.position.y > 0:
			safe_top = maxf(28.0, safe_rect.position.y + 6.0)

	# 1. CoinBar (Top-Left Safe Area)
	var cb_h: float = clampf(vp_size.x * 0.088, 32.0, 42.0)
	var cb_w: float = cb_h * (452.0 / 151.0)
	if _coin_bar != null and is_instance_valid(_coin_bar):
		_coin_bar.size = Vector2(cb_w, cb_h)
		_coin_bar.position = Vector2(20.0, safe_top)

		var icon_sz: float = cb_h * 0.88
		var icon_y: float = (cb_h - icon_sz) * 0.5
		if _coin_icon != null and is_instance_valid(_coin_icon):
			_coin_icon.size = Vector2(icon_sz, icon_sz)
			_coin_icon.position = Vector2(4.0, icon_y)

		var plus_sz: float = cb_h * 0.76
		var plus_y: float = (cb_h - plus_sz) * 0.5
		if _plus_btn != null and is_instance_valid(_plus_btn):
			_plus_btn.size = Vector2(plus_sz, plus_sz)
			_plus_btn.position = Vector2(cb_w - plus_sz - 6.0, plus_y)

		if _coin_label != null and is_instance_valid(_coin_label):
			var l_x: float = icon_sz + 6.0
			var l_w: float = cb_w - l_x - plus_sz - 8.0
			_coin_label.position = Vector2(l_x, 0)
			_coin_label.size = Vector2(l_w, cb_h)

	# 2. SettingsButton (Top-Right Safe Area)
	var s_w: float = 52.0
	var s_h: float = s_w * (305.0 / 310.0)
	if _settings_btn != null and is_instance_valid(_settings_btn):
		_settings_btn.size = Vector2(s_w, s_h)
		_settings_btn.position = Vector2(vp_size.x - s_w - 24.0, safe_top)
		_settings_btn.pivot_offset = Vector2(s_w * 0.5, s_h * 0.5)

	# 3. Logo (Upper-Middle Sky Area)
	var logo_aspect: float = 808.0 / 748.0
	if _logo_rect != null and is_instance_valid(_logo_rect) and _logo_rect.texture != null:
		var ts: Vector2 = _logo_rect.texture.get_size()
		if ts.y > 0:
			logo_aspect = ts.x / ts.y

	var skyline_y: float = vp_size.y * 0.42
	var sky_top_y: float = safe_top + s_h + 10.0
	var avail_sky_h: float = maxf(100.0, skyline_y - sky_top_y)

	var logo_w: float = minf(vp_size.x * 0.72, 440.0)
	var logo_h: float = logo_w / logo_aspect
	if logo_h > avail_sky_h * 0.90:
		logo_h = avail_sky_h * 0.90
		logo_w = logo_h * logo_aspect

	var logo_x: float = (vp_size.x - logo_w) * 0.5
	var logo_y: float = sky_top_y + (avail_sky_h - logo_h) * 0.55

	if _logo_ctrl != null and is_instance_valid(_logo_ctrl):
		_logo_ctrl.position = Vector2(logo_x, logo_y)
		_logo_ctrl.size = Vector2(logo_w, logo_h)
		if _logo_rect != null and is_instance_valid(_logo_rect):
			_logo_rect.position = Vector2.ZERO
			_logo_rect.size = Vector2(logo_w, logo_h)

	# 4. Three Showcase Buses (Positioned in 3 bays)
	# Reference background base resolution: 768 x 1376
	var bg_scale_x: float = vp_size.x / 768.0
	var bg_scale_y: float = vp_size.y / 1376.0
	var bg_scale: float = maxf(bg_scale_x, bg_scale_y)
	
	# Compute offset to center the covered background
	var bg_draw_w: float = 768.0 * bg_scale
	var bg_draw_h: float = 1376.0 * bg_scale
	var bg_off_x: float = (vp_size.x - bg_draw_w) * 0.5
	var bg_off_y: float = (vp_size.y - bg_draw_h) * 0.5

	var bus_base_w: float = 330.0 * bg_scale
	var bus_base_h: float = bus_base_w * (675.0 / 808.0)

	# Ground coordinates for the 3 bays (measured from reference background)
	# Left: (140, 690), Center: (295, 715), Right: (465, 755)
	var r_x: float = bg_off_x + 140.0 * bg_scale
	var r_y: float = bg_off_y + 690.0 * bg_scale
	var y_x: float = bg_off_x + 295.0 * bg_scale
	var y_y: float = bg_off_y + 715.0 * bg_scale
	var b_x: float = bg_off_x + 465.0 * bg_scale
	var b_y: float = bg_off_y + 755.0 * bg_scale

	if _bus_red != null and is_instance_valid(_bus_red):
		_bus_red.size = Vector2(bus_base_w, bus_base_h)
		_bus_red.position = Vector2(r_x, r_y)
		_bus_red_base_y = r_y

	if _bus_yellow != null and is_instance_valid(_bus_yellow):
		_bus_yellow.size = Vector2(bus_base_w, bus_base_h)
		_bus_yellow.position = Vector2(y_x, y_y)
		_bus_yellow_base_y = y_y

	if _bus_blue != null and is_instance_valid(_bus_blue):
		_bus_blue.size = Vector2(bus_base_w, bus_base_h)
		_bus_blue.position = Vector2(b_x, b_y)
		_bus_blue_base_y = b_y

	# 5. PlayButton (Bottom-Center)
	var btn_w: float = minf(vp_size.x * 0.68, 335.0)
	var btn_h: float = btn_w * (268.0 / 735.0)
	var btn_y: float = (vp_size.y * 0.82) - (btn_h * 0.5)
	if _play_btn != null and is_instance_valid(_play_btn):
		_play_btn.size = Vector2(btn_w, btn_h)
		_play_btn.position = Vector2((vp_size.x - btn_w) * 0.5, btn_y)
		_play_btn.pivot_offset = Vector2(btn_w * 0.5, btn_h * 0.5)

	if _play_label != null and is_instance_valid(_play_label) and _play_label.label_settings != null:
		_play_label.label_settings.font_size = 38 if vp_size.x >= 600 else 32

	# 6. Decorative Foliage (Framing Lower Corners)
	var fol_w: float = minf(vp_size.x * 0.38, 260.0)
	var fol_h: float = fol_w # Square bounding box
	if _dec_left_fg != null and is_instance_valid(_dec_left_fg):
		_dec_left_fg.position = Vector2(0, vp_size.y - fol_h)
		_dec_left_fg.size = Vector2(fol_w, fol_h)
		if _left_leaves != null and is_instance_valid(_left_leaves):
			_left_leaves.size = Vector2(fol_w, fol_h)

	if _dec_right_fg != null and is_instance_valid(_dec_right_fg):
		_dec_right_fg.position = Vector2(vp_size.x - fol_w, vp_size.y - fol_h)
		_dec_right_fg.size = Vector2(fol_w, fol_h)
		if _right_leaves != null and is_instance_valid(_right_leaves):
			_right_leaves.size = Vector2(fol_w, fol_h)


# ==============================================================================
# 3. SETTINGS MODAL DIALOG
# ==============================================================================
func _show_settings_overlay() -> void:
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
		_settings_overlay = null

	_settings_overlay = Control.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.z_index = 100
	_home_screen.add_child(_settings_overlay)
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var wrapper := Control.new()
	wrapper.name = "ModalWrapper"
	wrapper.custom_minimum_size = Vector2(300, 290)
	wrapper.size = Vector2(300, 290)
	wrapper.pivot_offset = Vector2(150, 145)
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
	_settings_overlay.move_child(scrim, 0)

	_settings_panel = PanelContainer.new()
	_settings_panel.name = "PanelContainer"
	var ps := ClayStyle.create_clay_panel(Color("fffdf7"), Color("e6d8c3"), 28, 6, 22, 8, Color(0, 0, 0, 0.25))
	_settings_panel.add_theme_stylebox_override("panel", ps)
	wrapper.add_child(_settings_panel)
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
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

	# App Icon & Version footer in Settings
	var footer := HBoxContainer.new()
	footer.name = "VersionFooter"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 6)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var app_icon := TextureRect.new()
	app_icon.name = "AppIconSmall"
	app_icon.texture = load("res://icon.png")
	app_icon.custom_minimum_size = Vector2(22, 22)
	app_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	app_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	app_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(app_icon)

	var ver_label := Label.new()
	ver_label.name = "VersionLabel"
	ver_label.text = "Bus Party v1.0"
	ver_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vls := LabelSettings.new()
	vls.font = load("res://assets/fonts/Fredoka-Bold.ttf")
	vls.font_size = 13
	vls.font_color = Color(0.42, 0.28, 0.18, 0.7)
	ver_label.label_settings = vls
	footer.add_child(ver_label)

	vbox.add_child(footer)

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

	var icon_rect := TextureRect.new()
	icon_rect.texture = load(icon_path)
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_rect)

	var spacer_l := Control.new()
	spacer_l.custom_minimum_size = Vector2(8, 0)
	row.add_child(spacer_l)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/Fredoka-Bold.ttf")
	ls.font_size = 20
	ls.font_color = Color("6b351b")
	label.label_settings = ls
	row.add_child(label)

	var toggle_btn := TextureButton.new()
	toggle_btn.custom_minimum_size = Vector2(58, 32)
	toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle_btn.ignore_texture_size = true
	toggle_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

	var tex_on := load("res://assets/ui/clay_textless/toggle_on_green.png")
	var tex_off := load("res://assets/ui/clay_textless/toggle_off_grey.png")

	var state = {"on": is_on}
	toggle_btn.texture_normal = tex_on if state["on"] else tex_off

	toggle_btn.pressed.connect(func():
		_play_sfx("ui_click")
		state["on"] = not state["on"]
		toggle_btn.texture_normal = tex_on if state["on"] else tex_off

		var tw := toggle_btn.create_tween()
		tw.tween_property(toggle_btn, "scale", Vector2(1.12, 1.12), 0.07).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(toggle_btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)

		on_toggle.call(state["on"])
	)
	toggle_btn.pivot_offset = Vector2(29, 16)
	row.add_child(toggle_btn)

	return row_wrapper


func _create_close_button(on_close: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = load("res://assets/ui/clay_textless/icon_close_red.png")
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = Vector2(44, 44)
	btn.size = Vector2(44, 44)
	btn.pivot_offset = Vector2(22, 22)
	btn.pressed.connect(on_close)

	btn.button_down.connect(func():
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.06)
	)
	btn.button_up.connect(func():
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)
	)
	return btn
