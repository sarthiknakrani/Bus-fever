extends SceneTree

# ==============================================================================
# QA VERIFICATION: COMPLETE REBUILT HOME SCREEN FOR "BUS PARTY"
# ==============================================================================

const ARTIFACT_DIR := "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827"
const HOME_SCREENSHOT_PATH := ARTIFACT_DIR + "/bus_party_rebuilt_home_screen.png"
const SETTINGS_SCREENSHOT_PATH := ARTIFACT_DIR + "/bus_party_rebuilt_settings_screen.png"
const IPHONE_SCREENSHOT_PATH := ARTIFACT_DIR + "/bus_party_rebuilt_390x844.png"
const SCRATCH_PATH := "scratch/bus_party_home_screen.png"

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	call_deferred("_run_verification")

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
		passed_count += 1
	else:
		printerr("  [FAIL] %s" % message)
		failed_count += 1

func _check_node_text_for_forbidden(node: Node, forbidden: String = "fever") -> void:
	if "text" in node:
		var txt: String = str(node.get("text")).to_lower()
		_assert(not forbidden in txt, "Node '%s' text does not contain '%s' (text='%s')" % [node.name, forbidden, node.get("text")])
	if "tooltip_text" in node:
		var tt: String = str(node.get("tooltip_text")).to_lower()
		_assert(not forbidden in tt, "Node '%s' tooltip does not contain '%s'" % [node.name, forbidden])
	for child in node.get_children():
		_check_node_text_for_forbidden(child, forbidden)

func _capture_viewport(vp: SubViewport, path: String) -> void:
	var tex = vp.get_texture()
	if tex != null:
		var img = tex.get_image()
		if img != null:
			img.save_png(path)
			print("  [SAVED IMAGE] %s (%dx%d)" % [path, img.get_width(), img.get_height()])
			return
	printerr("  [ERROR] Viewport image was null for %s" % path)

func _run_verification() -> void:
	print("======================================================================")
	print("=== VERIFYING REBUILT HOME SCREEN & HIERARCHY FOR 'BUS PARTY' ===")
	print("======================================================================")

	# 1. Asset check
	var logo_path := "res://assets/ui/logo/bus_party_logo.png"
	_assert(ResourceLoader.exists(logo_path), "bus_party_logo.png exists in project")
	var logo_tex: Texture2D = ResourceLoader.load(logo_path)
	_assert(logo_tex != null, "bus_party_logo.png loads successfully as Texture2D")

	# Check showcase bus assets
	_assert(ResourceLoader.exists("res://assets/home/bus_red.png"), "bus_red.png exists")
	_assert(ResourceLoader.exists("res://assets/home/bus_yellow.png"), "bus_yellow.png exists")
	_assert(ResourceLoader.exists("res://assets/home/bus_blue.png"), "bus_blue.png exists")
	_assert(ResourceLoader.exists("res://assets/home/coastal_town_empty_road.png"), "coastal_town_empty_road.png exists")
	_assert(ResourceLoader.exists("res://assets/home/foliage_left.png"), "foliage_left.png exists")
	_assert(ResourceLoader.exists("res://assets/home/foliage_right.png"), "foliage_right.png exists")

	# 2. SubViewport setup for 720x1280
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var main_scene = load("res://scenes/main.tscn")
	_assert(main_scene != null, "main.tscn loaded successfully")
	var main_instance = main_scene.instantiate()
	vp.add_child(main_instance)

	if main_instance.has_method("_update_layout"):
		main_instance._update_layout(Vector2(720, 1280))

	# Wait frames for layout & rendering
	for i in range(15):
		await process_frame

	# 3. VERIFY STRICT HIERARCHY
	print("--- Checking Exact Hierarchy Structure ---")
	var home_screen = main_instance.get_node_or_null("HomeScreen")
	_assert(home_screen != null, "HomeScreen node exists")

	# BackgroundSky
	var bg_sky = home_screen.get_node_or_null("BackgroundSky")
	_assert(bg_sky != null, "BackgroundSky exists in HomeScreen")
	_assert(bg_sky.get_node_or_null("SkyGradient") != null, "SkyGradient exists in BackgroundSky")
	_assert(bg_sky.get_node_or_null("Clouds") != null, "Clouds exists in BackgroundSky")

	# BackgroundTown
	var bg_town = home_screen.get_node_or_null("BackgroundTown")
	_assert(bg_town != null, "BackgroundTown exists in HomeScreen")
	_assert(bg_town.get_node_or_null("Ocean") != null, "Ocean exists in BackgroundTown")
	_assert(bg_town.get_node_or_null("CoastalBuildings") != null, "CoastalBuildings exists in BackgroundTown")
	_assert(bg_town.get_node_or_null("PalmTrees") != null, "PalmTrees exists in BackgroundTown")
	_assert(bg_town.get_node_or_null("TownDecorations") != null, "TownDecorations exists in BackgroundTown")

	# MidgroundRoad
	var mg_road = home_screen.get_node_or_null("MidgroundRoad")
	_assert(mg_road != null, "MidgroundRoad exists in HomeScreen")
	_assert(mg_road.get_node_or_null("RoadSurface") != null, "RoadSurface exists in MidgroundRoad")
	_assert(mg_road.get_node_or_null("RoadMarkings") != null, "RoadMarkings exists in MidgroundRoad")
	_assert(mg_road.get_node_or_null("ParkingLines") != null, "ParkingLines exists in MidgroundRoad")
	_assert(mg_road.get_node_or_null("Pavement") != null, "Pavement exists in MidgroundRoad")

	# DecorativeLeftForeground
	var dec_left = home_screen.get_node_or_null("DecorativeLeftForeground")
	_assert(dec_left != null, "DecorativeLeftForeground exists in HomeScreen")
	_assert(dec_left.get_node_or_null("Leaves") != null, "Leaves exists in DecorativeLeftForeground")
	_assert(dec_left.get_node_or_null("Flowers") != null, "Flowers exists in DecorativeLeftForeground")

	# DecorativeRightForeground
	var dec_right = home_screen.get_node_or_null("DecorativeRightForeground")
	_assert(dec_right != null, "DecorativeRightForeground exists in HomeScreen")
	_assert(dec_right.get_node_or_null("Leaves") != null, "Leaves exists in DecorativeRightForeground")
	_assert(dec_right.get_node_or_null("Flowers") != null, "Flowers exists in DecorativeRightForeground")

	# Logo
	var logo_ctrl = home_screen.get_node_or_null("Logo")
	_assert(logo_ctrl != null, "Logo exists in HomeScreen")
	var logo_rect = logo_ctrl.get_node_or_null("BusPartyLogo")
	_assert(logo_rect != null, "BusPartyLogo exists in Logo")
	if logo_rect != null and logo_rect is TextureRect:
		_assert(logo_rect.texture != null, "BusPartyLogo has valid Texture2D")
		_assert(logo_rect.texture.resource_path.ends_with("bus_party_logo.png"), "BusPartyLogo points to bus_party_logo.png")

	# CoinBar
	var coin_bar = home_screen.get_node_or_null("CoinBar")
	_assert(coin_bar != null, "CoinBar exists in HomeScreen")
	var coin_icon = coin_bar.get_node_or_null("CoinIcon")
	_assert(coin_icon != null, "CoinIcon exists in CoinBar")
	var coin_label = coin_bar.get_node_or_null("CoinLabel")
	_assert(coin_label != null, "CoinLabel exists in CoinBar")
	var plus_btn = coin_bar.get_node_or_null("PlusButton")
	_assert(plus_btn != null, "PlusButton exists in CoinBar")

	# SettingsButton
	var settings_btn = home_screen.get_node_or_null("SettingsButton")
	_assert(settings_btn != null, "SettingsButton exists in HomeScreen")

	# BusGroup
	var bus_group = home_screen.get_node_or_null("BusGroup")
	_assert(bus_group != null, "BusGroup exists in HomeScreen")
	var bus_red = bus_group.get_node_or_null("BusRed")
	_assert(bus_red != null, "BusRed exists in BusGroup")
	var bus_yellow = bus_group.get_node_or_null("BusYellow")
	_assert(bus_yellow != null, "BusYellow exists in BusGroup")
	var bus_blue = bus_group.get_node_or_null("BusBlue")
	_assert(bus_blue != null, "BusBlue exists in BusGroup")

	# PlayButton
	var play_btn = home_screen.get_node_or_null("PlayButton")
	_assert(play_btn != null, "PlayButton exists in HomeScreen")
	var play_label = play_btn.get_node_or_null("PlayLabel")
	_assert(play_label != null, "PlayLabel exists in PlayButton")
	if play_label != null and play_label is Label:
		_assert(play_label.text == "Play", "PlayLabel has text 'Play'")
		_assert(play_label.label_settings != null, "PlayLabel has custom LabelSettings")

	# 4. Check entire scene tree for forbidden "fever" text
	print("--- Checking for forbidden 'fever' references ---")
	_check_node_text_for_forbidden(main_instance, "fever")

	# 5. Check project name in ProjectSettings
	var proj_name: String = ProjectSettings.get_setting("application/config/name")
	_assert(not "fever" in proj_name.to_lower(), "Project name does not contain 'fever'")
	_assert("Bus Party" in proj_name, "Project name contains 'Bus Party'")

	# 6. Capture 720x1280 home screen
	print("--- Capturing 720x1280 Home Screen ---")
	_capture_viewport(vp, HOME_SCREENSHOT_PATH)
	_capture_viewport(vp, SCRATCH_PATH)
	_capture_viewport(vp, ARTIFACT_DIR + "/bus_party_home_screen.png")

	# 7. Test settings overlay
	print("--- Testing Settings Button & Overlay ---")
	if settings_btn != null and settings_btn is BaseButton:
		settings_btn.emit_signal("pressed")
		for i in range(12):
			await process_frame
		var settings_overlay = home_screen.get_node_or_null("SettingsOverlay")
		_assert(settings_overlay != null, "SettingsOverlay opened on SettingsButton press")
		if settings_overlay != null:
			_check_node_text_for_forbidden(settings_overlay, "fever")
			_capture_viewport(vp, SETTINGS_SCREENSHOT_PATH)
			_capture_viewport(vp, ARTIFACT_DIR + "/bus_party_settings_screen.png")
			# Close it
			var close_btn = settings_overlay.find_child("CloseButton", true, false)
			if close_btn != null and close_btn is BaseButton:
				close_btn.emit_signal("pressed")
				for i in range(10):
					await process_frame

	# 8. Test responsive layout at 390x844 (iPhone)
	print("--- Testing Responsive Layout 390x844 ---")
	vp.size = Vector2i(390, 844)
	if main_instance.has_method("_update_layout"):
		main_instance._update_layout(Vector2(390, 844))
	for i in range(12):
		await process_frame
	_capture_viewport(vp, IPHONE_SCREENSHOT_PATH)

	print("======================================================================")
	print("=== VERIFICATION COMPLETE: %d PASSED, %d FAILED ===" % [passed_count, failed_count])
	print("======================================================================")

	if failed_count == 0:
		quit(0)
	else:
		quit(1)
