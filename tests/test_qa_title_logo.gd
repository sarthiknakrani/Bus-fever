extends SceneTree

# ==============================================================================
# QA TEST SUITE: PREMIUM MULTICOLOR 3D GAME TITLE LOGO
# ==============================================================================

const ARTIFACT_DIR := "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c"

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	call_deferred("_run_qa_suite")

func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
		passed_count += 1
	else:
		printerr("  [FAIL] %s" % message)
		failed_count += 1

func _run_qa_suite() -> void:
	print("======================================================================")
	print("=== STARTING QA AUDIT: 3D MULTICOLOR GAME TITLE LOGO SUITE ===")
	print("======================================================================")

	_test_logo_asset_integrity()
	await _test_home_screen_hierarchy_and_buttons()
	await _test_responsive_resolutions_and_captures()

	print("======================================================================")
	print("=== QA AUDIT COMPLETE: %d PASSED, %d FAILED ===" % [passed_count, failed_count])
	print("======================================================================")

	if failed_count == 0:
		print("STATUS: ALL TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		push_error("STATUS: QA SUITE FAILED!")
		quit(1)

func _test_logo_asset_integrity() -> void:
	print("\n--- TEST GROUP 1: Logo Asset & Generator Integrity ---")
	
	var logo_path := "res://assets/ui/logo/bus_fever_party_logo.png"
	_assert(ResourceLoader.exists(logo_path), "Logo texture exists on disk at %s" % logo_path)
	
	var logo_tex: Texture2D = ResourceLoader.load(logo_path)
	_assert(logo_tex != null, "Logo texture loaded successfully as Texture2D")
	if logo_tex != null:
		_assert(logo_tex.get_width() >= 700 and logo_tex.get_height() >= 500, "Logo has high retina resolution (%dx%d px)" % [logo_tex.get_width(), logo_tex.get_height()])
		var aspect: float = float(logo_tex.get_width()) / float(logo_tex.get_height())
		_assert(aspect > 0.85 and aspect < 1.45, "Logo aspect ratio is balanced casual badge standard (%.3f)" % aspect)
		var logo_img := logo_tex.get_image()
		if logo_img != null:
			var p_x: int = int(round(logo_img.get_width() * (215.0 / 954.0))) if logo_img.get_width() > 800 else 140
			var p_y: int = int(round(logo_img.get_height() * (650.0 / 922.0))) if logo_img.get_height() > 800 else 420
			var p_col := logo_img.get_pixel(p_x, p_y)
			_assert(p_col.r > 0.85 and p_col.g > 0.35 and p_col.g < 0.75 and p_col.b < 0.35, "Letter 'P' in 'PARTY!' has candy orange face (r=%.2f, g=%.2f, b=%.2f)" % [p_col.r, p_col.g, p_col.b])
			var pb_x: int = int(round(logo_img.get_width() * (135.0 / 954.0))) if logo_img.get_width() > 800 else 84
			var pb_y: int = int(round(logo_img.get_height() * (650.0 / 922.0))) if logo_img.get_height() > 800 else 470
			var p_border := logo_img.get_pixel(pb_x, pb_y)
			_assert(p_border.b > p_border.r + 0.15 and p_border.b > p_border.g + 0.15, "Letter 'P' border is royal dark navy blue, NOT orange (r=%.2f, g=%.2f, b=%.2f)" % [p_border.r, p_border.g, p_border.b])

	var font_path := "res://assets/fonts/arial_rounded_bold.ttf"
	_assert(ResourceLoader.exists(font_path), "Font asset exists in project at %s" % font_path)

	var shader_path := "res://assets/shaders/logo_gloss_shine.gdshader"
	_assert(ResourceLoader.exists(shader_path), "Glossy shine shader exists at %s" % shader_path)

func _test_home_screen_hierarchy_and_buttons() -> void:
	print("\n--- TEST GROUP 2: Home Screen Hierarchy, Logo Nodes & Button Usability ---")

	var main_scene = load("res://scenes/main.tscn")
	_assert(main_scene != null, "main.tscn loaded successfully")
	var main_instance = main_scene.instantiate()
	root.add_child(main_instance)

	await process_frame
	await process_frame

	# Check logo nodes
	var logo_wrapper = main_instance.find_child("TitleLogoWrapper", true, false)
	_assert(logo_wrapper != null, "TitleLogoWrapper exists in HUD hierarchy")
	if logo_wrapper != null:
		var logo_rect: TextureRect = logo_wrapper.get_node_or_null("LogoTexture")
		_assert(logo_rect != null, "LogoTexture node exists inside TitleLogoWrapper")
		if logo_rect != null:
			_assert(logo_rect.texture != null, "LogoTexture has valid texture assigned")
			_assert(logo_rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "LogoTexture has TEXTURE_FILTER_LINEAR_WITH_MIPMAPS for razor sharpness")
			_assert(logo_rect.material is ShaderMaterial, "LogoTexture has ShaderMaterial attached")
			if logo_rect.material is ShaderMaterial:
				var sm := logo_rect.material as ShaderMaterial
				_assert(sm.shader != null, "Logo ShaderMaterial has valid shader assigned")
				var cycle_dur: float = sm.get_shader_parameter("cycle_duration")
				_assert(cycle_dur >= 2.0 and cycle_dur <= 3.5, "Logo glossy shine has calm slower animation duration (%.2fs)" % cycle_dur)

	# Check Settings button
	var settings_btn = main_instance.find_child("settings_btn", true, false)
	if settings_btn == null:
		# Check by type TextureButton at top-right
		for c in main_instance.find_children("*", "TextureButton", true, false):
			if c.name.to_lower().contains("setting") or c.offset_left < 0:
				settings_btn = c
				break
	_assert(settings_btn != null, "Settings button exists on home screen")

	# Check Play button
	var play_btn: TextureButton = null
	for c in main_instance.find_children("*", "TextureButton", true, false):
		if c.name.to_lower().contains("play") or c.anchor_top > 0.7:
			play_btn = c
			break
	_assert(play_btn != null, "Play button exists on home screen")
	if play_btn != null:
		_assert(play_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "Play button has interactive MOUSE_FILTER_STOP")
		_assert(play_btn.texture_normal != null, "Play button has 3D orange normal texture assigned")
		_assert(play_btn.texture_pressed != null, "Play button has 3D orange pressed texture assigned")

	main_instance.queue_free()
	await process_frame

func _test_responsive_resolutions_and_captures() -> void:
	print("\n--- TEST GROUP 3: Responsive Mobile Screen Fit & Visual Captures ---")

	var test_devices = [
		{"res": Vector2i(720, 1280), "tag": "720x1280", "name": "Standard Android (16:9)"},
		{"res": Vector2i(390, 844),  "tag": "390x844",  "name": "iPhone 12/13/14"},
		{"res": Vector2i(810, 1746), "tag": "810x1746", "name": "Tall Modern Android"},
		{"res": Vector2i(320, 568),  "tag": "320x568",  "name": "Compact Screen (iPhone SE 1st gen)"}
	]

	var main_scene = load("res://scenes/main.tscn")

	for dev in test_devices:
		var win_size: Vector2i = dev["res"]
		var tag: String = dev["tag"]
		var dev_name: String = dev["name"]

		var vp := SubViewport.new()
		vp.size = win_size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)

		var main_instance = main_scene.instantiate()
		vp.add_child(main_instance)

		# Force responsive layout update
		main_instance._update_layout(Vector2(win_size))
		await process_frame
		await process_frame

		var logo = main_instance._logo_wrapper
		_assert(logo != null, "[%s] Logo wrapper exists" % tag)
		if logo != null:
			# Verify horizontal fit
			_assert(logo.position.x >= 0.0, "[%s] Logo left edge >= 0 (x=%.1f)" % [tag, logo.position.x])
			_assert(logo.position.x + logo.size.x <= float(win_size.x) + 0.5, "[%s] Logo right edge fits within screen width (r=%.1f, max=%d)" % [tag, logo.position.x + logo.size.x, win_size.x])
			
			# Verify horizontal centering within 2px
			var expected_center_x = (float(win_size.x) - logo.size.x) * 0.5
			_assert(absf(logo.position.x - expected_center_x) < 2.0, "[%s] Logo is horizontally centered (%.1f vs expected %.1f)" % [tag, logo.position.x, expected_center_x])

			# Verify vertical clearance from Settings button (y >= 60)
			_assert(logo.position.y >= 60.0, "[%s] Logo clears top settings area (y=%.1f >= 60)" % [tag, logo.position.y])

			# Verify logo stays strictly within the cloud zone, never overlaying background buildings/trees (skyline at ~0.435-0.455)
			var max_horizon_y: float = maxf(float(win_size.y) * 0.44, 260.0)
			_assert(logo.position.y + logo.size.y <= max_horizon_y + 0.5, "[%s] Logo stays strictly inside clouds, never overlaying background buildings/trees (bottom=%.1f <= max=%.1f)" % [tag, logo.position.y + logo.size.y, max_horizon_y])

			# Verify vertical clearance from Play button (play button at ~0.81 * H)
			var play_y: float = float(win_size.y) * 0.81 - 40.0
			_assert(logo.position.y + logo.size.y < play_y - 20.0, "[%s] Logo clears play button with ample breathing room (bottom=%.1f < play_y=%.1f)" % [tag, logo.position.y + logo.size.y, play_y])

		# Wait for entrance animation and layout frames to process
		for f in range(15):
			await process_frame

		# Save full-screen capture if not headless dummy renderer
		if DisplayServer.get_name() != "headless":
			var tex := vp.get_texture()
			if tex != null:
				var img := tex.get_image()
				var out_path := "%s/qa_home_%s.png" % [ARTIFACT_DIR, tag]
				if img != null:
					img.save_png(out_path)
					print("  [CAPTURE] Saved %s (%dx%d)" % [out_path, img.get_width(), img.get_height()])

		vp.queue_free()
		await process_frame
