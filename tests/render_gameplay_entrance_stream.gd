extends SceneTree

const ARTIFACT_DIR := "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827"
const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n=== RENDERING INTERACTIVE DISPATCH & MATCHING BOARDING QA ===")
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
	lvl.force_entrance_parade = true
	vp.add_child(lvl)
	if not lvl.is_node_ready():
		lvl._ready()

	if lvl.camera_2d != null:
		lvl.camera_2d.enabled = true
		lvl.camera_2d.make_current()
	lvl._update_layout(Vector2(win_size))

	# Wait until passengers stream in and stop at gate
	for i in range(250):
		await process_frame

	# Dispatch Blue Bus 2 into Slot 1
	print("  Dispatching Blue Bus 2...")
	lvl.controller.tap_vehicle(2)
	for i in range(45):
		await process_frame

	# Now dispatch Yellow Bus 1 into Slot 2!
	print("  Dispatching Yellow Bus 1...")
	lvl.controller.tap_vehicle(1)

	# Wait for Yellow Bus arrival and yellow boarding
	for i in range(120):
		await process_frame
	var img1 = vp.get_texture().get_image()
	img1.save_png(ARTIFACT_DIR + "/qa_entrance_7_matching_boarding.png")
	print("  [SAVED] qa_entrance_7_matching_boarding.png (Yellow passengers boarding Yellow Bus 1 in Slot 2)")

	# Wait for Yellow boarding to complete, departure, and blue queue advancing
	for i in range(180):
		await process_frame
	var img2 = vp.get_texture().get_image()
	img2.save_png(ARTIFACT_DIR + "/qa_entrance_8_blue_at_gate.png")
	print("  [SAVED] qa_entrance_8_blue_at_gate.png (Blue queue advanced to gate and boarding Bus 2)")

	print("=== MATCHING BOARDING COMPLETE ===")
	quit(0)
