extends SceneTree

# ==============================================================================
# QA VERIFICATION: BUS PARTY REBRANDING & HOME SCREEN VALIDATION
# ==============================================================================

const ARTIFACT_DIR := "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827"
const SCREENSHOT_PATH := ARTIFACT_DIR + "/bus_party_home_screen.png"
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
		_assert(not forbidden in txt, "Node '%s' does not contain '%s' (text='%s')" % [node.name, forbidden, node.get("text")])
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
	print("=== VERIFYING REBRANDING TO 'BUS PARTY' ON HOME SCREEN ===")
	print("======================================================================")

	# 1. Asset check
	var logo_path := "res://assets/ui/logo/bus_party_logo.png"
	_assert(ResourceLoader.exists(logo_path), "bus_party_logo.png exists in project")
	var logo_tex: Texture2D = ResourceLoader.load(logo_path)
	_assert(logo_tex != null, "bus_party_logo.png loads successfully as Texture2D")
	if logo_tex != null:
		print("  -> Logo dimensions: %dx%d px" % [logo_tex.get_width(), logo_tex.get_height()])
		_assert(logo_tex.get_width() > 700 and logo_tex.get_height() > 400, "Logo has high resolution")

	# 2. SubViewport setup
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

	# Wait a few frames for layout & rendering
	for i in range(15):
		await process_frame

	var logo_rect: TextureRect = main_instance.find_child("LogoTexture", true, false)
	_assert(logo_rect != null, "LogoTexture node exists in scene")
	if logo_rect != null:
		_assert(logo_rect.texture != null, "LogoTexture has assigned texture")
		_assert(logo_rect.texture.resource_path.ends_with("bus_party_logo.png"), "LogoTexture uses bus_party_logo.png (path=%s)" % logo_rect.texture.resource_path)
		print("  -> Logo Rect size: %s, position: %s" % [logo_rect.size, logo_rect.global_position])

	# 3. Check entire scene tree for forbidden "fever" text
	_check_node_text_for_forbidden(main_instance, "fever")

	# 4. Check project name in ProjectSettings
	var proj_name: String = ProjectSettings.get_setting("application/config/name")
	print("  -> ProjectSettings application/config/name: '%s'" % proj_name)
	_assert(not "fever" in proj_name.to_lower(), "Project name does not contain 'fever'")
	_assert("Bus Party" in proj_name, "Project name contains 'Bus Party'")

	# 5. Capture screenshot of home screen
	_capture_viewport(vp, SCREENSHOT_PATH)
	_capture_viewport(vp, SCRATCH_PATH)

	# 6. Test settings overlay
	var settings_btn: BaseButton = main_instance.find_child("settings_btn", true, false)
	_assert(settings_btn != null, "settings_btn exists")
	if settings_btn != null:
		settings_btn.emit_signal("pressed")
		for i in range(10):
			await process_frame
		var settings_overlay = main_instance.find_child("SettingsOverlay", true, false)
		_assert(settings_overlay != null, "SettingsOverlay opens when settings clicked")
		if settings_overlay != null:
			_check_node_text_for_forbidden(settings_overlay, "fever")
			_capture_viewport(vp, ARTIFACT_DIR + "/bus_party_settings_screen.png")

	print("======================================================================")
	print("=== VERIFICATION COMPLETE: %d PASSED, %d FAILED ===" % [passed_count, failed_count])
	print("======================================================================")

	if failed_count == 0:
		quit(0)
	else:
		quit(1)
