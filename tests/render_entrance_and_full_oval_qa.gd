extends SceneTree

const ARTIFACT_DIR := "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827"
const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n=== RENDERING ENTRANCE STREAM AND FULL OVAL CIRCULATION QA ===")
	var win_size := Vector2i(720, 1280)

	var vp := SubViewport.new()
	vp.size = win_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var gc = root.get_node_or_null("GameController")
	if gc == null:
		gc = load("res://scripts/autoload/game_controller.gd").new()
		gc.name = "GameController"
		root.add_child(gc)
	gc.current_level_number = 1

	var lvl: CarJamLevel = CarJamLevelScene.instantiate()
	lvl.enable_entrance_parade = true
	lvl.force_entrance_parade = true
	vp.add_child(lvl)
	if not lvl.is_node_ready():
		lvl._ready()

	if lvl.camera_2d != null:
		lvl.camera_2d.enabled = true
		lvl.camera_2d.make_current()
	lvl._update_layout(Vector2(win_size))

	# Frame 1: Immediate start - track should be completely empty (0 visible passengers)
	await process_frame
	await process_frame
	var img_start = vp.get_texture().get_image()
	img_start.save_png(ARTIFACT_DIR + "/qa_full_oval_1_empty_start.png")
	print("  [SAVED] qa_full_oval_1_empty_start.png (Track starts completely empty)")

	# Entrance parade advancing down feeder and populating oval
	for sec in range(1, 9):
		for i in range(60):
			await process_frame
		print("[Step %d] pending=%d feeder=%d circ=%d visuals=%d" % [
			sec,
			lvl._pending_feeder_rows.size(),
			lvl._feeder_rows.size(),
			lvl._circulating_rows.size(),
			lvl.passenger_visuals.get_child_count()
		])
		if not lvl._feeder_rows.is_empty():
			print("   feeder[0].prog = %.1f" % lvl._feeder_rows[0].progress)
		if not lvl._circulating_rows.is_empty():
			print("   circ[0].prog = %.1f" % lvl._circulating_rows[0].progress)
		var img = vp.get_texture().get_image()
		var fname = ARTIFACT_DIR + "/qa_stream_step_%d_sec.png" % sec
		img.save_png(fname)
		print("  [SAVED] qa_stream_step_%d_sec.png" % sec)

	# Now test gameplay: dispatch Blue Bus 2 into Slot 1
	print("\n--- DISPATCHING BLUE BUS 2 ---")
	lvl.controller.tap_vehicle(2)
	for i in range(120):
		await process_frame
	var img_blue = vp.get_texture().get_image()
	img_blue.save_png(ARTIFACT_DIR + "/qa_play_1_blue_boarding.png")
	print("  [SAVED] qa_play_1_blue_boarding.png (Blue passengers boarding bus in slot)")

	# Wait for Blue boarding to finish and bus departure
	for i in range(180):
		await process_frame

	# Dispatch Yellow Bus 1 into Slot 2
	print("\n--- DISPATCHING YELLOW BUS 1 ---")
	lvl.controller.tap_vehicle(1)
	for i in range(120):
		await process_frame
	var img_yellow = vp.get_texture().get_image()
	img_yellow.save_png(ARTIFACT_DIR + "/qa_play_2_yellow_boarding.png")
	print("  [SAVED] qa_play_2_yellow_boarding.png (Yellow passengers boarding bus in slot)")

	print("=== ENTRANCE AND CIRCULATION QA COMPLETE ===")
	quit(0)
