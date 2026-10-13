extends SceneTree

const ARTIFACT_DIR := "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c"
const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run_all_captures")

func _run_all_captures() -> void:
	print("--- STARTING VISUAL QA CAPTURE RUN ---")
	
	var targets = [
		{"res": Vector2i(810, 1753), "tag": "810x1753"},
		{"res": Vector2i(390, 844),  "tag": "390x844"},
		{"res": Vector2i(720, 1280), "tag": "720x1280"}
	]
	
	for t in targets:
		var sz: Vector2i = t["res"]
		var tag: String = t["tag"]
		
		# 1. Level 1 Gameplay
		await _capture_view(1, false, sz, "%s/level1_grey_platform_%s.png" % [ARTIFACT_DIR, tag])
		
		# 2. Level 2 Gameplay
		await _capture_view(2, false, sz, "%s/level2_grey_platform_%s.png" % [ARTIFACT_DIR, tag])
		
		# 3. Level 2 OUT OF SPACE Popup
		await _capture_view(2, true, sz, "%s/level2_out_of_space_%s.png" % [ARTIFACT_DIR, tag])

	print("--- ALL CAPTURES COMPLETE ---")
	quit(0)

func _capture_view(lvl_num: int, show_failure: bool, win_size: Vector2i, out_path: String) -> void:
	var gc = root.get_node_or_null("GameController")
	if gc == null:
		gc = load("res://scripts/autoload/game_controller.gd").new()
		gc.name = "GameController"
		root.add_child(gc)
	gc.current_level_number = lvl_num
	
	var vp := SubViewport.new()
	vp.size = win_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var lvl: CarJamLevel = CarJamLevelScene.instantiate()
	vp.add_child(lvl)
	if not lvl.is_node_ready():
		lvl._ready()
	
	if lvl.camera_2d != null:
		lvl.camera_2d.enabled = true
		lvl.camera_2d.make_current()
	lvl._update_layout(Vector2(win_size))
	
	if show_failure:
		lvl.controller.puzzle_failed.emit()
		
	# Wait for rendering to settle
	await create_timer(0.35).timeout
	
	var img = vp.get_texture().get_image()
	if img != null:
		img.save_png(out_path)
		print("Saved capture: %s (%dx%d)" % [out_path, img.get_width(), img.get_height()])
	else:
		printerr("Failed to get viewport image for %s" % out_path)
		
	vp.queue_free()
	await create_timer(0.1).timeout
