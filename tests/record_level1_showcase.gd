extends SceneTree

const ARTIFACT_DIR := "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/c728cf8f-a5f0-47d4-bf47-cd75afc92827"
const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

var vp: SubViewport
var frame_dir: String
var frame_idx: int = 0

func _init() -> void:
	call_deferred("_run")

func _save_frame() -> void:
	var img = vp.get_texture().get_image()
	if img != null:
		var p = "%s/frame_%04d.png" % [frame_dir, frame_idx]
		img.save_png(p)
		frame_idx += 1

func _run() -> void:
	print("\n=== RECORDING FULL LEVEL 1 SHOWCASE VIDEO ===")
	var win_size := Vector2i(540, 960)

	vp = SubViewport.new()
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

	frame_dir = ARTIFACT_DIR + "/scratch/video_frames"
	DirAccess.make_dir_recursive_absolute(frame_dir)

	var dir = DirAccess.open(frame_dir)
	if dir:
		for f in dir.get_files():
			dir.remove(f)

	# Phase 1: Start with empty track (15 frames)
	for i in range(15):
		await process_frame
		_save_frame()

	# Phase 2: Passengers stream in from feeder (60 frames)
	for i in range(60):
		await process_frame
		_save_frame()

	# Phase 3: Queue stops at gate (40 frames)
	for i in range(40):
		await process_frame
		_save_frame()

	# Phase 4: Dispatch Blue Bus 2 (unblocked at start)
	lvl.controller.tap_vehicle(2)
	for i in range(35):
		await process_frame
		_save_frame()

	# Phase 5: Dispatch Yellow Bus 1 (freed after Bus 2)
	lvl.controller.tap_vehicle(1)
	for i in range(120):
		await process_frame
		_save_frame()

	print("=== RECORDING FINISHED: %d frames captured ===" % frame_idx)
	quit(0)
