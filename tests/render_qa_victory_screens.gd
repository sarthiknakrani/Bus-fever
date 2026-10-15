extends SceneTree

const ARTIFACT_DIR := "/Users/nakranisarthikashokbhai/.gemini/antigravity/brain/12b46d5f-80de-46ce-9b32-104e3da72e3c"
const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run_captures")

func _run_captures() -> void:
	print("--- STARTING VICTORY CELEBRATION QA CAPTURE RUN ---")
	
	var save_mgr = root.get_node_or_null("SaveManager")
	if save_mgr != null:
		save_mgr.wipe()
		save_mgr.set_coins(100)

	var win_size := Vector2i(720, 1280)

	# 1. Level 1 Complete Screen Initial Presentation
	await _capture_victory(1, 0.15, "%s/qa_victory_1_screen.png" % ARTIFACT_DIR, win_size)

	# 2. Level 1 Fireworks Active
	await _capture_victory(1, 0.35, "%s/qa_victory_2_fireworks.png" % ARTIFACT_DIR, win_size)

	# 3. Level 1 Flying Coins Mid-Flight
	await _capture_victory(1, 0.70, "%s/qa_victory_3_coins_flying.png" % ARTIFACT_DIR, win_size)

	# 4. Level 1 Fully Settled (+50 added to counter -> 150)
	await _capture_victory(1, 1.40, "%s/qa_victory_4_settled.png" % ARTIFACT_DIR, win_size)

	# 5. Level 2 Complete ("More Levels Coming Soon" state)
	await _capture_victory(2, 0.50, "%s/qa_victory_5_level2_end.png" % ARTIFACT_DIR, win_size)

	print("--- ALL VICTORY CAPTURES COMPLETED SUCCESSFULLY ---")
	quit(0)

func _capture_victory(lvl_num: int, wait_time: float, out_path: String, win_size: Vector2i) -> void:
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

	# Trigger level complete
	lvl._on_level_completed()

	await create_timer(wait_time).timeout

	var img = vp.get_texture().get_image()
	if img != null:
		img.save_png(out_path)
		print("Saved capture: %s (%dx%d) after %.2fs" % [out_path, img.get_width(), img.get_height(), wait_time])
	else:
		printerr("Failed to get viewport image for %s" % out_path)

	vp.queue_free()
	await create_timer(0.05).timeout
