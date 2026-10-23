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

func _setup_level(lvl: CarJamLevel, level_num: int) -> void:
	lvl.enable_entrance_parade = false
	lvl.force_entrance_parade = false
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
	print("=== RENDERING BUS MOVEMENT COLLISION-FREE & EXHAUST SMOKE SHOWCASE ===")
	print("=========================================================================\n")

	_ensure_game_controller()

	var frame_dir := ARTIFACT_DIR + "/scratch/bus_smoke_frames"
	DirAccess.make_dir_recursive_absolute(frame_dir)
	var dir = DirAccess.open(frame_dir)
	if dir:
		for f in dir.get_files():
			dir.remove(f)

	var vp := SubViewport.new()
	vp.size = Vector2i(540, 960)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var lvl: CarJamLevel = CarJamLevelScene.instantiate()
	vp.add_child(lvl)
	_setup_level(lvl, 1)

	if lvl.camera_2d != null:
		lvl.camera_2d.enabled = true
		lvl.camera_2d.make_current()
	lvl._update_layout(Vector2(540, 960))

	# Allow initialization
	for f in 15:
		await process_frame

	var frame_counter := 0

	# 1. Idle circulation before dispatches (30 frames)
	print("Phase 1: Board idle and passenger circulation (Level 1)...")
	for f in 30:
		await process_frame
		var img = vp.get_texture().get_image()
		if img != null:
			img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
			frame_counter += 1

	# 2. Rapid dispatch of Bus 4 (LEFT), Bus 3 (RIGHT), and Bus 5 (DOWN)
	print("Phase 2: Rapidly dispatching Bus 4, Bus 3, Bus 5...")
	lvl._on_vehicle_tapped(4)
	for f in 4:
		await process_frame
		var img = vp.get_texture().get_image()
		if img != null:
			img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
			frame_counter += 1

	lvl._on_vehicle_tapped(3)
	for f in 4:
		await process_frame
		var img = vp.get_texture().get_image()
		if img != null:
			img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
			frame_counter += 1

	lvl._on_vehicle_tapped(5)

	# 3. Multi-bus transit and smoke emission
	print("Phase 3: Recording multi-bus transit, collision-free yielding & exhaust smoke...")
	var snapshot_saved := false
	for f in 90:
		await process_frame
		var img = vp.get_texture().get_image()
		if img != null:
			img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
			frame_counter += 1

		# Save screenshot mid-transit showing smoke puffs
		if f == 25 and not snapshot_saved:
			_capture_viewport(vp, ARTIFACT_DIR + "/bus_transit_multi_bus_smoke_level1.png")
			snapshot_saved = true

	# 4. Buses parked, smoke stopped, alignment verified
	print("Phase 4: Buses parked in bays...")
	_capture_viewport(vp, ARTIFACT_DIR + "/bus_parking_arrival_precision.png")

	for f in 30:
		await process_frame
		var img = vp.get_texture().get_image()
		if img != null:
			img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
			frame_counter += 1

	# 5. Let boarding occur and Bus 3 depart with exhaust smoke
	print("Phase 5: Boarding into Bus 3 and Departure sequence with smoke...")
	for f in 120:
		await process_frame
		var img = vp.get_texture().get_image()
		if img != null:
			img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
			frame_counter += 1

	lvl.queue_free()
	await process_frame

	# 6. Level 2 Rapid multi-bus transit
	print("Phase 6: Level 2 Rapid Dispatches (Bus 1, Bus 2, Bus 3)...")
	var lvl2: CarJamLevel = CarJamLevelScene.instantiate()
	vp.add_child(lvl2)
	_setup_level(lvl2, 2)
	if lvl2.camera_2d != null:
		lvl2.camera_2d.enabled = true
		lvl2.camera_2d.make_current()
	lvl2._update_layout(Vector2(540, 960))

	for f in 15:
		await process_frame

	lvl2._on_vehicle_tapped(1)
	for f in 4:
		await process_frame
		var img = vp.get_texture().get_image()
		if img != null:
			img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
			frame_counter += 1

	lvl2._on_vehicle_tapped(2)
	for f in 4:
		await process_frame
		var img = vp.get_texture().get_image()
		if img != null:
			img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
			frame_counter += 1

	lvl2._on_vehicle_tapped(3)

	var l2_snapshot_saved := false
	for f in 100:
		await process_frame
		var img = vp.get_texture().get_image()
		if img != null:
			img.save_png("%s/frame_%04d.png" % [frame_dir, frame_counter])
			frame_counter += 1

		if f == 28 and not l2_snapshot_saved:
			_capture_viewport(vp, ARTIFACT_DIR + "/bus_transit_multi_bus_smoke_level2.png")
			l2_snapshot_saved = true

	lvl2.queue_free()
	vp.queue_free()
	await process_frame

	print("\nCaptured %d video frames." % frame_counter)
	print("=== SHOWCASE RENDERING COMPLETE ===")
	quit(0)
