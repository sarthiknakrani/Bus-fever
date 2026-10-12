extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	print("=== RUNNING MOBILE UI POPUPS VISUAL & LAYOUT QA ===")
	
	# Test 1: Verify all 5 vector SVG files exist and are valid CompressedTexture2D
	var svg_paths = [
		"res://assets/ui/icons/sound.svg",
		"res://assets/ui/icons/music.svg",
		"res://assets/ui/icons/vibration.svg",
		"res://assets/ui/icons/close.svg",
		"res://assets/ui/icons/trophy.svg"
	]
	for p in svg_paths:
		var tex = load(p)
		assert(tex != null, "Failed to load vector asset: " + p)
		print("  [PASS] Vector icon verified: %s (Type: %s, Size: %s)" % [p, tex.get_class(), tex.get_size()])

	# Test 2: Instantiate Level 2 CarJamLevel
	var lvl: CarJamLevel = CarJamLevelScene.instantiate()
	root.add_child(lvl)
	if not lvl.is_node_ready():
		lvl._ready()

	# Verify Pause UI
	var pause_overlay = lvl.pause_overlay
	assert(pause_overlay != null, "Pause overlay not found")
	var p_bg = pause_overlay.get_node_or_null("PauseBg")
	assert(p_bg != null and p_bg.mouse_filter == Control.MOUSE_FILTER_STOP, "PauseBg must stop touch events")
	print("  [PASS] PauseOverlay mouse_filter = STOP (blocks touches through to buses)")

	# Verify Restart Confirm UI
	var rc_overlay = lvl.restart_confirm_overlay
	assert(rc_overlay != null, "Restart confirm overlay not found")
	var rc_bg = rc_overlay.get_child(0) as ColorRect
	assert(rc_bg != null and rc_bg.mouse_filter == Control.MOUSE_FILTER_STOP, "Restart confirm overlay must stop touch events")
	print("  [PASS] RestartConfirmOverlay mouse_filter = STOP")

	# Verify Result UI
	var res_overlay = lvl.result_overlay
	assert(res_overlay != null, "Result overlay not found")
	var res_bg = res_overlay.get_child(0) as ColorRect
	assert(res_bg != null and res_bg.mouse_filter == Control.MOUSE_FILTER_STOP, "Result overlay must stop touch events")
	print("  [PASS] ResultOverlay mouse_filter = STOP")

	# Verify Booster Bar safe margin
	var booster_bar = lvl.booster_bar
	assert(booster_bar != null, "Booster bar not found")
	assert(booster_bar.offset_bottom <= -18.0, "Booster bar must clear Safari bottom chrome")
	print("  [PASS] Booster bar offset_bottom = %.1f (Clears mobile Safari bottom bar)" % booster_bar.offset_bottom)

	print("=== ALL MOBILE UI POPUPS VERIFICATIONS PASSED ===")
	lvl.queue_free()
	quit(0)
