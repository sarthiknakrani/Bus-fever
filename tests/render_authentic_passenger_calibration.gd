extends SceneTree

const ARTIFACT_DIR := "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827"
const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run")

func _ensure_game_controller() -> void:
	var gc = root.get_node_or_null("GameController")
	if gc == null:
		var gc_script = GDScript.new()
		gc_script.source_code = "extends Node\nvar current_level_number: int = 1\nfunc has_level(n: int) -> bool: return n <= 2\n"
		gc_script.reload()
		gc = Node.new()
		gc.set_script(gc_script)
		gc.name = "GameController"
		root.add_child(gc)

func _setup_level(lvl: CarJamLevel, level_num: int, parade: bool) -> void:
	lvl.enable_entrance_parade = parade
	lvl.force_entrance_parade = parade
	if not lvl.is_node_ready():
		lvl._ready()
	var path := "res://levels/level_001.tres" if level_num == 1 else "res://levels/level_002.tres"
	var lvl_res = ResourceLoader.load(path) as CarJamLevelData
	lvl.controller.load_level(lvl_res)
	lvl._setup_visuals(lvl_res)

func _capture_viewport(vp: SubViewport, path: String) -> void:
	var img = vp.get_texture().get_image()
	if img != null:
		img.save_png(path)
		print("  [SAVED IMAGE] %s (%dx%d)" % [path.get_file(), img.get_width(), img.get_height()])
	else:
		printerr("  [ERROR] Viewport image was null for %s" % path.get_file())

func _run() -> void:
	print("\n=========================================================================")
	print("=== RENDERING AUTHENTIC PASSENGER SPEED & RESOLUTION SHOWCASE ===")
	print("=========================================================================\n")

	_ensure_game_controller()

	# 1. Capture across requested portrait resolutions:
	#  - 390x844 (standard portrait)
	#  - 810x1746 (tall modern phone)
	#  - 720x1280 (16:9 portrait)
	var resolutions := [
		{"res": Vector2i(390, 844), "name": "authentic_movement_390x844.png"},
		{"res": Vector2i(810, 1746), "name": "authentic_movement_810x1746.png"},
		{"res": Vector2i(720, 1280), "name": "authentic_movement_720x1280.png"}
	]

	for item in resolutions:
		var sz: Vector2i = item["res"]
		var out_path: String = ARTIFACT_DIR + "/" + item["name"]
		print("Rendering %s at %dx%d..." % [item["name"], sz.x, sz.y])

		var vp := SubViewport.new()
		vp.size = sz
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)

		var lvl: CarJamLevel = CarJamLevelScene.instantiate()
		vp.add_child(lvl)
		_setup_level(lvl, 1, false)

		if lvl.camera_2d != null:
			lvl.camera_2d.enabled = true
			lvl.camera_2d.make_current()
		lvl._update_layout(Vector2(sz))

		# Simulate 40 frames (~1.5s circulation)
		for f in range(40):
			lvl._process(0.04)
			await process_frame

		_capture_viewport(vp, out_path)
		lvl.queue_free()
		vp.queue_free()
		await process_frame

	# 2. Capture Developer Diagnostic Overlay (with F3 telemetry active)
	print("Rendering authentic_diagnostic_overlay.png with F3 overlay active...")
	var vp_ov := SubViewport.new()
	vp_ov.size = Vector2i(540, 960)
	vp_ov.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp_ov)

	var lvl_ov: CarJamLevel = CarJamLevelScene.instantiate()
	lvl_ov.show_passenger_debug_overlay = true
	vp_ov.add_child(lvl_ov)
	_setup_level(lvl_ov, 1, false)

	if lvl_ov.camera_2d != null:
		lvl_ov.camera_2d.enabled = true
		lvl_ov.camera_2d.make_current()
	lvl_ov._update_layout(Vector2(540, 960))

	# Run 25 frames to populate and draw telemetry
	for f in range(25):
		lvl_ov._process(0.04)
		await process_frame

	_capture_viewport(vp_ov, ARTIFACT_DIR + "/authentic_diagnostic_overlay.png")
	lvl_ov.queue_free()
	vp_ov.queue_free()
	await process_frame

	# 3. Record video sequence:
	# - Entrance parade streaming onto track
	# - 3 continuous laps of smooth 4-across circulation
	# - Bus 3 dispatch, gate-only boarding, feeder vacancy replenishment
	print("\nRecording video frames for authentic_passenger_calibration_showcase.mp4...")
	var video_size := Vector2i(540, 960)
	var frame_dir := ARTIFACT_DIR + "/scratch/auth_video_frames"
	DirAccess.make_dir_recursive_absolute(frame_dir)
	var dir = DirAccess.open(frame_dir)
	if dir:
		for f in dir.get_files():
			dir.remove(f)

	var vp_vid := SubViewport.new()
	vp_vid.size = video_size
	vp_vid.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp_vid)

	var lvl_vid: CarJamLevel = CarJamLevelScene.instantiate()
	vp_vid.add_child(lvl_vid)
	_setup_level(lvl_vid, 1, true)

	if lvl_vid.camera_2d != null:
		lvl_vid.camera_2d.enabled = true
		lvl_vid.camera_2d.make_current()
	lvl_vid._update_layout(Vector2(video_size))

	var frame_counter := 0

	# Phase A: Initial Entrance Parade streaming from feeder (60 frames)
	print("  Phase A: Entrance parade streaming...")
	for f in range(60):
		lvl_vid._process(0.033)
		await process_frame
		if f % 2 == 0:
			var img = vp_vid.get_texture().get_image()
			if img != null:
				img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
				frame_counter += 1

	# Phase B: Continuous 3-lap circulation (36 slots, 4-across) (120 frames)
	print("  Phase B: Continuous 3-lap circulation (36 slots, 4-across)...")
	for f in range(120):
		lvl_vid._process(0.033)
		await process_frame
		if f % 2 == 0:
			var img = vp_vid.get_texture().get_image()
			if img != null:
				img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
				frame_counter += 1

	# Phase C: Bus 3 tapped -> Parks in bay -> Boarding gate animation (90 frames)
	print("  Phase C: Dispatching Bus 3 and boarding gate...")
	lvl_vid.controller.tap_vehicle(3)
	for f in range(90):
		lvl_vid._process(0.033)
		await process_frame
		if f % 2 == 0:
			var img = vp_vid.get_texture().get_image()
			if img != null:
				img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
				frame_counter += 1

	# Phase D: Feeder replenishment into vacated slots (60 frames)
	print("  Phase D: Feeder queue FIFO advance into vacated capacity...")
	for f in range(60):
		lvl_vid._process(0.033)
		await process_frame
		if f % 2 == 0:
			var img = vp_vid.get_texture().get_image()
			if img != null:
				img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
				frame_counter += 1

	print("Finished capturing %d video frames." % frame_counter)
	lvl_vid.queue_free()
	vp_vid.queue_free()
	await process_frame

	print("\n=== ALL SHOWCASE ASSETS GENERATED SUCCESSFULLY ===")
	quit(0)
